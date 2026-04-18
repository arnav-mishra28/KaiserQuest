# BattleSystem.gd v2.0 — Authentic Pokémon Gen 1/2 battle UI
# FIGHT (answer) / HINT / SKIP menu
# HP bars, screen shake on wrong, glow on correct
extends Node2D

signal battle_ended(won: bool, badge_name: String, xp_earned: int)

enum Phase { INTRO, MENU, ANSWERING, RESULT, ENDED }

var _gym:    Dictionary = {}
var _qs:     Array      = []
var _qi:     int        = 0
var _sel:    int        = 0   # answer option selection
var _phase:  int        = Phase.INTRO

# HP (actual values)
var _p_hp:     int   = 0; var _p_max:   int   = 0
var _e_hp:     int   = 0; var _e_max:   int   = 0
# Animated HP display (lerps toward actual)
var _p_hp_d:   float = 0.0; var _e_hp_d: float = 0.0
# Combo system
var _combo:    int   = 0; var _best_combo: int = 0
const P_DMG := 6; const E_DMG := 5

# Visual effects
var _flash_t:   float = 0.0
var _flash_col: Color = Color.TRANSPARENT
var _glow_t:    float = 0.0
var _shake_t:   float = 0.0
var _shake_mag: float = 0.0
var _result:    String = ""
var _explain:   String = ""
var _acols:     Array  = []
var _score:     int    = 0
var _time:      float  = 0.0
var _avatars:   Node2D = null
var _hint_used: bool   = false
var _hint_text: String = ""
var _show_hint: bool   = false
var _dialog:    Node   = null

# Menu state: 0=FIGHT, 1=HINT, 2=SKIP — only active in MENU phase
var _menu_sel:  int  = 0
var _in_answer: bool = false  # true when FIGHT was chosen and showing options

# Gen 1/2 Color palette
const BG_LT  := Color("#e8e8d0"); const BG_DK  := Color("#d8d8c0")
const BOX_BG := Color("#f8f8f0"); const BOX_DK := Color("#181010")
const HP_G   := Color("#50d030"); const HP_Y   := Color("#f8c800"); const HP_R := Color("#e82020")
const HP_BG  := Color("#282828"); const SEL_DK := Color("#181010")
const TXT    := Color("#181010"); const TXT_W  := Color("#f8f8f0")
const GLOW_C := Color("#f8e000")

func setup(gym_data: Dictionary, dialog_node: Node) -> void:
	_gym=gym_data; _qs=gym_data.get("questions",[]); _dialog=dialog_node
	_qi=0; _sel=0; _score=0; _phase=Phase.INTRO; _menu_sel=0; _in_answer=false
	_hint_used=false; _hint_text=""; _show_hint=false
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	_p_hp=GameManager.get_hp(); _p_max=GameManager.get_max_hp()
	_p_hp_d=float(_p_hp)
	_e_max=18+GameManager.get_level()*2; _e_hp=_e_max; _e_hp_d=float(_e_max)
	_combo=0; _best_combo=0
	set_process(true); set_process_input(false)
	# Create battle avatars
	_avatars = Node2D.new()
	_avatars.set_script(load("res://scripts/battle/BattleAvatars.gd"))
	add_child(_avatars)
	_avatars.setup(gym_data.get("world","math"), gym_data.get("color",Color("#2060d0")))
	call_deferred("_start_intro")

func _start_intro() -> void:
	if _dialog and _dialog.has_method("show_lines"):
		if "context" in _dialog: _dialog.context = "battle"
		_dialog.show_lines(_gym.get("intro",["Battle start!"]), func():
			_phase=Phase.MENU; set_process_input(true))

# ── INPUT ─────────────────────────────────────────────────────────────────────
func _input(ev: InputEvent) -> void:
	match _phase:
		Phase.MENU:    _menu_input(ev)
		Phase.ANSWERING: _answer_input(ev)

# ── Returns the answer index (0-3) under a screen position, or -1 ─────────────
func _get_answer_at(pos: Vector2) -> int:
	# Answer options are only shown when _in_answer is true
	# Right panel 2×2 grid layout (matches _draw_battle_menu math):
	const W := 480; const H := 320
	var my  := H/2 + 6       # = 166
	var rw  := W/2 - 2       # = 238
	for i in 4:
		var row := i / 2; var col := i % 2
		var ox2 := W/2 + 8 + col * (rw/2 - 4)         # 250 or 365
		var oy2 := my + 14 + row * ((H - my - 8) / 2)  # 180 or 253
		var bw  := rw/2 - 8    # ≈ 111
		var bh  := (H - my - 10) / 2 - 4  # ≈ 68
		if pos.x >= ox2 and pos.x <= ox2 + bw and pos.y >= oy2 and pos.y <= oy2 + bh:
			return i
	return -1

