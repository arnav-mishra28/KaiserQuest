# GameManager.gd
# Global singleton: player stats, XP, badge tracking, save/load
extends Node

# ── Player Stats ──────────────────────────────────────────────────────────────
var player_name:      String       = "Alex"
var player_level:     int          = 1
var player_xp:        int          = 0
var xp_to_next_level: int          = 100
var badges:           Array        = []
var player_grid_pos:  Vector2i     = Vector2i(2, 8)
var npcs_talked:      Array        = []   # NPC IDs already rewarded
var items_collected:  Array        = []   # Item IDs already collected

# ── Signals ───────────────────────────────────────────────────────────────────
signal xp_changed(cur: int, max_val: int, level: int)
signal level_up_occurred(new_level: int)
signal badge_earned(badge_name: String)

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	load_game()

# ── XP & Leveling ─────────────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	player_xp += amount
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		player_level += 1
		level_up_occurred.emit(player_level)
	xp_changed.emit(player_xp, xp_to_next_level, player_level)
	save_game()

# ── Gym Logic ─────────────────────────────────────────────────────────────────
func can_challenge_gym(gym_number: int) -> bool:
	return player_level >= gym_number * 5

func has_badge(badge_name: String) -> bool:
	return badge_name in badges

func earn_badge(badge_name: String) -> void:
	if badge_name not in badges:
		badges.append(badge_name)
		badge_earned.emit(badge_name)
		save_game()

# ── NPC / Item Tracking ───────────────────────────────────────────────────────
func has_talked_to(npc_id: String) -> bool:
	return npc_id in npcs_talked

func mark_talked(npc_id: String) -> void:
	if npc_id not in npcs_talked:
		npcs_talked.append(npc_id)

func has_item(item_id: String) -> bool:
	return item_id in items_collected

func collect_item(item_id: String) -> void:
	if item_id not in items_collected:
		items_collected.append(item_id)

# ── Save / Load ───────────────────────────────────────────────────────────────
func save_game() -> void:
	var data := {
		"player_name":    player_name,
		"player_level":   player_level,
		"player_xp":      player_xp,
		"xp_to_next":     xp_to_next_level,
		"badges":         badges,
		"grid_pos":       {"x": player_grid_pos.x, "y": player_grid_pos.y},
		"npcs_talked":    npcs_talked,
		"items_collected":items_collected
	}
	var file := FileAccess.open("user://kq_save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists("user://kq_save.json"):
		return
	var file := FileAccess.open("user://kq_save.json", FileAccess.READ)
	if not file:
		return
	var raw   := file.get_as_text()
	file.close()
	var data = JSON.parse_string(raw)
	if not data is Dictionary:
		return
	player_name      = data.get("player_name",  "Alex")
	player_level     = data.get("player_level",  1)
	player_xp        = data.get("player_xp",     0)
	xp_to_next_level = data.get("xp_to_next",    100)
	badges           = data.get("badges",         [])
	npcs_talked      = data.get("npcs_talked",    [])
	items_collected  = data.get("items_collected",[])
	var gp           = data.get("grid_pos", {"x": 2, "y": 8})
	player_grid_pos  = Vector2i(gp.get("x", 2), gp.get("y", 8))

func reset_game() -> void:
	player_name      = "Alex"
	player_level     = 1
	player_xp        = 0
	xp_to_next_level = 100
	badges           = []
	player_grid_pos  = Vector2i(2, 8)
	npcs_talked      = []
	items_collected  = []
	if FileAccess.file_exists("user://kq_save.json"):
		DirAccess.remove_absolute("user://kq_save.json")
