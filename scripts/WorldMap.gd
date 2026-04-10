# WorldMap.gd  —  The full KaiserQuest region map (Kanto-style)
extends Node2D

signal enter_zone(zone_id:String)
signal show_dialog(lines:Array)

# ── Map constants ─────────────────────────────────────────────────────────────
const TS   := 16   # smaller tiles for world map (fits more world)
const COLS := 30
const ROWS := 20

# Tile IDs
const T_OCEAN  := 0; const T_GRASS := 1; const T_FOREST:= 2
const T_MTNLO  := 3; const T_MTNHI := 4; const T_PATH  := 5
const T_SAND   := 6; const T_TOWN  := 7; const T_GYM   := 8
const T_SILVER := 9; const T_WATER :=10; const T_BRIDGE:=11
const T_CAVE   :=12; const T_SIGN  :=13

# ── The full world region map ─────────────────────────────────────────────────
# 30 cols × 20 rows = 480×320 pixels at TS=16
const WMAP := [
# Col: 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29
	[ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 4, 4, 4, 4,  4, 4, 0, 0, 0, 0, 0, 0, 0, 0], # 0
	[ 0, 0, 0, 0, 2, 2, 2, 1, 1, 1,  1, 1, 1, 2, 2, 4, 9, 4, 4, 4,  4, 4, 4, 2, 2, 0, 0, 0, 0, 0], # 1
	[ 0, 0, 0, 2, 1, 1, 1, 1, 7, 5,  5, 5, 1, 1, 2, 4, 4, 4, 3, 3,  3, 4, 4, 2, 1, 0, 0, 0, 0, 0], # 2
	[ 0, 0, 2, 1, 1, 1, 5, 5, 5, 1,  1, 5, 5, 1, 2, 3, 4, 3, 1, 1,  1, 3, 4, 1, 1, 2, 0, 0, 0, 0], # 3
	[ 0, 2, 1, 1, 1, 5, 1, 1, 1, 5, 10,10, 5, 1, 1, 1, 5, 1, 1, 1,  1, 1, 5, 1, 1, 1, 2, 0, 0, 0], # 4
	[ 0, 1, 1, 7, 5, 1, 1, 1, 1,10, 10,10,10, 1, 1, 1, 5, 1, 1, 1,  1, 1, 5, 1, 7, 1, 1, 2, 0, 0], # 5
	[ 0, 1, 5, 5, 5, 1, 1, 2, 11,11, 11,11,11, 2, 1, 1, 5, 1, 1, 2,  2, 1, 5, 1, 5, 1, 1, 1, 2, 0], # 6
	[ 0, 1, 1, 8, 1, 1, 2, 1, 1, 1,  1, 1, 1, 1, 2, 1, 1, 5, 5, 1,  1, 5, 5, 1, 8, 1, 1, 1, 1, 0], # 7
	[ 0, 2, 1, 5, 1, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 5, 1, 1, 1,  1, 1, 5, 1, 5, 1, 1, 1, 2, 0], # 8
	[ 0, 1, 1, 5, 1, 1, 1, 1, 1, 6,  6, 6, 6, 1, 1, 1, 5, 1, 1, 1,  1, 1, 5, 1, 1, 1, 1, 2, 1, 0], # 9
	[ 0, 1, 5, 5, 5, 1, 1, 1, 6, 6,  7, 6, 6, 6, 1, 1, 1, 5, 5, 1,  1, 5, 5, 1, 5, 5, 5, 1, 1, 0], # 10
	[ 0, 1, 1, 8, 1, 1, 2, 1, 6, 6,  6, 6, 6, 1, 2, 1, 5, 1, 1, 1,  1, 1, 1, 1, 8, 1, 1, 1, 2, 0], # 11
	[ 0, 2, 1, 5, 1, 1, 1, 1, 1, 6,  6, 6, 6, 1, 1, 5, 1, 1, 2, 1,  1, 2, 1, 1, 5, 1, 1, 1, 1, 0], # 12
	[ 0, 1, 1, 5, 1, 1, 1, 2, 1, 1,  1, 1, 1, 2, 1, 5, 1, 1, 1, 1,  1, 1, 1, 5, 5, 1, 2, 1, 1, 0], # 13
	[ 0, 1, 5, 5, 5, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 5, 5, 5, 1,  1, 5, 1, 1, 1, 1, 1, 1, 2, 0], # 14
	[ 0, 1, 1, 7, 5, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 5, 1, 1, 1, 1,  1, 1, 5, 7, 5, 1, 1, 2, 1, 0], # 15
	[ 0, 2, 1, 5, 1, 1, 2, 2, 1, 1,  1, 1, 1, 2, 2, 1, 1, 1, 1, 1,  1, 5, 1, 5, 1, 1, 1, 1, 2, 0], # 16
	[ 0, 0, 2, 5, 1, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 1, 1, 2, 2,  2, 1, 1, 5, 1, 1, 2, 0, 0, 0], # 17
	[ 0, 0, 0, 2, 2, 1, 1, 1, 1, 1,  1, 1, 1, 1, 1, 1, 1, 2, 0, 0,  0, 2, 2, 1, 1, 2, 0, 0, 0, 0], # 18
	[ 0, 0, 0, 0, 0, 2, 2, 2, 2, 2,  2, 2, 2, 2, 2, 2, 2, 0, 0, 0,  0, 0, 0, 2, 2, 0, 0, 0, 0, 0], # 19
]

