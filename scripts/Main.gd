# Main.gd — Master scene coordinator with World Select
extends Node

var _overworld: Node2D      = null
var _battle:    Node2D      = null
var _title:     Node2D      = null
var _world_sel: Node2D      = null
var _dialog:    CanvasLayer = null
var _hud:       CanvasLayer = null
var _active_world: String   = "math"

func _ready() -> void:
	_setup_ui()
	_show_title()

func _setup_ui() -> void:
	_dialog = load("res://scripts/DialogBox.gd").new()
	_dialog.name = "DialogBox"
	_dialog.add_to_group("dialog_box")
	add_child(_dialog)

	_hud = load("res://scripts/HUD.gd").new()
	_hud.name = "HUD"
	add_child(_hud)

# ── Title Screen ──────────────────────────────────────────────────────────────
func _show_title() -> void:
	_title = load("res://scripts/TitleScreen.gd").new()
	_title.name = "TitleScreen"
	_title.connect("start_game", _on_title_start)
	add_child(_title)

func _on_title_start() -> void:
	_title.queue_free(); _title = null
	_show_world_select()

# ── World Select ──────────────────────────────────────────────────────────────
func _show_world_select() -> void:
	if _overworld:
		_overworld.queue_free(); _overworld = null

	_world_sel = load("res://scripts/WorldSelectScreen.gd").new()
	_world_sel.name = "WorldSelect"
	_world_sel.connect("world_chosen", _on_world_chosen)
	add_child(_world_sel)

func _on_world_chosen(world_id: String) -> void:
	_active_world = world_id
	_world_sel.queue_free(); _world_sel = null
	_show_overworld(world_id)

# ── Overworld ─────────────────────────────────────────────────────────────────
func _show_overworld(world_id: String) -> void:
	var ow = load("res://scripts/Overworld.gd").new()
	ow.name      = "Overworld"
	ow.world_id  = world_id
	ow.add_to_group("overworld")
	ow.connect("show_dialog",      _on_ow_dialog)
	ow.connect("start_gym_battle", _on_gym_battle)
	ow.connect("gain_xp",          _on_gain_xp)
	add_child(ow)
	move_child(ow, 0)
	_overworld = ow

func _resume_overworld() -> void:
	if _overworld and is_instance_valid(_overworld):
		_overworld.show()
		_overworld.set_dialog_open(false)

# ── Dialog ────────────────────────────────────────────────────────────────────
func _on_ow_dialog(lines: Array) -> void:
	_dialog.show_lines(lines, func():
		_resume_overworld()
	)

# ── XP ────────────────────────────────────────────────────────────────────────
func _on_gain_xp(amount: int, _ctx: String) -> void:
	GameManager.add_xp(amount)
	_hud.show_xp_gain(amount)

# ── Gym Battle ────────────────────────────────────────────────────────────────
func _on_gym_battle(gym_data: Dictionary) -> void:
	if _overworld:
		_overworld.set_process_input(false)
		_overworld.hide()

	_battle = load("res://scripts/BattleScene.gd").new()
	_battle.name = "BattleScene"
	_battle.connect("battle_ended", _on_battle_ended)
	add_child(_battle)
	move_child(_battle, 1)
	_battle.setup(gym_data)

func _on_battle_ended(won: bool, badge_name: String, xp: int) -> void:
	if _battle:
		_battle.queue_free(); _battle = null

	# Load correct leader data for win/lose lines
	var leader: Dictionary
	match _active_world:
		"english": leader = EnglishDB.get_gym1_leader()
		"music":   leader = MusicDB.get_gym1_leader()
		_:         leader = AlgebraDB.get_gym1_leader()

	if won:
		GameManager.add_xp(xp)
		GameManager.earn_badge(badge_name)
		var lines: Array = leader.get("win",[]).duplicate()
		lines.append("★  " + badge_name + " earned!  ★\n\n+" + str(xp) + " XP!")
		_dialog.show_lines(lines, func(): _resume_overworld())
	else:
		var lines: Array = leader.get("lose",[]).duplicate()
		lines.append("Review your notes and try again!")
		_dialog.show_lines(lines, func(): _resume_overworld())

# ── Global keys ───────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:    # Dev: full reset
				GameManager.reset_game()
				get_tree().reload_current_scene()
			KEY_ESCAPE: # Return to world select (from overworld only)
				if _overworld and is_instance_valid(_overworld) and not _battle:
					_overworld.queue_free(); _overworld = null
					_show_world_select()
