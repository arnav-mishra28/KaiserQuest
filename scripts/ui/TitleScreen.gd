# TitleScreen.gd
extends Node2D
signal start_game
var _a:float=0.0; var _bt:float=0.0; var _blink:bool=true; var _ready_f:bool=false; var _t:float=0.0
const STARS:=[Vector2(18,12),Vector2(55,8),Vector2(95,22),Vector2(148,6),Vector2(190,18),Vector2(235,10),Vector2(280,25),Vector2(330,8),Vector2(375,20),Vector2(415,12),Vector2(458,28),Vector2(32,42),Vector2(78,55),Vector2(128,38),Vector2(200,48),Vector2(260,35),Vector2(315,52),Vector2(362,40),Vector2(430,50),Vector2(470,36),Vector2(10,70),Vector2(60,82),Vector2(110,68),Vector2(175,88),Vector2(240,72),Vector2(300,90),Vector2(355,78),Vector2(410,95),Vector2(455,68),Vector2(8,100)]
func _ready()->void: set_process(true); set_process_input(true)
func _process(d:float)->void:
	_t+=d; _a=minf(_a+d*0.55,1.0); if _a>=1.0: _ready_f=true
	_bt+=d; if _bt>=0.52: _bt=0.0; _blink=not _blink; queue_redraw()
func _input(ev:InputEvent)->void:
	if _ready_f and ev.is_action_pressed("ui_accept"): start_game.emit()
func _draw()->void:
	const W:=480.0;const H:=320.0; var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010")
	for i in 8:
		var tt:=float(i)/7.0; draw_rect(Rect2(0,i*40,W,42),Color(0.02+tt*0.04,0.02+tt*0.06,0.10+tt*0.14,_a))
	for si in STARS.size():
		var s=STARS[si]; var tw:=0.55+0.45*sin(_t*1.8+si*0.7)
		draw_rect(Rect2(s.x,s.y,2 if si%3==0 else 1,2 if si%3==0 else 1),Color(1,1,1,_a*tw))
	draw_rect(Rect2(400,18,24,24),Color(1.0,0.97,0.80,_a)); draw_rect(Rect2(407,20,22,20),Color(0.04,0.04,0.14,_a))
	var dm:=Color(0.06,0.07,0.18,_a)
	draw_colored_polygon(PackedVector2Array([Vector2(0,200), Vector2(60,140), Vector2(130,200)]), dm)
	draw_colored_polygon(PackedVector2Array([Vector2(100,200), Vector2(200,118), Vector2(310,200)]), dm)
	draw_colored_polygon(PackedVector2Array([Vector2(270,200), Vector2(380,108), Vector2(480,200)]), dm)
	var sm:=Color(0.78,0.84,1.0,_a)
	draw_colored_polygon(PackedVector2Array([Vector2(360,126), Vector2(380,108), Vector2(400,126)]), sm)
	draw_rect(Rect2(0,200,W,H-200),Color(0.05,0.10,0.05,_a))
	if _a>0.1:
		draw_rect(Rect2(58,60,364,116),DK); draw_rect(Rect2(60,62,360,112),Color("#f0f0e0"))
		draw_rect(Rect2(60,62,360,16),Color("#2060a0")); draw_rect(Rect2(61,63,358,14),Color("#4888d0"))
		draw_rect(Rect2(60,62,360,16),Color(1.0,0.84,0.0,_a*0.6),false,2.0)
		draw_string(fnt,Vector2(82,116),"KAISER",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(0,0,0,_a*0.5))
		draw_string(fnt,Vector2(80,114),"KAISER",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(1.0,0.88,0.20,_a))
		draw_string(fnt,Vector2(220,156),"QUEST",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(0,0,0,_a*0.5))
		draw_string(fnt,Vector2(218,154),"QUEST",HORIZONTAL_ALIGNMENT_LEFT,-1,52,Color(1.0,1.0,1.0,_a))
		draw_rect(Rect2(68,160,346,2),Color(1.0,0.84,0.0,_a*0.6))
	if _a>0.5:
		draw_string(fnt,Vector2(96,182),"Learn  ·  Battle  ·  Become Kaiser",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.75,0.82,1.0,_a))
	if _a>0.7:
		for wd in [{"icon":"∑","col":Color("#2060d0"),"lbl":"MATH","x":108.0},{"icon":"A","col":Color("#c07010"),"lbl":"LANGUAGE","x":218.0},{"icon":"♪","col":Color("#8020c0"),"lbl":"MUSIC","x":326.0}]:
			draw_rect(Rect2(wd.x-2,198,76,38),Color(0,0,0,_a*0.45)); draw_rect(Rect2(wd.x-2,198,76,38),wd.col*Color(1,1,1,_a*0.45),false,1.5)
			draw_string(fnt,Vector2(wd.x+6,220),wd.icon,HORIZONTAL_ALIGNMENT_LEFT,-1,20,wd.col*Color(1,1,1,_a))
			draw_string(fnt,Vector2(wd.x+28,220),wd.lbl,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.9,0.9,0.9,_a))
	if _ready_f and _blink:
		draw_rect(Rect2(138,248,204,22),Color(0,0,0,0.55))
		draw_string(fnt,Vector2(150,264),"Press  ENTER  to  Start",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#ffffff"))
	draw_string(fnt,Vector2(400,314),"v1.0",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.3,0.3,0.5,_a))
