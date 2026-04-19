# SubjectSelectScreen.gd — Choose Subject → Branch
extends Node2D

signal subject_branch_chosen(subject: String, branch: String)

var _stage:     int    = 0   # 0=subject 1=branch
var _sel_sub:   int    = 0
var _sel_br:    int    = 0
var _chosen_sub:String = ""
var _time:      float  = 0.0
var _alpha:     float  = 0.0

var _subjects := []
var _branches := []

func _ready() -> void:
	set_process(true); set_process_input(true)
	_subjects = SubjectDB.SUBJECTS.keys()

func _process(delta: float) -> void:
	_time += delta; _alpha = minf(_alpha + delta * 1.5, 1.0); queue_redraw()

func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_left"):
		if _stage == 0: _sel_sub = (_sel_sub - 1 + _subjects.size()) % _subjects.size()
		else: _sel_br = (_sel_br - 1 + _branches.size()) % _branches.size()
	elif ev.is_action_pressed("ui_right"):
		if _stage == 0: _sel_sub = (_sel_sub + 1) % _subjects.size()
		else: _sel_br = (_sel_br + 1) % _branches.size()
	elif ev.is_action_pressed("ui_accept"):
		if _stage == 0:
			_chosen_sub = _subjects[_sel_sub]
			_branches = SubjectDB.SUBJECTS[_chosen_sub]["branches"].keys()
			_sel_br = 0; _stage = 1
		else:
			var branch = _branches[_sel_br]
			subject_branch_chosen.emit(_chosen_sub, branch)
	elif ev.is_action_pressed("ui_cancel"):
		if _stage == 1: _stage = 0

func _draw() -> void:
	const W := 480.0; const H := 320.0
	var fnt := ThemeDB.fallback_font
	var DK  := Color("#181010")

	# Background
	draw_rect(Rect2(0,0,W,H), Color("#050510"))
	for i in 20:
		var sx := float((i*53+7)%480); var sy := float((i*37+11)%200)
		draw_rect(Rect2(sx,sy,2,2), Color(1,1,1,(0.3+0.5*sin(_time*1.5+i))*_alpha*0.6))

	if _stage == 0:
		_draw_subject_select(fnt, W, H, DK)
	else:
		_draw_branch_select(fnt, W, H, DK)

