# WorldMap.gd v0.4 — Gen 2/3 quality Kanto-style region map
extends Node2D

signal enter_zone(zone_id:String)
signal show_dialog(lines:Array)

const TS:=16; const COLS:=30; const ROWS:=20
const T_OCEAN:=0;const T_GRASS:=1;const T_FOREST:=2;const T_MTNLO:=3
const T_MTNHI:=4;const T_PATH:=5;const T_SAND:=6;const T_TOWN:=7
const T_GYM:=8;const T_SILVER:=9;const T_WATER:=10;const T_BRIDGE:=11
const T_CAVE:=12;const T_SIGN:=13

# Gen 2/3 Palette
const OC1:=Color("#1838a0");const OC2:=Color("#2050b8");const OC3:=Color("#4878d0")
const OC_W:=Color("#90c8f8")
const GR1:=Color("#58a030");const GR2:=Color("#489028");const GR3:=Color("#386820")
const GR4:=Color("#78c048");const GRF:=Color("#f880a0")
const FR1:=Color("#185010");const FR2:=Color("#286818");const FR3:=Color("#40a028")
const MT1:=Color("#706858");const MT2:=Color("#888070");const MT3:=Color("#a09888")
const SN1:=Color("#d8e0f0");const SN2:=Color("#e8f0ff");const SN3:=Color("#ffffff")
const PT1:=Color("#d8c060");const PT2:=Color("#c8b050");const PT3:=Color("#b09838")
const SD1:=Color("#e8d878");const SD2:=Color("#d8c868")
const TW1:=Color("#e0d8b0");const RO1:=Color("#c03818");const WN:=Color("#88ccff")
const SL1:=Color("#404880");const SL2:=Color("#6070a8");const SL3:=Color("#9098d0")
const SL_PEAK:=Color("#c8d0f0")
const BR1:=Color("#c0902c");const BR2:=Color("#a07020")
const OL:=Color("#181010")
const WA1:=Color("#2848b0");const WA2:=Color("#3860c8");const WA3:=Color("#6090e0")
const CV1:=Color("#302838");const CV2:=Color("#484058")

const WMAP:=[
	[0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,4,4,4,4, 4,4,0,0,0,0,0,0,0,0],
	[0,0,0,0,2,2,2,1,1,1, 1,1,1,2,2,4,9,4,4,4, 4,4,4,2,2,0,0,0,0,0],
	[0,0,0,2,1,1,1,1,7,5, 5,5,1,1,2,4,4,4,3,3, 3,4,4,2,1,0,0,0,0,0],
	[0,0,2,1,1,1,5,5,5,1, 1,5,5,1,2,3,4,3,1,1, 1,3,4,1,1,2,0,0,0,0],
	[0,2,1,1,1,5,1,1,1,5,10,10,5,1,1,1,5,1,1,1, 1,1,5,1,1,1,2,0,0,0],
	[0,1,1,7,5,1,1,1,1,10,10,10,10,1,1,1,5,1,1,1,1,1,5,1,7,1,1,2,0,0],
	[0,1,5,5,5,1,1,2,11,11,11,11,11,2,1,1,5,1,1,2, 2,1,5,1,5,1,1,1,2,0],
	[0,1,1,8,1,1,2,1,1,1, 1,1,1,1,2,1,1,5,5,1, 1,5,5,1,8,1,1,1,1,0],
	[0,2,1,5,1,1,1,1,1,1, 1,1,1,1,1,1,5,1,1,1, 1,1,5,1,5,1,1,1,2,0],
	[0,1,1,5,1,1,1,1,1,6, 6,6,6,1,1,1,5,1,1,1, 1,1,5,1,1,1,1,2,1,0],
	[0,1,5,5,5,1,1,1,6,6, 7,6,6,6,1,1,1,5,5,1, 1,5,5,1,5,5,5,1,1,0],
	[0,1,1,8,1,1,2,1,6,6, 6,6,6,1,2,1,5,1,1,1, 1,1,1,1,8,1,1,1,2,0],
	[0,2,1,5,1,1,1,1,1,6, 6,6,6,1,1,5,1,1,2,1, 1,2,1,1,5,1,1,1,1,0],
	[0,1,1,5,1,1,1,2,1,1, 1,1,1,2,1,5,1,1,1,1, 1,1,1,5,5,1,2,1,1,0],
	[0,1,5,5,5,1,1,1,1,1, 1,1,1,1,1,1,5,5,5,1, 1,5,1,1,1,1,1,1,2,0],
	[0,1,1,7,5,1,1,1,1,1, 1,1,1,1,1,5,1,1,1,1, 1,1,5,7,5,1,1,2,1,0],
	[0,2,1,5,1,1,2,2,1,1, 1,1,1,2,2,1,1,1,1,1, 1,5,1,5,1,1,1,1,2,0],
	[0,0,2,5,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,2,2, 2,1,1,5,1,1,2,0,0,0],
	[0,0,0,2,2,1,1,1,1,1, 1,1,1,1,1,1,1,2,0,0, 0,2,2,1,1,2,0,0,0,0],
	[0,0,0,0,0,2,2,2,2,2, 2,2,2,2,2,2,2,0,0,0, 0,0,0,2,2,0,0,0,0,0],
]

