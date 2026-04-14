# WorldMap.gd — Kanto-style scrolling region map
extends Node2D
signal enter_zone(zone_id:String)
signal show_dialog(lines:Array)

const TS:=16;const COLS:=30;const ROWS:=20
const T_OCEAN:=0;const T_GRASS:=1;const T_FOREST:=2;const T_MTN:=3;const T_PEAK:=4
const T_PATH:=5;const T_SAND:=6;const T_TOWN:=7;const T_GYM:=8;const T_SILVER:=9
const T_WATER:=10;const T_BRIDGE:=11

const WMAP:=[[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0,0,0,0],[0,0,0,0,2,2,2,1,1,1,1,1,1,2,2,4,9,4,4,4,4,4,4,2,2,0,0,0,0,0],[0,0,0,2,1,1,1,1,7,5,5,5,1,1,2,4,4,4,3,3,3,4,4,2,1,0,0,0,0,0],[0,0,2,1,1,1,5,5,5,1,1,5,5,1,2,3,4,3,1,1,1,3,4,1,1,2,0,0,0,0],[0,2,1,1,1,5,1,1,1,5,10,10,5,1,1,1,5,1,1,1,1,1,5,1,1,1,2,0,0,0],[0,1,1,7,5,1,1,1,1,10,10,10,10,1,1,1,5,1,1,1,1,1,5,1,7,1,1,2,0,0],[0,1,5,5,5,1,1,2,11,11,11,11,11,2,1,1,5,1,1,2,2,1,5,1,5,1,1,1,2,0],[0,1,1,8,1,1,2,1,1,1,1,1,1,1,2,1,1,5,5,1,1,5,5,1,8,1,1,1,1,0],[0,2,1,5,1,1,1,1,1,1,1,1,1,1,1,1,5,1,1,1,1,1,5,1,5,1,1,1,2,0],[0,1,1,5,1,1,1,1,1,6,6,6,6,1,1,1,5,1,1,1,1,1,5,1,1,1,1,2,1,0],[0,1,5,5,5,1,1,1,6,6,7,6,6,6,1,1,1,5,5,1,1,5,5,1,5,5,5,1,1,0],[0,1,1,8,1,1,2,1,6,6,6,6,6,1,2,1,5,1,1,1,1,1,1,1,8,1,1,1,2,0],[0,2,1,5,1,1,1,1,1,6,6,6,6,1,1,5,1,1,2,1,1,2,1,1,5,1,1,1,1,0],[0,1,1,5,1,1,1,2,1,1,1,1,1,2,1,5,1,1,1,1,1,1,1,5,5,1,2,1,1,0],[0,1,5,5,5,1,1,1,1,1,1,1,1,1,1,1,5,5,5,1,1,5,1,1,1,1,1,1,2,0],[0,1,1,7,5,1,1,1,1,1,1,1,1,1,1,5,1,1,1,1,1,1,5,7,5,1,1,2,1,0],[0,2,1,5,1,1,2,2,1,1,1,1,1,2,2,1,1,1,1,1,1,5,1,5,1,1,1,1,2,0],[0,0,2,5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,1,1,5,1,1,2,0,0,0],[0,0,0,2,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0,0,0,2,2,1,1,2,0,0,0,0],[0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,2,2,0,0,0,0,0]]
const LOCS:=[{"id":"math","pos":Vector2i(8,2),"label":"Mathopolis","type":"zone","color":Color("#2060d0")},{"id":"english","pos":Vector2i(10,10),"label":"Lexicon City","type":"zone","color":Color("#c07010")},{"id":"music","pos":Vector2i(24,5),"label":"Harmonia","type":"zone","color":Color("#8020c0")},{"id":"silver","pos":Vector2i(16,1),"label":"Silver Mtn","type":"silver","color":Color("#8090c0")},{"id":"cross","pos":Vector2i(3,5),"label":"Crossroads","type":"rest","color":Color("#409040")},{"id":"east","pos":Vector2i(23,15),"label":"Eastholm","type":"rest","color":Color("#409040")}]

