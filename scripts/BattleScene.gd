# BattleScene.gd v0.4 — Gen 2/3 style knowledge battle
extends Node2D

signal battle_ended(won:bool, badge_name:String, xp:int)

var _gym:Dictionary={}; var _qs:Array=[]; var _qi:int=0
var _lives:int=3; var _sel:int=0; var _locked:bool=false; var _over:bool=false
var _flash_t:float=0.0; var _flash_c:Color=Color.TRANSPARENT
var _result:String=""; var _explain:String=""; var _acols:Array=[]
var _time:float=0.0

# Gen 2/3 battle palette
const OL  := Color("#181010")
const C_BG := Color("#e8f0e0")     # Gen 2 light green battle bg
const C_BG2:= Color("#d8e8d0")
const C_PANEL:=Color("#e0e8f8")    # blue-tinted panel
const C_PNL2:= Color("#c8d8f0")
const C_TEXT:= Color("#181010")    # dark text
const C_GOLD:= Color("#c07010")
const C_SEL := Color("#a8d0f8")
const C_OK  := Color("#48a848")
const C_BAD := Color("#d84030")
const C_OK2 := Color("#68c868")
const C_BAD2:= Color("#f06050")
const C_HP_G:= Color("#40c040")
const C_HP_Y:= Color("#d8c000")
const C_HP_R:= Color("#e02020")
const C_HP_BG:=Color("#888888")

func setup(gym_data:Dictionary)->void:
	_gym=gym_data; _qs=gym_data.get("questions",[]); _qi=0
	_lives=3; _sel=0; _over=false; _reset_acols()
	set_process(true); set_process_input(false); _locked=true
	call_deferred("_show_intro")

func _show_intro()->void:
	var dlg:=get_tree().get_first_node_in_group("dialog_box")
	if dlg: dlg.show_lines(_gym.get("intro",["Ready?"]),func(): _locked=false; set_process_input(true))

func _input(event:InputEvent)->void:
	if _over or _locked: return
	var opts:=_qs[_qi].get("opts",[])
	if event.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_accept"): _submit(); get_viewport().set_input_as_handled()

func _submit()->void:
	_locked=true; var q:=_qs[_qi]; var ok:=(q.ans==_sel)
	_explain=q.get("explain",""); _reset_acols()
	AdaptiveAI.record_answer(q.get("topic","general"),ok)
	if ok:
		_acols[_sel]=C_OK; _result="Correct!"
		_flash_c=Color(0.7,1.0,0.7,0.3)
	else:
		_acols[_sel]=C_BAD; _acols[q.ans]=C_OK
		_result="Wrong! Answer: "+_letters(q.ans)
		_flash_c=Color(1.0,0.6,0.6,0.3); _lives-=1
	_flash_t=1.9; queue_redraw()

func _process(delta:float)->void:
	_time+=delta
	if _flash_t>0.0:
		_flash_t-=delta
		if _flash_t<=0.0: _after()
	queue_redraw()

func _after()->void:
	_result=""; _explain=""; _flash_c=Color.TRANSPARENT; _reset_acols()
	if _lives<=0: _end(false); return
	_qi+=1
	if _qi>=_qs.size(): _end(true); return
	_sel=0; _locked=false; queue_redraw()

func _end(won:bool)->void:
	_over=true; _locked=true; set_process_input(false)
	AdaptiveAI.end_session()
	battle_ended.emit(won,_gym.get("badge_name",""),_gym.get("xp_reward",100) if won else 0)

func _reset_acols()->void: _acols=[C_PANEL,C_PANEL,C_PANEL,C_PANEL]
func _letters(i:int)->String: return ["A","B","C","D"][i] if i<4 else "?"

