# Player.gd — Grid-based CharacterBody2D (no Camera2D = static world)
extends CharacterBody2D

const TS           := 32
const FIRST_DELAY  := 0.20
const HOLD_RATE    := 0.09

signal interact_at(front: Vector2i, facing: int)
signal player_moved(grid_pos: Vector2i)

var grid_pos:      Vector2i = Vector2i(7, 8)
var facing:        int      = 0
var is_moving:     bool     = false
var dialog_open:   bool     = false
var map_cols:      int      = 15
var map_rows:      int      = 10
var blocked_tiles: Array    = []

var _hold_t:   float    = 0.0
var _step_t:   float    = 0.0
var _last_dir: Vector2i = Vector2i.ZERO
var _frame:    int      = 0
var _anim_t:   float    = 0.0
var _tween:    Tween    = null

func _ready() -> void:
	add_to_group("player")
	_sync_pos()

func set_grid_start(gp: Vector2i, blocked: Array, cols: int, rows: int) -> void:
	map_cols=cols; map_rows=rows; blocked_tiles=blocked
	grid_pos=_clamp(gp); _sync_pos()

func _sync_pos() -> void:
	position=Vector2(grid_pos.x*TS+TS/2,grid_pos.y*TS+TS/2); z_index=grid_pos.y

func _clamp(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x,0,map_cols-1),clampi(p.y,0,map_rows-1))

func _is_walkable(p: Vector2i) -> bool:
	if p.x<0 or p.x>=map_cols or p.y<0 or p.y>=map_rows: return false
	for b in blocked_tiles:
		if b==p: return false
	return true

func _physics_process(delta: float) -> void:
	if dialog_open or is_moving: _hold_t=0.0; _step_t=0.0; _last_dir=Vector2i.ZERO; return
	var dir:=Vector2i.ZERO; var face:=-1
	if   Input.is_action_pressed("ui_down"):  dir=Vector2i(0,1);  face=0
	elif Input.is_action_pressed("ui_up"):    dir=Vector2i(0,-1); face=1
	elif Input.is_action_pressed("ui_left"):  dir=Vector2i(-1,0); face=2
	elif Input.is_action_pressed("ui_right"): dir=Vector2i(1,0);  face=3
	if Input.is_action_just_pressed("ui_accept") and not dialog_open:
		interact_at.emit(grid_pos+_dir_vec(facing),facing); return
	if face>=0: facing=face
	if dir==Vector2i.ZERO: _hold_t=0.0; _step_t=0.0; _last_dir=Vector2i.ZERO; return
	if dir!=_last_dir: _last_dir=dir; _hold_t=0.0; _step_t=0.0; _try_step(dir); return
	_hold_t+=delta
	if _hold_t<FIRST_DELAY: return
	_step_t+=delta
	if _step_t>=HOLD_RATE: _step_t=0.0; _try_step(dir)

func _try_step(dir: Vector2i) -> void:
	var dest:=_clamp(grid_pos+dir)
	if not _is_walkable(dest): return
	grid_pos=dest; is_moving=true; z_index=dest.y
	var target:=Vector2(dest.x*TS+TS/2,dest.y*TS+TS/2)
	if _tween: _tween.kill()
	_tween=create_tween(); _tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self,"position",target,0.10)
	_tween.tween_callback(func(): is_moving=false; player_moved.emit(grid_pos))
	_anim_t+=0.10; if _anim_t>=0.10: _anim_t=0.0; _frame=1-_frame
	queue_redraw()

func _process(_d:float)->void: queue_redraw()

func _dir_vec(d: int) -> Vector2i:
	match d:
		0:
			return Vector2i(0, 1)
		1:
			return Vector2i(0, -1)
		2:
			return Vector2i(-1, 0)
		3:
			return Vector2i(1, 0)

	return Vector2i.ZERO

func _draw()->void:
	var f:=_frame if is_moving else 0
	var lo:=-3 if f==0 else 3; var ro:=3 if f==0 else -3
	var DK:=Color("#181010"); var SKN:=Color("#f0c890")
	draw_rect(Rect2(-TS/2+4,TS/2-2,24,5),Color(0,0,0,0.22))
	draw_rect(Rect2(-TS/2+5+lo,TS/2-6,9,5),DK); draw_rect(Rect2(-TS/2+18+ro,TS/2-6,9,5),DK)
	draw_rect(Rect2(-TS/2+6,TS/2-15,9,11),Color("#1a3a8f")); draw_rect(Rect2(-TS/2+6,TS/2-15,9,11),DK,false,1.0)
	draw_rect(Rect2(-TS/2+17,TS/2-15,9,11),Color("#1a3a8f")); draw_rect(Rect2(-TS/2+17,TS/2-15,9,11),DK,false,1.0)
	draw_rect(Rect2(-TS/2+7,TS/2-15,16,4),Color("#2a4aaa"))
	draw_rect(Rect2(-TS/2+4,TS/2-23,24,10),Color("#c01010")); draw_rect(Rect2(-TS/2+4,TS/2-23,24,3),Color("#e01818"))
	draw_rect(Rect2(-TS/2+4,TS/2-23,24,10),DK,false,1.0)
	draw_rect(Rect2(-TS/2+0,TS/2-22,5,10),SKN); draw_rect(Rect2(-TS/2+0,TS/2-22,5,10),DK,false,1.0)
	draw_rect(Rect2(-TS/2+27,TS/2-22,5,10),SKN); draw_rect(Rect2(-TS/2+27,TS/2-22,5,10),DK,false,1.0)
	draw_rect(Rect2(-TS/2+7,TS/2-31,18,10),SKN); draw_rect(Rect2(-TS/2+7,TS/2-31,18,10),DK,false,1.0)
	draw_rect(Rect2(-TS/2+6,TS/2-31,20,5),Color("#c01010")); draw_rect(Rect2(-TS/2+5,TS/2-28,22,4),Color("#c01010"))
	draw_rect(Rect2(-TS/2+6,TS/2-31,20,5),DK,false,1.0); draw_rect(Rect2(-TS/2+14,TS/2-30,5,3),Color("#ffd700"))
	if facing==0:
		draw_rect(Rect2(-TS/2+10,TS/2-25,4,3),DK); draw_rect(Rect2(-TS/2+18,TS/2-25,4,3),DK)
		draw_rect(Rect2(-TS/2+11,TS/2-25,2,2),Color(1,1,1,0.7)); draw_rect(Rect2(-TS/2+19,TS/2-25,2,2),Color(1,1,1,0.7))
	elif facing==2:
		draw_rect(Rect2(-TS/2+9,TS/2-25,4,3),DK); draw_rect(Rect2(-TS/2+10,TS/2-25,2,2),Color(1,1,1,0.6))
	elif facing==3:
		draw_rect(Rect2(-TS/2+19,TS/2-25,4,3),DK); draw_rect(Rect2(-TS/2+20,TS/2-25,2,2),Color(1,1,1,0.6))
