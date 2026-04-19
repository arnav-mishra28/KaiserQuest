# AdaptiveAI.gd — Adaptive Learning Engine (Autoload)
extends Node

var _data: Dictionary = {}
var _session_world: String = ""
var _session_data:  Array  = []
var _q_start:       float  = 0.0

signal weak_topics_updated(world: String, topics: Array)

func _ready() -> void:
	_load()

func _ensure(key: String) -> void:
	if key not in _data:
		_data[key] = {
			"topic_accuracy": {}, "avg_ms": 5000.0, "sessions": 0,
			"total_correct": 0, "total_q": 0, "difficulty_level": 1,
			"streak": 0, "best_streak": 0, "xp_multiplier": 1.0
		}

func start_session(world: String) -> void:
	_ensure(world); _session_world = world
	_session_data = []; _q_start = Time.get_ticks_msec()

func record_answer(topic: String, correct: bool) -> void:
	var ms := Time.get_ticks_msec() - _q_start
	_q_start = Time.get_ticks_msec()
	_session_data.append({"topic": topic, "correct": correct, "ms": ms})
	if _session_world in _data:
		var d = _data[_session_world]
		d["streak"] = d["streak"] + 1 if correct else 0
		d["best_streak"] = max(d["best_streak"], d["streak"])

func end_session() -> Dictionary:
	if _session_world == "" or _session_data.is_empty(): return {}
	_ensure(_session_world)
	var d = _data[_session_world]
	d["sessions"] += 1
	var total_ms := 0.0; var correct := 0
	for s in _session_data:
		total_ms += float(s["ms"]); d["total_q"] += 1
		if s["correct"]: d["total_correct"] += 1; correct += 1
		var ta: Dictionary = d["topic_accuracy"]
		if s["topic"] not in ta: ta[s["topic"]] = [0, 0, 5000.0]
		ta[s["topic"]][1] += 1
		if s["correct"]: ta[s["topic"]][0] += 1
		ta[s["topic"]][2] = lerp(float(ta[s["topic"]][2]), float(s["ms"]), 0.3)
	if _session_data.size() > 0:
		d["avg_ms"] = lerp(float(d["avg_ms"]), total_ms / _session_data.size(), 0.25)
	var acc = float(correct) / max(_session_data.size(), 1)
	if acc >= 0.85 and d["difficulty_level"] < 4: d["difficulty_level"] += 1
	elif acc < 0.40 and d["difficulty_level"] > 1: d["difficulty_level"] -= 1
	var speed := clampf((5000.0 - float(d["avg_ms"])) / 5000.0, 0.0, 1.0)
	d["xp_multiplier"] = 1.0 + speed * 0.75 + acc * 0.75
	_save()
	var weak := get_weak_topics(_session_world)
	weak_topics_updated.emit(_session_world, weak)
	return {"correct": correct, "total": _session_data.size(), "accuracy": acc,
			"xp_multiplier": d["xp_multiplier"], "weak": weak,
			"streak": d["streak"], "difficulty": d["difficulty_level"]}

func get_weak_topics(world: String) -> Array:
	_ensure(world)
	var ta: Dictionary = _data[world]["topic_accuracy"]; var weak := []
	for topic in ta:
		if float(ta[topic][0]) / max(float(ta[topic][1]), 1.0) < 0.60: weak.append(topic)
	return weak

func get_accuracy(world: String) -> float:
	_ensure(world)
	var d = _data[world]
	return float(d["total_correct"]) / max(float(d["total_q"]), 1.0)

func get_difficulty_level(world: String) -> int:
	_ensure(world); return _data[world]["difficulty_level"]

func get_xp_multiplier(world: String) -> float:
	_ensure(world); return _data[world]["xp_multiplier"]

func get_streak(world: String) -> int:
	_ensure(world); return _data[world]["streak"]

func get_summary(world: String) -> Dictionary:
	_ensure(world); var d = _data[world]
	return {
		"accuracy":    float(d["total_correct"]) / max(float(d["total_q"]), 1.0),
		"sessions":    d["sessions"], "difficulty": d["difficulty_level"],
		"streak":      d["streak"],   "best_streak": d["best_streak"],
		"xp_mult":     d["xp_multiplier"], "weak": get_weak_topics(world)
	}

func adaptive_select(questions: Array, world: String, player_level: int, count: int) -> Array:
	if questions.is_empty(): return []
	_ensure(world)
	var weak := get_weak_topics(world)
	var max_diff := clampi(player_level / 5 + 2, 1, 4)
	var hi: Array = []; var lo: Array = []
	for q in questions:
		var d := int(q.get("difficulty", 1))
		if d > max_diff: continue
		if q.get("topic", "") in weak: hi.append(q)
		else: lo.append(q)
	hi.shuffle(); lo.shuffle()
	var pool := hi + lo
	if pool.size() < count:
		var all := questions.duplicate(); all.shuffle()
		for q in all:
			if q not in pool: pool.append(q)
			if pool.size() >= count: break
	return pool.slice(0, min(count, pool.size()))

func get_explanation_level(world: String) -> String:
	var acc := get_accuracy(world)
	if acc < 0.40: return "beginner"
	elif acc < 0.70: return "intermediate"
	return "advanced"

func predict_success(world: String, topic: String, difficulty: int) -> float:
	var acc := get_accuracy(world); var speed := clampf(1.0 - float(get_summary(world).get("avg_ms", 5000.0)) / 8000.0, 0.0, 1.0)
	var combined := acc * 0.7 + speed * 0.3; var bias := float(difficulty - 1) * 0.22
	return 1.0 / (1.0 + exp(-8.0 * (combined - bias - 0.5)))

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
