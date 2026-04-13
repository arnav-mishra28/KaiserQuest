# GameManager.gd v0.5
extends Node

var player_name:  String = "Arix"
var active_world: String = ""
var world_state:  Dictionary = {}

signal xp_changed(cur:int,max_xp:int,level:int)
signal level_up(new_level:int)
signal badge_earned(badge_name:String)
signal hp_changed(cur:int,max_hp:int)

const XP_BASE   := 100
const BASE_HP   := 30    # player starts with 30 Knowledge HP
const HP_PER_LV := 2     # +2 HP each level

func _ready()->void:
	for w in ["math","english","music"]: _init_world(w)
	_load()

func _init_world(wid:String)->void:
	if wid not in world_state:
		world_state[wid]={
			"level":1,"xp":0,"badges":[],"hp":BASE_HP,
			"grid_pos":{"x":7,"y":8},
			"npcs_talked":[],"items_collected":[],
			"quests_done":[],"duels_won":0,
			"teachers_learned":[], # teacher NPC IDs whose lesson was studied
			"score_thresholds":{},  # gym_id -> best score (0-100)
			"silver_attempts":0,"silver_cooldown_time":0,"kaiser":false
		}

func _ws()->Dictionary: return world_state[active_world]

# ── Stats ────────────────────────────────────────────────────────────────────
func get_level()->int:   return _ws().level
func get_xp()->int:      return _ws().xp
func get_xp_max()->int:  return _ws().level * XP_BASE
func get_badges()->Array: return _ws().badges
func get_max_hp()->int:  return BASE_HP + (_ws().level - 1) * HP_PER_LV
func get_hp()->int:      return _ws().get("hp", get_max_hp())
func is_kaiser()->bool:  return _ws().get("kaiser", false)

func heal_hp()->void:
	_ws()["hp"] = get_max_hp()
	hp_changed.emit(get_hp(), get_max_hp())

func take_damage(dmg:int)->void:
	var ws:=_ws(); ws["hp"] = max(0, ws.get("hp", get_max_hp()) - dmg)
	hp_changed.emit(get_hp(), get_max_hp()); _save()

func restore_hp(amt:int)->void:
	var ws:=_ws(); ws["hp"] = min(get_max_hp(), ws.get("hp", get_max_hp()) + amt)
	hp_changed.emit(get_hp(), get_max_hp())

func get_grid_pos()->Vector2i:
	var g=_ws().grid_pos
	return Vector2i(clampi(int(g.get("x",7)),0,14), clampi(int(g.get("y",8)),0,9))

func set_grid_pos(p:Vector2i)->void:
	_ws().grid_pos={"x":p.x,"y":p.y}

# ── XP ────────────────────────────────────────────────────────────────────────
func add_xp(amount:int)->void:
	var ws:=_ws(); ws.xp+=amount
	var cap=ws.level*XP_BASE
	while ws.xp>=cap:
		ws.xp-=cap; ws.level+=1; cap=ws.level*XP_BASE
		heal_hp()  # heal to full on level up
		level_up.emit(ws.level)
	xp_changed.emit(ws.xp,ws.level*XP_BASE,ws.level); _save()

# ── Gym / Badge ───────────────────────────────────────────────────────────────
func can_challenge_gym(gym_num:int)->bool: return get_level()>=(gym_num*5)
func earn_badge(b:String)->void:
	var ws:=_ws()
	if b not in ws.badges: ws.badges.append(b); badge_earned.emit(b); _save()
func has_badge(b:String)->bool: return b in _ws().badges

# Score threshold system (Phase 4)
func set_gym_score(gym_id:String,score:int)->void:
	if "score_thresholds" not in _ws(): _ws()["score_thresholds"]={}
	_ws().score_thresholds[gym_id]=max(score, _ws().score_thresholds.get(gym_id,0)); _save()
func get_gym_score(gym_id:String)->int:
	return _ws().get("score_thresholds",{}).get(gym_id,0)
func gym_score_passes(gym_id:String)->bool: return get_gym_score(gym_id)>=70

# Teacher lesson tracking (Phase 2)
func learned_from(npc_id:String)->bool:
	return npc_id in _ws().get("teachers_learned",[])
func mark_learned(npc_id:String)->void:
	var tl=_ws().get("teachers_learned",[])
	if npc_id not in tl: tl.append(npc_id); _ws()["teachers_learned"]=tl

# ── Silver Mountain ───────────────────────────────────────────────────────────
func can_challenge_silver()->bool: return get_level()>=100 and get_badges().size()>=20
func silver_on_cooldown()->bool:
	return _ws().silver_cooldown_time>int(Time.get_unix_time_from_system())
func silver_attempt_failed()->void:
	var ws:=_ws(); ws.silver_attempts+=1
	if ws.silver_attempts>=3:
		ws.silver_cooldown_time=int(Time.get_unix_time_from_system())+86400
		ws.silver_attempts=0
	_save()
func silver_cleared()->void: _ws().kaiser=true; _save()

# ── NPC / Item / Quest ────────────────────────────────────────────────────────
func has_talked(id:String)->bool:  return id in _ws().npcs_talked
func mark_talked(id:String)->void:
	if id not in _ws().npcs_talked: _ws().npcs_talked.append(id)
func has_item(id:String)->bool:    return id in _ws().items_collected
func collect_item(id:String)->void:
	if id not in _ws().items_collected: _ws().items_collected.append(id)
func quest_done(id:String)->bool:  return id in _ws().quests_done
func complete_quest(id:String)->void:
	if id not in _ws().quests_done:
		_ws().quests_done.append(id); _save()
func add_duel_win()->void: _ws().duels_won+=1; _save()
func get_duel_wins()->int: return _ws().duels_won

# ── Save / Load ───────────────────────────────────────────────────────────────
func _save()->void:
	var f:=FileAccess.open("user://kq_v5.json",FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"name":player_name,"ws":world_state})); f.close()

func _load()->void:
	if not FileAccess.file_exists("user://kq_v5.json"): return
	var f:=FileAccess.open("user://kq_v5.json",FileAccess.READ)
	if not f: return
	var d=JSON.parse_string(f.get_as_text()); f.close()
	if not d is Dictionary: return
	player_name=d.get("name","Arix")
	var ws_raw=d.get("ws",{})
	for wid in ws_raw: world_state[wid]=ws_raw[wid]
	# Fix OOB positions from old saves
	for wid in world_state:
		var gp=world_state[wid].get("grid_pos",{"x":7,"y":8})
		if int(gp.get("y",0))>9 or int(gp.get("x",0))>14:
			world_state[wid].grid_pos={"x":7,"y":8}

func reset_all()->void:
	world_state={}
	for w in ["math","english","music"]: _init_world(w)
	for fn in ["user://kq_v5.json","user://kq_ai.json"]:
		if FileAccess.file_exists(fn): DirAccess.remove_absolute(fn)
