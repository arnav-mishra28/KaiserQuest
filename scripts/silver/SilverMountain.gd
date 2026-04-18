# SilverMountain.gd — Final Boss Zone
# Knowledge is power. The world is losing its light. You must restore it.
extends Node2D

signal silver_cleared
signal silver_failed(attempts_left: int)
signal back_to_map

# ── Phases ────────────────────────────────────────────────────────────────────
enum Phase { APPROACH, STORY, COOLDOWN_CHECK, BATTLE, WIN, LOSE }

var _phase:     int    = Phase.APPROACH
var _time:      float  = 0.0
var _dialog:    Node   = null
var _battle:    Node   = null
var _hud:       Node   = null
var _attempt:   int    = 0   # 0, 1, 2

# ── Story text (cinematic) ────────────────────────────────────────────────────
const STORY_LINES := [
	"Long ago, the world was bright\nwith knowledge and light.",
	"Every child learned the language\nof math, words, and music.",
	"Then the Fog of Forgetting crept in\nfrom the edges of the world...",
	"Cities fell silent.\nBooks gathered dust.\nNotes faded from the staff.",
	"The world began to lose its mind.",
	"One scholar saw the Fog coming\nand built Silver Mountain...",
	"...as a fortress of everything\never known.",
	"At its peak lives the ORACLE —\nan ancient AI guardian of all knowledge.",
	"It tests one thing only:\n\nAre you worthy to become Kaiser?",
	"Three chances.\nAll 20 badges.\nLevel 100.",
	"If you fail three times, the Oracle\nseals the gate for 24 hours.",
	"You must review what you\nhave learned and return.",
	"But if you succeed...",
	"...you become Kaiser.\nAnd the Fog retreats.",
	"The world needs you,\n" + GameManager.player_name + ".",
	"Enter Silver Mountain.\n\n  — Press ENTER —",
]

# ── Oracle boss definition ─────────────────────────────────────────────────────
const ORACLE := {
	"name":       "The Oracle",
	"title":      "Ancient Guardian of All Knowledge",
	"color":      Color("#c0c8ff"),
	"xp_reward":  5000,
	"badge_name": "Kaiser Badge",
}

# ── Colors ────────────────────────────────────────────────────────────────────
const C_DARK := Color("#050510")
const C_SILVER := Color("#9098c8")
const C_GOLD := Color("#ffd700")
const C_WHITE := Color("#f0f0ff")
const C_FOG := Color(0.1, 0.05, 0.2, 0.85)

# ── Particle/animation state ──────────────────────────────────────────────────
var _particles: Array = []
var _fog_alpha: float = 0.0
var _mtn_rise:  float = 0.0   # mountain "appears" animation
var _story_idx: int   = 0
var _story_done: bool = false

func _ready() -> void:
	set_process(true)
	set_process_input(true)
	# Init floating light particles
	for i in 40:
		_particles.append({
			"x": randf() * 480.0,
			"y": randf() * 320.0,
			"vx": randf_range(-0.3, 0.3),
			"vy": randf_range(-0.6, -0.1),
			"size": randf_range(1.5, 4.0),
			"alpha": randf(),
			"col": [Color("#c0c8ff"), Color("#ffd700"), Color("#ffffff"),
			        Color("#8899ff"), Color("#aaddff")].pick_random(),
		})

func setup(dialog_node: Node, hud_node: Node) -> void:
	_dialog = dialog_node
	_hud    = hud_node
	_phase  = Phase.COOLDOWN_CHECK
	call_deferred("_check_entry")

