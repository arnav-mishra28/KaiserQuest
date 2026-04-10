# Overworld.gd v0.4 — Gen 2 quality pixel art + bug fixes
extends Node2D

signal show_dialog(lines:Array)
signal start_gym_battle(gym_data:Dictionary)
signal gain_xp(amount:int, ctx:String)
signal start_duel(opponent:Dictionary)
signal back_to_world_map

# ── Tile IDs ──────────────────────────────────────────────────────────────────
const T_GRASS:=0;const T_TREE:=1;const T_HOUSE:=2;const T_DOOR:=3
const T_PATH:=4;const T_GYM:=5;const T_GDOOR:=6;const T_ITEM:=7
const T_WATER:=8;const T_SAND:=9;const T_STONE:=10;const T_FENCE:=12;const T_SIGN:=13
const TS:=32;const COLS:=15;const ROWS:=10
const WALKABLE:=[0,4,7,9,3]

# ── Gen 2/3 Color Palette ─────────────────────────────────────────────────────
# Grass
const G1 := Color("#68b840");const G2 := Color("#58a830")
const G3 := Color("#487828");const G4 := Color("#80d048")
const G5 := Color("#98e060")
# Tree
const TR0 := Color("#0c2808");const TR1 := Color("#1c4810")
const TR2 := Color("#306820");const TR3 := Color("#50a030")
const TR4 := Color("#70c040");const TR5 := Color("#90d858")
const TRK := Color("#6a4010");const TRK2:= Color("#8a5820")
# Path / Sand
const P1 := Color("#e8d060");const P2 := Color("#d8c050")
const P3 := Color("#c0a038");const P4 := Color("#f0dc80")
# Water
const W1 := Color("#2040a8");const W2 := Color("#3858c0")
const W3 := Color("#5880d8");const W4 := Color("#88b0f0")
const W5 := Color("#b8d8ff")
# Buildings
const HW := Color("#e8dcc0");const HW2:= Color("#d0c4a8")
const HR := Color("#c84018");const HR2:= Color("#a83010")
const HW3:= Color("#b0a888");const WIN:= Color("#88ccff")
const WIN2:=Color("#a8dcff");const DR := Color("#784010")
const DR2 := Color("#9a5818")
# Gym colors per world
const GM_MATH  := [Color("#1038a8"),Color("#1848c8"),Color("#3060e0"),Color("#60a0ff"),Color("#88c0ff")]
const GM_ENG   := [Color("#703808"),Color("#984c10"),Color("#c06818"),Color("#e89030"),Color("#ffc060")]
const GM_MUS   := [Color("#481078"),Color("#601898"),Color("#8028b8"),Color("#b050e0"),Color("#d888ff")]
# Outline / border
const OL := Color("#181010")
const OL2:= Color("#302010")
# Stone / rock
const ST1:= Color("#706868");const ST2:= Color("#908080");const ST3:= Color("#504848")
# Fence
const FN1:= Color("#c89040");const FN2:= Color("#b07830")

const MAPS:={
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

const WORLD_NPCS:={
	"math":[
		{"id":"m1","pos":Vector2i(7,5),"color":Color("#e8c030"),"shirt":Color("#e8c030"),"xp":50,
		 "lines":["That towering Citadel\nahead is the Variable Citadel!","You need Level 5 to challenge\nProfessor Axiom!","Defeat him for your first badge!"]},
		{"id":"m2","pos":Vector2i(11,2),"color":Color("#20a020"),"shirt":Color("#20a020"),"xp":50,
		 "lines":["Welcome to Mathopolis!\nCity of equations!","A variable is a letter for\nan unknown number.","x + 2 = 5  →  x = 3!"]},
		{"id":"m3","pos":Vector2i(1,6),"color":Color("#c02020"),"shirt":Color("#c02020"),"xp":50,
		 "lines":["20 badges in Math World.\nGet them all for Silver Mountain!"]},
		{"id":"m4","pos":Vector2i(3,3),"color":Color("#8888b0"),"shirt":Color("#8888b0"),"xp":50,
		 "lines":["Algebra: every equation\nholds a hidden truth.","Find the variable and\nyou find the answer."]},
		{"id":"mq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"mq_lost_equation",
		 "lines":["I'm Equa the Scholar!\nI lost my 3 formula stones!","Will you help me find them?"]},
		{"id":"m_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Rival Kira","accuracy":0.6,"color":Color("#ff6020")},
		 "lines":["Knowledge Duel!\n7 questions. 3 lives each.","Think you can beat me?"]},
	],
	"english":[
		{"id":"e1","pos":Vector2i(7,5),"shirt":Color("#e8c030"),"xp":50,
		 "lines":["The golden tower — Noun Sanctum!","Lexis guards it.\nYou need Level 5!"]},
		{"id":"e2","pos":Vector2i(11,2),"shirt":Color("#20a080"),"xp":50,
		 "lines":["Lexicon City! Words are power.","Noun = person, place, thing, idea."]},
		{"id":"e3","pos":Vector2i(1,6),"shirt":Color("#cc8020"),"xp":50,
		 "lines":["Proper nouns are always\ncapitalized. London. Paris. Arix!"]},
		{"id":"e4","pos":Vector2i(3,3),"shirt":Color("#b090a0"),"xp":50,
		 "lines":["Master the noun and\nyou master naming the world."]},
		{"id":"eq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"eq_noun_collector",
		 "lines":["I'm Vela! I need 3 Word Scrolls\nfound around Lexicon City!","Will you collect them?"]},
		{"id":"e_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Word Rival Syl","accuracy":0.55,"color":Color("#ff9020")},
		 "lines":["A grammar duel!","Prove your language skills!"]},
	],
	"music":[
		{"id":"mu1","pos":Vector2i(7,5),"shirt":Color("#e8c030"),"xp":50,
		 "lines":["Purple spire = Harmony Hall!","Maestro Resonus performs there.","Level 5 to challenge him!"]},
		{"id":"mu2","pos":Vector2i(11,2),"shirt":Color("#8030c0"),"xp":50,
		 "lines":["Harmonia! City of eternal music.","Staff = 5 lines. Spaces: F-A-C-E."]},
		{"id":"mu3","pos":Vector2i(1,6),"shirt":Color("#c03060"),"xp":50,
		 "lines":["Whole=4 beats. Half=2. Quarter=1.\nThat's the heartbeat of music!"]},
		{"id":"mu4","pos":Vector2i(3,3),"shirt":Color("#a0a0c0"),"xp":50,
		 "lines":["Music is mathematics\nyou can hear."]},
		{"id":"muq_giver1","pos":Vector2i(13,4),"shirt":Color("#20c060"),"xp":0,
		 "type":"quest_giver","quest_id":"muq_lost_notes",
		 "lines":["I'm Aria! I lost 3 Musical Notes\naround Harmonia!","Help me find them?"]},
		{"id":"mu_duel1","pos":Vector2i(12,6),"shirt":Color("#e05010"),"xp":0,
		 "type":"duel","opponent":{"name":"Beat Rival Dex","accuracy":0.5,"color":Color("#ff20ff")},
		 "lines":["A music theory duel!","Let's see who hears\nthe notes more clearly!"]},
	],
}

