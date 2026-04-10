# Main.gd v0.4 — Master scene coordinator with guaranteed input flow
extends Node

var _title:Node2D=null; var _wmap:Node2D=null; var _ow:Node2D=null
var _battle:Node2D=null; var _duel:Node2D=null; var _name_screen:Node2D=null
var _dialog:CanvasLayer=null; var _hud:CanvasLayer=null

func _ready()->void:
	_dialog=load("res://scripts/DialogBox.gd").new()
	_dialog.name="DialogBox"; _dialog.add_to_group("dialog_box"); add_child(_dialog)
	_hud=load("res://scripts/HUD.gd").new(); _hud.name="HUD"; add_child(_hud)
	_show_title()

func _show_title()->void:
	_title=load("res://scripts/TitleScreen.gd").new()
	_title.name="Title"; _title.connect("start_game",_on_title_start); add_child(_title)

func _on_title_start()->void:
	_title.queue_free(); _title=null
	if GameManager.player_name not in ["Arix",""]: _show_world_map()
	else: _show_name_entry()

func _show_name_entry()->void:
	_name_screen=_NameEntry.new(); _name_screen.name="NameEntry"
	_name_screen.connect("name_chosen",_on_name_chosen); add_child(_name_screen)

func _on_name_chosen(n:String)->void:
	GameManager.player_name=n
	if _name_screen: _name_screen.queue_free(); _name_screen=null
	_show_world_map()

func _show_world_map()->void:
	if _ow: _ow.hide(); _ow.set_process_input(false)
	if _wmap==null:
		_wmap=load("res://scripts/WorldMap.gd").new()
		_wmap.name="WorldMap"; _wmap.add_to_group("overworld")
		_wmap.connect("enter_zone",_on_enter_zone)
		_wmap.connect("show_dialog",_on_wmap_dialog)
		add_child(_wmap); move_child(_wmap,0)
	_wmap.show()
	# Ensure input is enabled — bug fix for blank screen
	_wmap.set_process(true)
	_wmap.set_process_input(true)

func _on_wmap_dialog(lines:Array)->void:
	if _wmap: _wmap.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _wmap and is_instance_valid(_wmap):
			_wmap.set_process(true); _wmap.set_process_input(true))

func _on_enter_zone(zone_id:String)->void:
	if _wmap: _wmap.hide(); _wmap.set_process_input(false)
	GameManager.active_world=zone_id
	_show_overworld(zone_id)

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
	# CRITICAL: init before enabling — sets valid position
	_ow.init_world(wid)
	_ow.show()
	_ow.set_process(true)
	_ow.set_process_input(true)

func _on_ow_dialog(lines:Array)->void:
	if _ow: _ow.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _ow and is_instance_valid(_ow):
			_ow.set_process(true); _ow.set_process_input(true))

func _on_back_to_map()->void:
	if _ow: _ow.hide(); _ow.set_process_input(false)
	_show_world_map()

func _on_xp(amount:int,_ctx:String)->void:
	GameManager.add_xp(amount); _hud.show_xp_gain(amount)

func _on_gym_battle(gym_data:Dictionary)->void:
	if _ow: _ow.set_process_input(false); _ow.hide()
	_battle=load("res://scripts/BattleScene.gd").new()
	_battle.name="Battle"; _battle.connect("battle_ended",_on_battle_ended); add_child(_battle)
	if get_child_count()>1: move_child(_battle,1)
	_battle.setup(gym_data)

func _on_battle_ended(won:bool,badge_name:String,xp:int)->void:
	if _battle: _battle.queue_free(); _battle=null
	var world:=GameManager.active_world
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db=db_map.get(world,AlgebraDB)
	if won:
		GameManager.add_xp(xp); GameManager.earn_badge(badge_name)
		var lines:Array=db.get_gym1_leader().get("win",[]).duplicate()
		lines.append("★  "+badge_name+" earned!  ★\n\n+"+str(xp)+" XP!")
		_dialog.show_lines(lines,func():
			if _ow and is_instance_valid(_ow):
				_ow.show(); _ow.set_process(true); _ow.set_process_input(true))
	else:
		var lines:Array=db.get_gym1_leader().get("lose",[]).duplicate()
		lines.append("Study more and return stronger!")
		_dialog.show_lines(lines,func():
			if _ow and is_instance_valid(_ow):
				_ow.show(); _ow.set_process(true); _ow.set_process_input(true))

func _on_duel(opponent:Dictionary)->void:
	await get_tree().create_timer(0.5).timeout
	if _dialog.is_open(): return
	if _ow: _ow.set_process_input(false); _ow.hide()
	_duel=load("res://scripts/KnowledgeDuel.gd").new()
	_duel.name="Duel"; _duel.connect("duel_ended",_on_duel_ended); add_child(_duel)
	if get_child_count()>1: move_child(_duel,1)
	_duel.setup(GameManager.active_world,opponent)

