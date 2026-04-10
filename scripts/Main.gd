# Main.gd v0.3 — Master scene coordinator
extends Node

var _title:    Node2D=null; var _wmap:Node2D=null; var _ow:Node2D=null
var _battle:   Node2D=null; var _duel:Node2D=null; var _name_screen:Node2D=null
var _dialog:   CanvasLayer=null; var _hud:CanvasLayer=null

func _ready()->void:
	_dialog=load("res://scripts/DialogBox.gd").new()
	_dialog.name="DialogBox"; _dialog.add_to_group("dialog_box"); add_child(_dialog)
	_hud=load("res://scripts/HUD.gd").new(); _hud.name="HUD"; add_child(_hud)
	_show_title()

# ── Title ─────────────────────────────────────────────────────────────────────
func _show_title()->void:
	_title=load("res://scripts/TitleScreen.gd").new()
	_title.name="Title"; _title.connect("start_game",_on_title_start); add_child(_title)

func _on_title_start()->void:
	_title.queue_free(); _title=null
	if GameManager.player_name not in ["Arix",""]:
		_show_world_map()
	else:
		_show_name_entry()

# ── Name Entry ────────────────────────────────────────────────────────────────
func _show_name_entry()->void:
	_name_screen=_NameEntry.new(); _name_screen.name="NameEntry"
	_name_screen.connect("name_chosen",_on_name_chosen); add_child(_name_screen)

func _on_name_chosen(n:String)->void:
	GameManager.player_name=n
	if _name_screen: _name_screen.queue_free(); _name_screen=null
	_show_world_map()

# ── World Map ─────────────────────────────────────────────────────────────────
func _show_world_map()->void:
	if _ow: _ow.hide()
	if _wmap==null:
		_wmap=load("res://scripts/WorldMap.gd").new()
		_wmap.name="WorldMap"; _wmap.add_to_group("overworld")
		_wmap.connect("enter_zone",_on_enter_zone)
		_wmap.connect("show_dialog",_on_wmap_dialog)
		add_child(_wmap); move_child(_wmap,0)
	_wmap.show(); _wmap.set_process_input(true)

func _on_wmap_dialog(lines:Array)->void:
	if _wmap: _wmap.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _wmap and is_instance_valid(_wmap): _wmap.set_process_input(true))

func _on_enter_zone(zone_id:String)->void:
	if _wmap: _wmap.hide(); _wmap.set_process_input(false)
	GameManager.active_world=zone_id
	_show_overworld(zone_id)

# ── Overworld ─────────────────────────────────────────────────────────────────
func _show_overworld(wid:String)->void:
	if _ow==null:
		_ow=load("res://scripts/Overworld.gd").new()
		_ow.name="Overworld"; _ow.add_to_group("overworld")
		_ow.connect("show_dialog",_on_ow_dialog)
		_ow.connect("start_gym_battle",_on_gym_battle)
		_ow.connect("gain_xp",_on_xp)
		_ow.connect("start_duel",_on_duel)
		_ow.connect("back_to_world_map",_on_back_to_map)
		add_child(_ow); move_child(_ow,0)
	_ow.init_world(wid); _ow.show(); _ow.set_process_input(true)

func _on_ow_dialog(lines:Array)->void:
	if _ow: _ow.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _ow and is_instance_valid(_ow): _ow.set_process_input(true))

func _on_back_to_map()->void:
	if _ow: _ow.hide(); _ow.set_process_input(false)
	_show_world_map()

func _on_xp(amount:int,_ctx:String)->void:
	GameManager.add_xp(amount); _hud.show_xp_gain(amount)

# ── Gym Battle ────────────────────────────────────────────────────────────────
func _on_gym_battle(gym_data:Dictionary)->void:
	if _ow: _ow.set_process_input(false); _ow.hide()
	_battle=load("res://scripts/BattleScene.gd").new()
	_battle.name="Battle"; _battle.connect("battle_ended",_on_battle_ended); add_child(_battle)
	if _battle.get_index()>0: move_child(_battle,1)
	_battle.setup(gym_data)

func _on_battle_ended(won:bool,badge_name:String,xp:int)->void:
	if _battle: _battle.queue_free(); _battle=null
	var world:=GameManager.active_world
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db=db_map.get(world,AlgebraDB)
	var rep:=AdaptiveAI._build_report() if AdaptiveAI.has_method("_build_report") else {}
	if won:
		GameManager.add_xp(xp); GameManager.earn_badge(badge_name)
		var lines:Array=db.get_gym1_leader().get("win",[]).duplicate()
		lines.append("★  "+badge_name+" earned!  ★\n\n+"+str(xp)+" XP!")
		if rep.get("accuracy",1.0)<0.7:
			lines.append("Your accuracy was "+str(int(rep.get("accuracy",0)*100))+"% —\nkeep practicing those weak topics!")
		_dialog.show_lines(lines,func():
			if _ow and is_instance_valid(_ow): _ow.show(); _ow.set_process_input(true))
	else:
		var lines:Array=db.get_gym1_leader().get("lose",[]).duplicate()
		lines.append("Review and return stronger!")
		_dialog.show_lines(lines,func():
			if _ow and is_instance_valid(_ow): _ow.show(); _ow.set_process_input(true))

