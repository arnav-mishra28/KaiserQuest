# Overworld.gd
# Top-down pixel town: draws map, player, NPCs; handles movement & interaction
extends Node2D

# ── Signals to Main ───────────────────────────────────────────────────────────
signal show_dialog(lines: Array)
signal start_gym_battle(gym_data: Dictionary)
signal gain_xp(amount: int, context: String)

# ── Tile Constants ────────────────────────────────────────────────────────────
const TS  := 32   # Tile size in pixels
const COLS := 15
const ROWS := 10

const GRASS    := 0
const TREE     := 1
const HOUSE    := 2
const DOOR     := 3
const PATH     := 4
const GYM_WALL := 5
const GYM_DOOR := 6
const ITEM     := 7   # Collectible item on the ground

# Tile colours (GBA-inspired palette)
const C_GRASS1  := Color("#5a8f3c")
const C_GRASS2  := Color("#4e7e35")
const C_TREE    := Color("#244f14")
const C_TREE_LT := Color("#2e6318")
const C_BARK    := Color("#5a3210")
const C_HOUSE   := Color("#c8a882")
const C_ROOF    := Color("#8b2222")
const C_WIN     := Color("#aaddff")
const C_DOOR    := Color("#5a3010")
const C_PATH1   := Color("#c8b878")
const C_PATH2   := Color("#bca86e")
const C_GYM     := Color("#3a5fa0")
const C_GYM_D   := Color("#7ab0e0")
const C_GYM_TOP := Color("#2a4880")
const C_ITEM    := Color("#ffe040")   # Glowing scroll / orb
const C_BORDER  := Color("#111111")

# ── Map Layout ────────────────────────────────────────────────────────────────
# 15 cols × 10 rows — fits exactly in 480×320 at TS=32
const MAP := [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],  # row 0
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,1],  # row 1
	[1,0,2,2,0,0,0,0,0,2,2,0,0,0,1],  # row 2  houses
	[1,0,2,2,0,0,0,0,0,2,2,0,0,0,1],  # row 3
	[1,0,3,0,0,0,0,0,0,0,3,0,0,0,1],  # row 4  house doors
	[1,0,0,0,0,0,4,4,4,0,0,7,0,0,1],  # row 5  path + ITEM at (11,5)
	[1,0,0,0,0,4,0,0,0,4,0,0,0,0,1],  # row 6  open area
	[1,0,0,0,4,5,5,6,5,5,4,0,0,0,1],  # row 7  GYM
	[1,0,0,0,0,4,4,4,4,4,0,0,0,0,1],  # row 8  path below gym
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],  # row 9
]

# Walkable tiles
const WALKABLE := [GRASS, PATH, ITEM]

# ── NPC Definitions ───────────────────────────────────────────────────────────
const NPCS := [
	{
		"id":      "npc_hint",
		"pos":     Vector2i(7, 6),
		"color":   Color("#e8c830"),   # yellow shirt
		"xp":      50,
		"lines":   [
			"Psst! That blue building ahead\nis the Algebra Gym!",
			"The leader is Professor Axiom.\nYou need Level 5 to challenge him!",
			"Talk to people around town\nto gain XP and level up!"
		]
	},
	{
		"id":      "npc_scholar",
		"pos":     Vector2i(11, 2),
		"color":   Color("#30a030"),   # green shirt
		"xp":      50,
		"lines":   [
			"Welcome to Mathopolis!\nThis town is famous for scholars.",
			"A variable is a letter that\nstands for an unknown number.",
			"For example: if x + 2 = 5,\nthen  x = 3!"
		]
	},
	{
		"id":      "npc_traveler",
		"pos":     Vector2i(1, 6),
		"color":   Color("#a03030"),   # red shirt
		"xp":      50,
		"lines":   [
			"I've travelled far to study\nunder Professor Axiom.",
			"His Variable Badge is one of\n20 badges in the Algebra region!",
			"Collect all 20 and you can\nchallenge Silver Mountain!"
		]
	},
	{
		"id":      "npc_elder",
		"pos":     Vector2i(3, 3),
		"color":   Color("#9090b0"),   # grey shirt (elder)
		"xp":      50,
		"lines":   [
			"Ah, a young learner!",
			"In my day we solved equations\nwith chalk on stone tablets.",
			"Variables let us solve for the\nunknown. Remember that, child."
		]
	},
]

