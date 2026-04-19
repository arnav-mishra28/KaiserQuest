# SilverMountain.gd — Final Boss Zone
extends Node2D
signal silver_cleared
signal back_to_map

enum Phase { CHECK, STORY, BATTLE, WIN, LOSE, COOLDOWN }
var _phase:int=Phase.CHECK; var _time:float=0.0; var _dialog:Node=null; var _hud:Node=null
var _attempt:int=0; var _particles:Array=[]; var _mtn_rise:float=0.0

func _ready()->void:
	set_process(true); set_process_input(true)
	for i in 40:
		_particles.append({"x":randf()*480,"y":randf()*320,"vx":randf_range(-0.3,0.3),
			"vy":randf_range(-0.6,-0.1),"size":randf_range(1.5,4.0),"alpha":randf(),
			"col":[Color("#c0c8ff"),Color("#ffd700"),Color("#ffffff"),Color("#8899ff")].pick_random()})

func setup(dlg:Node,hud:Node)->void:
	_dialog=dlg; _hud=hud; call_deferred("_check")

func _check()->void:
	if GameManager.silver_on_cooldown():
		var s:=GameManager.silver_cooldown_remaining(); var hrs:=s/3600; var mins:=(s%3600)/60
		if _dialog:
			if "context" in _dialog: _dialog.context="world"
			_dialog.show_lines(["Silver Mountain is sealed...","Cooldown: "+str(hrs)+"h "+str(mins)+"m remaining.","Study your weak topics!","Return when the gate reopens."],func(): back_to_map.emit())
		return
	if not GameManager.can_challenge_silver():
		var lv:=GameManager.get_level(); var bdg:=GameManager.get_badges().size()
		if _dialog:
			if "context" in _dialog: _dialog.context="world"
			_dialog.show_lines(["The Oracle senses you...","But you are not ready.","Need: Level 100 (you: "+str(lv)+"), 20 badges (you: "+str(bdg)+"/20).","Keep learning. Keep growing."],func(): back_to_map.emit())
		return
	_phase=Phase.STORY; _show_story()

func _show_story()->void:
	if _dialog:
		if "context" in _dialog: _dialog.context="world"
		_dialog.show_lines(["Long ago, the world was bright\nwith knowledge and light.",
			"Then the Fog of Forgetting came...",
			"Cities fell silent. Books gathered dust.\nNotes faded from the staff.",
			"One scholar built Silver Mountain\nas a fortress of all knowledge.",
			"At its peak lives the ORACLE —\nguardian of everything ever learned.",
			"Three chances. All 20 badges. Level 100.",
			"You are ready, "+GameManager.player_name+".",
			"Enter Silver Mountain.\n\n  — Press ENTER —"],
			func(): _begin_battle())

func _begin_battle()->void:
	_phase=Phase.BATTLE; _attempt+=1
	var all_q:Array=[]
	for sub_key in SubjectDB._questions.keys():
		all_q.append_array(SubjectDB._questions[sub_key])
	all_q.shuffle()
	var pool:=all_q.slice(0,15)
	var boss:={"name":"The Oracle","title":"Ancient Guardian of All Knowledge",
		"color":Color("#c0c8ff"),"xp_reward":5000,"badge_name":"Kaiser Badge","is_silver":true,
		"questions":pool,"world":GameManager.active_subject+":"+GameManager.active_branch,
		"intro":["The Oracle has waited for you.","15 mixed questions from all subjects.","3 lives. This is your final test.\n\nBegin — attempt "+str(_attempt)+"/3!"],
		"win":["...","It is done.","You have answered the call\nof all knowledge.","★ KAISER ★"],
		"lose":["Not yet...","Return stronger."]}
	AdaptiveAI.start_session(GameManager.active_subject+":"+GameManager.active_branch)
	var b:=Node2D.new(); b.name="OracleBattle"; b.set_script(load("res://scripts/battle/BattleSystem.gd"))
	b.connect("battle_ended",_on_oracle_ended); get_parent().add_child(b)
	b.setup(boss,_dialog); hide()

