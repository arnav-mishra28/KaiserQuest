# Overworld.gd v0.3 — Town map with side quests, duels, expanded NPCs
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

# ── NPC definitions per world ─────────────────────────────────────────────────
const WORLD_NPCS:={
	"math":[
		{"id":"m1","pos":Vector2i(7,5),"color":Color("#e8c830"),"xp":50,
		 "lines":["That towering blue Citadel\nis the Variable Citadel!","Need Level 5 to challenge\nProfessor Axiom!"]},
		{"id":"m2","pos":Vector2i(11,2),"color":Color("#30a030"),"xp":50,
		 "lines":["Welcome to Mathopolis!\nCity of equations!","A variable is a letter for\nan unknown number.","x + 2 = 5  →  x = 3!"]},
		{"id":"m3","pos":Vector2i(1,6),"color":Color("#a03030"),"xp":50,
		 "lines":["20 badges in Math World.\nCollect all 20 for Silver Mtn!"]},
		{"id":"m4","pos":Vector2i(3,3),"color":Color("#9090b0"),"xp":50,
		 "lines":["Algebra: every equation\nholds a hidden truth.","Find the variable and\nyou find the answer."]},
		# Quest giver NPC
		{"id":"mq_giver1","pos":Vector2i(13,4),"color":Color("#60c060"),"xp":0,
		 "type":"quest_giver","quest_id":"mq_lost_equation",
		 "lines":["I'm Equa! I lost my 3 formula\nstones around town!","Will you help me find them?"]},
		# Duel NPC
		{"id":"m_duel1","pos":Vector2i(12,6),"color":Color("#ff6020"),"xp":0,
		 "type":"duel",
		 "opponent":{"name":"Rival Kira","accuracy":0.6,"color":Color("#ff6020")},
		 "lines":["Hey! I challenge you to\na Knowledge Duel!","7 questions, 3 lives each.\nThink you can beat me?"]},
	],
	"english":[
		{"id":"e1","pos":Vector2i(7,5),"color":Color("#e8c830"),"xp":50,
		 "lines":["The golden tower ahead\nis the Noun Sanctum!","Lexis guards it.\nYou need Level 5!"]},
		{"id":"e2","pos":Vector2i(11,2),"color":Color("#30a080"),"xp":50,
		 "lines":["Lexicon City!\nCity of a thousand words!","A noun: person, place,\nthing, or idea."]},
		{"id":"e3","pos":Vector2i(1,6),"color":Color("#cc8830"),"xp":50,
		 "lines":["Proper nouns name specific\nthings — always capitalized!"]},
		{"id":"e4","pos":Vector2i(3,3),"color":Color("#b090a0"),"xp":50,
		 "lines":["Master the noun and you\nbegin to master language."]},
		{"id":"eq_giver1","pos":Vector2i(13,4),"color":Color("#60c060"),"xp":0,
		 "type":"quest_giver","quest_id":"eq_noun_collector",
		 "lines":["I'm Vela! I need 3 Word Scrolls\nscattered around Lexicon City!","Will you collect them for me?"]},
		{"id":"e_duel1","pos":Vector2i(12,6),"color":Color("#ff6020"),"xp":0,
		 "type":"duel",
		 "opponent":{"name":"Word Rival Syl","accuracy":0.55,"color":Color("#ff9020")},
		 "lines":["A grammar duel?","Let's test those language\nskills of yours!"]},
	],
	"music":[
		{"id":"mu1","pos":Vector2i(7,5),"color":Color("#e8c830"),"xp":50,
		 "lines":["Purple spire = Harmony Hall!","Maestro Resonus is inside.\nLevel 5 to challenge him!"]},
		{"id":"mu2","pos":Vector2i(11,2),"color":Color("#8030c0"),"xp":50,
		 "lines":["Harmonia! City of music!","5 staff lines. Spaces: F-A-C-E."]},
		{"id":"mu3","pos":Vector2i(1,6),"color":Color("#c03060"),"xp":50,
		 "lines":["Whole=4 beats. Half=2.\nQuarter=1. That's the rhythm!"]},
		{"id":"mu4","pos":Vector2i(3,3),"color":Color("#a0a0c0"),"xp":50,
		 "lines":["Music is mathematics\nyou can hear."]},
		{"id":"muq_giver1","pos":Vector2i(13,4),"color":Color("#60c060"),"xp":0,
		 "type":"quest_giver","quest_id":"muq_lost_notes",
		 "lines":["I'm Aria! I lost 3 Musical\nNotes around Harmonia!","Help me find them?"]},
		{"id":"mu_duel1","pos":Vector2i(12,6),"color":Color("#ff6020"),"xp":0,
		 "type":"duel",
		 "opponent":{"name":"Beat Rival Dex","accuracy":0.5,"color":Color("#ff20ff")},
		 "lines":["A music theory duel!","Let's see who hears\nthe notes more clearly!"]},
	],
}

