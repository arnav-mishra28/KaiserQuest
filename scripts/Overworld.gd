# Overworld.gd v0.5 — 2.5D isometric-lite + Teacher NPC system
extends Node2D

signal show_dialog(lines:Array)
signal start_gym_battle(gym_data:Dictionary)
signal start_teacher_lesson(lesson_data:Dictionary)
signal gain_xp(amount:int, ctx:String)
signal start_duel(opponent:Dictionary)
signal back_to_world_map

# ── Tile IDs ──────────────────────────────────────────────────────────────────
const T_GRASS:=0;const T_TREE:=1;const T_HOUSE:=2;const T_DOOR:=3
const T_PATH:=4;const T_GYM:=5;const T_GDOOR:=6;const T_ITEM:=7
const T_WATER:=8;const T_SAND:=9;const T_STONE:=10;const T_FENCE:=12;const T_SIGN:=13
const TS:=32;const COLS:=15;const ROWS:=10
const WALKABLE:=[0,4,7,9,3]

# ── 2.5D Isometric-lite constants ─────────────────────────────────────────────
# Objects are drawn TALLER than the tile to fake 3D depth
const WALL_H := 20   # extra pixels for building "front face"
const TREE_H := 28   # extra height for trees

# ── World palettes (classic GB/GBC 4-tone per world) ─────────────────────────
const PALETTES := {
	"math": {
		"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),
		"path":Color("#d4c06a"),"path2":Color("#c4b058"),"water":Color("#3050b0"),
		"wall":Color("#c8c8a0"),"roof":Color("#204880"),"win":Color("#9bbc0f")
	},
	"english": {
		"g0":Color("#e8d8a0"),"g1":Color("#d8c890"),"g2":Color("#a87840"),"g3":Color("#503010"),
		"path":Color("#f0e090"),"path2":Color("#e0d080"),"water":Color("#5090c0"),
		"wall":Color("#f0e8d0"),"roof":Color("#a03818"),"win":Color("#e8d8a0")
	},
	"music": {
		"g0":Color("#281848"),"g1":Color("#201038"),"g2":Color("#100820"),"g3":Color("#080410"),
		"path":Color("#604890"),"path2":Color("#503878"),"water":Color("#102888"),
		"wall":Color("#302048"),"roof":Color("#601080"),"win":Color("#9840d0")
	},
}