# Item definition
const ITEM_DATA := {
	"id":    "algebra_scroll",
	"pos":   Vector2i(11, 5),
	"xp":    200,
	"lines": [
		"You found an Algebra Scroll!",
		"It reads: 'A variable holds a\nplace for what we do not yet know.'",
		"'Name the unknown, and you\nhave begun to solve the puzzle.'",
		"+200 XP gained!"
	]
}

# ── Player State ──────────────────────────────────────────────────────────────
var _p_grid:   Vector2i = Vector2i(2, 8)   # grid position
var _p_pixel:  Vector2  = Vector2(64, 256) # smooth draw position
var _p_dir:    int      = 0  # 0=down 1=up 2=left 3=right
var _p_moving: bool     = false
var _p_frame:  int      = 0   # walk anim frame 0/1
var _anim_t:   float    = 0.0

# ── Other State ───────────────────────────────────────────────────────────────
var _dialog_open: bool = false
var _gym_cleared: bool = false
var _tween:       Tween = null

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("overworld")
	_p_grid  = GameManager.player_grid_pos
	_p_pixel = Vector2(_p_grid.x * TS, _p_grid.y * TS)
	_gym_cleared = GameManager.has_badge("Variable Badge")
	set_process(true)

func set_dialog_open(v: bool) -> void:
	_dialog_open = v

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _dialog_open or _p_moving:
		return

	var dir := Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir = Vector2i( 0,  1); _p_dir = 0
	elif event.is_action_pressed("ui_up"):    dir = Vector2i( 0, -1); _p_dir = 1
	elif event.is_action_pressed("ui_left"):  dir = Vector2i(-1,  0); _p_dir = 2
	elif event.is_action_pressed("ui_right"): dir = Vector2i( 1,  0); _p_dir = 3
	elif event.is_action_pressed("ui_accept"):
		_try_interact()
		return

	if dir != Vector2i.ZERO:
		_try_move(_p_grid + dir)

func _try_move(dest: Vector2i) -> void:
	var tile := _tile_at(dest)
	if tile == GYM_DOOR:
		_try_enter_gym()
		return
	if tile in WALKABLE:
		_move_to(dest)
		# Auto-collect item
		if tile == ITEM and dest == ITEM_DATA.pos and not GameManager.has_item(ITEM_DATA.id):
			_collect_item()

func _move_to(dest: Vector2i) -> void:
	_p_grid  = dest
	_p_moving = true
	GameManager.player_grid_pos = dest

	var target_px := Vector2(dest.x * TS, dest.y * TS)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		func(v: Vector2): _p_pixel = v; queue_redraw(),
		_p_pixel, target_px, 0.12
	)
	_tween.tween_callback(func(): _p_moving = false)

func _try_interact() -> void:
	var front := _p_grid + _dir_vec(_p_dir)

	# Check NPCs
	for npc in NPCS:
		if npc.pos == front:
			_talk_npc(npc)
			return

	# Check item (facing it)
	if front == ITEM_DATA.pos and not GameManager.has_item(ITEM_DATA.id):
		_collect_item()
		return

	# Facing gym door
	if _tile_at(front) == GYM_DOOR:
		_try_enter_gym()
		return

	# Facing a house door
	if _tile_at(front) == DOOR:
		_open_dialog(["The door is locked tight."])

func _talk_npc(npc: Dictionary) -> void:
	var lines: Array = npc.lines.duplicate()
	var first_time := not GameManager.has_talked_to(npc.id)
	if first_time:
		GameManager.mark_talked(npc.id)
		lines.append("(+" + str(npc.xp) + " XP for listening!)")
		_open_dialog(lines)
		await get_tree().create_timer(0.05).timeout
		gain_xp.emit(npc.xp, "")
	else:
		_open_dialog(lines)

func _collect_item() -> void:
	GameManager.collect_item(ITEM_DATA.id)
	_open_dialog(ITEM_DATA.lines)
	gain_xp.emit(ITEM_DATA.xp, "")
	queue_redraw()

func _try_enter_gym() -> void:
	if _gym_cleared:
		_open_dialog(["You already earned the Variable Badge!\nProfessor Axiom nods with pride."])
		return
	if not GameManager.can_challenge_gym(1):
		var need := 5
		_open_dialog([
			"The gym door won't budge!",
			"You need  Level " + str(need) + "  to challenge\nProfessor Axiom.",
			"Your Level: " + str(GameManager.player_level) + "\n\nExplore town to gain XP first!"
		])
		return
	# Level OK — launch battle
	var data: Dictionary = AlgebraDB.get_gym1_leader()
	data["questions"] = AlgebraDB.get_gym1_questions()
	start_gym_battle.emit(data)