var _p:Vector2i=Vector2i(8,5); var _px:Vector2=Vector2(128,80)
var _dir:int=0; var _mov:bool=false; var _dlg:bool=false
var _tw:Tween=null; var _t:float=0.0; var _ft:int=0; var _at:float=0.0
var _cam:Vector2=Vector2.ZERO
var _hold_t:float=0.0; var _step_t:float=0.0; var _last_d:Vector2i=Vector2i.ZERO

func _ready()->void: add_to_group("overworld"); _upd_cam(); set_process(true); set_process_input(true)
func set_dialog_open(v:bool)->void: _dlg=v

func _physics_process(delta:float)->void:
	if _dlg or _mov: _hold_t=0.0; _step_t=0.0; _last_d=Vector2i.ZERO; return
	var d:=Vector2i.ZERO
	if   Input.is_action_pressed("ui_down"):  d=Vector2i(0,1);_dir=0
	elif Input.is_action_pressed("ui_up"):    d=Vector2i(0,-1);_dir=1
	elif Input.is_action_pressed("ui_left"):  d=Vector2i(-1,0);_dir=2
	elif Input.is_action_pressed("ui_right"): d=Vector2i(1,0);_dir=3
	if d==Vector2i.ZERO: _hold_t=0.0; _step_t=0.0; _last_d=Vector2i.ZERO; return
	if d!=_last_d: _last_d=d; _hold_t=0.0; _step_t=0.0; _do_step(d); return
	_hold_t+=delta
	if _hold_t<0.22: return
	_step_t+=delta
	if _step_t>=0.10: _step_t=0.0; _do_step(d)

func _input(ev:InputEvent)->void:
	if _dlg or _mov: return
	if Input.is_action_just_pressed("ui_accept"):
		_interact()

func _do_step(d:Vector2i)->void:
	var dest:=_p+d; var t:=_tile(dest)
	if t in [T_OCEAN,T_WATER]: return
	_p=dest; _mov=true
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tw: _tw.kill()
	_tw=create_tween()
	_tw.tween_method(func(v:Vector2):_px=v;_upd_cam();queue_redraw(),_px,tgt,0.12)
	_tw.tween_callback(func():_mov=false; _chk_loc())
	_ft=1-_ft

func _chk_loc()->void:
	for loc in LOCS:
		if loc.pos==_p and loc.type in ["zone","silver"]: _enter(loc); return

func _interact()->void:
	var front:=_p+_dvec(_dir)
	for loc in LOCS:
		if loc.pos==front: _enter(loc); return

func _enter(loc:Dictionary)->void:
	match loc.type:
		"zone": enter_zone.emit(loc.id)
		"silver":
			if not GameManager.can_challenge_silver():
				show_dialog.emit(["Silver Mountain...\nA powerful force blocks your path.","You need Level 100 and all 20 badges!"])
			else: enter_zone.emit("silver")
		"rest":
			GameManager.heal_full()
			show_dialog.emit(["Welcome to "+loc.label+"!","You rest and recover.\nAll HP restored!"])

func _upd_cam()->void:
	_cam.x=clamp(_px.x-240.0,0,COLS*TS-480); _cam.y=clamp(_px.y-160.0,0,ROWS*TS-320)
func _tile(p:Vector2i)->int:
	if p.y<0 or p.y>=ROWS or p.x<0 or p.x>=COLS: return T_OCEAN
	return WMAP[p.y][p.x]
func _dvec(d:int) -> Vector2i:
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
func _process(d:float)->void: _t+=d; _at+=d; if _at>=0.25: _at=0.0; _ft=1-_ft; queue_redraw()