# ═══════════════════ GEN 2/3 DRAWING ══════════════════════════════════════════
func _draw()->void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font
	var wcol:Color=_gym.get("color",Color("#3060c0"))
	var q:=_qs[_qi] if _qi<_qs.size() else {}

	# ── Gen 2 battle background ────────────────────────────────────────────
	# Top half: leader area
	draw_rect(Rect2(0,0,W,H/2),C_BG)
	# Checkered grass pattern (Gen 2 style)
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			if ((gx/4+gy/4)%2)==0: draw_rect(Rect2(gx,gy,4,4),C_BG2)
	# Battle platform (white oval under leader — Gen 2 style)
	draw_rect(Rect2(W-180,60,160,28),Color(1,1,1,0.7))
	draw_rect(Rect2(W-184,62,168,24),Color(1,1,1,0.5),false,2.0)
	# Bottom half: player area
	draw_rect(Rect2(0,H/2,W,H/2),Color(0.88,0.92,0.88))
	draw_rect(Rect2(0,H/2,W,4),Color(0.6,0.7,0.6))

	# ── Enemy info box (top-left, Gen 2 style) ────────────────────────────
	draw_rect(Rect2(6,6,230,62),OL)
	draw_rect(Rect2(7,7,228,60),Color("#e8f0f8"))
	draw_rect(Rect2(7,7,228,14),wcol.lightened(0.3))
	draw_rect(Rect2(8,8,226,12),wcol.lightened(0.4))
	# Leader name
	draw_string(fnt,Vector2(12,19),_gym.get("name","???"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,C_TEXT)
	# Title subtitle
	draw_string(fnt,Vector2(12,32),_gym.get("title",""),HORIZONTAL_ALIGNMENT_LEFT,200,10,Color(0.3,0.3,0.4))
	# HP bar (Gen 2 style — labeled)
	draw_string(fnt,Vector2(12,46),"KP:",HORIZONTAL_ALIGNMENT_LEFT,-1,10,C_TEXT)
	var hp_f:=float(_qs.size()-_qi)/float(_qs.size())
	var hcol:=C_HP_G if hp_f>0.5 else (C_HP_Y if hp_f>0.25 else C_HP_R)
	# HP bar outline
	draw_rect(Rect2(34,40,160,8),OL)
	draw_rect(Rect2(35,41,158,6),C_HP_BG)
	draw_rect(Rect2(35,41,int(158*hp_f),6),hcol)
	# Question counter
	draw_string(fnt,Vector2(200,46),"Q"+str(_qi+1)+"/"+str(_qs.size()),
		HORIZONTAL_ALIGNMENT_LEFT,-1,10,C_TEXT)
	# Weak topic
	var weak:=AdaptiveAI.get_weak_topics(_gym.get("world","math"))
	if weak.size()>0:
		draw_string(fnt,Vector2(12,58),"Weak: "+weak[0],HORIZONTAL_ALIGNMENT_LEFT,-1,9,C_BAD)

	# ── Leader sprite (right side, Gen 2 position) ────────────────────────
	_draw_leader_sprite(W-160,10,wcol)

	# ── Question box (Gen 2 white dialog style) ───────────────────────────
	var qy:=76
	draw_rect(Rect2(4,qy,W-8,50),OL)
	draw_rect(Rect2(5,qy+1,W-10,48),Color(1,1,1,0.95))
	draw_rect(Rect2(5,qy+1,W-10,6),wcol*Color(1,1,1,0.15))
	draw_string(fnt,Vector2(12,qy+16),q.get("q","..."),HORIZONTAL_ALIGNMENT_LEFT,W-24,13,C_TEXT)
	draw_string(fnt,Vector2(W-60,qy+46),"Q."+str(_qi+1)+" / "+str(_qs.size()),
		HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.5,0.5,0.6))

	# ── Answer options (Gen 2 menu style) ─────────────────────────────────
	var ay:=132
	var opts:=q.get("opts",[])
	for i in opts.size():
		var sel:=(i==_sel and not _locked)
		var bg:=_acols[i]
		# Option box with Gen 2 border
		draw_rect(Rect2(4,ay,W-8,34),OL)
		draw_rect(Rect2(5,ay+1,W-10,32),bg)
		if sel:
			draw_rect(Rect2(5,ay+1,W-10,32),C_SEL)
			draw_rect(Rect2(5,ay+1,W-10,8),wcol*Color(1,1,1,0.2))
		# Option letter
		var lc:= C_GOLD if not sel else wcol.darkened(0.3)
		draw_string(fnt,Vector2(12,ay+21),_letters(i)+"  ",HORIZONTAL_ALIGNMENT_LEFT,-1,14,lc)
		# Option text
		draw_string(fnt,Vector2(30,ay+21),opts[i],HORIZONTAL_ALIGNMENT_LEFT,W-42,13,C_TEXT)
		# Cursor arrow (Gen 2 style ► cursor)
		if sel:
			draw_string(fnt,Vector2(W-20,ay+21),"►",HORIZONTAL_ALIGNMENT_LEFT,-1,12,wcol.darkened(0.2))
		ay+=36

	# ── Player info box (Gen 2 style, bottom-right) ────────────────────────
	var ply_x:=W/2; var ply_y:=H-58
	draw_rect(Rect2(ply_x,ply_y,W/2-4,52),OL)
	draw_rect(Rect2(ply_x+1,ply_y+1,W/2-6,50),Color(1,1,1,0.95))
	draw_rect(Rect2(ply_x+1,ply_y+1,W/2-6,12),wcol*Color(1,1,1,0.2))
	draw_string(fnt,Vector2(ply_x+6,ply_y+12),GameManager.player_name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,C_TEXT)
	# Lives as hearts
	var hearts:=""; for i in 3: hearts+="♥" if i<_lives else "♡"
	draw_string(fnt,Vector2(ply_x+6,ply_y+26),hearts,HORIZONTAL_ALIGNMENT_LEFT,-1,16,
		C_OK if _lives==3 else (C_HP_Y if _lives==2 else C_HP_R))
	# Controls hint
	draw_string(fnt,Vector2(ply_x+6,ply_y+42),"↑↓ Move  ENTER Confirm",
		HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.4,0.4,0.5))

	# ── Player battle sprite (left side) ──────────────────────────────────
	_draw_player_sprite(10,H-70)

	# ── Flash overlay ──────────────────────────────────────────────────────
	if _flash_t>0.0:
		draw_rect(Rect2(0,0,W,H),_flash_c)
		var rc:=C_OK2 if _result.begins_with("C") else C_BAD2
		# Gen 2 result box
		draw_rect(Rect2(W/2-110,H/2-26,220,54),OL)
		draw_rect(Rect2(W/2-109,H/2-25,218,52),Color(1,1,1,0.96))
		draw_rect(Rect2(W/2-109,H/2-25,218,14),rc*Color(1,1,1,0.3))
		draw_string(fnt,Vector2(W/2-80,H/2-10),_result,HORIZONTAL_ALIGNMENT_LEFT,-1,14,C_TEXT)
		if _explain!="":
			var exl:=_explain.split("\n")
			for ei in exl.size():
				draw_string(fnt,Vector2(W/2-100,H/2+10+ei*16),exl[ei],
					HORIZONTAL_ALIGNMENT_LEFT,200,11,Color(0.25,0.25,0.35))