const QUEST_ITEMS:={
	"math":   [{"id":"mstone1","pos":Vector2i(13,3)},{"id":"mstone2","pos":Vector2i(13,7)},{"id":"mstone3","pos":Vector2i(1,3)}],
	"english":[{"id":"escroll1","pos":Vector2i(13,3)},{"id":"escroll2","pos":Vector2i(13,7)},{"id":"escroll3","pos":Vector2i(1,3)}],
	"music":  [{"id":"mnote1","pos":Vector2i(13,3)},{"id":"mnote2","pos":Vector2i(13,7)},{"id":"mnote3","pos":Vector2i(1,3)}],
}
const MAIN_ITEM:={
	"math":{"id":"math_scroll","pos":Vector2i(11,5),"xp":200,
	 "lines":["Found an Algebra Scroll!","'Variables are the unknown\nwaiting to be named.'","+200 XP!"]},
	"english":{"id":"eng_quill","pos":Vector2i(11,5),"xp":200,
	 "lines":["Found an Ancient Quill!","'Name the world and\nyou begin to own it.'","+200 XP!"]},
	"music":{"id":"mus_note","pos":Vector2i(11,5),"xp":200,
	 "lines":["Found a Resonant Note!","'Music: language the\nsoul speaks natively.'","+200 XP!"]},
}

const TOWN_NAMES:={"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP:={"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}

# ── State ─────────────────────────────────────────────────────────────────────
var _world:String="math"
var _p_grid:Vector2i=Vector2i(7,8)
var _p_pixel:Vector2=Vector2(7*32,8*32)
var _p_dir:int=0
var _p_moving:bool=false
var _p_frame:int=0
var _anim_t:float=0.0
var _dialog:bool=false
var _cleared:bool=false
var _tween:Tween=null
var _time:float=0.0

func _ready()->void:
	add_to_group("overworld")
	set_process(true)
	set_process_input(true)

func init_world(wid:String)->void:
	_world=wid
	GameManager.active_world=wid
	# BUG FIX: clamp grid pos to valid map bounds
	var gp:=GameManager.get_grid_pos()
	gp.x=clampi(gp.x,0,COLS-1)
	gp.y=clampi(gp.y,0,ROWS-1)
	# Extra check: if tile is not walkable, reset to safe default
	var t:=_tile_at(gp)
	if t not in WALKABLE: gp=Vector2i(7,8)
	_p_grid=gp
	_p_pixel=Vector2(_p_grid.x*TS,_p_grid.y*TS)
	_cleared=GameManager.has_badge(BADGE_MAP.get(wid,""))
	set_process(true)
	set_process_input(true)

func set_dialog_open(v:bool)->void:
	_dialog=v
	if not v: set_process_input(true)

func _input(event:InputEvent)->void:
	if _dialog or _p_moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);  _p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1); _p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0); _p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);  _p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	elif event.is_action_pressed("ui_cancel"):
		back_to_world_map.emit(); return
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
	_p_grid=dest; _p_moving=true
	GameManager.set_grid_pos(dest)
	var tgt:=Vector2(dest.x*TS,dest.y*TS)
	if _tween: _tween.kill()
	_tween=create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;queue_redraw(),_p_pixel,tgt,0.12)
	_tween.tween_callback(func():_p_moving=false; _check_quest_item())

func _check_quest_item()->void:
	for qi in QUEST_ITEMS.get(_world,[]):
		if _p_grid==qi.pos and not GameManager.has_item(qi.id):
			GameManager.collect_item(qi.id)
			var aq:=QuestManager.get_active_quest(_world)
			if not aq.is_empty():
				var step:=QuestManager.get_quest_step(aq)
				var steps=aq.get("steps",["..."])
				show_dialog.emit([steps[min(step,steps.size()-1)]])
				if QuestManager.all_items_collected(aq) and not GameManager.quest_done(aq.id):
					_complete_quest(aq)
			return

