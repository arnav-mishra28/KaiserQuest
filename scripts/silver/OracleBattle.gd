# OracleBattle.gd — Production-level Oracle Final Boss Battle
# Full HP system, animated HP bars, flash effects, starbursts, shake, typewriter results
extends Node2D

signal oracle_ended(won: bool)

# ── Phases ─────────────────────────────────────────────────────────────────────
enum Phase { INTRO, MENU, ANSWERING, RESULT, WIN_ANIM, LOSE_ANIM, ENDED }

# ── Data ───────────────────────────────────────────────────────────────────────
var _data:      Dictionary = {}
var _qs:        Array      = []
var _qi:        int        = 0
var _sel:       int        = 0
var _phase:     int        = Phase.INTRO
var _dialog:    Node       = null

# ── HP system ─────────────────────────────────────────────────────────────────
var _p_hp:      int   = 0;  var _p_max:  int   = 0
var _o_hp:      int   = 0;  var _o_max:  int   = 0
var _p_hp_disp: float = 0.0 # animated display HP
var _o_hp_disp: float = 0.0

# ── Scoring ───────────────────────────────────────────────────────────────────
var _score:     int   = 0
var _combo:     int   = 0   # consecutive correct
var _best_combo:int   = 0
var _p_dmg:     int   = 8   # damage player takes on wrong
var _o_dmg:     int   = 0   # computed per question

# ── Visual effects ─────────────────────────────────────────────────────────────
var _time:          float = 0.0
var _flash_t:       float = 0.0
var _flash_col:     Color = Color.TRANSPARENT
var _glow_t:        float = 0.0
var _shake_t:       float = 0.0
var _shake_offset:  Vector2 = Vector2.ZERO
var _result_text:   String = ""
var _explain_text:  String = ""
var _acols:         Array  = []
var _show_combo:    bool   = false
var _combo_t:       float  = 0.0

# ── Sprite animation ───────────────────────────────────────────────────────────
var _oracle_bob:  float = 0.0
var _oracle_glow: float = 0.0
var _player_bob:  float = 0.0

# ── Menu ───────────────────────────────────────────────────────────────────────
var _menu_sel:  int  = 0     # 0=FIGHT 1=HINT 2=SKIP
var _in_answer: bool = false
var _hint_used: bool = false
var _hint_text: String = ""
var _show_hint: bool  = false

# ── Particles (answer sparks) ─────────────────────────────────────────────────
var _sparks: Array = []

# ── Gen 1/2 Palette + Oracle-specific ─────────────────────────────────────────
const BG1  := Color("#e8e8d0"); const BG2  := Color("#d8d8c0")
const BOX  := Color("#f8f8f0"); const DK   := Color("#181010")
const HP_G := Color("#50d030"); const HP_Y := Color("#f8c800"); const HP_R := Color("#e82020")
const HP_BK:= Color("#282828"); const GOLD := Color("#ffd700")
const SILV := Color("#c0c8ff"); const GLOW := Color("#f8e000")
const SEL  := Color("#4888d0")

# ═══════════════════════════════════════════════════════════════════════════════
#  SETUP
# ═══════════════════════════════════════════════════════════════════════════════
func setup(data: Dictionary, dialog_node: Node) -> void:
	_data    = data
	_qs      = data.get("questions", [])
	_dialog  = dialog_node
	_qi      = 0; _sel = 0; _score = 0; _combo = 0
	_menu_sel = 0; _in_answer = false; _hint_used = false
	_phase   = Phase.INTRO
	_acols   = [BOX, BOX, BOX, BOX]

	# HP scaled to level + attempt (harder each attempt)
	var lv      := GameManager.get_level()
	var attempt := data.get("attempt", 1)
	_p_hp    = GameManager.get_hp()
	_p_max   = GameManager.get_max_hp()
	_p_hp_disp = float(_p_hp)
	# Oracle HP scales with question count
	_o_max   = _qs.size() * (10 + attempt * 2)
	_o_hp    = _o_max
	_o_hp_disp = float(_o_hp)
	# Damage per correct answer = fraction of oracle HP
	_o_dmg   = max(8, int(_o_max / _qs.size()))
	# Player damage scales with attempt
	_p_dmg   = 6 + attempt * 2

	set_process(true); set_process_input(false)
	call_deferred("_intro")

func _intro() -> void:
	if _dialog:
		_dialog.show_lines(_data.get("intro", ["Oracle Battle begins!"]),
			func(): _phase = Phase.MENU; set_process_input(true))