# ── Quest item positions per world ────────────────────────────────────────────
const QUEST_ITEMS:={
	"math":   [{"id":"mstone1","pos":Vector2i(13,3)},{"id":"mstone2","pos":Vector2i(13,7)},{"id":"mstone3","pos":Vector2i(1,3)}],
	"english":[{"id":"escroll1","pos":Vector2i(13,3)},{"id":"escroll2","pos":Vector2i(13,7)},{"id":"escroll3","pos":Vector2i(1,3)}],
	"music":  [{"id":"mnote1","pos":Vector2i(13,3)},{"id":"mnote2","pos":Vector2i(13,7)},{"id":"mnote3","pos":Vector2i(1,3)}],
}
const MAIN_ITEM:={
	"math":{"id":"math_scroll","pos":Vector2i(11,5),"xp":200,"lines":["Algebra Scroll found!","'Variables are the unknown\nwaiting to be named.'","+200 XP!"]},
	"english":{"id":"eng_quill","pos":Vector2i(11,5),"xp":200,"lines":["Ancient Quill found!","'Name the world and\nyou begin to own it.'","+200 XP!"]},
	"music":{"id":"mus_note","pos":Vector2i(11,5),"xp":200,"lines":["Resonant Note found!","'Music: the language\nthe soul speaks natively.'","+200 XP!"]},
}

const TOWN_NAMES:={"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP:={"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}

# ── State ─────────────────────────────────────────────────────────────────────
var _world:String="math"
var _p_grid:Vector2i=Vector2i(2,8)
var _p_pixel:Vector2=Vector2(64,256)
var _p_dir:int=0; var _p_moving:bool=false; var _p_frame:int=0
var _anim_t:float=0.0; var _dialog:bool=false; var _cleared:bool=false
var _tween:Tween=null; var _time:float=0.0

func init_world(wid:String)->void:
	_world=wid; GameManager.active_world=wid
	_p_grid=GameManager.get_grid_pos()
	_p_pixel=Vector2(_p_grid.x*TS,_p_grid.y*TS)
	_cleared=GameManager.has_badge(BADGE_MAP.get(wid,""))

func set_dialog_open(v:bool)->void: _dialog=v

func _input(event:InputEvent)->void:
	if _dialog or _p_moving: return
	var dir:=Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir=Vector2i(0,1);_p_dir=0
	elif event.is_action_pressed("ui_up"):    dir=Vector2i(0,-1);_p_dir=1
	elif event.is_action_pressed("ui_left"):  dir=Vector2i(-1,0);_p_dir=2
	elif event.is_action_pressed("ui_right"): dir=Vector2i(1,0);_p_dir=3
	elif event.is_action_pressed("ui_accept"): _interact(); return
	elif event.is_action_pressed("ui_cancel"):
		back_to_world_map.emit(); return
	if dir!=Vector2i.ZERO: _try_move(_p_grid+dir)

func _try_move(dest:Vector2i)->void:
	var t:=_tile_at(dest)
	if t==T_GDOOR: _enter_gym(); return
	if t in WALKABLE:
		_do_move(dest)
		if t==T_ITEM and dest==MAIN_ITEM.get(_world,{}).get("pos",Vector2i(-1,-1)):
			if not GameManager.has_item(MAIN_ITEM[_world].id): _collect_main_item()