func _draw_subject_select(fnt: Font, W: float, H: float, DK: Color) -> void:
	# Header
	draw_rect(Rect2(0,0,W,38), Color(0,0,0,0.65))
	draw_string(fnt, Vector2(14,26), "CHOOSE YOUR SUBJECT",
		HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#ffd700"))
	draw_string(fnt, Vector2(280,26), "← → Navigate  ENTER Select",
		HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.55,0.55,0.75))

	const CW := 142.0; const CH := 240.0; const GAP := 7.0
	var total_w := CW*3+GAP*2; var sx := (W-total_w)/2.0
	for i in _subjects.size():
		var sub = SubjectDB.SUBJECTS[_subjects[i]]
		var cx := sx + i*(CW+GAP); var cy := 44.0
		var sel := (i==_sel_sub)
		var pulse := (0.7+0.3*sin(_time*3.0)) if sel else 0.0
		var col: Color = sub["color"]

		draw_rect(Rect2(cx,cy,CW,CH), col.darkened(0.65))
		if sel: draw_rect(Rect2(cx-2,cy-2,CW+4,CH+4), col*Color(1,1,1,0.5+pulse*0.4),false,3.0)
		draw_rect(Rect2(cx,cy,CW,CH), col*Color(1,1,1,0.6+pulse*0.3),false,2.0)

		# Inner scene box
		draw_rect(Rect2(cx+4,cy+4,CW-8,100), Color(0,0,0,0.4))
		_draw_subject_scene(i, cx+4, cy+4, CW-8, 100, col)

		draw_string(fnt, Vector2(cx+8,cy+118), sub["icon"],
			HORIZONTAL_ALIGNMENT_LEFT,-1,32,col*Color(1,1,1,_alpha))
		draw_string(fnt, Vector2(cx+4,cy+148), sub["name"].to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT,CW-8,12,Color("#ffffff"))
		var dl = sub["desc"].split("\n")
		for di in dl.size():
			draw_string(fnt,Vector2(cx+4,cy+164+di*14),dl[di],
				HORIZONTAL_ALIGNMENT_LEFT,CW-8,11,Color(0.75,0.80,0.75))
		# Badge count
		var total_badges := 0
		for br in sub["branches"].keys():
			total_badges += GameManager.branch_state.get(_subjects[i]+":"+br,{}).get("badges",[]).size()
		if total_badges > 0:
			draw_string(fnt,Vector2(cx+4,cy+CH-18),"★ "+str(total_badges)+" badges",
				HORIZONTAL_ALIGNMENT_LEFT,CW-8,10,Color("#ffd700"))
		if sel: draw_rect(Rect2(cx,cy,CW,CH),col*Color(1,1,1,0.08))

	# Footer
	draw_rect(Rect2(0,H-26,W,26),Color(0,0,0,0.6))
	draw_string(fnt,Vector2(W/2-120,H-8),"Press ENTER to select "+_subjects[_sel_sub].to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#e8e8e8"))

func _draw_subject_scene(idx: int, ox: float, oy: float, w: float, h: float, col: Color) -> void:
	var fnt := ThemeDB.fallback_font
	match idx:
		0: # Math
			draw_rect(Rect2(ox,oy,w,h),Color("#0a1a3a"))
			for gx in range(0,int(w),14): draw_rect(Rect2(ox+gx,oy,1,h),Color(0.2,0.4,0.8,0.28))
			for gy in range(0,int(h),14): draw_rect(Rect2(ox,oy+gy,w,1),Color(0.2,0.4,0.8,0.28))
			draw_string(fnt,Vector2(ox+6,oy+28),"x+3=?",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#44aaff"))
			draw_string(fnt,Vector2(ox+6,oy+50),"y=2x",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#88ccff"))
		1: # Languages
			draw_rect(Rect2(ox,oy,w,h),Color("#2a1a08"))
			for bx in range(0,int(w)-12,10):
				draw_rect(Rect2(ox+bx+1,oy+h-30,8,24),Color(0.5+float(bx%30)/60,0.2,0.1))
			draw_rect(Rect2(ox,oy+h-32,w,4),Color(0.4,0.25,0.1))
			draw_string(fnt,Vector2(ox+8,oy+28),"English",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffcc44"))
			draw_string(fnt,Vector2(ox+8,oy+48),"Español",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ff8844"))
			draw_string(fnt,Vector2(ox+8,oy+68),"Français",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#4488ff"))
		2: # Music
			draw_rect(Rect2(ox,oy,w,h),Color("#180828"))
			for sl in range(5): draw_rect(Rect2(ox+4,oy+18+sl*10,w-8,1),Color(0.7,0.5,1.0,0.55))
			for np in [Vector2(8,16),Vector2(26,26),Vector2(44,21),Vector2(62,31)]:
				draw_rect(Rect2(ox+np.x,oy+np.y+12,10,8),Color("#cc44ff"))
				draw_rect(Rect2(ox+np.x+8,oy+np.y,2,13),Color("#cc44ff"))

func _draw_branch_select(fnt: Font, W: float, H: float, DK: Color) -> void:
	var sub = SubjectDB.SUBJECTS[_chosen_sub]
	var col: Color = sub["color"]

	draw_rect(Rect2(0,0,W,38),Color(0,0,0,0.65))
	draw_string(fnt,Vector2(14,26),sub["name"].to_upper()+" — CHOOSE BRANCH",
		HORIZONTAL_ALIGNMENT_LEFT,-1,16,col)
	draw_string(fnt,Vector2(330,14),"← → Nav  ENTER Select",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.55,0.55,0.75))
	draw_string(fnt,Vector2(330,26),"ESC = Back",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.55,0.55,0.75))

	var br_keys = sub["branches"].keys()
	var n = br_keys.size()
	const CW := 140.0; const CH := 220.0; const GAP := 10.0
	var total_w = CW*n + GAP*(n-1); var sx = (W-total_w)/2.0

	for i in n:
		var br = sub["branches"][br_keys[i]]
		var cx = sx + i*(CW+GAP); var cy := 50.0
		var sel = (i == _sel_br)
		var pulse := (0.7+0.3*sin(_time*3.0)) if sel else 0.0

		draw_rect(Rect2(cx,cy,CW,CH),col.darkened(0.65))
		if sel: draw_rect(Rect2(cx-2,cy-2,CW+4,CH+4),col*Color(1,1,1,0.5+pulse*0.4),false,3.0)
		draw_rect(Rect2(cx,cy,CW,CH),col*Color(1,1,1,0.6+pulse*0.3),false,2.0)

		draw_string(fnt,Vector2(cx+8,cy+30),br["icon"],HORIZONTAL_ALIGNMENT_LEFT,-1,28,col*Color(1,1,1,_alpha))
		draw_string(fnt,Vector2(cx+4,cy+66),br["name"].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,CW-8,12,Color("#ffffff"))
		draw_string(fnt,Vector2(cx+4,cy+84),br["desc"],HORIZONTAL_ALIGNMENT_LEFT,CW-8,11,Color(0.75,0.80,0.75))

		# Branch stats
		var bs = GameManager.branch_state.get(_chosen_sub+":"+br_keys[i],{})
		var lv = bs.get("level",1); var bdg = bs.get("badges",[]).size()
		draw_string(fnt,Vector2(cx+4,cy+106),"Lv."+str(lv)+"  ★"+str(bdg)+"/20",
			HORIZONTAL_ALIGNMENT_LEFT,CW-8,11,Color("#aaddff"))

		# 20 gym progress bar
		draw_rect(Rect2(cx+4,cy+124,CW-8,8),DK)
		draw_rect(Rect2(cx+5,cy+125,int((CW-10)*float(bdg)/20.0),6),col)
		draw_string(fnt,Vector2(cx+4,cy+140),"Gyms: "+str(bdg)+"/20",
			HORIZONTAL_ALIGNMENT_LEFT,CW-8,10,Color(0.7,0.7,0.9))

		if bs.get("kaiser",false):
			draw_string(fnt,Vector2(cx+4,cy+CH-18),"★ KAISER ★",
				HORIZONTAL_ALIGNMENT_LEFT,CW-8,11,Color("#ffd700"))
		if sel: draw_rect(Rect2(cx,cy,CW,CH),col*Color(1,1,1,0.08))

	draw_rect(Rect2(0,H-26,W,26),Color(0,0,0,0.6))
	draw_string(fnt,Vector2(W/2-140,H-8),"ENTER to enter "+sub["branches"][br_keys[_sel_br]]["name"],
		HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#e8e8e8"))