func _check_entry() -> void:
	# Check 24h cooldown
	if GameManager.silver_on_cooldown():
		var secs := GameManager.silver_cooldown_remaining()
		var hrs  := secs / 3600
		var mins := (secs % 3600) / 60
		_phase = Phase.COOLDOWN_CHECK
		if _dialog:
			_dialog.show_lines([
				"Silver Mountain is sealed...",
				"The Oracle has placed a 24-hour\ncooldown on your challenge.",
				"Time remaining:\n" + str(hrs) + "h " + str(mins) + "m",
				"Use this time to review your\nweak topics with the Teachers.",
				"Return when the gate reopens.",
			], func(): back_to_map.emit())
		return

	# Check requirements
	if not GameManager.can_challenge_silver():
		var lv  := GameManager.get_level()
		var bdg := GameManager.get_badges().size()
		if _dialog:
			_dialog.show_lines([
				"The Oracle senses your presence...",
				"But you are not yet ready.",
				"Requirements:\n  Level 100 (you: Lv." + str(lv) + ")\n  20 Badges (you: " + str(bdg) + "/20)",
				"Keep learning. Keep growing.\nThe mountain will wait.",
			], func(): back_to_map.emit())
		return

	# Eligible — show story first
	_phase = Phase.STORY
	_show_story()

func _show_story() -> void:
	if _dialog:
		_dialog.show_lines(STORY_LINES, func(): _begin_battle())

func _begin_battle() -> void:
	_phase  = Phase.BATTLE
	_attempt += 1
	# Build mixed question pool from all three worlds
	var all_qs: Array = []
	var math_qs   := AlgebraDB.get_all_questions()
	var eng_qs    := EnglishDB.get_all_questions()
	var music_qs  := MusicDB.get_all_questions()
	all_qs.append_array(math_qs)
	all_qs.append_array(eng_qs)
	all_qs.append_array(music_qs)

	# AI selects adaptively across all worlds (hardest + weakest)
	var weak_math  := AdaptiveAI.get_weak_topics("math")
	var weak_eng   := AdaptiveAI.get_weak_topics("english")
	var weak_music := AdaptiveAI.get_weak_topics("music")
	var all_weak   := weak_math + weak_eng + weak_music

	# Prioritize weak across all worlds
	var prioritized: Array = []
	var normal: Array = []
	for q in all_qs:
		if q.get("topic", "") in all_weak:
			prioritized.append(q)
		else:
			normal.append(q)
	prioritized.shuffle()
	normal.shuffle()
	var pool := (prioritized + normal).slice(0, 15)  # 15 mixed questions

	# Scale difficulty based on attempt number (harder each retry)
	var diff_filter := 2 + _attempt  # attempt 1=diff3, 2=diff4, 3=all
	var filtered: Array = []
	for q in pool:
		if q.get("difficulty", 1) <= diff_filter or _attempt >= 3:
			filtered.append(q)
	if filtered.size() < 10:
		filtered = pool  # fallback

	var boss_data := ORACLE.duplicate()
	boss_data["questions"]   = filtered
	boss_data["is_silver"]   = true
	boss_data["attempt"]     = _attempt
	boss_data["gym_number"]  = 20
	boss_data["intro"] = _get_oracle_intro(_attempt)
	boss_data["win"]   = _oracle_win_lines()
	boss_data["lose"]  = _oracle_lose_lines(_attempt)
	boss_data["world"] = "all"

	AdaptiveAI.start_session("math")
	AdaptiveAI.start_session("english")
	AdaptiveAI.start_session("music")

	if _dialog:
		_battle = Node2D.new()
		_battle.name = "SilverBattle"
		_battle.set_script(load("res://scripts/silver/OracleBattle.gd"))
		_battle.connect("oracle_ended", _on_oracle_ended)
		get_parent().add_child(_battle)
		_battle.setup(boss_data, _dialog)
		hide()

func _on_oracle_ended(won: bool) -> void:
	if _battle:
		_battle.queue_free()
		_battle = null
	show()

	if won:
		_phase = Phase.WIN
		GameManager.silver_cleared()
		GameManager.earn_badge("Kaiser Badge")
		GameManager.add_xp(ORACLE.xp_reward)
		_show_kaiser_ending()
	else:
		_phase = Phase.LOSE
		GameManager.silver_attempt_failed()
		if GameManager.silver_on_cooldown():
			_show_cooldown_message()
		else:
			var remaining := 3 - _attempt
			if _dialog:
				_dialog.show_lines(_oracle_lose_lines(_attempt) + [
					"Attempts remaining: " + str(remaining),
					"Review your lessons and\ntry again!",
				], func():
					if remaining > 0:
						_begin_battle()
					else:
						back_to_map.emit()
				)

