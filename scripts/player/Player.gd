# Player.gd — CharacterBody2D with Camera2D
# Camera2D is a child: it follows the player automatically.
# World tiles draw at real world coords — no manual camera offset needed.
extends CharacterBody2D

const TS          := 32
const FIRST_DELAY := 0.20
const HOLD_RATE   := 0.09

signal interact_at(front: Vector2i, facing: int)
signal player_moved(grid_pos: Vector2i)

var grid_pos:    Vector2i = Vector2i(7, 7)
var facing:      int      = 0   # 0=down 1=up 2=left 3=right
var is_moving:   bool     = false
var dialog_open: bool     = false
var map_cols:    int      = 20
var map_rows:    int      = 15
var blocked_tiles: Array  = []

var _hold_t:   float    = 0.0
var _step_t:   float    = 0.0
var _last_dir: Vector2i = Vector2i.ZERO
var _frame:    int      = 0
var _anim_t:   float    = 0.0
var _tween:    Tween    = null
var _cam:      Camera2D = null

func _ready() -> void:
	# ── Camera2D attached to player ──────────────────────────────────────
	# This is THE fix for the "screen moves with player" bug.
	# Camera2D follows this node's position; Godot handles the viewport.
	_cam = Camera2D.new()
	_cam.enabled           = true
	_cam.position_smoothing_enabled = false
	_cam.zoom              = Vector2(2.0, 2.0)   # 2x zoom = bigger pixels = Gen 2 look
	add_child(_cam)

	_sync_position()
	add_to_group("player")

func set_grid_start(gp: Vector2i, blocked: Array, cols: int, rows: int) -> void:
	map_cols      = cols
	map_rows      = rows
	blocked_tiles = blocked
	grid_pos      = _clamp(gp)
	_sync_position()

func _sync_position() -> void:
	position = Vector2(grid_pos.x * TS + TS / 2,
	                   grid_pos.y * TS + TS / 2)
	z_index  = grid_pos.y

func _clamp(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, 0, map_cols - 1),
	                clampi(p.y, 0, map_rows - 1))

func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= map_cols or p.y < 0 or p.y >= map_rows:
		return false
	for b in blocked_tiles:
		if b == p: return false
	return true

# ── HOLD-TO-MOVE ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dialog_open or is_moving:
		_hold_t = 0.0; _step_t = 0.0; _last_dir = Vector2i.ZERO; return

	var dir  := Vector2i.ZERO
	var face := -1
	if   Input.is_action_pressed("ui_down"):  dir = Vector2i( 0, 1); face = 0
	elif Input.is_action_pressed("ui_up"):    dir = Vector2i( 0,-1); face = 1
	elif Input.is_action_pressed("ui_left"):  dir = Vector2i(-1, 0); face = 2
	elif Input.is_action_pressed("ui_right"): dir = Vector2i( 1, 0); face = 3

	if Input.is_action_just_pressed("ui_accept") and not dialog_open:
		var front := grid_pos + _dir_vec(facing)
		interact_at.emit(front, facing)
		return

	if face >= 0: facing = face
	if dir == Vector2i.ZERO:
		_hold_t = 0.0; _step_t = 0.0; _last_dir = Vector2i.ZERO; return

	if dir != _last_dir:
		_last_dir = dir; _hold_t = 0.0; _step_t = 0.0; _try_step(dir); return

	_hold_t += delta
	if _hold_t < FIRST_DELAY: return
	_step_t += delta
	if _step_t >= HOLD_RATE: _step_t = 0.0; _try_step(dir)

func _try_step(dir: Vector2i) -> void:
	var dest := _clamp(grid_pos + dir)
	if not _is_walkable(dest): return
	grid_pos  = dest
	is_moving = true
	z_index   = dest.y
	var target := Vector2(dest.x * TS + TS / 2, dest.y * TS + TS / 2)
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "position", target, 0.10)
	_tween.tween_callback(func(): is_moving = false; player_moved.emit(grid_pos))
	_anim_t += 0.10
	if _anim_t >= 0.10: _anim_t = 0.0; _frame = 1 - _frame
	queue_redraw()

func _process(_d: float) -> void: queue_redraw()

func _dir_vec(d: int) -> Vector2i:
	match d:
		0: return Vector2i( 0, 1)
		1: return Vector2i( 0,-1)
		2: return Vector2i(-1, 0)
		3: return Vector2i( 1, 0)
	return Vector2i.ZERO