# ── Map data ──────────────────────────────────────────────────────────────────
const MAPS := {
	"math":[
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
		[1,0,0,0,0,8,8,0,0,0,0,0,0,0,1],
		[1,0,2,2,0,8,8,0,2,2,0,0,0,0,1],
		[1,0,2,2,0,8,0,0,2,2,0,12,12,0,1],
		[1,0,3,0,0,0,0,0,0,3,0,12,0,0,1],
		[1,0,0,0,4,4,4,4,4,0,0,7,0,0,1],
		[1,0,0,4,0,0,0,0,0,4,0,0,0,0,1],
		[1,0,4,5,5,6,5,5,5,5,4,0,0,0,1],
		[1,0,0,4,4,4,4,4,4,4,0,0,0,0,1],
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	],
	"english":[
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
		[1,9,9,9,9,9,9,9,9,9,9,9,9,9,1],
		[1,9,2,2,9,9,9,9,9,2,2,9,9,9,1],
		[1,9,2,2,9,9,9,9,9,2,2,9,13,9,1],
		[1,9,3,9,9,9,9,9,9,9,3,9,9,9,1],
		[1,9,9,9,4,4,4,4,4,9,9,7,9,9,1],
		[1,9,9,4,9,9,9,9,9,4,9,9,9,9,1],
		[1,9,4,5,5,6,5,5,5,5,4,9,9,9,1],
		[1,9,9,4,4,4,4,4,4,4,9,9,9,9,1],
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	],
	"music":[
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
		[1,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
		[1,0,2,2,0,0,0,0,0,2,2,0,0,0,1],
		[1,0,2,2,0,0,0,10,10,2,2,0,0,0,1],
		[1,0,3,0,0,0,0,10,0,0,3,0,0,0,1],
		[1,0,0,0,4,4,4,4,4,0,0,7,0,0,1],
		[1,0,0,4,0,0,0,0,0,4,0,0,0,0,1],
		[1,0,4,5,5,6,5,5,5,5,4,0,0,0,1],
		[1,0,0,4,4,4,4,4,4,4,0,0,0,0,1],
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	],
}

# ── Teacher NPC definitions (Phase 2: NPCs teach concepts) ───────────────────
const TEACHERS := {
	"math": [
		{
			"id":"teach_var","pos":Vector2i(11,2),"shirt":Color("#204888"),
			"name":"Prof. Varius","type":"teacher",
			"subject":"Variables",
			"lesson":[
				"📖 LESSON: Variables",
				"A VARIABLE is a letter that\nrepresents an unknown value.",
				"Example:  x + 3 = 7\n\nHere, x is the variable.",
				"To solve: subtract 3 from both sides.\nx = 7 - 3  →  x = 4",
				"Remember:\n• Variables are usually letters (x, y, n)\n• They hold unknown values\n• Finding their value = solving!",
				"Tip from Prof. Varius:\n'Name the unknown, and\nyou have begun to solve it.'"
			],
			"xp":75
		},
		{
			"id":"teach_eq","pos":Vector2i(3,3),"shirt":Color("#106010"),
			"name":"Scholar Equa","type":"teacher",
			"subject":"Equations",
			"lesson":[
				"📖 LESSON: Equations",
				"An EQUATION is a mathematical\nstatement with an equals sign (=).",
				"Example:  2x + 4 = 10\n\nBoth sides must remain equal.",
				"Solving strategy:\n1. Move numbers to one side\n2. Isolate the variable\n3. Check your answer!",
				"2x + 4 = 10\n2x = 10 - 4 = 6\nx = 6 ÷ 2  →  x = 3",
				"Test: 2(3)+4 = 6+4 = 10 ✓"
			],
			"xp":75
		},
		{
			"id":"teach_fn","pos":Vector2i(1,6),"shirt":Color("#880020"),
			"name":"Elder Func","type":"teacher",
			"subject":"Functions",
			"lesson":[
				"📖 LESSON: Functions",
				"A FUNCTION maps every input\nto exactly ONE output.",
				"Written as:  f(x) = ...\nf(x) = 2x + 1",
				"If x = 3:\nf(3) = 2(3) + 1 = 7",
				"The DOMAIN is all valid inputs.\nThe RANGE is all possible outputs.",
				"Elder Func's rule:\n'One input, one output.\nThat is the law of functions.'"
			],
			"xp":75
		},
	],
	"english": [
		{
			"id":"teach_noun","pos":Vector2i(11,2),"shirt":Color("#884400"),
			"name":"Wordsmith Nora","type":"teacher",
			"subject":"Nouns",
			"lesson":[
				"📖 LESSON: Nouns",
				"A NOUN names a person, place,\nthing, or idea.",
				"Types of nouns:\n• Common: city, book, river\n• Proper: London, Bible, Nile",
				"• Collective: flock, team, class\n• Abstract: freedom, joy, love",
				"Proper nouns are ALWAYS\ncapitalized in English.",
				"Nora's tip:\n'If you can put THE before it,\nit's probably a noun!'"
			],
			"xp":75
		},
		{
			"id":"teach_verb","pos":Vector2i(3,3),"shirt":Color("#006040"),
			"name":"Scholar Verbis","type":"teacher",
			"subject":"Verbs",
			"lesson":[
				"📖 LESSON: Verbs",
				"A VERB is an action word\nor a state of being.",
				"Action verbs: run, jump, write\nLinking verbs: is, are, seems",
				"Tenses:\n• Past:    She walked.\n• Present: She walks.\n• Future:  She will walk.",
				"Irregular verbs don't follow rules:\ngo → went, see → saw",
				"Verbis's rule:\n'Every sentence MUST have\na verb. That is the law!'"
			],
			"xp":75
		},
		{
			"id":"teach_adj","pos":Vector2i(1,6),"shirt":Color("#602060"),
			"name":"Poet Adj","type":"teacher",
			"subject":"Adjectives",
			"lesson":[
				"📖 LESSON: Adjectives",
				"An ADJECTIVE describes or\nmodifies a noun.",
				"Example: 'The TALL, ANCIENT tower\nstood in the MISTY valley.'",
				"Tall, ancient, misty = adjectives\nThey describe: tower, valley",
				"Comparison:\n• big → bigger → biggest\n• good → better → best",
				"Poet Adj says:\n'Colors, sizes, feelings —\nadjectives paint your words!'"
			],
			"xp":75
		},
	],
	"music": [
		{
			"id":"teach_staff","pos":Vector2i(11,2),"shirt":Color("#601088"),
			"name":"Maestro Staffa","type":"teacher",
			"subject":"Staff & Clefs",
			"lesson":[
				"📖 LESSON: Staff & Clefs",
				"The MUSICAL STAFF has 5 lines\nand 4 spaces between them.",
				"Lines (bottom→top): E G B D F\n'Every Good Boy Does Fine'",
				"Spaces (bottom→top): F A C E\nThey spell the word FACE!",
				"The TREBLE CLEF sits on the\nstaff for higher notes.",
				"The BASS CLEF sits on the\nstaff for lower notes."
			],
			"xp":75
		},
		{
			"id":"teach_notes","pos":Vector2i(3,3),"shirt":Color("#008060"),
			"name":"Rhythm Master","type":"teacher",
			"subject":"Note Values",
			"lesson":[
				"📖 LESSON: Note Values",
				"Every note has a DURATION\n(how long it is held).",
				"Whole note    = 4 beats  (○)\nHalf note     = 2 beats  (𝅗𝅥)\nQuarter note  = 1 beat   (♩)",
				"Eighth note   = ½ beat  (♪)\nSixteenth     = ¼ beat  (𝅘𝅥𝅯)",
				"In 4/4 time:\n1 whole = 2 halves = 4 quarters\n= 8 eighths = 16 sixteenths",
				"Rhythm Master says:\n'Count the beats out loud!\n1-2-3-4, 1-2-3-4...'"
			],
			"xp":75
		},
		{
			"id":"teach_scales","pos":Vector2i(1,6),"shirt":Color("#800020"),
			"name":"Elder Harmona","type":"teacher",
			"subject":"Scales",
			"lesson":[
				"📖 LESSON: Scales",
				"A SCALE is a sequence of notes\nfollowing a specific pattern.",
				"Major scale pattern:\nW-W-H-W-W-W-H\n(W=whole step, H=half step)",
				"C Major scale:\nC D E F G A B C\n(All white keys on piano!)",
				"Minor scales sound darker/sadder.\nMajor scales sound bright/happy.",
				"Elder Harmona's wisdom:\n'A scale is a ladder.\nClimb it to find any melody.'"
			],
			"xp":75
		},
	],
}

const WORLD_NPCS := {
	"math":[
		{"id":"mq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"mq_lost_equation",
		 "lines":["I'm Equa! I lost 3 formula\nstones around Mathopolis!","Will you help me find them?"]},
		{"id":"m_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Rival Kira","accuracy":0.6,"color":Color("#ff6020")},
		 "lines":["Knowledge Duel challenge!","7 questions, 3 lives each.\nThink you can beat me?"]},
	],
	"english":[
		{"id":"eq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"eq_noun_collector",
		 "lines":["I'm Vela! I need 3 Word Scrolls\nfound around Lexicon City!","Will you collect them?"]},
		{"id":"e_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Word Rival Syl","accuracy":0.55,"color":Color("#ff9020")},
		 "lines":["A grammar duel!","Prove your language mastery!"]},
	],
	"music":[
		{"id":"muq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"muq_lost_notes",
		 "lines":["I'm Aria! 3 Musical Notes\nare lost around Harmonia!","Help me find them?"]},
		{"id":"mu_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Beat Rival Dex","accuracy":0.5,"color":Color("#ff20ff")},
		 "lines":["Music theory duel!","Let's see who hears\nthe notes more clearly!"]},
	],
}