# ═══════════════════════════════════════════════════════════════════════════════
#  INPUT
# ═══════════════════════════════════════════════════════════════════════════════
func _input(ev: InputEvent) -> void:
	if _phase not in [Phase.MENU]:
		return
	if not _in_answer:
		_menu_nav(ev)
	else:
		_answer_nav(ev)

func _menu_nav(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_left"):
		_menu_sel = max(0, _menu_sel - 1); queue_redraw()
	elif ev.is_action_pressed("ui_down") or ev.is_action_pressed("ui_right"):
		_menu_sel = min(2, _menu_sel + 1); queue_redraw()
	elif ev.is_action_pressed("ui_accept"):
		_menu_action(); ev.get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var mi := _menu_hit(ev.position)
		if mi >= 0: _menu_sel = mi; _menu_action()
		ev.get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var mi := _menu_hit(ev.position)
		if mi >= 0 and mi != _menu_sel: _menu_sel = mi; queue_redraw()

func _answer_nav(ev: InputEvent) -> void:
	var opts := _qs[_qi].get("opts", []) if _qi < _qs.size() else []
	if ev.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + opts.size()) % opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % opts.size(); queue_redraw()
	elif ev.is_action_pressed("ui_accept"):
		_submit(); ev.get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_cancel"):
		_in_answer = false; queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var idx := _answer_hit(ev.position)
		if idx >= 0: _sel = idx; _submit()
		ev.get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var idx := _answer_hit(ev.position)
		if idx >= 0 and idx != _sel: _sel = idx; queue_redraw()

func _menu_action() -> void:
	match _menu_sel:
		0: _in_answer = true; _sel = 0; queue_redraw()
		1: _use_hint()
		2: _skip()

func _use_hint() -> void:
	if _hint_used:
		_hint_text = "Hint already used\nfor this question!"
	else:
		_hint_used = true
		var q := _qs[_qi]; var opts := q.get("opts", []); var ans := q.ans
		_hint_text = "Hint: Answer starts with\n'" + (opts[ans].substr(0, 4) if opts.size() > ans else "?") + "...'"
	_show_hint = true; queue_redraw()

func _skip() -> void:
	_hint_used = false; _show_hint = false; _hint_text = ""
	_acols = [BOX, BOX, BOX, BOX]; _combo = 0
	_qi += 1
	if _qi >= _qs.size(): _conclude()
	else: _sel = 0; _menu_sel = 0; _in_answer = false; queue_redraw()

func _submit() -> void:
	if _qi >= _qs.size(): return
	set_process_input(false)
	_phase = Phase.ANSWERING
	var q  := _qs[_qi]
	var ok := (q.ans == _sel)
	_explain_text = q.get("explain", "")
	_hint_used    = false; _show_hint = false
	_acols        = [BOX, BOX, BOX, BOX]

	# Record in adaptive system (try to infer world from topic)
	var topic := q.get("topic", "general")
	var world := _infer_world(topic)
	AdaptiveAI.record_answer(topic, ok)

	if ok:
		_acols[_sel] = HP_G
		_result_text  = _combo_message(_combo + 1)
		_combo        += 1
		_best_combo    = max(_best_combo, _combo)
		_score         = min(100, _score + int(100.0 / _qs.size()))
		_o_hp          = max(0, _o_hp - _o_dmg)
		_glow_t        = 1.0
		_flash_col     = Color(GLOW, 0.25)
		_spawn_sparks(true)
	else:
		_acols[_sel]   = HP_R
		_acols[q.ans]  = HP_G
		_result_text   = _fail_message()
		_combo         = 0
		_p_hp          = max(0, _p_hp - _p_dmg)
		GameManager.take_damage(_p_dmg)
		_shake_t       = 0.6; _shake_offset = Vector2.ZERO
		_flash_col     = Color(HP_R, 0.3)
		_spawn_sparks(false)

	_flash_t = 0.0
	queue_redraw()

func _combo_message(c: int) -> String:
	if c >= 5:  return "COMBO x" + str(c) + "!  CRITICAL HIT!"
	if c >= 3:  return "COMBO x" + str(c) + "!  SUPER EFFECTIVE!"
	if c >= 2:  return "CORRECT!  Combo x" + str(c) + "!"
	return "Correct!  It's super effective!"

func _fail_message() -> String:
	var msgs := ["Not very effective...", "The Oracle counters!", "Knowledge gap found!",
	             "Study harder...", "The Fog advances!"]
	return msgs[randi() % msgs.size()]

