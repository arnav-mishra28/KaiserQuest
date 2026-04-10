# BattleScene.gd — Knowledge Battle with world-themed leader sprites
extends Node2D

signal battle_ended(won: bool, badge_name: String, xp: int)

var _gym_data:  Dictionary = {}
var _questions: Array      = []
var _q_idx:     int        = 0
var _lives:     int        = 3
var _sel:       int        = 0
var _locked:    bool       = false
var _over:      bool       = false
var _anim_global: float    = 0.0

const C_BG       := Color("#06061a")
const C_ENEMY    := Color("#0e1c34")
const C_Q_BOX    := Color("#080e08")
const C_ANS_NORM := Color("#0c1c0c")
const C_ANS_SEL  := Color("#1a4020")
const C_ANS_OK   := Color("#0a4a0a")
const C_ANS_BAD  := Color("#4a0a0a")
const C_PLAYER   := Color("#14140a")
const C_TEXT     := Color("#e8e8e8")
const C_GOLD     := Color("#ffd700")
const C_GREEN    := Color("#44ff66")
const C_RED      := Color("#ff4444")
const C_BORDER   := Color("#4466aa")
const W := 480;  const H := 320;  const M := 8

var _flash_col:   Color   = Color.TRANSPARENT
var _flash_t:     float   = 0.0
var _result_text: String  = ""
var _explain:     String  = ""
var _show_res:    bool    = false
var _ans_cols:    Array   = [C_ANS_NORM,C_ANS_NORM,C_ANS_NORM,C_ANS_NORM]
var _leader_anim: float   = 0.0

func setup(gym_data: Dictionary) -> void:
	_gym_data  = gym_data
	_questions = gym_data.get("questions", [])
	_q_idx = 0; _lives = 3; _sel = 0; _over = false
	_locked = true
	set_process(true)
	set_process_input(false)
	call_deferred("_show_intro")

func _show_intro() -> void:
	var dlg := get_tree().get_first_node_in_group("dialog_box")
	if dlg:
		dlg.show_lines(_gym_data.get("intro", ["Ready?"]), func():
			_locked = false
			set_process_input(true)
		)

func _input(event: InputEvent) -> void:
	if _over or _locked: return
	if event.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + _questions[_q_idx].opts.size()) % _questions[_q_idx].opts.size()
		queue_redraw()
	elif event.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % _questions[_q_idx].opts.size()
		queue_redraw()
	elif event.is_action_pressed("ui_accept"):
		_submit()
		get_viewport().set_input_as_handled()

func _submit() -> void:
	_locked = true
	var q = _questions[_q_idx]
	var ok = (q.ans == _sel)
	_explain = q.get("explain", "")
	if ok:
		_ans_cols[_sel] = C_ANS_OK
		_result_text    = "Correct! ✓"
		_flash_col      = Color(0, 1, 0, 0.15)
	else:
		_ans_cols[_sel]    = C_ANS_BAD
		_ans_cols[q.ans]   = C_ANS_OK
		_result_text       = "Wrong!  Correct: " + _letter(q.ans)
		_flash_col         = Color(1, 0, 0, 0.15)
		_lives -= 1
	_show_res = true
	_flash_t  = 1.8
	queue_redraw()

func _process(delta: float) -> void:
	_anim_global += delta
	_leader_anim += delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_after_answer()
	queue_redraw()

func _after_answer() -> void:
	_show_res = false
	_flash_col = Color.TRANSPARENT
	_explain   = ""
	_reset_cols()
	if _lives <= 0: _end(false); return
	_q_idx += 1
	if _q_idx >= _questions.size(): _end(true); return
	_sel = 0; _locked = false

func _end(won: bool) -> void:
	_over = true; _locked = true
	set_process_input(false)
	battle_ended.emit(won, _gym_data.get("badge_name","Badge"),
		_gym_data.get("xp_reward",100) if won else 0)

func _reset_cols() -> void:
	_ans_cols = [C_ANS_NORM,C_ANS_NORM,C_ANS_NORM,C_ANS_NORM]

