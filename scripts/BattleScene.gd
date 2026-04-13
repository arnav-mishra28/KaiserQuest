# BattleScene.gd v0.5 — Full turn-based knowledge battle
# Correct answer = Attack enemy | Wrong answer = Take damage
extends Node2D

signal battle_ended(won:bool, badge_name:String, xp:int)

enum State { INTRO, QUESTION, ANIMATING, RESULT_FLASH, ENDED }

var _gym:   Dictionary = {}
var _qs:    Array      = []
var _qi:    int        = 0
var _sel:   int        = 0
var _state: int        = State.INTRO

# ── HP System ─────────────────────────────────────────────────────────────────
var _player_hp:    int = 0
var _player_max:   int = 0
var _enemy_hp:     int = 0
var _enemy_max:    int = 0
const ENEMY_BASE_HP := 20
const PLAYER_DAMAGE := 4   # damage taken on wrong answer
const ENEMY_DAMAGE  := 5   # damage dealt on correct answer

# ── Animation state ───────────────────────────────────────────────────────────
var _flash_t:    float  = 0.0
var _flash_col:  Color  = Color.TRANSPARENT
var _attack_anim:bool   = false
var _anim_t:     float  = 0.0
var _result_text:String = ""
var _explain:    String = ""
var _acols:      Array  = []
var _player_shake:float = 0.0
var _enemy_shake: float = 0.0
var _time:        float = 0.0
var _score:       int   = 0   # 0–100 score for Phase 4 threshold

# ── Gen 2/3 Battle Palette ────────────────────────────────────────────────────
const BG_TOP    := Color("#98a060")  # Gen 2 green battle bg top
const BG_BOT    := Color("#b8c880")  # lighter bottom
const BG_STRIPE := Color("#88904c")  # checker stripe
const BOX_BG    := Color("#f0f0e0")  # info box background
const BOX_DARK  := Color("#181010")  # outline
const HP_G      := Color("#58c840")
const HP_Y      := Color("#f8d810")
const HP_R      := Color("#e02020")
const HP_GRAY   := Color("#686868")
const SEL_BG    := Color("#a8d8f8")
const C_TEXT    := Color("#181010")
const C_ATCK    := Color("#f84800")  # attack flash color
const C_HIT     := Color("#f8d860")

func setup(gym_data:Dictionary)->void:
	_gym=gym_data; _qs=gym_data.get("questions",[]); _qi=0
	_sel=0; _score=0; _state=State.INTRO; _acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	# Init HPs
	_player_hp=GameManager.get_hp(); _player_max=GameManager.get_max_hp()
	_enemy_max=ENEMY_BASE_HP + GameManager.get_level()*2
	_enemy_hp=_enemy_max
	set_process(true); set_process_input(false)
	call_deferred("_show_intro")

func _show_intro()->void:
	var dlg:=get_tree().get_first_node_in_group("dialog_box")
	if dlg: dlg.show_lines(_gym.get("intro",["Ready?"]),func():
		_state=State.QUESTION; set_process_input(true))

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event:InputEvent)->void:
	if _state!=State.QUESTION: return
	var opts:=_qs[_qi].get("opts",[]) if _qi<_qs.size() else []
	if event.is_action_pressed("ui_up"):    _sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_down"):_sel=(_sel+1)%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_accept"): _submit(); get_viewport().set_input_as_handled()

# ── Answer submission ─────────────────────────────────────────────────────────
func _submit()->void:
	_state=State.ANIMATING
	set_process_input(false)
	var q:=_qs[_qi]
	var ok:=(q.ans==_sel)
	_explain=q.get("explain","")
	_result_text=("Correct!" if ok else "Wrong!")
	AdaptiveAI.record_answer(q.get("topic","general"),ok)
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	_acols[_sel]=HP_G if ok else HP_R
	if not ok: _acols[q.ans]=HP_G

	if ok:
		# Player attacks enemy
		_enemy_hp=max(0,_enemy_hp-ENEMY_DAMAGE)
		_enemy_shake=0.35
		_flash_col=Color(C_ATCK,0.3)
		_score=mini(_score+int(100.0/_qs.size()),100)
	else:
		# Enemy attacks player
		_player_hp=max(0,_player_hp-PLAYER_DAMAGE)
		_player_shake=0.35
		_flash_col=Color(HP_R,0.2)
		GameManager.take_damage(PLAYER_DAMAGE)

	_flash_t=0.0
	_state=State.RESULT_FLASH
	queue_redraw()

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta:float)->void:
	_time+=delta
	_player_shake=maxf(0.0,_player_shake-delta*4.0)
	_enemy_shake= maxf(0.0,_enemy_shake-delta*4.0)

	if _state==State.RESULT_FLASH:
		_flash_t+=delta
		if _flash_t>=1.8: _advance()
	queue_redraw()

