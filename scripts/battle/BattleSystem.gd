# BattleSystem.gd — Gen 1/2 Knowledge Battle (no nested functions)
extends Node2D
signal battle_ended(won: bool, badge_name: String, xp_earned: int)

enum Phase { INTRO, MENU, ANSWERING, RESULT, ENDED }
var _gym:       Dictionary = {}
var _qs:        Array      = []
var _qi:        int        = 0
var _sel:       int        = 0
var _phase:     int        = Phase.INTRO
var _p_hp:      int        = 0;  var _p_max:  int   = 0
var _e_hp:      int        = 0;  var _e_max:  int   = 0
var _p_hp_d:    float      = 0.0; var _e_hp_d:float = 0.0
var _flash_t:   float      = 0.0
var _flash_col: Color      = Color.TRANSPARENT
var _glow_t:    float      = 0.0
var _shake_t:   float      = 0.0
var _result:    String     = ""
var _explain:   String     = ""
var _acols:     Array      = []
var _score:     int        = 0
var _combo:     int        = 0
var _time:      float      = 0.0
var _hint_used: bool       = false
var _hint_text: String     = ""
var _show_hint: bool       = false
var _dialog:    Node       = null
var _menu_sel:  int        = 0
var _in_answer: bool       = false
# Avatar animation
var _p_attack_t: float     = 0.0
var _e_hurt_t:   float     = 0.0
var _p_hurt_t:   float     = 0.0
var _p_victory:  bool      = false

const BG1:=Color("#e8e8d0"); const BG2:=Color("#d8d8c0")
const BOX:=Color("#f8f8f0"); const DK:=Color("#181010")
const HP_G:=Color("#50d030"); const HP_Y:=Color("#f8c800"); const HP_R:=Color("#e82020")
const HP_BK:=Color("#282828"); const GLOW_C:=Color("#f8e000")

func setup(gym_data: Dictionary, dialog_node: Node) -> void:
	_gym=gym_data; _qs=gym_data.get("questions",[]); _dialog=dialog_node
	_qi=0; _sel=0; _score=0; _combo=0; _phase=Phase.INTRO; _menu_sel=0; _in_answer=false
	_hint_used=false; _hint_text=""; _show_hint=false
	_acols=[BOX,BOX,BOX,BOX]
	_p_hp=GameManager.get_hp(); _p_max=GameManager.get_max_hp()
	_p_hp_d=float(_p_hp)
	_e_max=18+GameManager.get_level()*2; _e_hp=_e_max; _e_hp_d=float(_e_max)
	set_process(true); set_process_input(false)
	call_deferred("_start_intro")

func _start_intro() -> void:
	if _dialog and _dialog.has_method("show_lines"):
		if "context" in _dialog: _dialog.context="battle"
		_dialog.show_lines(_gym.get("intro",["Battle start!"]), func():
			_phase=Phase.MENU; set_process_input(true))

func _input(ev: InputEvent) -> void:
	match _phase:
		Phase.MENU: _menu_input(ev)
		_: pass

func _menu_input(ev: InputEvent) -> void:
	if not _in_answer:
		if ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_left"):
			_menu_sel=max(0,_menu_sel-1); queue_redraw()
		elif ev.is_action_pressed("ui_down") or ev.is_action_pressed("ui_right"):
			_menu_sel=min(2,_menu_sel+1); queue_redraw()
		elif ev.is_action_pressed("ui_accept"):
			match _menu_sel:
				0: _in_answer=true; _sel=0; queue_redraw()
				1: _use_hint()
				2: _skip()
			ev.get_viewport().set_input_as_handled()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index==MOUSE_BUTTON_LEFT:
			var mi:=_hit_menu(ev.position)
			if mi>=0:
				match mi:
					0: _in_answer=true; _sel=0; queue_redraw()
					1: _use_hint()
					2: _skip()
		elif ev is InputEventMouseMotion:
			var mi:=_hit_menu(ev.position)
			if mi>=0 and mi!=_menu_sel: _menu_sel=mi; queue_redraw()
	else:
		var opts:=_qs[_qi].get("opts",[]) if _qi<_qs.size() else []
		if ev.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
		elif ev.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
		elif ev.is_action_pressed("ui_accept"): _submit(); ev.get_viewport().set_input_as_handled()
		elif ev.is_action_pressed("ui_cancel"): _in_answer=false; queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index==MOUSE_BUTTON_LEFT:
			var idx:=_hit_answer(ev.position)
			if idx>=0: _sel=idx; _submit()
		elif ev is InputEventMouseMotion:
			var idx:=_hit_answer(ev.position)
			if idx>=0 and idx!=_sel: _sel=idx; queue_redraw()

