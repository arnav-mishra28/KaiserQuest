# WorldMap.gd v3.0 — Full Kalos Region: 20 cities, routes, gyms, paths
extends Node2D

signal enter_zone(zone_id: String)
signal show_dialog(lines: Array)

const TS   := 16
const COLS := 40   # 40×16=640 → scrollable world
const ROWS := 26   # 26×16=416 → scrollable world

# Tile IDs
const T_OCEAN:=0;const T_GRASS:=1;const T_FOREST:=2;const T_MTN:=3;const T_PEAK:=4
const T_PATH:=5;const T_SAND:=6;const T_TOWN:=7;const T_GYM:=8;const T_SILVER:=9
const T_WATER:=10;const T_BRIDGE:=11;const T_CAVE:=12;const T_FLOWER:=13

# ── FULL KALOS REGION MAP (40×26) ────────────────────────────────────────────
const WMAP := [
#  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 4, 4,  4, 4, 4, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #0
  [0, 0, 0, 0, 2, 2, 2, 1, 1, 1,  1, 1, 2, 2, 1, 1, 4, 4, 9, 4,  4, 4, 4, 4, 1, 1, 2, 2, 1, 1,  1, 2, 2, 1, 1, 1, 2, 2, 0, 0], #1
  [0, 0, 0, 2, 1, 1, 1, 1, 7, 5,  5, 1, 1, 1, 5, 4, 4, 3, 3, 4,  4, 3, 4, 1, 1, 1, 1, 1, 8, 5,  5, 1, 1, 1, 1, 2, 1, 1, 2, 0], #2
  [0, 0, 2, 1, 1, 1, 5, 5, 5, 1,  1, 5, 1, 1, 5, 3, 4, 3, 1, 1,  1, 3, 4, 1, 1, 5, 1, 5, 5, 1,  1, 5, 1, 1, 2, 1, 1, 1, 1, 0], #3
  [0, 2, 1, 1, 1, 5, 1, 1, 1, 5, 10,10, 5, 1, 1, 1, 5, 1, 1, 1,  1, 1, 5, 1, 5, 1, 1, 1, 1, 5,  1, 1, 5, 2, 1, 1, 1, 1, 2, 0], #4
  [0, 1, 1, 7, 5, 1, 1, 1,10,10, 10,10, 1, 1, 1, 5, 1, 1, 1, 1,  8, 1, 5, 1, 1, 1, 5, 1, 1, 1,  5, 2, 1, 1, 7, 1, 1, 2, 1, 0], #5
  [0, 1, 5, 5, 5, 1, 2,11,11,11, 11,11, 2, 1, 5, 1, 1, 1, 2, 5,  5, 5, 1, 1, 5, 1, 1, 2, 1, 5,  1, 1, 2, 1, 5, 1, 2, 1, 1, 0], #6
  [0, 1, 1, 8, 1, 1, 2, 1, 1, 1,  1, 1, 2, 1, 1, 5, 1, 1, 1, 1,  7, 1, 1, 5, 1, 1, 2, 1, 1, 1,  1, 5, 1, 1, 8, 1, 1, 1, 2, 0], #7
  [0, 2, 1, 5, 1, 1, 1, 1, 1, 1,  1, 1, 1, 1, 5, 1, 1, 2, 1, 1,  5, 1, 1, 1, 5, 1, 1, 1, 5, 1,  1, 1, 5, 1, 5, 1, 1, 2, 1, 0], #8
  [0, 1, 1, 5, 1, 1, 1, 1, 1, 6,  6, 6, 6, 1, 1, 5, 1, 1, 1, 5,  1, 1, 1, 1, 1, 5, 1, 5, 1, 1,  1, 5, 1, 1, 1, 1, 2, 1, 1, 0], #9
  [0, 1, 5, 5, 5, 1, 1, 1, 6, 6,  7, 6, 6, 1, 1, 1, 5, 1, 5, 1,  1, 1, 5, 1, 5, 1, 1, 1, 1, 5,  5, 1, 1, 1, 1, 2, 1, 1, 2, 0], #10
  [0, 1, 1, 8, 1, 1, 2, 1, 6, 6,  6, 6, 6, 2, 1, 5, 1, 1, 1, 1,  1, 5, 1, 5, 1, 1, 2, 1, 1, 1,  1, 5, 1, 1, 8, 1, 1, 2, 1, 0], #11
  [0, 2, 1, 5, 1, 1, 1, 1, 1, 6,  6, 6, 6, 1, 5, 1, 1, 2, 1, 1,  5, 1, 1, 1, 1, 5, 1, 1, 5, 1,  1, 1, 5, 2, 5, 1, 1, 1, 2, 0], #12
  [0, 1, 1, 5, 1, 1, 1, 2, 1, 1,  1, 1, 1, 2, 1, 5, 1, 1, 1, 5,  1, 1, 5, 1, 5, 1, 2, 1, 1, 1,  5, 1, 1, 1, 1, 5, 1, 2, 1, 0], #13
  [0, 1, 5, 5, 5, 1, 1, 1, 1, 1,  1, 1, 1, 1, 5, 1, 1, 1, 5, 1,  1, 5, 1, 1, 1, 1, 1, 5, 5, 5,  1, 1, 1, 2, 1, 1, 1, 1, 2, 0], #14
  [0, 1, 1, 7, 5, 1, 1, 1, 1, 1,  1, 1, 1, 5, 1, 5, 1, 1, 1, 1,  5, 1, 1, 5, 1, 5, 1, 1, 1, 1,  5, 1, 7, 1, 5, 1, 1, 2, 1, 0], #15
  [0, 2, 1, 5, 1, 1, 2, 2, 1, 1,  1, 1, 2, 1, 5, 1, 1, 2, 1, 5,  1, 1, 5, 1, 1, 1, 2, 1, 1, 5,  1, 1, 5, 1, 1, 5, 2, 1, 1, 0], #16
  [0, 0, 2, 5, 1, 1, 1, 1, 1, 1,  1, 1, 1, 5, 1, 1, 5, 1, 1, 1,  1, 5, 1, 1, 2, 1, 1, 1, 5, 1,  1, 5, 1, 8, 1, 1, 1, 2, 0, 0], #17
  [0, 0, 0, 2, 2, 1, 1, 1, 1, 1,  1, 1, 5, 1, 1, 5, 1, 1, 5, 1,  8, 1, 1, 2, 1, 2, 1, 5, 1, 1,  1, 1, 2, 5, 1, 1, 2, 0, 0, 0], #18
  [0, 0, 0, 0, 1, 1, 2, 1, 1, 1,  1, 5, 1, 1, 5, 1, 1, 1, 1, 5,  5, 5, 2, 1, 1, 1, 5, 1, 1, 1,  2, 1, 1, 5, 1, 2, 0, 0, 0, 0], #19
  [0, 0, 0, 0, 0, 2, 1, 1, 5, 1,  1, 1, 1, 5, 1, 1, 1, 5, 5, 7,  5, 5, 1, 1, 1, 5, 1, 1, 1, 2,  1, 1, 5, 1, 2, 0, 0, 0, 0, 0], #20
  [0, 0, 0, 0, 0, 0, 2, 5, 1, 1,  1, 1, 5, 1, 1, 1, 5, 1, 1, 5,  1, 1, 5, 1, 5, 1, 1, 2, 1, 1,  1, 5, 1, 2, 0, 0, 0, 0, 0, 0], #21
  [0, 0, 0, 0, 0, 0, 0, 2, 2, 1,  1, 5, 1, 1, 2, 5, 1, 1, 5, 1,  1, 5, 1, 1, 1, 2, 1, 1, 1, 5,  1, 1, 2, 0, 0, 0, 0, 0, 0, 0], #22
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 2,  2, 1, 1, 2, 1, 1, 5, 5, 1, 1,  1, 1, 5, 2, 1, 1, 1, 5, 1, 1,  2, 0, 0, 0, 0, 0, 0, 0, 0, 0], #23
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 2, 2, 1, 1, 5, 1, 1, 1, 1,  1, 5, 1, 1, 2, 1, 5, 1, 2, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #24
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 2, 2, 2, 2, 2, 2, 2,  2, 2, 2, 2, 0, 2, 2, 2, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #25
]

