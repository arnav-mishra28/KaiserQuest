# AdaptiveAI.gd  ——  Real Adaptive Learning Engine (Autoload)
# Tracks: accuracy per topic, answer speed, difficulty progression
# Generates: ordered question pools that target weak areas first
extends Node

# ── Per-world persistent data ─────────────────────────────────────────────────
var _data: Dictionary = {}

# ── Session state (reset each battle/duel) ────────────────────────────────────
var _session_world: String  = ""
var _session_data:  Array   = []
var _q_start:       float   = 0.0

signal weak_topics_updated(world: String, topics: Array)
signal performance_report(world: String, report: Dictionary)

func _ready() -> void:
	for w in ["math", "english", "music"]:
		if w not in _data:
			_data[w] = {
				"topic_accuracy": {},   # topic -> [correct, total, avg_ms]
				"avg_ms":         5000.0,
				"sessions":       0,
				"total_correct":  0,
				"total_q":        0,
				"difficulty_level": 1,  # 1=easy 2=medium 3=hard 4=expert
				"streak":         0,    # current correct streak
				"best_streak":    0,
				"xp_multiplier":  1.0,  # increases with performance
			}
	_load()

# ── Session control ────────────────────────────────────────────────────────────
func start_session(world: String) -> void:
	_session_world = world
	_session_data  = []
	_q_start       = Time.get_ticks_msec()

func record_answer(topic: String, correct: bool) -> void:
	var ms := Time.get_ticks_msec() - _q_start
	_q_start = Time.get_ticks_msec()
	_session_data.append({"topic": topic, "correct": correct, "ms": ms})
	# Update streak live
	if _session_world in _data:
		var d: Dictionary = _data[_session_world]

		if correct:
			d["streak"] = d.get("streak", 0) + 1
			d["best_streak"] = max(d.get("best_streak", 0), d["streak"])
		else:
			d["streak"] = 0

func end_session() -> Dictionary:
	if _session_world == "" or _session_data.is_empty():
		return {}
	var d   = _data[_session_world]
	d.sessions += 1
	var total_ms := 0.0
	var correct  := 0

	for s in _session_data:
		total_ms += float(s.ms)
		d.total_q += 1
		if s.correct:
			d.total_correct += 1
			correct += 1
		# Per-topic accuracy
		var ta = d.topic_accuracy

		if s.topic not in ta or ta[s.topic].size() < 3:
			ta[s.topic] = [0, 0, 5000.0]

# Now safe to use
		ta[s.topic][1] += 1

		if s.correct:
			ta[s.topic][0] += 1

		ta[s.topic][2] = lerp(ta[s.topic][2], float(s.ms), 0.3)

	if _session_data.size() > 0:
		d.avg_ms = lerp(d.avg_ms, total_ms / _session_data.size(), 0.25)

	# ── Difficulty auto-scaling ────────────────────────────────────────────
	var session_acc := float(correct) / float(_session_data.size())
	var diff = d.get("difficulty_level", 1)

	if session_acc >= 0.85 and diff < 4:
		diff += 1
	elif session_acc < 0.40 and diff > 1:
		diff -= 1

	d["difficulty_level"] = diff  # demote to easier tier

	# ── XP multiplier scales with speed + accuracy ─────────────────────────
	# Base 1.0 → up to 2.5× for fast AND accurate answers
	var speed_bonus := clampf((5000.0 - d.avg_ms) / 5000.0, 0.0, 1.0)
	var acc_overall = float(d.total_correct) / max(float(d.total_q), 1.0)
	d.xp_multiplier = 1.0 + speed_bonus * 0.75 + acc_overall * 0.75

	_save()

	var weak := get_weak_topics(_session_world)
	weak_topics_updated.emit(_session_world, weak)

	var report := {
	"correct": correct,
	"total": _session_data.size(),
	"accuracy": session_acc,
	"avg_ms": d.get("avg_ms", 0.0),
	"difficulty": d.get("difficulty_level", 1),
	"streak": d.get("streak", 0),
	"best_streak": d.get("best_streak", 0),
	"xp_multiplier": d.get("xp_multiplier", 1.0),
	"weak": weak,
}
	performance_report.emit(_session_world, report)
	return report

# ── Weak topic detection ───────────────────────────────────────────────────────
func get_weak_topics(world: String) -> Array:
	if world not in _data: return []
	var ta   = _data[world].topic_accuracy
	var weak := []
	for topic in ta:
		var acc = float(ta[topic][0]) / max(float(ta[topic][1]), 1.0)
		if acc < 0.60: weak.append(topic)
	return weak