func _do_move(dest:Vector2i)->void:
	_p_grid=dest; _p_moving=true; GameManager.set_grid_pos(dest)
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
			var step:=QuestManager.get_quest_step(aq)
			if not aq.is_empty():
				var step_lines=aq.steps
				show_dialog.emit([step_lines[min(step,step_lines.size()-1)]])
				if QuestManager.all_items_collected(aq):
					_complete_quest(aq)
			return

func _complete_quest(q:Dictionary)->void:
	GameManager.complete_quest(q.id)
	gain_xp.emit(q.reward_xp,"quest")
	show_dialog.emit([q.reward_text,"Quest complete: "+q.title,"Returning to the next quest..."])

func _interact()->void:
	var front:=_p_grid+_dv(_p_dir)
	for npc in WORLD_NPCS.get(_world,[]):
		if npc.pos==front: _talk_npc(npc); return
	if _tile_at(front)==T_GDOOR: _enter_gym(); return
	if front==MAIN_ITEM.get(_world,{}).get("pos",Vector2i(-1,-1)):
		if not GameManager.has_item(MAIN_ITEM[_world].id): _collect_main_item()

func _talk_npc(npc:Dictionary)->void:
	var typ=npc.get("type","normal")
	match typ:
		"quest_giver": _talk_quest_giver(npc)
		"duel":        _talk_duel_npc(npc)
		_:             _talk_normal(npc)

func _talk_normal(npc:Dictionary)->void:
	var lines=npc.lines.duplicate()
	# Adaptive explanation level
	var lvl:=AdaptiveAI.get_explanation_level(_world)
	if lvl=="beginner" and not GameManager.has_talked(npc.id):
		lines.append("(Tip: Take your time!\nEach answer teaches you something.)")
	elif lvl=="advanced" and not GameManager.has_talked(npc.id):
		lines.append("(Your accuracy is impressive!\nKeep it up, future Kaiser!)")
	if not GameManager.has_talked(npc.id):
		GameManager.mark_talked(npc.id)
		lines.append("(+"+str(npc.xp)+" XP!)")
		show_dialog.emit(lines)
		await get_tree().create_timer(0.05).timeout
		gain_xp.emit(npc.xp,"")
	else:
		show_dialog.emit(lines)

func _talk_quest_giver(npc:Dictionary)->void:
	var qid=npc.quest_id
	var q_list:=QuestManager.get_quests(_world)
	var q:={}
	for qd in q_list:
		if qd.id==qid: q=qd; break
	if q.is_empty(): show_dialog.emit(["..."]);  return
	if GameManager.quest_done(qid):
		show_dialog.emit(["Thanks again for your\nhelp, "+GameManager.player_name+"!","You are a true scholar of\n"+TOWN_NAMES.get(_world,"")+"!"]); return
	var step:=QuestManager.get_quest_step(q)
	if QuestManager.all_items_collected(q) and not GameManager.quest_done(qid):
		_complete_quest(q)
	else:
		var status_lines:=[q.get("steps",["..."])[min(step,q.get("steps",["..."]).size()-1)]]
		if step==0: status_lines=npc.lines.duplicate()
		show_dialog.emit(status_lines)

func _talk_duel_npc(npc:Dictionary)->void:
	var opp=npc.get("opponent",{"name":"Rival","accuracy":0.5})
	show_dialog.emit(npc.lines + ["Accept the duel? (ENTER = Yes)"],)
	# Signal deferred — after dialog closes, launch duel
	await get_tree().create_timer(0.1).timeout
	# We let dialog handle it; duel launched from Main via signal
	start_duel.emit(opp)

func _collect_main_item()->void:
	var item=MAIN_ITEM.get(_world,{})
	GameManager.collect_item(item.id)
	show_dialog.emit(item.lines)
	gain_xp.emit(item.xp,""); queue_redraw()

