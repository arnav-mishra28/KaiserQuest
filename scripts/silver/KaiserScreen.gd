# KaiserScreen.gd
extends Node2D
var _time:float=0.0; var _seal_r:float=0.0; var _ta:float=0.0; var _blink:bool=true; var _bt:float=0.0
var _sparks:Array=[]; var _stars:Array=[]
const GOLD:=Color("#ffd700"); const SILV:=Color("#c0c8ff"); const DK:=Color("#181010")
func _ready()->void:
	set_process(true); set_process_input(true)
	for i in 80: _stars.append({"x":randf()*480,"y":randf()*320,"s":randf_range(1.0,3.0),"a":randf(),"sp":randf_range(0.5,2.0)})
	for i in 60:
		_sparks.append({"x":240+randf_range(-10,10),"y":160+randf_range(-10,10),
			"vx":randf_range(-4,4),"vy":randf_range(-5,-0.5),"life":randf_range(0.5,2.5),"max":2.0,
			"col":[GOLD,SILV,Color("#ffffff"),Color("#ffeeaa")].pick_random(),"size":randf_range(2,6)})
func _input(ev:InputEvent)->void:
	if _ta>=1.0 and ev.is_action_pressed("ui_accept"):
		get_parent().call_deferred("_show_subject_select")
func _process(d:float)->void:
	_time+=d; _ta=minf(_ta+d*0.5,1.0); _seal_r=minf(_seal_r+d*40.0,90.0)
	_bt+=d; if _bt>=0.55: _bt=0.0; _blink=not _blink
	for i in range(_sparks.size()-1,-1,-1):
		var s:=_sparks[i]; s.x+=s.vx; s.y+=s.vy; s.vy+=0.08; s.life-=d
		if s.life<=0: _sparks.remove_at(i)
	for s in _stars: s.a=fmod(s.a+d*s.sp*0.3,1.0)
	queue_redraw()
func _draw()->void:
	const W:=480.0;const H:=320.0; var fnt:=ThemeDB.fallback_font
	draw_rect(Rect2(0,0,W,H),Color(0.08,0.06,0.02))
	for y in range(0,int(H),4):
		for x in range(0,int(W),4):
			if ((x/4+y/4)%2)==0: draw_rect(Rect2(x,y,4,4),Color(0.10,0.08,0.04,0.6))
	for s in _stars: draw_rect(Rect2(s.x,s.y,s.s,s.s),Color(1,1,0.9,s.a*_ta))
	for s in _sparks:
		var a:=clampf(s.life/s.max,0.0,1.0); draw_rect(Rect2(s.x,s.y,s.size,s.size),Color(s.col.r,s.col.g,s.col.b,a))
	if _ta>0.1:
		draw_rect(Rect2(8,8,W-16,H-16),Color(GOLD.r,GOLD.g,GOLD.b,_ta*0.5),false,3.0)
		draw_rect(Rect2(12,12,W-24,H-24),Color(GOLD.r,GOLD.g,GOLD.b,_ta*0.25),false,1.5)
	var cr:=_seal_r
	if cr>0:
		draw_arc(Vector2(W/2,H/2),cr,0,TAU,64,Color(GOLD.r,GOLD.g,GOLD.b,_ta*0.9),3.0)
		draw_arc(Vector2(W/2,H/2),cr-6.0,0,TAU,64,Color(GOLD.r,GOLD.g,GOLD.b,_ta*0.5),1.5)
		for i in 8:
			var angle:=float(i)/8.0*TAU+_time*0.2
			draw_line(Vector2(W/2+cos(angle)*(cr-12),H/2+sin(angle)*(cr-12)),
				Vector2(W/2+cos(angle)*(cr+12),H/2+sin(angle)*(cr+12)),
				Color(GOLD.r,GOLD.g,GOLD.b,_ta*0.7),2.0)
		draw_circle(Vector2(W/2,H/2),cr-10.0,Color(0.06,0.04,0.01,0.95))
		draw_string(fnt,Vector2(W/2-14,H/2+14),"K",HORIZONTAL_ALIGNMENT_LEFT,-1,44,Color(GOLD.r,GOLD.g,GOLD.b,_ta))
	if _ta>0.3:
		var ta2:=(_ta-0.3)*1.43
		draw_string(fnt,Vector2(106,46),"KAISER OF KNOWLEDGE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(0,0,0,0.6*ta2))
		draw_string(fnt,Vector2(104,44),"KAISER OF KNOWLEDGE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(GOLD.r,GOLD.g,GOLD.b,ta2))
		draw_rect(Rect2(60,52,360,2),Color(GOLD.r,GOLD.g,GOLD.b,ta2*0.6))
	if _ta>0.5:
		var ta3:=(_ta-0.5)*2.0
		var name:=GameManager.player_name.to_upper()
		draw_string(fnt,Vector2(240-len(name)*7,266),name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(SILV.r,SILV.g,SILV.b,ta3))
		draw_string(fnt,Vector2(152,284),"has restored the light of the world",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.8,0.8,0.7,ta3*0.8))
	if _ta>=1.0 and _blink:
		draw_rect(Rect2(148,298,184,16),Color(0,0,0,0.5))
		draw_string(fnt,Vector2(156,311),"Press ENTER to continue",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,1,1,0.9))