const LOCATIONS:=[
	{"id":"math",    "pos":Vector2i(8,2), "label":"Mathopolis",  "type":"zone","color":Color("#44aaff")},
	{"id":"english", "pos":Vector2i(10,10),"label":"Lexicon City","type":"zone","color":Color("#ffcc44")},
	{"id":"music",   "pos":Vector2i(24,5),"label":"Harmonia",    "type":"zone","color":Color("#cc44ff")},
	{"id":"silver",  "pos":Vector2i(16,1),"label":"Silver Mtn",  "type":"silver","color":Color("#c0c8ff")},
	{"id":"cross",   "pos":Vector2i(3,5), "label":"Crossroads",  "type":"rest","color":Color("#aaffaa")},
	{"id":"east",    "pos":Vector2i(23,15),"label":"Eastholm",   "type":"rest","color":Color("#aaffaa")},
	{"id":"west",    "pos":Vector2i(3,15),"label":"Westfield",   "type":"rest","color":Color("#aaffaa")},
]

var _p_grid:Vector2i=Vector2i(8,5)
var _p_pixel:Vector2=Vector2(128,80)
var _p_dir:int=0; var _moving:bool=false; var _dialog_open:bool=false
var _tween:Tween=null; var _time:float=0.0; var _anim_t:float=0.0; var _frame:int=0
var _cam:Vector2=Vector2.ZERO

func _ready()->void:
	add_to_group("overworld")
	_p_grid=Vector2i(8,5); _p_pixel=Vector2(8*TS,5*TS)
	_update_cam(); set_process(true); set_process_input(true)

func set_dialog_open(v:bool)->void: _dialog_open=v

func _input(event:InputEvent)->void:
	if _dialog_open or _moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);_p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1);_p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0);_p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);_p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	if dir!=Vector2i.ZERO: _try_move(_p_grid+dir)

func _try_move(dest:Vector2i)->void:
	var t:=_tile_at(dest)
	if t in [T_OCEAN,T_MTNHI,T_FOREST,T_WATER]: return
	_do_move(dest)

func _do_move(dest:Vector2i)->void:
	_p_grid=dest; _moving=true
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tween: _tween.kill()
	_tween=create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;_update_cam();queue_redraw(),_p_pixel,tgt,0.14)
	_tween.tween_callback(func():_moving=false;_check_loc())

func _check_loc()->void:
	for loc in LOCATIONS:
		if loc.pos==_p_grid:
			if loc.type in ["zone","silver"]: _enter_loc(loc); return

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	for loc in LOCATIONS:
		if loc.pos==front: _prompt(loc); return

func _prompt(loc:Dictionary)->void:
	match loc.type:
		"zone": enter_zone.emit(loc.id)
		"silver":
			if not GameManager.can_challenge_silver():
				show_dialog.emit(["Silver Mountain...\nA powerful force repels you.","You need Level 100 and\nall 20 badges to enter!"])
			else: enter_zone.emit("silver")
		"rest":
			show_dialog.emit(["Welcome to "+loc.label+"!","Rest here before your\njourney continues."])

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
		_:
			return Vector2i.ZERO

func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.25: _anim_t=0.0; _frame=1-_frame
	queue_redraw()