func _infer_world(topic: String) -> String:
	var math_topics   := ["variables","linear","functions","quadratic"]
	var english_topics:= ["nouns","verbs","adjectives","sentences","advanced"]
	var music_topics  := ["staff","notes","chords","scales","time"]
	if topic in math_topics:    return "math"
	if topic in english_topics: return "english"
	if topic in music_topics:   return "music"
	return "math"

func _spawn_sparks(correct: bool) -> void:
	var col := HP_G if correct else HP_R
	for i in 12:
		_sparks.append({
			"x":   240.0 + randf_range(-20, 20),
			"y":   80.0  + randf_range(-20, 20),
			"vx":  randf_range(-3.0, 3.0),
			"vy":  randf_range(-4.0, -1.0),
			"life":randf_range(0.3, 0.8),
			"max": 0.6,
			"col": col,
			"size":randf_range(2.0, 5.0),
		})

# ── Process ────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	_oracle_bob  = sin(_time * 1.4) * 3.0
	_oracle_glow = 0.5 + 0.5 * sin(_time * 2.0)
	_player_bob  = sin(_time * 1.8 + 1.0) * 2.0

	# Animate HP bars toward actual values
	_p_hp_disp = lerp(_p_hp_disp, float(_p_hp), delta * 4.0)
	_o_hp_disp = lerp(_o_hp_disp, float(_o_hp), delta * 4.0)

	# Screen shake decay
	if _shake_t > 0.0:
		_shake_t = max(0.0, _shake_t - delta)
		var mag := _shake_t * _shake_t * 8.0
		_shake_offset = Vector2(randf_range(-mag, mag), randf_range(-mag * 0.5, mag * 0.5))
	else:
		_shake_offset = Vector2.ZERO

	# Glow decay
	if _glow_t > 0.0: _glow_t = max(0.0, _glow_t - delta * 1.5)

	# Combo timer
	if _show_combo: _combo_t = max(0.0, _combo_t - delta); if _combo_t <= 0: _show_combo = false

	# Result display timer
	if _phase == Phase.ANSWERING:
		_flash_t += delta
		if _flash_t >= 2.4: _after_result()

	# Particle update
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.x += s.vx; s.y += s.vy; s.vy += 0.12; s.life -= delta
		if s.life <= 0: _sparks.remove_at(i)

	# Win/lose animation phases
	if _phase == Phase.WIN_ANIM:
		_flash_t += delta
		if _flash_t >= 3.0: _end_battle(true)
	if _phase == Phase.LOSE_ANIM:
		_flash_t += delta
		if _flash_t >= 2.5: _end_battle(false)

	queue_redraw()

func _after_result() -> void:
	_result_text  = ""; _explain_text = ""
	_flash_col    = Color.TRANSPARENT
	_acols        = [BOX, BOX, BOX, BOX]
	_flash_t      = 0.0

	if _o_hp <= 0: _conclude_win(); return
	if _p_hp <= 0: _conclude_lose(); return
	_qi += 1
	if _qi >= _qs.size(): _conclude(); return

	_sel = 0; _menu_sel = 0; _in_answer = false; _hint_used = false; _show_hint = false
	_phase = Phase.MENU; set_process_input(true); queue_redraw()

func _conclude() -> void:
	if _o_hp < _p_hp: _conclude_win()
	elif _p_hp <= 0:  _conclude_lose()
	else: _conclude_win()  # if score >= 60% = win

func _conclude_win() -> void:
	_phase   = Phase.WIN_ANIM
	_flash_t = 0.0
	set_process_input(false)

func _conclude_lose() -> void:
	_phase   = Phase.LOSE_ANIM
	_flash_t = 0.0
	set_process_input(false)

func _end_battle(won: bool) -> void:
	_phase = Phase.ENDED
	AdaptiveAI.end_session()
	oracle_ended.emit(won)

# ── Hit testing ────────────────────────────────────────────────────────────────
func _menu_hit(pos: Vector2) -> int:
	const W := 480; const H := 320; const MY := 166
	for mi in 3:
		var iy := MY + 8 + mi * 22
		if pos.x >= W/2 + 8 and pos.x <= W - 8 and pos.y >= iy and pos.y <= iy + 22:
			return mi
	return -1

func _answer_hit(pos: Vector2) -> int:
	const MY := 166; const W := 480; const H := 320
	var rw := W/2 - 2
	for i in 4:
		var row := i / 2; var col := i % 2
		var ox2 := W/2 + 8 + col * (rw/2 - 4)
		var oy2 := MY + 14 + row * ((H - MY - 8) / 2)
		var bw  := rw/2 - 8; var bh := (H - MY - 10) / 2 - 4
		if pos.x >= ox2 and pos.x <= ox2+bw and pos.y >= oy2 and pos.y <= oy2+bh:
			return i
	return -1