# ── Location markers (20 gyms + silver + routes) ─────────────────────────────
const LOCS := [
	# ACT 1 Cities
	{"id":"starter_town",   "pos":Vector2i(8,2),  "label":"Pallet Grove",    "type":"zone","color":Color("#60b030"),"gym":1},
	{"id":"mathopolis",     "pos":Vector2i(3,5),  "label":"Mathopolis",      "type":"zone","color":Color("#2060d0"),"gym":2},
	{"id":"lexicon_city",   "pos":Vector2i(10,10),"label":"Lexicon City",    "type":"zone","color":Color("#c07010"),"gym":3},
	{"id":"harmonia",       "pos":Vector2i(20,5), "label":"Harmonia",        "type":"zone","color":Color("#8020c0"),"gym":4},
	{"id":"crossroads",     "pos":Vector2i(3,15), "label":"Crossroads",      "type":"zone","color":Color("#806020"),"gym":5},
	# ACT 2 Cities
	{"id":"equation_vale",  "pos":Vector2i(20,7), "label":"Equation Vale",   "type":"zone","color":Color("#10a060"),"gym":6},
	{"id":"verb_city",      "pos":Vector2i(28,2), "label":"Verb City",       "type":"zone","color":Color("#308840"),"gym":7},
	{"id":"chord_haven",    "pos":Vector2i(34,7), "label":"Chord Haven",     "type":"zone","color":Color("#c040a0"),"gym":8},
	{"id":"function_peak",  "pos":Vector2i(34,11),"label":"Function Peak",   "type":"zone","color":Color("#c04020"),"gym":9},
	{"id":"syntax_port",    "pos":Vector2i(28,7), "label":"Syntax Port",     "type":"zone","color":Color("#6030a0"),"gym":10},
	{"id":"scale_summit",   "pos":Vector2i(34,17),"label":"Scale Summit",    "type":"zone","color":Color("#2080c0"),"gym":11},
	{"id":"quadratic_mesa", "pos":Vector2i(20,18),"label":"Quadratic Mesa",  "type":"zone","color":Color("#902020"),"gym":12},
	# ACT 3 Cities
	{"id":"grammar_citadel","pos":Vector2i(10,18),"label":"Grammar Citadel", "type":"zone","color":Color("#a03080"),"gym":13},
	{"id":"time_keep",      "pos":Vector2i(20,20),"label":"Time Keep",       "type":"zone","color":Color("#204080"),"gym":14},
	{"id":"mixed_ruins",    "pos":Vector2i(15,15),"label":"Mixed Ruins",     "type":"zone","color":Color("#706050"),"gym":15},
	{"id":"pressure_city",  "pos":Vector2i(32,15),"label":"Pressure City",   "type":"zone","color":Color("#c03010"),"gym":16},
	{"id":"harmony_peak",   "pos":Vector2i(3,18), "label":"Harmony Peak",    "type":"zone","color":Color("#8040c0"),"gym":17},
	{"id":"strategy_vale",  "pos":Vector2i(15,20),"label":"Strategy Vale",   "type":"zone","color":Color("#405080"),"gym":18},
	{"id":"kaiser_gate",    "pos":Vector2i(32,17),"label":"Kaiser Gate",     "type":"zone","color":Color("#c08010"),"gym":19},
	{"id":"apex_city",      "pos":Vector2i(20,20),"label":"Apex City",       "type":"zone","color":Color("#2060a0"),"gym":20},
	# Special
	{"id":"silver",         "pos":Vector2i(18,1), "label":"Silver Mtn",      "type":"silver","color":Color("#9098c8"),"gym":0},
]