func get_topic_accuracy(world: String, topic: String) -> float:
	if world not in _data: return -1.0
	var ta = _data[world].topic_accuracy
	if topic not in ta: return -1.0
	return float(ta[topic][0]) / max(float(ta[topic][1]), 1.0)

func get_accuracy(world: String) -> float:
	if world not in _data: return 1.0
	var d = _data[world]
	return float(d.total_correct) / max(float(d.total_q), 1.0)

func get_avg_speed(world: String) -> float:
	if world not in _data: return 5000.0
	return _data[world].avg_ms

func get_difficulty_level(world: String) -> int:
	if world not in _data:
		return 1

	return _data[world].get("difficulty", 1)

func get_xp_multiplier(world: String) -> float:
	if world not in _data: return 1.0
	return _data[world].xp_multiplier

func get_streak(world: String) -> int:
	if world not in _data: return 0
	return _data[world].streak

# ── Adaptive question selection ────────────────────────────────────────────────
# Priority: 1) Weak topics  2) Current difficulty tier  3) Random
func adaptive_select(questions: Array, world: String, player_level: int, count: int) -> Array:
	if questions.is_empty(): return []
	var weak       := get_weak_topics(world)
	var diff_tier  := get_difficulty_level(world)
	var max_diff   = clamp(int(player_level / 5) + 2, 1, 4)

	# Bucket questions
	var weak_exact:  Array = []   # weak topic + matching difficulty
	var weak_any:    Array = []   # weak topic any difficulty
	var diff_match:  Array = []   # current difficulty tier
	var easy_fill:   Array = []   # fallback: anything within level range

	for q in questions:
		var qd    := int(q.get("difficulty", 1))
		var qt    = q.get("topic", "")
		var in_range = qd <= max_diff

		if not in_range: continue

		if qt in weak:
			if qd == diff_tier: weak_exact.append(q)
			else: weak_any.append(q)
		elif qd == diff_tier:
			diff_match.append(q)
		else:
			easy_fill.append(q)

	weak_exact.shuffle(); weak_any.shuffle()
	diff_match.shuffle(); easy_fill.shuffle()

	var pool: Array = weak_exact + weak_any + diff_match + easy_fill
	if pool.size() < count:
		# Pad with anything if pool is thin
		var all := questions.duplicate(); all.shuffle()
		for q in all:
			if q not in pool: pool.append(q)
			if pool.size() >= count: break

	return pool.slice(0, min(count, pool.size()))

# ── NPC explanation level (used for adaptive hints) ───────────────────────────
func get_explanation_level(world: String) -> String:
	var acc := get_accuracy(world)
	if acc < 0.40:   return "beginner"
	elif acc < 0.70: return "intermediate"
	return "advanced"

# ── Performance summary for HUD ───────────────────────────────────────────────
func get_summary(world: String) -> Dictionary:
	if world not in _data:
		return {"accuracy": 0.0, "sessions": 0, "difficulty": 1,
				"streak": 0, "xp_mult": 1.0, "weak": []}
	var d: Dictionary = _data.get(world, {})

	return {
	"accuracy": float(d.get("total_correct", 0)) / max(float(d.get("total_q", 1)), 1.0),
	"sessions": d.get("sessions", 0),
	"difficulty": d.get("difficulty", 1),  # ✅ safe fallback
	"streak": d.get("streak", 0),
	"best_streak": d.get("best_streak", 0),
	"xp_mult": d.get("xp_multiplier", 1.0),
	"weak": get_weak_topics(world),
	"avg_ms": d.get("avg_ms", 0),
}

# ── Save / Load ────────────────────────────────────────────────────────────────
func _save() -> void:
	var f := FileAccess.open("user://kq_ai.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_data)); f.close()

func _load() -> void:
	if not FileAccess.file_exists("user://kq_ai.json"): return
	var f := FileAccess.open("user://kq_ai.json", FileAccess.READ)
	if not f: return
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if d is Dictionary:
		for k in d: _data[k] = d[k]

func reset(world: String) -> void:
	_data[world] = {
		"topic_accuracy": {}, "avg_ms": 5000.0, "sessions": 0,
		"total_correct": 0, "total_q": 0, "difficulty_level": 1,
		"streak": 0, "best_streak": 0, "xp_multiplier": 1.0,
	}
	_save()