# ── Returns the menu item (0=FIGHT,1=HINT,2=SKIP) under position, or -1 ──────
func _get_menu_at(pos: Vector2) -> int:
	const W := 480; const H := 320
	var my := H/2 + 6
	for mi in 3:
		var item_y := my + 8 + mi * 22
		if pos.x >= W/2 + 8 and pos.x <= W - 8 and pos.y >= item_y and pos.y <= item_y + 22:
			return mi
	return -1

func _menu_input(ev: InputEvent) -> void:
	if not _in_answer:
		# ── FIGHT/HINT/SKIP menu ──────────────────────────────────────────
		if ev.is_action_pressed("ui_up") or ev.is_action_pressed("ui_left"):
			_menu_sel = max(0, _menu_sel-1); queue_redraw()
		elif ev.is_action_pressed("ui_down") or ev.is_action_pressed("ui_right"):
			_menu_sel = min(2, _menu_sel+1); queue_redraw()
		elif ev.is_action_pressed("ui_accept"):
			match _menu_sel:
				0: _in_answer = true; _sel = 0; queue_redraw()
				1: _use_hint()
				2: _skip_question()
			ev.get_viewport().set_input_as_handled()
		# Mouse click on menu items
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var mi := _get_menu_at(ev.position)
			if mi >= 0:
				match mi:
					0: _in_answer = true; _sel = 0; queue_redraw()
					1: _use_hint()
					2: _skip_question()
				ev.get_viewport().set_input_as_handled()
		# Mouse hover on menu items
		elif ev is InputEventMouseMotion:
			var mi := _get_menu_at(ev.position)
			if mi >= 0 and mi != _menu_sel: _menu_sel = mi; queue_redraw()
	else:
		# ── Answer options ────────────────────────────────────────────────
		var opts := _qs[_qi].get("opts",[]) if _qi < _qs.size() else []
		if ev.is_action_pressed("ui_up"):
			_sel = (_sel - 1 + opts.size()) % opts.size(); queue_redraw()
		elif ev.is_action_pressed("ui_down"):
			_sel = (_sel + 1) % opts.size(); queue_redraw()
		elif ev.is_action_pressed("ui_accept"):
			_submit(); ev.get_viewport().set_input_as_handled()
		elif ev.is_action_pressed("ui_cancel"):
			_in_answer = false; queue_redraw()
		# ── CLICK on answer box → instant select + submit ─────────────────
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var idx := _get_answer_at(ev.position)
			if idx >= 0:
				_sel = idx; _submit()
				ev.get_viewport().set_input_as_handled()
		# ── HOVER over answer box → highlight ─────────────────────────────
		elif ev is InputEventMouseMotion:
			var idx := _get_answer_at(ev.position)
			if idx >= 0 and idx != _sel: _sel = idx; queue_redraw()

func _answer_input(_ev: InputEvent) -> void: pass

func _use_hint() -> void:
	if _hint_used:
		_hint_text="Already used hint\nthis question!"
	else:
		_hint_used=true
		var q:=_qs[_qi]; var ans:=q.ans; var opts:=q.get("opts",[])
		_hint_text="Hint: The answer\nbegins with '"+(opts[ans].substr(0,3) if opts.size()>ans else "?")+".'"
	_show_hint=true; queue_redraw()

func _skip_question() -> void:
	_hint_used=false; _show_hint=false; _hint_text=""
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	_qi+=1
	if _qi>=_qs.size(): _end(_e_hp<_p_hp); return
	_sel=0; _in_answer=false; _menu_sel=0; queue_redraw()