const QUEST_ITEMS := {
	"math":   [{"id":"mstone1","pos":Vector2i(13,3)},{"id":"mstone2","pos":Vector2i(13,7)},{"id":"mstone3","pos":Vector2i(1,3)}],
	"english":[{"id":"escroll1","pos":Vector2i(13,3)},{"id":"escroll2","pos":Vector2i(13,7)},{"id":"escroll3","pos":Vector2i(1,3)}],
	"music":  [{"id":"mnote1","pos":Vector2i(13,3)},{"id":"mnote2","pos":Vector2i(13,7)},{"id":"mnote3","pos":Vector2i(1,3)}],
}
const MAIN_ITEM := {
	"math":   {"id":"math_scroll","pos":Vector2i(11,5),"xp":200,"lines":["Found an Algebra Scroll!","'Variables are the unknown\nwaiting to be named.'","+200 XP!"]},
	"english":{"id":"eng_quill","pos":Vector2i(11,5),"xp":200,"lines":["Found an Ancient Quill!","'Name the world and\nyou begin to own it.'","+200 XP!"]},
	"music":  {"id":"mus_note","pos":Vector2i(11,5),"xp":200,"lines":["Found a Resonant Note!","'Music: language the\nsoul speaks natively.'","+200 XP!"]},
}
const TOWN_NAMES := {"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP  := {"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}

# ── State ─────────────────────────────────────────────────────────────────────
var _world:String="math"
var _p_grid:Vector2i=Vector2i(7,8)
var _p_pixel:Vector2=Vector2(224,256)
var _p_dir:int=0; var _p_moving:bool=false
var _p_frame:int=0; var _anim_t:float=0.0
var _dialog:bool=false; var _cleared:bool=false
var _tween:Tween=null; var _time:float=0.0

func _ready()->void:
	add_to_group("overworld"); set_process(true); set_process_input(true)

func init_world(wid:String)->void:
	_world=wid; GameManager.active_world=wid
	var gp:=GameManager.get_grid_pos()
	gp.x=clampi(gp.x,0,COLS-1); gp.y=clampi(gp.y,0,ROWS-1)
	if _tile_at(gp) not in WALKABLE: gp=Vector2i(7,8)
	_p_grid=gp; _p_pixel=Vector2(_p_grid.x*TS,_p_grid.y*TS)
	_cleared=GameManager.has_badge(BADGE_MAP.get(wid,""))
	set_process(true); set_process_input(true)

func set_dialog_open(v:bool)->void:
	_dialog=v; if not v: set_process_input(true)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event:InputEvent)->void:
	if _dialog or _p_moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);  _p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1); _p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0); _p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);  _p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	elif event.is_action_pressed("ui_cancel"): back_to_world_map.emit(); return
	if dir!=Vector2i.ZERO: _try_move(_p_grid+dir)

func _try_move(dest:Vector2i)->void:
	var t:=_tile_at(dest)
	if t==T_GDOOR: _enter_gym(); return
	if t in WALKABLE:
		_do_move(dest)
		var item=MAIN_ITEM.get(_world,{})
		if t==T_ITEM and dest==item.get("pos",Vector2i(-1,-1)) and not GameManager.has_item(item.get("id","")):
			_collect_main_item()

func _do_move(dest:Vector2i)->void:
	_p_grid=dest; _p_moving=true; GameManager.set_grid_pos(dest)
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tween: _tween.kill()
	_tween=create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;queue_redraw(),_p_pixel,tgt,0.11)
	_tween.tween_callback(func():_p_moving=false; _check_quest())

func _check_quest()->void:
	for qi in QUEST_ITEMS.get(_world,[]):
		if _p_grid==qi.pos and not GameManager.has_item(qi.id):
			GameManager.collect_item(qi.id)
			var aq:=QuestManager.get_active_quest(_world)
			if not aq.is_empty():
				var step:=QuestManager.get_quest_step(aq)
				var steps=aq.get("steps",["..."])
				show_dialog.emit([steps[min(step,steps.size()-1)]])
				if QuestManager.all_items_collected(aq) and not GameManager.quest_done(aq.id):
					GameManager.complete_quest(aq.id); gain_xp.emit(aq.get("reward_xp",150),"quest")
					show_dialog.emit([aq.get("reward_text","Quest complete!")])
			return

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	# Check teachers first
	for t in TEACHERS.get(_world,[]):
		if t.pos==front: _talk_teacher(t); return
	# Then regular NPCs
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.pos==front: _talk_npc(npc); return
	if _tile_at(front)==T_GDOOR: _enter_gym()

func _talk_teacher(t:Dictionary)->void:
	var already:=GameManager.learned_from(t.id)
	var lines=t.lesson.duplicate()
	if not already:
		GameManager.mark_learned(t.id)
		lines.append("✓ Lesson complete!\n+"+str(t.xp)+" XP earned!\n\nThis knowledge will\nhelp you in battle!")
		show_dialog.emit(lines)
		await get_tree().create_timer(0.05).timeout
		gain_xp.emit(t.xp,"lesson")
	else:
		lines.append("(Review complete — you already\nearned XP for this lesson)")
		show_dialog.emit(lines)

