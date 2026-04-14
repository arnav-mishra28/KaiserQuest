# BattleSystem.gd v1.0 — Full turn-based HP battle
extends Node2D

signal battle_ended(won:bool, badge_name:String, xp_earned:int)

enum Phase { INTRO, QUESTION, ANIMATING, RESULT, ENDED }

var _gym:   Dictionary = {}
var _qs:    Array      = []
var _qi:    int        = 0
var _sel:   int        = 0
var _phase: int        = Phase.INTRO

var _player_hp:  int   = 0
var _player_max: int   = 0
var _enemy_hp:   int   = 0
var _enemy_max:  int   = 0
const PLAYER_DMG := 5
const ENEMY_DMG  := 6

var _flash_t:     float = 0.0
var _flash_col:   Color = Color.TRANSPARENT
var _result_text: String = ""
var _explain:     String = ""
var _acols:       Array  = []
var _p_shake:     float  = 0.0
var _e_shake:     float  = 0.0
var _score:       int    = 0
var _time:        float  = 0.0
var _dialog:      Node   = null

# ── Gen 2 Battle Palette ──────────────────────────────────────────────────────
const BG_TOP    := Color("#98a060")
const BG_STRIPE := Color("#88904c")
const BG_BOT    := Color("#b8c880")
const BOX_BG    := Color("#f0f0e0")
const BOX_DK    := Color("#181010")
const HP_G      := Color("#48c840")
const HP_Y      := Color("#f8d010")
const HP_R      := Color("#e02020")
const HP_GRAY   := Color("#686868")
const SEL_BG    := Color("#a8d8f8")
const C_ATK     := Color("#f84800")
const C_OK      := Color("#48c840")
const C_BAD     := Color("#e02020")