# ── Route duel NPCs ───────────────────────────────────────────────────────────
const ROUTE_DUELS := [
	{"pos":Vector2i(6,3),   "name":"Youngster Jay","accuracy":0.40,"world":"math",   "xp":80},
	{"pos":Vector2i(12,3),  "name":"Scholar Mira", "accuracy":0.50,"world":"english","xp":100},
	{"pos":Vector2i(15,7),  "name":"Poet Sam",     "accuracy":0.45,"world":"music",  "xp":100},
	{"pos":Vector2i(22,3),  "name":"Traveler Lee", "accuracy":0.52,"world":"math",   "xp":120},
	{"pos":Vector2i(6,7),   "name":"RIVAL — Kira", "accuracy":0.65,"world":"math",   "xp":200, "rival":true, "encounter":1},
	{"pos":Vector2i(25,12), "name":"Thinker Rox",  "accuracy":0.58,"world":"english","xp":150},
	{"pos":Vector2i(30,4),  "name":"Musician Theo","accuracy":0.55,"world":"music",  "xp":150},
	{"pos":Vector2i(26,10), "name":"Logician Vera","accuracy":0.62,"world":"math",   "xp":180},
	{"pos":Vector2i(24,13), "name":"Grammarian Nix","accuracy":0.60,"world":"english","xp":180},
	{"pos":Vector2i(8,13),  "name":"RIVAL — Kira", "accuracy":0.72,"world":"english","xp":250,"rival":true,"encounter":2},
	{"pos":Vector2i(16,13), "name":"Scholar Zeph", "accuracy":0.65,"world":"music",  "xp":200},
	{"pos":Vector2i(36,13), "name":"Master Tao",   "accuracy":0.70,"world":"math",   "xp":220},
	{"pos":Vector2i(8,18),  "name":"Elder Lysa",   "accuracy":0.68,"world":"english","xp":220},
	{"pos":Vector2i(24,19), "name":"RIVAL — Kira", "accuracy":0.78,"world":"music",  "xp":300,"rival":true,"encounter":3},
]