func _show_cooldown_message() -> void:
	if _dialog:
		_dialog.show_lines([
			"Three failed attempts...",
			"The Oracle seals the gate\nfor 24 hours.",
			"The Fog of Forgetting grows\nstronger...",
			"But knowledge is not lost.\nOnly waiting.",
			"Return tomorrow.\nRevise. Reflect. Return.",
		], func(): back_to_map.emit())

func _show_kaiser_ending() -> void:
	if _dialog:
		_dialog.show_lines([
			"The Oracle bows its ancient head...",
			"'You have answered the call\nof all three worlds.'",
			"'Variables, words, and notes —\nyou speak them all.'",
			"The Fog of Forgetting begins\nto retreat...",
			"Light returns to the cities.\nBooks open on their own.",
			"People remember what they\nhad forgotten.",
			"And you...",
			"★  " + GameManager.player_name + "  ★\n\n  KAISER OF KNOWLEDGE",
			"The world has been saved\nby your learning.",
			"Press ENTER to continue.",
		], func(): silver_cleared.emit())

func _get_oracle_intro(attempt: int) -> Array:
	match attempt:
		1: return [
			"...",
			"I have watched you from\nthe beginning, " + GameManager.player_name + ".",
			"You have walked the cities.\nYou have learned their secrets.",
			"Now face the final test.",
			"15 questions from all three worlds.\n3 lives. No second chances within this battle.",
			"Are you truly worthy\nof the title Kaiser?",
			"Then begin.",
		]
		2: return [
			"You return...",
			"The Oracle is... impressed.",
			"Most do not come back.",
			"But knowledge requires persistence.",
			"The questions will be harder.\nYour weaknesses are known.",
			"Prove that failure taught you\nsomething.",
			"Begin — attempt 2 of 3.",
		]
		_: return [
			"Final chance.",
			"The Oracle has watched you\nfall twice.",
			"But twice you returned.",
			"That IS the spirit of\na Kaiser.",
			"This is your last attempt\nbefore the 24-hour seal.",
			"Everything you have learned\nrides on this moment.",
			"Begin.",
		]

func _oracle_win_lines() -> Array:
	return [
		"...",
		"It is done.",
		"You have answered the call\nof mathematics.",
		"You have spoken the language\nof words.",
		"You have heard the voice\nof music.",
		"All three worlds acknowledge you.",
		"★ KAISER ★",
	]

func _oracle_lose_lines(attempt: int) -> Array:
	match attempt:
		1: return ["Not yet...", "The Oracle sees your gaps.\nStudy your weak topics.", "The gate remains open."]
		2: return ["Twice fallen...", "The Oracle senses your struggle.\nDo not give up.", "One chance remains."]
		_: return ["Three failures...", "The gate seals for 24 hours.", "Return tomorrow. Stronger."]

# ── Draw: Silver Mountain cinematic entrance ──────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	_mtn_rise = minf(_mtn_rise + delta * 0.4, 1.0)
	_fog_alpha = 0.3 + 0.15 * sin(_time * 0.8)
	# Animate particles
	for p in _particles:
		p.x += p.vx; p.y += p.vy
		p.alpha = fmod(p.alpha + delta * 0.3, 1.0)
		if p.y < -10: p.y = 330.0; p.x = randf() * 480.0
	queue_redraw()