func _on_oracle_ended(won:bool,_badge:String,xp:int)->void:
	get_parent().get_node_or_null("OracleBattle")?.queue_free(); show()
	if won:
		GameManager.silver_cleared(); GameManager.earn_badge("Kaiser Badge"); GameManager.add_xp(xp)
		_phase=Phase.WIN; silver_cleared.emit()
	else:
		GameManager.silver_attempt_failed()
		if GameManager.silver_on_cooldown():
			if _dialog:
				if "context" in _dialog: _dialog.context="world"
				_dialog.show_lines(["Three failed attempts...","The Oracle seals the gate for 24 hours.","Return tomorrow. Stronger."],func(): back_to_map.emit())
		else:
			var rem:=3-_attempt
			if _dialog:
				if "context" in _dialog: _dialog.context="world"
				_dialog.show_lines(["Defeated...","Attempts remaining: "+str(rem),"Study your weak topics and return!"],
					func(): if rem>0: _begin_battle() else: back_to_map.emit())

func _process(delta:float)->void:
	_time+=delta; _mtn_rise=minf(_mtn_rise+delta*0.4,1.0)
	for p in _particles:
		p.x+=p.vx; p.y+=p.vy; p.alpha=fmod(p.alpha+delta*0.3,1.0)
		if p.y<-10: p.y=330.0; p.x=randf()*480.0
	queue_redraw()

func _draw()->void:
	const W:=480.0;const H:=320.0; var fnt:=ThemeDB.fallback_font
	var ease:=_mtn_rise*_mtn_rise*(3.0-2.0*_mtn_rise)
	for sy in range(0,int(H),4):
		var t:=float(sy)/H; draw_rect(Rect2(0,sy,W,4),Color(0.02+t*0.04,0.01+t*0.04,0.08+t*0.12,ease))
	for si in 60:
		var sx:=float((si*71+13)%480); var sy:=float((si*47+7)%200)
		var tw:=0.3+0.7*sin(_time*1.2+si*0.6)
		draw_rect(Rect2(sx,sy,2 if si%4==0 else 1,2 if si%4==0 else 1),Color(1,1,1,tw*ease))
	draw_rect(Rect2(0,200,W,H-200),Color(0.05,0.02,0.12,0.3*ease))
	var mtn_y:=H-(H-60)*ease; var m1:=Color(0.10,0.08,0.20,ease)
	draw_colored_polygon(PackedVector2Array([Vector2(0,H),Vector2(80,mtn_y+60),Vector2(180,H)]),PackedColorArray([m1,m1,m1]))
	draw_colored_polygon(PackedVector2Array([Vector2(120,H),Vector2(240,mtn_y-20),Vector2(380,H)]),PackedColorArray([m1.lightened(0.05),m1.lightened(0.05),m1.lightened(0.05)]))
	draw_colored_polygon(PackedVector2Array([Vector2(280,H),Vector2(400,mtn_y+40),Vector2(480,H)]),PackedColorArray([m1,m1,m1]))
	var sp:=Color(0.55,0.60,0.90,ease)
	draw_colored_polygon(PackedVector2Array([Vector2(200,H),Vector2(240,mtn_y),Vector2(280,H)]),PackedColorArray([sp,sp,sp]))
	var snow:=Color(0.92,0.95,1.0,ease)
	draw_colored_polygon(PackedVector2Array([Vector2(228,mtn_y+20),Vector2(240,mtn_y),Vector2(252,mtn_y+20)]),PackedColorArray([snow,snow,snow]))
	var glow_a:=0.4+0.3*sin(_time*2.0)
	draw_rect(Rect2(234,mtn_y-6,12,6),Color(0.8,0.85,1.0,glow_a*ease))
	for p in _particles:
		draw_rect(Rect2(p.x,p.y,p.size,p.size),Color(p.col.r,p.col.g,p.col.b,p.alpha*ease*0.7))
	if ease>0.5:
		var ta:=(ease-0.5)*2.0
		draw_string(fnt,Vector2(154,44),"SILVER MOUNTAIN",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.75,0.78,1.0,ta))
		draw_string(fnt,Vector2(134,64),"The Oracle Awaits",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1.0,0.84,0.0,ta*0.8))
		if _attempt>0:
			var dots:=""; for i in 3: dots+="●" if i<_attempt else "○"
			draw_rect(Rect2(4,4,120,16),Color(0,0,0,0.6))
			draw_string(fnt,Vector2(8,16),"Attempts: "+dots,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.75,0.78,1.0,ta))