func _hit_menu(pos: Vector2) -> int:
	const W:=480; const H:=320; const MY:=166
	for mi in 3:
		var iy:=MY+8+mi*22
		if pos.x>=W/2+8 and pos.x<=W-8 and pos.y>=iy and pos.y<=iy+22: return mi
	return -1

func _hit_answer(pos: Vector2) -> int:
	const W:=480; const H:=320; const MY:=166
	var rw:=W/2-2
	for i in 4:
		var row:=i/2; var col:=i%2
		var ox2:=W/2+8+col*(rw/2-4)
		var oy2:=MY+14+row*((H-MY-8)/2)
		var bw:=rw/2-8; var bh:=(H-MY-10)/2-4
		if pos.x>=ox2 and pos.x<=ox2+bw and pos.y>=oy2 and pos.y<=oy2+bh: return i
	return -1

func _use_hint() -> void:
	if _hint_used: _hint_text="Hint already used!"
	else:
		_hint_used=true; var q:=_qs[_qi]; var opts:=q.get("opts",[]); var ans:=int(q.get("ans",0))
		_hint_text="Hint: Answer begins with\n'"+(opts[ans].substr(0,4) if opts.size()>ans else "?")+"...'"
	_show_hint=true; queue_redraw()

func _skip() -> void:
	_hint_used=false; _show_hint=false; _combo=0
	_acols=[BOX,BOX,BOX,BOX]; _qi+=1
	if _qi>=_qs.size(): _end(_e_hp<_p_hp)
	else: _sel=0; _menu_sel=0; _in_answer=false; queue_redraw()

func _submit() -> void:
	_phase=Phase.ANSWERING; set_process_input(false)
	var q:=_qs[_qi]; var ok:=(int(q.get("ans",0))==_sel)
	_explain=q.get("explain",""); _hint_used=false; _show_hint=false
	_acols=[BOX,BOX,BOX,BOX]
	var key:=GameManager.active_subject+":"+GameManager.active_branch
	AdaptiveAI.record_answer(q.get("topic","general"),ok)
	if ok:
		_acols[_sel]=HP_G; _combo+=1
		_result="Super effective!"+((" Combo x"+str(_combo)+"!") if _combo>1 else "")
		_e_hp=max(0,_e_hp-5*(1+min(_combo-1,2)))
		_glow_t=0.8; _score=mini(_score+int(100.0/_qs.size()),100)
		_flash_col=Color(GLOW_C,0.3)
		_p_attack_t=0.5; _e_hurt_t=0.4
	else:
		_acols[_sel]=HP_R; _acols[int(q.get("ans",0))]=HP_G; _combo=0
		_result="Not very effective..."; _p_hp=max(0,_p_hp-6)
		GameManager.take_damage(6); _shake_t=0.5; _flash_col=Color(HP_R,0.2)
		_p_hurt_t=0.4
	_flash_t=0.0; queue_redraw()

func _process(delta: float) -> void:
	_time+=delta
	_p_hp_d=lerp(_p_hp_d,float(_p_hp),delta*4.0)
	_e_hp_d=lerp(_e_hp_d,float(_e_hp),delta*4.0)
	_glow_t=max(0.0,_glow_t-delta)
	_shake_t=max(0.0,_shake_t-delta)
	_p_attack_t=max(0.0,_p_attack_t-delta)
	_e_hurt_t=max(0.0,_e_hurt_t-delta)
	_p_hurt_t=max(0.0,_p_hurt_t-delta)
	if _phase==Phase.ANSWERING:
		_flash_t+=delta
		if _flash_t>=2.2: _after()
	queue_redraw()

func _after() -> void:
	_result=""; _explain=""; _flash_col=Color.TRANSPARENT; _acols=[BOX,BOX,BOX,BOX]; _flash_t=0.0
	if _e_hp<=0: _end(true); return
	if _p_hp<=0: _end(false); return
	_qi+=1
	if _qi>=_qs.size(): _end(_e_hp<_p_hp); return
	_sel=0; _in_answer=false; _menu_sel=0; _hint_used=false; _show_hint=false
	_phase=Phase.MENU; set_process_input(true); queue_redraw()

func _end(won: bool) -> void:
	_phase=Phase.ENDED; set_process_input(false)
	if won: _p_victory=true
	AdaptiveAI.end_session()
	GameManager.set_best_score(_gym.get("badge_name","gym"),_score)
	battle_ended.emit(won,_gym.get("badge_name",""),_gym.get("xp_reward",200) if won else 0)

