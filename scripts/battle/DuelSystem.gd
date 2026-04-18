# DuelSystem.gd — Knowledge Duel vs AI opponent
extends Node2D

signal duel_ended(won: bool, xp_earned: int)

var _world:   String     = ""
var _opp:     Dictionary = {}
var _qs:      Array      = []
var _qi:      int        = 0
var _p_lives: int        = 3
var _a_lives: int        = 3
var _sel:     int        = 0
var _locked:  bool       = false
var _over:    bool       = false
var _time:    float      = 0.0
var _q_time:  float      = 0.0
var _flash_t: float      = 0.0
var _flash_c: Color      = Color.TRANSPARENT
var _result:  String     = ""
var _dialog:  Node       = null

const Q_LIMIT := 12.0
const BG1  := Color("#98a060"); const BG2  := Color("#88904c")
const BOT1 := Color("#b8c880"); const BOT2 := Color("#a8b060")
const BOX  := Color("#f0f0e0"); const DK   := Color("#181010")
const HP_G := Color("#48c840"); const HP_Y := Color("#f8d010"); const HP_R := Color("#e02020")
const SEL  := Color("#a8d8f8")

func setup(world: String, opponent: Dictionary, dialog_node: Node) -> void:
	_world  = world; _opp = opponent; _dialog = dialog_node
	var db_map := {"math": AlgebraDB, "english": EnglishDB, "music": MusicDB}
	var db = db_map.get(world, AlgebraDB)
	_qs = AdaptiveAI.adaptive_select(db.get_all_questions(), world, GameManager.get_level(), 7)
	if _qs.is_empty(): _qs = db.get_gym1_questions()
	_qi = 0; _p_lives = 3; _a_lives = 3; _sel = 0; _over = false; _locked = true
	AdaptiveAI.start_session(world)
	set_process(true); set_process_input(false)
	call_deferred("_intro")

func _intro() -> void:
	if _dialog and _dialog.has_method("show_lines"):
		if "context" in _dialog: _dialog.context = "battle"
		_dialog.show_lines([
			_opp.get("name","Rival") + " challenges you\nto a Knowledge Duel!",
			"7 questions  ·  3 lives each",
			"Correct answer → you score a point!\nWrong answer → opponent scores!",
			"Press ENTER to begin!"
		], func(): _locked = false; _q_time = Q_LIMIT; set_process_input(true))

func _input(ev: InputEvent) -> void:
	if _over or _locked: return
	var opts = _qs[_qi].get("opts",[]) if _qi < _qs.size() else []
	if ev.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + opts.size()) % opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_accept"):
		_submit(); ev.get_viewport().set_input_as_handled()
	# ── Click on answer to select + submit instantly ──────────────────────────
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var idx := _get_opt_at(ev.position)
		if idx >= 0:
			_sel = idx
			_submit()
			get_viewport().set_input_as_handled()
	# ── Hover to highlight ────────────────────────────────────────────────────
	elif ev is InputEventMouseMotion:
		var idx := _get_opt_at(ev.position)
		if idx >= 0 and idx != _sel: _sel = idx; queue_redraw()

# Returns which answer option the mouse is hovering over (0-3), or -1
func _get_opt_at(pos: Vector2) -> int:
	# Options: 2×2 grid starting at ay=86, each 32px tall, 34px spacing
	# Col 0: cx=4, width=234    Col 1: cx=242, width=234
	# Row 0: ry=86              Row 1: ry=120
	const AY := 86; const AH := 32; const STEP := 34
	var cols := [4, 242]; var widths := [234, 234]
	for i in 4:
		var col := i % 2; var row := i / 2
		var cx = cols[col]; var ry := AY + row * STEP
		if pos.x >= cx and pos.x <= cx + widths[col] and pos.y >= ry and pos.y <= ry + AH:
			return i
	return -1

func _submit() -> void:
	_locked = true; var q = _qs[_qi]; var ok = (q.ans == _sel)
	AdaptiveAI.record_answer(q.get("topic",""), ok)
	var ai_ok = randf() < _opp.get("accuracy", 0.5)
	if ok and not ai_ok:    _a_lives -= 1; _result = "✓ You score a point!"
	elif not ok and ai_ok:  _p_lives -= 1; _result = "✗ Opponent scores!"
	elif ok and ai_ok:      _result = "Both correct!"
	else:                   _result = "Both wrong!"
	_flash_c = Color(0,0.8,0,0.2) if ok else Color(0.8,0,0,0.2)
	_flash_t = 0.0; queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if not _locked and not _over:
		_q_time -= delta
		if _q_time <= 0.0: _timeout()
	if _locked and not _over:
		_flash_t += delta
		if _flash_t >= 1.6: _advance()
	queue_redraw()

func _timeout() -> void:
	_locked = true; _p_lives -= 1; _result = "⏱ Time's up!"; _flash_c = Color(0.8,0.4,0,0.2); queue_redraw()

