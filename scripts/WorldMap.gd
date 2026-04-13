# WorldMap.gd v0.5 — 2.5D isometric-lite region map
extends Node2D

signal enter_zone(zone_id:String)
signal show_dialog(lines:Array)

const TS:=16; const COLS:=30; const ROWS:=20
const T_OCEAN:=0;const T_GRASS:=1;const T_FOREST:=2;const T_MTNLO:=3
const T_MTNHI:=4;const T_PATH:=5;const T_SAND:=6;const T_TOWN:=7
const T_GYM:=8;const T_SILVER:=9;const T_WATER:=10;const T_BRIDGE:=11
const T_CAVE:=12;const T_SIGN:=13

# 2.5D: raised tile height (front face shown below tile)
const RAISED_H:=8

const WMAP:=[
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0,0,0,0],
	[0,0,0,0,2,2,2,1,1,1,1,1,1,2,2,4,9,4,4,4,4,4,4,2,2,0,0,0,0,0],
	[0,0,0,2,1,1,1,1,7,5,5,5,1,1,2,4,4,4,3,3,3,4,4,2,1,0,0,0,0,0],
	[0,0,2,1,1,1,5,5,5,1,1,5,5,1,2,3,4,3,1,1,1,3,4,1,1,2,0,0,0,0],
	[0,2,1,1,1,5,1,1,1,5,10,10,5,1,1,1,5,1,1,1,1,1,5,1,1,1,2,0,0,0],
	[0,1,1,7,5,1,1,1,1,10,10,10,10,1,1,1,5,1,1,1,1,1,5,1,7,1,1,2,0,0],
	[0,1,5,5,5,1,1,2,11,11,11,11,11,2,1,1,5,1,1,2,2,1,5,1,5,1,1,1,2,0],
	[0,1,1,8,1,1,2,1,1,1,1,1,1,1,2,1,1,5,5,1,1,5,5,1,8,1,1,1,1,0],
	[0,2,1,5,1,1,1,1,1,1,1,1,1,1,1,1,5,1,1,1,1,1,5,1,5,1,1,1,2,0],
	[0,1,1,5,1,1,1,1,1,6,6,6,6,1,1,1,5,1,1,1,1,1,5,1,1,1,1,2,1,0],
	[0,1,5,5,5,1,1,1,6,6,7,6,6,6,1,1,1,5,5,1,1,5,5,1,5,5,5,1,1,0],
	[0,1,1,8,1,1,2,1,6,6,6,6,6,1,2,1,5,1,1,1,1,1,1,1,8,1,1,1,2,0],
	[0,2,1,5,1,1,1,1,1,6,6,6,6,1,1,5,1,1,2,1,1,2,1,1,5,1,1,1,1,0],
	[0,1,1,5,1,1,1,2,1,1,1,1,1,2,1,5,1,1,1,1,1,1,1,5,5,1,2,1,1,0],
	[0,1,5,5,5,1,1,1,1,1,1,1,1,1,1,1,5,5,5,1,1,5,1,1,1,1,1,1,2,0],
	[0,1,1,7,5,1,1,1,1,1,1,1,1,1,1,5,1,1,1,1,1,1,5,7,5,1,1,2,1,0],
	[0,2,1,5,1,1,2,2,1,1,1,1,1,2,2,1,1,1,1,1,1,5,1,5,1,1,1,1,2,0],
	[0,0,2,5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,1,1,5,1,1,2,0,0,0],
	[0,0,0,2,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,2,2,1,1,2,0,0,0,0],
	[0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,2,2,0,0,0,0,0],
]
const LOCS:=[
	{"id":"math",   "pos":Vector2i(8,2),"label":"Mathopolis",  "type":"zone","color":Color("#2060d0")},
	{"id":"english","pos":Vector2i(10,10),"label":"Lexicon City","type":"zone","color":Color("#c07010")},
	{"id":"music",  "pos":Vector2i(24,5),"label":"Harmonia",   "type":"zone","color":Color("#8020c0")},
	{"id":"silver", "pos":Vector2i(16,1),"label":"Silver Mtn", "type":"silver","color":Color("#8090c0")},
	{"id":"cross",  "pos":Vector2i(3,5),"label":"Crossroads",  "type":"rest","color":Color("#409040")},
	{"id":"east",   "pos":Vector2i(23,15),"label":"Eastholm",  "type":"rest","color":Color("#409040")},
]