func _talk_npc(npc:Dictionary)->void:
	match npc.get("type","normal"):
		"quest_giver": _talk_quest(npc)
		"duel":
			show_dialog.emit(npc.get("lines",[]))
			await get_tree().create_timer(0.1).timeout
			start_duel.emit(npc.get("opponent",{}))
		_:
			var lines=npc.get("lines",[]).duplicate()
			if not GameManager.has_talked(npc.id) and npc.get("xp",0)>0:
				GameManager.mark_talked(npc.id)
				lines.append("(+"+str(npc.xp)+" XP!)")
				show_dialog.emit(lines)
				await get_tree().create_timer(0.05).timeout
				gain_xp.emit(npc.xp,"")
			else: show_dialog.emit(lines)

func _talk_quest(npc:Dictionary)->void:
	var qid=npc.get("quest_id",""); var q:={}
	for qd in QuestManager.get_quests(_world):
		if qd.id==qid: q=qd; break
	if q.is_empty() or GameManager.quest_done(qid):
		show_dialog.emit(["Thanks again, "+GameManager.player_name+"!"]); return
	if QuestManager.all_items_collected(q) and not GameManager.quest_done(qid):
		GameManager.complete_quest(q.id); gain_xp.emit(q.get("reward_xp",150),"quest")
		show_dialog.emit([q.get("reward_text","Quest complete!")]); return
	var step:=QuestManager.get_quest_step(q)
	show_dialog.emit([q.get("steps",["..."])[min(step,q.get("steps",["..."]).size()-1)] if step>0 else npc.get("lines",["..."])[0]])

func _collect_main_item()->void:
	var item=MAIN_ITEM.get(_world,{})
	GameManager.collect_item(item.get("id","")); show_dialog.emit(item.get("lines",[]))
	gain_xp.emit(item.get("xp",0),""); queue_redraw()

func _enter_gym()->void:
	var badge=BADGE_MAP.get(_world,"")
	if _cleared: show_dialog.emit(["You already hold the "+badge+"!"]); return
	if not GameManager.can_challenge_gym(1):
		show_dialog.emit(["SEALED — Need Level 5!\nYour Level: "+str(GameManager.get_level())]); return
	# Phase 4: check teacher lesson requirement
	var teachers=TEACHERS.get(_world,[])
	var lessons_done:=0
	for t in teachers:
		if GameManager.learned_from(t.id): lessons_done+=1
	if lessons_done==0:
		show_dialog.emit(["The Gym doors won't open!","You must study with at least\n1 Teacher in town first.","Talk to the NPCs with 📖 icons\nand learn their lessons!"]); return
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db=db_map[_world]
	var data:Dictionary=db.get_gym1_leader()
	data["questions"]=db.get_gym1_questions()
	data["world"]=_world
	AdaptiveAI.start_session(_world)
	start_gym_battle.emit(data)

func _tile_at(p:Vector2i)->int:
	if p.y<0 or p.y>=ROWS or p.x<0 or p.x>=COLS: return T_TREE
	return MAPS.get(_world,MAPS.math)[p.y][p.x]
func _dv(d:int)->Vector2i:
	match d:
		0:
			return Vector2i(0, 1)
		1:
			return Vector2i(0, -1)
		2:
			return Vector2i(-1, 0)
		3:
			return Vector2i(1, 0)
	return Vector2i.ZERO

func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.20: _anim_t=0.0; _p_frame=1-_p_frame
	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
#  2.5D ISOMETRIC-LITE RENDERING ENGINE
#  Technique: tiles are flat top-down but objects have a raised "front face"
#  giving depth illusion. Inspired by Pokémon Red/Blue/Gold/Silver.
# ═══════════════════════════════════════════════════════════════════════════════
func _get_pal()->Dictionary: return PALETTES.get(_world, PALETTES.math)

func _draw()->void:
	# Draw ground layer first (back to front for depth)
	var map=MAPS.get(_world,MAPS.math)
	for r in ROWS:
		for c in COLS: _draw_ground(map[r][c],c*TS,r*TS,c,r)
	# Draw raised objects (front face visible) — back to front
	for r in ROWS:
		for c in COLS:
			if map[r][c] in [T_TREE,T_HOUSE,T_GYM,T_GDOOR,T_FENCE,T_SIGN]:
				_draw_raised(map[r][c],c*TS,r*TS,c,r)
		# Draw entities at this row depth
		_draw_entities_at_row(r)
	# UI overlay
	_draw_sparkles()
	_draw_ui_overlay()

func _draw_entities_at_row(row:int)->void:
	# Teachers
	for t in TEACHERS.get(_world,[]):
		if t.pos.y==row: _draw_npc_iso(t.pos.x*TS, t.pos.y*TS, t.shirt, "teacher", not GameManager.learned_from(t.id))
	# Regular NPCs
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.pos.y==row: _draw_npc_iso(npc.pos.x*TS, npc.pos.y*TS, npc.shirt, npc.get("type","normal"), false)
	# Player
	if _p_grid.y==row or (row==_p_grid.y and _p_moving):
		_draw_player_iso()

