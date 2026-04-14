# Player.gd — CharacterBody2D with hold-to-move grid movement
# Attached to: CharacterBody2D node in World scene
extends CharacterBody2D

# ── Movement config ───────────────────────────────────────────────────────────
const TILE_SIZE    := 32
const MOVE_SPEED   := 200.0          # pixels/sec for smooth tween
const FIRST_DELAY  := 0.22           # seconds before hold kicks in
const HOLD_RATE    := 0.10           # seconds between steps while held

signal interact_at(grid_pos:Vector2i, direction:int)
signal player_moved(grid_pos:Vector2i)

# ── State ─────────────────────────────────────────────────────────────────────
var grid_pos:    Vector2i = Vector2i(7,7)
var facing:      int      = 2          # 0=down,1=up,2=left,3=right
var is_moving:   bool     = false
var dialog_open: bool     = false

var _hold_timer:  float = 0.0         # time current key has been held
var _step_timer:  float = 0.0         # time until next step fires
var _last_dir:    Vector2i = Vector2i.ZERO
var _tween:       Tween = null

# ── Animation ─────────────────────────────────────────────────────────────────
var _anim_frame:  int   = 0
var _anim_timer:  float = 0.0
var _walk_cycle:  bool  = false

# ── Collidables (set by World) ────────────────────────────────────────────────
var blocked_tiles: Array = []   # Array of Vector2i that are walls/water/etc.

func _ready()->void:
	position = Vector2(grid_pos.x*TILE_SIZE + TILE_SIZE/2,
	                   grid_pos.y*TILE_SIZE + TILE_SIZE/2)
	z_index = 0

func set_grid_start(gp:Vector2i, blocked:Array)->void:
	grid_pos    = gp
	blocked_tiles = blocked
	position = Vector2(gp.x*TILE_SIZE + TILE_SIZE/2,
	                   gp.y*TILE_SIZE + TILE_SIZE/2)

# ═══════════════════════════════════════════════════════════════════════════════
#  PHYSICS PROCESS — hold-to-move runs every frame
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta:float)->void:
	if dialog_open or is_moving:
		_hold_timer = 0.0
		_step_timer = 0.0
		_last_dir   = Vector2i.ZERO
		return

	# Read held direction
	var dir := Vector2i.ZERO
	var face_override := -1
	if   Input.is_action_pressed("ui_down"):  dir=Vector2i(0,1);  face_override=0
	elif Input.is_action_pressed("ui_up"):    dir=Vector2i(0,-1); face_override=1
	elif Input.is_action_pressed("ui_left"):  dir=Vector2i(-1,0); face_override=2
	elif Input.is_action_pressed("ui_right"): dir=Vector2i(1,0);  face_override=3

	# Interact
	if Input.is_action_just_pressed("ui_accept"):
		var front := grid_pos + _dir_vec(facing)
		interact_at.emit(front, facing)
		return

	if face_override>=0: facing = face_override

	if dir == Vector2i.ZERO:
		_hold_timer = 0.0; _step_timer = 0.0; _last_dir = Vector2i.ZERO
		_anim_frame = 0; queue_redraw(); return

	# First press or direction change — step immediately
	if dir != _last_dir:
		_last_dir  = dir
		_hold_timer = 0.0
		_step_timer = 0.0
		_try_step(dir)
		return

	# Hold timing
	_hold_timer += delta
	if _hold_timer < FIRST_DELAY: return   # wait before repeat starts

	_step_timer += delta
	if _step_timer >= HOLD_RATE:
		_step_timer = 0.0
		_try_step(dir)

func _try_step(dir:Vector2i)->void:
	var dest := grid_pos + dir
	if not _is_walkable(dest): return
	_move_to(dest)

func _is_walkable(p:Vector2i)->bool:
	for b in blocked_tiles:
		if b == p: return false
	return true

func _move_to(dest:Vector2i)->void:
	grid_pos  = dest
	is_moving = true
	_walk_cycle = true

	var target_px := Vector2(dest.x*TILE_SIZE + TILE_SIZE/2,
	                          dest.y*TILE_SIZE + TILE_SIZE/2)

	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self,"position",target_px,0.1)
	_tween.tween_callback(func():
		is_moving = false
		player_moved.emit(grid_pos)
	)
	# Update z_index for depth sorting
	z_index = dest.y

	# Animate walk frame
	_anim_timer += 0.1
	if _anim_timer >= 0.1:
		_anim_timer = 0.0
		_anim_frame = 1 - _anim_frame
	queue_redraw()

func _process(delta:float)->void:
	# Continuous redraw for smooth visuals
	queue_redraw()

func _dir_vec(d:int)->Vector2i:
	match d:
		0: return Vector2i(0,1)
		1: return Vector2i(0,-1)
		2: return Vector2i(-1,0)
		3: return Vector2i(1,0)
	return Vector2i.ZERO