var _p_grid:Vector2i=Vector2i(8,5); var _p_pixel:Vector2=Vector2(128,80)
var _p_dir:int=0; var _moving:bool=false; var _dialog_open:bool=false
var _tween:Tween=null; var _time:float=0.0; var _frame:int=0; var _anim_t:float=0.0
var _cam:Vector2=Vector2.ZERO

func _ready()->void:
	add_to_group("overworld"); _update_cam()
	set_process(true); set_process_input(true)

func set_dialog_open(v:bool)->void: _dialog_open=v

func _input(event:InputEvent)->void:
	if _dialog_open or _moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);_p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1);_p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0);_p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);_p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	if dir!=Vector2i.ZERO:
		var dest:=_p_grid+dir; var t:=_tile_at(dest)
		if t not in [T_OCEAN,T_WATER]:
			_do_move(dest)

func _do_move(dest:Vector2i)->void:
	_p_grid=dest; _moving=true
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tween: _tween.kill()
	_tween=create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;_update_cam();queue_redraw(),_p_pixel,tgt,0.14)
	_tween.tween_callback(func():_moving=false; _check_loc())

func _check_loc()->void:
	for loc in LOCS:
		if loc.pos==_p_grid and loc.type in ["zone","silver"]:
			_enter_loc(loc); return

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	for loc in LOCS:
		if loc.pos==front: _prompt(loc); return

func _prompt(loc:Dictionary)->void:
	match loc.type:
		"zone": enter_zone.emit(loc.id)
		"silver":
			if not GameManager.can_challenge_silver():
				show_dialog.emit(["Silver Mountain...\nA mighty force blocks your path.","Need Level 100 and all 20 badges."])
			else: enter_zone.emit("silver")
		"rest":
			# Rest towns heal the player!
			GameManager.heal_hp()
			show_dialog.emit(["Welcome to "+loc.label+"!","You rest and recover fully.\nHP restored!"])

func _enter_loc(loc:Dictionary)->void: _prompt(loc)
func _update_cam()->void:
	const VW:=480;const VH:=320;const MW:=COLS*TS;const MH:=ROWS*TS
	_cam.x=clamp(_p_pixel.x-VW/2.0+TS/2.0,0,MW-VW)
	_cam.y=clamp(_p_pixel.y-VH/2.0+TS/2.0,0,MH-VH)
func _tile_at(p:Vector2i)->int:
	if p.y<0 or p.y>=ROWS or p.x<0 or p.x>=COLS: return T_OCEAN
	return WMAP[p.y][p.x]
func _dv(d:int)->Vector2i:
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

func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.25: _anim_t=0.0; _frame=1-_frame
	queue_redraw()

# ═════════════════ 2.5D WORLD MAP DRAWING ═════════════════════════════════════
func _draw()->void:
	var ox:=int(_cam.x); var oy:=int(_cam.y)
	# Draw ground layer first, then raised objects back-to-front
	var c0=int(ox/TS); var c1=min(c0+32,COLS)
	var r0=int(oy/TS); var r1=min(r0+22,ROWS)
	for r in range(r0,r1):
		for c in range(c0,c1):
			_draw_ground(WMAP[r][c],c*TS-ox,r*TS-oy,c,r)
	# Raised objects + player (back to front for depth)
	for r in range(r0,r1):
		for c in range(c0,c1):
			if WMAP[r][c] in [T_FOREST,T_TOWN,T_GYM,T_SILVER]:
				_draw_raised(WMAP[r][c],c*TS-ox,r*TS-oy)
		if _p_grid.y==r: _draw_player_sprite(_p_pixel.x-ox,_p_pixel.y-oy)
	_draw_loc_labels(ox,oy); _draw_minimap(); _draw_ui()