func _enter_gym()->void:
	var badge=BADGE_MAP.get(_world,"")
	if _cleared:
		show_dialog.emit(["You already hold the "+badge+"!","The leader bows with respect."]); return
	if not GameManager.can_challenge_gym(1):
		show_dialog.emit(["The entrance is sealed!","Need Level 5 to challenge.","Your Level: "+str(GameManager.get_level())+"\nExplore "+TOWN_NAMES.get(_world,"")+" first!"]); return
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
	return Vector2i.ZERO

func _process(delta:float)->void:
	_time+=delta; _anim_t+=delta
	if _anim_t>=0.22: _anim_t=0.0; _p_frame=1-_p_frame
	queue_redraw()

# ══════════════ DRAWING ═══════════════════════════════════════════════════════
func _draw()->void:
	_draw_map(); _draw_quest_items(); _draw_npcs(); _draw_player(); _draw_ui()

func _draw_map()->void:
	var map=MAPS.get(_world,MAPS.math)
	for r in ROWS:
		for c in COLS: _draw_tile(map[r][c],c*TS,r*TS,c,r)
	_draw_item_sparkle(); _draw_gym_banner()

func _draw_tile(t:int,rx:int,ry:int,c:int,r:int)->void:
	var chk:=(c+r)%2==0
	match t:
		0:
			_tg(rx, ry, chk)
		1:
			_tt(rx, ry)
		2:
			_th(rx, ry)
		3:
			_td(rx, ry, chk)
		4:
			_tp(rx, ry, chk)
		5:
			_tg(rx, ry, chk)
		6:
			_tgd(rx, ry)
		7:
			_tg(rx, ry, chk)
		8:
			_tw(rx, ry)
		9:
			_ts(rx, ry, chk)
		10:
			_tst(rx, ry)
		12:
			_tf(rx, ry, chk)
		13:
			_tsgn(rx, ry, chk)
		_:
			draw_rect(Rect2(rx, ry, TS, TS), Color.MAGENTA)

func _tg(rx:int,ry:int,chk:bool)->void:
	var b:=Color("#1e5218") if _world=="math" else (Color("#c8a860") if _world=="english" else Color("#180e2e"))
	draw_rect(Rect2(rx,ry,TS,TS),b.darkened(0.1) if chk else b)
	if (rx*3+ry*7)%192==0:
		draw_rect(Rect2(rx+4,ry+20,2,8),b.lightened(0.25))
		draw_rect(Rect2(rx+9,ry+18,2,10),b.lightened(0.2))

func _tt(rx:int,ry:int)->void:
	var dk:=Color("#1a4010") if _world!="music" else Color("#220840")
	var lt:=Color("#2a6018") if _world!="music" else Color("#401060")
	draw_rect(Rect2(rx,ry,TS,TS),dk)
	draw_rect(Rect2(rx+2,ry+18,28,12),lt); draw_rect(Rect2(rx+4,ry+10,24,14),dk.lightened(0.1))
	draw_rect(Rect2(rx+8,ry+4,16,12),lt.lightened(0.1)); draw_rect(Rect2(rx+10,ry+5,8,4),lt.lightened(0.28))
	draw_rect(Rect2(rx+12,ry+3,4,3),Color(1,1,1,0.13)); draw_rect(Rect2(rx+TS-5,ry+10,5,TS-10),dk.darkened(0.2))
	draw_rect(Rect2(rx+11,ry+24,10,8),Color("#5a3210")); draw_rect(Rect2(rx+13,ry+24,3,8),Color("#7a4218"))

