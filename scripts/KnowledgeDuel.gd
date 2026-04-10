# KnowledgeDuel.gd  —  Knowledge Duel battle (player vs AI opponent)
extends Node2D

signal duel_ended(won:bool, xp_earned:int)

var _world:    String   = ""
var _qs:       Array    = []
var _qi:       int      = 0
var _p_lives:  int      = 3
var _ai_lives: int      = 3
var _sel:      int      = 0
var _locked:   bool     = false
var _over:     bool     = false
var _flash_t:  float    = 0.0
var _flash_c:  Color    = Color.TRANSPARENT
var _result:   String   = ""
var _time:     float    = 0.0
var _q_time:   float    = 0.0   # time left to answer (speed bonus)
var _ai_data:  Dictionary = {}  # opponent info

const Q_TIME_LIMIT := 12.0   # seconds per question
const C_TEXT := Color("#e8e8e8")
const C_GOLD := Color("#ffd700")

func setup(world:String, ai_opponent:Dictionary)->void:
	_world=world; _ai_data=ai_opponent
	# Build adaptive question set
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db:=db_map.get(world,AlgebraDB)
	_qs=AdaptiveAI.adaptive_select(
		db.get_all_questions(), world, GameManager.get_level(), 7)
	_qi=0; _p_lives=3; _ai_lives=3; _sel=0; _over=false; _locked=true
	AdaptiveAI.start_session(world)
	set_process(true); set_process_input(false)
	call_deferred("_show_intro")

func _show_intro()->void:
	var dlg:=get_tree().get_first_node_in_group("dialog_box")
	if dlg:
		dlg.show_lines([
			"A Knowledge Duel challenge!",
			_ai_data.get("name","Challenger")+" challenges you\nto a battle of wits!",
			"7 questions. 3 lives each.\nFastest correct answer wins!",
			"Press ENTER to begin the duel!"
		], func(): _locked=false; _q_time=Q_TIME_LIMIT; set_process_input(true))

func _input(event:InputEvent)->void:
	if _over or _locked: return
	var opts:=_qs[_qi].opts
	if event.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_accept"): _submit(); get_viewport().set_input_as_handled()

func _submit()->void:
	_locked=true
	var q:=_qs[_qi]; var ok:=(q.ans==_sel)
	var speed_bonus:=int(((_q_time/Q_TIME_LIMIT)*0.5)*100)   # up to 50 bonus XP for speed
	AdaptiveAI.record_answer(q.get("topic",""), ok)

	# AI answer logic — harder opponents answer faster and more accurately
	var ai_correct:=randf()<_ai_data.get("accuracy",0.5)

	if ok and ai_correct:
		_result="Both correct! +"+str(speed_bonus)+" speed XP"
		_flash_c=Color(0.5,0.8,0.0,0.15)
	elif ok and not ai_correct:
		_ai_lives-=1; _result="You scored! Opponent down."
		_flash_c=Color(0.0,1.0,0.0,0.18)
	elif not ok and ai_correct:
		_p_lives-=1; _result="Opponent scored! Stay sharp."
		_flash_c=Color(1.0,0.0,0.0,0.18)
	else:
		_result="Both wrong! Neither scores."
		_flash_c=Color(0.5,0.5,0.0,0.12)
	_flash_t=1.6; queue_redraw()

func _process(delta:float)->void:
	_time+=delta
	if not _locked and not _over:
		_q_time-=delta
		if _q_time<=0.0: _time_out()
	if _flash_t>0.0:
		_flash_t-=delta
		if _flash_t<=0.0: _after_answer()
	queue_redraw()

func _time_out()->void:
	_locked=true; _p_lives-=1
	_result="Time's up! Opponent scores."
	_flash_c=Color(1.0,0.3,0.0,0.18)
	_flash_t=1.4; queue_redraw()

func _after_answer()->void:
	_result=""; _flash_c=Color.TRANSPARENT
	if _p_lives<=0: _end(false); return
	if _ai_lives<=0: _end(true); return
	_qi+=1
	if _qi>=_qs.size(): _end(_p_lives>_ai_lives); return
	_sel=0; _locked=false; _q_time=Q_TIME_LIMIT; queue_redraw()

func _end(won:bool)->void:
	_over=true; _locked=true; set_process_input(false)
	var rep:=AdaptiveAI.end_session()
	var xp:=0
	if won:
		xp=150+int(rep.get("accuracy",0.5)*100)
		GameManager.add_duel_win()
	duel_ended.emit(won, xp)

