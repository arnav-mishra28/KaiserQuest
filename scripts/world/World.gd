# World.gd — Town / City map (15×10 tiles = 480×320 static viewport)
extends Node2D
signal change_scene(scene_name: String, data: Dictionary)

const TS:=32; const COLS:=15; const ROWS:=10
const WALKABLE:=[0,4,7,9,12]

var _world:String=""; var _player:Node2D=null; var _dialog:Node=null; var _hud:Node=null
var _time:float=0.0; var _dlg_open:bool=false

# ── Town maps (one layout, recolored per branch) ──────────────────────────────
const MAP := [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,8,8,0,0,0,0,0,0,0,0,1],
	[1,0,2,2,8,8,0,2,2,0,0,0,0,0,1],
	[1,0,2,2,8,0,0,2,2,0,11,11,0,0,1],
	[1,0,12,0,0,0,0,12,0,0,11,0,0,0,1],
	[1,0,0,0,4,4,4,4,4,4,0,7,0,0,1],
	[1,0,0,4,0,0,0,0,0,0,4,0,0,0,1],
	[1,0,4,5,5,6,5,5,5,5,4,0,0,0,1],
	[1,0,0,4,4,4,4,4,4,4,0,0,0,0,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]
# T_GRASS=0,T_TREE=1,T_HOUSE=2,T_DOOR=12,T_PATH=4,T_GYM=5,T_GDOOR=6,T_ITEM=7,T_FENCE=11,T_WATER=8,T_SAND=9

const GYM_DOOR := Vector2i(5,7)

const WORLD_NPCS := {
	"math:algebra": [
		{"id":"t1","pos":Vector2i(7,2),"type":"teacher","name":"Prof. Varius","subject":"Variables",
		 "xp":75,"shirt":Color("#2060d0"),
		 "lesson":["📖 LESSON: Variables","A variable is a letter that stands\nfor an unknown number.","x, y, n are variables.\n7, 3.14 are constants.","If x+2=5, then x=3.\n✓ Lesson complete! +75 XP"]},
		{"id":"t2","pos":Vector2i(4,8),"type":"teacher","name":"Scholar Equa","subject":"Equations",
		 "xp":75,"shirt":Color("#10a060"),
		 "lesson":["📖 LESSON: Equations","An equation says two things\nare equal.","2x+1=7 means: solve for x.\nSubtract 1: 2x=6. Divide: x=3.","✓ Lesson complete! +75 XP"]},
		{"id":"npc1","pos":Vector2i(12,3),"xp":50,"shirt":Color("#e8c030"),
		 "lines":["Welcome to this city!","Talk to ? Teachers to learn\nand gain XP!","You need Level 5 for Gym 1."]},
		{"id":"npc2","pos":Vector2i(12,5),"xp":50,"shirt":Color("#30a030"),
		 "lines":["There are 20 gyms\nin this branch!","Each gym tests your knowledge.\nGet all 20 badges!"]},
		{"id":"duel1","pos":Vector2i(12,6),"type":"duel","xp":0,"shirt":Color("#e05010"),
		 "opponent":{"name":"Rival Kira","accuracy":0.55,"world":"math:algebra"},
		 "lines":["I challenge you!\nKnowledge Duel!","7 questions. Let's go!"]},
	],
	"languages:english": [
		{"id":"et1","pos":Vector2i(7,2),"type":"teacher","name":"Wordsmith Nora","subject":"Nouns",
		 "xp":75,"shirt":Color("#c07010"),
		 "lesson":["📖 LESSON: Nouns","A noun names a person,\nplace, thing, or idea.","London, cat, freedom\nare all nouns.","Proper nouns (London)\nalways capitalised.","✓ Lesson complete! +75 XP"]},
		{"id":"et2","pos":Vector2i(4,8),"type":"teacher","name":"Scholar Verbis","subject":"Verbs",
		 "xp":75,"shirt":Color("#308840"),
		 "lesson":["📖 LESSON: Verbs","Verbs express action or state.\nRun, jump, is, seems.","Past tense of eat = ate.\nFuture = will eat.","✓ Lesson complete! +75 XP"]},
		{"id":"enpc1","pos":Vector2i(12,3),"xp":50,"shirt":Color("#e8c030"),
		 "lines":["Welcome to Lexicon City!","Words have power here.","Talk to ? Teachers first!"]},
		{"id":"eduel1","pos":Vector2i(12,6),"type":"duel","xp":0,"shirt":Color("#e05010"),
		 "opponent":{"name":"Word Rival Syl","accuracy":0.50,"world":"languages:english"},
		 "lines":["Grammar Duel!","Prove your language skills!"]},
	],
	"music:theory": [
		{"id":"mt1","pos":Vector2i(7,2),"type":"teacher","name":"Maestro Staffa","subject":"Staff",
		 "xp":75,"shirt":Color("#8020c0"),
		 "lesson":["📖 LESSON: The Staff","The musical staff has 5 lines.\nNotes sit on lines and spaces.","Spaces = F-A-C-E (bottom up).\nLines = Every Good Boy Does Fine.","Treble clef = higher notes.","✓ Lesson complete! +75 XP"]},
		{"id":"mt2","pos":Vector2i(4,8),"type":"teacher","name":"Rhythm Master","subject":"Notes",
		 "xp":75,"shirt":Color("#c04090"),
		 "lesson":["📖 LESSON: Note Values","Whole note = 4 beats.\nHalf note = 2 beats.","Quarter note = 1 beat.\nEighth note = 1/2 beat.","✓ Lesson complete! +75 XP"]},
		{"id":"mnpc1","pos":Vector2i(12,3),"xp":50,"shirt":Color("#e8c030"),
		 "lines":["Welcome to Harmonia!","Music flows through\nevery stone here.","Talk to ? Teachers!"]},
		{"id":"mduel1","pos":Vector2i(12,6),"type":"duel","xp":0,"shirt":Color("#e05010"),
		 "opponent":{"name":"Beat Rival Dex","accuracy":0.48,"world":"music:theory"},
		 "lines":["Music Theory Duel!","Let's see who hears\nthe notes more clearly!"]},
	],
}