# ── Named locations on the map ────────────────────────────────────────────────
const LOCATIONS := [
	# Zone entries (walkable town tiles the player can step on to enter)
	{"id":"math",     "pos":Vector2i(8,2),  "label":"Mathopolis",   "type":"zone", "color":Color("#44aaff")},
	{"id":"english",  "pos":Vector2i(10,10),"label":"Lexicon City", "type":"zone", "color":Color("#ffcc44")},
	{"id":"music",    "pos":Vector2i(24,5), "label":"Harmonia",     "type":"zone", "color":Color("#cc44ff")},
	# Silver Mountain
	{"id":"silver",   "pos":Vector2i(16,1), "label":"Silver Mtn",   "type":"silver","color":Color("#c0c8ff")},
	# Rest towns (lore / waypoints)
	{"id":"waypoint1","pos":Vector2i(3,5),  "label":"Crossroads",   "type":"rest", "color":Color("#aaffaa")},
	{"id":"waypoint2","pos":Vector2i(23,15),"label":"Eastholm",     "type":"rest", "color":Color("#aaffaa")},
	{"id":"waypoint3","pos":Vector2i(3,15), "label":"Westfield",    "type":"rest", "color":Color("#aaffaa")},
]

# ── Gym indicators (drawn as icons) ──────────────────────────────────────────
const GYM_TILES := [
	Vector2i(3,7),  Vector2i(3,11),   # Math gyms col
	Vector2i(11,7), Vector2i(24,11),  # English gyms
	Vector2i(24,7), Vector2i(3,11),   # Music gyms
]

# ── Player ────────────────────────────────────────────────────────────────────
var _p_grid:  Vector2i = Vector2i(8,5)
var _p_pixel: Vector2  = Vector2(128,80)
var _p_dir:   int      = 0
var _moving:  bool     = false
var _dialog:  bool     = false
var _tween:   Tween    = null
var _time:    float    = 0.0
var _anim_t:  float    = 0.0
var _frame:   int      = 0
# Map offset for camera scrolling
var _cam:     Vector2  = Vector2.ZERO

func _ready()->void:
	add_to_group("overworld")
	_p_grid = _get_saved_pos()
	_p_pixel = Vector2(_p_grid.x*TS, _p_grid.y*TS)
	_update_camera()
	set_process(true); set_process_input(true)

func _get_saved_pos()->Vector2i:
	# Start in center of map near Crossroads
	return Vector2i(8,5)

func set_dialog_open(v:bool)->void: _dialog=v

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event:InputEvent)->void:
	if _dialog or _moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);  _p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1); _p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0); _p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);  _p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	if dir!=Vector2i.ZERO: _try_move(_p_grid+dir)

func _try_move(dest:Vector2i)->void:
	var t:=_tile_at(dest)
	if t in [T_OCEAN,T_MTNHI,T_FOREST]: return
	if _is_zone(dest): _enter_location(dest); return
	if _tile_at(dest)==T_WATER: return
	_do_move(dest)

func _do_move(dest:Vector2i)->void:
	_p_grid=dest; _moving=true
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tween: _tween.kill()
	_tween=create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;_update_camera();queue_redraw(),_p_pixel,tgt,0.14)
	_tween.tween_callback(func():_moving=false; _check_encounter())

