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
		var d = _data[_session_world]
		if correct:
			d.streak += 1
			d.best_streak = max(d.best_streak, d.streak)
		else:
			d.streak = 0

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
		if s.topic not in ta:
			ta[s.topic] = [0, 0, 5000.0]  # ensure 3 elements

# Ensure structure is always valid (VERY IMPORTANT)
		if ta[s.topic].size() < 3:
			ta[s.topic].resize(3)
			ta[s.topic][2] = 5000.0

		ta[s.topic][1] += 1

		if s.correct:
			ta[s.topic][0] += 1

# Now safe
		ta[s.topic][2] = lerp(ta[s.topic][2], float(s.ms), 0.3)

	if _session_data.size() > 0:
		d.avg_ms = lerp(d.avg_ms, total_ms / _session_data.size(), 0.25)

	# ── Difficulty auto-scaling ────────────────────────────────────────────
	var session_acc := float(correct) / float(_session_data.size())
	if session_acc >= 0.85 and d.difficulty_level < 4:
		d.difficulty_level += 1   # promote to harder tier
	elif session_acc < 0.40 and d.difficulty_level > 1:
		d.difficulty_level -= 1   # demote to easier tier

	# ── XP multiplier scales with speed + accuracy ─────────────────────────
	# Base 1.0 → up to 2.5× for fast AND accurate answers
	var speed_bonus := clampf((5000.0 - d.avg_ms) / 5000.0, 0.0, 1.0)
	var acc_overall = float(d.total_correct) / max(float(d.total_q), 1.0)
	d.xp_multiplier = 1.0 + speed_bonus * 0.75 + acc_overall * 0.75

	_save()

	var weak := get_weak_topics(_session_world)
	weak_topics_updated.emit(_session_world, weak)

	var report := {
		"correct":        correct,
		"total":          _session_data.size(),
		"accuracy":       session_acc,
		"avg_ms":         d.avg_ms,
		"difficulty":     d.difficulty_level,
		"streak":         d.streak,
		"best_streak":    d.best_streak,
		"xp_multiplier":  d.xp_multiplier,
		"weak":           weak,
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
	if world not in _data: return 1
	return _data[world].difficulty_level

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
	var d = _data[world]
	return {
		"accuracy":   float(d.total_correct) / max(float(d.total_q), 1.0),
		"sessions":   d.sessions,
		"difficulty": d.difficulty_level,
		"streak":     d.streak,
		"best_streak":d.best_streak,
		"xp_mult":    d.xp_multiplier,
		"weak":       get_weak_topics(world),
		"avg_ms":     d.avg_ms,
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

# ═══════════════════════════════════════════════════════════════════════════════
#  TRAINING PIPELINE — Smart Question Generator & Difficulty Predictor
#  Input: accuracy, response_time, attempts per topic
#  Output: recommended difficulty, predicted success probability
# ═══════════════════════════════════════════════════════════════════════════════

# ── Predict success probability for a question at given difficulty ────────────
# Uses logistic-style function: P(success) = sigmoid(accuracy * speed_factor - diff_bias)
func predict_success(world: String, topic: String, difficulty: int) -> float:
	var acc       := get_topic_accuracy(world, topic)
	if acc < 0:   acc = get_accuracy(world)  # fall back to overall
	var speed_f   := clampf(1.0 - get_avg_speed(world) / 8000.0, 0.0, 1.0)
	var combined  := acc * 0.7 + speed_f * 0.3
	# Difficulty bias: each tier reduces success by ~20%
	var bias      := float(difficulty - 1) * 0.22
	# Sigmoid-style: 1/(1+e^(-k*(x-0.5))) mapped to [0,1]
	var x         := combined - bias
	return 1.0 / (1.0 + exp(-8.0 * (x - 0.5)))

# ── Recommend next difficulty tier for a world ────────────────────────────────
func recommend_difficulty(world: String) -> int:
	var acc   := get_accuracy(world)
	var speed := get_avg_speed(world)
	# Target: 70-80% accuracy at recommended difficulty (learning zone)
	# If above 85% → promote. If below 45% → demote.
	var curr  := get_difficulty_level(world)
	if acc >= 0.85 and speed < 4500: return min(4, curr + 1)
	if acc < 0.45:                   return max(1, curr - 1)
	return curr

# ── Generate a mini quiz from weak areas (for revision mode) ─────────────────
func generate_revision_set(all_questions: Array, world: String, count: int) -> Array:
	var weak     := get_weak_topics(world)
	var revision := []
	# Prioritize weakest topic first (lowest accuracy)
	if world in _data:
		var ta = _data[world].topic_accuracy
		var sorted_topics := weak.duplicate()
		sorted_topics.sort_custom(func(a,b):
			var acc_a = float(ta.get(a,[0,1])[0])/max(float(ta.get(a,[0,1])[1]),1)
			var acc_b = float(ta.get(b,[0,1])[0])/max(float(ta.get(b,[0,1])[1]),1)
			return acc_a < acc_b)
		for topic in sorted_topics:
			for q in all_questions:
				if q.get("topic","") == topic: revision.append(q)
			if revision.size() >= count: break
	# Pad with general questions if needed
	if revision.size() < count:
		var general := all_questions.duplicate(); general.shuffle()
		for q in general:
			if q not in revision: revision.append(q)
			if revision.size() >= count: break
	return revision.slice(0, min(count, revision.size()))

# ── Session performance trend (are you improving?) ───────────────────────────
func get_improvement_trend(world: String) -> String:
	if world not in _data: return "no_data"
	var d = _data[world]
	if d.sessions < 2: return "new"
	var acc = float(d.total_correct) / max(float(d.total_q), 1.0)
	var diff = d.difficulty_level
	# Heuristic: improving = high accuracy + moving up in difficulty
	if acc >= 0.75 and diff >= 3: return "excellent"
	if acc >= 0.60 and diff >= 2: return "improving"
	if acc >= 0.45:               return "steady"
	return "struggling"

# ── Full performance report for story/narrative context ──────────────────────
func get_narrative_feedback(world: String) -> String:
	var trend  := get_improvement_trend(world)
	var weak   := get_weak_topics(world)
	var name   := GameManager.player_name
	match trend:
		"excellent":
			return name + " shows mastery in " + world + "!\nChallenging the Oracle will be worthy."
		"improving":
			var ws = weak[0] if weak.size() > 0 else "unknown"
			return name + " is growing fast!\nWatch: " + ws + " still needs work."
		"steady":
			return name + " makes steady progress.\nKeep practicing weak topics."
		"struggling":
			var ws = weak[0] if weak.size() > 0 else "fundamentals"
			return name + " struggles with " + ws + ".\nReturn to Teachers for help."
		_:
			return "Begin your journey in " + world + ".\nEvery master starts as a student."