# ── Player state ──────────────────────────────────────────────────────────────
var _p:    Vector2i = Vector2i(8, 3)
var _px:   Vector2  = Vector2(128, 48)
var _dir:  int      = 0
var _mov:  bool     = false
var _dlg:  bool     = false
var _tw:   Tween    = null
var _time: float    = 0.0
var _ft:   int      = 0
var _at:   float    = 0.0
var _cam:  Vector2  = Vector2.ZERO  # camera (stays 0 since map scrolls)

func _ready() -> void:
	add_to_group("overworld")
	_p = Vector2i(8, 3); _px = Vector2(_p.x*TS, _p.y*TS)
	_upd_cam(); set_process(true); set_process_input(true)

func set_dialog_open(v: bool) -> void: _dlg = v

func _upd_cam() -> void:
	# Map is 40×26 tiles = 640×416 px; viewport is 480×320
	_cam.x = clamp(_px.x - 240.0, 0, COLS*TS - 480)
	_cam.y = clamp(_px.y - 160.0, 0, ROWS*TS - 320)

func _physics_process(delta: float) -> void:
	if _dlg or _mov: return
	var d := Vector2i.ZERO
	if   Input.is_action_pressed("ui_down"):  d=Vector2i(0,1);  _dir=0
	elif Input.is_action_pressed("ui_up"):    d=Vector2i(0,-1); _dir=1
	elif Input.is_action_pressed("ui_left"):  d=Vector2i(-1,0); _dir=2
	elif Input.is_action_pressed("ui_right"): d=Vector2i(1,0);  _dir=3
	if d != Vector2i.ZERO: _step(d)

func _input(ev: InputEvent) -> void:
	if _dlg or _mov: return
	if Input.is_action_just_pressed("ui_accept"):
		_interact()