# ── GROUND TILES (flat top-down) ──────────────────────────────────────────────
func _draw_ground(t:int,rx:int,ry:int,c:int,r:int)->void:
	var pal:=_get_pal()
	match t:
		T_GRASS,T_ITEM,T_DOOR:
			# Gen 2 checkered grass
			draw_rect(Rect2(rx,ry,TS,TS), pal.g0)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(rx+dx,ry+dy,4,4),pal.g1)
			# Flowers/blades
			if (c*7+r*11)%8==0:
				draw_rect(Rect2(rx+5,ry+21,2,7),pal.g0.lightened(0.3))
				draw_rect(Rect2(rx+13,ry+19,2,9),pal.g0.lightened(0.25))
		T_TREE,T_HOUSE,T_GYM,T_GDOOR,T_FENCE,T_SIGN:
			# Ground under raised objects = same grass
			draw_rect(Rect2(rx,ry,TS,TS),pal.g0)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(rx+dx,ry+dy,4,4),pal.g1)
		T_PATH:
			draw_rect(Rect2(rx,ry,TS,TS),pal.path)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(rx+dx,ry+dy,4,4),pal.path2)
			# Path border
			draw_rect(Rect2(rx,ry+TS-1,TS,1),pal.g2)
		T_SAND:
			draw_rect(Rect2(rx,ry,TS,TS),Color("#e8d880"))
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(rx+dx,ry+dy,4,4),Color("#d8c870"))
		T_WATER:
			var wv:=0.4+0.6*sin(_time*1.5+(c+r)*0.4)
			draw_rect(Rect2(rx,ry,TS,TS),pal.water)
			for wy in [4,10,16,22,28]:
				var shift:=int(sin(_time*2.0+(c+r)*0.5)*2)
				draw_rect(Rect2(rx+2,ry+wy+shift,TS-4,2),pal.water.lightened(0.25)*Color(1,1,1,wv))
		T_STONE:
			draw_rect(Rect2(rx,ry,TS,TS),Color("#706868"))
			draw_rect(Rect2(rx+1,ry+1,14,14),Color("#808080")); draw_rect(Rect2(rx+17,ry+1,14,14),Color("#808080"))
			draw_rect(Rect2(rx+9,ry+17,14,14),Color("#808080"))
			draw_rect(Rect2(rx,ry,TS,TS),Color("#181010"),false,1.0)
		_:
			draw_rect(Rect2(rx,ry,TS,TS),pal.g0)

# ── RAISED OBJECTS (2.5D front face trick) ────────────────────────────────────
func _draw_raised(t:int,rx:int,ry:int,c:int,r:int)->void:
	match t:
		T_TREE:   _iso_tree(rx,ry)
		T_HOUSE:  _iso_house(rx,ry)
		T_GYM:    _iso_gym_wall(rx,ry)
		T_GDOOR:  _iso_gym_door(rx,ry)
		T_FENCE:  _iso_fence(rx,ry)
		T_SIGN:   _iso_sign(rx,ry)

# ── 2.5D TREE ─────────────────────────────────────────────────────────────────
func _iso_tree(rx:int,ry:int)->void:
	var pal=_get_pal(); var dk=pal.g3; var md=pal.g2; var lt=pal.g1; var hi=pal.g0
	# Shadow on ground
	draw_rect(Rect2(rx+4,ry+26,24,6),Color(0,0,0,0.22))
	# Trunk front face (2.5D: visible side)
	draw_rect(Rect2(rx+11,ry+18,10,TREE_H-18),md)
	draw_rect(Rect2(rx+12,ry+18,5,TREE_H-18),md.lightened(0.2))
	draw_rect(Rect2(rx+11,ry+18,10,TREE_H-18),dk,false,1.0)
	# Crown (top view + slight front)
	draw_rect(Rect2(rx+2,ry+16,28,14),dk)           # outermost shadow
	draw_rect(Rect2(rx+3,ry+10,26,18),md)            # main body
	draw_rect(Rect2(rx+6,ry+5,20,16),lt)             # inner bright
	draw_rect(Rect2(rx+9,ry+2,14,13),hi)             # top bright
	draw_rect(Rect2(rx+11,ry+2,10,7),hi.lightened(0.3)) # specular
	draw_rect(Rect2(rx+12,ry+2,6,3),Color(1,1,1,0.25)) # top gleam
	# Crown outline
	draw_rect(Rect2(rx+2,ry+10,28,18),dk,false,1.0)

# ── 2.5D HOUSE ────────────────────────────────────────────────────────────────
func _iso_house(rx:int,ry:int)->void:
	var pal:=_get_pal(); var dk:=Color("#181010")
	var wall=pal.wall; var roof=pal.roof; var win=pal.win
	# Shadow
	draw_rect(Rect2(rx+2,ry+TS-2,TS-2,WALL_H+4),Color(0,0,0,0.18))
	# Front face of house (the 2.5D wall)
	draw_rect(Rect2(rx,ry+TS-WALL_H,TS,WALL_H),wall.darkened(0.12))
	# Roof (top face — visible from above)
	draw_rect(Rect2(rx,ry,TS,TS-WALL_H),roof)
	draw_rect(Rect2(rx,ry,TS,6),roof.darkened(0.2))  # roof ridge
	draw_rect(Rect2(rx+2,ry+2,TS-4,3),roof.lightened(0.15))
	# Chimney (2.5D: shows top + front face)
	draw_rect(Rect2(rx+22,ry-5,6,TS-WALL_H+3),roof.darkened(0.3))  # chimney front
	draw_rect(Rect2(rx+21,ry-7,8,4),dk)  # chimney top
	draw_rect(Rect2(rx+22,ry-6,6,3),Color("#505050"))
	# Front wall (below roof line)
	draw_rect(Rect2(rx,ry+TS-WALL_H,TS,WALL_H),wall)
	draw_rect(Rect2(rx+TS-4,ry+TS-WALL_H,4,WALL_H),wall.darkened(0.2))  # right side shadow
	# Window on front face
	draw_rect(Rect2(rx+5,ry+TS-WALL_H+2,10,10),dk)
	draw_rect(Rect2(rx+6,ry+TS-WALL_H+3,8,8),win)
	draw_rect(Rect2(rx+9,ry+TS-WALL_H+3,1,8),dk)
	draw_rect(Rect2(rx+6,ry+TS-WALL_H+6,8,1),dk)
	draw_rect(Rect2(rx+6,ry+TS-WALL_H+3,4,3),win.lightened(0.4))  # pane shine
	draw_rect(Rect2(rx+17,ry+TS-WALL_H+2,10,10),dk)
	draw_rect(Rect2(rx+18,ry+TS-WALL_H+3,8,8),win)
	draw_rect(Rect2(rx+21,ry+TS-WALL_H+3,1,8),dk)
	draw_rect(Rect2(rx+18,ry+TS-WALL_H+6,8,1),dk)
	draw_rect(Rect2(rx+18,ry+TS-WALL_H+3,4,3),win.lightened(0.4))
	# House outline
	draw_rect(Rect2(rx,ry,TS,TS+WALL_H-TS),dk,false,1.0)
	draw_rect(Rect2(rx,ry,TS,TS),dk,false,1.0)

