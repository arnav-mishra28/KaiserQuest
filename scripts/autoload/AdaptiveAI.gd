# AdaptiveAI.gd — Adaptive learning engine
extends Node
var _data:Dictionary={}
var _session_world:String=""
var _session_data:Array=[]
var _q_start:float=0.0
signal weak_topics_updated(world:String,topics:Array)

func _ready()->void:
	for w in ["math","english","music"]:
		if w not in _data:
			_data[w]={"topic_accuracy":{},"avg_ms":5000.0,"sessions":0,"total_correct":0,"total_q":0}
	_load()

func start_session(world:String)->void:
	_session_world=world; _session_data=[]; _q_start=Time.get_ticks_msec()

func record_answer(topic:String,correct:bool)->void:
	var ms:=Time.get_ticks_msec()-_q_start; _q_start=Time.get_ticks_msec()
	_session_data.append({"topic":topic,"correct":correct,"ms":ms})

func end_session()->Dictionary:
	if _session_world=="" or _session_data.is_empty(): return {}
	var d=_data[_session_world]; d.sessions+=1; var total_ms:=0.0
	for s in _session_data:
		total_ms+=s.ms
		if s.correct: d.total_correct+=1
		d.total_q+=1
		if s.topic not in d.topic_accuracy: d.topic_accuracy[s.topic]=[0,0]
		d.topic_accuracy[s.topic][1]+=1
		if s.correct: d.topic_accuracy[s.topic][0]+=1
	if _session_data.size()>0: d.avg_ms=lerp(d.avg_ms,total_ms/_session_data.size(),0.3)
	_save()
	var correct:=0
	for s in _session_data: if s.correct: correct+=1
	var rep:={"correct":correct,"total":_session_data.size(),"accuracy":float(correct)/max(_session_data.size(),1),"weak":get_weak_topics(_session_world)}
	weak_topics_updated.emit(_session_world,rep.weak)
	return rep

func get_weak_topics(world:String)->Array:
	if world not in _data: return []
	var ta=_data[world].topic_accuracy; var weak:=[]
	for topic in ta:
		if float(ta[topic][0])/max(ta[topic][1],1)<0.6: weak.append(topic)
	return weak

func get_accuracy(world:String)->float:
	if world not in _data: return 1.0
	return float(_data[world].total_correct)/max(_data[world].total_q,1)

func get_avg_speed(world:String)->float:
	if world not in _data: return 5000.0
	return _data[world].avg_ms

func adaptive_select(questions:Array,world:String,player_level:int,count:int)->Array:
	var weak:=get_weak_topics(world); var prioritized:=[]; var normal:=[]
	for q in questions:
		var diff=q.get("difficulty",1)
		if diff>(player_level/5)+2: continue
		if q.get("topic","") in weak: prioritized.append(q)
		else: normal.append(q)
	prioritized.shuffle(); normal.shuffle()
	var pool:=prioritized+normal; var result:=[]
	for i in min(count,pool.size()): result.append(pool[i])
	if result.is_empty(): result=questions.duplicate(); result.shuffle(); result=result.slice(0,min(count,result.size()))
	return result

func get_explanation_level(world:String)->String:
	var acc:=get_accuracy(world)
	if acc<0.4: return "beginner"
	elif acc<0.7: return "intermediate"
	return "advanced"

func _save()->void:
	var f:=FileAccess.open("user://kq_ai.json",FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_data)); f.close()

func _load()->void:
	if not FileAccess.file_exists("user://kq_ai.json"): return
	var f:=FileAccess.open("user://kq_ai.json",FileAccess.READ)
	if not f: return
	var d=JSON.parse_string(f.get_as_text()); f.close()
	if d is Dictionary: for k in d: _data[k]=d[k]