# ── Leader sprite (Gen 2 style professor) ────────────────────────────────────
func _draw_leader_sprite(ox:int,oy:int,col:Color)->void:
	var dark:=OL; var skin:=Color("#f8d8a8")
	# Shoes
	draw_rect(Rect2(ox+5,oy+54,9,5),dark); draw_rect(Rect2(ox+22,oy+54,9,5),dark)
	draw_rect(Rect2(ox+6,oy+55,7,4),Color("#282828")); draw_rect(Rect2(ox+23,oy+55,7,4),Color("#282828"))
	# Legs
	draw_rect(Rect2(ox+7,oy+40,8,16),Color("#2038a0"))
	draw_rect(Rect2(ox+21,oy+40,8,16),Color("#2038a0"))
	draw_rect(Rect2(ox+7,oy+40,8,16),dark,false,1.0); draw_rect(Rect2(ox+21,oy+40,8,16),dark,false,1.0)
	# Lab coat
	draw_rect(Rect2(ox+4,oy+22,28,20),col.lightened(0.4))
	draw_rect(Rect2(ox+4,oy+22,28,5),Color(1,1,1,0.3))
	draw_rect(Rect2(ox+4,oy+22,28,20),dark,false,1.0)
	# Shirt/tie beneath
	draw_rect(Rect2(ox+13,oy+24,10,18),Color("#e8e8f0"))
	draw_rect(Rect2(ox+16,oy+26,4,16),col)
	# Arms
	draw_rect(Rect2(ox+0,oy+23,5,14),skin); draw_rect(Rect2(ox+0,oy+23,5,14),dark,false,1.0)
	draw_rect(Rect2(ox+31,oy+23,5,14),skin); draw_rect(Rect2(ox+31,oy+23,5,14),dark,false,1.0)
	# Head
	draw_rect(Rect2(ox+9,oy+8,18,16),skin); draw_rect(Rect2(ox+9,oy+8,18,16),dark,false,1.0)
	draw_rect(Rect2(ox+10,oy+8,16,5),Color("#fae8b8"))
	# Hair (grey)
	draw_rect(Rect2(ox+9,oy+8,18,5),Color("#909098")); draw_rect(Rect2(ox+10,oy+8,14,3),Color("#b0b0b8"))
	# Glasses
	draw_rect(Rect2(ox+10,oy+16,7,5),dark,false,1.5); draw_rect(Rect2(ox+21,oy+16,7,5),dark,false,1.5)
	draw_rect(Rect2(ox+17,oy+18,4,1),dark)
	draw_rect(Rect2(ox+12,oy+17,3,3),Color("#88ccff")); draw_rect(Rect2(ox+23,oy+17,3,3),Color("#88ccff"))