func _open_dialog(lines: Array) -> void:
	show_dialog.emit(lines)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _tile_at(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= ROWS or pos.x < 0 or pos.x >= COLS:
		return TREE
	return MAP[pos.y][pos.x]

func _dir_vec(d: int) -> Vector2i:
	match d:
		0: return Vector2i( 0,  1)
		1: return Vector2i( 0, -1)
		2: return Vector2i(-1,  0)
		3: return Vector2i( 1,  0)
	return Vector2i.ZERO

# ── Rendering ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= 0.25:
		_anim_t  = 0.0
		_p_frame = 1 - _p_frame
		queue_redraw()

func _draw() -> void:
	_draw_map()
	_draw_items()
	_draw_npcs()
	_draw_player()
	_draw_location_name()

# ── Map drawing ───────────────────────────────────────────────────────────────
func _draw_map() -> void:
	for r in ROWS:
		for c in COLS:
			var tile: int = MAP[r][c]
			var rx   := c * TS
			var ry   := r * TS
			_draw_tile(tile, rx, ry, c, r)

func _draw_tile(tile: int, rx: int, ry: int, c: int, r: int) -> void:
	var base := Rect2(rx, ry, TS, TS)
	match tile:
		GRASS:
			draw_rect(base, C_GRASS1 if (c + r) % 2 == 0 else C_GRASS2)
		TREE:
			draw_rect(base, C_TREE)
			# Foliage lighter center
			draw_rect(Rect2(rx+6, ry+4, 20, 18), C_TREE_LT)
			# Trunk
			draw_rect(Rect2(rx+11, ry+22, 10, 10), C_BARK)
		HOUSE:
			draw_rect(base, C_HOUSE)
			# Roof stripe at top
			draw_rect(Rect2(rx, ry, TS, 8), C_ROOF)
			# Window
			draw_rect(Rect2(rx+7, ry+12, 18, 12), C_WIN)
			draw_rect(Rect2(rx+7, ry+12, 18, 12), C_BORDER, false)
			# Window cross
			draw_rect(Rect2(rx+15, ry+12, 2, 12), C_BORDER)
			draw_rect(Rect2(rx+7,  ry+17, 18, 2), C_BORDER)
		DOOR:
			draw_rect(base, C_GRASS1 if (c + r) % 2 == 0 else C_GRASS2)
			# Door frame
			draw_rect(Rect2(rx+8, ry+8, 16, 22), C_DOOR)
			draw_rect(Rect2(rx+8, ry+8, 16, 22), C_BORDER, false)
			# Door knob
			draw_rect(Rect2(rx+20, ry+18, 3, 3), Color("#ffd700"))
		PATH:
			draw_rect(base, C_PATH1 if (c + r) % 2 == 0 else C_PATH2)
			# Pebble texture
			draw_rect(Rect2(rx+5,  ry+6,  3, 3), Color(0, 0, 0, 0.07))
			draw_rect(Rect2(rx+20, ry+21, 3, 3), Color(0, 0, 0, 0.07))
		GYM_WALL:
			draw_rect(base, C_GYM)
			# Roof stripe
			draw_rect(Rect2(rx, ry, TS, 7), C_GYM_TOP)
			# GYM letter hint — decorative bar
			draw_rect(Rect2(rx+4, ry+14, 24, 3), C_GYM_D)
		GYM_DOOR:
			draw_rect(base, C_GYM)
			# Door opening
			draw_rect(Rect2(rx+6, ry+6, 20, 24), C_GYM_D)
			draw_rect(Rect2(rx+6, ry+6, 20, 24), C_BORDER, false)
			# Door shine strip
			draw_rect(Rect2(rx+8, ry+8, 4, 12), Color(1,1,1,0.25))
			# Gold badge above
			draw_rect(Rect2(rx+12, ry+1, 8, 5), Color("#ffd700"))
		ITEM:
			# Grass under item
			draw_rect(base, C_GRASS1 if (c + r) % 2 == 0 else C_GRASS2)
			# Only draw if not yet collected
			if not GameManager.has_item(ITEM_DATA.id):
				# Glowing orb/scroll
				var glow := 0.6 + sin(Time.get_ticks_msec() * 0.003) * 0.4
				draw_rect(Rect2(rx+10, ry+8, 12, 16), Color(C_ITEM.r, C_ITEM.g, C_ITEM.b, glow))
				draw_rect(Rect2(rx+12, ry+10, 8, 12), Color(1,1,0.6, glow * 0.6))
				# Sparkle
				draw_rect(Rect2(rx+13, ry+4, 2, 4), Color(1,1,1,glow))
				draw_rect(Rect2(rx+11, ry+6, 6, 2), Color(1,1,1,glow))
		_:
			draw_rect(base, Color.MAGENTA)   # Missing tile — error indicator

# ── NPCs ──────────────────────────────────────────────────────────────────────
func _draw_items() -> void:
	pass   # Items drawn in _draw_tile; separate pass not needed

func _draw_npcs() -> void:
	for npc in NPCS:
		_draw_npc(npc.pos, npc.color)

func _draw_npc(gp: Vector2i, shirt: Color) -> void:
	var px := gp.x * TS
	var py := gp.y * TS
	# Shoes
	draw_rect(Rect2(px+7,  py+27, 7, 4), Color("#111111"))
	draw_rect(Rect2(px+18, py+27, 7, 4), Color("#111111"))
	# Pants
	draw_rect(Rect2(px+8,  py+19, 14, 10), Color("#2a4a90"))
	# Shirt
	draw_rect(Rect2(px+6,  py+11, 20, 10), shirt)
	# Arms
	draw_rect(Rect2(px+2,  py+12, 5, 8), Color("#f5c5a3"))
	draw_rect(Rect2(px+25, py+12, 5, 8), Color("#f5c5a3"))
	# Head
	draw_rect(Rect2(px+9,  py+3, 14, 10), Color("#f5c5a3"))
	# Hair
	draw_rect(Rect2(px+9,  py+3, 14, 4), Color("#5a3010"))
	# Eyes
	draw_rect(Rect2(px+12, py+9, 3, 3), Color("#111111"))
	draw_rect(Rect2(px+18, py+9, 3, 3), Color("#111111"))

# ── Player ────────────────────────────────────────────────────────────────────
func _draw_player() -> void:
	var px := int(_p_pixel.x)
	var py := int(_p_pixel.y)
	var fr := _p_frame if _p_moving else 0

	# Leg animation offsets
	var lo := -2 if fr == 0 else 2
	var ro :=  2 if fr == 0 else -2

	# Shoes
	draw_rect(Rect2(px+6+lo,  py+27, 7, 4), Color("#111111"))
	draw_rect(Rect2(px+18+ro, py+27, 7, 4), Color("#111111"))
	# Pants
	draw_rect(Rect2(px+7,  py+18, 7, 11), Color("#1a3a8f"))
	draw_rect(Rect2(px+18, py+18, 7, 11), Color("#1a3a8f"))
	# Shirt (Red — a nod to the original!)
	draw_rect(Rect2(px+5,  py+10, 22, 11), Color("#d02020"))
	# Arms
	draw_rect(Rect2(px+1,  py+11, 5, 9), Color("#f5c5a3"))
	draw_rect(Rect2(px+26, py+11, 5, 9), Color("#f5c5a3"))
	# Head
	draw_rect(Rect2(px+8,  py+2, 16, 10), Color("#f5c5a3"))
	# Hair / cap
	draw_rect(Rect2(px+7,  py+2, 18, 5), Color("#111111"))
	draw_rect(Rect2(px+5,  py+4, 22, 3), Color("#d02020"))   # cap brim
	# Eyes (only facing down = front)
	if _p_dir == 0:
		draw_rect(Rect2(px+11, py+8, 3, 3), Color("#111111"))
		draw_rect(Rect2(px+18, py+8, 3, 3), Color("#111111"))
	elif _p_dir == 2:   # left
		draw_rect(Rect2(px+10, py+8, 3, 3), Color("#111111"))
	elif _p_dir == 3:   # right
		draw_rect(Rect2(px+19, py+8, 3, 3), Color("#111111"))
	# Direction shadow dot at feet
	var shadow_col := Color(0, 0, 0, 0.15)
	draw_rect(Rect2(px+7, py+31, 18, 3), shadow_col)

# ── Location Name ─────────────────────────────────────────────────────────────
func _draw_location_name() -> void:
	var fnt := ThemeDB.fallback_font
	# Semi-transparent pill
	draw_rect(Rect2(6, 6, 130, 20), Color(0, 0, 0, 0.45))
	draw_string(fnt, Vector2(12, 21), "Mathopolis",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffffff"))