# ═══════════════════ DRAWING ══════════════════════════════════════════════════
func _draw()->void:
	var ox:=int(_cam.x); var oy:=int(_cam.y)
	_draw_tiles(ox,oy); _draw_locations(ox,oy); _draw_player(ox,oy)
	_draw_minimap(); _draw_ui()

func _draw_tiles(ox:int,oy:int)->void:
	var c0=int(ox/TS); var c1=min(c0+32,COLS)
	var r0=int(oy/TS); var r1=min(r0+22,ROWS)
	for r in range(r0,r1):
		for c in range(c0,c1):
			_wt(WMAP[r][c],c*TS-ox,r*TS-oy,c,r)

func _wt(t:int,px:int,py:int,c:int,r:int)->void:
	var chk:=(c+r)%2==0
	match t:
		T_OCEAN:  _wt_ocean(px,py,c,r)
		T_GRASS:  _wt_grass(px,py,c,r,chk)
		T_FOREST: _wt_forest(px,py,c,r)
		T_MTNLO:  _wt_mtnlo(px,py,chk)
		T_MTNHI:  _wt_mtnhi(px,py)
		T_PATH:   _wt_path(px,py,c,r,chk)
		T_SAND:   _wt_sand(px,py,chk)
		T_TOWN:   _wt_town(px,py,chk)
		T_GYM:    _wt_gym(px,py)
		T_SILVER: _wt_silver(px,py)
		T_WATER:  _wt_water(px,py,c,r)
		T_BRIDGE: _wt_bridge(px,py,r)
		T_CAVE:   _wt_cave(px,py)
		T_SIGN:   _wt_sign(px,py,chk)
		_:        _wt_grass(px,py,c,r,chk)

func _wt_ocean(px:int,py:int,c:int,r:int)->void:
	var wv:=0.4+0.6*sin(_time*1.2+(c+r)*0.4)
	draw_rect(Rect2(px,py,TS,TS),OC1)
	draw_rect(Rect2(px+1,py+2,TS-2,2),OC2)
	draw_rect(Rect2(px+1,py+8,TS-2,2),OC2*Color(1,1,1,wv))
	draw_rect(Rect2(px+1,py+13,TS-2,1),OC3*Color(1,1,1,wv*0.5))

func _wt_grass(px:int,py:int,c:int,r:int,chk:bool)->void:
	draw_rect(Rect2(px,py,TS,TS),GR1)
	# Gen 2 checker
	for dy in range(0,TS,4):
		for dx in range(0,TS,4):
			if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),GR2)
	# Blade detail
	if (c*7+r*11)%6==0:
		draw_rect(Rect2(px+3,py+10,1,4),GR4); draw_rect(Rect2(px+10,py+9,1,5),GR4)
	# Tiny flower
	if (c*11+r*7)%9==0: draw_rect(Rect2(px+6,py+7,2,2),GRF)

func _wt_forest(px:int,py:int,c:int,r:int)->void:
	draw_rect(Rect2(px,py,TS,TS),FR1)
	# Mini round tree
	draw_rect(Rect2(px+1,py+5,14,9),FR2); draw_rect(Rect2(px+3,py+3,10,9),FR3)
	draw_rect(Rect2(px+5,py+2,6,6),FR3.lightened(0.15)); draw_rect(Rect2(px+6,py+2,4,3),Color(1,1,1,0.12))
	draw_rect(Rect2(px+6,py+11,4,5),Color("#6a4010")); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_mtnlo(px:int,py:int,chk:bool)->void:
	draw_rect(Rect2(px,py,TS,TS),MT1 if chk else MT2)
	# Rock face detail
	draw_rect(Rect2(px+2,py+3,5,4),MT3); draw_rect(Rect2(px+2,py+4,4,2),Color(1,1,1,0.12))
	draw_rect(Rect2(px+9,py+9,5,4),MT3); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_mtnhi(px:int,py:int)->void:
	draw_rect(Rect2(px,py,TS,TS),MT1)
	# Snow cap
	draw_rect(Rect2(px+3,py+0,10,6),SN1); draw_rect(Rect2(px+4,py+0,8,4),SN2)
	draw_rect(Rect2(px+6,py+0,4,2),SN3); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_path(px:int,py:int,c:int,r:int,chk:bool)->void:
	draw_rect(Rect2(px,py,TS,TS),PT1)
	for dy in range(0,TS,4):
		for dx in range(0,TS,4):
			if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),PT2)
	draw_rect(Rect2(px,py,TS,1),PT3); draw_rect(Rect2(px,py,1,TS),PT3)