# ── Player battle sprite ──────────────────────────────────────────────────────
func _draw_player_sprite(ox:int,oy:int)->void:
	var dark:=OL; var skin:=Color("#f8d8a8")
	# Shoes
	draw_rect(Rect2(ox+4,oy+46,9,5),dark); draw_rect(Rect2(ox+19,oy+46,9,5),dark)
	draw_rect(Rect2(ox+5,oy+47,7,4),Color("#282828")); draw_rect(Rect2(ox+20,oy+47,7,4),Color("#282828"))
	# Pants
	draw_rect(Rect2(ox+5,oy+34,9,14),Color("#1838a0")); draw_rect(Rect2(ox+18,oy+34,9,14),Color("#1838a0"))
	draw_rect(Rect2(ox+5,oy+34,9,14),dark,false,1.0); draw_rect(Rect2(ox+18,oy+34,9,14),dark,false,1.0)
	# Red shirt
	draw_rect(Rect2(ox+3,oy+20,26,16),Color("#c01010"))
	draw_rect(Rect2(ox+3,oy+20,26,4),Color("#e01818"))
	draw_rect(Rect2(ox+3,oy+20,26,16),dark,false,1.0)
	# Arms
	draw_rect(Rect2(ox+0,oy+21,4,12),skin); draw_rect(Rect2(ox+0,oy+21,4,12),dark,false,1.0)
	draw_rect(Rect2(ox+28,oy+21,4,12),skin); draw_rect(Rect2(ox+28,oy+21,4,12),dark,false,1.0)
	# Head
	draw_rect(Rect2(ox+8,oy+8,16,14),skin); draw_rect(Rect2(ox+8,oy+8,16,14),dark,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,14,5),Color("#fae8b8"))
	# Red cap
	draw_rect(Rect2(ox+6,oy+8,20,5),Color("#c01010")); draw_rect(Rect2(ox+5,oy+11,22,4),Color("#c01010"))
	draw_rect(Rect2(ox+6,oy+8,20,5),dark,false,1.0)
	draw_rect(Rect2(ox+5,oy+11,22,2),dark)
	# Cap badge
	draw_rect(Rect2(ox+14,oy+9,4,3),Color("#ffd700"))
	# Eyes
	draw_rect(Rect2(ox+11,oy+15,3,3),dark); draw_rect(Rect2(ox+18,oy+15,3,3),dark)
	draw_rect(Rect2(ox+12,oy+15,1,2),Color(1,1,1,0.7)); draw_rect(Rect2(ox+19,oy+15,1,2),Color(1,1,1,0.7))