func _th(rx:int,ry:int)->void:
	var wall:=Color("#c8a882") if _world!="music" else Color("#2a1848")
	var roof:=Color("#204488") if _world=="math" else (Color("#8b2222") if _world=="english" else Color("#6a1a8a"))
	draw_rect(Rect2(rx,ry,TS,TS),wall); draw_rect(Rect2(rx,ry,TS,10),roof.darkened(0.3))
	draw_rect(Rect2(rx,ry+4,TS,7),roof); draw_rect(Rect2(rx+2,ry+9,TS-4,2),roof.lightened(0.12))
	draw_rect(Rect2(rx+TS-4,ry+10,4,TS-10),wall.darkened(0.18))
	draw_rect(Rect2(rx+6,ry+12,20,13),Color("#aaddff")); draw_rect(Rect2(rx+6,ry+12,20,13),Color("#334466"),false,1.5)
	draw_rect(Rect2(rx+15,ry+12,2,13),Color("#334466")); draw_rect(Rect2(rx+6,ry+17,20,2),Color("#334466"))
	draw_rect(Rect2(rx+7,ry+13,6,5),Color(1,1,0.9,0.12)); draw_rect(Rect2(rx+22,ry,5,10),roof.darkened(0.25))

func _td(rx:int,ry:int,chk:bool)->void:
	_tg(rx,ry,chk); draw_rect(Rect2(rx+8,ry+5,16,25),Color("#5a3010"))
	draw_rect(Rect2(rx+8,ry+5,16,25),Color("#222222"),false,1.0)
	draw_rect(Rect2(rx+10,ry+7,5,10),Color(1,0.8,0.5,0.15)); draw_rect(Rect2(rx+20,ry+16,3,3),Color("#ffd700"))

func _tp(rx:int,ry:int,chk:bool)->void:
	var c1:=Color("#c0b07a") if _world!="english" else Color("#e8d09a")
	draw_rect(Rect2(rx,ry,TS,TS),c1 if chk else c1.darkened(0.08))
	draw_rect(Rect2(rx+1,ry+1,14,14),Color(0,0,0,0.06)); draw_rect(Rect2(rx+17,ry+1,14,14),Color(0,0,0,0.06))
	draw_rect(Rect2(rx+9,ry+17,14,14),Color(0,0,0,0.06)); draw_rect(Rect2(rx+2,ry+2,4,4),Color(1,1,1,0.07))

func _tgw(rx:int,ry:int)->void:
	match _world:
		"math":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#0a1e50")); draw_rect(Rect2(rx,ry,TS,6),Color("#1a3a80"))
			draw_rect(Rect2(rx+1,ry+1,TS-2,3),Color(0.3,0.5,1.0,0.2))
			draw_rect(Rect2(rx+4,ry+8,2,20),Color("#2255cc",0.55)); draw_rect(Rect2(rx+20,ry+5,2,22),Color("#2255cc",0.55))
			draw_rect(Rect2(rx+4,ry+TS-4,TS-8,2),Color("#44aaff",0.45)); draw_rect(Rect2(rx,ry,TS,TS),Color("#0e2870"),false,1.0)
		"english":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#3e2408")); draw_rect(Rect2(rx,ry,TS,6),Color("#6a4010"))
			draw_rect(Rect2(rx+1,ry+1,TS-2,3),Color(1.0,0.9,0.3,0.15))
			for bx in [3,11,19]:
				draw_rect(Rect2(rx+bx,ry+8,7,19),Color(0.55+bx*0.012,0.22,0.1))
				draw_rect(Rect2(rx+bx,ry+8,7,2),Color(1.0,0.92,0.55,0.5))
			draw_rect(Rect2(rx+4,ry+TS-4,TS-8,2),Color("#ffcc44",0.4)); draw_rect(Rect2(rx,ry,TS,TS),Color("#5a3010"),false,1.0)
		"music":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#180830")); draw_rect(Rect2(rx,ry,TS,6),Color("#38168a"))
			draw_rect(Rect2(rx+1,ry+1,TS-2,3),Color(0.7,0.2,1.0,0.2))
			for sl in [8,14,20]: draw_rect(Rect2(rx+2,ry+sl,TS-4,1),Color("#9955dd",0.45))
			draw_rect(Rect2(rx+6,ry+10,6,6),Color("#cc44ff",0.7)); draw_rect(Rect2(rx+20,ry+17,6,6),Color("#cc44ff",0.7))
			draw_rect(Rect2(rx+4,ry+TS-4,TS-8,2),Color("#cc44ff",0.45)); draw_rect(Rect2(rx,ry,TS,TS),Color("#280a4a"),false,1.0)