func _submit() -> void:
	_phase=Phase.ANSWERING; set_process_input(false)
	var q:=_qs[_qi]; var ok:=(q.ans==_sel)
	_explain=q.get("explain",""); _hint_used=false; _show_hint=false
	AdaptiveAI.record_answer(q.get("topic","general"),ok)
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	if ok:
		_acols[_sel]=HP_G
		_combo+=1; _best_combo=max(_best_combo,_combo)
		var combo_str:="" if _combo<2 else " COMBO x"+str(_combo)+"!"
		_result="It's super effective!"+combo_str
		_e_hp=max(0,_e_hp-E_DMG*(1+min(_combo-1,2)))  # combo bonus dmg
		if _avatars: _avatars.player_attack()
		await get_tree().create_timer(0.15).timeout
		if _avatars: _avatars.enemy_hurt()
		_glow_t=0.8; _score=mini(_score+int(100.0/_qs.size()),100)
		_flash_col=Color(GLOW_C,0.35)
	else:
		_acols[_sel]=HP_R; _acols[q.ans]=HP_G
		_combo=0
		_result="Not very effective..."
		_p_hp=max(0,_p_hp-P_DMG)
		_shake_t=0.5; _shake_mag=7.0
		GameManager.take_damage(P_DMG)
		_flash_col=Color(HP_R,0.22)
	_flash_t=0.0; queue_redraw()

func _process(delta: float) -> void:
	_time+=delta
	# Animate HP bars
	_p_hp_d = lerp(_p_hp_d, float(_p_hp), delta*4.0)
	_e_hp_d = lerp(_e_hp_d, float(_e_hp), delta*4.0)
	# Glow fades
	if _glow_t>0.0: _glow_t=max(0.0,_glow_t-delta)
	# Shake offset
	if _shake_t>0.0:
		_shake_t=max(0.0,_shake_t-delta)
		# Shake is handled by HUD overlay flicker, no camera here
	# Result display timer
	if _phase==Phase.ANSWERING:
		_flash_t+=delta
		if _flash_t>=2.2: _after_answer()
	queue_redraw()

func _after_answer() -> void:
	_result=""; _explain=""; _flash_col=Color.TRANSPARENT
	_acols=[BOX_BG,BOX_BG,BOX_BG,BOX_BG]
	if _e_hp<=0: _end(true); return
	if _p_hp<=0: _end(false); return
	_qi+=1
	if _qi>=_qs.size(): _end(_e_hp<_p_hp); return
	_sel=0; _in_answer=false; _menu_sel=0; _hint_used=false; _show_hint=false
	_phase=Phase.MENU; set_process_input(true); queue_redraw()

func _end(won: bool) -> void:
	_phase=Phase.ENDED; set_process_input(false)
	GameManager.set_best_score(_gym.get("badge_name","gym"),_score)
	AdaptiveAI.end_session()
	battle_ended.emit(won,_gym.get("badge_name",""),_gym.get("xp_reward",100) if won else 0)

# ══════════════════════════════════════════════════════════════════════════════
#  POKÉMON GEN 1/2 BATTLE SCREEN
# ══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	if _qs.is_empty(): return
	const W:=480; const H:=320
	var fnt:=ThemeDB.fallback_font
	var q:=_qs[_qi] if _qi<_qs.size() else {}
	var wcol:=_gym.get("color",Color("#2040c0"))

	# ── Gen 1/2 battle background ──────────────────────────────────────────
	# Top area: light grid pattern (tall grass / arena feel)
	for gy in range(0,H/2,4):
		for gx in range(0,W,4):
			draw_rect(Rect2(gx,gy,4,4), BG_DK if ((gx/4+gy/4)%2)==0 else BG_LT)
	# Dividing line
	draw_rect(Rect2(0,H/2,W,4), BOX_DK)
	# Bottom: white menu area
	draw_rect(Rect2(0,H/2+4,W,H/2-4), BOX_BG)

	# ── Battle platforms (Gen 1/2 style oval platforms) ────────────────────
	# Enemy platform (top right)
	_draw_platform(W-220, 55, 120, false)
	# Player platform (bottom left)
	_draw_platform(10, 100, 120, true)

	# ── Sprites ────────────────────────────────────────────────────────────
	# Enemy sprite (top right, facing left)
	var e_shake_x := int(randf_range(-_shake_mag,_shake_mag)*0.3) if _shake_t>0 else 0
	_draw_enemy_sprite(W-190+e_shake_x, 8, wcol)

	# Player sprite (bottom left, facing right — back view)
	var p_shake_x := int(randf_range(-_shake_mag,_shake_mag)) if _shake_t>0 else 0
	_draw_player_sprite(40+p_shake_x, 60)

	# ── Enemy HP box (top left — Gen 1/2 style) ────────────────────────────
	_draw_hp_box(6, 6, 230, _gym.get("name","???"),
		_gym.get("title",""), int(_e_hp_d), _e_max, GameManager.get_level()+2, wcol, true, fnt)

	# ── Player HP box (bottom right — Gen 1/2 style) ───────────────────────
	_draw_hp_box(W-240, H/2-62, 234, GameManager.player_name,
		"", int(_p_hp_d), _p_max, GameManager.get_level(), wcol, false, fnt)

	# ── Bottom menu (Gen 1/2 two-panel layout) ─────────────────────────────
	var my := H/2+6
	if _phase in [Phase.MENU, Phase.ANSWERING, Phase.RESULT]:
		_draw_battle_menu(my, W, H, q, fnt, wcol)

	# ── Score bar ─────────────────────────────────────────────────────────
	_draw_score_bar(H, W, fnt, wcol)

	# ── Effect overlays ───────────────────────────────────────────────────
	_draw_effects(W, H, fnt)