const ITEM_POS := Vector2i(11,5)

func init_world(world_id: String, player: Node2D, dlg: Node, hud: Node) -> void:
	_world=world_id; _player=player; _dialog=dlg; _hud=hud
	if not _player.is_in_group("player"): _player.add_to_group("player")
	var gp:=GameManager.get_grid_pos()
	_player.set_grid_start(gp, _get_blocked(), COLS, ROWS)
	_player.connect("interact_at", _on_interact)
	_player.connect("player_moved", _on_moved)
	add_to_group("active_world")
	set_process(true)

func set_dialog_open(v: bool) -> void: _dlg_open=v

func _get_blocked() -> Array:
	var blocked:=[]; 
	for r in ROWS:
		for c in COLS:
			if MAP[r][c] not in WALKABLE: blocked.append(Vector2i(c,r))
	return blocked

func _on_moved(gp: Vector2i) -> void:
	GameManager.set_grid_pos(gp)
	if gp==ITEM_POS and not GameManager.has_item("branch_scroll"):
		GameManager.collect_item("branch_scroll")
		_show_dialog(["You found a Knowledge Scroll!","'The greatest journey begins\nwith a single question.'","+200 XP!"])
		GameManager.add_xp(200)
		if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(200)

func _on_interact(front: Vector2i, _facing: int) -> void:
	if front==GYM_DOOR: _try_gym(); return
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.pos==front: _talk_npc(npc); return

func _talk_npc(npc: Dictionary) -> void:
	match npc.get("type","normal"):
		"teacher": _talk_teacher(npc)
		"duel":    _talk_duel(npc)
		_:         _talk_normal(npc)

func _talk_normal(npc: Dictionary) -> void:
	var lines=npc.get("lines",[]).duplicate()
	var lvl:=AdaptiveAI.get_explanation_level(_world)
	if not GameManager.has_talked(npc.id):
		GameManager.mark_talked(npc.id)
		if lvl=="beginner": lines.append("Tip: take your time!\nEvery lesson teaches something.")
		lines.append("(+"+str(npc.xp)+" XP!)")
		_show_dialog(lines)
		await get_tree().create_timer(0.05).timeout
		GameManager.add_xp(npc.xp)
		if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(npc.xp)
	else: _show_dialog(lines)

func _talk_teacher(npc: Dictionary) -> void:
	if GameManager.has_talked(npc.id):
		_show_dialog(["You already learned from "+npc.get("name","Teacher")+"!","Review: "+npc.get("subject","")+" is important."])
		return
	GameManager.mark_talked(npc.id)
	var lesson=npc.get("lesson",[])
	_show_dialog(lesson, func():
		GameManager.add_xp(npc.xp)
		if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(npc.xp))