func _step(d: Vector2i) -> void:
	var dest := _p + d; var t := _tile(dest)
	if t in [T_OCEAN, T_MTN, T_PEAK]: return
	_p = dest; _mov = true
	var tgt := Vector2(dest.x*TS, dest.y*TS)
	if _tw: _tw.kill()
	_tw = create_tween()
	_tw.tween_method(func(v:Vector2):_px=v;_upd_cam();queue_redraw(),_px,tgt,0.13)
	_tw.tween_callback(func():_mov=false;_chk())
	_ft = 1-_ft

func _chk() -> void:
	# Auto-enter zones stepped on
	for loc in LOCS:
		if loc.pos == _p:
			if loc.type in ["zone","silver"]: _enter(loc); return
	# Route duels (auto-trigger if walked into)
	for duel in ROUTE_DUELS:
		if duel.pos == _p and not GameManager.has_talked(duel.name+"_duel"):
			_trigger_duel(duel); return

func _interact() -> void:
	var front := _p + _dir_vec(_dir)
	for loc in LOCS:
		if loc.pos == front: _enter(loc); return
	for duel in ROUTE_DUELS:
		if duel.pos == front: _trigger_duel(duel); return

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
		_:
			return Vector2i.ZERO

func _enter(loc: Dictionary) -> void:
	if loc.type == "silver":
		if not GameManager.can_challenge_silver():
			show_dialog.emit(["Silver Mountain...", "You need Level 100\nand all 20 badges!"])
		else: enter_zone.emit("silver")
		return
	enter_zone.emit(loc.id)

func _trigger_duel(duel: Dictionary) -> void:
	GameManager.mark_talked(duel.name+"_duel")
	var lines: Array
	if duel.get("rival", false):
		lines = GymStoryline.get_rival_dialog(duel.get("encounter", 1))
	else:
		lines = [duel.name+" blocks your path!",
				 "Knowledge Duel!\nProve yourself!"]
	show_dialog.emit(lines)
	await get_tree().create_timer(0.1).timeout
	enter_zone.emit("duel:" + JSON.stringify(duel))

func _tile(p: Vector2i) -> int:
	if p.y<0 or p.y>=ROWS or p.x<0 or p.x>=COLS: return T_OCEAN
	return WMAP[p.y][p.x]

func _process(d: float) -> void:
	_time+=d; _at+=d; if _at>=0.25: _at=0.0; _ft=1-_ft; queue_redraw()

