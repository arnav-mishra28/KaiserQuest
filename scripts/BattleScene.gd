# BattleScene.gd
# Knowledge Battle: Gym Leader vs Player — quiz-based combat
extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────
signal battle_ended(won: bool, badge_name: String, xp: int)

# ── Data ──────────────────────────────────────────────────────────────────────
var _gym_data:  Dictionary = {}
var _questions: Array      = []
var _q_idx:     int        = 0
var _lives:     int        = 3
var _sel:       int        = 0          # currently selected answer (0-3)
var _locked:    bool       = false      # true while showing answer result
var _over:      bool       = false

# ── Colors ────────────────────────────────────────────────────────────────────
const C_BG        := Color("#08081a")
const C_ENEMY     := Color("#10203a")
const C_Q_BOX     := Color("#0a180a")
const C_ANS_NORM  := Color("#0e200e")
const C_ANS_SEL   := Color("#1a4020")
const C_ANS_OK    := Color("#0a4a0a")
const C_ANS_BAD   := Color("#4a0a0a")
const C_PLAYER_BG := Color("#18180a")
const C_TEXT      := Color("#e8e8e8")
const C_GOLD      := Color("#ffd700")
const C_GREEN     := Color("#44ff66")
const C_RED       := Color("#ff4444")
const C_BORDER    := Color("#4466aa")

# ── Layout constants ──────────────────────────────────────────────────────────
const W  := 480
const H  := 320
const M  :=  8    # margin

# ── Result flash state ────────────────────────────────────────────────────────
var _flash_color: Color   = Color.TRANSPARENT
var _flash_timer: float   = 0.0
var _result_text: String  = ""
var _explain:     String  = ""
var _show_result: bool    = false
var _ans_colors: Array[Color] = [C_ANS_NORM, C_ANS_NORM, C_ANS_NORM, C_ANS_NORM]

# ── Init ──────────────────────────────────────────────────────────────────────
func setup(gym_data: Dictionary) -> void:
	_gym_data  = gym_data
	_questions = gym_data.get("questions", [])
	_q_idx     = 0
	_lives     = 3
	_sel       = 0
	_over      = false
	set_process(true)
	set_process_input(false)
	_locked = true
	# Defer so the node is fully in the scene tree
	call_deferred("_show_intro")

func _show_intro() -> void:
	_locked = true
	set_process_input(false)
	var intro_lines: Array = _gym_data.get("intro", ["Ready to battle?"])
	var dlg: CanvasLayer = _get_dialog()
	if dlg:
		dlg.show_lines(intro_lines, func():
			_locked = false
			set_process_input(true)
		)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _over or _locked:
		return

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
	var q         := _questions[_q_idx]
	var correct   := (q.ans == _sel)
	_explain      = q.get("explain", "")

	if correct:
		_ans_colors[_sel] = C_ANS_OK
		_result_text      = "Correct!"
		_flash_color      = Color(0.0, 1.0, 0.0, 0.18)
	else:
		_ans_colors[_sel]      = C_ANS_BAD
		_ans_colors[q.ans]     = C_ANS_OK   # Show correct answer
		_result_text           = "Wrong!  Answer: " + _letters(q.ans)
		_flash_color           = Color(1.0, 0.0, 0.0, 0.18)
		_lives -= 1

	_show_result  = true
	_flash_timer  = 1.6
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_after_answer()
		queue_redraw()

func _after_answer() -> void:
	_show_result = false
	_flash_color = Color.TRANSPARENT
	_explain     = ""
	_reset_ans_colors()

	if _lives <= 0:
		_end_battle(false)
		return

	_q_idx += 1
	if _q_idx >= _questions.size():
		_end_battle(true)
		return

	_sel    = 0
	_locked = false
	queue_redraw()

func _end_battle(won: bool) -> void:
	_over   = true
	_locked = true
	set_process_input(false)
	# Let the flash finish, then emit
	var badge := _gym_data.get("badge_name", "Unknown Badge")
	var xp    := _gym_data.get("xp_reward", 100) if won else 0
	battle_ended.emit(won, badge, xp)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _reset_ans_colors() -> void:
	_ans_colors = [C_ANS_NORM, C_ANS_NORM, C_ANS_NORM, C_ANS_NORM] as Array[Color]

func _letters(i: int) -> String:
	return ["A", "B", "C", "D"][i] if i < 4 else "?"

func _get_dialog() -> CanvasLayer:
	return get_tree().get_first_node_in_group("dialog_box")

