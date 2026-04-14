# DuelSystem.gd — Knowledge Duel (player vs AI opponent with timer)
extends Node2D

signal duel_ended(won:bool, xp_earned:int)

var _world:    String     = ""
var _opp:      Dictionary = {}
var _qs:       Array      = []
var _qi:       int        = 0
var _p_lives:  int        = 3
var _ai_lives: int        = 3
var _sel:      int        = 0
var _locked:   bool       = false
var _over:     bool       = false
var _time:     float      = 0.0
var _q_time:   float      = 0.0
var _result:   String     = ""
var _flash_t:  float      = 0.0
var _flash_c:  Color      = Color.TRANSPARENT
var _dialog:   Node       = null

const Q_LIMIT  := 12.0
const BG_TOP   := Color("#98a060"); const BG_STRIPE:=Color("#88904c")
const BG_BOT   := Color("#b8c880"); const BOX_BG:=Color("#f0f0e0")
const BOX_DK   := Color("#181010"); const HP_G:=Color("#48c840")
const HP_Y     := Color("#f8d010"); const HP_R:=Color("#e02020")
const SEL      := Color("#a8d8f8")

func setup(world:String, opponent:Dictionary, dialog_node:Node)->void:
	_world  = world; _opp = opponent; _dialog = dialog_node
	var db_map := {"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db := db_map.get(world, AlgebraDB)
	_qs = AdaptiveAI.adaptive_select(db.get_all_questions(), world, GameManager.get_level(), 7)
	if _qs.is_empty(): _qs = db.get_gym1_questions()
	_qi=0; _p_lives=3; _ai_lives=3; _sel=0; _over=false; _locked=true
	AdaptiveAI.start_session(world)
	set_process(true); set_process_input(false)
	call_deferred("_intro")

func _intro()->void:
	if _dialog:
		_dialog.show_lines([
			_opp.get("name","Rival")+" challenges you\nto a Knowledge Duel!",
			"7 questions. 3 lives each.\nFaster correct answers = bonus XP!",
			"Press ENTER to begin the duel!"
		], func(): _locked=false; _q_time=Q_LIMIT; set_process_input(true))

func _input(ev:InputEvent)->void:
	if _over or _locked: return
	var opts := _qs[_qi].get("opts",[]) if _qi<_qs.size() else []
	if ev.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_accept"): _submit(); ev.get_viewport()

func _submit()->void:
	_locked=true; var q:=_qs[_qi]; var ok:=(q.ans==_sel)
	var speed_bonus:=int((_q_time/Q_LIMIT)*50)
	AdaptiveAI.record_answer(q.get("topic",""), ok)
	var ai_ok:=randf()<_opp.get("accuracy",0.5)
	if ok and not ai_ok:    _ai_lives-=1; _result="You scored!"
	elif not ok and ai_ok:  _p_lives-=1;  _result="Opponent scores!"
	elif ok and ai_ok:      _result="Both correct! +"+str(speed_bonus)+" XP"
	else:                   _result="Both wrong!"
	_flash_c = Color(0,0.8,0,0.2) if ok else Color(0.8,0,0,0.2)
	_flash_t = 0.0; queue_redraw()

func _process(delta:float)->void:
	_time+=delta
	if not _locked and not _over:
		_q_time -= delta
		if _q_time<=0.0: _timeout()
	if _locked and not _over:
		_flash_t+=delta
		if _flash_t>=1.6: _advance()
	queue_redraw()

func _timeout()->void:
	_locked=true; _p_lives-=1; _result="Time's up!"; _flash_c=Color(0.8,0.3,0,0.2); queue_redraw()

func _advance()->void:
	_result=""; _flash_c=Color.TRANSPARENT
	if _p_lives<=0: _end(false); return
	if _ai_lives<=0: _end(true); return
	_qi+=1
	if _qi>=_qs.size(): _end(_p_lives>_ai_lives); return
	_sel=0; _locked=false; _q_time=Q_LIMIT; queue_redraw()

func _end(won:bool)->void:
	_over=true; _locked=true; set_process_input(false)
	AdaptiveAI.end_session()
	var xp := _opp.get("reward_xp",150) if won else 30  # small consolation XP
	duel_ended.emit(won, xp)

func _draw()->void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font; var q:=_qs[_qi] if _qi<_qs.size() else {}

	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG_STRIPE if ((gx/4+gy/4)%2)==0 else BG_TOP)
	for gy in range(H/2,H,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG_BOT if ((gx/4+gy/4)%2)==0 else Color("#a8b860"))

	# ── VS header ─────────────────────────────────────────────────────────
	draw_rect(Rect2(0,0,W,34),BOX_DK); draw_rect(Rect2(0,0,W,32),Color("#f0f0e0"))
	# Player side
	draw_rect(Rect2(2,2,148,28),Color("#204080")); draw_rect(Rect2(3,3,146,26),Color("#3060b0"))
	draw_string(fnt,Vector2(8,14),GameManager.player_name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ffffff"))
	var ph:=""; for i in 3: ph+="♥" if i<_p_lives else "♡"
	draw_string(fnt,Vector2(8,26),ph,HORIZONTAL_ALIGNMENT_LEFT,-1,14, HP_G if _p_lives>1 else HP_R)
	# VS
	draw_string(fnt,Vector2(W/2-12,22),"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#ffd700"))
	# Opponent side
	draw_rect(Rect2(W-150,2,148,28),Color("#802020")); draw_rect(Rect2(W-149,3,146,26),Color("#b03030"))
	draw_string(fnt,Vector2(W-144,14),_opp.get("name","Rival"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ffffff"))
	var ah:=""; for i in 3: ah+="♥" if i<_ai_lives else "♡"
	draw_string(fnt,Vector2(W-144,26),ah,HORIZONTAL_ALIGNMENT_LEFT,-1,14, HP_G if _ai_lives>1 else HP_R)

	# Timer bar
	var tf := _q_time/Q_LIMIT if not _locked else 1.0
	var tc := HP_G if tf>0.5 else (HP_Y if tf>0.25 else HP_R)
	draw_rect(Rect2(0,34,W,5),BOX_DK); draw_rect(Rect2(1,35,W-2,3),Color("#686868"))
	draw_rect(Rect2(1,35,int((W-2)*tf),3),tc)

	# Question
	draw_rect(Rect2(4,42,W-8,40),BOX_DK); draw_rect(Rect2(5,43,W-10,38),BOX_BG)
	draw_string(fnt,Vector2(12,56),q.get("q","..."),HORIZONTAL_ALIGNMENT_LEFT,W-24,13,BOX_DK)
	draw_string(fnt,Vector2(W-56,78),"Q "+str(_qi+1)+"/"+str(_qs.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.4,0.5))

	# Options
	var ay:=86; var opts:=q.get("opts",[])
	for i in opts.size():
		var cx:=4 if i%2==0 else W/2+2; var ry:=ay if i<2 else ay+34
		var sel:=(not _locked and i==_sel)
		draw_rect(Rect2(cx,ry,W/2-6,32),BOX_DK); draw_rect(Rect2(cx+1,ry+1,W/2-8,30),BOX_BG)
		if sel: draw_rect(Rect2(cx+1,ry+1,W/2-8,30),SEL)
		draw_string(fnt,Vector2(cx+5,ry+21),("►" if sel else " ")+" "+["A","B","C","D"][i]+". "+opts[i],
			HORIZONTAL_ALIGNMENT_LEFT,W/2-12,12,BOX_DK)

	# Duel info
	draw_rect(Rect2(4,H-14,W-8,10),BOX_DK); draw_rect(Rect2(5,H-13,W-10,8),BOX_BG)
	draw_string(fnt,Vector2(8,H-4),"Wins: "+str(GameManager.get_duel_wins())+"   Weak: "+
		(AdaptiveAI.get_weak_topics(_world)[0] if AdaptiveAI.get_weak_topics(_world).size()>0 else "none"),
		HORIZONTAL_ALIGNMENT_LEFT,-1,9,BOX_DK)

	# Flash + result
	if _locked and not _over and _flash_t>0:
		draw_rect(Rect2(0,0,W,H/2),_flash_c)
		if _flash_t>0.3:
			draw_rect(Rect2(W/2-120,H/2-28,240,24),BOX_DK)
			draw_rect(Rect2(W/2-119,H/2-27,238,22),BOX_BG)
			draw_string(fnt,Vector2(W/2-100,H/2-12),_result,HORIZONTAL_ALIGNMENT_LEFT,200,13,BOX_DK)