# ═══════════════════════════════════════════════════════════════════════════════
#  PRODUCTION-LEVEL DRAW
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	if _qs.is_empty(): return
	const W := 480; const H := 320
	var fnt := ThemeDB.fallback_font
	var q   := _qs[_qi] if _qi < _qs.size() else {}
	var so  := _shake_offset

	# ── Background: Battle arena ───────────────────────────────────────────
	_draw_bg(W, H)

	# ── Battle platforms ───────────────────────────────────────────────────
	_draw_platform(W - 230, 65, 130, false)
	_draw_platform(20, 105, 110, true)

	# ── Oracle sprite (top right, shaking on player wrong answer) ──────────
	var ox := int(W - 185 + so.x)
	var oy := int(8 + _oracle_bob + so.y * 0.3)
	_draw_oracle_sprite(ox, oy)

	# ── Player sprite (bottom left, shaking on wrong) ──────────────────────
	var px2 := int(40 + so.x * 1.2)
	var py2  := int(62 + _player_bob)
	_draw_player_sprite(px2, py2)

	# ── Particles (sparks) ────────────────────────────────────────────────
	for s in _sparks:
		var a := clampf(s.life / s.max, 0.0, 1.0)
		draw_rect(Rect2(s.x, s.y, s.size, s.size), Color(s.col.r, s.col.g, s.col.b, a))

	# ── Oracle HP box (top-left) ──────────────────────────────────────────
	_draw_hp_box(6, 6, 230, "THE ORACLE", "Ancient Guardian",
		int(_o_hp_disp), _o_max, 99, SILV, true, fnt)

	# ── Player HP box (bottom-right of top half) ──────────────────────────
	_draw_hp_box(W - 240, H/2 - 62, 234, GameManager.player_name.to_upper(),
		"Lv." + str(GameManager.get_level()), int(_p_hp_disp), _p_max,
		GameManager.get_level(), SILV, false, fnt)

	# ── Divider ───────────────────────────────────────────────────────────
	draw_rect(Rect2(0, H/2, W, 4), DK)

	# ── Bottom menu ──────────────────────────────────────────────────────
	var my := H/2 + 6
	draw_rect(Rect2(0, my, W, H - my), BOX)
	_draw_menu(my, W, H, q, fnt)

	# ── Score strip ───────────────────────────────────────────────────────
	draw_rect(Rect2(0, H - 5, W, 5), DK)
	draw_rect(Rect2(1, H - 4, W - 2, 3), HP_BK)
	draw_rect(Rect2(1, H - 4, int((W - 2) * float(_score) / 100.0), 3), SILV)

	# ── Glow overlay (correct answer) ────────────────────────────────────
	if _glow_t > 0.0:
		var ga := _glow_t * 0.5
		draw_rect(Rect2(0, 0, W, H/2), Color(GLOW.r, GLOW.g, GLOW.b, ga * 0.3))
		for i in 8:
			var angle := float(i) / 8.0 * TAU
			var length := 50.0 * (1.0 - _glow_t)
			draw_line(Vector2(W - 165, 40),
				Vector2(W - 165 + cos(angle)*length, 40 + sin(angle)*length),
				Color(GLOW, ga * 1.5), 2.5)

	# ── Flash overlay ────────────────────────────────────────────────────
	if _flash_t > 0.0 and _phase == Phase.ANSWERING and _flash_col.a > 0.01:
		var fa := maxf(0.0, _flash_col.a - _flash_t * 0.12)
		draw_rect(Rect2(0, 0, W, H), Color(_flash_col.r, _flash_col.g, _flash_col.b, fa))

	# ── Win animation ─────────────────────────────────────────────────────
	if _phase == Phase.WIN_ANIM:
		_draw_win_anim(W, H, fnt)
	elif _phase == Phase.LOSE_ANIM:
		_draw_lose_anim(W, H, fnt)

	# ── Combo banner ─────────────────────────────────────────────────────
	if _combo >= 2 and _phase == Phase.MENU:
		var ca := minf(_combo_t, 1.0)
		draw_rect(Rect2(W/2 - 80, 3, 160, 14), Color(0, 0, 0, 0.7 * ca))
		draw_string(fnt, Vector2(W/2 - 60, 14),
			"🔥 COMBO x" + str(_combo) + " 🔥",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD.r, GOLD.g, GOLD.b, ca))