func _draw_platform(px:int,py:int,pw:int,is_player:bool)->void:
	# Gen 1/2 oval platform under sprites
	var pc := Color("#b0a060") if is_player else Color("#a09060")
	draw_rect(Rect2(px-8,py+12,pw+16,10), pc.darkened(0.3))
	draw_rect(Rect2(px-12,py+14,pw+24,8), pc)
	draw_rect(Rect2(px-14,py+16,pw+28,5), pc.lightened(0.15))

func _draw_hp_box(bx:int,by:int,bw:int,name:String,title:String,hp:int,max_hp:int,lv:int,wcol:Color,is_enemy:bool,fnt:Font)->void:
	var bh := 52
	# Outer border
	draw_rect(Rect2(bx,by,bw,bh), BOX_DK)
	# White fill
	draw_rect(Rect2(bx+2,by+2,bw-4,bh-4), BOX_BG)
	# Inner border
	draw_rect(Rect2(bx+2,by+2,bw-4,bh-4), BOX_DK, false, 1.5)
	# Name + level line
	draw_string(fnt, Vector2(bx+8,by+14), name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,-1,13, BOX_DK)
	draw_string(fnt, Vector2(bx+bw-52,by+14), ":Lv"+str(lv), HORIZONTAL_ALIGNMENT_LEFT,-1,12, BOX_DK)
	# HP label
	draw_string(fnt, Vector2(bx+8,by+28), "HP", HORIZONTAL_ALIGNMENT_LEFT,-1,11, BOX_DK)
	# HP bar (Gen 1 style: thick bar)
	var hp_f  := float(hp)/float(max_hp)
	var hcol  := HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
	var bar_x := bx+30; var bar_y := by+22; var bar_w := bw-38
	# Bar track (dark)
	draw_rect(Rect2(bar_x,bar_y,bar_w,8), BOX_DK)
	draw_rect(Rect2(bar_x+1,bar_y+1,bar_w-2,6), HP_BG)
	# Bar fill
	draw_rect(Rect2(bar_x+1,bar_y+1,int((bar_w-2)*hp_f),6), hcol)
	# HP numbers (only for player)
	if not is_enemy:
		draw_string(fnt, Vector2(bx+bw-80,by+43),
			str(hp)+"/"+str(max_hp), HORIZONTAL_ALIGNMENT_LEFT,-1,12, BOX_DK)
	# EXP bar (player only) — colored strip at bottom
	if not is_enemy:
		var xp_f := float(GameManager.get_xp())/float(GameManager.get_xp_max())
		draw_rect(Rect2(bx+2,by+bh-6,bw-4,4), BOX_DK)
		draw_rect(Rect2(bx+3,by+bh-5,bw-6,2), Color("#4880f0"))
		draw_rect(Rect2(bx+3,by+bh-5,int((bw-6)*xp_f),2), Color("#88c8ff"))

