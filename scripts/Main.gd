# Main.gd v0.5 — Master coordinator
extends Node

var _title:Node2D=null; var _wmap:Node2D=null; var _ow:Node2D=null
var _battle:Node2D=null; var _duel:Node2D=null; var _name:Node2D=null
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
	if GameManager.player_name not in ["Arix",""]: _show_wmap()
	else: _show_name()

func _show_name()->void:
	_name=_NameEntry.new(); _name.name="NameEntry"
	_name.connect("name_chosen",_on_named); add_child(_name)
func _on_named(n:String)->void:
	GameManager.player_name=n; _name.queue_free(); _name=null; _show_wmap()

func _show_wmap()->void:
	if _ow: _ow.hide(); _ow.set_process_input(false)
	if _wmap==null:
		_wmap=load("res://scripts/WorldMap.gd").new()
		_wmap.name="WorldMap"; _wmap.add_to_group("overworld")
		_wmap.connect("enter_zone",_on_zone); _wmap.connect("show_dialog",_on_wmap_dlg)
		add_child(_wmap); move_child(_wmap,0)
	_wmap.show(); _wmap.set_process(true); _wmap.set_process_input(true)

func _on_wmap_dlg(lines:Array)->void:
	if _wmap: _wmap.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _wmap and is_instance_valid(_wmap): _wmap.set_process(true); _wmap.set_process_input(true))

func _on_zone(zone_id:String)->void:
	if _wmap: _wmap.hide(); _wmap.set_process_input(false)
	GameManager.active_world=zone_id; _show_ow(zone_id)

func _show_ow(wid:String)->void:
	if _ow==null:
		_ow=load("res://scripts/Overworld.gd").new()
		_ow.name="Overworld"; _ow.add_to_group("overworld")
		_ow.connect("show_dialog",_on_ow_dlg)
		_ow.connect("start_gym_battle",_on_gym)
		_ow.connect("gain_xp",_on_xp)
		_ow.connect("start_duel",_on_duel)
		_ow.connect("back_to_world_map",_on_back)
		add_child(_ow); move_child(_ow,0)
	_ow.init_world(wid); _ow.show(); _ow.set_process(true); _ow.set_process_input(true)

func _on_ow_dlg(lines:Array)->void:
	if _ow: _ow.set_process_input(false)
	_dialog.show_lines(lines,func():
		if _ow and is_instance_valid(_ow): _ow.set_process(true); _ow.set_process_input(true))

func _on_back()->void:
	if _ow: _ow.hide(); _ow.set_process_input(false); _show_wmap()

func _on_xp(amt:int,_ctx:String)->void:
	GameManager.add_xp(amt); _hud.show_xp_gain(amt)

func _on_gym(gym_data:Dictionary)->void:
	if _ow: _ow.set_process_input(false); _ow.hide()
	_battle=load("res://scripts/BattleScene.gd").new()
	_battle.name="Battle"; _battle.connect("battle_ended",_on_battle_done)
	add_child(_battle); if get_child_count()>1: move_child(_battle,1)
	_battle.setup(gym_data)

func _on_battle_done(won:bool,badge_name:String,xp:int)->void:
	if _battle: _battle.queue_free(); _battle=null
	var world:=GameManager.active_world
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db=db_map.get(world,AlgebraDB)
	if won:
		GameManager.add_xp(xp); GameManager.earn_badge(badge_name)
		var lines:Array=db.get_gym1_leader().get("win",[]).duplicate()
		lines.append("★ "+badge_name+" earned! ★\n\n+"+str(xp)+" XP!")
		_dialog.show_lines(lines,func(): _resume_ow())
	else:
		var lines:Array=db.get_gym1_leader().get("lose",[]).duplicate()
		lines.append("Study lessons with the Teachers\nand return stronger!")
		_dialog.show_lines(lines,func(): _resume_ow())

func _resume_ow()->void:
	if _ow and is_instance_valid(_ow): _ow.show(); _ow.set_process(true); _ow.set_process_input(true)

func _on_duel(opp:Dictionary)->void:
	await get_tree().create_timer(0.5).timeout
	if _dialog.is_open(): return
	if _ow: _ow.set_process_input(false); _ow.hide()
	_duel=load("res://scripts/KnowledgeDuel.gd").new()
	_duel.name="Duel"; _duel.connect("duel_ended",_on_duel_done)
	add_child(_duel); if get_child_count()>1: move_child(_duel,1)
	_duel.setup(GameManager.active_world,opp)