# ── Background ────────────────────────────────────────────────────────────────
func _draw_bg(W: int, H: int) -> void:
	# Top: deep night sky arena
	for y in range(0, H/2, 4):
		var t := float(y) / float(H/2)
		draw_rect(Rect2(0, y, W, 4), Color(
			lerp(0.04, 0.08, t), lerp(0.02, 0.05, t), lerp(0.12, 0.18, t)))
	# Arena floor (Gen 1/2 checkered grass)
	for y in range(0, H/2, 4):
		for x in range(0, W, 4):
			if ((x/4 + y/4) % 2) == 0:
				draw_rect(Rect2(x, y, 4, 4), Color(0.0, 0.0, 0.0, 0.04))
	# Distant mountains silhouettes in background
	var mc := Color(0.06, 0.05, 0.15, 0.6)
	draw_colored_polygon(PackedVector2Array([Vector2(0,H/2),Vector2(60,H/4),Vector2(140,H/2)]),
		PackedColorArray([mc,mc,mc]))
	draw_colored_polygon(PackedVector2Array([Vector2(100,H/2),Vector2(220,H/5),Vector2(350,H/2)]),
		PackedColorArray([mc,mc,mc]))
	draw_colored_polygon(PackedVector2Array([Vector2(300,H/2),Vector2(400,H/4+10),Vector2(W,H/2)]),
		PackedColorArray([mc,mc,mc]))
	# Silver mountain peak hint (background deco)
	var sp := Color(0.35, 0.38, 0.6, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(200,H/2),Vector2(240,H/5-10),Vector2(280,H/2)]),
		PackedColorArray([sp,sp,sp]))
	var sg := 0.4 + 0.3 * sin(_time * 2.0)
	draw_rect(Rect2(234, H/5 - 16, 12, 8), Color(0.8, 0.85, 1.0, sg))

# ── Platform ──────────────────────────────────────────────────────────────────
func _draw_platform(px: int, py: int, pw: int, is_player: bool) -> void:
	var pc := Color("#b8b060") if is_player else Color("#9898a0")
	draw_rect(Rect2(px-10, py+12, pw+20, 10), pc.darkened(0.35))
	draw_rect(Rect2(px-14, py+14, pw+28, 8), pc)
	draw_rect(Rect2(px-16, py+16, pw+32, 5), pc.lightened(0.18))

# ── Oracle Sprite (alien AI entity — geometric + glowing) ─────────────────────
func _draw_oracle_sprite(ox: int, oy: int) -> void:
	var glow_a := _oracle_glow * 0.6
	var pulse := 0.7 + 0.3 * sin(_time * 3.0)

	# Outer aura
	draw_rect(Rect2(ox+2, oy+2, 56, 68), Color(SILV.r, SILV.g, SILV.b, glow_a * 0.2))

	# Robe body
	draw_rect(Rect2(ox+8, oy+30, 36, 28), Color(0.15, 0.12, 0.35))
	draw_rect(Rect2(ox+8, oy+30, 36, 6),  Color(0.25, 0.22, 0.55))
	draw_rect(Rect2(ox+8, oy+30, 36, 28), DK, false, 1.0)
	# Robe inner glow stripe
	draw_rect(Rect2(ox+14, oy+34, 4, 20), Color(SILV.r, SILV.g, SILV.b, glow_a * 0.5))

	# Arms
	draw_rect(Rect2(ox+2,  oy+32, 7, 16), Color(0.15, 0.12, 0.35))
	draw_rect(Rect2(ox+2,  oy+32, 7, 16), DK, false, 1.0)
	draw_rect(Rect2(ox+43, oy+32, 7, 16), Color(0.15, 0.12, 0.35))
	draw_rect(Rect2(ox+43, oy+32, 7, 16), DK, false, 1.0)

	# Head: ancient mask
	draw_rect(Rect2(ox+12, oy+8, 28, 24), Color(0.20, 0.18, 0.40))
	draw_rect(Rect2(ox+12, oy+8, 28, 24), DK, false, 1.5)
	# Forehead gem
	draw_rect(Rect2(ox+22, oy+9, 8, 6), Color(SILV.r, SILV.g, SILV.b, pulse))
	draw_rect(Rect2(ox+23, oy+10, 6, 4), Color(1.0, 1.0, 1.0, pulse * 0.6))
	# Eye slits (glowing)
	draw_rect(Rect2(ox+16, oy+18, 8, 4), Color(SILV.r, SILV.g, SILV.b, pulse))
	draw_rect(Rect2(ox+28, oy+18, 8, 4), Color(SILV.r, SILV.g, SILV.b, pulse))
	draw_rect(Rect2(ox+17, oy+19, 6, 2), Color(1.0, 1.0, 1.0, pulse * 0.7))
	draw_rect(Rect2(ox+29, oy+19, 6, 2), Color(1.0, 1.0, 1.0, pulse * 0.7))
	# Hood
	draw_rect(Rect2(ox+10, oy+5, 32, 12), Color(0.10, 0.08, 0.28))
	draw_rect(Rect2(ox+10, oy+5, 32, 12), DK, false, 1.0)
	draw_rect(Rect2(ox+14, oy+5, 24, 4),  Color(SILV.r, SILV.g, SILV.b, 0.3))
	# Floating knowledge orbs around the Oracle
	for i in 3:
		var angle := _time * 1.5 + i * TAU / 3.0
		var rx := ox + 28 + int(cos(angle) * 22)
		var ry := oy + 28 + int(sin(angle) * 16)
		var oc := [SILV, GOLD, Color("#ff88ff")][i]
		draw_rect(Rect2(rx, ry, 5, 5), Color(oc.r, oc.g, oc.b, 0.6 + 0.4 * sin(_time * 2 + i)))
		draw_rect(Rect2(rx+1, ry+1, 3, 3), Color(1, 1, 1, 0.4))