func setup(gym_data:Dictionary, dialog_node:Node)->void:
	_gym       = gym_data
	_qs        = gym_data.get("questions",[])
	_dialog    = dialog_node
	_qi        = 0
	_sel       = 0
	_score     = 0
	_phase     = Phase.INTRO
	_acols     = [BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	_player_hp  = GameManager.get_hp()
	_player_max = GameManager.get_max_hp()
	_enemy_max  = 20 + GameManager.get_level()*2
	_enemy_hp   = _enemy_max
	set_process(true)
	set_process_input(false)
	call_deferred("_start_intro")

func _start_intro()->void:
	if _dialog:
		_dialog.show_lines(_gym.get("intro",["Ready to battle!"]),func():
			_phase = Phase.QUESTION; set_process_input(true))

func _input(event:InputEvent)->void:
	if _phase != Phase.QUESTION: return
	var opts = _qs[_qi].get("opts",[]) if _qi<_qs.size() else []
	if event.is_action_pressed("ui_up"):
		_sel=(_sel-1+opts.size())%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_down"):
		_sel=(_sel+1)%opts.size(); queue_redraw()
	elif event.is_action_pressed("ui_accept"):
		_submit(); get_viewport().set_input_as_handled()

func _submit()->void:
	_phase = Phase.ANIMATING; set_process_input(false)
	var q  = _qs[_qi]
	var ok = (q.ans == _sel)
	_explain = q.get("explain","")
	AdaptiveAI.record_answer(q.get("topic","general"), ok)
	_acols = [BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	_acols[_sel] = HP_G if ok else HP_R
	if not ok: _acols[q.ans] = HP_G

	if ok:
		_result_text = "Correct!  You attack!"
		_enemy_hp    = max(0, _enemy_hp - ENEMY_DMG)
		_e_shake     = 0.4
		_flash_col   = Color(C_ATK, 0.25)
		_score       = mini(_score + int(100.0/_qs.size()), 100)
	else:
		_result_text = "Wrong!  Take damage!"
		_player_hp   = max(0, _player_hp - PLAYER_DMG)
		_p_shake     = 0.4
		_flash_col   = Color(HP_R, 0.2)
		GameManager.take_damage(PLAYER_DMG)

	_flash_t = 0.0
	_phase   = Phase.RESULT
	queue_redraw()

func _process(delta:float)->void:
	_time   += delta
	_p_shake = maxf(0.0, _p_shake - delta*4.0)
	_e_shake = maxf(0.0, _e_shake - delta*4.0)

	if _phase == Phase.RESULT:
		_flash_t += delta
		if _flash_t >= 2.0: _advance()
	queue_redraw()

func _advance()->void:
	_result_text = ""; _explain = ""; _flash_col = Color.TRANSPARENT
	_acols = [BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	if _enemy_hp <= 0: _end(true); return
	if _player_hp <= 0: _end(false); return
	_qi += 1
	if _qi >= _qs.size(): _end(_enemy_hp < _player_hp); return
	_sel = 0; _phase = Phase.QUESTION; set_process_input(true); queue_redraw()

func _end(won:bool)->void:
	_phase = Phase.ENDED; set_process_input(false)
	GameManager.set_best_score(_gym.get("badge_name","gym"), _score)
	AdaptiveAI.end_session()
	battle_ended.emit(won, _gym.get("badge_name",""), _gym.get("xp_reward",100) if won else 0)

# ═══════════════════════════════════════════════════════════════════════════════
#  GEN 2 BATTLE SCREEN DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt := ThemeDB.fallback_font
	var q   = _qs[_qi] if _qi < _qs.size() else {}
	var wcol= _gym.get("color", Color("#2040c0"))

	# ── Gen 2 battle background ────────────────────────────────────────────
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG_STRIPE if ((gx/4+gy/4)%2)==0 else BG_TOP)
	for gy in range(H/2,H,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG_BOT if ((gx/4+gy/4)%2)==0 else Color("#a8b860"))

	# Platforms (Gen 2 oval battle platforms)
	_draw_platform(W-220, 62, 120)
	_draw_platform(10,   110,  120)
	draw_rect(Rect2(0,H/2,W,3), BOX_DK)

	# ── Sprites ───────────────────────────────────────────────────────────
	var esh := int(sin(_time*40)*_e_shake*8)
	var psh := int(sin(_time*40)*_p_shake*8)
	_draw_enemy_sprite(W-210+esh, 8, wcol)
	_draw_player_battle(40+psh, 62)

	# ── Enemy HP box ──────────────────────────────────────────────────────
	_draw_hp_box(6, 6, 240, _gym.get("name","???"), _enemy_hp, _enemy_max, wcol, true, fnt)
	# ── Player HP box ─────────────────────────────────────────────────────
	_draw_hp_box(W-246, H/2-62, 240, GameManager.player_name, _player_hp, _player_max, wcol, false, fnt)

	# ── Question ──────────────────────────────────────────────────────────
	var menu_y := H/2 + 4
	if _phase in [Phase.QUESTION, Phase.ANIMATING, Phase.RESULT]:
		draw_rect(Rect2(4,menu_y,W-8,40), BOX_DK)
		draw_rect(Rect2(5,menu_y+1,W-10,38), BOX_BG)
		draw_rect(Rect2(5,menu_y+1,W-10,10), wcol*Color(1,1,1,0.18))
		draw_string(fnt,Vector2(12,menu_y+14), q.get("q","..."), HORIZONTAL_ALIGNMENT_LEFT,W-24,13,BOX_DK)
		draw_string(fnt,Vector2(W-56,menu_y+38),"Q "+str(_qi+1)+"/"+str(_qs.size()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.4,0.5))

		# Options 2×2 grid (Gen 2 style)
		var opts = q.get("opts",[])
		var ay   := menu_y + 46
		for i in opts.size():
			var col_x := 4         if i%2==0 else W/2+2
			var row_y := ay        if i<2    else ay+34
			var sel   = (_phase==Phase.QUESTION and i==_sel)
			draw_rect(Rect2(col_x, row_y, W/2-6, 32), BOX_DK)
			draw_rect(Rect2(col_x+1,row_y+1,W/2-8,30), _acols[i] if i<_acols.size() else BOX_BG)
			if sel: draw_rect(Rect2(col_x+1,row_y+1,W/2-8,30), SEL_BG)
			var cursor := "►" if sel else " "
			draw_string(fnt,Vector2(col_x+5,row_y+21),
				cursor+" "+["A","B","C","D"][i]+". "+opts[i],
				HORIZONTAL_ALIGNMENT_LEFT,W/2-12,12,BOX_DK)

	# Score bar
	draw_rect(Rect2(4,H-14,W-8,10), BOX_DK)
	draw_rect(Rect2(5,H-13,W-10,8), BOX_BG)
	draw_rect(Rect2(5,H-13,int((W-10)*float(_score)/100.0),8), wcol)
	draw_string(fnt,Vector2(8,H-4),"Score: "+str(_score)+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,9,BOX_DK)
	var weak := AdaptiveAI.get_weak_topics(_gym.get("world","math"))
	if weak.size()>0:
		draw_string(fnt,Vector2(W-160,H-4),"Weak: "+weak[0],HORIZONTAL_ALIGNMENT_LEFT,-1,9,HP_R)

	# ── Flash overlay ─────────────────────────────────────────────────────
	if _phase == Phase.RESULT:
		draw_rect(Rect2(0,0,W,H/2), _flash_col)
		# Attack slash (Gen 2 style)
		if _result_text.begins_with("Correct") and _flash_t < 0.5:
			var at := _flash_t/0.5
			draw_rect(Rect2(int(W*0.25),int(H*0.08),int(W*0.45*at),5), C_ATK)
			draw_rect(Rect2(int(W*0.28),int(H*0.12),int(W*0.4*at),4),  Color("#f8d860"))
		# Result box
		if _flash_t > 0.35:
			draw_rect(Rect2(4,H/2-54,W-8,50), BOX_DK)
			draw_rect(Rect2(5,H/2-53,W-10,48), BOX_BG)
			var rc := C_OK if _result_text.begins_with("Correct") else C_BAD
			draw_rect(Rect2(5,H/2-53,W-10,14), rc*Color(1,1,1,0.3))
			draw_string(fnt,Vector2(12,H/2-37), _result_text, HORIZONTAL_ALIGNMENT_LEFT,-1,14,BOX_DK)
			if _explain != "":
				var exl := _explain.split("\n")
				for ei in exl.size():
					draw_string(fnt,Vector2(12,H/2-20+ei*13),exl[ei],HORIZONTAL_ALIGNMENT_LEFT,W-24,11,Color(0.25,0.25,0.35))

func _draw_platform(px:int,py:int,pw:int)->void:
	draw_rect(Rect2(px-10,py+12,pw+20,18), Color("#c0b878"))
	draw_rect(Rect2(px-14,py+14,pw+28,14), Color("#d8d0a0"))
	draw_rect(Rect2(px-16,py+16,pw+32,10), Color("#e0d8b0"))

func _draw_hp_box(bx:int,by:int,bw:int,name:String,hp:int,max_hp:int,wcol:Color,is_enemy:bool,fnt:Font)->void:
	var bh := 52
	draw_rect(Rect2(bx,by,bw,bh),       BOX_DK)
	draw_rect(Rect2(bx+1,by+1,bw-2,bh-2),BOX_BG)
	draw_rect(Rect2(bx+1,by+1,bw-2,14), wcol.lightened(0.3))
	draw_string(fnt,Vector2(bx+5,by+13), name, HORIZONTAL_ALIGNMENT_LEFT,-1,12, BOX_DK)
	# HP bar
	draw_string(fnt,Vector2(bx+5,by+28),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,11,BOX_DK)
	var hp_f  := float(hp)/float(max_hp)
	var hcol  := HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
	var bar_x := bx+24; var bar_y := by+22; var bar_w := bw-28
	draw_rect(Rect2(bar_x,bar_y,bar_w,8), BOX_DK)
	draw_rect(Rect2(bar_x+1,bar_y+1,bar_w-2,6), HP_GRAY)
	draw_rect(Rect2(bar_x+1,bar_y+1,int((bar_w-2)*hp_f),6), hcol)
	draw_string(fnt,Vector2(bx+5,by+42), str(hp)+"/"+str(max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,12,BOX_DK)
	if not is_enemy:
		draw_string(fnt,Vector2(bx+bw-62,by+42),"Lv."+str(GameManager.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.3,0.3,0.5))

func _draw_enemy_sprite(ox:int,oy:int,col:Color)->void:
	var DK := BOX_DK; var SKN := Color("#f0c890")
	draw_rect(Rect2(ox+5,oy+54,9,5),DK); draw_rect(Rect2(ox+22,oy+54,9,5),DK)
	draw_rect(Rect2(ox+6,oy+38,8,18),Color("#181888")); draw_rect(Rect2(ox+6,oy+38,8,18),DK,false,1.0)
	draw_rect(Rect2(ox+21,oy+38,8,18),Color("#181888")); draw_rect(Rect2(ox+21,oy+38,8,18),DK,false,1.0)
	draw_rect(Rect2(ox+4,oy+20,28,20),col.lightened(0.4))
	draw_rect(Rect2(ox+4,oy+20,28,6),Color(1,1,1,0.25))
	draw_rect(Rect2(ox+4,oy+20,28,20),DK,false,1.0)
	draw_rect(Rect2(ox+13,oy+22,10,18),Color("#e8e8e8"))
	draw_rect(Rect2(ox+16,oy+24,4,16),col)
	draw_rect(Rect2(ox+0,oy+21,5,14),SKN); draw_rect(Rect2(ox+0,oy+21,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+31,oy+21,5,14),SKN); draw_rect(Rect2(ox+31,oy+21,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,18,14),SKN); draw_rect(Rect2(ox+9,oy+8,18,14),DK,false,1.0)
	draw_rect(Rect2(ox+10,oy+8,16,5),SKN.lightened(0.2))
	draw_rect(Rect2(ox+9,oy+8,18,5),Color("#9898a0"))
	draw_rect(Rect2(ox+10,oy+14,7,5),DK,false,1.5); draw_rect(Rect2(ox+21,oy+14,7,5),DK,false,1.5)
	draw_rect(Rect2(ox+17,oy+16,4,1),DK)
	draw_rect(Rect2(ox+12,oy+15,3,3),Color("#88c8ff")); draw_rect(Rect2(ox+23,oy+15,3,3),Color("#88c8ff"))

func _draw_player_battle(ox:int,oy:int)->void:
	var DK := BOX_DK; var SKN := Color("#f0c890")
	draw_rect(Rect2(ox+4,oy+44,26,6),Color(0,0,0,0.2))
	draw_rect(Rect2(ox+6,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+6,oy+38,9,8),DK,false,1.0)
	draw_rect(Rect2(ox+19,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+19,oy+38,9,8),DK,false,1.0)
	draw_rect(Rect2(ox+4,oy+22,26,18),Color("#c01010"))
	draw_rect(Rect2(ox+4,oy+22,26,5),Color("#e01818"))
	draw_rect(Rect2(ox+4,oy+22,26,18),DK,false,1.0)
	draw_rect(Rect2(ox+0,oy+23,5,14),SKN); draw_rect(Rect2(ox+0,oy+23,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+29,oy+23,5,14),SKN); draw_rect(Rect2(ox+29,oy+23,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,16,16),SKN); draw_rect(Rect2(ox+9,oy+8,16,16),DK,false,1.0)
	draw_rect(Rect2(ox+7,oy+8,20,6),Color("#c01010")); draw_rect(Rect2(ox+6,oy+11,22,5),Color("#c01010"))
	draw_rect(Rect2(ox+7,oy+8,20,6),DK,false,1.0); draw_rect(Rect2(ox+14,oy+9,5,4),Color("#ffd700"))
	draw_rect(Rect2(ox+11,oy+15,3,3),DK); draw_rect(Rect2(ox+18,oy+15,3,3),DK)
	draw_rect(Rect2(ox+12,oy+15,1,2),Color(1,1,1,0.65)); draw_rect(Rect2(ox+19,oy+15,1,2),Color(1,1,1,0.65))
