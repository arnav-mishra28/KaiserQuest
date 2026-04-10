# GameManager.gd — Global singleton
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal xp_changed(cur:int, max_xp:int, level:int)
signal level_up(new_level:int)
signal badge_earned(badge_name:String)

# ── Player Core ───────────────────────────────────────────────────────────────
var player_name : String  = "Arix"
var active_world: String  = "math"

# Per-world state
var world_state : Dictionary = {}

# ── Constants ─────────────────────────────────────────────────────────────────
const XP_PER_LEVEL := 100

# ── Boot ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_world("math")
	_init_world("english")
	_init_world("music")
	_load()

# ── World Init ────────────────────────────────────────────────────────────────
func _init_world(wid: String) -> void:
	if wid not in world_state:
		world_state[wid] = {
			"level": 1,
			"xp": 0,
			"badges": [],
			"grid_pos": Vector2i(2, 8),   # ✅ ALWAYS Vector2i
			"npcs_talked": [],
			"items_collected": []
		}

# ── Accessors ─────────────────────────────────────────────────────────────────
func _ws() -> Dictionary:
	return world_state[active_world]

func get_level() -> int:
	return _ws()["level"]

func get_xp() -> int:
	return _ws()["xp"]

func get_xp_max() -> int:
	return _ws()["level"] * XP_PER_LEVEL

func get_badges() -> Array:
	return _ws()["badges"]

# ✅ CLEAN VERSION — ALWAYS RETURNS Vector2i
func get_grid_pos() -> Vector2i:
	return _ws()["grid_pos"]

# ✅ CLEAN SETTER — ALWAYS STORES Vector2i
func set_grid_pos(p: Vector2i) -> void:
	_ws()["grid_pos"] = p
	_save()

# ── XP & Level ────────────────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	var ws := _ws()
	ws["xp"] += amount

	var cap = ws["level"] * XP_PER_LEVEL

	while ws["xp"] >= cap:
		ws["xp"] -= cap
		ws["level"] += 1
		cap = ws["level"] * XP_PER_LEVEL
		level_up.emit(ws["level"])

	xp_changed.emit(ws["xp"], ws["level"] * XP_PER_LEVEL, ws["level"])
	_save()

# ── Items ─────────────────────────────────────────────────────────────────────
func has_item(item_id: String) -> bool:
	return item_id in _ws()["items_collected"]

func collect_item(item_id: String) -> void:
	var ws := _ws()
	if item_id not in ws["items_collected"]:
		ws["items_collected"].append(item_id)
		_save()

# ── Gym Logic ─────────────────────────────────────────────────────────────────
func can_challenge_gym(gym_num: int) -> bool:
	return get_level() >= gym_num * 5

# ── Badge ─────────────────────────────────────────────────────────────────────
func earn_badge(badge_name: String) -> void:
	var ws := _ws()
	if badge_name not in ws["badges"]:
		ws["badges"].append(badge_name)
		badge_earned.emit(badge_name)
		_save()

func has_badge(badge_name: String) -> bool:
	return badge_name in _ws()["badges"]
	
# ── NPC Interaction ───────────────────────────────────────────────────────────
func has_talked_to(npc_id: String) -> bool:
	return npc_id in _ws()["npcs_talked"]

func mark_talked(npc_id: String) -> void:
	var ws := _ws()
	if npc_id not in ws["npcs_talked"]:
		ws["npcs_talked"].append(npc_id)
		_save()

# ── Save / Load ───────────────────────────────────────────────────────────────
func _save() -> void:
	var data := {
		"player_name": player_name,
		"world_state": world_state
	}

	var f := FileAccess.open("user://kq_save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists("user://kq_save.json"):
		return

	var f := FileAccess.open("user://kq_save.json", FileAccess.READ)
	if not f:
		return

	var raw := f.get_as_text()
	f.close()

	var data = JSON.parse_string(raw)
	if not data is Dictionary:
		return

	player_name = data.get("player_name", "Arix")
	var ws_raw = data.get("world_state", {})

	for wid in ws_raw:
		var w = ws_raw[wid]

		# 🔥 CRITICAL FIX: sanitize grid_pos
		if w.has("grid_pos"):
			var g = w["grid_pos"]

			if g is Dictionary:
				w["grid_pos"] = Vector2i(g.get("x", 2), g.get("y", 8))

			elif g is String:
				var cleaned = g.replace("(", "").replace(")", "")
				var parts = cleaned.split(",")
				if parts.size() == 2:
					w["grid_pos"] = Vector2i(int(parts[0]), int(parts[1]))
				else:
					w["grid_pos"] = Vector2i(2, 8)

		world_state[wid] = w