func _draw()->void:
	var ox:=int(_cam.x);var oy:=int(_cam.y);var fnt:=ThemeDB.fallback_font;var DK:=Color("#181010")
	var c0=int(ox/TS);var c1=min(c0+32,COLS);var r0=int(oy/TS);var r1=min(r0+22,ROWS)
	for r in range(r0,r1):
		for c in range(c0,c1): _wt(WMAP[r][c],c*TS-ox,r*TS-oy,c,r)
	for r in range(r0,r1):
		for c in range(c0,c1):
			if WMAP[r][c] in [T_FOREST,T_TOWN,T_GYM,T_SILVER]:
				_wt_raised(WMAP[r][c],c*TS-ox,r*TS-oy)
		if _p.y==r: _draw_player_sprite(_px.x-ox,_px.y-oy)
	for loc in LOCS:
		var sx=loc.pos.x*TS-ox; var sy=loc.pos.y*TS-oy
		if sx<-80 or sx>500 or sy<-20 or sy>340: continue
		var pulse:=0.55+0.45*sin(_t*2.5+loc.pos.x)
		draw_rect(Rect2(sx-1,sy-13,len(loc.label)*6+8,11),DK)
		draw_rect(Rect2(sx,sy-12,len(loc.label)*6+6,9),Color("#f0f0e0"))
		draw_string(fnt,Vector2(sx+3,sy-4),loc.label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,loc.color*Color(1,1,1,pulse))
		if loc.type in ["zone","silver"]:
			draw_rect(Rect2(sx-1,sy-1,TS+2,TS+2),loc.color*Color(1,1,1,0.2+pulse*0.15),false,1.5)
	# Minimap
	draw_rect(Rect2(2,2,COLS*2+4,ROWS*2+4),DK)
	for r in ROWS:
		for c in COLS:
			var mc: Color

			match WMAP[r][c]:
				T_OCEAN:
					mc = Color("#1b3a80")

				T_GRASS, T_FOREST:
					mc = Color("#4a9829")

				T_MTN:
					mc = Color("#7080a0")

				T_PEAK:
					mc = Color("#d0d8e0")

				T_PATH:
					mc = Color("#c08a00")

				T_SAND, T_TOWN:
					mc = Color("#d8c878")

				T_GYM:
					mc = Color("#c24040")

				T_SILVER:
					mc = Color("#a0a0a0")

				T_WATER:
					mc = Color("#2840b0")

				_:
					mc = Color("#444444")
			draw_rect(Rect2(4+c*2,4+r*2,2,2),mc)
	draw_rect(Rect2(4+_p.x*2-1,4+_p.y*2-1,4,4),Color("#ffffff"))
	# Zone hint
	for loc in LOCS:
		if (_p-loc.pos).length()<2.5:
			draw_rect(Rect2(100,303,280,16),DK); draw_rect(Rect2(101,304,278,14),Color("#f0f0e0"))
			draw_string(fnt,Vector2(110,314),"ENTER — enter "+loc.label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,loc.color)
			break

func _wt(t:int,px:int,py:int,c:int,r:int)->void:
	var ck:=(c+r)%2==0
	match t:
		T_OCEAN:
			draw_rect(Rect2(px,py,TS,TS),Color("#1838a0"))
			draw_rect(Rect2(px+1,py+2,TS-2,2),Color("#2858c0",0.6+0.4*sin(_t*1.2+(c+r)*0.4)))
		T_GRASS,T_FOREST,T_TOWN,T_GYM,T_SILVER:
			draw_rect(Rect2(px,py,TS,TS),Color("#58a030") if ck else Color("#489028"))
			if (c*7+r*11)%8==0: draw_rect(Rect2(px+3,py+9,1,4),Color("#78c048"))
		T_MTN: draw_rect(Rect2(px,py,TS,TS),Color("#706858") if ck else Color("#806868"))
		T_PEAK:
			draw_rect(Rect2(px,py,TS,TS),Color("#555060"))
			draw_rect(Rect2(px+3,py+0,10,5),Color("#d8e0f0")); draw_rect(Rect2(px+5,py+0,6,3),Color("#ffffff"))
		T_PATH:
			draw_rect(Rect2(px,py,TS,TS),Color("#d8c060") if ck else Color("#c8b050"))
		T_SAND,T_TOWN:
			draw_rect(Rect2(px,py,TS,TS),Color("#e8d878") if ck else Color("#d8c868"))
		T_WATER:
			var wt:=0.45+0.55*sin(_t*1.6+(c+r)*0.5)
			draw_rect(Rect2(px,py,TS,TS),Color("#2848b0"))
			draw_rect(Rect2(px+1,py+3,TS-2,2),Color("#4868c8",wt))
		T_BRIDGE:
			draw_rect(Rect2(px,py,TS,TS),Color("#c09030"))
			draw_rect(Rect2(px+1,py,3,TS),Color("#a07020")); draw_rect(Rect2(px+12,py,3,TS),Color("#a07020"))
		_: draw_rect(Rect2(px,py,TS,TS),Color("#489028") if ck else Color("#388020"))