func _on_duel_done(won:bool,xp:int)->void:
	if _duel: _duel.queue_free(); _duel=null
	var lines:Array
	if won:
		GameManager.add_xp(xp)
		lines=["Duel Victory!","Your knowledge is undeniable!","+"+str(xp)+" XP!\nDuel Wins: "+str(GameManager.get_duel_wins())]
	else:
		lines=["Duel lost...","Study your weak topics\nand challenge again!"]
	_dialog.show_lines(lines,func(): _resume_ow())

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_F5:
			GameManager.reset_all()
			for fn in ["user://kq_v5.json","user://kq_ai.json"]:
				if FileAccess.file_exists(fn): DirAccess.remove_absolute(fn)
			get_tree().reload_current_scene()
		elif event.keycode==KEY_F4:
			if _battle: _battle.queue_free(); _battle=null
			if _duel: _duel.queue_free(); _duel=null
			if _ow: _ow.hide(); _ow.set_process_input(false)
			_show_wmap()

# ══════════════ Name Entry ═════════════════════════════════════════════════════
class _NameEntry extends Node2D:
	signal name_chosen(n:String)
	var _n:String="Arix"; var _ct:float=0.0; var _cur:bool=true; var _done:bool=false
	func _ready()->void: set_process(true); set_process_input(true)
	func _process(d:float)->void: _ct+=d; if _ct>=0.5: _ct=0.0; _cur=not _cur; queue_redraw()
	func _input(event:InputEvent)->void:
		if _done: return
		if event is InputEventKey and event.pressed:
			var k=event.keycode
			if k==KEY_BACKSPACE and _n.length()>0: _n=_n.substr(0,_n.length()-1)
			elif k in [KEY_ENTER,KEY_KP_ENTER]:
				if _n.strip_edges()!="": _done=true; name_chosen.emit(_n.strip_edges())
			elif k>=KEY_A and k<=KEY_Z and _n.length()<10:
				var ch:=char(k)
				_n+=ch.to_upper() if (event.shift_pressed or _n.length()==0) else ch.to_lower()
	func _draw()->void:
		const W:=480;const H:=320; var fnt:=ThemeDB.fallback_font; var dk:=Color("#181010")
		# Gen 2 green checkered bg
		for gy in range(0,H,4):
			for gx in range(0,W,4):
				draw_rect(Rect2(gx,gy,4,4),Color("#58a030") if ((gx/4+gy/4)%2)==0 else Color("#489028"))
		# Dialog box (Gen 2 style)
		draw_rect(Rect2(60,85,360,150),dk); draw_rect(Rect2(61,86,358,148),Color("#f0f8f0"))
		draw_rect(Rect2(61,86,358,16),Color("#2060a0")); draw_rect(Rect2(62,87,356,14),Color("#3878c0"))
		draw_string(fnt,Vector2(70,100),"What is your name?",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#f0f8ff"))
		# Input box
		draw_rect(Rect2(78,116,244,30),dk); draw_rect(Rect2(79,117,242,28),Color("#ffffff"))
		draw_string(fnt,Vector2(86,135),_n+("█" if _cur else " "),HORIZONTAL_ALIGNMENT_LEFT,-1,18,dk)
		draw_string(fnt,Vector2(70,162),"Type your name, then press ENTER",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.3,0.3,0.4))
		draw_string(fnt,Vector2(70,177),"(letters only, max 10 chars)",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.5,0.5,0.6))
		draw_string(fnt,Vector2(70,196),"Your journey to become Kaiser begins!",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#106030"))
		# Mini player preview
		_draw_p(340,100)
	func _draw_p(ox:int,oy:int)->void:
		var dk:=Color("#181010"); var skin:=Color("#f0c890")
		draw_rect(Rect2(ox+5,oy+36,22,5),Color(0,0,0,0.2))
		draw_rect(Rect2(ox+5,oy+28,10,9),Color("#181888")); draw_rect(Rect2(ox+5,oy+28,10,9),dk,false,1.0)
		draw_rect(Rect2(ox+17,oy+28,10,9),Color("#181888")); draw_rect(Rect2(ox+17,oy+28,10,9),dk,false,1.0)
		draw_rect(Rect2(ox+3,oy+16,26,14),Color("#c01010")); draw_rect(Rect2(ox+3,oy+16,26,4),Color("#e01818"))
		draw_rect(Rect2(ox+3,oy+16,26,14),dk,false,1.0)
		draw_rect(Rect2(ox+0,oy+17,4,12),skin); draw_rect(Rect2(ox+0,oy+17,4,12),dk,false,1.0)
		draw_rect(Rect2(ox+28,oy+17,4,12),skin); draw_rect(Rect2(ox+28,oy+17,4,12),dk,false,1.0)
		draw_rect(Rect2(ox+9,oy+4,14,14),skin); draw_rect(Rect2(ox+9,oy+4,14,14),dk,false,1.0)
		draw_rect(Rect2(ox+7,oy+4,18,6),Color("#c01010")); draw_rect(Rect2(ox+6,oy+7,20,5),Color("#c01010"))
		draw_rect(Rect2(ox+7,oy+4,18,6),dk,false,1.0); draw_rect(Rect2(ox+14,oy+5,5,4),Color("#ffd700"))
		draw_rect(Rect2(ox+11,oy+11,4,3),dk); draw_rect(Rect2(ox+17,oy+11,4,3),dk)