# ── Player sprite (Gen 1/2 back view) ─────────────────────────────────────────
func _draw_player_sprite(ox: int, oy: int) -> void:
	draw_rect(Rect2(ox+4, oy+44, 26, 6), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(ox+6,  oy+38, 9, 8), Color("#181888")); draw_rect(Rect2(ox+6,  oy+38, 9, 8), DK, false, 1.0)
	draw_rect(Rect2(ox+19, oy+38, 9, 8), Color("#181888")); draw_rect(Rect2(ox+19, oy+38, 9, 8), DK, false, 1.0)
	draw_rect(Rect2(ox+4,  oy+22, 26, 18), Color("#c01010"))
	draw_rect(Rect2(ox+4,  oy+22, 26, 5),  Color("#e01818")); draw_rect(Rect2(ox+4,  oy+22, 26, 18), DK, false, 1.0)
	draw_rect(Rect2(ox+0,  oy+23, 5, 14),  Color("#f0c890")); draw_rect(Rect2(ox+0,  oy+23, 5, 14), DK, false, 1.0)
	draw_rect(Rect2(ox+29, oy+23, 5, 14),  Color("#f0c890")); draw_rect(Rect2(ox+29, oy+23, 5, 14), DK, false, 1.0)
	draw_rect(Rect2(ox+9,  oy+8, 16, 16),  Color("#f0c890")); draw_rect(Rect2(ox+9,  oy+8, 16, 16), DK, false, 1.0)
	draw_rect(Rect2(ox+7,  oy+8, 20, 6),   Color("#c01010")); draw_rect(Rect2(ox+6,  oy+11, 22, 5), Color("#c01010"))
	draw_rect(Rect2(ox+7,  oy+8, 20, 6),   DK, false, 1.0); draw_rect(Rect2(ox+14, oy+9, 5, 4), GOLD)
	draw_rect(Rect2(ox+11, oy+15, 3, 3), DK); draw_rect(Rect2(ox+18, oy+15, 3, 3), DK)