func _update_camera()->void:
	const VW:=480; const VH:=320
	const MW:=COLS*TS; const MH:=ROWS*TS
	var cx:=_p_pixel.x - VW/2.0 + TS/2.0
	var cy:=_p_pixel.y - VH/2.0 + TS/2.0
	_cam.x=clamp(cx,0,MW-VW)
	_cam.y=clamp(cy,0,MH-VH)

func _check_encounter()->void:
	# Auto-trigger zone entry when stepping on zone tile
	for loc in LOCATIONS:
		if loc.pos==_p_grid:
			_enter_location(_p_grid)
			return

func _is_zone(pos:Vector2i)->bool:
	for loc in LOCATIONS:
		if loc.pos==pos: return true
	return false

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	for loc in LOCATIONS:
		if loc.pos==front:
			_prompt_enter(loc); return
	if _tile_at(front)==T_SIGN:
		show_dialog.emit(["A weathered signpost...",
			"It reads: 'Silver Mountain lies\nto the north. Only the Kaiser\nshall pass.'"])

func _prompt_enter(loc:Dictionary)->void:
	match loc.type:
		"zone":
			show_dialog.emit([
				"You are at the entrance to\n"+loc.label+"!",
				"This city holds many\nsecrets to unlock.",
				"Press ENTER while facing\nthe city to enter."
			])
		"silver":
			if not GameManager.can_challenge_silver():
				show_dialog.emit([
					"The Silver Mountain looms\nbefore you...",
					"A mysterious force repels\nyou from the gates.",
					"You need Level 100 and\nall 20 badges to enter!"
				])
			else:
				enter_zone.emit("silver")
		"rest":
			show_dialog.emit([
				"You found "+loc.label+"!",
				"Rest here and recover\nbefore your journey continues.",
				"Talking to locals may\nreveal hidden knowledge..."
			])

func _enter_location(pos:Vector2i)->void:
	for loc in LOCATIONS:
		if loc.pos==pos:
			if loc.type=="zone":
				enter_zone.emit(loc.id)
			elif loc.type=="silver":
				_prompt_enter(loc)
			return

func _tile_at(p:Vector2i)->int:
	if p.y<0 or p.y>=ROWS or p.x<0 or p.x>=COLS: return T_OCEAN
	return WMAP[p.y][p.x]
func _dv(d:int)->Vector2i:
	match d:
		0: return Vector2i(0, 1)
		1: return Vector2i(0, -1)
		2: return Vector2i(-1, 0)
		3: return Vector2i(1, 0)
	return Vector2i.ZERO

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.25: _anim_t=0.0; _frame=1-_frame
	queue_redraw()

# ═════════════════════════ DRAWING ════════════════════════════════════════════
func _draw()->void:
	var ox:=int(_cam.x); var oy:=int(_cam.y)
	_draw_tiles(ox,oy)
	_draw_locations(ox,oy)
	_draw_player(ox,oy)
	_draw_minimap()
	_draw_ui()

func _draw_tiles(ox:int,oy:int)->void:
	var c0 =int(ox/TS); var c1=min(c0+31,COLS)
	var r0 =int(oy/TS); var r1=min(r0+21,ROWS)
	for r in range(r0,r1):
		for c in range(c0,c1):
			_draw_wt(WMAP[r][c], c*TS-ox, r*TS-oy, c, r)