func _complete_quest(q:Dictionary)->void:
	GameManager.complete_quest(q.id)
	gain_xp.emit(q.reward_xp,"quest")
	show_dialog.emit([q.reward_text,"Quest complete: "+q.title])

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.pos==front: _talk_npc(npc); return
	if _tile_at(front)==T_GDOOR: _enter_gym(); return
	var item=MAIN_ITEM.get(_world,{})
	if front==item.get("pos",Vector2i(-1,-1)) and not GameManager.has_item(item.get("id","")): _collect_main_item()

func _talk_npc(npc:Dictionary)->void:
	match npc.get("type","normal"):
		"quest_giver": _talk_quest_giver(npc)
		"duel":        _talk_duel_npc(npc)
		_:             _talk_normal(npc)

func _talk_normal(npc:Dictionary)->void:
	var lines=npc.lines.duplicate()
	var lvl:=AdaptiveAI.get_explanation_level(_world)
	if not GameManager.has_talked(npc.id):
		GameManager.mark_talked(npc.id)
		if lvl=="beginner": lines.append("Tip: Take your time!\nEvery answer teaches you something.")
		elif lvl=="advanced": lines.append("Your accuracy is impressive!\nFuture Kaiser!")
		lines.append("(+"+str(npc.xp)+" XP!)")
		show_dialog.emit(lines)
		await get_tree().create_timer(0.05).timeout
		gain_xp.emit(npc.xp,"")
	else:
		show_dialog.emit(lines)

func _talk_quest_giver(npc:Dictionary)->void:
	var qid=npc.get("quest_id","")
	var q:={}
	for qd in QuestManager.get_quests(_world):
		if qd.id==qid: q=qd; break
	if q.is_empty(): show_dialog.emit(["..."]);return
	if GameManager.quest_done(qid):
		show_dialog.emit(["Thanks again, "+GameManager.player_name+"!","You are a true scholar!"])
		return
	if QuestManager.all_items_collected(q) and not GameManager.quest_done(qid):
		_complete_quest(q); return
	var step:=QuestManager.get_quest_step(q)
	var steps=q.get("steps",["..."])
	show_dialog.emit([steps[min(step,steps.size()-1)] if step>0 else npc.lines[0]])

func _talk_duel_npc(npc:Dictionary)->void:
	var opp=npc.get("opponent",{"name":"Rival","accuracy":0.5})
	show_dialog.emit(npc.get("lines",[]))
	await get_tree().create_timer(0.1).timeout
	start_duel.emit(opp)

func _collect_main_item()->void:
	var item=MAIN_ITEM.get(_world,{})
	GameManager.collect_item(item.get("id",""))
	show_dialog.emit(item.get("lines",[]))
	gain_xp.emit(item.get("xp",0),"")
	queue_redraw()

