# GameManager.gd — Global State (Autoload)
extends Node

# ── Player ────────────────────────────────────────────────────────────────────
var player_name:    String = "Arix"
var active_subject: String = ""  # "math" | "languages" | "music"
var active_branch:  String = ""  # e.g. "algebra" | "english" | "theory"

# Per-branch state: { "math:algebra": { level, xp, badges, hp, ... }, ... }
var branch_state:   Dictionary = {}

# ── Signals ───────────────────────────────────────────────────────────────────
signal xp_changed(cur: int, max_xp: int, level: int)
signal level_up(new_level: int)
signal badge_earned(badge_name: String)
signal hp_changed(cur: int, max_hp: int)

const XP_BASE    := 100
const BASE_HP    := 30
const HP_PER_LV  := 3

# ── Branch key ────────────────────────────────────────────────────────────────
func _key() -> String:
	return active_subject + ":" + active_branch

func _ws() -> Dictionary:
	var k := _key()
	if k not in branch_state: _init_branch(k)
	return branch_state[k]

func _init_branch(key: String) -> void:
	branch_state[key] = {
		"level": 1, "xp": 0, "hp": BASE_HP, "gold": 0,
		"badges": [], "npcs_talked": [], "items_collected": [],
		"quests_done": [], "duels_won": 0,
		"silver_attempts": 0, "silver_cooldown": 0, "kaiser": false,
		"score_best": {}, "grid_pos": {"x": 7, "y": 8}
	}

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_level() -> int:   return _ws().get("level", 1)
func get_xp() -> int:      return _ws().get("xp", 0)
func get_xp_max() -> int:  return get_level() * XP_BASE
func get_badges() -> Array: return _ws().get("badges", [])
func get_hp() -> int:      return _ws().get("hp", get_max_hp())
func get_max_hp() -> int:  return BASE_HP + (get_level() - 1) * HP_PER_LV
func get_duel_wins() -> int: return _ws().get("duels_won", 0)
func get_gold() -> int:    return _ws().get("gold", 0)
func is_kaiser() -> bool:  return _ws().get("kaiser", false)

func get_grid_pos() -> Vector2i:
	var g = _ws().get("grid_pos", {"x": 7, "y": 8})
	return Vector2i(clampi(int(g.get("x",7)),0,14), clampi(int(g.get("y",8)),0,9))

func set_grid_pos(p: Vector2i) -> void:
	_ws()["grid_pos"] = {"x": p.x, "y": p.y}

# ── XP & Level ────────────────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	var ws := _ws()
	ws["xp"] += amount
	var cap := get_level() * XP_BASE
	while ws["xp"] >= cap:
		ws["xp"] -= cap; ws["level"] += 1; cap = ws["level"] * XP_BASE
		level_up.emit(ws["level"])
	xp_changed.emit(ws["xp"], ws["level"] * XP_BASE, ws["level"])
	_save()

# ── HP ────────────────────────────────────────────────────────────────────────
func restore_hp() -> void:
	_ws()["hp"] = get_max_hp(); hp_changed.emit(get_hp(), get_max_hp())

func take_damage(d: int) -> void:
	var ws := _ws(); ws["hp"] = max(0, ws.get("hp", get_max_hp()) - d)
	hp_changed.emit(get_hp(), get_max_hp()); _save()

# ── Gym / Badge ───────────────────────────────────────────────────────────────
func can_challenge_gym(gym_num: int) -> bool:
	return get_level() >= gym_num * 5

func earn_badge(b: String) -> void:
	var ws := _ws()
	if b not in ws["badges"]:
		ws["badges"].append(b); badge_earned.emit(b); _save()

func has_badge(b: String) -> bool: return b in _ws().get("badges", [])
func set_best_score(id: String, score: int) -> void:
	var ws := _ws()
	ws["score_best"][id] = max(score, ws["score_best"].get(id, 0)); _save()

# ── Silver Mountain ───────────────────────────────────────────────────────────
func can_challenge_silver() -> bool:
	return get_level() >= 100 and get_badges().size() >= 20

func silver_on_cooldown() -> bool:
	return int(_ws().get("silver_cooldown", 0)) > int(Time.get_unix_time_from_system())

func silver_cooldown_remaining() -> int:
	return max(0, int(_ws().get("silver_cooldown", 0)) - int(Time.get_unix_time_from_system()))

func silver_attempt_failed() -> void:
	var ws := _ws(); ws["silver_attempts"] = ws.get("silver_attempts", 0) + 1
	if ws["silver_attempts"] >= 3:
		ws["silver_cooldown"] = int(Time.get_unix_time_from_system()) + 86400
		ws["silver_attempts"] = 0
	_save()

func silver_cleared() -> void: _ws()["kaiser"] = true; _save()

# ── Flags ─────────────────────────────────────────────────────────────────────
func has_talked(id: String) -> bool:  return id in _ws().get("npcs_talked", [])
func mark_talked(id: String) -> void:
	if id not in _ws().get("npcs_talked", []): _ws()["npcs_talked"].append(id)

func has_item(id: String) -> bool:    return id in _ws().get("items_collected", [])
func collect_item(id: String) -> void:
	if id not in _ws().get("items_collected", []): _ws()["items_collected"].append(id)

func quest_done(id: String) -> bool:  return id in _ws().get("quests_done", [])
func complete_quest(id: String) -> void:
	if id not in _ws().get("quests_done", []): _ws()["quests_done"].append(id); _save()

func add_duel_win() -> void: _ws()["duels_won"] = _ws().get("duels_won", 0) + 1; _save()

# ── Save / Load ───────────────────────────────────────────────────────────────
func _ready() -> void: _load()

func _save() -> void:
	var f := FileAccess.open("user://kq_save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"name": player_name, "bs": branch_state}))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists("user://kq_save.json"): return
	var f := FileAccess.open("user://kq_save.json", FileAccess.READ)
	if not f: return
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if not d is Dictionary: return
	player_name  = d.get("name", "Arix")
	branch_state = d.get("bs", {})

func reset_all() -> void:
	branch_state = {}
	if FileAccess.file_exists("user://kq_save.json"):
		DirAccess.remove_absolute("user://kq_save.json")
