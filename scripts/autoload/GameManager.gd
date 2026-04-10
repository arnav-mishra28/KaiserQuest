# GameManager.gd — Global singleton v0.3
extends Node

var player_name:  String = "Arix"
var active_world: String = ""
var current_zone: String = "world_map"   # "world_map" | "math" | "english" | "music"
var world_state:  Dictionary = {}

signal xp_changed(cur:int, max_xp:int, level:int)
signal level_up(new_level:int)
signal badge_earned(badge_name:String)
signal quest_updated(quest_id:String)

const XP_BASE := 100

func _ready()->void:
	for w in ["math","english","music"]: _init_world(w)
	_load()

func _init_world(wid:String)->void:
	if wid not in world_state:
		world_state[wid]={
			"level":1,"xp":0,"badges":[],
			"grid_pos":{"x":7,"y":11},
			"npcs_talked":[],"items_collected":[],
			"quests_done":[],"duels_won":0,
			"silver_attempts":0,
			"silver_cooldown_time":0,    # unix timestamp when cooldown expires
			"kaiser":false
		}

# ── Accessors ────────────────────────────────────────────────────────────────
func _ws()->Dictionary: return world_state[active_world]
func get_level()->int:   return _ws().level
func get_xp()->int:      return _ws().xp
func get_xp_max()->int:  return _ws().level * XP_BASE
func get_badges()->Array: return _ws().badges
func get_grid_pos()->Vector2i:
	var g =_ws().grid_pos; return Vector2i(g.x,g.y)
func set_grid_pos(p:Vector2i)->void:
	_ws().grid_pos={"x":p.x,"y":p.y}
func is_kaiser()->bool: return _ws().kaiser

# ── XP ───────────────────────────────────────────────────────────────────────
func add_xp(amount:int)->void:
	var ws:=_ws(); ws.xp+=amount
	var cap =ws.level*XP_BASE
	while ws.xp>=cap:
		ws.xp-=cap; ws.level+=1; cap=ws.level*XP_BASE
		level_up.emit(ws.level)
	xp_changed.emit(ws.xp,ws.level*XP_BASE,ws.level)
	_save()

# ── Gym / Badge ───────────────────────────────────────────────────────────────
func can_challenge_gym(gym_num:int)->bool: return get_level()>=(gym_num*5)
func earn_badge(b:String)->void:
	var ws:=_ws()
	if b not in ws.badges: ws.badges.append(b); badge_earned.emit(b); _save()
func has_badge(b:String)->bool: return b in _ws().badges

# ── Silver Mountain ───────────────────────────────────────────────────────────
func can_challenge_silver()->bool:
	return get_level()>=100 and get_badges().size()>=20

func silver_on_cooldown()->bool:
	var t:=int(Time.get_unix_time_from_system())
	return _ws().silver_cooldown_time > t

func silver_cooldown_remaining()->int:
	var t:=int(Time.get_unix_time_from_system())
	return max(0, _ws().silver_cooldown_time - t)

func silver_attempt_failed()->void:
	var ws:=_ws(); ws.silver_attempts+=1
	if ws.silver_attempts>=3:
		# 24h cooldown, reset attempts
		ws.silver_cooldown_time=int(Time.get_unix_time_from_system())+86400
		ws.silver_attempts=0
	_save()

func silver_cleared()->void:
	_ws().kaiser=true; _save()

# ── NPC / Item / Quest flags ──────────────────────────────────────────────────
func has_talked(id:String)->bool:   return id in _ws().npcs_talked
func mark_talked(id:String)->void:
	if id not in _ws().npcs_talked: _ws().npcs_talked.append(id)
func has_item(id:String)->bool:     return id in _ws().items_collected
func collect_item(id:String)->void:
	if id not in _ws().items_collected: _ws().items_collected.append(id)
func quest_done(id:String)->bool:   return id in _ws().quests_done
func complete_quest(id:String)->void:
	if id not in _ws().quests_done:
		_ws().quests_done.append(id); quest_updated.emit(id); _save()
func add_duel_win()->void:
	_ws().duels_won+=1; _save()
func get_duel_wins()->int: return _ws().duels_won

# ── Save / Load ───────────────────────────────────────────────────────────────
func _save()->void:
	var f:=FileAccess.open("user://kq_v3.json",FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"name":player_name,"ws":world_state})); f.close()

func _load()->void:
	if not FileAccess.file_exists("user://kq_v3.json"): return
	var f:=FileAccess.open("user://kq_v3.json",FileAccess.READ)
	if not f: return
	var d=JSON.parse_string(f.get_as_text()); f.close()
	if not d is Dictionary: return
	player_name=d.get("name","Arix")
	var ws=d.get("ws",{})
	for wid in ws: world_state[wid]=ws[wid]

func reset_all()->void:
	world_state={}
	for w in ["math","english","music"]: _init_world(w)
	if FileAccess.file_exists("user://kq_v3.json"):
		DirAccess.remove_absolute("user://kq_v3.json")