# ── 2.5D GYM WALL ─────────────────────────────────────────────────────────────
func _iso_gym_wall(rx:int,ry:int)->void:
	var world_cols:={"math":[Color("#1038a0"),Color("#1848c8"),Color("#4878e8"),Color("#80b0ff")],
					 "english":[Color("#703808"),Color("#984c10"),Color("#c06818"),Color("#ffc060")],
					 "music":[Color("#481078"),Color("#6018a0"),Color("#9030c0"),Color("#d068f0")]}
	var cols=world_cols.get(_world,world_cols.math)
	var dk:=Color("#181010"); var glow:=0.35+0.35*sin(_time*2.5)
	# Shadow
	draw_rect(Rect2(rx+2,ry+TS-2,TS-2,WALL_H+2),Color(0,0,0,0.2))
	# Top face (roof)
	draw_rect(Rect2(rx,ry,TS,TS-WALL_H),cols[0])
	draw_rect(Rect2(rx,ry,TS,5),cols[1].lightened(0.1))
	draw_rect(Rect2(rx+2,ry+2,TS-4,3),Color(1,1,1,0.12))
	# Front face (2.5D wall)
	draw_rect(Rect2(rx,ry+TS-WALL_H,TS,WALL_H),cols[1])
	draw_rect(Rect2(rx+TS-4,ry+TS-WALL_H,4,WALL_H),cols[0])  # shadow side
	# Pillar details
	draw_rect(Rect2(rx+5,ry+TS-WALL_H,3,WALL_H),cols[0])
	draw_rect(Rect2(rx+TS-8,ry+TS-WALL_H,3,WALL_H),cols[0])
	# Animated energy stripe
	draw_rect(Rect2(rx+4,ry+TS-4,TS-8,3),cols[3]*Color(1,1,1,glow))
	# Top mid stripe
	draw_rect(Rect2(rx,ry+TS-WALL_H-2,TS,2),cols[2])
	draw_rect(Rect2(rx,ry,TS,TS+WALL_H-TS),dk,false,1.0); draw_rect(Rect2(rx,ry,TS,TS),dk,false,1.0)

# ── 2.5D GYM DOOR ─────────────────────────────────────────────────────────────
func _iso_gym_door(rx:int,ry:int)->void:
	var world_cols:={"math":[Color("#1038a0"),Color("#1848c8"),Color("#80b0ff")],
					 "english":[Color("#703808"),Color("#c06818"),Color("#ffc060")],
					 "music":[Color("#481078"),Color("#6018a0"),Color("#d068f0")]}
	var cols=world_cols.get(_world,world_cols.math)
	var dk:=Color("#181010"); var glow:=0.5+0.5*sin(_time*3.0)
	draw_rect(Rect2(rx+2,ry+TS-2,TS-2,WALL_H+2),Color(0,0,0,0.2))
	draw_rect(Rect2(rx,ry,TS,TS-WALL_H),cols[0])
	draw_rect(Rect2(rx,ry+TS-WALL_H,TS,WALL_H),cols[1])
	# Door arch on front face
	draw_rect(Rect2(rx+6,ry+TS-WALL_H-1,20,WALL_H+1),cols[0])
	draw_rect(Rect2(rx+6,ry+TS-WALL_H-1,20,WALL_H+1),cols[2]*Color(1,1,1,glow),false,2.0)
	draw_rect(Rect2(rx+8,ry+TS-WALL_H+1,5,WALL_H-2),Color(1,1,1,0.18))
	# Glow badge above
	draw_rect(Rect2(rx+10,ry+TS-WALL_H-6,12,5),cols[2]*Color(1,1,1,glow))
	# Door knob
	draw_rect(Rect2(rx+15,ry+TS-8,4,4),cols[2]*Color(1,1,1,glow))
	draw_rect(Rect2(rx,ry,TS,TS),dk,false,1.0)

func _iso_fence(rx:int,ry:int)->void:
	var dk:=Color("#181010"); var fc:=Color("#c89040")
	draw_rect(Rect2(rx+3,ry+4,4,TS+8),fc); draw_rect(Rect2(rx+3,ry+4,4,TS+8),dk,false,1.0)
	draw_rect(Rect2(rx+25,ry+4,4,TS+8),fc); draw_rect(Rect2(rx+25,ry+4,4,TS+8),dk,false,1.0)
	draw_rect(Rect2(rx+3,ry+6,TS-6,4),fc); draw_rect(Rect2(rx+3,ry+6,TS-6,4),dk,false,1.0)
	draw_rect(Rect2(rx+3,ry+18,TS-6,4),fc); draw_rect(Rect2(rx+3,ry+18,TS-6,4),dk,false,1.0)

func _iso_sign(rx:int,ry:int)->void:
	var dk:=Color("#181010")
	draw_rect(Rect2(rx+13,ry+12,6,TS+WALL_H-10),Color("#8a5020"))
	draw_rect(Rect2(rx+13,ry+12,6,TS+WALL_H-10),dk,false,1.0)
	draw_rect(Rect2(rx+4,ry+4,24,14),Color("#c07830"))
	draw_rect(Rect2(rx+4,ry+4,24,14),Color("#e89040"),false,1.0)
	draw_rect(Rect2(rx+4,ry+4,24,14),dk,false,1.0)