func _heart(filled: bool) -> String:
	return "♥" if filled else "♡"

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _questions.is_empty():
		return
	var fnt := ThemeDB.fallback_font
	var q   := _questions[_q_idx] if _q_idx < _questions.size() else {}

	# Background
	draw_rect(Rect2(0, 0, W, H), C_BG)

	# ── Enemy / Leader panel (top) ────────────────────────────────────────────
	draw_rect(Rect2(M, M, W - M*2, 64), C_ENEMY)
	draw_rect(Rect2(M, M, W - M*2, 64), C_BORDER, false, 1.5)

	# Leader pixel sprite (placeholder humanoid in left area)
	_draw_leader_sprite(16, 12)

	# Leader name & title
	draw_string(fnt, Vector2(70, M + 18),
		_gym_data.get("name", "???"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_GOLD)
	draw_string(fnt, Vector2(70, M + 34),
		_gym_data.get("title", ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.85, 1.0))

	# Leader HP bar (represents questions remaining)
	var total    := _questions.size()
	var answered := _q_idx
	var hp_frac  := float(total - answered) / float(total)
	var hp_col   := Color(0.1, 0.7, 0.2) if hp_frac > 0.5 else Color(0.9, 0.6, 0.1) if hp_frac > 0.25 else Color(0.9, 0.1, 0.1)
	draw_string(fnt, Vector2(70, M + 48), "Knowledge:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.7))
	draw_rect(Rect2(148, M + 40, 180, 10), Color(0.1, 0.1, 0.15))
	draw_rect(Rect2(148, M + 40, int(180 * hp_frac), 10), hp_col)
	draw_rect(Rect2(148, M + 40, 180, 10), C_BORDER, false, 1.0)

	# Question counter
	draw_string(fnt, Vector2(340, M + 48),
		"Q " + str(_q_idx + 1) + " / " + str(total),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.9))

	# ── Question box ──────────────────────────────────────────────────────────
	var qy := M + 72
	draw_rect(Rect2(M, qy, W - M*2, 56), C_Q_BOX)
	draw_rect(Rect2(M, qy, W - M*2, 56), C_BORDER, false, 1.5)
	draw_string(fnt, Vector2(16, qy + 18),
		q.get("q", "..."), HORIZONTAL_ALIGNMENT_LEFT, W - 32, 14, C_TEXT)

	# ── Answer options ────────────────────────────────────────────────────────
	var ay     := qy + 64
	var opts   := q.get("opts", [])
	for i in opts.size():
		var ax     := M
		var aw     := W - M*2
		var ah     := 36
		var aoy    := ay + i * (ah + 4)
		var bg_col := _ans_colors[i] if i < _ans_colors.size() else C_ANS_NORM
		var selected := (i == _sel and not _locked)

		draw_rect(Rect2(ax, aoy, aw, ah), bg_col)
		if selected:
			draw_rect(Rect2(ax, aoy, aw, ah), Color(0.4, 0.8, 0.4, 0.25))
		draw_rect(Rect2(ax, aoy, aw, ah), C_BORDER if not selected else Color("#66ff99"), false, 1.5)

		# Letter label
		var letter_col := C_GOLD if selected else Color(0.7, 0.7, 0.5)
		draw_string(fnt, Vector2(ax + 10, aoy + 24),
			_letters(i) + ".",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, letter_col)

		# Answer text
		draw_string(fnt, Vector2(ax + 32, aoy + 24),
			opts[i], HORIZONTAL_ALIGNMENT_LEFT, aw - 44, 14, C_TEXT)

		# Selection cursor arrow
		if selected:
			draw_string(fnt, Vector2(ax + aw - 18, aoy + 24),
				"◀", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_GOLD)

	# ── Player info bar (bottom) ───────────────────────────────────────────────
	var ply := H - 28
	draw_rect(Rect2(M, ply, W - M*2, 24), C_PLAYER_BG)
	draw_rect(Rect2(M, ply, W - M*2, 24), C_BORDER, false, 1.0)

	# Lives hearts
	var hearts_str := ""
	for i in 3:
		hearts_str += _heart(i < _lives) + " "
	draw_string(fnt, Vector2(16, ply + 17),
		GameManager.player_name + "   " + hearts_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_TEXT)

	# Controls hint
	draw_string(fnt, Vector2(290, ply + 17),
		"↑↓ Select  |  ENTER Confirm",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.55, 0.7))

	# ── Flash overlay (result feedback) ───────────────────────────────────────
	if _flash_timer > 0.0:
		draw_rect(Rect2(0, 0, W, H), _flash_color)

		# Result text
		var rt_col := C_GREEN if _result_text.begins_with("Correct") else C_RED
		draw_rect(Rect2(150, 130, 180, 50), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(150, 130, 180, 50), rt_col * Color(1,1,1,0.6), false, 2.0)
		draw_string(fnt, Vector2(168, 152), _result_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, rt_col)

		# Explanation (smaller)
		if _explain != "":
			var exp_lines: PackedStringArray = _explain.split("\n")
			for li: int in exp_lines.size():
				draw_string(fnt, Vector2(16, 200 + li * 18),
					exp_lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, W - 32, 12, Color(0.85, 0.9, 0.7))

# ── Leader sprite (placeholder pixel humanoid) ────────────────────────────────
func _draw_leader_sprite(ox: int, oy: int) -> void:
	# Glasses-wearing professor
	# Shoes
	draw_rect(Rect2(ox+5,  oy+46, 8, 5), Color("#222222"))
	draw_rect(Rect2(ox+20, oy+46, 8, 5), Color("#222222"))
	# Pants / legs
	draw_rect(Rect2(ox+6,  oy+35, 8, 14), Color("#2a3a6a"))
	draw_rect(Rect2(ox+19, oy+35, 8, 14), Color("#2a3a6a"))
	# Lab coat (white shirt)
	draw_rect(Rect2(ox+4,  oy+20, 26, 18), Color("#d8d8f0"))
	# Tie
	draw_rect(Rect2(ox+14, oy+22, 6, 14), Color("#cc2020"))
	# Head
	draw_rect(Rect2(ox+8,  oy+6, 18, 16), Color("#f0c8a0"))
	# Hair (grey)
	draw_rect(Rect2(ox+8,  oy+6, 18, 5), Color("#888890"))
	# Glasses
	draw_rect(Rect2(ox+9,  oy+15, 7, 5), Color("#222222"), false, 1.0)
	draw_rect(Rect2(ox+18, oy+15, 7, 5), Color("#222222"), false, 1.0)
	draw_rect(Rect2(ox+16, oy+17, 3, 1), Color("#222222"))  # glasses bridge