func _tgd(rx:int,ry:int)->void:
	match _world:
		"math":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#0a1e50")); draw_rect(Rect2(rx+4,ry+4,24,28),Color("#1a4acc"))
			draw_rect(Rect2(rx+4,ry+4,24,28),Color("#44aaff"),false,2.0); draw_rect(Rect2(rx+6,ry+5,6,20),Color(1,1,1,0.22))
			draw_rect(Rect2(rx+8,ry+1,16,4),Color("#44aaff",0.85)); draw_rect(Rect2(rx+14,ry+17,4,4),Color("#ffffff"))
		"english":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#3e2408")); draw_rect(Rect2(rx+4,ry+3,24,29),Color("#6a3810"))
			draw_rect(Rect2(rx+4,ry+3,24,29),Color("#ffd700"),false,2.0); draw_rect(Rect2(rx+6,ry+5,5,18),Color(1,0.9,0.5,0.15))
			draw_rect(Rect2(rx+10,ry+1,12,3),Color("#ffd700",0.85)); draw_rect(Rect2(rx+13,ry+16,6,7),Color("#ffd700"))
		"music":
			draw_rect(Rect2(rx,ry,TS,TS),Color("#180830")); draw_rect(Rect2(rx+4,ry+3,24,29),Color("#4a1088"))
			draw_rect(Rect2(rx+4,ry+3,24,29),Color("#cc44ff"),false,2.0); draw_rect(Rect2(rx+4,ry+3,24,8),Color("#6a20a0"))
			draw_rect(Rect2(rx+6,ry+5,4,18),Color(1,1,1,0.18)); draw_rect(Rect2(rx+14,ry+16,4,5),Color("#ff88ff"))

func _tw(rx:int,ry:int)->void:
	var wt:=0.5+0.5*sin(_time*2.2+(rx+ry)*0.04)
	draw_rect(Rect2(rx,ry,TS,TS),Color(0.08,0.25,0.75))
	for wrow in [5,12,19,26]: draw_rect(Rect2(rx+2,ry+wrow,TS-4,2),Color(0.3,0.6,1.0,wt*0.45))

func _ts(rx:int,ry:int,chk:bool)->void:
	draw_rect(Rect2(rx,ry,TS,TS),Color("#c8a858") if chk else Color("#baa048"))

func _tst(rx:int,ry:int)->void:
	draw_rect(Rect2(rx,ry,TS,TS),Color("#555060"))
	draw_rect(Rect2(rx+1,ry+1,14,14),Color("#656070")); draw_rect(Rect2(rx+17,ry+1,14,14),Color("#656070"))
	draw_rect(Rect2(rx+9,ry+17,14,14),Color("#656070")); draw_rect(Rect2(rx+2,ry+2,4,4),Color(1,1,1,0.08))

func _tf(rx:int,ry:int,chk:bool)->void:
	_tg(rx,ry,chk); draw_rect(Rect2(rx+3,ry+7,4,20),Color("#8a5020"))
	draw_rect(Rect2(rx+25,ry+7,4,20),Color("#8a5020")); draw_rect(Rect2(rx+3,ry+9,TS-6,3),Color("#a86030"))
	draw_rect(Rect2(rx+3,ry+19,TS-6,3),Color("#a86030"))

func _tsgn(rx:int,ry:int,chk:bool)->void:
	_ts(rx,ry,chk); draw_rect(Rect2(rx+13,ry+14,5,16),Color("#6a3808"))
	draw_rect(Rect2(rx+5,ry+7,22,12),Color("#aa7030")); draw_rect(Rect2(rx+5,ry+7,22,12),Color("#ffd700"),false,1.5)

