# BattleScene.gd v0.3 — Knowledge Battle with adaptive AI tracking
extends Node2D

signal battle_ended(won:bool, badge_name:String, xp:int)

var _gym:Dictionary={}; var _qs:Array=[]; var _qi:int=0
var _lives:int=3; var _sel:int=0; var _locked:bool=false; var _over:bool=false
var _flash_t:float=0.0; var _flash_c:Color=Color.TRANSPARENT
var _result:String=""; var _explain:String=""; var _acols:Array=[]
var _time:float=0.0; var _report:Dictionary={}

const C_TEXT:=Color("#e8e8e8"); const C_GOLD:=Color("#ffd700")
const C_OK:=Color("#0a4a0a"); const C_BAD:=Color("#4a0a0a"); const C_NORM:=Color("#0e1e0e")

func setup(gym_data:Dictionary)->void:
	_gym=gym_data; _qs=gym_data.get("questions",[]); _qi=0
	_lives=3; _sel=0; _over=false; _reset_acols()
	set_process(true); set_process_input(false); _locked=true
	call_deferred("_show_intro")

func _show_intro()->void:
	var dlg:=get_tree().get_first_node_in_group("dialog_box")
	if dlg: dlg.show_lines(_gym.get("intro",["Ready?"]),func(): _locked=false; set_process_input(true))

func _input(event:InputEvent)->void:
	if _over or _locked: return
	var opts:=_qs[_qi].opts
	if event.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_accept"): _submit(); get_viewport().set_input_as_handled()

func _submit()->void:
	_locked=true; var q:=_qs[_qi]; var ok:=(q.ans==_sel)
	_explain=q.get("explain",""); _reset_acols()
	AdaptiveAI.record_answer(q.get("topic","general"), ok)
	if ok:
		_acols[_sel]=C_OK; _result="Correct!"
		_flash_c=Color(0.0,1.0,0.0,0.16)
	else:
		_acols[_sel]=C_BAD; _acols[q.ans]=C_OK
		_result="Wrong!  Correct: "+_letters(q.ans)
		_flash_c=Color(1.0,0.0,0.0,0.16); _lives-=1
	_flash_t=1.8; queue_redraw()

func _process(delta:float)->void:
	_time+=delta
	if _flash_t>0.0:
		_flash_t-=delta
		if _flash_t<=0.0: _after_answer()
	queue_redraw()

func _after_answer()->void:
	_result=""; _explain=""; _flash_c=Color.TRANSPARENT; _reset_acols()
	if _lives<=0: _end(false); return
	_qi+=1
	if _qi>=_qs.size(): _end(true); return
	_sel=0; _locked=false; queue_redraw()

func _end(won:bool)->void:
	_over=true; _locked=true; set_process_input(false)
	_report=AdaptiveAI.end_session()
	battle_ended.emit(won, _gym.get("badge_name",""), _gym.get("xp_reward",100) if won else 0)

func _reset_acols()->void: _acols=[C_NORM,C_NORM,C_NORM,C_NORM]
func _letters(i:int)->String: return ["A","B","C","D"][i] if i<4 else "?"