# ── 2.5D GEN 2 SPRITE ─────────────────────────────────────────────────────────
# Drawn relative to this node's origin (center of tile)
func _draw() -> void:
	var f   := _frame if is_moving else 0
	var lo  := -3 if f == 0 else  3
	var ro  :=  3 if f == 0 else -3
	var ox  := -TS / 2
	var oy  := -TS / 2
	_draw_red_sprite(ox, oy, lo, ro)

func _draw_red_sprite(ox: int, oy: int, lo: int, ro: int) -> void:
	var DK  := Color("#181010")
	var SKN := Color("#f0c890")
	var RED := Color("#c01018"); var RDL := Color("#e02020"); var RDD := Color("#980c10")
	var BLU := Color("#1828a0")
	var GLD := Color("#ffd700")

	# Ground shadow
	draw_rect(Rect2(ox+4,  oy+30, 24,  5), Color(0,0,0,0.25))

	# Shoes with walk-bob
	draw_rect(Rect2(ox+5+lo,  oy+26, 9, 5), DK)
	draw_rect(Rect2(ox+6+lo,  oy+27, 7, 4), Color("#282828"))
	draw_rect(Rect2(ox+18+ro, oy+26, 9, 5), DK)
	draw_rect(Rect2(ox+19+ro, oy+27, 7, 4), Color("#282828"))

	# Pants
	draw_rect(Rect2(ox+6,  oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+17, oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+7,  oy+15,  5, 13), BLU.lightened(0.12))
	draw_rect(Rect2(ox+6,  oy+15, 10, 13), DK, false, 1.0)
	draw_rect(Rect2(ox+17, oy+15, 10, 13), DK, false, 1.0)

	# Belt + buckle
	draw_rect(Rect2(ox+5,  oy+14, 22,  3), Color("#502808"))
	draw_rect(Rect2(ox+13, oy+14,  5,  3), GLD)

	# Red shirt
	draw_rect(Rect2(ox+4, oy+7, 24,  9), RED)
	draw_rect(Rect2(ox+4, oy+7, 24,  3), RDL)
	draw_rect(Rect2(ox+4, oy+12,24,  4), RDD)
	draw_rect(Rect2(ox+4, oy+7, 24,  9), DK, false, 1.0)
	draw_rect(Rect2(ox+12,oy+7,  8,  4), Color("#e8e8e8"))  # collar

	# Arms
	for ax in [0, 27]:
		draw_rect(Rect2(ox+ax, oy+8, 5, 11), SKN)
		draw_rect(Rect2(ox+ax, oy+8, 5, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+1,  oy+8, 3, 5), SKN.lightened(0.15))
	draw_rect(Rect2(ox+28, oy+8, 3, 5), SKN.lightened(0.15))

	# Neck
	draw_rect(Rect2(ox+13, oy+4, 6, 5), SKN)

	# Head
	draw_rect(Rect2(ox+7, oy+0, 18, 11), SKN)
	draw_rect(Rect2(ox+7, oy+0, 18, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+8, oy+0, 16,  4), SKN.lightened(0.2))
	draw_rect(Rect2(ox+7, oy+7, 18,  4), SKN.darkened(0.1))

	# Cap brim
	draw_rect(Rect2(ox+5, oy+3, 22, 3), RED)
	draw_rect(Rect2(ox+5, oy+3, 22, 3), DK, false, 1.0)
	# Cap body
	draw_rect(Rect2(ox+6, oy+0, 20, 5), RED)
	draw_rect(Rect2(ox+6, oy+0, 20, 5), DK, false, 1.0)
	draw_rect(Rect2(ox+7, oy+0, 16, 2), RDL)
	draw_rect(Rect2(ox+14,oy+1,  5, 3), GLD)
	draw_rect(Rect2(ox+15,oy+1,  3, 2), Color(1,1,1,0.55))

	# Direction eyes
	match facing:
		0:
			draw_rect(Rect2(ox+10,oy+6, 4, 3), DK)
			draw_rect(Rect2(ox+18,oy+6, 4, 3), DK)
			draw_rect(Rect2(ox+11,oy+6, 2, 2), Color(1,1,1,0.7))
			draw_rect(Rect2(ox+19,oy+6, 2, 2), Color(1,1,1,0.7))
		1:
			draw_rect(Rect2(ox+10,oy+6, 4, 3), DK)
			draw_rect(Rect2(ox+18,oy+6, 4, 3), DK)
		2:
			draw_rect(Rect2(ox+9, oy+6, 4, 3), DK)
			draw_rect(Rect2(ox+10,oy+6, 2, 2), Color(1,1,1,0.65))
		3:
			draw_rect(Rect2(ox+19,oy+6, 4, 3), DK)
			draw_rect(Rect2(ox+20,oy+6, 2, 2), Color(1,1,1,0.65))