# ── Quest items ───────────────────────────────────────────────────────────────
func _draw_quest_items()->void:
	var aq:=QuestManager.get_active_quest(_world)
	if aq.is_empty(): return
	for qi in QUEST_ITEMS.get(_world,[]):
		if GameManager.has_item(qi.id): continue
		var rx=qi.pos.x*TS; var ry=qi.pos.y*TS
		var g:=0.5+0.5*sin(_time*4.0+qi.pos.x)
		var wcol:=Color("#44aaff") if _world=="math" else (Color("#ffcc44") if _world=="english" else Color("#cc44ff"))
		draw_rect(Rect2(rx+10,ry+8,12,14),wcol*Color(1,1,1,g))
		draw_rect(Rect2(rx+13,ry+4,6,5),Color(1,1,1,g))
		draw_rect(Rect2(rx+9,ry+11,14,3),Color(1,1,1,g*0.4))

func _draw_item_sparkle()->void:
	var item=MAIN_ITEM.get(_world,{})
	if item.is_empty() or GameManager.has_item(item.get("id","")): return
	var p=item.pos; var rx=p.x*TS; var ry=p.y*TS
	var g:=0.55+0.45*sin(_time*3.5); var g2:=0.55+0.45*sin(_time*3.5+PI)
	var col:=Color("#44aaff") if _world=="math" else (Color("#ffcc44") if _world=="english" else Color("#cc44ff"))
	draw_rect(Rect2(rx+9,ry+8,14,15),col*Color(1,1,1,g)); draw_rect(Rect2(rx+12,ry+11,8,10),Color(1,1,1,g*0.55))
	draw_rect(Rect2(rx+14,ry+2,4,7),Color(1,1,1,g)); draw_rect(Rect2(rx+10,ry+5,12,3),Color(1,1,1,g2*0.55))