func _draw_wt(t:int,px:int,py:int,c:int,r:int)->void:
	var chk:=(c+r)%2==0
	match t:
		T_OCEAN:
			var wv:=0.45+0.55*sin(_time*1.4+(c+r)*0.3)
			draw_rect(Rect2(px,py,TS,TS),Color(0.05,0.15,0.55))
			draw_rect(Rect2(px+1,py+3,TS-2,2),Color(0.2,0.45,0.9,wv*0.4))
			draw_rect(Rect2(px+1,py+9,TS-2,2),Color(0.2,0.45,0.9,wv*0.3))
		T_GRASS:
			draw_rect(Rect2(px,py,TS,TS),Color("#2a5a1e") if chk else Color("#245218"))
			if (c*7+r*3)%20==0: draw_rect(Rect2(px+3,py+9,2,5),Color("#3a7a28",0.7))
		T_FOREST:
			draw_rect(Rect2(px,py,TS,TS),Color("#1a3a10"))
			draw_rect(Rect2(px+2,py+4,12,8),Color("#224a14"))
			draw_rect(Rect2(px+4,py+1,8,6),Color("#2a5c1a"))
			draw_rect(Rect2(px+5,py+10,6,6),Color("#5a3210"))
		T_MTNLO:
			draw_rect(Rect2(px,py,TS,TS),Color("#6a5a48"))
			draw_rect(Rect2(px,py,TS,TS),Color("#7a6a58"),false,1.0)
			draw_rect(Rect2(px+3,py+2,TS-6,6),Color("#8a7a68"))
		T_MTNHI:
			draw_rect(Rect2(px,py,TS,TS),Color("#555060"))
			draw_rect(Rect2(px+3,py,10,5),Color("#b0b8c8"))  # snow cap
			draw_rect(Rect2(px+5,py+1,6,3),Color("#e8ecf8"))
		T_PATH:
			draw_rect(Rect2(px,py,TS,TS),Color("#b8a868") if chk else Color("#a89858"))
			draw_rect(Rect2(px+1,py+1,5,5),Color(0,0,0,0.05))
			draw_rect(Rect2(px+9,py+9,5,5),Color(0,0,0,0.05))
		T_SAND:
			draw_rect(Rect2(px,py,TS,TS),Color("#d4b870") if chk else Color("#c4a860"))
		T_TOWN:
			draw_rect(Rect2(px,py,TS,TS),Color("#b8a868") if chk else Color("#a89858"))
			# Town marker: small house rooftop
			draw_rect(Rect2(px+2,py+5,12,9),Color("#c8a882"))
			draw_rect(Rect2(px+2,py+2,12,5),Color("#8b2222"))
			draw_rect(Rect2(px+5,py+7,6,7),Color("#aaddff"))
		T_GYM:
			draw_rect(Rect2(px,py,TS,TS),Color("#b8a868"))
			# Gym icon (small pillar)
			draw_rect(Rect2(px+3,py+3,10,11),Color("#2244aa"))
			draw_rect(Rect2(px+3,py+3,10,11),Color("#44aaff"),false,1.0)
			draw_colored_polygon(
	PackedVector2Array([Vector2(px+1,py+3), Vector2(px+8,py+0), Vector2(px+15,py+3)]),
	Color("#46aaff")
)
		T_SILVER:
			var sg:=0.6+0.4*sin(_time*2.0)
			draw_rect(Rect2(px,py,TS,TS),Color("#181830"))
			draw_rect(Rect2(px+2,py+8,12,8),Color(0.45,0.48,0.7))
			draw_colored_polygon(
	PackedVector2Array([Vector2(px+1,py+3), Vector2(px+8,py+0), Vector2(px+15,py+3)]),
	Color("#46aaff")
)
			draw_rect(Rect2(px+5,py+1,6,3),Color(0.85,0.9,1.0,sg))
		T_WATER:
			var wt:=0.4+0.6*sin(_time*2.0+(c+r)*0.5)
			draw_rect(Rect2(px,py,TS,TS),Color(0.1,0.4,0.85))
			draw_rect(Rect2(px+1,py+4,TS-2,2),Color(0.4,0.7,1.0,wt*0.5))
		T_BRIDGE:
			draw_rect(Rect2(px,py,TS,TS),Color("#8a6030"))
			draw_rect(Rect2(px+2,py,3,TS),Color("#6a4020"))
			draw_rect(Rect2(px+11,py,3,TS),Color("#6a4020"))
			draw_rect(Rect2(px,py+6,TS,4),Color("#7a5028"))
		T_CAVE:
			draw_rect(Rect2(px,py,TS,TS),Color("#3a3040"))
			draw_rect(Rect2(px+3,py+4,10,9),Color("#111118"))
			draw_rect(Rect2(px+3,py+4,10,9),Color("#555060"),false,1.0)
		T_SIGN:
			draw_rect(Rect2(px,py,TS,TS),Color("#2a5a1e"))
			draw_rect(Rect2(px+5,py+5,6,8),Color("#5a3810"))
			draw_rect(Rect2(px+2,py+3,12,5),Color("#aa7030"))
			draw_rect(Rect2(px+2,py+3,12,5),Color("#ffd700"),false,1.0)
		_:
			draw_rect(Rect2(px,py,TS,TS),Color("#2a5a1e"))