# ── HP box (Gen 1/2 style) ─────────────────────────────────────────────────────
func _draw_hp_box(bx:int,by:int,bw:int,name:String,sub:String,hp:int,max_hp:int,lv:int,wcol:Color,is_enemy:bool,fnt:Font)->void:
	var bh := 54
	draw_rect(Rect2(bx,by,bw,bh), DK)
	draw_rect(Rect2(bx+2,by+2,bw-4,bh-4), BOX)
	draw_rect(Rect2(bx+2,by+2,bw-4,bh-4), DK, false, 1.5)
	# Header stripe
	draw_rect(Rect2(bx+2,by+2,bw-4,14), Color(wcol.r*0.25, wcol.g*0.25, wcol.b*0.4))
	draw_string(fnt, Vector2(bx+7,by+13), name, HORIZONTAL_ALIGNMENT_LEFT,-1,12, DK)
	draw_string(fnt, Vector2(bx+bw-48,by+13), ":Lv"+str(lv), HORIZONTAL_ALIGNMENT_LEFT,-1,11, DK)
	# HP label + bar
	draw_string(fnt, Vector2(bx+7,by+28), "HP", HORIZONTAL_ALIGNMENT_LEFT,-1,10, DK)
	var hp_f := float(hp) / float(max(max_hp, 1))
	var hcol := HP_G if hp_f > 0.5 else (HP_Y if hp_f > 0.25 else HP_R)
	var bx2 := bx+28; var bw2 := bw-36; var by2 := by+22
	draw_rect(Rect2(bx2,by2,bw2,8), DK)
	draw_rect(Rect2(bx2+1,by2+1,bw2-2,6), HP_BK)
	draw_rect(Rect2(bx2+1,by2+1,int((bw2-2)*hp_f),6), hcol)
	# HP number (player only)
	if not is_enemy:
		draw_string(fnt, Vector2(bx+bw-78,by+43), str(hp)+"/"+str(max_hp), HORIZONTAL_ALIGNMENT_LEFT,-1,11, DK)
	# EXP bar
	if not is_enemy:
		var xp_f := float(GameManager.get_xp())/float(GameManager.get_xp_max())
		draw_rect(Rect2(bx+2,by+bh-6,bw-4,4), DK)
		draw_rect(Rect2(bx+3,by+bh-5,bw-6,2), HP_BK)
		draw_rect(Rect2(bx+3,by+bh-5,int((bw-6)*xp_f),2), Color("#6898f0"))
	# Boss-specific: Oracle question counter instead of numbers
	if is_enemy:
		draw_string(fnt, Vector2(bx+7,by+43), "Questions: "+str(_qi)+"/"+str(_qs.size()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,10, DK)

# ── Bottom menu ────────────────────────────────────────────────────────────────
func _draw_menu(my: int, W: int, H: int, q: Dictionary, fnt: Font) -> void:
	var lw := W/2 - 2; var rw := W/2 - 2

	# LEFT PANEL
	draw_rect(Rect2(2, my, lw, H-my-4), DK)
	draw_rect(Rect2(4, my+2, lw-4, H-my-8), BOX)
	draw_rect(Rect2(4, my+2, lw-4, H-my-8), DK, false, 1.5)

	if _result_text != "":
		var rc := HP_G if _result_text.begins_with("C") or _result_text.begins_with("COMBO") or _result_text.begins_with("super") else HP_R
		draw_rect(Rect2(4, my+2, lw-4, 18), Color(rc.r*0.3, rc.g*0.3, rc.b*0.3))
		draw_string(fnt, Vector2(10, my+15), _result_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, lw-10, 11, rc)
		if _explain_text != "":
			var el := _explain_text.split("\n")
			for ei in el.size():
				draw_string(fnt, Vector2(10, my+32+ei*16), el[ei], HORIZONTAL_ALIGNMENT_LEFT, lw-10, 11, DK)
	elif _show_hint:
		var hl := _hint_text.split("\n")
		for hi in hl.size():
			draw_string(fnt, Vector2(10, my+16+hi*16), hl[hi].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, lw-10, 12, DK)
	else:
		var qt := q.get("q", "...").split("\n")
		for qi2 in qt.size():
			draw_string(fnt, Vector2(10, my+16+qi2*16), qt[qi2].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, lw-10, 12, DK)
		# Topic badge
		var topic := q.get("topic", "")
		if topic != "":
			draw_rect(Rect2(4, H-my-20, len(topic)*7+12, 14), Color(SILV.r, SILV.g, SILV.b, 0.4))
			draw_string(fnt, Vector2(10, H-my-8), topic.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DK)

	# RIGHT PANEL
	draw_rect(Rect2(W/2+2, my, rw-4, H-my-4), DK)
	draw_rect(Rect2(W/2+4, my+2, rw-8, H-my-8), BOX)
	draw_rect(Rect2(W/2+4, my+2, rw-8, H-my-8), DK, false, 1.5)

	if not _in_answer:
		# FIGHT / HINT / SKIP
		var items := ["FIGHT", "HINT", "SKIP"]
		for mi in items.size():
			var iy := my + 12 + mi * 22
			var sel := (_menu_sel == mi and _phase == Phase.MENU)
			if sel:
				draw_rect(Rect2(W/2+6, iy-12, rw-12, 20), Color(SEL.r, SEL.g, SEL.b, 0.2))
				draw_colored_polygon(
					PackedVector2Array([Vector2(W/2+14,iy-6), Vector2(W/2+20,iy-1), Vector2(W/2+14,iy+4)]),
					PackedColorArray([DK,DK,DK]))
			draw_string(fnt, Vector2(W/2+26, iy+4), items[mi], HORIZONTAL_ALIGNMENT_LEFT,-1,14,
				GOLD if sel else DK)
		# Score
		draw_string(fnt, Vector2(W/2+10, H-my-22), "SCORE: "+str(_score)+"%",
			HORIZONTAL_ALIGNMENT_LEFT,-1,10, Color(0.4,0.4,0.5))
	else:
		# Answer options (2×2 grid)
		var opts := q.get("opts", [])
		for i in opts.size():
			var row := i/2; var col := i%2
			var ox2 := W/2+8+col*(rw/2-4)
			var oy2 := my+14+row*((H-my-8)/2)
			var bw2 := rw/2-8; var bh2 := (H-my-10)/2-4
			var bg  := _acols[i] if i < _acols.size() else BOX
			var sel := (i == _sel and _phase == Phase.MENU)
			draw_rect(Rect2(ox2, oy2, bw2, bh2), DK)
			draw_rect(Rect2(ox2+2, oy2+2, bw2-4, bh2-4), bg)
			if sel: draw_rect(Rect2(ox2+2, oy2+2, bw2-4, bh2-4), Color(SEL.r, SEL.g, SEL.b, 0.3))
			if sel:
				draw_colored_polygon(
					PackedVector2Array([Vector2(ox2+4,oy2+8),Vector2(ox2+10,oy2+13),Vector2(ox2+4,oy2+18)]),
					PackedColorArray([DK,DK,DK]))
			draw_string(fnt, Vector2(ox2+14, oy2+18),
				["A","B","C","D"][i]+". "+opts[i],
				HORIZONTAL_ALIGNMENT_LEFT, bw2-20, 11, DK)
			# Mouse hover highlight
			if sel:
				draw_rect(Rect2(ox2, oy2, bw2, bh2), Color(SILV.r, SILV.g, SILV.b, 0.15), false, 2.0)

# ── Win animation ─────────────────────────────────────────────────────────────
func _draw_win_anim(W: int, H: int, fnt: Font) -> void:
	var t := minf(_flash_t / 3.0, 1.0)
	# Expanding golden rings
	for i in 4:
		var r := int(50.0 + i * 40.0 + _flash_t * 60.0)
		var a := maxf(0.0, 0.7 - _flash_t * 0.2 - i * 0.12)
		draw_arc(Vector2(W/2, H/2), r, 0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, a), 2.5)
	# Gold flash
	draw_rect(Rect2(0,0,W,H), Color(GOLD.r, GOLD.g, GOLD.b, minf(_flash_t * 0.15, 0.5)))
	# KAISER text
	if _flash_t > 1.0:
		var ta := minf((_flash_t - 1.0) * 2.0, 1.0)
		draw_rect(Rect2(W/2-130, H/2-30, 260, 60), Color(0,0,0,0.8*ta))
		draw_string(fnt, Vector2(W/2-80, H/2-6), "★ KAISER ★",
			HORIZONTAL_ALIGNMENT_LEFT,-1,22, Color(GOLD.r,GOLD.g,GOLD.b,ta))
		draw_string(fnt, Vector2(W/2-106, H/2+18),
			GameManager.player_name+" has been acknowledged!",
			HORIZONTAL_ALIGNMENT_LEFT,-1,13, Color(1,1,1,ta))

# ── Lose animation ─────────────────────────────────────────────────────────────
func _draw_lose_anim(W: int, H: int, fnt: Font) -> void:
	var t := minf(_flash_t / 2.5, 1.0)
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, t * 0.75))
	if _flash_t > 0.8:
		var ta := minf((_flash_t - 0.8) * 2.0, 1.0)
		draw_rect(Rect2(W/2-130, H/2-28, 260, 56), Color(0.1,0.0,0.0,0.9*ta))
		draw_rect(Rect2(W/2-130, H/2-28, 260, 56), Color(HP_R.r,HP_R.g,HP_R.b,0.5*ta), false, 2.0)
		draw_string(fnt, Vector2(W/2-70, H/2-8), "DEFEATED...",
			HORIZONTAL_ALIGNMENT_LEFT,-1,18, Color(HP_R.r,HP_R.g,HP_R.b,ta))
		draw_string(fnt, Vector2(W/2-84, H/2+14), "The Oracle is not satisfied.",
			HORIZONTAL_ALIGNMENT_LEFT,-1,12, Color(0.8,0.6,0.6,ta))