func _draw_battle_menu(my:int,W:int,H:int,q:Dictionary,fnt:Font,wcol:Color)->void:
	# Gen 1/2 two-panel split:
	# LEFT: text/question panel | RIGHT: 4-option menu OR FIGHT/HINT/SKIP
	var lw := W/2-2; var rw := W/2-2

	# LEFT PANEL — question text OR result
	draw_rect(Rect2(2,my,lw,H-my-4), BOX_DK)
	draw_rect(Rect2(4,my+2,lw-4,H-my-8), BOX_BG)
	draw_rect(Rect2(4,my+2,lw-4,H-my-8), BOX_DK, false, 1.5)

	if _result != "":
		# Show result + explanation
		draw_string(fnt,Vector2(10,my+18),_result.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,BOX_DK)
		if _explain != "":
			var exl:=_explain.split("\n")
			for ei in exl.size():
				draw_string(fnt,Vector2(10,my+34+ei*16),exl[ei],HORIZONTAL_ALIGNMENT_LEFT,lw-10,11,BOX_DK)
	elif _show_hint:
		var hl:=_hint_text.split("\n")
		for hi in hl.size():
			draw_string(fnt,Vector2(10,my+18+hi*16),hl[hi].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,BOX_DK)
	else:
		# Show question
		var qtext:=q.get("q","...")
		var qlines:=qtext.split("\n")
		for qi2 in qlines.size():
			draw_string(fnt,Vector2(10,my+16+qi2*16),qlines[qi2].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,lw-10,12,BOX_DK)

	# RIGHT PANEL — FIGHT/HINT/SKIP menu OR answer options
	draw_rect(Rect2(W/2+2,my,rw-4,H-my-4), BOX_DK)
	draw_rect(Rect2(W/2+4,my+2,rw-8,H-my-8), BOX_BG)
	draw_rect(Rect2(W/2+4,my+2,rw-8,H-my-8), BOX_DK, false, 1.5)

	if not _in_answer:
		# FIGHT / HINT / SKIP main menu
		var menu_items := ["FIGHT","HINT","SKIP"]
		for mi in menu_items.size():
			var item_y := my+18+mi*22
			var is_sel := (_menu_sel==mi and _phase==Phase.MENU)
			if is_sel:
				# Black cursor triangle (Gen 1 style ►)
				draw_colored_polygon(
					PackedVector2Array([Vector2(W/2+12,item_y-10),Vector2(W/2+18,item_y-5),Vector2(W/2+12,item_y)]),
					PackedColorArray([BOX_DK,BOX_DK,BOX_DK])
				)
			draw_string(fnt,Vector2(W/2+24,item_y),menu_items[mi],
				HORIZONTAL_ALIGNMENT_LEFT,-1,14,BOX_DK)
		# Score indicator
		draw_string(fnt,Vector2(W/2+10,my+H-my-18),"SCORE:"+str(_score)+"%",
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#606060"))
	else:
		# Answer options (A/B/C/D grid)
		var opts:=q.get("opts",[])
		for i in opts.size():
			var row := i/2; var col := i%2
			var ox  := W/2+8+col*(rw/2-4)
			var oy2 := my+14+row*((H-my-8)/2)
			var sel := (i==_sel and _phase==Phase.MENU)
			var bg  := _acols[i] if i<_acols.size() else BOX_BG
			# Option box
			draw_rect(Rect2(ox,oy2,rw/2-8,((H-my-10)/2)-4), BOX_DK)
			draw_rect(Rect2(ox+2,oy2+2,rw/2-12,((H-my-10)/2)-8), bg)
			if sel:
				draw_rect(Rect2(ox+2,oy2+2,rw/2-12,((H-my-10)/2)-8), wcol*Color(1,1,1,0.25))
			# Cursor
			if sel:
				draw_colored_polygon(
					PackedVector2Array([Vector2(ox+4,oy2+8),Vector2(ox+10,oy2+13),Vector2(ox+4,oy2+18)]),
					PackedColorArray([BOX_DK,BOX_DK,BOX_DK])
				)
			draw_string(fnt,Vector2(ox+14,oy2+16),["A","B","C","D"][i]+". "+opts[i],
				HORIZONTAL_ALIGNMENT_LEFT,rw/2-20,11,BOX_DK)

func _draw_score_bar(H:int,W:int,fnt:Font,wcol:Color)->void:
	# Very thin score strip at absolute bottom
	draw_rect(Rect2(0,H-4,W,4), BOX_DK)
	draw_rect(Rect2(1,H-3,W-2,2), HP_BG)
	draw_rect(Rect2(1,H-3,int((W-2)*float(_score)/100.0),2), wcol)

func _draw_effects(W:int,H:int,fnt:Font)->void:
	# Glow flash on correct answer
	if _glow_t>0.0:
		var a := _glow_t/0.8*0.45
		draw_rect(Rect2(0,0,W,H/2), Color(GLOW_C,a))
		# Starburst
		for i in 8:
			var angle := float(i)/8.0*TAU
			var length := 40.0*(1.0-_glow_t/0.8)
			draw_line(Vector2(W-160,40), Vector2(W-160+cos(angle)*length,40+sin(angle)*length),
				Color(GLOW_C,a*1.5), 3.0)

	# Red flash on wrong answer
	if _flash_t>0.0 and _flash_col.r>0.5:
		var a := maxf(0.0, 0.3-((_flash_t-0.5)*0.3))
		if a>0.0: draw_rect(Rect2(0,0,W,H), Color(HP_R,a))
		# Screen shake visual (flicker top edge)
		if _shake_t>0.0:
			for sx in range(0,W,8):
				draw_rect(Rect2(sx,0,4,3), BOX_DK*Color(1,1,1,_shake_t*2))

	# Result popup box (Gen 1 style)
	if _result!="" and _flash_t>0.4:
		pass  # Result shown in left panel above

func _draw_enemy_sprite(ox:int,oy:int,col:Color)->void:
	var DK:=BOX_DK; var SKN:=Color("#f0c890")
	draw_rect(Rect2(ox+5,oy+54,9,5),DK); draw_rect(Rect2(ox+22,oy+54,9,5),DK)
	draw_rect(Rect2(ox+6,oy+38,8,18),Color("#181888")); draw_rect(Rect2(ox+6,oy+38,8,18),DK,false,1.0)
	draw_rect(Rect2(ox+21,oy+38,8,18),Color("#181888")); draw_rect(Rect2(ox+21,oy+38,8,18),DK,false,1.0)
	draw_rect(Rect2(ox+4,oy+20,28,20),col.lightened(0.4)); draw_rect(Rect2(ox+4,oy+20,28,6),Color(1,1,1,0.25))
	draw_rect(Rect2(ox+4,oy+20,28,20),DK,false,1.0)
	draw_rect(Rect2(ox+13,oy+22,10,18),Color("#e8e8e8")); draw_rect(Rect2(ox+16,oy+24,4,16),col)
	draw_rect(Rect2(ox+0,oy+21,5,14),SKN); draw_rect(Rect2(ox+0,oy+21,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+31,oy+21,5,14),SKN); draw_rect(Rect2(ox+31,oy+21,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,18,14),SKN); draw_rect(Rect2(ox+9,oy+8,18,14),DK,false,1.0)
	draw_rect(Rect2(ox+10,oy+8,16,5),SKN.lightened(0.2))
	draw_rect(Rect2(ox+9,oy+8,18,5),Color("#9898a0"))
	draw_rect(Rect2(ox+10,oy+14,7,5),DK,false,1.5); draw_rect(Rect2(ox+21,oy+14,7,5),DK,false,1.5)
	draw_rect(Rect2(ox+17,oy+16,4,1),DK)
	draw_rect(Rect2(ox+12,oy+15,3,3),Color("#88c8ff")); draw_rect(Rect2(ox+23,oy+15,3,3),Color("#88c8ff"))

func _draw_player_sprite(ox:int,oy:int)->void:
	var DK:=BOX_DK; var SKN:=Color("#f0c890")
	draw_rect(Rect2(ox+4,oy+44,26,6),Color(0,0,0,0.2))
	draw_rect(Rect2(ox+6,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+6,oy+38,9,8),DK,false,1.0)
	draw_rect(Rect2(ox+19,oy+38,9,8),Color("#181888")); draw_rect(Rect2(ox+19,oy+38,9,8),DK,false,1.0)
	draw_rect(Rect2(ox+4,oy+22,26,18),Color("#c01010"))
	draw_rect(Rect2(ox+4,oy+22,26,5),Color("#e01818")); draw_rect(Rect2(ox+4,oy+22,26,18),DK,false,1.0)
	draw_rect(Rect2(ox+0,oy+23,5,14),SKN); draw_rect(Rect2(ox+0,oy+23,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+29,oy+23,5,14),SKN); draw_rect(Rect2(ox+29,oy+23,5,14),DK,false,1.0)
	draw_rect(Rect2(ox+9,oy+8,16,16),SKN); draw_rect(Rect2(ox+9,oy+8,16,16),DK,false,1.0)
	draw_rect(Rect2(ox+7,oy+8,20,6),Color("#c01010")); draw_rect(Rect2(ox+6,oy+11,22,5),Color("#c01010"))
	draw_rect(Rect2(ox+7,oy+8,20,6),DK,false,1.0); draw_rect(Rect2(ox+14,oy+9,5,4),Color("#ffd700"))
	draw_rect(Rect2(ox+11,oy+15,3,3),DK); draw_rect(Rect2(ox+18,oy+15,3,3),DK)
	draw_rect(Rect2(ox+12,oy+15,1,2),Color(1,1,1,0.65)); draw_rect(Rect2(ox+19,oy+15,1,2),Color(1,1,1,0.65))