func _draw_gym_banner()->void:
	var fnt:=ThemeDB.fallback_font
	var gnames:={"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	var gcols:={"math":Color("#44aaff"),"english":Color("#ffd700"),"music":Color("#cc44ff")}
	var gcol=gcols.get(_world,Color.WHITE)
	draw_rect(Rect2(150,198,180,20),Color(0,0,0,0.72)); draw_rect(Rect2(150,198,180,20),gcol*Color(1,1,1,0.6),false,2.0)
	draw_string(fnt,Vector2(158,212),"★  "+gnames.get(_world,"")+"  ★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)

func _draw_npcs()->void:
	for npc in WORLD_NPCS.get(_world,[]):
		_draw_npc(npc.pos.x*TS,npc.pos.y*TS,npc.color,npc.get("type","normal"))

func _draw_npc(px:int,py:int,shirt:Color,typ:String="normal")->void:
	draw_rect(Rect2(px+5,py+27,9,4),Color("#111111")); draw_rect(Rect2(px+18,py+27,9,4),Color("#111111"))
	draw_rect(Rect2(px+7,py+18,8,11),Color("#2a4a90")); draw_rect(Rect2(px+17,py+18,8,11),Color("#2a4a90"))
	draw_rect(Rect2(px+7,py+18,16,4),Color("#3a5aaa"))
	draw_rect(Rect2(px+5,py+10,22,10),shirt); draw_rect(Rect2(px+5,py+10,22,3),shirt.lightened(0.22))
	draw_rect(Rect2(px+1,py+11,5,9),Color("#f0c090")); draw_rect(Rect2(px+26,py+11,5,9),Color("#f0c090"))
	draw_rect(Rect2(px+8,py+2,16,10),Color("#f0c090")); draw_rect(Rect2(px+9,py+2,14,4),Color("#f8d0a8"))
	draw_rect(Rect2(px+8,py+2,16,4),Color("#4a2808"))
	draw_rect(Rect2(px+11,py+8,4,3),Color("#111111")); draw_rect(Rect2(px+18,py+8,4,3),Color("#111111"))
	# Special markers
	if typ=="quest_giver":
		draw_rect(Rect2(px+11,py-8,10,10),Color("#ffd700"))
		var fnt:=ThemeDB.fallback_font
		draw_string(fnt,Vector2(px+13,py-1),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#000000"))
	elif typ=="duel":
		draw_rect(Rect2(px+11,py-8,10,10),Color("#ff4422"))
		var fnt:=ThemeDB.fallback_font
		draw_string(fnt,Vector2(px+14,py-1),"⚔",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#ffffff"))

func _draw_player()->void:
	var px:=int(_p_pixel.x); var py:=int(_p_pixel.y)
	var fr:=_p_frame if _p_moving else 0
	var lo:=-3 if fr==0 else 3; var ro:=3 if fr==0 else -3
	draw_rect(Rect2(px+5,py+30,22,5),Color(0,0,0,0.22))
	draw_rect(Rect2(px+5+lo,py+26,9,5),Color("#111111")); draw_rect(Rect2(px+18+ro,py+26,9,5),Color("#111111"))
	draw_rect(Rect2(px+4+lo,py+29,11,3),Color("#222222")); draw_rect(Rect2(px+17+ro,py+29,11,3),Color("#222222"))
	draw_rect(Rect2(px+6,py+17,9,11),Color("#1a3a8f")); draw_rect(Rect2(px+17,py+17,9,11),Color("#1a3a8f"))
	draw_rect(Rect2(px+7,py+17,16,4),Color("#2a4aaa")); draw_rect(Rect2(px+14,py+18,4,3),Color("#ffd700"))
	draw_rect(Rect2(px+4,py+9,24,10),Color("#cc1818")); draw_rect(Rect2(px+4,py+9,24,3),Color("#e02020"))
	draw_rect(Rect2(px+4,py+15,24,4),Color("#aa1010")); draw_rect(Rect2(px+13,py+9,6,4),Color("#e8e8e8"))
	draw_rect(Rect2(px+0,py+10,5,10),Color("#f0c090")); draw_rect(Rect2(px+27,py+10,5,10),Color("#f0c090"))
	draw_rect(Rect2(px+7,py+1,18,10),Color("#f0c090")); draw_rect(Rect2(px+8,py+1,16,4),Color("#f8d0a8"))
	draw_rect(Rect2(px+7,py+8,18,3),Color("#d8a878")); draw_rect(Rect2(px+6,py+1,20,5),Color("#cc1818"))
	draw_rect(Rect2(px+4,py+4,24,3),Color("#cc1818")); draw_rect(Rect2(px+5,py+2,18,2),Color("#e02020"))
	draw_rect(Rect2(px+14,py+2,5,4),Color("#ffd700"))
	if _p_dir==0:
		draw_rect(Rect2(px+10,py+7,4,3),Color("#111111")); draw_rect(Rect2(px+18,py+7,4,3),Color("#111111"))
		draw_rect(Rect2(px+11,py+7,2,2),Color(1,1,1,0.55)); draw_rect(Rect2(px+19,py+7,2,2),Color(1,1,1,0.55))
	elif _p_dir==2:
		draw_rect(Rect2(px+9,py+7,4,3),Color("#111111")); draw_rect(Rect2(px+10,py+7,2,2),Color(1,1,1,0.45))
	elif _p_dir==3:
		draw_rect(Rect2(px+19,py+7,4,3),Color("#111111")); draw_rect(Rect2(px+20,py+7,2,2),Color(1,1,1,0.45))

func _draw_ui()->void:
	var fnt=ThemeDB.fallback_font; var town=TOWN_NAMES.get(_world,"")
	draw_rect(Rect2(5,5,134,22),Color(0,0,0,0.52)); draw_rect(Rect2(5,5,134,22),Color(0.5,0.5,0.9,0.38),false,1.0)
	draw_string(fnt,Vector2(11,21),town,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffffff"))
	# ESC hint
	draw_rect(Rect2(338,5,136,16),Color(0,0,0,0.4))
	draw_string(fnt,Vector2(342,17),"ESC = World Map",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.6,0.6,0.8))
	# Quest indicator
	var aq:=QuestManager.get_active_quest(_world)
	if not aq.is_empty() and not GameManager.quest_done(aq.id):
		var step:=QuestManager.get_quest_step(aq)
		var total_items=aq.get("item_ids",[]).size()
		draw_rect(Rect2(5,28,200,16),Color(0,0,0,0.45))
		draw_string(fnt,Vector2(9,41),"Quest: "+aq.title+" ["+str(step)+"/"+str(max(total_items,1))+"]",
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ffd700"))