func _advance()->void:
	_result_text=""; _explain=""; _flash_col=Color.TRANSPARENT
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	# Check win/loss conditions
	if _enemy_hp<=0: _end(true); return
	if _player_hp<=0: _end(false); return
	_qi+=1
	if _qi>=_qs.size():
		_end(_enemy_hp<_player_hp); return  # whoever has lower HP loses
	_sel=0; _state=State.QUESTION; set_process_input(true); queue_redraw()

func _end(won:bool)->void:
	_state=State.ENDED; set_process_input(false)
	GameManager.set_gym_score(_gym.get("badge_name","gym1"),_score)
	AdaptiveAI.end_session()
	var xp:=_gym.get("xp_reward",100) if won else 0
	battle_ended.emit(won,_gym.get("badge_name",""),xp)

# ═══════════════════════════════════════════════════════════════════════════════
#  GEN 2/3 TURN-BASED BATTLE DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font
	var q:=_qs[_qi] if _qi<_qs.size() else {}

	# ── Gen 2 battle background ────────────────────────────────────────────
	# Top half: battle field (green checkered)
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			var c:= BG_STRIPE if ((gx/4+gy/4)%2)==0 else BG_TOP
			draw_rect(Rect2(gx,gy,4,4),c)
	# Enemy platform (raised oval — Gen 2 style)
	draw_rect(Rect2(W-230,40,100,18),Color("#c0b878"))
	draw_rect(Rect2(W-236,42,112,14),Color("#d8d0a0"))
	draw_rect(Rect2(W-238,44,116,10),Color("#e0d8b0"))
	# Player platform
	draw_rect(Rect2(20,100,100,18),Color("#c0b878"))
	draw_rect(Rect2(14,102,112,14),Color("#d8d0a0"))
	draw_rect(Rect2(12,104,116,10),Color("#e0d8b0"))
	# Bottom half: menu area
	for gy in range(H/2,H,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4),BG_BOT if ((gx/4+gy/4)%2)==0 else Color("#a8b860"))

	# ── Enemy sprite + HP box ─────────────────────────────────────────────
	var wcol:=_gym.get("color",Color("#2040c0"))
	var ex_shake:=int(sin(_time*40)*_enemy_shake*8)
	_draw_enemy_sprite(W-200+ex_shake, 8, wcol)
	# Enemy HP box (top-left area)
	_draw_hp_box(8,8,220,_gym.get("name","???"),_enemy_hp,_enemy_max,true,fnt)

	# ── Player sprite ─────────────────────────────────────────────────────
	var px_shake:=int(sin(_time*40)*_player_shake*8)
	_draw_player_battle_sprite(50+px_shake,62)
	# Player HP box (bottom-right area)
	_draw_hp_box(W-226,H/2-64,218,GameManager.player_name,_player_hp,_player_max,false,fnt)

	# ── Menu area (bottom half) ───────────────────────────────────────────
	var menu_y:=H/2
	# Divider line
	draw_rect(Rect2(0,menu_y,W,3),BOX_DARK)

	if _state==State.QUESTION or _state==State.RESULT_FLASH or _state==State.ANIMATING:
		# Question box
		draw_rect(Rect2(4,menu_y+4,W-8,38),BOX_DARK)
		draw_rect(Rect2(5,menu_y+5,W-10,36),BOX_BG)
		draw_rect(Rect2(5,menu_y+5,W-10,10),wcol*Color(1,1,1,0.2))
		draw_string(fnt,Vector2(12,menu_y+18),q.get("q","..."),HORIZONTAL_ALIGNMENT_LEFT,W-24,13,C_TEXT)
		draw_string(fnt,Vector2(W-56,menu_y+38),"Q "+str(_qi+1)+"/"+str(_qs.size()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.4,0.5))

		# Answer options (Gen 2 menu style — 2x2 grid)
		var opts:=q.get("opts",[])
		var oy:=menu_y+46
		for i in opts.size():
			var col_x:= 4 if i%2==0 else W/2+2
			var row_y:= oy if i<2 else oy+33
			var sel:=(_state==State.QUESTION and i==_sel)
			draw_rect(Rect2(col_x,row_y,W/2-6,31),BOX_DARK)
			draw_rect(Rect2(col_x+1,row_y+1,W/2-8,29),_acols[i] if i<_acols.size() else BOX_BG)
			if sel: draw_rect(Rect2(col_x+1,row_y+1,W/2-8,29),SEL_BG)
			# Cursor ► (Gen 2 style)
			var cursor:="►" if sel else " "
			draw_string(fnt,Vector2(col_x+4,row_y+20),cursor+" "+["A","B","C","D"][i]+". "+opts[i],
				HORIZONTAL_ALIGNMENT_LEFT,W/2-12,12,C_TEXT)

	# ── Score bar ─────────────────────────────────────────────────────────
	draw_rect(Rect2(4,H-16,W-8,12),BOX_DARK)
	draw_rect(Rect2(5,H-15,W-10,10),BOX_BG)
	draw_rect(Rect2(5,H-15,int((W-10)*float(_score)/100.0),10),wcol)
	draw_string(fnt,Vector2(8,H-6),"Score: "+str(_score)+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,9,C_TEXT)
	var weak:=AdaptiveAI.get_weak_topics(_gym.get("world","math"))
	if weak.size()>0:
		draw_string(fnt,Vector2(W-160,H-6),"Weak: "+weak[0],HORIZONTAL_ALIGNMENT_LEFT,-1,9,HP_R)

	# ── Result flash overlay ──────────────────────────────────────────────
	if _state==State.RESULT_FLASH:
		draw_rect(Rect2(0,0,W,H/2),_flash_col)
		# Attack animation line (Gen 2 style slash)
		if _result_text=="Correct!" and _flash_t<0.4:
			var at:=_flash_t/0.4
			draw_rect(Rect2(int(W*0.3),int(H*0.1),int(W*0.4*at),4),C_ATCK)
			draw_rect(Rect2(int(W*0.3)+4,int(H*0.1)+4,int(W*0.35*at),4),C_HIT)
		# Result text box (Gen 2 style)
		if _flash_t>0.3:
			draw_rect(Rect2(4,H/2-50,W-8,46),BOX_DARK)
			draw_rect(Rect2(5,H/2-49,W-10,44),BOX_BG)
			var rc:=HP_G if _result_text=="Correct!" else HP_R
			draw_rect(Rect2(5,H/2-49,W-10,12),rc*Color(1,1,1,0.3))
			draw_string(fnt,Vector2(12,H/2-35),_result_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,C_TEXT)
			if _explain!="":
				var exlines:=_explain.split("\n")
				for ei in exlines.size():
					draw_string(fnt,Vector2(12,H/2-20+ei*13),exlines[ei],
						HORIZONTAL_ALIGNMENT_LEFT,W-24,11,Color(0.25,0.25,0.35))