func _on_duel_ended(won:bool,xp:int)->void:
	if _duel: _duel.queue_free(); _duel=null
	var lines:Array
	if won:
		GameManager.add_xp(xp)
		lines=["You won the Knowledge Duel!","Your mastery is undeniable!","+"+str(xp)+" XP!\nDuel Wins: "+str(GameManager.get_duel_wins())]
	else:
		lines=["You lost the duel...","Study your weak topics and\nchallenge again!","Every loss is a lesson."]
	_dialog.show_lines(lines,func():
		if _ow and is_instance_valid(_ow):
			_ow.show(); _ow.set_process(true); _ow.set_process_input(true))

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F5:
			# Clear save and restart
			if FileAccess.file_exists("user://kq_v3.json"):
				DirAccess.remove_absolute("user://kq_v3.json")
			if FileAccess.file_exists("user://kq_ai.json"):
				DirAccess.remove_absolute("user://kq_ai.json")
			get_tree().reload_current_scene()
		elif event.keycode==KEY_F4:
			if _ow: _ow.hide(); _ow.set_process_input(false)
			if _battle: _battle.queue_free(); _battle=null
			if _duel: _duel.queue_free(); _duel=null
			_show_world_map()

# ═══════════════ Name Entry ═══════════════════════════════════════════════════
class _NameEntry extends Node2D:
	signal name_chosen(n:String)
	var _n:String="Arix"; var _ct:float=0.0; var _cur:bool=true; var _done:bool=false
	const OL:=Color("#181010")

	func _ready()->void: set_process(true); set_process_input(true)

	func _process(delta:float)->void:
		_ct+=delta; if _ct>=0.5: _ct=0.0; _cur=not _cur; queue_redraw()

	func _input(event:InputEvent)->void:
		if _done: return
		if event is InputEventKey and event.pressed:
			var k=event.keycode
			if k==KEY_BACKSPACE and _n.length()>0:
				_n=_n.substr(0,_n.length()-1)
			elif k in [KEY_ENTER,KEY_KP_ENTER]:
				if _n.strip_edges()!="": _done=true; name_chosen.emit(_n.strip_edges())
			elif k>=KEY_A and k<=KEY_Z and _n.length()<10:
				var ch:=char(k)
				_n+=ch.to_upper() if (event.shift_pressed or _n.length()==0) else ch.to_lower()
			elif k==KEY_MINUS and _n.length()>0 and _n.length()<10: _n+="-"

	func _draw()->void:
		const W:=480;const H:=320
		var fnt:=ThemeDB.fallback_font
		# Gen 2 style: light cream background with checker
		draw_rect(Rect2(0,0,W,H),Color("#d8e8d0"))
		for gy in range(0,H,4):
			for gx in range(0,W,4):
				if ((gx/4+gy/4)%2)==0: draw_rect(Rect2(gx,gy,4,4),Color("#c8d8c0"))
		# Central dialog box (Gen 2 style)
		draw_rect(Rect2(60,80,360,160),OL)
		draw_rect(Rect2(61,81,358,158),Color("#f0f8f0"))
		draw_rect(Rect2(61,81,358,18),Color("#4878d0"))
		draw_rect(Rect2(62,82,356,16),Color("#6898e8"))
		# Title
		draw_string(fnt,Vector2(68,96),"What is your name?",
			HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,1,1))
		# Input field
		draw_rect(Rect2(76,112,248,32),OL)
		draw_rect(Rect2(77,113,246,30),Color("#ffffff"))
		draw_rect(Rect2(78,114,244,28),Color("#f8f8f0"))
		draw_string(fnt,Vector2(84,132),_n+("█" if _cur else " "),
			HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#181010"))
		# Player sprite preview
		_draw_mini_player(340,100)
		# Instructions
		draw_string(fnt,Vector2(76,162),"Type your name, then press ENTER",
			HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.3,0.3,0.4))
		draw_string(fnt,Vector2(76,178),"(letters only, max 10 characters)",
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.5,0.5,0.6))
		draw_string(fnt,Vector2(76,198),"Your adventure begins when you confirm!",
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.2,0.4,0.2))

	func _draw_mini_player(ox:int,oy:int)->void:
		var dark:=OL; var skin:=Color("#f8d8a8")
		draw_rect(Rect2(ox+4,oy+36,22,5),Color(0,0,0,0.2))
		draw_rect(Rect2(ox+5,oy+30,9,7),Color("#181888")); draw_rect(Rect2(ox+5,oy+30,9,7),dark,false,1.0)
		draw_rect(Rect2(ox+16,oy+30,9,7),Color("#181888")); draw_rect(Rect2(ox+16,oy+30,9,7),dark,false,1.0)
		draw_rect(Rect2(ox+3,oy+18,24,14),Color("#c01010")); draw_rect(Rect2(ox+3,oy+18,24,4),Color("#e01818"))
		draw_rect(Rect2(ox+3,oy+18,24,14),dark,false,1.0)
		draw_rect(Rect2(ox+0,oy+19,4,12),skin); draw_rect(Rect2(ox+0,oy+19,4,12),dark,false,1.0)
		draw_rect(Rect2(ox+26,oy+19,4,12),skin); draw_rect(Rect2(ox+26,oy+19,4,12),dark,false,1.0)
		draw_rect(Rect2(ox+8,oy+6,14,14),skin); draw_rect(Rect2(ox+8,oy+6,14,14),dark,false,1.0)
		draw_rect(Rect2(ox+6,oy+6,18,6),Color("#c01010")); draw_rect(Rect2(ox+5,oy+9,20,4),Color("#c01010"))
		draw_rect(Rect2(ox+6,oy+6,18,6),dark,false,1.0)
		draw_rect(Rect2(ox+10,oy+13,4,3),dark); draw_rect(Rect2(ox+16,oy+13,4,3),dark)
