# Main.gd
# Master scene coordinator — wires together all game systems
extends Node

# ── Scene references ──────────────────────────────────────────────────────────
var _overworld:    Node2D       = null
var _battle:       Node2D       = null
var _title:        Node2D       = null
var _dialog:       CanvasLayer  = null
var _hud:          CanvasLayer  = null

# ── Boot ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_persistent_ui()
	_show_title()

func _setup_persistent_ui() -> void:
	# Dialog box (CanvasLayer, always present)
	_dialog = load("res://scripts/DialogBox.gd").new()
	_dialog.name = "DialogBox"
	_dialog.add_to_group("dialog_box")
	add_child(_dialog)

	# HUD (CanvasLayer, always present)
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
	_title.queue_free()
	_title = null
	_show_overworld()

# ── Overworld ─────────────────────────────────────────────────────────────────
func _show_overworld() -> void:
	if _overworld:
		return   # already exists
	_overworld = load("res://scripts/Overworld.gd").new()
	_overworld.name = "Overworld"
	_overworld.add_to_group("overworld")
	_overworld.connect("show_dialog",     _on_overworld_dialog)
	_overworld.connect("start_gym_battle",_on_gym_battle)
	_overworld.connect("gain_xp",         _on_gain_xp)
	add_child(_overworld)
	move_child(_overworld, 0)   # keep behind UI layers

func _resume_overworld() -> void:
	if _overworld:
		_overworld.show()
		_overworld.set_process_input(true)

# ── Dialog from Overworld ─────────────────────────────────────────────────────
func _on_overworld_dialog(lines: Array) -> void:
	if _overworld:
		_overworld.set_process_input(false)
	_dialog.show_lines(lines, func():
		if _overworld and is_instance_valid(_overworld):
			_overworld.set_process_input(true)
	)

# ── XP Gain ───────────────────────────────────────────────────────────────────
func _on_gain_xp(amount: int, _context: String) -> void:
	GameManager.add_xp(amount)
	_hud.show_xp_gain(amount)

# ── Gym Battle ────────────────────────────────────────────────────────────────
func _on_gym_battle(gym_data: Dictionary) -> void:
	# Disable overworld
	if _overworld:
		_overworld.set_process_input(false)
		_overworld.hide()

	# Create battle scene
	_battle = load("res://scripts/BattleScene.gd").new()
	_battle.name = "BattleScene"
	_battle.connect("battle_ended", _on_battle_ended)
	add_child(_battle)
	move_child(_battle, 1)   # above overworld, below UI
	_battle.setup(gym_data)

func _on_battle_ended(won: bool, badge_name: String, xp: int) -> void:
	# Remove battle scene
	if _battle:
		_battle.queue_free()
		_battle = null

	# Process result
	if won:
		GameManager.add_xp(xp)
		GameManager.earn_badge(badge_name)
		var leader := AlgebraDB.get_gym1_leader()
		var win_lines: Array = leader.get("win", []).duplicate()
		win_lines.append("★  " + badge_name + " earned!  ★\n\n+" + str(xp) + " XP!")
		_dialog.show_lines(win_lines, func(): _resume_overworld())
	else:
		var leader := AlgebraDB.get_gym1_leader()
		var lose_lines: Array = leader.get("lose", []).duplicate()
		lose_lines.append("Review your notes and try again!")
		_dialog.show_lines(lose_lines, func(): _resume_overworld())

# ── Global shortcuts ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# F5 = quick reset (dev helper)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			GameManager.reset_game()
			get_tree().reload_current_scene()