func _talk_duel(npc: Dictionary) -> void:
	var opp=npc.get("opponent",{"name":"Rival","accuracy":0.5,"world":_world})
	_show_dialog(npc.get("lines",[]), func():
		change_scene.emit("duel",{"world":_world,"opponent":opp}))

func _try_gym() -> void:
	var parts:=_world.split(":")
	if parts.size()<2: return
	var subject:=parts[0]; var branch:=parts[1]
	var badges:=GameManager.get_badges()
	var gym_num:=badges.size()+1
	if gym_num>20:
		_show_dialog(["You have conquered all 20 gyms!","Silver Mountain awaits!"]); return
	var leader:=SubjectDB.get_gym_leader(subject,branch,gym_num)
	var badge_name=leader.get("badge_name","Badge "+str(gym_num))
	if GameManager.has_badge(badge_name):
		_show_dialog(["You already hold "+badge_name+"!","The leader bows respectfully."]); return
	if not GameManager.can_challenge_gym(gym_num):
		_show_dialog(["The gym is sealed!","You need Level "+str(gym_num*5)+" for Gym "+str(gym_num)+".",
			"Your Level: "+str(GameManager.get_level())+"\nTalk to Teachers for XP!"]); return
	var talked:=0
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.get("type","")=="teacher" and GameManager.has_talked(npc.id): talked+=1
	if talked==0:
		_show_dialog(["The gym door is locked!","Talk to a ? Teacher first!","Every gym requires at least\none lesson first."]); return
	var qs:=SubjectDB.get_gym_questions(subject,branch,gym_num, 5+min(gym_num,7))
	leader["questions"]=qs; leader["world"]=_world
	AdaptiveAI.start_session(_world)
	change_scene.emit("battle",leader)

func _show_dialog(lines: Array, cb: Callable=Callable()) -> void:
	if _dialog and _dialog.has_method("show_lines"):
		if "context" in _dialog: _dialog.context="world"
		_dialog.show_lines(lines, cb)

func _process(delta: float) -> void: _time+=delta; queue_redraw()

func get_town_name() -> String:
	var sub_data=SubjectDB.SUBJECTS.get(GameManager.active_subject,{})
	var br_data=sub_data.get("branches",{}).get(GameManager.active_branch,{})
	return br_data.get("name","Unknown City")

const TOWN_NAMES := {}

# ── DRAWING ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_map(); _draw_item_sparkle(); _draw_gym_banner(); _draw_npcs(); _draw_ui()

func _draw_map() -> void:
	var sub_col=SubjectDB.SUBJECTS.get(GameManager.active_subject,{}).get("color",Color("#2060d0"))
	for r in ROWS:
		for c in COLS: _draw_tile(MAP[r][c],c*TS,r*TS,c,r,sub_col)