# ═══════════════════════════════════════════════════════════════════════════════
#  PIXEL ART PLAYER DRAWING — 2.5D Pokemon Gen 1/2 style
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	var f  := _anim_frame if is_moving else 0
	var lo := -3 if f==0 else 3
	var ro :=  3 if f==0 else -3
	# Center sprite on origin (position is the center of the tile)
	var ox := -TILE_SIZE/2
	var oy := -TILE_SIZE/2
	_draw_player_sprite(ox, oy, lo, ro)

func _draw_player_sprite(ox:int, oy:int, lo:int, ro:int)->void:
	var DK  := Color("#181010")
	var SKN := Color("#f0c890")
	var RED := Color("#c01018")
	var RDL := Color("#e02020")
	var RDD := Color("#980c10")
	var BLU := Color("#1828a0")
	var CAP := Color("#c01018")
	var GLD := Color("#ffd700")

	# ── Ground shadow ──────────────────────────────────────────────────────
	draw_rect(Rect2(ox+5, oy+30, 22, 5), Color(0,0,0,0.22))

	# ── Shoes ─────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+5+lo, oy+26, 9, 5), DK)
	draw_rect(Rect2(ox+6+lo, oy+27, 7, 4), Color("#282828"))
	draw_rect(Rect2(ox+18+ro,oy+26, 9, 5), DK)
	draw_rect(Rect2(ox+19+ro,oy+27, 7, 4), Color("#282828"))

	# ── Pants ─────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+6,  oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+17, oy+15, 10, 13), BLU)
	draw_rect(Rect2(ox+7,  oy+15,  5, 13), BLU.lightened(0.12))
	draw_rect(Rect2(ox+6,  oy+15, 10, 13), DK, false, 1.0)
	draw_rect(Rect2(ox+17, oy+15, 10, 13), DK, false, 1.0)

	# Belt
	draw_rect(Rect2(ox+5,  oy+14, 22, 3), Color("#502808"))
	draw_rect(Rect2(ox+13, oy+14,  5, 3), GLD)

	# ── Shirt ─────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+4, oy+7, 24, 9), RED)
	draw_rect(Rect2(ox+4, oy+7, 24, 3), RDL)
	draw_rect(Rect2(ox+4, oy+12,24, 4), RDD)
	draw_rect(Rect2(ox+4, oy+7, 24, 9), DK, false, 1.0)
	draw_rect(Rect2(ox+12,oy+7,  8, 4), Color("#e8e8e8"))  # collar

	# ── Arms ──────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+0, oy+8, 5, 11), SKN); draw_rect(Rect2(ox+0,oy+8,5,11),DK,false,1.0)
	draw_rect(Rect2(ox+1, oy+8, 3,  5), SKN.lightened(0.15))
	draw_rect(Rect2(ox+27,oy+8, 5, 11), SKN); draw_rect(Rect2(ox+27,oy+8,5,11),DK,false,1.0)
	draw_rect(Rect2(ox+28,oy+8, 3,  5), SKN.lightened(0.15))

	# ── Neck ──────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+13, oy+4, 6, 5), SKN)

	# ── Head ──────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+7, oy+0, 18, 11), SKN)
	draw_rect(Rect2(ox+7, oy+0, 18, 11), DK, false, 1.0)
	draw_rect(Rect2(ox+8, oy+0, 16,  4), SKN.lightened(0.2))
	draw_rect(Rect2(ox+7, oy+7, 18,  4), SKN.darkened(0.1))

	# ── Cap ───────────────────────────────────────────────────────────────
	draw_rect(Rect2(ox+5, oy+3, 22, 3), CAP); draw_rect(Rect2(ox+5,oy+3,22,3),DK,false,1.0)
	draw_rect(Rect2(ox+6, oy+0, 20, 5), CAP); draw_rect(Rect2(ox+6,oy+0,20,5),DK,false,1.0)
	draw_rect(Rect2(ox+7, oy+0, 16, 2), RDL)  # highlight strip
	draw_rect(Rect2(ox+14,oy+1,  5, 3), GLD)  # badge

	# ── Eyes (direction-aware) ────────────────────────────────────────────
	match facing:
		0:  # south — full face
			draw_rect(Rect2(ox+10,oy+6, 4,3), DK)
			draw_rect(Rect2(ox+18,oy+6, 4,3), DK)
			draw_rect(Rect2(ox+11,oy+6, 2,2), Color(1,1,1,0.7))
			draw_rect(Rect2(ox+19,oy+6, 2,2), Color(1,1,1,0.7))
		1:  # north — back of head
			draw_rect(Rect2(ox+10,oy+6, 4,3), DK)
			draw_rect(Rect2(ox+18,oy+6, 4,3), DK)
		2:  # west
			draw_rect(Rect2(ox+9, oy+6, 4,3), DK)
			draw_rect(Rect2(ox+10,oy+6, 2,2), Color(1,1,1,0.65))
		3:  # east
			draw_rect(Rect2(ox+19,oy+6, 4,3), DK)
			draw_rect(Rect2(ox+20,oy+6, 2,2), Color(1,1,1,0.65))
