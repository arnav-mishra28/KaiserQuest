# AdaptiveAI.gd — Adaptive learning engine (autoload)
extends Node

# Per-world performance data
var _data: Dictionary = {}

# Tracks for current battle session
var _session_world:  String  = ""
var _session_start:  float   = 0.0
var _q_start_time:   float   = 0.0
var _session_data:   Array   = []   # [{topic, correct, time_ms}]

signal weak_topics_updated(world:String, topics:Array)

func _ready()->void:
	for w in ["math","english","music"]:
		if w not in _data:
			_data[w] = {
				"topic_accuracy": {},   # topic -> [correct, total]
				"avg_time_ms":    5000,
				"sessions":       0,
				"total_correct":  0,
				"total_questions":0
			}
	_load()

# ── Session control ───────────────────────────────────────────────────────────
func start_session(world:String)->void:
	_session_world=world; _session_start=Time.get_ticks_msec()
	_session_data=[]; _q_start_time=Time.get_ticks_msec()

func record_answer(topic:String, correct:bool)->void:
	var elapsed:=Time.get_ticks_msec()-_q_start_time
	_session_data.append({"topic":topic,"correct":correct,"ms":elapsed})
	_q_start_time=Time.get_ticks_msec()

func end_session()->Dictionary:
	if _session_world=="" or _session_data.is_empty(): return {}
	var d=_data[_session_world]
	d.sessions+=1
	var total_ms:=0.0
	for s in _session_data:
		total_ms+=s.ms
		if s.correct: d.total_correct+=1
		d.total_questions+=1
		var ta=d.topic_accuracy
		if s.topic not in ta: ta[s.topic]=[0,0]
		ta[s.topic][1]+=1
		if s.correct: ta[s.topic][0]+=1
	if _session_data.size()>0:
		d.avg_time_ms=lerp(d.avg_time_ms, total_ms/_session_data.size(), 0.3)
	_save()
	var report:=_build_report()
	weak_topics_updated.emit(_session_world, get_weak_topics(_session_world))
	return report

func _build_report()->Dictionary:
	var d=_data[_session_world]
	var correct:=0; var total:=_session_data.size()
	for s in _session_data: if s.correct: correct+=1
	return {
		"correct":   correct,
		"total":     total,
		"accuracy":  float(correct)/max(total,1),
		"avg_ms":    d.avg_time_ms,
		"weak":      get_weak_topics(_session_world)
	}

# ── Weak topic detection ──────────────────────────────────────────────────────
func get_weak_topics(world:String)->Array:
	if world not in _data: return []
	var ta=_data[world].topic_accuracy; var weak:=[]
	for topic in ta:
		var acc=float(ta[topic][0])/max(ta[topic][1],1)
		if acc<0.6: weak.append(topic)
	return weak

func get_accuracy(world:String)->float:
	if world not in _data: return 1.0
	var d=_data[world]
	return float(d.total_correct)/max(d.total_questions,1)

func get_avg_speed(world:String)->float:
	if world not in _data: return 5000.0
	return _data[world].avg_time_ms

# ── Adaptive question selection ───────────────────────────────────────────────
# Given a pool of questions, returns them ordered by priority:
# weak topics first, then shuffle, respecting difficulty to player level
func adaptive_select(questions:Array, world:String, player_level:int, count:int)->Array:
	var weak:=get_weak_topics(world)
	var prioritized:=[]; var normal:=[]
	for q in questions:
		var diff=q.get("difficulty",1)
		# Skip questions too far above or below player level
		if diff > (player_level/5)+2: continue
		if q.get("topic","") in weak: prioritized.append(q)
		else: normal.append(q)
	prioritized.shuffle(); normal.shuffle()
	var pool:=prioritized+normal
	var result:=[]
	for i in min(count,pool.size()): result.append(pool[i])
	return result

# ── NPC explanation level ─────────────────────────────────────────────────────
func get_explanation_level(world:String)->String:
	var acc:=get_accuracy(world)
	if acc<0.4:   return "beginner"
	elif acc<0.7: return "intermediate"
	else:         return "advanced"

# ── Save/Load ─────────────────────────────────────────────────────────────────
func _save()->void:
	var f:=FileAccess.open("user://kq_ai.json",FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_data)); f.close()

func _load()->void:
	if not FileAccess.file_exists("user://kq_ai.json"): return
	var f:=FileAccess.open("user://kq_ai.json",FileAccess.READ)
	if not f: return
	var d=JSON.parse_string(f.get_as_text()); f.close()
	if d is Dictionary:
		for k in d: _data[k]=d[k]