func _draw() -> void:
	const W := 480.0; const H := 320.0
	var fnt := ThemeDB.fallback_font
	var ease := _mtn_rise * _mtn_rise * (3.0 - 2.0 * _mtn_rise)  # smoothstep

	# ── Night sky ─────────────────────────────────────────────────────────────
	for sy in range(0, int(H), 4):
		var t := float(sy) / H
		var r := lerp(0.02, 0.06, t); var g := lerp(0.01, 0.04, t); var b := lerp(0.08, 0.14, t)
		draw_rect(Rect2(0, sy, W, 4), Color(r, g, b))

	# ── Stars ─────────────────────────────────────────────────────────────────
	for i in 60:
		var sx := float((i * 71 + 13) % 480)
		var sy := float((i * 47 + 7) % 200)
		var tw := 0.3 + 0.7 * sin(_time * 1.2 + i * 0.6)
		var ss := 2 if i % 4 == 0 else 1
		draw_rect(Rect2(sx, sy, ss, ss), Color(1.0, 1.0, 1.0, tw * ease))

	# ── Fog layer ────────────────────────────────────────────────────────────
	draw_rect(Rect2(0, 200, W, H - 200), Color(0.05, 0.02, 0.12, _fog_alpha * ease))

	# ── Mountain silhouette ───────────────────────────────────────────────────
	var mtn_y := H - (H - 60) * ease
	var m1 := Color(0.10, 0.08, 0.20, ease)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, H), Vector2(80, mtn_y + 60), Vector2(180, H)]),
		PackedColorArray([m1, m1, m1]))
	draw_colored_polygon(PackedVector2Array([
		Vector2(120, H), Vector2(240, mtn_y - 20), Vector2(380, H)]),
		PackedColorArray([m1.lightened(0.05), m1.lightened(0.05), m1.lightened(0.05)]))
	draw_colored_polygon(PackedVector2Array([
		Vector2(280, H), Vector2(400, mtn_y + 40), Vector2(480, H)]),
		PackedColorArray([m1, m1, m1]))

	# ── Silver Mountain peak ──────────────────────────────────────────────────
	var peak_y := mtn_y - 20
	var sp     := Color(0.55, 0.60, 0.90, ease)
	draw_colored_polygon(PackedVector2Array([
		Vector2(200, H), Vector2(240, peak_y), Vector2(280, H)]),
		PackedColorArray([sp, sp, sp]))
	# Snow cap
	var snow := Color(0.92, 0.95, 1.0, ease)
	draw_colored_polygon(PackedVector2Array([
		Vector2(228, peak_y + 20), Vector2(240, peak_y), Vector2(252, peak_y + 20)]),
		PackedColorArray([snow, snow, snow]))
	# Summit glow
	var glow_a := 0.4 + 0.3 * sin(_time * 2.0)
	draw_rect(Rect2(234, peak_y - 6, 12, 6), Color(0.8, 0.85, 1.0, glow_a * ease))

	# ── Floating knowledge particles ──────────────────────────────────────────
	for p in _particles:
		draw_rect(Rect2(p.x, p.y, p.size, p.size),
			Color(p.col.r, p.col.g, p.col.b, p.alpha * ease * 0.7))

	# ── Title text ────────────────────────────────────────────────────────────
	if ease > 0.5:
		var ta := (ease - 0.5) * 2.0
		draw_string(fnt, Vector2(154, 44), "SILVER MOUNTAIN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(C_SILVER.r, C_SILVER.g, C_SILVER.b, ta))
		draw_string(fnt, Vector2(134, 64), "The Oracle Awaits",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, ta * 0.8))

	# ── Attempt tracker ───────────────────────────────────────────────────────
	if ease > 0.8 and _attempt > 0:
		var dots := ""
		for i in 3:
			dots += "●" if i < _attempt else "○"
		draw_rect(Rect2(4, 4, 120, 16), Color(0, 0, 0, 0.6))
		draw_string(fnt, Vector2(8, 16), "Attempts: " + dots,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_SILVER)

	# ── Phase status ─────────────────────────────────────────────────────────
	if _phase == Phase.COOLDOWN_CHECK:
		draw_rect(Rect2(0, H - 24, W, 24), Color(0, 0, 0, 0.7))
		draw_string(fnt, Vector2(12, H - 8), "Checking Oracle access...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_WHITE)