func _draw() -> void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font
	var q:=_qs[_qi] if _qi<_qs.size() else {}
	var wcol:Color=_gym.get("color",Color("#2060d0"))
	var shake_x:=0; var shake_y:=0
	if _shake_t>0.0:
		shake_x=int(randf_range(-4,4)*_shake_t); shake_y=int(randf_range(-2,2)*_shake_t)

	# Background
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG2 if ((gx/4+gy/4)%2)==0 else BG1)
	draw_rect(Rect2(0,H/2,W,4),DK)
	draw_rect(Rect2(0,H/2+4,W,H/2-4),BOX)

	# Platforms
	_draw_platform(W-220+shake_x,55,120,false)
	_draw_platform(10+shake_x,100,110,true)

	# AVATAR — Enemy (front, top-right)
	_draw_enemy_avatar(W-185+shake_x, 8+shake_y, wcol)

	# AVATAR — Player (back, bottom-left)
	_draw_player_avatar(40+shake_x, 62+shake_y)

	# HP Boxes
	_draw_hp_box(6,6,230,_gym.get("name","???"),_gym.get("title",""),int(_e_hp_d),_e_max,GameManager.get_level()+2,wcol,true,fnt)
	_draw_hp_box(W-240,H/2-62,234,GameManager.player_name,"",int(_p_hp_d),_p_max,GameManager.get_level(),wcol,false,fnt)

	# Battle menu
	var my:=H/2+6
	if _phase in [Phase.MENU,Phase.ANSWERING,Phase.RESULT]:
		_draw_menu(my,W,H,q,fnt,wcol)

	# Score bar
	draw_rect(Rect2(0,H-4,W,4),DK); draw_rect(Rect2(1,H-3,W-2,2),HP_BK)
	draw_rect(Rect2(1,H-3,int((W-2)*float(_score)/100.0),2),wcol)

	# Glow effect
	if _glow_t>0.0:
		var ga:=_glow_t*0.5
		draw_rect(Rect2(0,0,W,H/2),Color(GLOW_C.r,GLOW_C.g,GLOW_C.b,ga*0.3))
		for i in 8:
			var angle:=float(i)/8.0*TAU
			var length:=50.0*(1.0-_glow_t)
			draw_line(Vector2(W-165,40),Vector2(W-165+cos(angle)*length,40+sin(angle)*length),Color(GLOW_C,ga*1.5),2.5)

	# Flash
	if _phase==Phase.ANSWERING and _flash_t>0.0 and _flash_col.a>0.01:
		var fa:=maxf(0.0,_flash_col.a-_flash_t*0.12)
		draw_rect(Rect2(0,0,W,H),Color(_flash_col.r,_flash_col.g,_flash_col.b,fa))

func _draw_platform(px:int,py:int,pw:int,is_player:bool)->void:
	var pc:=Color("#b0a060") if is_player else Color("#a09060")
	draw_rect(Rect2(px-8,py+12,pw+16,10),pc.darkened(0.3))
	draw_rect(Rect2(px-12,py+14,pw+24,8),pc)
	draw_rect(Rect2(px-14,py+16,pw+28,5),pc.lightened(0.15))