# ── DRAWING ───────────────────────────────────────────────────────────────────
func _draw()->void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font
	var wcol:Color={"math":Color("#44aaff"),"english":Color("#ffcc44"),"music":Color("#cc44ff")}.get(_world,Color.WHITE)
	var q:=_qs[_qi] if _qi<_qs.size() else {}

	# BG
	draw_rect(Rect2(0,0,W,H),Color("#06060e"))
	for sl in range(0,H,4): draw_rect(Rect2(0,sl,W,1),Color(0,0,0,0.07))

	# ── Versus header ────────────────────────────────────────────────────
	draw_rect(Rect2(0,0,W,36),Color(0,0,0,0.7))
	# Player side
	draw_rect(Rect2(4,4,140,28),Color(0.1,0.2,0.5,0.8))
	draw_rect(Rect2(4,4,140,28),wcol*Color(1,1,1,0.5),false,1.5)
	var ph:=""; for i in 3: ph+="♥ " if i<_p_lives else "♡ "
	draw_string(fnt,Vector2(10,14),GameManager.player_name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ffffff"))
	draw_string(fnt,Vector2(10,26),ph,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ff4444"))
	# VS
	draw_string(fnt,Vector2(W/2-10,22),"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,C_GOLD)
	# AI side
	draw_rect(Rect2(W-144,4,140,28),Color(0.3,0.1,0.1,0.8))
	draw_rect(Rect2(W-144,4,140,28),Color("#ff4444",0.5),false,1.5)
	var ah:=""; for i in 3: ah+="♥ " if i<_ai_lives else "♡ "
	draw_string(fnt,Vector2(W-138,14),_ai_data.get("name","Challenger"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ff8888"))
	draw_string(fnt,Vector2(W-138,26),ah,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ff4444"))

	# ── Timer bar ────────────────────────────────────────────────────────
	var tf:=_q_time/Q_TIME_LIMIT if not _locked else 1.0
	var tc:=Color(0.2,0.8,0.2) if tf>0.5 else (Color(0.9,0.6,0.1) if tf>0.25 else Color(0.9,0.1,0.1))
	draw_rect(Rect2(0,36,W,5),Color(0.1,0.1,0.1))
	draw_rect(Rect2(0,36,int(W*tf),5),tc)

	# ── Question ─────────────────────────────────────────────────────────
	draw_rect(Rect2(6,46,W-12,52),Color(0.04,0.07,0.04))
	draw_rect(Rect2(6,46,W-12,52),wcol*Color(1,1,1,0.35),false,1.5)
	draw_string(fnt,Vector2(14,62),q.get("q","..."),HORIZONTAL_ALIGNMENT_LEFT,W-28,13,C_TEXT)
	draw_string(fnt,Vector2(W-80,46+52-12),"Q "+str(_qi+1)+"/"+str(_qs.size()),
		HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.6,0.6,0.8))

	# ── Options ───────────────────────────────────────────────────────────
	var opts:=q.get("opts",[])
	var ay:=104
	for i in opts.size():
		var sel:=(i==_sel and not _locked)
		var bg:=Color(0.04,0.12,0.04) if not sel else Color(0.1,0.28,0.1)
		draw_rect(Rect2(6,ay,W-12,34),bg)
		if sel: draw_rect(Rect2(6,ay,W-12,34),wcol*Color(1,1,1,0.2))
		draw_rect(Rect2(6,ay,W-12,34),wcol*Color(1,1,1,0.4) if sel else Color(0.25,0.25,0.25),false,1.5)
		draw_string(fnt,Vector2(14,ay+22),["A","B","C","D"][i]+".",HORIZONTAL_ALIGNMENT_LEFT,-1,14,C_GOLD if sel else Color(0.65,0.65,0.5))
		draw_string(fnt,Vector2(34,ay+22),opts[i],HORIZONTAL_ALIGNMENT_LEFT,W-50,13,C_TEXT)
		if sel: draw_string(fnt,Vector2(W-20,ay+22),"◀",HORIZONTAL_ALIGNMENT_LEFT,-1,12,C_GOLD)
		ay+=38

	# ── Duel score strip ─────────────────────────────────────────────────
	draw_rect(Rect2(0,H-22,W,22),Color(0,0,0,0.65))
	draw_string(fnt,Vector2(14,H-8),"Wins: "+str(GameManager.get_duel_wins()),
		HORIZONTAL_ALIGNMENT_LEFT,-1,12,C_GOLD)
	draw_string(fnt,Vector2(240,H-8),"↑↓ Select  |  ENTER Answer",
		HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.5,0.5,0.65))

	# ── Flash ─────────────────────────────────────────────────────────────
	if _flash_t>0.0:
		draw_rect(Rect2(0,0,W,H),_flash_c)
		draw_rect(Rect2(120,130,240,44),Color(0,0,0,0.88))
		draw_rect(Rect2(120,130,240,44),wcol*Color(1,1,1,0.5),false,2.0)
		draw_string(fnt,Vector2(134,156),_result,HORIZONTAL_ALIGNMENT_LEFT,212,13,C_TEXT)