func _letter(i: int) -> String:
	return ["A","B","C","D"][i] if i < 4 else "?"

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _questions.is_empty(): return
	var fnt := ThemeDB.fallback_font
	var q   = _questions[_q_idx] if _q_idx < _questions.size() else {}

	# Background
	draw_rect(Rect2(0,0,W,H), C_BG)
	# Decorative bg pattern
	for xi in range(0,W,40):
		draw_rect(Rect2(xi,0,1,H), Color(1,1,1,0.02))
	for yi in range(0,H,40):
		draw_rect(Rect2(0,yi,W,1), Color(1,1,1,0.02))

	# ── Enemy panel ───────────────────────────────────────────────────────────
	draw_rect(Rect2(M,M,W-M*2,70), C_ENEMY)
	draw_rect(Rect2(M,M,W-M*2,70), C_BORDER, false, 1.5)
	# Inner glow
	draw_rect(Rect2(M+2,M+2,W-M*2-4,66), Color(1,1,1,0.03))

	# Leader sprite (world-themed)
	_draw_leader(_gym_data.get("leader_type","math"), 14, 12)

	# Name & title
	var lname = _gym_data.get("name","???")
	var ltitle = _gym_data.get("title","")
	draw_string(fnt, Vector2(78,M+18), lname,  HORIZONTAL_ALIGNMENT_LEFT,-1,16, C_GOLD)
	draw_string(fnt, Vector2(78,M+32), ltitle, HORIZONTAL_ALIGNMENT_LEFT,-1,11, Color(0.75,0.85,1))

	# HP bar (questions remaining)
	var total := _questions.size(); var done := _q_idx
	var hp    := float(total-done)/float(total)
	var hpc   := Color(0.1,0.7,0.2) if hp>0.5 else Color(0.9,0.6,0.1) if hp>0.25 else Color(0.9,0.1,0.1)
	draw_string(fnt, Vector2(78,M+46),"Mastery:", HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.7,0.7,0.7))
	draw_rect(Rect2(140,M+38,200,11), Color(0.08,0.08,0.15))
	draw_rect(Rect2(140,M+38,int(200*hp),11), hpc)
	draw_rect(Rect2(140,M+38,200,11), C_BORDER, false,1.0)
	# HP bar shine
	draw_rect(Rect2(140,M+38,int(200*hp),3), Color(1,1,1,0.2))
	draw_string(fnt, Vector2(350,M+48),"Q "+str(_q_idx+1)+"/"+str(total),
		HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.7,0.7,0.9))

	# ── Question box ──────────────────────────────────────────────────────────
	var qy := M+78
	draw_rect(Rect2(M,qy,W-M*2,58), C_Q_BOX)
	draw_rect(Rect2(M,qy,W-M*2,58), C_BORDER, false, 1.5)
	draw_rect(Rect2(M+2,qy+2,W-M*2-4,3), Color(1,1,1,0.05))  # top highlight
	draw_string(fnt, Vector2(16,qy+18), q.get("q","..."),
		HORIZONTAL_ALIGNMENT_LEFT, W-32, 14, C_TEXT)

	# ── Answer options ────────────────────────────────────────────────────────
	var ay := qy+66
	var opts = q.get("opts",[])
	for i in opts.size():
		var ah   = 34; var aoy = ay + i*(ah+4)
		var sel  = (i==_sel and not _locked)
		var bc   = _ans_cols[i] if i < _ans_cols.size() else C_ANS_NORM

		draw_rect(Rect2(M,aoy,W-M*2,ah), bc)
		if sel:
			draw_rect(Rect2(M,aoy,W-M*2,ah), Color(0.3,0.7,0.3,0.2))
		draw_rect(Rect2(M,aoy,W-M*2,ah), C_BORDER if not sel else Color("#66ff99"), false, 1.5)
		if sel:
			draw_rect(Rect2(M+2,aoy+1,W-M*2-4,2), Color(1,1,1,0.1))  # top shine

		var lc := C_GOLD if sel else Color(0.7,0.65,0.45)
		draw_string(fnt, Vector2(M+10,aoy+23), _letter(i)+".",
			HORIZONTAL_ALIGNMENT_LEFT,-1,15,lc)
		draw_string(fnt, Vector2(M+30,aoy+23), opts[i],
			HORIZONTAL_ALIGNMENT_LEFT,W-M*2-44,14,C_TEXT)
		if sel:
			draw_string(fnt, Vector2(M+W-M*2-18,aoy+23),"◀",
				HORIZONTAL_ALIGNMENT_LEFT,-1,13,C_GOLD)

	# ── Player bar ────────────────────────────────────────────────────────────
	var ply := H-28
	draw_rect(Rect2(M,ply,W-M*2,24), C_PLAYER)
	draw_rect(Rect2(M,ply,W-M*2,24), C_BORDER, false,1.0)
	var hearts := ""
	for hi in 3:
		hearts += ("♥ " if hi < _lives else "♡ ")
	draw_string(fnt,Vector2(16,ply+17),GameManager.player_name+"   "+hearts,
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,C_TEXT)
	draw_string(fnt,Vector2(290,ply+17),"↑↓ Move  |  ENTER Select",
		HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.55,0.55,0.7))

	# ── Flash overlay ─────────────────────────────────────────────────────────
	if _flash_t > 0.0:
		draw_rect(Rect2(0,0,W,H), _flash_col)
		var rc := C_GREEN if _result_text.begins_with("Correct") else C_RED
		draw_rect(Rect2(140,125,200,54), Color(0,0,0,0.88))
		draw_rect(Rect2(140,125,200,54), rc*Color(1,1,1,0.5), false,2.0)
		draw_string(fnt,Vector2(158,148),_result_text,
			HORIZONTAL_ALIGNMENT_LEFT,-1,15,rc)
		if _explain != "":
			for li in _explain.split("\n").size():
				draw_string(fnt,Vector2(14,198+li*17),_explain.split("\n")[li],
					HORIZONTAL_ALIGNMENT_LEFT,W-28,12,Color(0.85,0.92,0.72))

