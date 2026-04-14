# Player.gd — CharacterBody2D — FIXED hold-to-move + hard map bounds
extends CharacterBody2D

const TILE_SIZE   := 32
const FIRST_DELAY := 0.22   # seconds before hold repeat starts
const HOLD_RATE   := 0.10   # seconds between steps while held

signal interact_at(grid_pos: Vector2i, direction: int)
signal player_moved(grid_pos: Vector2i)

# ── Public state ──────────────────────────────────────────────────────────────
var grid_pos:    Vector2i = Vector2i(7, 7)
var facing:      int      = 0    # 0=down 1=up 2=left 3=right
var is_moving:   bool     = false
var dialog_open: bool     = false

# Map bounds set by World (REQUIRED to prevent out-of-bounds)
var map_cols: int = 20
var map_rows: int = 15

# Blocked tile list set by World
var blocked_tiles: Array = []

# ── Hold-movement timers ──────────────────────────────────────────────────────
var _hold_t:  float    = 0.0
var _step_t:  float    = 0.0
var _last_dir:Vector2i = Vector2i.ZERO

# ── Animation ─────────────────────────────────────────────────────────────────
var _frame: int   = 0
var _anim_t:float = 0.0
var _tween: Tween = null

func _ready() -> void:
	_sync_pixel_pos()

func set_grid_start(gp: Vector2i, blocked: Array, cols: int, rows: int) -> void:
	map_cols      = cols
	map_rows      = rows
	blocked_tiles = blocked
	# Hard-clamp start position
	grid_pos      = _clamp_pos(gp)
	_sync_pixel_pos()

func _sync_pixel_pos() -> void:
	position = Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2,
	                   grid_pos.y * TILE_SIZE + TILE_SIZE / 2)

# ── HARD BOUNDS CHECK ─────────────────────────────────────────────────────────
func _clamp_pos(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, 0, map_cols - 1),
	                clampi(p.y, 0, map_rows - 1))

func _is_walkable(p: Vector2i) -> bool:
	# 1. Hard map bounds — NEVER leave the grid
	if p.x < 0 or p.x >= map_cols or p.y < 0 or p.y >= map_rows:
		return false
	# 2. Check blocked tile list
	for b in blocked_tiles:
		if b == p:
			return false
	return true

# ═══════════════════════════════════════════════════════════════════════════════
#  PHYSICS PROCESS — hold-to-move
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if dialog_open or is_moving:
		_hold_t   = 0.0
		_step_t   = 0.0
		_last_dir = Vector2i.ZERO
		return

	# Read direction
	var dir := Vector2i.ZERO
	var face := -1
	if   Input.is_action_pressed("ui_down"):  dir = Vector2i( 0, 1); face = 0
	elif Input.is_action_pressed("ui_up"):    dir = Vector2i( 0,-1); face = 1
	elif Input.is_action_pressed("ui_left"):  dir = Vector2i(-1, 0); face = 2
	elif Input.is_action_pressed("ui_right"): dir = Vector2i( 1, 0); face = 3

	# Interact (just pressed — fires only once)
	if Input.is_action_just_pressed("ui_accept") and not dialog_open:
		var front := grid_pos + _dir_vec(facing)
		interact_at.emit(front, facing)
		return

	if face >= 0:
		facing = face

	if dir == Vector2i.ZERO:
		_hold_t   = 0.0
		_step_t   = 0.0
		_last_dir = Vector2i.ZERO
		return

	# Direction changed → step immediately, reset timers
	if dir != _last_dir:
		_last_dir = dir
		_hold_t   = 0.0
		_step_t   = 0.0
		_try_step(dir)
		return

	# Still holding same direction
	_hold_t += delta
	if _hold_t < FIRST_DELAY:
		return   # initial pause before repeat

	_step_t += delta
	if _step_t >= HOLD_RATE:
		_step_t = 0.0
		_try_step(dir)

func _try_step(dir: Vector2i) -> void:
	var dest := grid_pos + dir
	if not _is_walkable(dest):
		return
	_do_move(dest)

func _do_move(dest: Vector2i) -> void:
	# Extra safety clamp
	dest      = _clamp_pos(dest)
	grid_pos  = dest
	is_moving = true
	z_index   = dest.y

	var target := Vector2(dest.x * TILE_SIZE + TILE_SIZE / 2,
	                      dest.y * TILE_SIZE + TILE_SIZE / 2)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "position", target, 0.10)
	_tween.tween_callback(func():
		is_moving = false
		player_moved.emit(grid_pos)
	)

	# Walk animation tick
	_anim_t += 0.1
	if _anim_t >= 0.1:
		_anim_t = 0.0
		_frame  = 1 - _frame

	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _dir_vec(d: int) -> Vector2i:
	match d:
		0: return Vector2i( 0,  1)
		1: return Vector2i( 0, -1)
		2: return Vector2i(-1,  0)
		3: return Vector2i( 1,  0)
	return Vector2i.ZERO