# ── Knowledge Duel ────────────────────────────────────────────────────────────
func _on_duel(opponent:Dictionary)->void:
	# Small delay to let dialog finish
	await get_tree().create_timer(0.4).timeout
	if _dialog.is_open(): return   # still in dialog, skip
	if _ow: _ow.set_process_input(false); _ow.hide()
	_duel=load("res://scripts/KnowledgeDuel.gd").new()
	_duel.name="Duel"; _duel.connect("duel_ended",_on_duel_ended); add_child(_duel)
	if _duel.get_index()>0: move_child(_duel,1)
	_duel.setup(GameManager.active_world, opponent)

func _on_duel_ended(won:bool, xp:int)->void:
	if _duel: _duel.queue_free(); _duel=null
	var lines:Array
	if won:
		GameManager.add_xp(xp)
		lines=["You won the Knowledge Duel!","Your mastery is undeniable!","+"+str(xp)+" XP earned!\nDuel Wins: "+str(GameManager.get_duel_wins())]
	else:
		lines=["You lost this time...","Study your weak topics and\nchallenge again!","Every loss is a lesson."]
	_dialog.show_lines(lines,func():
		if _ow and is_instance_valid(_ow): _ow.show(); _ow.set_process_input(true))

# ── Dev ───────────────────────────────────────────────────────────────────────
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F5:
			GameManager.reset_all(); AdaptiveAI._data={}; get_tree().reload_current_scene()
		elif event.keycode==KEY_F4:
			if _ow: _ow.hide(); _ow.set_process_input(false)
			if _battle: _battle.queue_free(); _battle=null
			if _duel: _duel.queue_free(); _duel=null
			_show_world_map()

# ═════════════════════════════════════════════════════════════════════════════
class _NameEntry extends Node2D:
	signal name_chosen(n:String)
	var _n:String="Arix"; var _ct:float=0.0; var _cur:bool=true; var _done:bool=false
	func _ready()->void: set_process(true); set_process_input(true)
	func _process(delta:float)->void:
		_ct+=delta; if _ct>=0.5: _ct=0.0; _cur=not _cur; queue_redraw()
	func _input(event:InputEvent)->void:
		if _done: return
		if event is InputEventKey and event.pressed:
			var k =event.keycode
			if k==KEY_BACKSPACE and _n.length()>0: _n=_n.substr(0,_n.length()-1)
			elif k in [KEY_ENTER,KEY_KP_ENTER]:
				if _n.strip_edges()!="": _done=true; name_chosen.emit(_n.strip_edges())
			elif k>=KEY_A and k<=KEY_Z and _n.length()<10:
				var ch:=char(k)
				_n+=ch.to_upper() if (event.shift_pressed or _n.length()==0) else ch.to_lower()
			elif k==KEY_MINUS and _n.length()>0 and _n.length()<10: _n+="-"
	func _draw()->void:
		const W:=480;const H:=320
		var fnt:=ThemeDB.fallback_font
		draw_rect(Rect2(0,0,W,H),Color("#050510"))
		for i in 20:
			var sx:=float((i*53+7)%480); var sy:=float((i*37+11)%200)
			draw_rect(Rect2(sx,sy,2,2),Color(1,1,1,0.4))
		draw_rect(Rect2(80,90,320,140),Color(0.04,0.04,0.12,0.96))
		draw_rect(Rect2(80,90,320,140),Color(0.8,0.8,1.0,0.75),false,2.5)
		draw_string(fnt,Vector2(108,118),"What is your name, young scholar?",
			HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ffd700"))
		draw_rect(Rect2(108,126,264,32),Color(0.08,0.08,0.18))
		draw_rect(Rect2(108,126,264,32),Color(0.6,0.7,1.0,0.8),false,2.0)
		draw_string(fnt,Vector2(118,148),_n+("█" if _cur else " "),
			HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#ffffff"))
		draw_string(fnt,Vector2(108,172),"Type name  |  ENTER to confirm",
			HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.6,0.65,0.8))
		draw_string(fnt,Vector2(130,190),"(max 10 chars, letters only)",
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.45,0.45,0.6))
		_draw_sprite(214,56)
	func _draw_sprite(ox:int,oy:int)->void:
		draw_rect(Rect2(ox+6,oy+26,9,5),Color("#111111")); draw_rect(Rect2(ox+19,oy+26,9,5),Color("#111111"))
		draw_rect(Rect2(ox+7,oy+17,9,11),Color("#1a3a8f")); draw_rect(Rect2(ox+18,oy+17,9,11),Color("#1a3a8f"))
		draw_rect(Rect2(ox+4,oy+9,24,10),Color("#cc1818")); draw_rect(Rect2(ox+4,oy+9,24,3),Color("#e02020"))
		draw_rect(Rect2(ox+0,oy+10,5,10),Color("#f0c090")); draw_rect(Rect2(ox+27,oy+10,5,10),Color("#f0c090"))
		draw_rect(Rect2(ox+7,oy+1,18,10),Color("#f0c090")); draw_rect(Rect2(ox+6,oy+1,20,5),Color("#cc1818"))
		draw_rect(Rect2(ox+4,oy+4,24,3),Color("#cc1818")); draw_rect(Rect2(ox+14,oy+2,5,4),Color("#ffd700"))
		draw_rect(Rect2(ox+10,oy+7,4,3),Color("#111111")); draw_rect(Rect2(ox+18,oy+7,4,3),Color("#111111"))