# ── Leader sprites (3 distinct types) ────────────────────────────────────────
func _draw_leader(ltype:String, ox:int, oy:int)->void:
	var bob := int(sin(_leader_anim * 2.2) * 2)
	match ltype:
		"english": _leader_english(ox, oy+bob)
		"music":   _leader_music(ox, oy+bob)
		_:         _leader_math(ox, oy+bob)

func _leader_math(ox:int,oy:int)->void:
	# Professor in white lab coat with glasses
	draw_rect(Rect2(ox+5, oy+44,8,6), Color(0.15,0.15,0.15))   # shoes
	draw_rect(Rect2(ox+18,oy+44,8,6), Color(0.15,0.15,0.15))
	draw_rect(Rect2(ox+6, oy+34,8,13), Color(0.2,0.28,0.7))    # pants L
	draw_rect(Rect2(ox+17,oy+34,8,13), Color(0.2,0.28,0.7))    # pants R
	draw_rect(Rect2(ox+4, oy+18,23,18), Color(0.92,0.92,0.95)) # lab coat
	draw_rect(Rect2(ox+6, oy+19,19,15), Color(0.96,0.96,1.0))  # coat highlight
	draw_rect(Rect2(ox+14,oy+20,3,14), Color(0.6,0.1,0.1))     # tie
	draw_rect(Rect2(ox+1, oy+19,4,12), Color(0.92,0.92,0.95))  # arm L
	draw_rect(Rect2(ox+26,oy+19,4,12), Color(0.92,0.92,0.95))  # arm R
	draw_rect(Rect2(ox+1, oy+29,4,4),  Color(0.95,0.78,0.64))  # hand L
	draw_rect(Rect2(ox+26,oy+29,4,4),  Color(0.95,0.78,0.64))  # hand R
	# Clipboard (right hand)
	draw_rect(Rect2(ox+26,oy+20,10,14),Color(0.9,0.85,0.75))
	draw_rect(Rect2(ox+27,oy+22,8,10), Color(1,0.98,0.9))
	draw_rect(Rect2(ox+28,oy+24,6,1),  Color(0.4,0.4,0.5))
	draw_rect(Rect2(ox+28,oy+27,6,1),  Color(0.4,0.4,0.5))
	# Head
	draw_rect(Rect2(ox+8, oy+4, 15,14), Color(0.95,0.78,0.64))
	draw_rect(Rect2(ox+9, oy+5, 10,8), Color(0.98,0.82,0.68))
	# Grey hair
	draw_rect(Rect2(ox+8, oy+4, 15,5), Color(0.7,0.7,0.75))
	draw_rect(Rect2(ox+6, oy+7, 4,5),  Color(0.7,0.7,0.75))
	draw_rect(Rect2(ox+21,oy+7, 4,5),  Color(0.7,0.7,0.75))
	# Glasses (round)
	draw_rect(Rect2(ox+9, oy+12,5,5), Color(0.2,0.2,0.3), false,1.0)
	draw_rect(Rect2(ox+17,oy+12,5,5), Color(0.2,0.2,0.3), false,1.0)
	draw_rect(Rect2(ox+14,oy+14,4,1), Color(0.2,0.2,0.3))
	# Mustache
	draw_rect(Rect2(ox+11,oy+17,8,3), Color(0.55,0.45,0.35))