func _wt_sand(px:int,py:int,chk:bool)->void:
	draw_rect(Rect2(px,py,TS,TS),SD1 if chk else SD2)

func _wt_town(px:int,py:int,chk:bool)->void:
	# Mini house on sandy base
	draw_rect(Rect2(px,py,TS,TS),SD1 if chk else SD2)
	draw_rect(Rect2(px+1,py+5,12,9),TW1); draw_rect(Rect2(px+1,py+2,12,5),RO1)
	draw_rect(Rect2(px+4,py+7,4,7),WN); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_gym(px:int,py:int)->void:
	# Mini gym (blue octagonal hint)
	draw_rect(Rect2(px,py,TS,TS),Color("#304890"))
	draw_rect(Rect2(px+2,py+2,12,12),Color("#3858a8")); draw_rect(Rect2(px+3,py+1,10,2),Color("#4878c8"))
	draw_rect(Rect2(px+2,py+6,12,3),Color("#6090e0",0.5)); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_silver(px:int,py:int)->void:
	var sg:=0.55+0.45*sin(_time*2.2)
	draw_rect(Rect2(px,py,TS,TS),SL1)
	# Peak shape
	draw_rect(Rect2(px+2,py+6,12,10),SL2)
	draw_colored_polygon(
	PackedVector2Array([
		Vector2(px, py+6),
		Vector2(px+8, py+0),
		Vector2(px+16, py+6)
	]),
	SL2
)
	draw_rect(Rect2(px+4,py+2,8,4),SL3); draw_rect(Rect2(px+6,py+1,4,2),SL_PEAK)
	draw_rect(Rect2(px+5,py+0,6,3),Color(1,1,1,sg))
	draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_water(px:int,py:int,c:int,r:int)->void:
	var wt:=0.45+0.55*sin(_time*1.6+(c+r)*0.5)
	draw_rect(Rect2(px,py,TS,TS),WA1)
	draw_rect(Rect2(px+1,py+3,TS-2,2),WA2); draw_rect(Rect2(px+1,py+9,TS-2,2),WA2*Color(1,1,1,wt))
	draw_rect(Rect2(px+3,py+6,TS-6,1),WA3*Color(1,1,1,wt*0.5))

func _wt_bridge(px:int,py:int,r:int)->void:
	# horizontal bridge if in middle rows
	draw_rect(Rect2(px,py,TS,TS),BR1)
	draw_rect(Rect2(px+1,py,3,TS),BR2); draw_rect(Rect2(px+12,py,3,TS),BR2)
	draw_rect(Rect2(px,py+6,TS,4),BR2.lightened(0.1)); draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_cave(px:int,py:int)->void:
	draw_rect(Rect2(px,py,TS,TS),CV1)
	draw_rect(Rect2(px+2,py+3,12,9),Color("#0a0810")); draw_rect(Rect2(px+3,py+2,10,2),CV2)
	draw_rect(Rect2(px,py,TS,TS),OL,false,1.0)

func _wt_sign(px:int,py:int,chk:bool)->void:
	_wt_grass(px,py,0,0,chk)
	draw_rect(Rect2(px+6,py+7,4,9),BR2); draw_rect(Rect2(px+2,py+4,12,5),SD1)
	draw_rect(Rect2(px+2,py+4,12,5),OL,false,1.0)

# ── Locations on map ──────────────────────────────────────────────────────────
func _draw_locations(ox:int,oy:int)->void:
	var fnt:=ThemeDB.fallback_font
	for loc in LOCATIONS:
		var sx=loc.pos.x*TS-ox; var sy=loc.pos.y*TS-oy
		if sx<-80 or sx>500 or sy<-20 or sy>340: continue
		var pulse:=0.55+0.45*sin(_time*2.5+loc.pos.x)
		# Label background + text
		var lw:=len(loc.label)*6+8
		draw_rect(Rect2(sx-1,sy-14,lw,12),OL)
		draw_rect(Rect2(sx,sy-13,lw-2,10),Color(0,0,0,0.7))
		draw_string(fnt,Vector2(sx+3,sy-4),loc.label,HORIZONTAL_ALIGNMENT_LEFT,-1,9,loc.color*Color(1,1,1,pulse))
		if loc.type in ["zone","silver"]:
			draw_rect(Rect2(sx-2,sy-2,TS+4,TS+4),loc.color*Color(1,1,1,0.25+pulse*0.2),false,1.5)