# ═════════════════════════════════════════════════════════════════════════════
#  DRAWING
# ═════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var ox := int(_cam.x); var oy := int(_cam.y)
	var fnt := ThemeDB.fallback_font
	var DK  := Color("#181010")

	# Tiles
	var c0=int(ox/TS);var c1=min(c0+32,COLS)
	var r0=int(oy/TS);var r1=min(r0+22,ROWS)
	for r in range(r0,r1):
		for c in range(c0,c1):
			_wt(WMAP[r][c], c*TS-ox, r*TS-oy, c, r)

	# Raised tiles (buildings, trees) above player y
	for r in range(r0,r1):
		for c in range(c0,c1):
			if WMAP[r][c] in [T_FOREST,T_TOWN,T_GYM,T_SILVER]:
				_wt_raised(WMAP[r][c], c*TS-ox, r*TS-oy)
		# Route duel NPCs
		for duel in ROUTE_DUELS:
			if duel.pos.y == r and not GameManager.has_talked(duel.name+"_duel"):
				var sx=duel.pos.x*TS-ox; var sy=duel.pos.y*TS-oy
				if sx>-20 and sx<500 and sy>-20 and sy<340:
					_draw_route_npc(sx,sy,duel)
		# Player at their row
		if _p.y == r: _draw_player_sprite(_px.x-ox, _px.y-oy)

	# Location labels
	for loc in LOCS:
		var sx=loc.pos.x*TS-ox; var sy=loc.pos.y*TS-oy
		if sx<-80 or sx>500 or sy<-20 or sy>340: continue
		var pulse := 0.55+0.45*sin(_time*2.5+loc.pos.x)
		# Gym number badge
		if loc.get("gym",0) > 0:
			var act := GymStoryline.get_act(loc.gym)
			var act_col = {1:Color("#60b030"),2:Color("#2060d0"),3:Color("#c03010")}.get(act,Color.WHITE)
			draw_rect(Rect2(sx+TS-6,sy-2,14,12), DK)
			draw_rect(Rect2(sx+TS-5,sy-1,12,10), act_col)
			draw_string(fnt,Vector2(sx+TS-4,sy+8),"G"+str(loc.gym),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#ffffff"))
		draw_rect(Rect2(sx-1,sy-13,len(loc.label)*6+8,11), DK)
		draw_rect(Rect2(sx,sy-12,len(loc.label)*6+6,9), Color(0,0,0,0.7))
		draw_string(fnt,Vector2(sx+3,sy-4),loc.label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,loc.color*Color(1,1,1,pulse))
		if loc.type in ["zone","silver"]:
			draw_rect(Rect2(sx-2,sy-2,TS+4,TS+4),loc.color*Color(1,1,1,0.25+pulse*0.15),false,1.5)

	# Minimap
	_draw_minimap(ox, oy)

	# HUD hints
	_draw_hud(fnt, DK, ox, oy)

func _wt(t:int,px:int,py:int,c:int,r:int)->void:
	var ck:=(c+r)%2==0
	match t:
		T_OCEAN:
			var wv:=0.4+0.6*sin(_time*1.2+(c+r)*0.3)
			draw_rect(Rect2(px,py,TS,TS),Color(0.05,0.15,0.55))
			draw_rect(Rect2(px+1,py+3,TS-2,2),Color(0.2,0.45,0.9,wv*0.4))
			draw_rect(Rect2(px+1,py+9,TS-2,2),Color(0.2,0.45,0.9,wv*0.25))
		T_GRASS:
			draw_rect(Rect2(px,py,TS,TS),Color("#2a5a1e") if ck else Color("#245218"))
			if (c*7+r*3)%18==0: draw_rect(Rect2(px+3,py+9,2,5),Color("#3a7a28",0.7))
			if (c*11+r*7)%14==0: draw_rect(Rect2(px+10,py+6,3,3),Color("#f880a0",0.8))
		T_FOREST:
			draw_rect(Rect2(px,py,TS,TS),Color("#1a3a10"))
			draw_rect(Rect2(px+2,py+4,12,8),Color("#224a14"))
			draw_rect(Rect2(px+4,py+1,8,6),Color("#2a5c1a"))
		T_MTN:
			draw_rect(Rect2(px,py,TS,TS),Color("#6a5a48"))
			draw_rect(Rect2(px+3,py+2,10,5),Color("#8a7a68"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_PEAK:
			draw_rect(Rect2(px,py,TS,TS),Color("#555060"))
			draw_rect(Rect2(px+3,py,10,5),Color("#b0b8c8"))
			draw_rect(Rect2(px+5,py+1,6,3),Color("#e8ecf8"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_PATH:
			var p1:=Color("#b8a868") if ck else Color("#a89858")
			draw_rect(Rect2(px,py,TS,TS),p1)
			draw_rect(Rect2(px+1,py+1,5,5),Color(0,0,0,0.05))
			draw_rect(Rect2(px+9,py+9,5,5),Color(0,0,0,0.05))
		T_SAND:
			draw_rect(Rect2(px,py,TS,TS),Color("#d4b870") if ck else Color("#c4a860"))
		T_TOWN:
			draw_rect(Rect2(px,py,TS,TS),Color("#b8a868") if ck else Color("#a89858"))
		T_GYM:
			draw_rect(Rect2(px,py,TS,TS),Color("#b8a868"))
		T_SILVER:
			var sg:=0.6+0.4*sin(_time*2.0)
			draw_rect(Rect2(px,py,TS,TS),Color("#181830"))
			draw_polygon(
	PackedVector2Array([
		Vector2(px, py+TS),
		Vector2(px+TS/2, py),
		Vector2(px+TS, py+TS)
	]),
	PackedColorArray([
		Color(0.45, 0.48, 0.7),
		Color(0.45, 0.48, 0.7),
		Color(0.45, 0.48, 0.7)
	])
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
		T_CAVE:
			draw_rect(Rect2(px,py,TS,TS),Color("#3a3040"))
			draw_rect(Rect2(px+3,py+4,10,9),Color("#111118"))
		T_FLOWER:
			draw_rect(Rect2(px,py,TS,TS),Color("#2a5a1e") if ck else Color("#245218"))
			draw_rect(Rect2(px+5,py+5,6,6),Color("#f8a020"))
		_:
			draw_rect(Rect2(px,py,TS,TS),Color("#245218"))

func _wt_raised(t:int,px:int,py:int)->void:
	var fnt:=ThemeDB.fallback_font
	match t:
		T_FOREST:
			draw_rect(Rect2(px+1,py+4,14,10),Color("#1a4010"))
			draw_rect(Rect2(px+2,py+2,12,8),Color("#286018"))
			draw_rect(Rect2(px+4,py+0,8,6),Color("#40a028"))
			draw_rect(Rect2(px+6,py+0,4,4),Color("#60c040"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_TOWN:
			draw_rect(Rect2(px,py,TS,TS),Color("#c8a882"))
			draw_rect(Rect2(px,py,TS,8),Color("#8b2222"))
			draw_rect(Rect2(px+2,py+8,TS-4,8-4),Color("#c8a882"))
			draw_rect(Rect2(px+4,py+9,6,6),Color("#88ccff"))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_GYM:
			draw_rect(Rect2(px,py,TS,TS),Color("#1a3888"))
			draw_rect(Rect2(px,py,TS,6),Color("#2050b0"))
			draw_rect(Rect2(px+2,py+6,TS-4,TS-8),Color("#2040a0"))
			draw_rect(Rect2(px+5,py+7,6,7),Color("#88ccff"))
			draw_rect(Rect2(px+4,py+TS-3,TS-8,2),Color("#4488ff",0.6+0.4*sin(_time*2.5)))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)
		T_SILVER:
			var sg:=0.5+0.5*sin(_time*2.0)
			draw_rect(Rect2(px+3,py+0,10,TS),Color(0.35,0.38,0.6))
			draw_rect(Rect2(px+4,py+0,8,5),Color(0.55,0.6,0.9))
			draw_rect(Rect2(px+6,py+0,4,3),Color(0.85,0.9,1.0,sg))
			draw_rect(Rect2(px,py,TS,TS),Color("#181010"),false,1.0)

func _draw_route_npc(sx:int,sy:int,duel:Dictionary)->void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010")
	var is_rival=duel.get("rival",false)
	var col:=Color("#e02020") if is_rival else Color("#e8c030")
	# Sprite (tiny NPC on world map)
	draw_rect(Rect2(sx+4,sy+10,8,4),DK)
	draw_rect(Rect2(sx+5,sy+4,6,7),col)
	draw_rect(Rect2(sx+4,sy+1,8,5),Color("#f0c890"))
	draw_rect(Rect2(sx+4,sy+1,8,5),DK,false,1.0)
	# Exclamation badge
	if is_rival:
		draw_rect(Rect2(sx+5,sy-8,6,7),Color("#e82020"))
		draw_string(fnt,Vector2(sx+7,sy-2),"R",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("#ffffff"))
	else:
		draw_rect(Rect2(sx+5,sy-8,6,7),Color("#f8d820"))
		draw_string(fnt,Vector2(sx+7,sy-2),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,7,DK)

func _draw_player_sprite(spx:float,spy:float)->void:
	var bob:=0 if _ft==0 else -1; var DK:=Color("#181010")
	draw_rect(Rect2(spx+1,spy+12,14,3),Color(0,0,0,0.2))
	draw_rect(Rect2(spx+2,spy+8+bob,4,5),Color("#1838a0"))
	draw_rect(Rect2(spx+10,spy+8-bob,4,5),Color("#1838a0"))
	draw_rect(Rect2(spx+1,spy+3,14,7),Color("#c01010"))
	draw_rect(Rect2(spx+1,spy+3,14,3),Color("#e01818"))
	draw_rect(Rect2(spx+1,spy+3,14,7),DK,false,1.0)
	draw_rect(Rect2(spx+4,spy+0,8,4),Color("#f0c890"))
	draw_rect(Rect2(spx+4,spy+0,8,4),DK,false,1.0)
	draw_rect(Rect2(spx+3,spy+0,10,3),Color("#c01010"))
	draw_rect(Rect2(spx+2,spy+2,12,2),Color("#c01010"))
	if _dir==0:
		draw_rect(Rect2(spx+5,spy+2,2,2),DK)
		draw_rect(Rect2(spx+9,spy+2,2,2),DK)

func _draw_minimap(ox:int,oy:int)->void:
	const MX:=4;const MY:=4;const MS:=2
	var mw:=COLS*MS; var mh:=ROWS*MS
	draw_rect(Rect2(MX-2,MY-2,mw+4,mh+4),Color("#181010"))
	draw_rect(Rect2(MX-1,MY-1,mw+2,mh+2),Color(0,0,0,0.8))
	for r in ROWS:
		for c in COLS:
			var mc:Color
			match WMAP[r][c]:
				T_OCEAN: mc=Color(0.05,0.15,0.55)
				T_GRASS,T_FOREST: mc=Color(0.2,0.5,0.15)
				T_MTN,T_PEAK: mc=Color(0.5,0.44,0.36)
				T_PATH: mc=Color(0.75,0.68,0.44)
				T_TOWN: mc=Color(0.85,0.7,0.45)
				T_GYM: mc=Color(0.15,0.35,0.85)
				T_SILVER: mc=Color(0.65,0.7,0.9)
				T_WATER: mc=Color(0.1,0.4,0.85)
				_: mc=Color(0.2,0.45,0.15)
			draw_rect(Rect2(MX+c*MS,MY+r*MS,MS,MS),mc)
	# Player dot
	draw_rect(Rect2(MX+_p.x*MS-1,MY+_p.y*MS-1,4,4),Color("#ffffff"))
	draw_rect(Rect2(MX+_p.x*MS-1,MY+_p.y*MS-1,4,4),Color("#181010"),false,1.0)
	# Camera viewport rect
	var vx:=int(ox/TS)*MS; var vy:=int(oy/TS)*MS
	draw_rect(Rect2(MX+vx,MY+vy,30*MS,20*MS),Color(1,1,1,0.12),false,1.0)

func _draw_hud(fnt:Font,DK:Color,ox:int,oy:int)->void:
	# Act indicator
	var total_badges := GameManager.get_badges().size()
	var act := 1 if total_badges<5 else (2 if total_badges<12 else 3)
	var act_name := GymStoryline.get_act_name(act)
	draw_rect(Rect2(420,4,58,14),DK); draw_rect(Rect2(421,5,56,12),Color(0,0,0,0.7))
	draw_string(fnt,Vector2(424,15),"ACT "+str(act),HORIZONTAL_ALIGNMENT_LEFT,-1,9,
		{1:Color("#60b030"),2:Color("#2060d0"),3:Color("#c03010")}.get(act,Color.WHITE))
	# Proximity to cities
	for loc in LOCS:
		var dist=(_p-loc.pos).length()
		if dist<3.0:
			draw_rect(Rect2(90,304,300,15),DK)
			draw_rect(Rect2(91,305,298,13),Color(0,0,0,0.75))
			var gym_str:="" if loc.get("gym",0)==0 else "  [Gym "+str(loc.gym)+"]"
			draw_string(fnt,Vector2(100,316),loc.label+gym_str+" — ENTER to enter",
				HORIZONTAL_ALIGNMENT_LEFT,-1,11,loc.color)
			break