func _leader_english(ox:int,oy:int)->void:
	# Scholar in elegant robes with scroll
	draw_rect(Rect2(ox+6, oy+44,8,6), Color(0.25,0.15,0.08))   # shoes
	draw_rect(Rect2(ox+17,oy+44,8,6), Color(0.25,0.15,0.08))
	draw_rect(Rect2(ox+5, oy+18,22,28), Color(0.62,0.38,0.12)) # robe main
	draw_rect(Rect2(ox+7, oy+20,18,24), Color(0.72,0.45,0.16)) # robe highlight
	draw_rect(Rect2(ox+12,oy+20,6,24), Color(0.85,0.55,0.2))   # robe center
	# Robe trim (gold)
	draw_rect(Rect2(ox+5, oy+18,22,3), Color(0.85,0.68,0.1))
	draw_rect(Rect2(ox+5, oy+44,22,3), Color(0.85,0.68,0.1))
	draw_rect(Rect2(ox+1, oy+19,5,22), Color(0.72,0.45,0.16))  # sleeve L
	draw_rect(Rect2(ox+25,oy+19,5,22), Color(0.72,0.45,0.16))  # sleeve R
	# Scroll in left hand
	draw_rect(Rect2(ox-4, oy+26,8,20), Color(0.92,0.85,0.7))
	draw_rect(Rect2(ox-4, oy+26,8,3),  Color(0.8,0.6,0.3))
	draw_rect(Rect2(ox-4, oy+43,8,3),  Color(0.8,0.6,0.3))
	draw_rect(Rect2(ox-3, oy+30,6,1),  Color(0.5,0.4,0.3))
	draw_rect(Rect2(ox-3, oy+33,6,1),  Color(0.5,0.4,0.3))
	# Head
	draw_rect(Rect2(ox+8, oy+4, 15,14), Color(0.95,0.78,0.64))
	draw_rect(Rect2(ox+9, oy+5, 10,8),  Color(0.98,0.82,0.68))
	# Dark hair (bun style)
	draw_rect(Rect2(ox+8, oy+4, 15,5),  Color(0.2,0.12,0.06))
	draw_rect(Rect2(ox+6, oy+6, 4,4),   Color(0.2,0.12,0.06))
	draw_rect(Rect2(ox+21,oy+6, 4,4),   Color(0.2,0.12,0.06))
	draw_rect(Rect2(ox+19,oy+3, 8,5),   Color(0.2,0.12,0.06))  # hair bun
	# Eyes (wise)
	draw_rect(Rect2(ox+10,oy+12,3,3), Color(0.15,0.12,0.08))
	draw_rect(Rect2(ox+18,oy+12,3,3), Color(0.15,0.12,0.08))
	draw_rect(Rect2(ox+10,oy+12,1,1), Color(1,1,1))
	draw_rect(Rect2(ox+18,oy+12,1,1), Color(1,1,1))
	# Earrings (golden)
	draw_rect(Rect2(ox+6, oy+13,3,3),  Color(0.9,0.7,0.1))
	draw_rect(Rect2(ox+22,oy+13,3,3),  Color(0.9,0.7,0.1))