# ═══════════════════════════════════════════════════════════════════════════════
#  DRAWING — 2.5D Gen 1/2 Pokémon-style player sprite
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var f   := _frame if is_moving else 0
	var lo  := -3 if f == 0 else  3
	var ro  :=  3 if f == 0 else -3
	var ox  := -TILE_SIZE / 2
	var oy  := -TILE_SIZE / 2
	_draw_sprite(ox, oy, lo, ro)

func _draw_sprite(ox: int, oy: int, lo: int, ro: int) -> void:
	var DK  := Color("#181010")
	var SKN := Color("#f0c890")
	var RED := Color("#c01018")
	var RDL := Color("#e02020")
	var RDD := Color("#980c10")
	var BLU := Color("#1828a0")
	var GLD := Color("#ffd700")

	# Shadow
	draw_rect(Rect2(ox+4,  oy+30, 24,  5), Color(0,0,0,0.22))

	# Shoes (walk animation via lo/ro offset)
	draw_rect(Rect2(ox+5+lo,  oy+26,  9, 5), DK)
	draw_rect(Rect2(ox+6+lo,  oy+27,  7, 4), Color("#282828"))
	draw_rect(Rect2(ox+18+ro, oy+26,  9, 5), DK)
	draw_rect(Rect2(ox+19+ro, oy+27,  7, 4), Color("#282828"))

	# Pants (2 legs visible)
	draw_rect(Rect2(ox+6,   oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+17,  oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+7,   oy+15,  5, 13), BLU.lightened(0.12))
	draw_rect(Rect2(ox+6,   oy+15, 10, 13), DK, false, 1.0)
	draw_rect(Rect2(ox+17,  oy+15, 10, 13), DK, false, 1.0)

	# Belt + buckle
	draw_rect(Rect2(ox+5,   oy+14, 22,  3), Color("#502808"))
	draw_rect(Rect2(ox+13,  oy+14,  5,  3), GLD)

	# Red shirt (layered for shading)
	draw_rect(Rect2(ox+4,   oy+7,  24,  9), RED)
	draw_rect(Rect2(ox+4,   oy+7,  24,  3), RDL)   # highlight
	draw_rect(Rect2(ox+4,   oy+12, 24,  4), RDD)   # shadow
	draw_rect(Rect2(ox+4,   oy+7,  24,  9), DK, false, 1.0)
	draw_rect(Rect2(ox+12,  oy+7,   8,  4), Color("#e8e8e8"))  # collar

	# Arms
	draw_rect(Rect2(ox+0,   oy+8,   5, 11), SKN)
	draw_rect(Rect2(ox+0,   oy+8,   5, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+1,   oy+8,   3,  5), SKN.lightened(0.15))
	draw_rect(Rect2(ox+27,  oy+8,   5, 11), SKN)
	draw_rect(Rect2(ox+27,  oy+8,   5, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+28,  oy+8,   3,  5), SKN.lightened(0.15))

	# Neck
	draw_rect(Rect2(ox+13,  oy+4,   6,  5), SKN)

	# Head
	draw_rect(Rect2(ox+7,   oy+0,  18, 11), SKN)
	draw_rect(Rect2(ox+7,   oy+0,  18, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+8,   oy+0,  16,  4), SKN.lightened(0.2))
	draw_rect(Rect2(ox+7,   oy+7,  18,  4), SKN.darkened(0.1))

	# Cap brim (extends past head)
	draw_rect(Rect2(ox+5,   oy+3,  22,  3), RED)
	draw_rect(Rect2(ox+5,   oy+3,  22,  3), DK, false, 1.0)
	# Cap body
	draw_rect(Rect2(ox+6,   oy+0,  20,  5), RED)
	draw_rect(Rect2(ox+6,   oy+0,  20,  5), DK, false, 1.0)
	draw_rect(Rect2(ox+7,   oy+0,  16,  2), RDL)  # highlight
	# Cap badge
	draw_rect(Rect2(ox+14,  oy+1,   5,  3), GLD)
	draw_rect(Rect2(ox+15,  oy+1,   3,  2), Color(1,1,1,0.5))

	# Eyes — direction-aware
	match facing:
		0:   # South — full face
			draw_rect(Rect2(ox+10, oy+6,  4,  3), DK)
			draw_rect(Rect2(ox+18, oy+6,  4,  3), DK)
			draw_rect(Rect2(ox+11, oy+6,  2,  2), Color(1,1,1,0.65))
			draw_rect(Rect2(ox+19, oy+6,  2,  2), Color(1,1,1,0.65))
		1:   # North — back of head
			draw_rect(Rect2(ox+10, oy+6,  4,  3), DK)
			draw_rect(Rect2(ox+18, oy+6,  4,  3), DK)
		2:   # West
			draw_rect(Rect2(ox+9,  oy+6,  4,  3), DK)
			draw_rect(Rect2(ox+10, oy+6,  2,  2), Color(1,1,1,0.6))
		3:   # East
			draw_rect(Rect2(ox+19, oy+6,  4,  3), DK)
			draw_rect(Rect2(ox+20, oy+6,  2,  2), Color(1,1,1,0.6))