func _draw_tile(t:int,px:int,py:int,c:int,r:int,sc:Color)->void:
	var chk:=(c+r)%2==0; var DK:=Color("#181010")
	match t:
		0: # GRASS
			var g1:=sc.darkened(0.5).lerp(Color("#245218"),0.6)
			var g2:=g1.darkened(0.1)
			draw_rect(Rect2(px,py,TS,TS),g1)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),g2)
			if (c*7+r*11)%6==0: draw_rect(Rect2(px+10,py+20,2,8),g1.lightened(0.25))
		1: # TREE
			draw_rect(Rect2(px,py,TS,TS),Color("#1a4010"))
			draw_rect(Rect2(px+2,py+18,28,12),Color("#2a6018"))
			draw_rect(Rect2(px+4,py+10,24,14),Color("#1a4010").lightened(0.1))
			draw_rect(Rect2(px+8,py+4,16,12),Color("#40a028"))
			draw_rect(Rect2(px+10,py+5,8,4),Color("#40a028").lightened(0.28))
			draw_rect(Rect2(px+11,py+24,10,8),Color("#5a3210"))
			draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		2: # HOUSE
			var wall:=Color("#c8a882"); var roof:=sc.darkened(0.2)
			draw_rect(Rect2(px,py,TS,TS),wall)
			draw_rect(Rect2(px,py,TS,10),roof.darkened(0.3)); draw_rect(Rect2(px,py+4,TS,7),roof)
			draw_rect(Rect2(px+TS-4,py+10,4,TS-10),wall.darkened(0.18))
			draw_rect(Rect2(px+6,py+12,20,13),Color("#aaddff")); draw_rect(Rect2(px+6,py+12,20,13),DK,false,1.5)
			draw_rect(Rect2(px+15,py+12,2,13),DK); draw_rect(Rect2(px+6,py+17,20,2),DK)
			draw_rect(Rect2(px+22,py,5,10),roof.darkened(0.25)); draw_rect(Rect2(px+21,py,7,3),DK)
			draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		4: # PATH
			var p1:=Color("#c0b07a"); draw_rect(Rect2(px,py,TS,TS),p1 if chk else p1.darkened(0.08))
			draw_rect(Rect2(px+1,py+1,14,14),Color(0,0,0,0.06)); draw_rect(Rect2(px+17,py+1,14,14),Color(0,0,0,0.06))
			draw_rect(Rect2(px+9,py+17,14,14),Color(0,0,0,0.06))
		5: # GYM WALL
			draw_rect(Rect2(px,py,TS,TS),sc.darkened(0.4))
			draw_rect(Rect2(px,py,TS,8),sc.darkened(0.2)); draw_rect(Rect2(px+1,py+1,TS-2,4),sc.lightened(0.1)*Color(1,1,1,0.2))
			draw_rect(Rect2(px+4,py+8,2,22),sc*Color(1,1,1,0.5)); draw_rect(Rect2(px+20,py+5,2,22),sc*Color(1,1,1,0.5))
			var glow:=0.4+0.35*sin(_time*2.5); draw_rect(Rect2(px+4,py+TS-3,TS-8,2),sc*Color(1,1,1,glow))
			draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		6: # GYM DOOR
			draw_rect(Rect2(px,py,TS,TS),sc.darkened(0.4))
			draw_rect(Rect2(px+4,py+4,24,28),sc.darkened(0.1))
			draw_rect(Rect2(px+4,py+4,24,28),sc.lightened(0.3),false,2.0)
			draw_rect(Rect2(px+6,py+5,6,20),Color(1,1,1,0.22))
			var glow2:=0.6+0.4*sin(_time*3.0); draw_rect(Rect2(px+8,py+1,16,4),sc*Color(1,1,1,glow2))
			draw_rect(Rect2(px+14,py+17,4,4),Color("#ffffff")); draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		7: # ITEM (ground only; sparkle drawn separately)
			var g1b:=sc.darkened(0.5).lerp(Color("#245218"),0.6)
			draw_rect(Rect2(px,py,TS,TS),g1b)
		8: # WATER
			var wv:=0.4+0.6*sin(_time*2.0+(c+r)*0.5)
			draw_rect(Rect2(px,py,TS,TS),Color(0.08,0.25,0.75))
			for wy in [5,12,19,26]: draw_rect(Rect2(px+2,py+wy,TS-4,2),Color(0.3,0.6,1.0,wv*0.45))
		9: # SAND
			draw_rect(Rect2(px,py,TS,TS),Color("#d4b870") if chk else Color("#c4a860"))
		11: # FENCE
			var g1c:=sc.darkened(0.5).lerp(Color("#245218"),0.6)
			draw_rect(Rect2(px,py,TS,TS),g1c)
			draw_rect(Rect2(px+3,py+6,4,22),Color("#8a5020")); draw_rect(Rect2(px+25,py+6,4,22),Color("#8a5020"))
			draw_rect(Rect2(px+3,py+8,TS-6,4),Color("#a86030")); draw_rect(Rect2(px+3,py+18,TS-6,4),Color("#a86030"))
		12: # DOOR
			var g1d:=sc.darkened(0.5).lerp(Color("#245218"),0.6)
			draw_rect(Rect2(px,py,TS,TS),g1d)
			draw_rect(Rect2(px+8,py+5,16,25),Color("#5a3010")); draw_rect(Rect2(px+8,py+5,16,25),DK,false,1.0)
			draw_rect(Rect2(px+20,py+16,3,3),Color("#ffd700"))
		_: draw_rect(Rect2(px,py,TS,TS),Color("#245218"))