func _draw()->void:
	if _qs.is_empty(): return
	const W:=480;const H:=320
	var fnt:=ThemeDB.fallback_font
	var wcol:Color=_gym.get("color",Color("#44aaff"))
	var q:=_qs[_qi] if _qi<_qs.size() else {}

	draw_rect(Rect2(0,0,W,H),Color("#06060e"))
	for sl in range(0,H,4): draw_rect(Rect2(0,sl,W,1),Color(0,0,0,0.08))

	# Leader panel
	draw_rect(Rect2(6,6,W-12,68),wcol.darkened(0.6))
	draw_rect(Rect2(6,6,W-12,68),wcol*Color(1,1,1,0.7),false,2.0)
	_draw_leader(12,10,wcol)
	draw_string(fnt,Vector2(76,24),_gym.get("name","???"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,C_GOLD)
	draw_string(fnt,Vector2(76,40),_gym.get("title",""),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.78,0.88,1.0))
	var hp_f:=float(_qs.size()-_qi)/float(_qs.size())
	var hc:=Color(0.1,0.75,0.2) if hp_f>0.5 else (Color(0.9,0.6,0.1) if hp_f>0.25 else Color(0.9,0.1,0.1))
	draw_string(fnt,Vector2(76,54),"Knowledge:",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.65,0.65,0.65))
	draw_rect(Rect2(152,46,180,10),Color(0.08,0.08,0.12))
	draw_rect(Rect2(152,46,int(180*hp_f),10),hc); draw_rect(Rect2(152,46,180,10),wcol*Color(1,1,1,0.4),false,1.0)
	draw_string(fnt,Vector2(345,56),"Q "+str(_qi+1)+"/"+str(_qs.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.65,0.65,0.85))

	# Weak topic indicator
	var weak:=AdaptiveAI.get_weak_topics(_gym.get("world","math"))
	if weak.size()>0:
		draw_string(fnt,Vector2(76,62),"Weak: "+weak[0],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(1.0,0.5,0.2))

	# Question
	draw_rect(Rect2(6,80,W-12,56),Color(0.04,0.08,0.04))
	draw_rect(Rect2(6,80,W-12,56),wcol*Color(1,1,1,0.4),false,1.5)
	draw_string(fnt,Vector2(14,80+20),q.get("q","..."),HORIZONTAL_ALIGNMENT_LEFT,W-28,14,C_TEXT)

	# Options
	var ay:=142
	var opts:=q.get("opts",[])
	for i in opts.size():
		var sel:=(i==_sel and not _locked)
		draw_rect(Rect2(6,ay,W-12,34),_acols[i] if i<_acols.size() else C_NORM)
		if sel: draw_rect(Rect2(6,ay,W-12,34),wcol*Color(1,1,1,0.18))
		draw_rect(Rect2(6,ay,W-12,34),wcol*Color(1,1,1,0.5) if sel else Color(0.3,0.3,0.3),false,1.5)
		draw_string(fnt,Vector2(14,ay+22),_letters(i)+".",HORIZONTAL_ALIGNMENT_LEFT,-1,15,C_GOLD if sel else Color(0.7,0.7,0.5))
		draw_string(fnt,Vector2(34,ay+22),opts[i],HORIZONTAL_ALIGNMENT_LEFT,W-50,14,C_TEXT)
		if sel: draw_string(fnt,Vector2(W-18,ay+22),"◀",HORIZONTAL_ALIGNMENT_LEFT,-1,13,C_GOLD)
		ay+=38

	# Player bar
	draw_rect(Rect2(6,H-28,W-12,24),Color(0.06,0.06,0.04))
	draw_rect(Rect2(6,H-28,W-12,24),Color(0.4,0.4,0.4,0.4),false,1.0)
	var hearts:=""; for i in 3: hearts+="♥ " if i<_lives else "♡ "
	draw_string(fnt,Vector2(14,H-11),GameManager.player_name+"   "+hearts,HORIZONTAL_ALIGNMENT_LEFT,-1,14,C_TEXT)
	draw_string(fnt,Vector2(295,H-11),"↑↓ Select  |  ENTER Confirm",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.5,0.5,0.65))

	# Flash
	if _flash_t>0.0:
		draw_rect(Rect2(0,0,W,H),_flash_c)
		var rc:=Color("#44ff66") if _result.begins_with("C") else Color("#ff4444")
		draw_rect(Rect2(140,118,200,56),Color(0,0,0,0.88)); draw_rect(Rect2(140,118,200,56),rc*Color(1,1,1,0.6),false,2.0)
		draw_string(fnt,Vector2(158,142),_result,HORIZONTAL_ALIGNMENT_LEFT,-1,15,rc)
		if _explain!="":
			var exl:=_explain.split("\n")
			for ei in exl.size():
				draw_string(fnt,Vector2(16,198+ei*17),exl[ei],HORIZONTAL_ALIGNMENT_LEFT,W-32,12,Color(0.85,0.9,0.72))

func _draw_leader(ox:int,oy:int,col:Color)->void:
	draw_rect(Rect2(ox+5,oy+46,8,5),Color("#222222")); draw_rect(Rect2(ox+21,oy+46,8,5),Color("#222222"))
	draw_rect(Rect2(ox+6,oy+34,9,14),Color("#2a3a6a")); draw_rect(Rect2(ox+20,oy+34,9,14),Color("#2a3a6a"))
	draw_rect(Rect2(ox+3,oy+18,30,18),col.darkened(0.3)); draw_rect(Rect2(ox+3,oy+18,30,5),col.darkened(0.1))
	draw_rect(Rect2(ox+11,oy+20,12,16),Color("#d8d8f0")); draw_rect(Rect2(ox+15,oy+22,6,14),col)
	draw_rect(Rect2(ox+0,oy+19,4,12),Color("#f0c090")); draw_rect(Rect2(ox+31,oy+19,4,12),Color("#f0c090"))
	draw_rect(Rect2(ox+9,oy+6,18,14),Color("#f0c090")); draw_rect(Rect2(ox+10,oy+6,16,5),Color("#f8d0a8"))
	draw_rect(Rect2(ox+9,oy+6,18,5),Color("#888890")); draw_rect(Rect2(ox+10,oy+7,14,2),Color("#aaaab0"))
	draw_rect(Rect2(ox+10,oy+14,7,5),Color("#222222"),false,1.5); draw_rect(Rect2(ox+20,oy+14,7,5),Color("#222222"),false,1.5)
	draw_rect(Rect2(ox+17,oy+16,3,1),Color("#222222")); draw_rect(Rect2(ox+12,oy+15,3,3),Color("#111111"))
	draw_rect(Rect2(ox+22,oy+15,3,3),Color("#111111")); draw_rect(Rect2(ox+13,oy+15,1,2),Color(1,1,1,0.5))