func _advance() -> void:
	_result = ""; _flash_c = Color.TRANSPARENT
	if _p_lives <= 0: _end(false); return
	if _a_lives <= 0: _end(true);  return
	_qi += 1
	if _qi >= _qs.size(): _end(_p_lives > _a_lives); return
	_sel = 0; _locked = false; _q_time = Q_LIMIT; queue_redraw()

func _end(won: bool) -> void:
	_over = true; _locked = true; set_process_input(false)
	AdaptiveAI.end_session()
	duel_ended.emit(won, _opp.get("reward_xp",150) if won else 25)

func _draw() -> void:
	if _qs.is_empty(): return
	const W := 480; const H := 320
	var fnt := ThemeDB.fallback_font
	var q   = _qs[_qi] if _qi < _qs.size() else {}
	var wcol= {"math":Color("#2060d0"),"english":Color("#c07010"),"music":Color("#8020c0")}.get(_world,Color("#2060d0"))

	# Gen 2 battle background
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG2 if ((gx/4+gy/4)%2)==0 else BG1)
	for gy in range(H/2,H,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BOT2 if ((gx/4+gy/4)%2)==0 else BOT1)

	# VS Header
	draw_rect(Rect2(0,0,W,32), DK); draw_rect(Rect2(0,0,W,30), BOX)
	# Player side
	draw_rect(Rect2(2,2,146,26), wcol.darkened(0.3))
	draw_string(fnt, Vector2(8,14), GameManager.player_name, HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ffffff"))
	var ph := ""; for i in 3: ph += ("♥" if i<_p_lives else "♡")
	draw_string(fnt, Vector2(8,26), ph, HORIZONTAL_ALIGNMENT_LEFT,-1,14, HP_G if _p_lives>1 else HP_R)
	# VS center
	draw_string(fnt, Vector2(W/2-12,22), "VS", HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#ffd700"))
	# Opponent side
	draw_rect(Rect2(W-148,2,146,26), Color("#802020"))
	draw_string(fnt, Vector2(W-142,14), _opp.get("name","Rival"), HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#ff8888"))
	var ah := ""; for i in 3: ah += ("♥" if i<_a_lives else "♡")
	draw_string(fnt, Vector2(W-142,26), ah, HORIZONTAL_ALIGNMENT_LEFT,-1,14, HP_G if _a_lives>1 else HP_R)

	# Timer bar
	var tf := clampf(_q_time/Q_LIMIT, 0.0, 1.0) if not _locked else 1.0
	var tc := HP_G if tf>0.5 else (HP_Y if tf>0.25 else HP_R)
	draw_rect(Rect2(0,32,W,5), DK); draw_rect(Rect2(1,33,W-2,3), Color("#686868"))
	draw_rect(Rect2(1,33,int((W-2)*tf),3), tc)

	# Question box
	draw_rect(Rect2(4,40,W-8,42), DK); draw_rect(Rect2(5,41,W-10,40), BOX)
	draw_rect(Rect2(5,41,W-10,12), wcol*Color(1,1,1,0.2))
	draw_string(fnt, Vector2(12,56), q.get("q","..."), HORIZONTAL_ALIGNMENT_LEFT,W-24,13,DK)
	draw_string(fnt, Vector2(W-58,78), "Q "+str(_qi+1)+"/"+str(_qs.size()), HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.4,0.5))

	# Options (2×2 grid)
	var opts = q.get("opts",[]); var ay := 86
	for i in opts.size():
		var cx := 4 if i%2==0 else W/2+2; var ry := ay if i<2 else ay+34
		var sel = (not _locked and i==_sel)
		draw_rect(Rect2(cx,ry,W/2-6,32), DK); draw_rect(Rect2(cx+1,ry+1,W/2-8,30), BOX)
		if sel: draw_rect(Rect2(cx+1,ry+1,W/2-8,30), SEL)
		draw_string(fnt, Vector2(cx+5,ry+21),
			("►" if sel else " ")+" "+["A","B","C","D"][i]+". "+opts[i],
			HORIZONTAL_ALIGNMENT_LEFT, W/2-12, 12, DK)

	# Stats bar
	draw_rect(Rect2(4,H-14,W-8,10), DK); draw_rect(Rect2(5,H-13,W-10,8), BOX)
	var weak := AdaptiveAI.get_weak_topics(_world)
	draw_string(fnt, Vector2(8,H-4),
		"Wins: "+str(GameManager.get_duel_wins())+(("   Weak: "+weak[0]) if weak.size()>0 else ""),
		HORIZONTAL_ALIGNMENT_LEFT,-1,9,DK)

	# Flash + result
	if _locked and not _over and _flash_t > 0:
		draw_rect(Rect2(0,0,W,H/2), _flash_c)
		if _flash_t > 0.3:
			draw_rect(Rect2(W/2-120,H/2-28,240,24), DK)
			draw_rect(Rect2(W/2-119,H/2-27,238,22), BOX)
			draw_string(fnt, Vector2(W/2-100,H/2-12), _result, HORIZONTAL_ALIGNMENT_LEFT,200,13,DK)