# ── Location labels ───────────────────────────────────────────────────────────
func _draw_locations(ox:int,oy:int)->void:
	var fnt:=ThemeDB.fallback_font
	for loc in LOCATIONS:
		var sx=loc.pos.x*TS-ox; var sy=loc.pos.y*TS-oy
		if sx<-60 or sx>500 or sy<-20 or sy>340: continue
		# Glow pulse for active zones
		var pulse:=0.6+0.4*sin(_time*2.5+loc.pos.x)
		# Name label
		draw_rect(Rect2(sx-2,sy-14,len(loc.label)*7+6,13),Color(0,0,0,0.65))
		draw_string(fnt,Vector2(sx,sy-3),loc.label,
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,loc.color*Color(1,1,1,pulse))
		# World zone highlight ring
		if loc.type in ["zone","silver"]:
			draw_rect(Rect2(sx-2,sy-2,TS+4,TS+4),loc.color*Color(1,1,1,0.3+pulse*0.2),false,1.5)

# ── Player sprite (mini on world map) ────────────────────────────────────────
func _draw_player(ox:int,oy:int)->void:
	var px:=int(_p_pixel.x)-ox; var py:=int(_p_pixel.y)-oy
	var bob:=0 if _frame==0 else -1
	# Shadow
	draw_rect(Rect2(px+2,py+13,12,3),Color(0,0,0,0.22))
	# Legs
	draw_rect(Rect2(px+3,py+9+bob,4,6),Color("#1a3a8f"))
	draw_rect(Rect2(px+9,py+9-bob,4,6),Color("#1a3a8f"))
	# Body
	draw_rect(Rect2(px+2,py+4,12,7),Color("#cc1818"))
	draw_rect(Rect2(px+2,py+4,12,2),Color("#e02020"))
	# Head
	draw_rect(Rect2(px+4,py+0,8,5),Color("#f0c090"))
	# Cap
	draw_rect(Rect2(px+3,py+0,10,3),Color("#cc1818"))
	draw_rect(Rect2(px+2,py+2,12,2),Color("#cc1818"))
	# Eyes
	if _p_dir==0:
		draw_rect(Rect2(px+5,py+3,2,2),Color("#111111"))
		draw_rect(Rect2(px+9,py+3,2,2),Color("#111111"))

# ── Minimap (corner overview) ─────────────────────────────────────────────────
func _draw_minimap()->void:
	const MX:=4; const MY:=4; const MW:=60; const MH:=40; const MS:=2
	draw_rect(Rect2(MX-1,MY-1,MW+2,MH+2),Color(0,0,0,0.7))
	draw_rect(Rect2(MX-1,MY-1,MW+2,MH+2),Color(0.5,0.5,0.8,0.6),false,1.0)
	for r in range(0,ROWS,1):
		for c in range(0,COLS,1):
			var t=WMAP[r][c]
			var mc:Color
			match t:
				T_OCEAN:  mc=Color(0.05,0.15,0.55)
				T_GRASS:  mc=Color(0.2,0.5,0.15)
				T_FOREST: mc=Color(0.1,0.3,0.1)
				T_MTNLO:  mc=Color(0.5,0.44,0.36)
				T_MTNHI:  mc=Color(0.7,0.72,0.8)
				T_PATH:   mc=Color(0.75,0.68,0.44)
				T_TOWN:   mc=Color(0.9,0.7,0.4)
				T_GYM:    mc=Color(0.2,0.4,0.9)
				T_SILVER: mc=Color(0.7,0.72,0.9)
				T_WATER:  mc=Color(0.1,0.4,0.85)
				_:         mc=Color(0.2,0.45,0.15)
			draw_rect(Rect2(MX+c*MS,MY+r*MS,MS,MS),mc)
	# Player dot
	draw_rect(Rect2(MX+_p_grid.x*MS-1,MY+_p_grid.y*MS-1,3,3),Color("#ffffff"))

# ── UI overlay ────────────────────────────────────────────────────────────────
func _draw_ui()->void:
	var fnt:=ThemeDB.fallback_font
	# Location hint (if near a zone)
	for loc in LOCATIONS:
		var dist=(_p_grid-loc.pos).length()
		if dist<2.5:
			draw_rect(Rect2(110,304,260,14),Color(0,0,0,0.65))
			draw_string(fnt,Vector2(118,315),
				"ENTER to enter "+loc.label,
				HORIZONTAL_ALIGNMENT_LEFT,-1,11,loc.color)
			break
	# Region name
	draw_rect(Rect2(440,4,38,14),Color(0,0,0,0.5))
	draw_string(fnt,Vector2(442,15),"Kalos",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.8,0.8,1.0))