func _enter_gym()->void:
	var badge=BADGE_MAP.get(_world,"")
	if _cleared:
		show_dialog.emit(["You already hold the "+badge+"!","The leader bows with respect."]); return
	if not GameManager.can_challenge_gym(1):
		show_dialog.emit(["The entrance is sealed!","You need  Level 5  to challenge\nthis Gym.","Your Level: "+str(GameManager.get_level())+"\nExplore "+TOWN_NAMES.get(_world,"")+" to gain XP!"]); return
	var db_map:={"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db=db_map[_world]
	var data:Dictionary=db.get_gym1_leader()
	data["questions"]=db.get_gym1_questions()
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
		_:
			return Vector2i.ZERO

func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.20: _anim_t=0.0; _p_frame=1-_p_frame
	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
#  Gen 2 / 3 DRAWING ENGINE
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	_draw_map()
	_draw_quest_sparkles()
	_draw_npcs()
	_draw_player()
	_draw_location_banner()
	_draw_hud_hints()

func _draw_map()->void:
	var map=MAPS.get(_world,MAPS.math)
	for r in ROWS:
		for c in COLS:
			_tile(map[r][c],c*TS,r*TS,c,r)
	_draw_item_sparkle()
	_draw_gym_sign()

# ── TILE DISPATCHER ───────────────────────────────────────────────────────────
func _tile(t:int,rx:int,ry:int,c:int,r:int)->void:
	match t:
		T_GRASS: _t_grass(rx,ry,c,r)
		T_TREE:  _t_tree(rx,ry,c,r)
		T_HOUSE: _t_house(rx,ry,c,r)
		T_DOOR:  _t_door(rx,ry,c,r)
		T_PATH:  _t_path(rx,ry,c,r)
		T_GYM:   _t_gym_wall(rx,ry,c,r)
		T_GDOOR: _t_gym_door(rx,ry,c,r)
		T_ITEM:  _t_grass(rx,ry,c,r)
		T_WATER: _t_water(rx,ry,c,r)
		T_SAND:  _t_sand(rx,ry,c,r)
		T_STONE: _t_stone(rx,ry,c,r)
		T_FENCE: _t_fence(rx,ry,c,r)
		T_SIGN:  _t_sign(rx,ry,c,r)
		_: draw_rect(Rect2(rx,ry,TS,TS),Color.MAGENTA)

# ── GRASS (Gen 2 checkered style) ─────────────────────────────────────────────
func _t_grass(rx:int,ry:int,c:int,r:int)->void:
	# World-specific base
	var base:Color; var alt:Color; var dk:Color; var hi:Color
	match _world:
		"math":    base=G1;alt=G2;dk=G3;hi=G4
		"english": base=Color("#c0a858");alt=Color("#b09848");dk=Color("#906830");hi=Color("#d8c070")
		"music":   base=Color("#2a1848");alt=Color("#221040");dk=Color("#180c30");hi=Color("#3c2460")
		_:         base=G1;alt=G2;dk=G3;hi=G4
	draw_rect(Rect2(rx,ry,TS,TS),base)
	# Gen 2 checkered pattern: 4x4 dark blocks on even grid positions
	for py in range(0,TS,4):
		for px in range(0,TS,4):
			if ((px/4 + py/4 + c + r)%2)==0:
				draw_rect(Rect2(rx+px,ry+py,4,4),alt)
	# Grass blade decorations on some tiles
	if (c*7+r*11)%8==0:
		draw_rect(Rect2(rx+5,ry+22,2,6),hi)
		draw_rect(Rect2(rx+12,ry+20,2,8),hi)
		draw_rect(Rect2(rx+20,ry+23,2,5),hi)
	# Flower decoration
	if (c*11+r*7)%14==0 and _world!="music":
		var fc:=Color("#f880a0") if _world=="english" else Color("#f8c030")
		draw_rect(Rect2(rx+14,ry+19,4,4),fc)
		draw_rect(Rect2(rx+15,ry+17,2,8),fc*Color(1,1,1,0.5))
		draw_rect(Rect2(rx+12,ry+20,8,2),fc*Color(1,1,1,0.5))
	# Gen 2 dark outline at borders (bottom+right edge)
	draw_rect(Rect2(rx,ry+TS-1,TS,1),dk*Color(1,1,1,0.3))

# ── TREE (Gen 2 rounded crown) ────────────────────────────────────────────────
func _t_tree(rx:int,ry:int,c:int,r:int)->void:
	_t_grass(rx,ry,c,r)
	# Shadow on ground
	draw_rect(Rect2(rx+4,ry+24,24,7),Color(0,0,0,0.18))
	# Trunk
	draw_rect(Rect2(rx+12,ry+20,8,12),TRK)
	draw_rect(Rect2(rx+14,ry+20,3,12),TRK2)
	# Gen 2 rounded crown — stacked ovals via rect masking
	# Layer 1: outermost shadow ring
	draw_rect(Rect2(rx+4,ry+14,24,16),TR1)
	draw_rect(Rect2(rx+2,ry+10,28,18),TR1)
	# Clip corners manually with grass color to fake oval
	draw_rect(Rect2(rx,ry,4,14),Color(0,0,0,0)) # left clear already
	_mask_corners(rx,ry+10,TR1,4)
	# Layer 2: main body
	draw_rect(Rect2(rx+4,ry+6,24,20),TR2)
	_mask_corners_partial(rx+4,ry+6,24,20,4)
	# Layer 3: bright inner
	draw_rect(Rect2(rx+7,ry+3,18,18),TR3)
	_mask_corners_partial(rx+7,ry+3,18,18,3)
	# Layer 4: highlight
	draw_rect(Rect2(rx+10,ry+2,12,12),TR4)
	_mask_corners_partial(rx+10,ry+2,12,12,3)
	# Layer 5: top specular
	draw_rect(Rect2(rx+12,ry+2,8,6),TR5)
	draw_rect(Rect2(rx+13,ry+2,4,3),Color(1,1,1,0.35))
	# Dark outline ring
	draw_rect(Rect2(rx+2,ry+10,28,18),TR0,false,1.0)

func _mask_corners(_rx:int,_ry:int,_col:Color,_sz:int)->void:
	pass  # corners implied by layering

func _mask_corners_partial(_rx:int,_ry:int,_w:int,_h:int,_sz:int)->void:
	pass  # corners implied by layering

# ── HOUSE (Gen 3 style with proper roof) ──────────────────────────────────────
func _t_house(rx:int,ry:int,c:int,r:int)->void:
	# Determine world-specific palette
	var wall:Color; var roof:Color; var roof2:Color
	match _world:
		"math":    wall=HW;  roof=Color("#204090");roof2=Color("#102870")
		"english": wall=HW;  roof=Color("#b83010");roof2=Color("#882010")
		"music":   wall=Color("#280840");roof=Color("#601090");roof2=Color("#400870")
		_:         wall=HW;  roof=HR; roof2=HR2
	# Wall base
	draw_rect(Rect2(rx,ry,TS,TS),wall)
	draw_rect(Rect2(rx+TS-5,ry+4,5,TS-4),HW3)  # side shadow
	# Roof (fills top portion with gable shape)
	draw_rect(Rect2(rx,ry,TS,10),roof2)
	draw_rect(Rect2(rx,ry+2,TS,8),roof)
	draw_rect(Rect2(rx+2,ry+8,TS-4,3),roof.lightened(0.1))
	# Chimney
	draw_rect(Rect2(rx+22,ry,5,9),roof2)
	draw_rect(Rect2(rx+21,ry,7,3),OL)
	# Window (Gen 3 style: frame + pane)
	draw_rect(Rect2(rx+4,ry+12,10,10),OL)     # outer frame
	draw_rect(Rect2(rx+5,ry+13,8,8),WIN)      # glass
	draw_rect(Rect2(rx+8,ry+13,1,8),OL2)      # vertical divider
	draw_rect(Rect2(rx+5,ry+16,8,1),OL2)      # horizontal divider
	draw_rect(Rect2(rx+5,ry+13,4,4),WIN2)     # top-left bright pane
	# Second window
	draw_rect(Rect2(rx+18,ry+12,10,10),OL)
	draw_rect(Rect2(rx+19,ry+13,8,8),WIN)
	draw_rect(Rect2(rx+22,ry+13,1,8),OL2)
	draw_rect(Rect2(rx+19,ry+16,8,1),OL2)
	draw_rect(Rect2(rx+19,ry+13,4,4),WIN2)
	# Wall outline
	draw_rect(Rect2(rx,ry,TS,TS),OL,false,1.0)

# ── DOOR (house entrance) ─────────────────────────────────────────────────────
func _t_door(rx:int,ry:int,c:int,r:int)->void:
	_t_grass(rx,ry,c,r)
	# Door frame
	draw_rect(Rect2(rx+10,ry+6,12,26),OL)
	draw_rect(Rect2(rx+11,ry+7,10,25),DR)
	# Door panels
	draw_rect(Rect2(rx+12,ry+8,4,10),DR2)
	draw_rect(Rect2(rx+17,ry+8,4,10),DR2)
	# Door knob
	draw_rect(Rect2(rx+18,ry+18,2,2),P4)
	# Top step
	draw_rect(Rect2(rx+8,ry+28,16,4),P2)
	draw_rect(Rect2(rx+8,ry+28,16,1),P4)

# ── PATH (Gen 2 sandy cobblestone) ───────────────────────────────────────────
func _t_path(rx:int,ry:int,c:int,r:int)->void:
	var main:Color=P1 if _world!="english" else Color("#e0d080")
	var alt:Color=P2 if _world!="english" else Color("#d0c070")
	# Base sand/dirt
	draw_rect(Rect2(rx,ry,TS,TS),main)
	# Gen 2 subtle texture — light/dark alternating blocks
	for py in range(0,TS,4):
		for px in range(0,TS,4):
			if ((px/4+py/4+c+r)%2)==0:
				draw_rect(Rect2(rx+px,ry+py,4,4),alt)
	# Cobblestone dividers (Gen 3 look)
	draw_rect(Rect2(rx,ry,TS,1),P3)           # top line
	draw_rect(Rect2(rx,ry,1,TS),P3)           # left line
	# Pebble decorations
	if (c*5+r*9)%6==0:
		draw_rect(Rect2(rx+7,ry+8,4,3),P3)
		draw_rect(Rect2(rx+20,ry+20,4,3),P3)
	# Border with adjacent grass (transition strip)
	var map=MAPS.get(_world,MAPS.math)
	if r>0 and map[r-1][c]==T_GRASS:
		draw_rect(Rect2(rx,ry,TS,2),G3*Color(1,1,1,0.5))
	if r<ROWS-1 and map[r+1][c]==T_GRASS:
		draw_rect(Rect2(rx,ry+TS-2,TS,2),G3*Color(1,1,1,0.5))

# ── GYM WALL (themed per world — Gen 3 octagonal gym style) ──────────────────
func _t_gym_wall(rx:int,ry:int,c:int,r:int)->void:
	var cols:Array=GM_MATH if _world=="math" else (GM_ENG if _world=="english" else GM_MUS)
	# Base wall body
	draw_rect(Rect2(rx,ry,TS,TS),cols[0])
	# Upper stripe (roof/trim)
	draw_rect(Rect2(rx,ry,TS,8),cols[1])
	draw_rect(Rect2(rx+1,ry+1,TS-2,4),cols[2].lightened(0.15))
	# Main wall panels
	draw_rect(Rect2(rx+2,ry+8,TS-4,TS-8),cols[1])
	# Vertical trim lines (gym pillar look)
	draw_rect(Rect2(rx+6,ry+8,3,TS-8),cols[0])
	draw_rect(Rect2(rx+TS-9,ry+8,3,TS-8),cols[0])
	# Horizontal band in middle
	draw_rect(Rect2(rx,ry+18,TS,4),cols[2])
	draw_rect(Rect2(rx+1,ry+19,TS-2,2),cols[3]*Color(1,1,1,0.4))
	# Bottom trim
	draw_rect(Rect2(rx,ry+TS-4,TS,4),cols[0])
	# Animated glow strip at bottom
	var glow:=0.4+0.35*sin(_time*2.5)
	draw_rect(Rect2(rx+4,ry+TS-3,TS-8,2),cols[4]*Color(1,1,1,glow))
	# Outline
	draw_rect(Rect2(rx,ry,TS,TS),OL,false,1.0)

# ── GYM DOOR (prominent entrance) ────────────────────────────────────────────
func _t_gym_door(rx:int,ry:int,c:int,r:int)->void:
	var cols:Array=GM_MATH if _world=="math" else (GM_ENG if _world=="english" else GM_MUS)
	draw_rect(Rect2(rx,ry,TS,TS),cols[0])
	# Door arch
	draw_rect(Rect2(rx+4,ry+4,24,28),cols[1])
	draw_rect(Rect2(rx+4,ry+4,24,28),cols[4],false,2.0)
	# Arch top
	draw_rect(Rect2(rx+4,ry+4,24,7),cols[2])
	# Door shine stripe
	draw_rect(Rect2(rx+6,ry+6,5,18),Color(1,1,1,0.22))
	# World-specific emblem above door
	var glow2:=0.6+0.4*sin(_time*3.0)
	draw_rect(Rect2(rx+10,ry+1,12,4),cols[4]*Color(1,1,1,glow2))
	# Door knob / badge
	draw_rect(Rect2(rx+14,ry+17,4,4),cols[4])
	draw_rect(Rect2(rx+15,ry+18,2,2),Color(1,1,1,0.8))
	# Outline
	draw_rect(Rect2(rx,ry,TS,TS),OL,false,1.0)

# ── WATER (Gen 2 animated waves) ─────────────────────────────────────────────
func _t_water(rx:int,ry:int,c:int,r:int)->void:
	var wave_off:=sin(_time*1.8+(c+r)*0.5)
	draw_rect(Rect2(rx,ry,TS,TS),W1)
	# Wave rows — animated offset
	for wy in [4,10,16,22,28]:
		var shift:=int(wave_off*2)
		var ww=TS-4+abs(shift)
		draw_rect(Rect2(rx+2,ry+wy+shift,ww,2),W2)
	# Mid highlights
	for wy2 in [7,19]:
		var shift2:=int(sin(_time*2.0+(c+r+5)*0.5)*2)
		draw_rect(Rect2(rx+4,ry+wy2+shift2,TS-8,2),W3)
	# Sparkle
	var sp:=sin(_time*4.0+(c*3+r*2)*0.8)
	if sp>0.7:
		draw_rect(Rect2(rx+int((c%3)*8)+4,ry+int((r%3)*6)+4,3,3),W5)
	# Dark border
	draw_rect(Rect2(rx,ry,TS,TS),W1.darkened(0.3),false,1.0)

# ── SAND (English world floor) ────────────────────────────────────────────────
func _t_sand(rx:int,ry:int,c:int,r:int)->void:
	draw_rect(Rect2(rx,ry,TS,TS),P1)
	# Gen 2 checker on sand
	for py in range(0,TS,4):
		for px in range(0,TS,4):
			if ((px/4+py/4+c+r)%2)==0: draw_rect(Rect2(rx+px,ry+py,4,4),P2)
	# Random pebbles
	if (c*13+r*5)%10==0:
		draw_rect(Rect2(rx+8,ry+10,5,4),P3)
		draw_rect(Rect2(rx+9,ry+11,3,2),P4)
	if (c*7+r*17)%16==0:
		draw_rect(Rect2(rx+20,ry+18,6,5),P3)

# ── STONE (Music world floor) ─────────────────────────────────────────────────
func _t_stone(rx:int,ry:int,c:int,r:int)->void:
	draw_rect(Rect2(rx,ry,TS,TS),ST1)
	# Stone blocks
	draw_rect(Rect2(rx+1,ry+1,14,14),ST2); draw_rect(Rect2(rx+17,ry+1,14,14),ST2)
	draw_rect(Rect2(rx+9,ry+17,14,14),ST2); draw_rect(Rect2(rx+1,ry+17,7,14),ST2)
	# Highlights
	draw_rect(Rect2(rx+2,ry+2,5,3),Color(1,1,1,0.15)); draw_rect(Rect2(rx+18,ry+2,5,3),Color(1,1,1,0.15))
	# Cracks
	draw_rect(Rect2(rx+6,ry+6,2,6),ST3); draw_rect(Rect2(rx+22,ry+20,2,5),ST3)
	draw_rect(Rect2(rx,ry,TS,TS),ST3,false,1.0)

# ── FENCE ─────────────────────────────────────────────────────────────────────
func _t_fence(rx:int,ry:int,c:int,r:int)->void:
	_t_grass(rx,ry,c,r)
	draw_rect(Rect2(rx+3,ry+6,4,22),FN2); draw_rect(Rect2(rx+3,ry+6,3,22),FN1)
	draw_rect(Rect2(rx+25,ry+6,4,22),FN2); draw_rect(Rect2(rx+25,ry+6,3,22),FN1)
	draw_rect(Rect2(rx+3,ry+8,TS-6,4),FN2); draw_rect(Rect2(rx+3,ry+8,TS-6,2),FN1)
	draw_rect(Rect2(rx+3,ry+18,TS-6,4),FN2); draw_rect(Rect2(rx+3,ry+18,TS-6,2),FN1)
	# Post tops
	draw_rect(Rect2(rx+2,ry+4,6,4),FN1); draw_rect(Rect2(rx+24,ry+4,6,4),FN1)

# ── SIGN ──────────────────────────────────────────────────────────────────────
func _t_sign(rx:int,ry:int,c:int,r:int)->void:
	_t_sand(rx,ry,c,r)
	draw_rect(Rect2(rx+13,ry+16,6,16),FN2)
	draw_rect(Rect2(rx+14,ry+16,3,16),FN1)
	draw_rect(Rect2(rx+4,ry+6,24,14),P3)
	draw_rect(Rect2(rx+4,ry+6,24,14),P1)
	draw_rect(Rect2(rx+4,ry+6,24,14),OL,false,1.5)
	draw_rect(Rect2(rx+6,ry+8,8,3),OL2); draw_rect(Rect2(rx+6,ry+13,14,3),OL2)

# ── ITEM SPARKLE ─────────────────────────────────────────────────────────────
func _draw_item_sparkle()->void:
	var item=MAIN_ITEM.get(_world,{})
	if item.is_empty() or GameManager.has_item(item.get("id","")): return
	var p=item.get("pos",Vector2i(-1,-1))
	var rx=p.x*TS; var ry=p.y*TS
	var g:=0.5+0.5*sin(_time*4.0)
	var g2:=0.5+0.5*sin(_time*4.0+PI)
	var col:=Color("#44aaff") if _world=="math" else (Color("#ffcc44") if _world=="english" else Color("#cc44ff"))
	# Gen 3-style item orb
	draw_rect(Rect2(rx+10,ry+9,12,14),col*Color(1,1,1,g))
	draw_rect(Rect2(rx+12,ry+11,8,10),Color(1,1,1,g*0.6))
	draw_rect(Rect2(rx+10,ry+9,12,14),OL,false,1.0)
	# Star sparkles
	draw_rect(Rect2(rx+14,ry+3,4,8),Color(1,1,1,g))
	draw_rect(Rect2(rx+10,ry+6,12,3),Color(1,1,1,g2*0.6))
	draw_rect(Rect2(rx+6,ry+12,4,4),Color(1,1,1,g2*0.5))
	draw_rect(Rect2(rx+22,ry+12,4,4),Color(1,1,1,g2*0.5))

# ── QUEST ITEM SPARKLES ───────────────────────────────────────────────────────
func _draw_quest_sparkles()->void:
	var aq:=QuestManager.get_active_quest(_world)
	if aq.is_empty(): return
	var col:=Color("#44aaff") if _world=="math" else (Color("#ffcc44") if _world=="english" else Color("#cc44ff"))
	for qi in QUEST_ITEMS.get(_world,[]):
		if GameManager.has_item(qi.id): continue
		var rx=qi.pos.x*TS; var ry=qi.pos.y*TS
		var g:=0.4+0.6*sin(_time*5.0+qi.pos.x*0.8)
		draw_rect(Rect2(rx+10,ry+8,12,14),col*Color(1,1,1,g))
		draw_rect(Rect2(rx+14,ry+2,4,7),Color(1,1,1,g))
		draw_rect(Rect2(rx+10,ry+8,12,14),OL,false,1.0)

# ── GYM SIGN BANNER ──────────────────────────────────────────────────────────
func _draw_gym_sign()->void:
	var fnt:=ThemeDB.fallback_font
	var gnames:={"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	var cols:=GM_MATH if _world=="math" else (GM_ENG if _world=="english" else GM_MUS)
	var gcol=cols[4]
	# Banner drawn above gym row (row 7, so y=7*32=224, banner at y=215)
	draw_rect(Rect2(128,212,224,18),OL)
	draw_rect(Rect2(129,213,222,16),cols[0])
	draw_rect(Rect2(130,214,220,14),cols[1])
	draw_string(fnt,Vector2(138,225),
		"★  "+gnames.get(_world,"")+"  ★",
		HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)

# ── NPC SPRITES (Gen 2/3 quality) ────────────────────────────────────────────
func _draw_npcs()->void:
	for npc in WORLD_NPCS.get(_world,[]):
		_draw_npc(npc.pos.x*TS,npc.pos.y*TS,npc.get("shirt",Color("#e8c030")),npc.get("type","normal"))

func _draw_npc(px:int,py:int,shirt:Color,typ:String)->void:
	var skin:=Color("#f8d8a8"); var hair:=Color("#382010")
	var dark:=OL; var pants:=Color("#2040a8")
	# Shadow
	draw_rect(Rect2(px+6,py+29,20,4),Color(0,0,0,0.2))
	# Shoes
	draw_rect(Rect2(px+7,py+26,7,5),dark)
	draw_rect(Rect2(px+18,py+26,7,5),dark)
	draw_rect(Rect2(px+8,py+27,5,4),Color("#303030"))
	draw_rect(Rect2(px+19,py+27,5,4),Color("#303030"))
	# Pants
	draw_rect(Rect2(px+8,py+17,6,11),pants)
	draw_rect(Rect2(px+18,py+17,6,11),pants)
	draw_rect(Rect2(px+9,py+17,4,11),pants.lightened(0.12))
	# Belt
	draw_rect(Rect2(px+7,py+16,18,3),Color("#5a4010"))
	draw_rect(Rect2(px+14,py+16,4,3),P4)
	# Shirt
	draw_rect(Rect2(px+6,py+9,20,9),shirt)
	draw_rect(Rect2(px+6,py+9,20,3),shirt.lightened(0.25))
	draw_rect(Rect2(px+6,py+14,20,4),shirt.darkened(0.15))
	draw_rect(Rect2(px+6,py+9,20,9),dark,false,1.0)
	# Arms with outline
	draw_rect(Rect2(px+2,py+10,5,10),skin); draw_rect(Rect2(px+2,py+10,5,10),dark,false,1.0)
	draw_rect(Rect2(px+25,py+10,5,10),skin); draw_rect(Rect2(px+25,py+10,5,10),dark,false,1.0)
	# Neck
	draw_rect(Rect2(px+13,py+6,6,5),skin)
	# Head with outline
	draw_rect(Rect2(px+8,py+1,16,10),skin)
	draw_rect(Rect2(px+9,py+1,14,4),Color("#fae8b8"))  # forehead highlight
	draw_rect(Rect2(px+8,py+1,16,10),dark,false,1.0)
	# Hair
	draw_rect(Rect2(px+8,py+1,16,4),hair)
	draw_rect(Rect2(px+9,py+1,12,2),hair.lightened(0.2))
	# Eyes
	draw_rect(Rect2(px+11,py+7,3,3),dark)
	draw_rect(Rect2(px+18,py+7,3,3),dark)
	draw_rect(Rect2(px+12,py+7,1,2),Color(1,1,1,0.7))
	draw_rect(Rect2(px+19,py+7,1,2),Color(1,1,1,0.7))
	# Type badges
	if typ=="quest_giver":
		draw_rect(Rect2(px+12,py-10,9,9),Color("#ffd700")); draw_rect(Rect2(px+12,py-10,9,9),dark,false,1.0)
		draw_string(ThemeDB.fallback_font,Vector2(px+14,py-2),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,11,dark)
	elif typ=="duel":
		draw_rect(Rect2(px+12,py-10,9,9),Color("#ff3010")); draw_rect(Rect2(px+12,py-10,9,9),dark,false,1.0)
		draw_string(ThemeDB.fallback_font,Vector2(px+14,py-2),"⚔",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#ffffff"))

# ── PLAYER SPRITE (Gen 2/3 Red style) ────────────────────────────────────────
func _draw_player()->void:
	var px:=int(_p_pixel.x); var py:=int(_p_pixel.y)
	var fr:=_p_frame if _p_moving else 0
	var lo:=-3 if fr==0 else 3; var ro:=3 if fr==0 else -3
	var skin:=Color("#f8d8a8"); var dark:=OL

	# Shadow
	draw_rect(Rect2(px+5,py+29,22,5),Color(0,0,0,0.2))
	# Shoes + outline
	draw_rect(Rect2(px+5+lo,py+26,9,5),dark)
	draw_rect(Rect2(px+6+lo,py+27,7,4),Color("#282828"))
	draw_rect(Rect2(px+18+ro,py+26,9,5),dark)
	draw_rect(Rect2(px+19+ro,py+27,7,4),Color("#282828"))
	# Pants + outline
	draw_rect(Rect2(px+7,py+16,8,12),Color("#183888"))
	draw_rect(Rect2(px+17,py+16,8,12),Color("#183888"))
	draw_rect(Rect2(px+8,py+16,6,12),Color("#203898"))  # highlight stripe
	draw_rect(Rect2(px+7,py+16,8,12),dark,false,1.0)
	draw_rect(Rect2(px+17,py+16,8,12),dark,false,1.0)
	# Belt
	draw_rect(Rect2(px+6,py+15,20,3),Color("#5a3808"))
	draw_rect(Rect2(px+13,py+15,5,3),Color("#ffd700"))
	# Shirt (Red's iconic red shirt) + outline
	draw_rect(Rect2(px+4,py+8,24,9),Color("#c01010"))
	draw_rect(Rect2(px+4,py+8,24,3),Color("#e01818"))   # top highlight
	draw_rect(Rect2(px+4,py+13,24,4),Color("#a00c0c"))  # bottom shadow
	draw_rect(Rect2(px+4,py+8,24,9),dark,false,1.0)
	# Shirt collar
	draw_rect(Rect2(px+12,py+8,8,4),Color("#e8e8e8"))
	# Arms with outline
	draw_rect(Rect2(px+0,py+9,5,11),skin)
	draw_rect(Rect2(px+0,py+9,5,11),dark,false,1.0)
	draw_rect(Rect2(px+1,py+9,3,5),Color("#fae8b8"))
	draw_rect(Rect2(px+27,py+9,5,11),skin)
	draw_rect(Rect2(px+27,py+9,5,11),dark,false,1.0)
	draw_rect(Rect2(px+28,py+9,3,5),Color("#fae8b8"))
	# Neck
	draw_rect(Rect2(px+13,py+5,6,5),skin)
	# Head with outline
	draw_rect(Rect2(px+7,py+0,18,11),skin)
	draw_rect(Rect2(px+8,py+0,16,4),Color("#fae8b8"))
	draw_rect(Rect2(px+7,py+0,18,11),dark,false,1.0)
	# Cap brim
	draw_rect(Rect2(px+4,py+3,24,3),Color("#c01010"))
	draw_rect(Rect2(px+4,py+3,24,3),dark,false,1.0)
	# Cap body
	draw_rect(Rect2(px+6,py+0,20,5),Color("#c01010"))
	draw_rect(Rect2(px+7,py+0,18,2),Color("#e01818"))
	draw_rect(Rect2(px+6,py+0,20,5),dark,false,1.0)
	# Cap badge/button
	draw_rect(Rect2(px+14,py+1,4,3),Color("#ffd700"))
	draw_rect(Rect2(px+15,py+1,2,2),Color(1,1,1,0.6))
	# Direction-aware eyes
	if _p_dir==0:  # facing south
		draw_rect(Rect2(px+10,py+6,4,3),dark)
		draw_rect(Rect2(px+18,py+6,4,3),dark)
		draw_rect(Rect2(px+11,py+6,2,2),Color(1,1,1,0.65))
		draw_rect(Rect2(px+19,py+6,2,2),Color(1,1,1,0.65))
	elif _p_dir==1:  # north (back)
		draw_rect(Rect2(px+10,py+6,4,3),dark)
		draw_rect(Rect2(px+18,py+6,4,3),dark)
	elif _p_dir==2:  # west
		draw_rect(Rect2(px+9,py+6,4,3),dark)
		draw_rect(Rect2(px+10,py+6,2,2),Color(1,1,1,0.6))
	elif _p_dir==3:  # east
		draw_rect(Rect2(px+19,py+6,4,3),dark)
		draw_rect(Rect2(px+20,py+6,2,2),Color(1,1,1,0.6))

# ── UI OVERLAYS ───────────────────────────────────────────────────────────────
func _draw_location_banner()->void:
	var fnt=ThemeDB.fallback_font; var town=TOWN_NAMES.get(_world,"")
	# Gen 3 style location banner (bottom-left box)
	draw_rect(Rect2(4,4,130,22),OL)
	draw_rect(Rect2(5,5,128,20),Color(0.05,0.05,0.12,0.88))
	draw_rect(Rect2(5,5,128,4),Color(0.2,0.2,0.5,0.5))
	draw_string(fnt,Vector2(9,21),town,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffffff"))

func _draw_hud_hints()->void:
	var fnt:=ThemeDB.fallback_font
	# ESC hint
	draw_rect(Rect2(330,4,146,16),OL)
	draw_rect(Rect2(331,5,144,14),Color(0,0,0,0.6))
	draw_string(fnt,Vector2(335,16),"ESC = World Map",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.7,0.7,0.9))
	# Quest tracker
	var aq:=QuestManager.get_active_quest(_world)
	if not aq.is_empty() and not GameManager.quest_done(aq.id):
		var step:=QuestManager.get_quest_step(aq)
		var total=aq.get("item_ids",[]).size()
		draw_rect(Rect2(4,28,230,16),OL)
		draw_rect(Rect2(5,29,228,14),Color(0,0,0,0.55))
		draw_string(fnt,Vector2(9,41),"Quest: "+aq.title+" ("+str(step)+"/"+str(max(total,1))+")",
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ffd700"))