# ── Enemy sprite ─────────────────────────────────────────────────────────────
func _draw_enemy_sprite(ox:int,oy:int,col:Color)->void:
	var dk:=Color("#181010"); var skin:=Color("#f0c890")
	# Prof. standing pose (back-to-viewer, Gen 2 enemy sprite style)
	draw_rect(Rect2(ox+5,oy+54,9,5),dk); draw_rect(Rect2(ox+22,oy+54,9,5),dk)
	draw_rect(Rect2(ox+6,oy+38,8,18),Color("#181888")); draw_rect(Rect2(ox+21,oy+38,8,18),Color("#181888"))
	draw_rect(Rect2(ox+6,oy+38,8,18),dk,false,1.0); draw_rect(Rect2(ox+21,oy+38,8,18),dk,false,1.0)
	# Lab coat (front view of enemy)
	draw_rect(Rect2(ox+4,oy+20,28,20),col.lightened(0.4))
	draw_rect(Rect2(ox+4,oy+20,28,6),Color(1,1,1,0.25))
	draw_rect(Rect2(ox+4,oy+20,28,20),dk,false,1.0)
	draw_rect(Rect2(ox+13,oy+22,10,18),Color("#e8e8e8"))
	draw_rect(Rect2(ox+16,oy+24,4,16),col)
	# Arms
	draw_rect(Rect2(ox+0,oy+21,5,14),skin); draw_rect(Rect2(ox+0,oy+21,5,14),dk,false,1.0)
	draw_rect(Rect2(ox+31,oy+21,5,14),skin); draw_rect(Rect2(ox+31,oy+21,5,14),dk,false,1.0)
	# Head
	draw_rect(Rect2(ox+9,oy+8,18,14),skin); draw_rect(Rect2(ox+9,oy+8,18,14),dk,false,1.0)
	draw_rect(Rect2(ox+10,oy+8,16,5),skin.lightened(0.2))
	# Grey hair
	draw_rect(Rect2(ox+9,oy+8,18,5),Color("#9898a0")); draw_rect(Rect2(ox+10,oy+8,14,2),Color("#b8b8c0"))
	# Glasses
	draw_rect(Rect2(ox+10,oy+16,7,5),dk,false,1.5); draw_rect(Rect2(ox+21,oy+16,7,5),dk,false,1.5)
	draw_rect(Rect2(ox+17,oy+18,4,1),dk)
	draw_rect(Rect2(ox+12,oy+17,3,3),Color("#88c8ff")); draw_rect(Rect2(ox+23,oy+17,3,3),Color("#88c8ff"))