func _draw_hp_box(bx:int,by:int,bw:int,name:String,title:String,hp:int,max_hp:int,lv:int,wcol:Color,is_enemy:bool,fnt:Font)->void:
	var bh:=52
	draw_rect(Rect2(bx,by,bw,bh),DK); draw_rect(Rect2(bx+2,by+2,bw-4,bh-4),BOX)
	draw_rect(Rect2(bx+2,by+2,bw-4,bh-4),DK,false,1.5)
	draw_rect(Rect2(bx+2,by+2,bw-4,14),Color(wcol.r*0.25,wcol.g*0.25,wcol.b*0.4))
	draw_string(fnt,Vector2(bx+7,by+13),name.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DK)
	draw_string(fnt,Vector2(bx+bw-48,by+13),":Lv"+str(lv),HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
	var hp_f:=float(hp)/float(max(max_hp,1))
	var hcol:=HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
	draw_string(fnt,Vector2(bx+7,by+28),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
	var bx2:=bx+28; var bw2:=bw-36; var by2:=by+22
	draw_rect(Rect2(bx2,by2,bw2,8),DK); draw_rect(Rect2(bx2+1,by2+1,bw2-2,6),HP_BK)
	draw_rect(Rect2(bx2+1,by2+1,int((bw2-2)*hp_f),6),hcol)
	if not is_enemy:
		draw_string(fnt,Vector2(bx+bw-78,by+43),str(hp)+"/"+str(max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
		var xp_f:=float(GameManager.get_xp())/float(GameManager.get_xp_max())
		draw_rect(Rect2(bx+2,by+bh-6,bw-4,4),DK); draw_rect(Rect2(bx+3,by+bh-5,bw-6,2),HP_BK)
		draw_rect(Rect2(bx+3,by+bh-5,int((bw-6)*xp_f),2),Color("#6898f0"))
	if is_enemy and not title.is_empty():
		draw_string(fnt,Vector2(bx+7,by+43),title.left(30),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.4,0.5))

func _draw_menu(my:int,W:int,H:int,q:Dictionary,fnt:Font,wcol:Color)->void:
	var lw:=W/2-2; var rw:=W/2-2
	draw_rect(Rect2(2,my,lw,H-my-4),DK); draw_rect(Rect2(4,my+2,lw-4,H-my-8),BOX)
	draw_rect(Rect2(4,my+2,lw-4,H-my-8),DK,false,1.5)
	if _result!="":
		var rc:=HP_G if _result.begins_with("Super") else HP_R
		draw_string(fnt,Vector2(10,my+18),_result.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,rc)
		if _explain!="":
			var exl:=_explain.split("\n")
			for ei in exl.size(): draw_string(fnt,Vector2(10,my+36+ei*16),exl[ei],HORIZONTAL_ALIGNMENT_LEFT,lw-10,11,DK)
	elif _show_hint:
		for hl in _hint_text.split("\n"): draw_string(fnt,Vector2(10,my+18),hl.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,DK)
	else:
		for li in q.get("q","...").split("\n"): draw_string(fnt,Vector2(10,my+16),li.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,DK)
	draw_rect(Rect2(W/2+2,my,rw-4,H-my-4),DK); draw_rect(Rect2(W/2+4,my+2,rw-8,H-my-8),BOX)
	draw_rect(Rect2(W/2+4,my+2,rw-8,H-my-8),DK,false,1.5)
	if not _in_answer:
		for mi in ["FIGHT","HINT","SKIP"].size():
			var item_y:=my+18+mi*22; var sel:=(_menu_sel==mi and _phase==Phase.MENU)
			if sel:
				draw_colored_polygon(PackedVector2Array([Vector2(W/2+12,item_y-10),Vector2(W/2+18,item_y-5),Vector2(W/2+12,item_y)]),PackedColorArray([DK,DK,DK]))
			draw_string(fnt,Vector2(W/2+24,item_y),["FIGHT","HINT","SKIP"][mi],HORIZONTAL_ALIGNMENT_LEFT,-1,14,DK)
		draw_string(fnt,Vector2(W/2+10,H-my-18),"SCORE:"+str(_score)+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.4,0.4,0.5))
	else:
		var opts:=q.get("opts",[])
		for i in opts.size():
			var row:=i/2; var col2:=i%2
			var ox2:=W/2+8+col2*(rw/2-4); var oy2:=my+14+row*((H-my-8)/2)
			var bw2:=rw/2-8; var bh2:=(H-my-10)/2-4
			var bg:=_acols[i] if i<_acols.size() else BOX; var sel2:=(i==_sel and _phase==Phase.MENU)
			draw_rect(Rect2(ox2,oy2,bw2,bh2),DK); draw_rect(Rect2(ox2+2,oy2+2,bw2-4,bh2-4),bg)
			if sel2: draw_rect(Rect2(ox2+2,oy2+2,bw2-4,bh2-4),wcol*Color(1,1,1,0.25))
			if sel2:
				draw_colored_polygon(PackedVector2Array([Vector2(ox2+4,oy2+8),Vector2(ox2+10,oy2+13),Vector2(ox2+4,oy2+18)]),PackedColorArray([DK,DK,DK]))
			draw_string(fnt,Vector2(ox2+14,oy2+16),["A","B","C","D"][i]+". "+opts[i],HORIZONTAL_ALIGNMENT_LEFT,bw2-20,11,DK)

func _draw_player_avatar(ox: int, oy: int) -> void:
	var DK:=Color("#181010"); var SKN:=Color("#f0c890")
	var att:=_p_attack_t; var hrt:=_p_hurt_t
	var ax:=int(sin(att*12.0)*8.0) if att>0 else 0
	var hx:=int(sin(hrt*20.0)*5.0) if hrt>0 else 0
	var bob:=int(sin(_time*2.0)*2.0)
	var px:=ox+ax+hx; var py:=oy+bob
	draw_rect(Rect2(px+4,py+44,26,6),Color(0,0,0,0.2))
	draw_rect(Rect2(px+6,py+38,9,8),Color("#181888")); draw_rect(Rect2(px+6,py+38,9,8),DK,false,1.0)
	draw_rect(Rect2(px+19,py+38,9,8),Color("#181888")); draw_rect(Rect2(px+19,py+38,9,8),DK,false,1.0)
	draw_rect(Rect2(px+4,py+22,26,18),Color("#c01010"))
	draw_rect(Rect2(px+4,py+22,26,5),Color("#e01818")); draw_rect(Rect2(px+4,py+22,26,18),DK,false,1.0)
	for ax2 in [0,29]:
		draw_rect(Rect2(px+ax2,py+23,5,14),SKN); draw_rect(Rect2(px+ax2,py+23,5,14),DK,false,1.0)
	draw_rect(Rect2(px+9,py+8,16,16),SKN); draw_rect(Rect2(px+9,py+8,16,16),DK,false,1.0)
	draw_rect(Rect2(px+7,py+8,20,6),Color("#c01010")); draw_rect(Rect2(px+6,py+11,22,5),Color("#c01010"))
	draw_rect(Rect2(px+7,py+8,20,6),DK,false,1.0); draw_rect(Rect2(px+14,py+9,5,4),Color("#ffd700"))
	draw_rect(Rect2(px+11,py+15,3,3),DK); draw_rect(Rect2(px+18,py+15,3,3),DK)
	if _p_victory:
		draw_rect(Rect2(px+28,py+8,6,16),SKN); draw_rect(Rect2(px+28,py+8,6,16),DK,false,1.0)
	if att>0:
		var ec:=_gym.get("color",Color("#44aaff"))
		draw_circle(Vector2(float(px)+36,float(py)+30),(8+(0.5-att)*20),Color(ec.r,ec.g,ec.b,att*1.5))

func _draw_enemy_avatar(ox: int, oy: int, col: Color) -> void:
	var DK:=Color("#181010"); var SKN:=Color("#f0c890")
	var hrt:=_e_hurt_t
	var hx:=int(sin(hrt*22.0)*6.0) if hrt>0 else 0
	var bob:=int(sin(_time*1.6)*2.0)
	var px:=ox+hx; var py:=oy+bob
	var pulse:=0.5+0.5*sin(_time*2.5)
	draw_rect(Rect2(px+5,py+54,9,5),DK); draw_rect(Rect2(px+22,py+54,9,5),DK)
	draw_rect(Rect2(px+6,py+38,8,18),Color("#181888")); draw_rect(Rect2(px+6,py+38,8,18),DK,false,1.0)
	draw_rect(Rect2(px+21,py+38,8,18),Color("#181888")); draw_rect(Rect2(px+21,py+38,8,18),DK,false,1.0)
	draw_rect(Rect2(px+4,py+20,28,20),col.lightened(0.4))
	draw_rect(Rect2(px+4,py+20,28,6),Color(1,1,1,0.25))
	draw_rect(Rect2(px+4,py+20,28,20),DK,false,1.0)
	draw_rect(Rect2(px+13,py+22,10,18),Color("#e8e8e8")); draw_rect(Rect2(px+16,py+24,4,16),col)
	for ax2 in [0,31]:
		draw_rect(Rect2(px+ax2,py+21,5,14),SKN); draw_rect(Rect2(px+ax2,py+21,5,14),DK,false,1.0)
	draw_rect(Rect2(px+9,py+8,18,14),SKN); draw_rect(Rect2(px+9,py+8,18,14),DK,false,1.0)
	draw_rect(Rect2(px+9,py+8,18,5),Color("#9898a0"))
	draw_rect(Rect2(px+10,py+14,7,5),DK,false,1.5); draw_rect(Rect2(px+21,py+14,7,5),DK,false,1.5)
	draw_rect(Rect2(px+17,py+16,4,1),DK)
	draw_rect(Rect2(px+12,py+15,3,3),Color("#88c8ff")); draw_rect(Rect2(px+23,py+15,3,3),Color("#88c8ff"))
	# Orbiting knowledge orbs
	for i in 3:
		var angle:=_time*1.5+i*TAU/3.0
		var rx:=px+19+int(cos(angle)*22); var ry:=py+28+int(sin(angle)*14)
		draw_rect(Rect2(rx,ry,5,5),Color(col.r,col.g,col.b,0.6+0.4*sin(_time*2+i)))