func _leader_music(ox:int,oy:int)->void:
	# Maestro with conductor's baton and formal coat
	var bob2 := int(sin(_leader_anim * 4.0) * 3)   # faster bob for energy
	draw_rect(Rect2(ox+5, oy+44,8,6), Color(0.1,0.08,0.12))   # shoes
	draw_rect(Rect2(ox+18,oy+44,8,6), Color(0.1,0.08,0.12))
	draw_rect(Rect2(ox+7, oy+34,7,12), Color(0.15,0.1,0.25))   # pants L
	draw_rect(Rect2(ox+17,oy+34,7,12), Color(0.15,0.1,0.25))   # pants R
	draw_rect(Rect2(ox+4, oy+18,23,18), Color(0.18,0.10,0.35)) # coat
	draw_rect(Rect2(ox+6, oy+19,19,15), Color(0.22,0.12,0.42)) # coat highlight
	draw_rect(Rect2(ox+13,oy+19,4,15), Color(0.9,0.8,1.0))     # shirt/cravat
	# Gold lapels
	draw_rect(Rect2(ox+6, oy+18,5,10), Color(0.8,0.62,0.1))
	draw_rect(Rect2(ox+20,oy+18,5,10), Color(0.8,0.62,0.1))
	draw_rect(Rect2(ox+1, oy+19,4,14), Color(0.18,0.10,0.35))  # arm L
	draw_rect(Rect2(ox+26,oy+19,4,14), Color(0.18,0.10,0.35))  # arm R
	# Baton (raised arm with bob)
	draw_rect(Rect2(ox+26,oy+8+bob2,3,16), Color(0.85,0.75,0.55))
	draw_rect(Rect2(ox+25,oy+7+bob2,5,4),  Color(1,1,1))        # baton tip
	# Head
	draw_rect(Rect2(ox+8, oy+4, 15,14), Color(0.95,0.78,0.64))
	draw_rect(Rect2(ox+9, oy+5, 10,8),  Color(0.98,0.82,0.68))
	# Curly hair (dark with purple tint)
	draw_rect(Rect2(ox+8, oy+4, 15,5),  Color(0.15,0.08,0.28))
	draw_rect(Rect2(ox+6, oy+6, 4,6),   Color(0.15,0.08,0.28))
	draw_rect(Rect2(ox+22,oy+6, 4,6),   Color(0.15,0.08,0.28))
	# Curls detail
	draw_rect(Rect2(ox+7, oy+9, 3,3),   Color(0.2,0.1,0.35))
	draw_rect(Rect2(ox+22,oy+9, 3,3),   Color(0.2,0.1,0.35))
	# Monocle
	draw_rect(Rect2(ox+17,oy+11,6,6), Color(0.6,0.6,0.7), false,1.0)
	draw_rect(Rect2(ox+22,oy+11,1,1), Color(0.6,0.6,0.7))  # monocle string
	# Eyes
	draw_rect(Rect2(ox+10,oy+12,3,3), Color(0.15,0.08,0.28))
	draw_rect(Rect2(ox+18,oy+12,3,3), Color(0.15,0.08,0.28))
	draw_rect(Rect2(ox+10,oy+12,1,1), Color(1,1,1))
	draw_rect(Rect2(ox+18,oy+12,1,1), Color(1,1,1))
	# Thin mustache
	draw_rect(Rect2(ox+12,oy+17,7,2), Color(0.3,0.15,0.45))