# ── Player battle sprite (back view, Gen 2 style) ─────────────────────────────
func _draw_player_battle_sprite(ox:int,oy:int)->void:
	var dk:=Color("#181010"); var skin:=Color("#f0c890")
	draw_rect(Rect2(ox+4,oy+44,26,6),Color(0,0,0,0.2))
	draw_rect(Rect2(ox+6,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+6,oy+38,9,8),dk,false,1.0)
	draw_rect(Rect2(ox+19,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+19,oy+38,9,8),dk,false,1.0)
	draw_rect(Rect2(ox+4,oy+22,26,18),Color("#c01010"))
	draw_rect(Rect2(ox+4,oy+22,26,5),Color("#e01818"))
	draw_rect(Rect2(ox+4,oy+22,26,18),dk,false,1.0)
	draw_rect(Rect2(ox+0,oy+23,5,14),skin); draw_rect(Rect2(ox+0,oy+23,5,14),dk,false,1.0)
	draw_rect(Rect2(ox+29,oy+23,5,14),skin); draw_rect(Rect2(ox+29,oy+23,5,14),dk,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,16,16),skin); draw_rect(Rect2(ox+9,oy+8,16,16),dk,false,1.0)
	draw_rect(Rect2(ox+7,oy+8,20,6),Color("#c01010")); draw_rect(Rect2(ox+6,oy+11,22,5),Color("#c01010"))
	draw_rect(Rect2(ox+7,oy+8,20,6),dk,false,1.0)
	draw_rect(Rect2(ox+14,oy+9,5,4),Color("#ffd700"))

# ── HP Box (Gen 2 info panel) ─────────────────────────────────────────────────
func _draw_hp_box(bx:int,by:int,bw:int,name:String,hp:int,max_hp:int,is_enemy:bool,fnt:Font)->void:
	var bh:=54; var dk:=BOX_DARK
	# Box outline + fill
	draw_rect(Rect2(bx,by,bw,bh),dk)
	draw_rect(Rect2(bx+1,by+1,bw-2,bh-2),BOX_BG)
	# Header stripe
	var wcol:=_gym.get("color",Color("#2040c0"))
	draw_rect(Rect2(bx+1,by+1,bw-2,14),wcol.lightened(0.3))
	# Name
	draw_string(fnt,Vector2(bx+5,by+12),name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,C_TEXT)
	# HP label
	draw_string(fnt,Vector2(bx+5,by+27),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,11,C_TEXT)
	# HP bar (Gen 2 style with segments)
	var bar_x:=bx+24; var bar_y:=by+21; var bar_w:=bw-28; var bar_h:=8
	draw_rect(Rect2(bar_x,bar_y,bar_w,bar_h),dk)
	draw_rect(Rect2(bar_x+1,bar_y+1,bar_w-2,bar_h-2),HP_GRAY)
	var hp_f:=float(hp)/float(max_hp)
	var hcol:=HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
	draw_rect(Rect2(bar_x+1,bar_y+1,int((bar_w-2)*hp_f),bar_h-2),hcol)
	# HP numbers
	draw_string(fnt,Vector2(bx+5,by+42),str(hp)+"/"+str(max_hp),
		HORIZONTAL_ALIGNMENT_LEFT,-1,12,C_TEXT)
	if not is_enemy:
		draw_string(fnt,Vector2(bx+bw-60,by+42),"Lv."+str(GameManager.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.3,0.3,0.5))