func _wt_raised(t:int,px:int,py:int)->void:
	var DK:=Color("#181010")
	match t:
		T_FOREST:
			draw_rect(Rect2(px+5,py+9,6,7),Color("#6a4010"))
			draw_rect(Rect2(px+1,py+11,14,7),Color("#1a4810")); draw_rect(Rect2(px+3,py+6,10,8),Color("#286018"))
			draw_rect(Rect2(px+5,py+3,6,6),Color("#40a028")); draw_rect(Rect2(px+6,py+2,4,3),Color("#58b840"))
			draw_rect(Rect2(px+7,py+1,2,2),Color(1,1,1,0.2)); draw_rect(Rect2(px+1,py+6,14,12),DK,false,1.0)
		T_TOWN:
			draw_rect(Rect2(px+1,py+4,14,10),Color("#e8d8b0")); draw_rect(Rect2(px+1,py+1,14,5),Color("#c03018"))
			draw_rect(Rect2(px+1,py+11,14,5),Color("#d0c8a0")); draw_rect(Rect2(px+4,py+6,4,5),Color("#88ccff"))
			draw_rect(Rect2(px+4,py+6,4,5),DK,false,1.0); draw_rect(Rect2(px+1,py+1,14,15),DK,false,1.0)
		T_GYM:
			var g:=0.4+0.4*sin(_t*2.5)
			draw_rect(Rect2(px+2,py+2,12,12),Color("#203080")); draw_rect(Rect2(px+2,py+12,12,4),Color("#102060"))
			draw_rect(Rect2(px+4,py+10,8,2),Color("#4080ff",g)); draw_rect(Rect2(px+2,py+2,12,16),DK,false,1.0)
		T_SILVER:
			var sg:=0.5+0.5*sin(_t*2.0)
			draw_rect(Rect2(px+2,py+8,12,8),Color("#6070a8"))
			draw_colored_polygon(
	PackedVector2Array([
		Vector2(px, py+8),
		Vector2(px+8, py+0),
		Vector2(px+16, py+8)
	]),
	Color("#8090c8")
)
			draw_rect(Rect2(px+5,py+2,6,3),Color("#b0c0e8")); draw_rect(Rect2(px+6,py+1,4,2),Color(1,1,1,sg))

func _draw_player_sprite(px:float,py:float)->void:
	var DK:=Color("#181010"); var skin:=Color("#f0c890")
	var bob:=0 if _ft==0 else -1
	draw_rect(Rect2(px+1,py+12,14,3),Color(0,0,0,0.2))
	draw_rect(Rect2(px+2,py+7+bob,5,6),Color("#181888")); draw_rect(Rect2(px+9,py+7-bob,5,6),Color("#181888"))
	draw_rect(Rect2(px+1,py+3,14,6),Color("#c01010")); draw_rect(Rect2(px+1,py+3,14,2),Color("#e01818"))
	draw_rect(Rect2(px+1,py+3,14,6),DK,false,1.0)
	draw_rect(Rect2(px+4,py+0,8,5),skin); draw_rect(Rect2(px+4,py+0,8,5),DK,false,1.0)
	draw_rect(Rect2(px+3,py+0,10,3),Color("#c01010")); draw_rect(Rect2(px+2,py+2,12,2),Color("#c01010"))
	draw_rect(Rect2(px+3,py+0,10,3),DK,false,1.0)
	if _dir==0: draw_rect(Rect2(px+5,py+3,2,2),DK); draw_rect(Rect2(px+9,py+3,2,2),DK)
