# Main.gd v2.0 — Scene coordinator
extends Node

var _scene:   Node   = null
var _dialog:  Node   = null
var _hud:     Node   = null
var _player:  Node2D = null

func _ready() -> void:
	_dialog = load("res://scripts/ui/DialogBox.gd").new()
	_dialog.name = "DialogBox"; _dialog.add_to_group("dialog_box"); add_child(_dialog)
	_hud    = load("res://scripts/ui/HUD.gd").new()
	_hud.name    = "HUD"; add_child(_hud)
	_show_title()

# ── Title ─────────────────────────────────────────────────────────────────────
func _show_title() -> void:
	_free_scene()
	var t := Node2D.new(); t.name = "Title"
	t.set_script(load("res://scripts/ui/TitleScreen.gd"))
	t.connect("start_game", _on_title_start)
	add_child(t); move_child(t, 0); _scene = t

func _on_title_start() -> void:
	if GameManager.player_name not in ["Arix",""]: _show_world_map()
	else: _show_name_entry()

# ── Name Entry ────────────────────────────────────────────────────────────────
func _show_name_entry() -> void:
	_free_scene()
	var ne := _NameEntry.new(); ne.name = "NameEntry"
	ne.connect("name_chosen", _on_named)
	add_child(ne); move_child(ne, 0); _scene = ne

func _on_named(n: String) -> void:
	GameManager.player_name = n; _show_world_map()

# ── World Map ─────────────────────────────────────────────────────────────────
func _show_world_map() -> void:
	_free_scene()
	var wm := Node2D.new(); wm.name = "WorldMap"
	wm.set_script(load("res://scripts/ui/WorldMap.gd"))
	wm.connect("enter_zone",  _on_enter_zone)
	wm.connect("show_dialog", _on_wm_dialog)
	add_child(wm); move_child(wm, 0); _scene = wm

func _on_wm_dialog(lines: Array) -> void: _dialog.show_lines(lines)
func _on_enter_zone(zone_id: String) -> void:
	if zone_id == "silver":
		_start_silver(); return
	# Handle route duel (format: "duel:{json}")
	if zone_id.begins_with("duel:"):
		var json_str := zone_id.substr(5)
		var opp = JSON.parse_string(json_str)
		if opp is Dictionary:
			_start_duel({"world": opp.get("world","math"), "opponent": opp})
		return
	# Find the world for this city
	var world := "math"
	for city in GymStoryline.CITIES:
		if city.id == zone_id: world = city.get("world","math"); break
	GameManager.active_world = world
	_show_world_with_gym(zone_id, world)

func _show_world_with_gym(city_id: String, world: String) -> void:
	_free_scene()
	var world_node := Node2D.new(); world_node.name = "World"
	world_node.set_script(load("res://scripts/world/World.gd"))
	add_child(world_node); move_child(world_node, 0); _scene = world_node
	world_node.add_to_group("active_world")
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.set_script(load("res://scripts/player/Player.gd"))
	var cs := CollisionShape2D.new()
	var shape := CapsuleShape2D.new(); shape.radius=10.0; shape.height=20.0
	cs.shape = shape; _player.add_child(cs); world_node.add_child(_player)
	world_node.init_world(world, _player, _dialog, _hud)
	world_node.connect("change_scene", _on_change_scene)
	# Show act intro if first time in this act
	var badges := GameManager.get_badges().size()
	var act := GymStoryline.get_act(badges+1)
	if act > 1 and not GameManager.has_talked("act_"+str(act)+"_intro"):
		GameManager.mark_talked("act_"+str(act)+"_intro")
		if "context" in _dialog: _dialog.context = "world"
		var intro = GymStoryline.ACT_INTROS.get(act,[])
		var resolved:Array = []
		for line in intro:
			resolved.append(str(line).replace("{name}", GameManager.player_name))
		_dialog.show_lines(resolved)

# ── Town World ────────────────────────────────────────────────────────────────
func _show_world(world_id: String) -> void:
	_free_scene()

	# World node (draws tiles at real coords)
	var world := Node2D.new(); world.name = "World"
	world.set_script(load("res://scripts/world/World.gd"))
	add_child(world); move_child(world, 0); _scene = world
	world.add_to_group("active_world")

	# Player (CharacterBody2D with Camera2D child)
	_player = CharacterBody2D.new(); _player.name = "Player"
	_player.set_script(load("res://scripts/player/Player.gd"))
	var cs    := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 10.0; shape.height = 20.0
	cs.shape = shape; _player.add_child(cs)
	world.add_child(_player)

	world.init_world(world_id, _player, _dialog, _hud)
	world.connect("change_scene", _on_change_scene)

func _on_change_scene(scene_name: String, data: Dictionary) -> void:
	match scene_name:
		"world_map": _show_world_map()
		"battle":    _start_battle(data)
		"duel":      _start_duel(data)
		"silver":    _start_silver()

# ── Silver Mountain ────────────────────────────────────────────────────────────
func _start_silver() -> void:
	if _scene: _scene.hide()
	var sm := Node2D.new(); sm.name = "SilverMountain"
	sm.set_script(load("res://scripts/silver/SilverMountain.gd"))
	sm.connect("silver_cleared", _on_silver_cleared)
	sm.connect("back_to_map", func():
		var sm_node = get_node_or_null("SilverMountain")
		if sm_node:
			sm_node.queue_free()

		if _scene:
			_scene.show()

		_show_world_map()
)
	add_child(sm)
	sm.setup(_dialog, _hud)

func _on_silver_cleared() -> void:
	var sm = get_node_or_null("SilverMountain")
	if sm:
		sm.queue_free()

	if _scene:
		_scene.show()
	_show_kaiser_screen()