# ── NPC SPRITES (2.5D depth — slightly taller) ───────────────────────────────
func _draw_npc_iso(px:int,py:int,shirt:Color,typ:String,has_lesson:bool)->void:
	var dk:=Color("#181010"); var skin:=Color("#f0c890")
	var pants:=Color("#2038a0"); var hair:=Color("#301808")
	# Shadow (isometric ground shadow)
	draw_rect(Rect2(px+5,py+30,22,5),Color(0,0,0,0.22))
	# Shoes
	draw_rect(Rect2(px+6,py+26,8,6),dk); draw_rect(Rect2(px+7,py+27,6,5),Color("#282828"))
	draw_rect(Rect2(px+18,py+26,8,6),dk); draw_rect(Rect2(px+19,py+27,6,5),Color("#282828"))
	# Legs (2.5D: show slight front face)
	draw_rect(Rect2(px+7,py+16,8,12),pants); draw_rect(Rect2(px+7,py+16,8,12),dk,false,1.0)
	draw_rect(Rect2(px+17,py+16,8,12),pants); draw_rect(Rect2(px+17,py+16,8,12),dk,false,1.0)
	draw_rect(Rect2(px+7,py+16,4,12),pants.lightened(0.12))  # leg highlight
	# Belt
	draw_rect(Rect2(px+6,py+15,20,3),Color("#503010")); draw_rect(Rect2(px+13,py+15,4,3),Color("#d0a020"))
	# Shirt body
	draw_rect(Rect2(px+5,py+8,22,9),shirt)
	draw_rect(Rect2(px+5,py+8,22,3),shirt.lightened(0.28))
	draw_rect(Rect2(px+5,py+13,22,4),shirt.darkened(0.18))
	draw_rect(Rect2(px+5,py+8,22,9),dk,false,1.0)
	# Arms
	draw_rect(Rect2(px+1,py+9,5,10),skin); draw_rect(Rect2(px+1,py+9,5,10),dk,false,1.0)
	draw_rect(Rect2(px+26,py+9,5,10),skin); draw_rect(Rect2(px+26,py+9,5,10),dk,false,1.0)
	# Neck
	draw_rect(Rect2(px+13,py+5,6,5),skin)
	# Head
	draw_rect(Rect2(px+8,py+0,16,11),skin); draw_rect(Rect2(px+8,py+0,16,11),dk,false,1.0)
	draw_rect(Rect2(px+9,py+0,14,4),skin.lightened(0.2))  # forehead
	# Hair
	draw_rect(Rect2(px+8,py+0,16,4),hair); draw_rect(Rect2(px+9,py+0,12,2),hair.lightened(0.2))
	# Eyes
	draw_rect(Rect2(px+11,py+7,3,3),dk); draw_rect(Rect2(px+18,py+7,3,3),dk)
	draw_rect(Rect2(px+12,py+7,1,2),Color(1,1,1,0.65)); draw_rect(Rect2(px+19,py+7,1,2),Color(1,1,1,0.65))
	# Type icons
	var fnt:=ThemeDB.fallback_font
	if typ=="teacher":
		var ic_col:=Color("#ffd700") if has_lesson else Color("#888888")
		draw_rect(Rect2(px+12,py-11,9,9),ic_col); draw_rect(Rect2(px+12,py-11,9,9),dk,false,1.0)
		draw_string(fnt,Vector2(px+14,py-3),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,10,dk)
	elif typ=="quest_giver":
		draw_rect(Rect2(px+12,py-11,9,9),Color("#ffd700")); draw_rect(Rect2(px+12,py-11,9,9),dk,false,1.0)
		draw_string(fnt,Vector2(px+14,py-3),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,10,dk)
	elif typ=="duel":
		draw_rect(Rect2(px+12,py-11,9,9),Color("#e03010")); draw_rect(Rect2(px+12,py-11,9,9),dk,false,1.0)
		draw_string(fnt,Vector2(px+13,py-3),"⚔",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#ffffff"))

# ── PLAYER SPRITE (2.5D Red-style) ───────────────────────────────────────────
func _draw_player_iso()->void:
	var px:=int(_p_pixel.x); var py:=int(_p_pixel.y)
	var fr:=_p_frame if _p_moving else 0
	var lo:=-3 if fr==0 else 3; var ro:=3 if fr==0 else -3
	var dk:=Color("#181010"); var skin:=Color("#f0c890")

	# Ground shadow (elongated for 2.5D look)
	draw_rect(Rect2(px+4,py+30,24,6),Color(0,0,0,0.25))
	# Shoes
	draw_rect(Rect2(px+5+lo,py+26,9,6),dk); draw_rect(Rect2(px+6+lo,py+27,7,5),Color("#282828"))
	draw_rect(Rect2(px+18+ro,py+26,9,6),dk); draw_rect(Rect2(px+19+ro,py+27,7,5),Color("#282828"))
	# Pants (2.5D: show front face)
	draw_rect(Rect2(px+6,py+16,9,12),Color("#1828a0")); draw_rect(Rect2(px+6,py+16,9,12),dk,false,1.0)
	draw_rect(Rect2(px+17,py+16,9,12),Color("#1828a0")); draw_rect(Rect2(px+17,py+16,9,12),dk,false,1.0)
	draw_rect(Rect2(px+7,py+16,5,12),Color("#2838b0"))  # highlight
	# Belt + buckle
	draw_rect(Rect2(px+5,py+15,22,3),Color("#502808")); draw_rect(Rect2(px+13,py+15,6,3),Color("#e0a010"))
	# Shirt (iconic red)
	draw_rect(Rect2(px+4,py+8,24,9),Color("#c01010"))
	draw_rect(Rect2(px+4,py+8,24,3),Color("#e01818"))
	draw_rect(Rect2(px+4,py+13,24,4),Color("#980c0c"))
	draw_rect(Rect2(px+4,py+8,24,9),dk,false,1.0)
	# Collar
	draw_rect(Rect2(px+12,py+8,8,4),Color("#e8e8e8"))
	# Arms
	draw_rect(Rect2(px+0,py+9,5,11),skin); draw_rect(Rect2(px+0,py+9,5,11),dk,false,1.0)
	draw_rect(Rect2(px+1,py+9,3,5),skin.lightened(0.15))
	draw_rect(Rect2(px+27,py+9,5,11),skin); draw_rect(Rect2(px+27,py+9,5,11),dk,false,1.0)
	draw_rect(Rect2(px+28,py+9,3,5),skin.lightened(0.15))
	# Neck
	draw_rect(Rect2(px+13,py+5,6,5),skin)
	# Head
	draw_rect(Rect2(px+7,py+0,18,11),skin); draw_rect(Rect2(px+7,py+0,18,11),dk,false,1.0)
	draw_rect(Rect2(px+8,py+0,16,4),skin.lightened(0.22))
	# Cap
	draw_rect(Rect2(px+5,py+3,22,3),Color("#c01010")); draw_rect(Rect2(px+5,py+3,22,3),dk,false,1.0)
	draw_rect(Rect2(px+6,py+0,20,5),Color("#c01010")); draw_rect(Rect2(px+6,py+0,20,5),dk,false,1.0)
	draw_rect(Rect2(px+7,py+0,16,2),Color("#e01818"))
	draw_rect(Rect2(px+14,py+1,5,4),Color("#ffd700"))  # cap badge
	draw_rect(Rect2(px+15,py+1,3,3),Color(1,1,1,0.5))
	# Direction-aware eyes
	if _p_dir==0:
		draw_rect(Rect2(px+10,py+6,4,3),dk); draw_rect(Rect2(px+18,py+6,4,3),dk)
		draw_rect(Rect2(px+11,py+6,2,2),Color(1,1,1,0.65)); draw_rect(Rect2(px+19,py+6,2,2),Color(1,1,1,0.65))
	elif _p_dir==1:
		draw_rect(Rect2(px+10,py+6,4,3),dk); draw_rect(Rect2(px+18,py+6,4,3),dk)
	elif _p_dir==2:
		draw_rect(Rect2(px+9,py+6,4,3),dk); draw_rect(Rect2(px+10,py+6,2,2),Color(1,1,1,0.55))
	elif _p_dir==3:
		draw_rect(Rect2(px+19,py+6,4,3),dk); draw_rect(Rect2(px+20,py+6,2,2),Color(1,1,1,0.55))

# ── SPARKLES ─────────────────────────────────────────────────────────────────
func _draw_sparkles()->void:
	# Main item
	var item=MAIN_ITEM.get(_world,{})
	if not item.is_empty() and not GameManager.has_item(item.get("id","")):
		var p=item.get("pos",Vector2i(-1,-1)); var rx=p.x*TS; var ry=p.y*TS
		var g=0.5+0.5*sin(_time*4.0); var col=_get_pal().g0.lightened(0.5)
		draw_rect(Rect2(rx+10,ry+8,12,14),col*Color(1,1,1,g))
		draw_rect(Rect2(rx+14,ry+2,4,7),Color(1,1,1,g))
		draw_rect(Rect2(rx+10,ry+8,12,14),Color("#181010"),false,1.0)
	# Quest items
	var aq:=QuestManager.get_active_quest(_world)
	if not aq.is_empty():
		for qi in QUEST_ITEMS.get(_world,[]):
			if GameManager.has_item(qi.id): continue
			var rx2=qi.pos.x*TS; var ry2=qi.pos.y*TS
			var g2:=0.4+0.6*sin(_time*5.0+qi.pos.x)
			draw_rect(Rect2(rx2+10,ry2+7,12,14),Color(1,0.9,0.2,g2))
			draw_rect(Rect2(rx2+14,ry2+1,4,7),Color(1,1,1,g2))

# ── UI OVERLAY ────────────────────────────────────────────────────────────────
func _draw_ui_overlay()->void:
	var fnt:=ThemeDB.fallback_font; var dk:=Color("#181010")
	# Town name box (Gen 2 style)
	draw_rect(Rect2(3,3,130,18),dk); draw_rect(Rect2(4,4,128,16),Color("#f0f0e0"))
	draw_rect(Rect2(4,4,128,6),_get_pal().g1)
	draw_string(fnt,Vector2(8,17),TOWN_NAMES.get(_world,""),HORIZONTAL_ALIGNMENT_LEFT,-1,12,dk)
	# ESC hint
	draw_rect(Rect2(330,3,148,14),dk); draw_rect(Rect2(331,4,146,12),Color("#f0f0e0",0.9))
	draw_string(fnt,Vector2(334,14),"ESC = World Map",HORIZONTAL_ALIGNMENT_LEFT,-1,10,dk)
	# Teacher progress
	var teachers=TEACHERS.get(_world,[])
	var learned:=0; for t in teachers: if GameManager.learned_from(t.id): learned+=1
	draw_rect(Rect2(3,23,130,14),dk); draw_rect(Rect2(4,24,128,12),Color("#f0f8f0",0.9))
	draw_string(fnt,Vector2(8,34),"Lessons: "+str(learned)+"/"+str(teachers.size()),
		HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#106010"))
	# Quest tracker
	var aq:=QuestManager.get_active_quest(_world)
	if not aq.is_empty() and not GameManager.quest_done(aq.id):
		var step:=QuestManager.get_quest_step(aq)
		var total=aq.get("item_ids",[]).size()
		draw_rect(Rect2(3,39,200,14),dk); draw_rect(Rect2(4,40,198,12),Color("#f8f8e8",0.9))
		draw_string(fnt,Vector2(8,50),"Quest: "+aq.get("title","")+" ("+str(step)+"/"+str(max(total,1))+")",
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#806000"))
	# Gym sign banner
	var gnames:={"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	var gcol=_get_pal().roof
	draw_rect(Rect2(130,TS*7-22,220,18),dk)
	draw_rect(Rect2(131,TS*7-21,218,16),Color("#f0f0e8"))
	draw_string(fnt,Vector2(140,TS*7-8),"★  "+gnames.get(_world,"Gym")+"  ★",
		HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)