func _draw_item_sparkle() -> void:
	if GameManager.has_item("branch_scroll"): return
	var rx:=ITEM_POS.x*TS; var ry:=ITEM_POS.y*TS
	var g:=0.5+0.5*sin(_time*4.0)
	var sc=SubjectDB.SUBJECTS.get(GameManager.active_subject,{}).get("color",Color("#44aaff"))
	draw_rect(Rect2(rx+9,ry+8,14,15),sc*Color(1,1,1,g))
	draw_rect(Rect2(rx+12,ry+11,8,10),Color(1,1,1,g*0.6))
	draw_rect(Rect2(rx+14,ry+2,4,7),Color(1,1,1,g))
	draw_rect(Rect2(rx+10,ry+5,12,3),Color(1,1,1,g*0.5))

func _draw_gym_banner() -> void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010")
	var sub_col=SubjectDB.SUBJECTS.get(GameManager.active_subject,{}).get("color",Color("#2060d0"))
	var br_data=SubjectDB.SUBJECTS.get(GameManager.active_subject,{}).get("branches",{}).get(GameManager.active_branch,{})
	var gym_n:=GameManager.get_badges().size()+1
	var banner_text="★ "+br_data.get("name","")+" Gym "+str(min(gym_n,20))+" ★"
	draw_rect(Rect2(128,210,224,18),DK); draw_rect(Rect2(129,211,222,16),sub_col.darkened(0.3))
	draw_string(fnt,Vector2(136,224),banner_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,sub_col.lightened(0.4))

func _draw_npcs() -> void:
	var DK:=Color("#181010"); var fnt:=ThemeDB.fallback_font
	for npc in WORLD_NPCS.get(_world,[]):
		var px=npc.pos.x*TS; var py=npc.pos.y*TS
		var shirt:Color=npc.get("shirt",Color("#e8c030"))
		var typ=npc.get("type","normal")
		# Shadow
		draw_rect(Rect2(px+6,py+27,20,4),Color(0,0,0,0.2))
		# Shoes
		draw_rect(Rect2(px+7,py+26,7,5),DK); draw_rect(Rect2(px+18,py+26,7,5),DK)
		# Pants
		draw_rect(Rect2(px+8,py+17,7,11),Color("#2a4a90")); draw_rect(Rect2(px+17,py+17,7,11),Color("#2a4a90"))
		# Shirt
		draw_rect(Rect2(px+5,py+10,22,9),shirt); draw_rect(Rect2(px+5,py+10,22,3),shirt.lightened(0.22))
		draw_rect(Rect2(px+5,py+10,22,9),DK,false,1.0)
		# Arms
		for ax in [1,26]: draw_rect(Rect2(px+ax,py+11,5,9),Color("#f0c090")); draw_rect(Rect2(px+ax,py+11,5,9),DK,false,1.0)
		# Head
		draw_rect(Rect2(px+8,py+2,16,10),Color("#f0c090")); draw_rect(Rect2(px+8,py+2,16,10),DK,false,1.0)
		draw_rect(Rect2(px+8,py+2,16,4),Color("#4a2808"))
		draw_rect(Rect2(px+11,py+8,4,3),DK); draw_rect(Rect2(px+18,py+8,4,3),DK)
		# Type badges
		if typ=="teacher":
			draw_rect(Rect2(px+11,py-9,10,9),Color("#ffd700")); draw_rect(Rect2(px+11,py-9,10,9),DK,false,1.0)
			draw_string(fnt,Vector2(px+14,py-1),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
		elif typ=="duel":
			draw_rect(Rect2(px+11,py-9,10,9),Color("#e82020")); draw_rect(Rect2(px+11,py-9,10,9),DK,false,1.0)
			draw_string(fnt,Vector2(px+13,py-1),"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#ffffff"))

func _draw_ui() -> void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010"); var BG:=Color("#f8f8f0")
	var sub_data=SubjectDB.SUBJECTS.get(GameManager.active_subject,{})
	var br_data=sub_data.get("branches",{}).get(GameManager.active_branch,{})
	var town=br_data.get("name","City")
	draw_rect(Rect2(3,3,130,16),DK); draw_rect(Rect2(5,5,126,12),BG); draw_rect(Rect2(5,5,126,12),DK,false,1.5)
	draw_string(fnt,Vector2(9,15),town.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
	# ESC hint
	draw_rect(Rect2(338,3,138,16),DK); draw_rect(Rect2(340,5,134,12),BG); draw_rect(Rect2(340,5,134,12),DK,false,1.5)
	draw_string(fnt,Vector2(344,15),"ESC = Subject Menu",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