func _show_kaiser_screen() -> void:
	_free_scene()
	var ks := Node2D.new(); ks.name = "KaiserScreen"
	ks.set_script(load("res://scripts/silver/KaiserScreen.gd"))
	add_child(ks); move_child(ks, 0); _scene = ks

# ── Gym Battle ────────────────────────────────────────────────────────────────
func _start_battle(gym_data: Dictionary) -> void:
	if _scene: _scene.hide()
	var b := Node2D.new(); b.name = "Battle"
	b.set_script(load("res://scripts/battle/BattleSystem.gd"))
	b.connect("battle_ended", _on_battle_ended)
	add_child(b); b.setup(gym_data, _dialog)

func _on_battle_ended(won: bool, badge_name: String, xp: int) -> void:
	var battle = get_node_or_null("Battle")
	if battle:
		battle.queue_free()
	if _scene: _scene.show()
	if "context" in _dialog: _dialog.context = "world"
	if won:
		GameManager.add_xp(xp); GameManager.earn_badge(badge_name); _hud.show_xp_gain(xp)
		var badges := GameManager.get_badges().size()
		var lines := ["★  "+badge_name+"  earned!","Badges: "+str(badges)+"/20","+"+ str(xp)+" XP!"]
		# Check for act completion
		if badges == 5:  lines.append("ACT 1 COMPLETE!\nRising challenges await...")
		elif badges == 12: lines.append("ACT 2 COMPLETE!\nThe final gyms await...")
		elif badges == 20: lines.append("ALL 20 BADGES!\nSilver Mountain awaits!")
		_dialog.show_lines(lines)
	else:
		var lines := ["Defeated...","Study with the Teachers\nand return stronger!"]
		_dialog.show_lines(lines)

# ── Knowledge Duel ────────────────────────────────────────────────────────────
func _start_duel(data: Dictionary) -> void:
	if _scene: _scene.hide()
	var d := Node2D.new(); d.name = "Duel"
	d.set_script(load("res://scripts/battle/DuelSystem.gd"))
	d.connect("duel_ended", _on_duel_ended)
	add_child(d); d.setup(data.get("world","math"), data.get("opponent",{}), _dialog)

func _on_duel_ended(won: bool, xp: int) -> void:
	var duel = get_node_or_null("Duel")
	if duel:
		duel.queue_free()

	if _scene: _scene.show()
	if won:
		GameManager.add_xp(xp); GameManager.add_duel_win(); _hud.show_xp_gain(xp)
		_dialog.show_lines(["Duel Victory! 🏆",GameManager.player_name+" wins!",
			"+"+str(xp)+" XP!\nTotal Duel Wins: "+str(GameManager.get_duel_wins())])
	else:
		_dialog.show_lines(["Duel lost...","Study your weak topics!\nYou still earned +"+str(xp)+" XP."])

func _free_scene() -> void:
	if _scene and is_instance_valid(_scene): _scene.queue_free(); _scene = null
	_player = null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5: GameManager.reset_all(); get_tree().reload_current_scene()
		elif event.keycode == KEY_F4:
			var battle = get_node_or_null("Battle")
			if battle:
				battle.queue_free()

			var duel = get_node_or_null("Duel")
			if duel:
				duel.queue_free()
			_show_world_map()

# ═══════════════ Name Entry Screen ════════════════════════════════════════════
class _NameEntry extends Node2D:
	signal name_chosen(n: String)
	var _n: String = "Arix"; var _ct: float = 0.0; var _cur: bool = true; var _done: bool = false
	func _ready() -> void: set_process(true); set_process_input(true)
	func _process(d: float) -> void: _ct+=d; if _ct>=0.5: _ct=0.0; _cur=not _cur; queue_redraw()
	func _input(ev: InputEvent) -> void:
		if _done: return
		if ev is InputEventKey and ev.pressed:
			var k = ev.keycode
			if k==KEY_BACKSPACE and _n.length()>0: _n=_n.substr(0,_n.length()-1)
			elif k in [KEY_ENTER,KEY_KP_ENTER]:
				if _n.strip_edges()!="": _done=true; name_chosen.emit(_n.strip_edges())
			elif k>=KEY_A and k<=KEY_Z and _n.length()<10:
				_n += char(k).to_upper() if (ev.shift_pressed or _n.length()==0) else char(k).to_lower()
	func _draw() -> void:
		const W:=480; const H:=320; var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010")
		# Gen 2 checkered green background
		for gy in range(0,H,4):
			for gx in range(0,W,4):
				draw_rect(Rect2(gx,gy,4,4), Color("#9bbc0f") if ((gx/4+gy/4)%2)==0 else Color("#8bac0f"))
		# Dialog box
		draw_rect(Rect2(60,85,360,150), DK); draw_rect(Rect2(61,86,358,148), Color("#f0f0e0"))
		draw_rect(Rect2(61,86,358,16), Color("#2060a0")); draw_rect(Rect2(62,87,356,14), Color("#4888d0"))
		draw_string(fnt,Vector2(70,100),"What is your name?",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#f0f8ff"))
		draw_rect(Rect2(78,116,244,30),DK); draw_rect(Rect2(79,117,242,28),Color("#ffffff"))
		draw_string(fnt,Vector2(86,135),_n+("█" if _cur else " "),HORIZONTAL_ALIGNMENT_LEFT,-1,18,DK)
		draw_string(fnt,Vector2(70,160),"Type name — press ENTER to confirm",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.3,0.3,0.4))
		draw_string(fnt,Vector2(70,176),"(letters only, max 10 chars)",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.5,0.5,0.6))
		draw_string(fnt,Vector2(70,198),"Your journey to become Kaiser begins!",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#106030"))