func _draw_ground(t:int,px:int,py:int,c:int,r:int)->void:
	var chk:=(c+r)%2==0
	match t:
		T_OCEAN:
			var wv:=0.4+0.6*sin(_time*1.2+(c+r)*0.4)
			draw_rect(Rect2(px,py,TS,TS),Color("#1838a0"))
			draw_rect(Rect2(px+1,py+2,TS-2,2),Color("#2858c0")*Color(1,1,1,wv))
			draw_rect(Rect2(px+1,py+8,TS-2,2),Color("#3868d0")*Color(1,1,1,wv*0.6))
		T_GRASS,T_FOREST,T_TOWN,T_GYM,T_SILVER:
			draw_rect(Rect2(px,py,TS,TS),Color("#58a030") if chk else Color("#489028"))
			if (c*7+r*11)%8==0: draw_rect(Rect2(px+3,py+9,1,4),Color("#78c048"))
		T_MTNLO:
			draw_rect(Rect2(px,py,TS,TS),Color("#706858") if chk else Color("#806868"))
			draw_rect(Rect2(px+2,py+3,5,4),Color("#908080")); draw_rect(Rect2(px+2,py+4,4,2),Color(1,1,1,0.12))
		T_MTNHI:
			draw_rect(Rect2(px,py,TS,TS),Color("#555060"))
			draw_rect(Rect2(px+3,py+0,10,5),Color("#d8e0f0")); draw_rect(Rect2(px+5,py+0,6,3),Color("#ffffff"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_PATH:
			draw_rect(Rect2(px,py,TS,TS),Color("#d8c060") if chk else Color("#c8b050"))
			draw_rect(Rect2(px,py+TS-1,TS,1),Color("#506020",0.3))
		T_SAND:
			draw_rect(Rect2(px,py,TS,TS),Color("#e8d878") if chk else Color("#d8c868"))
		T_WATER:
			var wt:=0.45+0.55*sin(_time*1.6+(c+r)*0.5)
			draw_rect(Rect2(px,py,TS,TS),Color("#2848b0"))
			draw_rect(Rect2(px+1,py+3,TS-2,2),Color("#4868c8")*Color(1,1,1,wt))
			draw_rect(Rect2(px+1,py+9,TS-2,2),Color("#6080e0")*Color(1,1,1,wt*0.5))
		T_BRIDGE:
			draw_rect(Rect2(px,py,TS,TS),Color("#c09030"))
			draw_rect(Rect2(px+1,py,3,TS),Color("#a07020")); draw_rect(Rect2(px+12,py,3,TS),Color("#a07020"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_CAVE:
			draw_rect(Rect2(px,py,TS,TS),Color("#302838"))
			draw_rect(Rect2(px+2,py+3,12,9),Color("#080810")); draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		_:
			draw_rect(Rect2(px,py,TS,TS),Color("#489028") if chk else Color("#388020"))

func _draw_raised(t:int,px:int,py:int)->void:
	var dk:=Color("#181010")
	match t:
		T_FOREST:
			# 2.5D mini tree
			draw_rect(Rect2(px+2,py+py,0,0),Color("#181010")) # no-op placeholder
			draw_rect(Rect2(px+5,py+9,6,7),Color("#6a4010"))
			draw_rect(Rect2(px+1,py+11,14,7),Color("#1a4810"))
			draw_rect(Rect2(px+3,py+6,10,8),Color("#286018"))
			draw_rect(Rect2(px+5,py+3,6,6),Color("#40a028"))
			draw_rect(Rect2(px+6,py+2,4,3),Color("#58b840"))
			draw_rect(Rect2(px+7,py+1,2,2),Color(1,1,1,0.2))
			draw_rect(Rect2(px+1,py+6,14,12),dk,false,1.0)
		T_TOWN:
			# Mini house with 2.5D front face
			draw_rect(Rect2(px+1,py+4,14,10),Color("#e8d8b0"))
			draw_rect(Rect2(px+1,py+1,14,5),Color("#c03018"))
			draw_rect(Rect2(px+1,py+11,14,5),Color("#d0c8a0"))  # front face
			draw_rect(Rect2(px+4,py+6,4,5),Color("#88ccff"))
			draw_rect(Rect2(px+4,py+6,4,5),dk,false,1.0)
			draw_rect(Rect2(px+1,py+1,14,15),dk,false,1.0)
		T_GYM:
			# Mini gym pillar with glow
			var glow:=0.4+0.4*sin(_time*2.5)
			draw_rect(Rect2(px+2,py+2,12,12),Color("#203080"))
			draw_rect(Rect2(px+2,py+12,12,4),Color("#102060"))  # front face
			draw_rect(Rect2(px+4,py+10,8,2),Color("#4080ff",glow))
			draw_rect(Rect2(px+2,py+2,12,16),dk,false,1.0)
		T_SILVER:
			var sg:=0.5+0.5*sin(_time*2.0)
			draw_rect(Rect2(px+2,py+8,12,8),Color("#6070a8"))
			draw_polygon(
	PackedVector2Array([Vector2(px,py+8), Vector2(px+8,py+0), Vector2(px+16,py+8)]),
	PackedColorArray([Color("#8090c8"), Color("#8090c8"), Color("#8090c8")])
)
			draw_rect(Rect2(px+5,py+2,6,3),Color("#b0c0e8"))
			draw_rect(Rect2(px+6,py+1,4,2),Color(1,1,1,sg))
			draw_rect(Rect2(px,py,TS,TS+RAISED_H),dk,false,1.0)

func _draw_loc_labels(ox:int,oy:int)->void:
	var fnt:=ThemeDB.fallback_font; var dk:=Color("#181010")
	for loc in LOCS:
		var sx=loc.pos.x*TS-ox; var sy=loc.pos.y*TS-oy
		if sx<-80 or sx>500 or sy<-20 or sy>340: continue
		var pulse:=0.55+0.45*sin(_time*2.5+loc.pos.x)
		var lw:=len(loc.label)*6+8
		draw_rect(Rect2(sx-1,sy-13,lw,11),dk)
		draw_rect(Rect2(sx,sy-12,lw-2,9),Color("#f0f0e0"))
		draw_string(fnt,Vector2(sx+3,sy-4),loc.label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,loc.color*Color(1,1,1,pulse))
		if loc.type in ["zone","silver"]:
			draw_rect(Rect2(sx-1,sy-1,TS+2,TS+2),loc.color*Color(1,1,1,0.2+pulse*0.15),false,1.5)

func _draw_player_sprite(px:float,py:float)->void:
	var dk:=Color("#181010"); var skin:=Color("#f0c890")
	var bob:=0 if _frame==0 else -1
	draw_rect(Rect2(px+1,py+12,14,3),Color(0,0,0,0.2))
	draw_rect(Rect2(px+2,py+7+bob,5,6),Color("#181888")); draw_rect(Rect2(px+9,py+7-bob,5,6),Color("#181888"))
	draw_rect(Rect2(px+1,py+3,14,6),Color("#c01010")); draw_rect(Rect2(px+1,py+3,14,2),Color("#e01818"))
	draw_rect(Rect2(px+1,py+3,14,6),dk,false,1.0)
	draw_rect(Rect2(px+4,py+0,8,5),skin); draw_rect(Rect2(px+4,py+0,8,5),dk,false,1.0)
	draw_rect(Rect2(px+3,py+0,10,3),Color("#c01010")); draw_rect(Rect2(px+2,py+2,12,2),Color("#c01010"))
	draw_rect(Rect2(px+3,py+0,10,3),dk,false,1.0)
	if _p_dir==0:
		draw_rect(Rect2(px+5,py+3,2,2),dk); draw_rect(Rect2(px+9,py+3,2,2),dk)

func _draw_minimap()->void:
	const MX:=4;const MY:=4;const MS:=2
	draw_rect(Rect2(MX-2,MY-2,COLS*MS+4,ROWS*MS+4),Color("#181010"))
	draw_rect(Rect2(MX-1,MY-1,COLS*MS+2,ROWS*MS+2),Color("#101010"))
	for r in ROWS:
		for c in COLS:
			var mc:Color
			match WMAP[r][c]:
				T_OCEAN: mc=Color("#1838a0")
				T_GRASS,T_FOREST: mc=Color("#489028")
				T_MTNLO: mc=Color("#706858")
				T_MTNHI: mc=Color("#d0d8e8")
				T_PATH: mc=Color("#d8c060")
				T_SAND,T_TOWN: mc=Color("#e8d878")
				T_GYM: mc=Color("#2040a0")
				T_SILVER: mc=Color("#8090c8")
				T_WATER: mc=Color("#2848b0")
				_: mc=Color("#409020")
			draw_rect(Rect2(MX+c*MS,MY+r*MS,MS,MS),mc)
	draw_rect(Rect2(MX+_p_grid.x*MS-1,MY+_p_grid.y*MS-1,4,4),Color("#ffffff"))
	draw_rect(Rect2(MX+_p_grid.x*MS-1,MY+_p_grid.y*MS-1,4,4),Color("#181010"),false,1.0)

func _draw_ui()->void:
	var fnt:=ThemeDB.fallback_font; var dk:=Color("#181010")
	for loc in LOCS:
		if (_p_grid-loc.pos).length()<2.5:
			draw_rect(Rect2(100,302,280,16),dk)
			draw_rect(Rect2(101,303,278,14),Color("#f0f0e0"))
			draw_string(fnt,Vector2(110,314),"ENTER — enter "+loc.label,
				HORIZONTAL_ALIGNMENT_LEFT,-1,10,loc.color)
			break
	draw_rect(Rect2(434,3,44,13),dk)
	draw_rect(Rect2(435,4,42,11),Color("#f0f0e0"))
	draw_string(fnt,Vector2(437,13),"Kalos",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.3,0.3,0.6))
