# TitleScreen.gd
extends Node2D
signal start_game
var _alpha:float=0.0; var _blink_t:float=0.0; var _blink:bool=true
var _ready_f:bool=false; var _time:float=0.0
const STARS:=[
	Vector2(18,12),Vector2(55,8),Vector2(95,22),Vector2(148,6),Vector2(190,18),
	Vector2(235,10),Vector2(280,25),Vector2(330,8),Vector2(375,20),Vector2(415,12),
	Vector2(458,28),Vector2(32,42),Vector2(78,55),Vector2(128,38),Vector2(200,48),
	Vector2(260,35),Vector2(315,52),Vector2(362,40),Vector2(430,50),Vector2(470,36),
	Vector2(10,70),Vector2(60,82),Vector2(110,68),Vector2(175,88),Vector2(240,72),
	Vector2(300,90),Vector2(355,78),Vector2(410,95),Vector2(455,68),Vector2(8,100),
]
func _ready()->void: set_process(true); set_process_input(true)
func _process(delta:float)->void:
	_time+=delta; _alpha=minf(_alpha+delta*0.55,1.0)
	if _alpha>=1.0: _ready_f=true
	_blink_t+=delta; if _blink_t>=0.52: _blink_t=0.0; _blink=not _blink
	queue_redraw()
func _input(event:InputEvent)->void:
	if _ready_f and event.is_action_pressed("ui_accept"): start_game.emit()
func _draw()->void:
	const W:=480.0;const H:=320.0
	var fnt:=ThemeDB.fallback_font
	# Sky
	for i in 8:
		var t:=float(i)/7.0
		draw_rect(Rect2(0,i*40,W,42),Color(0.02+t*0.04,0.02+t*0.06,0.10+t*0.14,_alpha))
	# Stars with twinkle
	for si in STARS.size():
		var s=STARS[si]; var tw:=0.55+0.45*sin(_time*1.8+si*0.7)
		draw_rect(Rect2(s.x,s.y,2 if si%3==0 else 1,2 if si%3==0 else 1),Color(1,1,1,_alpha*tw))
	# Moon crescent
	draw_rect(Rect2(400,18,24,24),Color(1.0,0.97,0.80,_alpha))
	draw_rect(Rect2(407,20,22,20),Color(0.04,0.04,0.14,_alpha))
	# Mountains
	var dm:=Color(0.06,0.07,0.18,_alpha)
	draw_colored_polygon(
	PackedVector2Array([Vector2(0,200), Vector2(60,140), Vector2(130,200)]),
	dm
)

	draw_colored_polygon(
	PackedVector2Array([Vector2(100,200), Vector2(200,118), Vector2(310,200)]),
	dm
)

	draw_colored_polygon(
	PackedVector2Array([Vector2(270,200), Vector2(380,108), Vector2(480,200)]),
	dm
)
	# Silver peak
	var sm:=Color(0.78,0.84,1.0,_alpha)
	draw_colored_polygon(
	PackedVector2Array([Vector2(360,126), Vector2(380,108), Vector2(400,126)]),
	sm
)
	# Ground
	draw_rect(Rect2(0,200,W,H-200),Color(0.05,0.10,0.05,_alpha))
	for gx in range(0,480,8):
		draw_rect(Rect2(gx,197,4,3+(gx%5)),Color(0.10,0.22,0.08,_alpha*0.7))
	# Title plate
	if _alpha>0.1:
		draw_rect(Rect2(60,62,362,114),Color(0,0,0,_alpha*0.55))
		draw_rect(Rect2(58,60,364,116),Color(1.0,0.84,0.0,_alpha*0.88),false,3.0)
		draw_rect(Rect2(62,64,356,108),Color(0.6,0.45,0.0,_alpha*0.55),false,1.5)
		# KAISER shadow + text
		draw_string(fnt,Vector2(84,118),"KAISER",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(0,0,0,_alpha*0.6))
		draw_string(fnt,Vector2(82,116),"KAISER",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(1.0,0.88,0.20,_alpha))
		draw_string(fnt,Vector2(222,158),"QUEST",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(0,0,0,_alpha*0.6))
		draw_string(fnt,Vector2(220,156),"QUEST",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(1.0,1.0,1.0,_alpha))
		draw_rect(Rect2(68,162,346,2),Color(1.0,0.84,0.0,_alpha*0.7))
	if _alpha>0.5:
		draw_string(fnt,Vector2(96,184),"Learn  ·  Level Up  ·  Become Kaiser",
			HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.75,0.82,1.0,_alpha))
	# World icons row
	if _alpha>0.7:
		for wd in [{"icon":"∑","col":Color("#44aaff"),"lbl":"MATH","x":110.0},
				   {"icon":"A","col":Color("#ffcc44"),"lbl":"LANGUAGE","x":220.0},
				   {"icon":"♪","col":Color("#cc44ff"),"lbl":"MUSIC","x":326.0}]:
			draw_rect(Rect2(wd.x-2,198,76,38),Color(0,0,0,_alpha*0.45))
			draw_rect(Rect2(wd.x-2,198,76,38),wd.col*Color(1,1,1,_alpha*0.45),false,1.5)
			draw_string(fnt,Vector2(wd.x+6,220),wd.icon,HORIZONTAL_ALIGNMENT_LEFT,-1,20,wd.col*Color(1,1,1,_alpha))
			draw_string(fnt,Vector2(wd.x+28,220),wd.lbl,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.9,0.9,0.9,_alpha))
	# Press ENTER
	if _ready_f and _blink:
		draw_rect(Rect2(138,248,204,22),Color(0,0,0,0.55))
		draw_string(fnt,Vector2(152,264),"Press  ENTER  to  Start",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#ffffff"))
	draw_string(fnt,Vector2(400,314),"v0.2",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.3,0.3,0.5,_alpha))