# ── Player (mini Gen 2 sprite) ────────────────────────────────────────────────
func _draw_player(ox:int,oy:int)->void:
	var px:=int(_p_pixel.x)-ox; var py:=int(_p_pixel.y)-oy
	var bob:=0 if _frame==0 else -1
	var dark:=OL; var skin:=Color("#f8d8a8")
	# Shadow
	draw_rect(Rect2(px+1,py+12,14,3),Color(0,0,0,0.2))
	# Legs
	draw_rect(Rect2(px+2,py+8+bob,4,6),Color("#1838a0"))
	draw_rect(Rect2(px+10,py+8-bob,4,6),Color("#1838a0"))
	# Body (red shirt)
	draw_rect(Rect2(px+1,py+3,14,7),Color("#c01010"))
	draw_rect(Rect2(px+1,py+3,14,2),Color("#e01818"))
	draw_rect(Rect2(px+1,py+3,14,7),dark,false,1.0)
	# Head
	draw_rect(Rect2(px+4,py+0,8,5),skin); draw_rect(Rect2(px+4,py+0,8,5),dark,false,1.0)
	# Cap
	draw_rect(Rect2(px+3,py+0,10,3),Color("#c01010"))
	draw_rect(Rect2(px+2,py+2,12,2),Color("#c01010"))
	draw_rect(Rect2(px+3,py+0,10,3),dark,false,1.0)
	# Eyes (front facing)
	if _p_dir==0:
		draw_rect(Rect2(px+5,py+3,2,2),dark); draw_rect(Rect2(px+9,py+3,2,2),dark)

# ── Minimap ───────────────────────────────────────────────────────────────────
func _draw_minimap()->void:
	const MX:=4;const MY:=4;const MS:=2
	var mw:=COLS*MS; var mh:=ROWS*MS
	draw_rect(Rect2(MX-2,MY-2,mw+4,mh+4),OL)
	draw_rect(Rect2(MX-1,MY-1,mw+2,mh+2),Color(0,0,0,0.7))
	for r in ROWS:
		for c in COLS:
			var mc:Color
			match WMAP[r][c]:
				T_OCEAN:  mc=OC1
				T_GRASS:  mc=GR1
				T_FOREST: mc=FR1
				T_MTNLO:  mc=MT1
				T_MTNHI:  mc=SN1
				T_PATH:   mc=PT1
				T_SAND,T_TOWN: mc=SD1
				T_GYM:    mc=Color("#3060c0")
				T_SILVER: mc=SL3
				T_WATER:  mc=WA2
				_:        mc=GR2
			draw_rect(Rect2(MX+c*MS,MY+r*MS,MS,MS),mc)
	# Player dot
	draw_rect(Rect2(MX+_p_grid.x*MS-1,MY+_p_grid.y*MS-1,4,4),Color("#ffffff"))
	draw_rect(Rect2(MX+_p_grid.x*MS-1,MY+_p_grid.y*MS-1,4,4),OL,false,1.0)

# ── UI ────────────────────────────────────────────────────────────────────────
func _draw_ui()->void:
	var fnt:=ThemeDB.fallback_font
	# Zone proximity hint
	for loc in LOCATIONS:
		var dist=(_p_grid-loc.pos).length()
		if dist<2.5:
			draw_rect(Rect2(100,303,280,15),OL)
			draw_rect(Rect2(101,304,278,13),Color(0,0,0,0.72))
			draw_string(fnt,Vector2(110,315),"ENTER — enter "+loc.label,
				HORIZONTAL_ALIGNMENT_LEFT,-1,11,loc.color)
			break
	# Region label
	draw_rect(Rect2(434,3,44,14),OL)
	draw_rect(Rect2(435,4,42,12),Color(0,0,0,0.65))
	draw_string(fnt,Vector2(437,14),"Kalos",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.8,0.8,1.0))
