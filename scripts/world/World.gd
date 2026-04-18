# World.gd v2.0 — FIXED camera: tiles at real world coords, Camera2D handles viewport
# No manual cam offset in _draw(). Player's Camera2D scrolls the view.
extends Node2D

signal change_scene(scene_name: String, data: Dictionary)

const TS   := 32
const COLS := 15   # 15×32=480 = viewport width → STATIC SCREEN
const ROWS := 10   # 10×32=320 = viewport height → STATIC SCREEN

# Tile IDs
const T_GRASS := 0; const T_TREE := 1; const T_HOUSE := 2
const T_PATH  := 4; const T_GYM  := 5; const T_GDOOR := 6
const T_ITEM  := 7; const T_WATER:= 8; const T_SAND  := 9
const T_STONE :=10; const T_DOOR :=12; const T_SIGN  :=11

const WALKABLE := [0, 4, 7, 9, 12]

const MAPS := {
"math": [
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
],
"english": [
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
[1,9,9,9,9,9,9,9,9,9,9,9,9,9,1],
[1,9,2,2,9,9,9,2,2,9,9,9,9,9,1],
[1,9,2,2,9,9,9,2,2,9,11,11,9,9,1],
[1,9,12,9,9,9,9,12,9,9,11,9,9,9,1],
[1,9,9,9,4,4,4,4,4,4,9,7,9,9,1],
[1,9,9,4,9,9,9,9,9,9,4,9,9,9,1],
[1,9,4,5,5,6,5,5,5,5,4,9,9,9,1],
[1,9,9,4,4,4,4,4,4,4,9,9,9,9,1],
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
],
"music": [
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
[1,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
[1,0,2,2,0,0,0,2,2,0,0,0,0,0,1],
[1,0,2,2,0,0,0,2,2,0,10,10,0,0,1],
[1,0,12,0,0,0,0,12,0,0,10,0,0,0,1],
[1,0,0,0,4,4,4,4,4,4,0,7,0,0,1],
[1,0,0,4,0,0,0,0,0,0,4,0,0,0,1],
[1,0,4,5,5,6,5,5,5,5,4,0,0,0,1],
[1,0,0,4,4,4,4,4,4,4,0,0,0,0,1],
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
],
}

const WORLD_NPCS := {
"math": [
	{"id":"t_var","pos":Vector2i(7,2),"shirt":Color("#204488"),"type":"teacher","name":"Prof. Varius","subject":"Variables","xp":75,
	 "lesson":["📖 LESSON: Variables","A VARIABLE is a letter for an\nunknown value. Example: x + 3 = 7","Solve: subtract 3 from both sides.\n   x = 7 – 3 = 4","Variables can be x, y, n, t...\nthey all work the same way.","✓ Lesson learned! +75 XP"]},
	{"id":"t_eq","pos":Vector2i(4,8),"shirt":Color("#106010"),"type":"teacher","name":"Scholar Equa","subject":"Equations","xp":75,
	 "lesson":["📖 LESSON: Equations","An EQUATION has an equals sign (=).\nBoth sides must stay balanced.","Example: 2x + 4 = 10\n→ Subtract 4:  2x = 6\n→ Divide by 2: x = 3","Always do the SAME thing\nto BOTH sides!","✓ Lesson learned! +75 XP"]},
	{"id":"t_fn","pos":Vector2i(11,8),"shirt":Color("#880020"),"type":"teacher","name":"Elder Func","subject":"Functions","xp":75,
	 "lesson":["📖 LESSON: Functions","A FUNCTION maps every input\nto exactly ONE output.","f(x) = 2x + 1\nIf x = 3:  f(3) = 2(3)+1 = 7","Domain = valid inputs\nRange = all possible outputs","✓ Lesson learned! +75 XP"]},
	{"id":"npc1","pos":Vector2i(13,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Mathopolis!","Talk to the ? Teachers to\nearn 75 XP each!","You need Level 5 for the Gym.\nOnly 400 XP total!"]},
	{"id":"npc2","pos":Vector2i(12,5),"shirt":Color("#30a030"),"xp":50,"lines":["A variable holds the place\nfor what we don't know yet!","Solve for x and you\nhave your answer."]},
	{"id":"npc3","pos":Vector2i(13,8),"shirt":Color("#a03030"),"xp":50,"lines":["There are 20 gym badges\nin Math World!","Collect them all and challenge\nSilver Mountain!"]},
	{"id":"npc4","pos":Vector2i(13,6),"shirt":Color("#9090b0"),"xp":50,"lines":["Algebra: every equation\nholds a hidden truth.","Find x and you find\nthe answer."]},
	{"id":"npc5","pos":Vector2i(12,6),"shirt":Color("#207060"),"xp":50,"lines":["Duel wins give 150 XP!\nChallenge ⚔ NPCs!","They have red icons\nabove their heads."]},
	{"id":"quest1","pos":Vector2i(12,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"mq1",
	 "lines":["I lost 3 Formula Stones\nscattered around town!","Find all 3 and bring them\nback for 200 XP + 50 Gold!"]},
	{"id":"duel1","pos":Vector2i(13,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Rival Kira","accuracy":0.55,"reward_xp":150},
	 "lines":["Hey! I challenge you to\na Knowledge Duel!","7 questions. 3 lives each.","Correct = you attack!\nWrong = you take damage!","Confirm to begin the duel!"]},
	{"id":"duel2","pos":Vector2i(13,7),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Scholar Zax","accuracy":0.65,"reward_xp":150},
	 "lines":["I'm Scholar Zax!\nChampion duelist!","7 equations stand between\nyou and 150 XP!","Confirm to begin the duel!"]},
	{"id":"trade1","pos":Vector2i(13,4),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["I have a rare Algebra Scroll!","Take it — it holds\n150 XP of wisdom!"]},
],
"english": [
	{"id":"et_noun","pos":Vector2i(7,2),"shirt":Color("#884400"),"type":"teacher","name":"Wordsmith Nora","subject":"Nouns","xp":75,
	 "lesson":["📖 LESSON: Nouns","A NOUN names a person, place,\nthing, or idea.","Common: city, book, river\nProper: London, Bible, Nile","Collective: flock, team\nAbstract: freedom, joy","✓ Lesson learned! +75 XP"]},
	{"id":"et_verb","pos":Vector2i(4,8),"shirt":Color("#006040"),"type":"teacher","name":"Scholar Verbis","subject":"Verbs","xp":75,
	 "lesson":["📖 LESSON: Verbs","VERBS are action or state words.","Past: walked  Present: walks\nFuture: will walk","Irregular: go→went  see→saw\nrun→ran  be→was","✓ Lesson learned! +75 XP"]},
	{"id":"et_adj","pos":Vector2i(11,8),"shirt":Color("#602060"),"type":"teacher","name":"Poet Adj","subject":"Adjectives","xp":75,
	 "lesson":["📖 LESSON: Adjectives","ADJECTIVES describe nouns.\n'The tall ancient tower'","Tall and ancient = adjectives.\nThey modify 'tower'.","Comparison:\nbig → bigger → biggest","✓ Lesson learned! +75 XP"]},
	{"id":"enpc1","pos":Vector2i(13,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Lexicon City!\nWords have power here!","Talk to ? Teachers first!"]},
	{"id":"enpc2","pos":Vector2i(12,5),"shirt":Color("#30a080"),"xp":50,"lines":["Proper nouns are always\ncapitalized!","London, Arix, Monday\nare all proper nouns."]},
	{"id":"enpc3","pos":Vector2i(13,8),"shirt":Color("#cc8830"),"xp":50,"lines":["Master nouns, verbs, adjectives\nand become Kaiser of Language!"]},
	{"id":"enpc4","pos":Vector2i(13,6),"shirt":Color("#b090a0"),"xp":50,"lines":["The pen is mightier\nthan the sword!"]},
	{"id":"enpc5","pos":Vector2i(12,6),"shirt":Color("#207060"),"xp":50,"lines":["Duel ⚔ nearby for 150 XP!\nChallenge Syl!"]},
	{"id":"equest1","pos":Vector2i(12,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"eq1",
	 "lines":["I need 3 Word Scrolls!\nThey're scattered around town.","Find all 3:\n200 XP + 50 Gold reward!"]},
	{"id":"eduel1","pos":Vector2i(13,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Word Rival Syl","accuracy":0.5,"reward_xp":150},
	 "lines":["Grammar duel challenge!","Prove your language skills\nagainst mine!","Confirm to begin the duel!"]},
	{"id":"eduel2","pos":Vector2i(13,7),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Lexicon Rex","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Lexicon Rex!\nGreatest wordsmith duelist!","Can you beat me?\nConfirm to duel!"]},
	{"id":"etrade","pos":Vector2i(13,4),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Ancient Quill!\n+150 XP of linguistic wisdom!"]},
],
"music": [
	{"id":"mt_staff","pos":Vector2i(7,2),"shirt":Color("#601088"),"type":"teacher","name":"Maestro Staffa","subject":"Staff & Clefs","xp":75,
	 "lesson":["📖 LESSON: Staff & Clefs","The MUSICAL STAFF has 5 lines.\nLines low→high: E G B D F","Spaces spell F-A-C-E\n'Every Good Boy Does Fine'","Treble clef = higher notes\nBass clef = lower notes","✓ Lesson learned! +75 XP"]},
	{"id":"mt_notes","pos":Vector2i(4,8),"shirt":Color("#008060"),"type":"teacher","name":"Rhythm Master","subject":"Note Values","xp":75,
	 "lesson":["📖 LESSON: Note Values","NOTE VALUES = how long notes are held.","Whole = 4 beats  Half = 2\nQuarter = 1  Eighth = ½","In 4/4 time:\n4 quarter notes fill one measure!","✓ Lesson learned! +75 XP"]},
	{"id":"mt_scale","pos":Vector2i(11,8),"shirt":Color("#800020"),"type":"teacher","name":"Elder Harmona","subject":"Scales","xp":75,
	 "lesson":["📖 LESSON: Scales","A SCALE follows a specific\nnote pattern.","Major scale: W-W-H-W-W-W-H\n(W=whole step, H=half step)","C Major: C D E F G A B C\nAll white piano keys!","✓ Lesson learned! +75 XP"]},
	{"id":"mnpc1","pos":Vector2i(13,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Harmonia!\nCity of eternal music!","Talk to ? Teachers to learn\nand gain XP!"]},
	{"id":"mnpc2","pos":Vector2i(12,5),"shirt":Color("#8030c0"),"xp":50,"lines":["The staff has 5 lines.\nSpaces spell F-A-C-E!"]},
	{"id":"mnpc3","pos":Vector2i(13,8),"shirt":Color("#c03060"),"xp":50,"lines":["Whole=4 beats. Half=2.\nQuarter=1. That's the rhythm!"]},
	{"id":"mnpc4","pos":Vector2i(13,6),"shirt":Color("#a0a0c0"),"xp":50,"lines":["Music is mathematics\nyou can hear!"]},
	{"id":"mnpc5","pos":Vector2i(12,6),"shirt":Color("#207060"),"xp":50,"lines":["Duel wins give great XP!\nChallenge ⚔ Dex nearby!"]},
	{"id":"mquest1","pos":Vector2i(12,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"muq1",
	 "lines":["3 Musical Notes are lost\naround Harmonia!","Find them all:\n200 XP + 50 Gold!"]},
	{"id":"mduel1","pos":Vector2i(13,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Beat Rival Dex","accuracy":0.45,"reward_xp":150},
	 "lines":["Music theory duel!","7 questions of rhythm\nand staff knowledge!","Confirm to begin the duel!"]},
	{"id":"mduel2","pos":Vector2i(13,7),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Conductor Forte","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Conductor Forte!\nMaster of musical duels!","Confirm to begin the duel!"]},
	{"id":"mtrade","pos":Vector2i(13,4),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Resonant Note!\n+150 XP of musical wisdom!"]},
],
}

const WORLD_ITEMS := {
"math":    [{"id":"ms1","pos":Vector2i(11,5),"xp":100,"gold":20,"msg":"Found a Formula Stone!\n+100 XP  +20 Gold"},
			{"id":"ms2","pos":Vector2i(13,8),"xp":100,"gold":20,"msg":"Found a Crystal Equation!\n+100 XP  +20 Gold"},
			{"id":"ms3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found an Algebra Scroll!\n+100 XP  +20 Gold"}],
"english": [{"id":"es1","pos":Vector2i(11,5),"xp":100,"gold":20,"msg":"Found a Word Scroll!\n+100 XP  +20 Gold"},
			{"id":"es2","pos":Vector2i(13,8),"xp":100,"gold":20,"msg":"Found an Ancient Quill!\n+100 XP  +20 Gold"},
			{"id":"es3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Grammar Tome!\n+100 XP  +20 Gold"}],
"music":   [{"id":"mus1","pos":Vector2i(11,5),"xp":100,"gold":20,"msg":"Found a Musical Note!\n+100 XP  +20 Gold"},
			{"id":"mus2","pos":Vector2i(13,8),"xp":100,"gold":20,"msg":"Found a Resonant Crystal!\n+100 XP  +20 Gold"},
			{"id":"mus3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Harmony Scroll!\n+100 XP  +20 Gold"}],
}
const ITEM_TRADE_ID := {"math":"math_gift","english":"eng_gift","music":"mus_gift"}
const TOWN_NAMES    := {"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP     := {"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}
const GYM_DOOR_POS  := Vector2i(5, 7)

var _world:        String    = "math"
var _player:       Node2D    = null
var _npcs:         Array     = []
var _dialog:       Node      = null
var _hud:          Node      = null
var _dialog_open:  bool      = false
var _interact_cool:float     = 0.0
var _time:         float     = 0.0
# Duel pending — set during dialog, launched on dialog close
var _pending_duel_opponent: Dictionary = {}
var _pending_duel_world:    String     = ""

func _ready() -> void:
	add_to_group("active_world")
	set_process(true)

func init_world(wid: String, player: Node2D, dialog: Node, hud: Node) -> void:
	_world  = wid; _player = player; _dialog = dialog; _hud = hud
	GameManager.active_world = wid
	if not _player.is_in_group("player"): _player.add_to_group("player")
	var gp := GameManager.get_grid_pos()
	if not _is_walkable(gp): gp = Vector2i(7, 7)
	_player.set_grid_start(gp, _get_blocked(), COLS, ROWS)
	_player.connect("interact_at",  _on_interact)
	_player.connect("player_moved", _on_player_moved)
	_spawn_npcs()
	queue_redraw()

func set_dialog_open(v: bool) -> void:
	_dialog_open = v
	if not v: _interact_cool = 0.3

func _get_blocked() -> Array:
	var blocked = []; var map = MAPS.get(_world, MAPS.math)
	for r in ROWS:
		for c in COLS:
			if map[r][c] not in WALKABLE: blocked.append(Vector2i(c, r))
	return blocked

func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= ROWS: return false
	return MAPS.get(_world, MAPS.math)[p.y][p.x] in WALKABLE

# ── NPC spawning ──────────────────────────────────────────────────────────────
func _spawn_npcs() -> void:
	for n in _npcs: if is_instance_valid(n): n.queue_free()
	_npcs.clear()
	var nscript := load("res://scripts/npc/NPC.gd")
	for nd in WORLD_NPCS.get(_world, []):
		var n := Area2D.new(); n.set_script(nscript)
		n.connect("talk_to", _on_npc_talk)
		add_child(n); n.setup(nd); _npcs.append(n)

# ── Interaction ───────────────────────────────────────────────────────────────
func _on_interact(front: Vector2i, _dir: int) -> void:
	if _dialog_open or _interact_cool > 0.0: return
	for n in _npcs:
		if is_instance_valid(n) and n.data.get("pos") == front:
			n.activate(); return
	for item in WORLD_ITEMS.get(_world, []):
		if item.pos == front and not GameManager.has_item(item.id):
			_collect_item(item); return
	if front == GYM_DOOR_POS: _try_gym(); return
	if _tile_at(front) == T_SIGN:
		_show_dialog(["Sign: '" + TOWN_NAMES.get(_world,"") + "'\n\nBecome Kaiser!\nLearn, battle, conquer!"])

func _on_player_moved(gp: Vector2i) -> void:
	GameManager.set_grid_pos(gp)
	for item in WORLD_ITEMS.get(_world, []):
		if item.pos == gp and not GameManager.has_item(item.id):
			_collect_item(item); return
	if randf() < 0.04:
		var amt := randi_range(5, 15)
		GameManager.add_xp(amt)
		if _hud: _hud.show_xp_gain(amt)

func _on_npc_talk(nd: Dictionary) -> void:
	if _dialog_open or _interact_cool > 0.0: return
	match nd.get("type","normal"):
		"teacher":     _handle_teacher(nd)
		"quest_giver": _handle_quest(nd)
		"duel":        _handle_duel(nd)
		"item_trade":  _handle_trade(nd)
		_:             _handle_normal(nd)

func _handle_teacher(t: Dictionary) -> void:
	var lines = t.get("lesson", []).duplicate()
	if not GameManager.learned_from(t.id):
		GameManager.mark_learned(t.id)
		_show_dialog(lines, func():
			GameManager.add_xp(t.get("xp",75))
			if _hud: _hud.show_xp_gain(t.get("xp",75))
		)
	else:
		lines.append("(Already studied — review only)")
		_show_dialog(lines)

func _handle_quest(nd: Dictionary) -> void:
	var qid = nd.get("quest_id","")
	if GameManager.quest_done(qid):
		_show_dialog(["Quest already complete!\nThanks, " + GameManager.player_name + "!"])
		return
	_show_dialog(nd.get("lines",[]))

func _handle_duel(nd: Dictionary) -> void:
	# Store opponent, show invitation dialog.
	# Duel launches when dialog closes via callback.
	_pending_duel_opponent = nd.get("opponent", {})
	_pending_duel_world    = _world
	var lines = nd.get("lines",[]).duplicate()
	_show_dialog(lines, func():
		# After dialog closes, emit scene change for duel
		if not _pending_duel_opponent.is_empty():
			var opp := _pending_duel_opponent.duplicate()
			var w   := _pending_duel_world
			_pending_duel_opponent = {}; _pending_duel_world = ""
			change_scene.emit("duel", {"opponent": opp, "world": w})
	)

func _handle_trade(nd: Dictionary) -> void:
	var tid = ITEM_TRADE_ID.get(_world,"gift")
	if GameManager.has_item(tid):
		_show_dialog(["You already received this gift!"]); return
	GameManager.collect_item(tid)
	_show_dialog(nd.get("lines",[]), func():
		GameManager.add_xp(150); if _hud: _hud.show_xp_gain(150)
	)

func _handle_normal(nd: Dictionary) -> void:
	var lines = nd.get("lines",[]).duplicate()
	var xp    = nd.get("xp",0)
	if xp > 0 and not GameManager.has_talked(nd.id):
		GameManager.mark_talked(nd.id)
		lines.append("(+" + str(xp) + " XP!)")
		_show_dialog(lines, func():
			GameManager.add_xp(xp); if _hud: _hud.show_xp_gain(xp)
		)
	else:
		_show_dialog(lines)

func _collect_item(item: Dictionary) -> void:
	GameManager.collect_item(item.id)
	GameManager.add_xp(item.get("xp",100)); GameManager.add_gold(item.get("gold",0))
	if _hud: _hud.show_xp_gain(item.get("xp",100))
	_show_dialog([item.get("msg","Found an item!")])
	_check_quests(); queue_redraw()

func _check_quests() -> void:
	for qid in ["mq1","eq1","muq1"]:
		if GameManager.quest_done(qid): continue
		for qd in QuestManager.get_quests(_world):
			if qd.id != qid: continue
			if QuestManager.all_items_collected(qd):
				GameManager.complete_quest(qid)
				GameManager.add_xp(qd.get("reward_xp",200))
				GameManager.add_gold(qd.get("reward_gold",50))
				if _hud: _hud.show_xp_gain(qd.get("reward_xp",200))
				_show_dialog([qd.get("reward_msg","Quest complete!")])
				return

func _try_gym() -> void:
	# Determine which gym number to challenge based on badges earned
	var db_map := {"math": AlgebraDB, "english": EnglishDB, "music": MusicDB}
	var db     = db_map.get(_world, AlgebraDB)
	var badges := GameManager.get_badges()
	
	# World-specific badge sequence
	var badge_seq := {
		"math":    ["Variable Badge", "Equation Badge", "Function Badge"],
		"english": ["Grammar Badge",  "Verb Badge",     "Sentence Badge"],
		"music":   ["Rhythm Badge",   "Harmony Badge",  "Scale Badge"],
	}
	var seq   = badge_seq.get(_world, [])
	
	# Find next gym to challenge
	var gym_num := 1
	for i in seq.size():
		if GameManager.has_badge(seq[i]):
			gym_num = i + 2
		else:
			gym_num = i + 1
			break
	
	var badge = seq[min(gym_num - 1, seq.size() - 1)] if seq.size() > 0 else ""
	
	# Check if all 3 already earned
	if gym_num > seq.size():
		_show_dialog(["You have conquered all 3 gyms\nin this city!", "Continue to the next city\non your journey to Kaiser!"]); return
	
	if not GameManager.can_challenge_gym(gym_num):
		var need := gym_num * 5
		_show_dialog(["The gym entrance is sealed!",
			"You need Level " + str(need) + " to challenge\nGym " + str(gym_num) + ".",
			"Your Level: " + str(GameManager.get_level()) + "\n\nTalk to Teachers for XP!"]); return
	
	# Check if at least 1 lesson has been learned
	var talked_count := 0
	for npc in WORLD_NPCS.get(_world, []):
		if npc.get("type","") == "teacher" and GameManager.has_talked(npc.id):
			talked_count += 1
	if talked_count == 0:
		_show_dialog(["The gym door is locked!",
			"Talk to a ? Teacher NPC first!\nLearn at least 1 lesson."]); return
	
	AdaptiveAI.start_session(_world)
	
	var gdata: Dictionary
	match gym_num:
		1: gdata = db.get_gym1_leader(); gdata["questions"] = db.get_gym1_questions()
		2: gdata = db.get_gym2_leader(); gdata["questions"] = db.get_gym2_questions()
		3: gdata = db.get_gym3_leader(); gdata["questions"] = db.get_gym3_questions()
		_: gdata = db.get_gym1_leader(); gdata["questions"] = db.get_gym1_questions()
	gdata["world"] = _world
	change_scene.emit("battle", gdata)

func _show_dialog(lines: Array, cb: Callable = Callable()) -> void:
	if _dialog and _dialog.has_method("show_lines"):
		_dialog.show_lines(lines, cb)

func _tile_at(p: Vector2i) -> int:
	if p.x<0 or p.x>=COLS or p.y<0 or p.y>=ROWS: return 1
	return MAPS.get(_world,MAPS.math)[p.y][p.x]

func _process(delta: float) -> void:
	_time += delta
	if _interact_cool > 0.0: _interact_cool -= delta
	for n in _npcs:
		if is_instance_valid(n): n.z_index = n.data.get("pos",Vector2i(0,0)).y
	if Input.is_action_just_pressed("ui_cancel") and not _dialog_open:
		change_scene.emit("world_map",{})
	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
#  DRAWING — tiles at real world coordinates (Camera2D on player handles viewport)
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var map = MAPS.get(_world, MAPS.math)
	# Draw ground layer
	for r in ROWS:
		for c in COLS:
			_draw_ground(map[r][c], c*TS, r*TS, c, r)
	# Draw items
	for item in WORLD_ITEMS.get(_world,[]):
		if not GameManager.has_item(item.id):
			_draw_item_sparkle(item.pos.x*TS, item.pos.y*TS)
	# Draw raised objects back-to-front (painter's algorithm)
	for r in ROWS:
		for c in COLS:
			var t = map[r][c]
			if t in [T_TREE,T_HOUSE,T_GYM,T_SIGN]:
				_draw_raised(t, c*TS, r*TS)
	# Gym banner
	_draw_gym_banner(GYM_DOOR_POS.x*TS, GYM_DOOR_POS.y*TS)
	# UI drawn in CanvasLayer (HUD), not here

# ── Palette ───────────────────────────────────────────────────────────────────
func _pal() -> Dictionary:
	match _world:
		"math":    return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058"),"wall":Color("#c8c8a0"),"roof":Color("#204880")}
		"english": return {"g0":Color("#e8d8a0"),"g1":Color("#d8c890"),"g2":Color("#a87840"),"g3":Color("#503010"),"path":Color("#f0e090"),"path2":Color("#e0d080"),"wall":Color("#f0e8d0"),"roof":Color("#a03818")}
		"music":   return {"g0":Color("#281848"),"g1":Color("#201038"),"g2":Color("#100820"),"g3":Color("#080410"),"path":Color("#604890"),"path2":Color("#503878"),"wall":Color("#302048"),"roof":Color("#601080")}
	return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058"),"wall":Color("#c8c8a0"),"roof":Color("#204880")}

func _gcol() -> Color:
	match _world:
		"math":
			return Color("#2060d0")
		"english":
			return Color("#c07010")
		"music":
			return Color("#8020c0")

	return Color("#2060d0")  # default

# ── Ground tiles ──────────────────────────────────────────────────────────────
func _draw_ground(t:int, px:int, py:int, c:int, r:int) -> void:
	var p := _pal(); var ck := (c+r)%2==0; var DK := Color("#181010")
	match t:
		0,7,12,2,5:  # grass-based tiles
			draw_rect(Rect2(px,py,TS,TS), p.g0)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4), p.g1)
			if (c*7+r*11)%8==0:
				draw_rect(Rect2(px+5,py+21,2,7),p.g0.lightened(0.3))
				draw_rect(Rect2(px+14,py+19,2,9),p.g0.lightened(0.25))
			if (c*11+r*7)%14==0 and _world!="music":
				var fc:=Color("#f880a0") if p.g0.r>0.5 else Color("#f8c030")
				draw_rect(Rect2(px+14,py+19,4,4),fc)
		4:   # path
			draw_rect(Rect2(px,py,TS,TS),p.path)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),p.path2)
			draw_rect(Rect2(px,py,TS,1),p.g2); draw_rect(Rect2(px,py+TS-1,TS,1),p.g2)
			draw_rect(Rect2(px,py,1,TS),p.g2); draw_rect(Rect2(px+TS-1,py,1,TS),p.g2)
		6:   # gym front door tile — path
			draw_rect(Rect2(px,py,TS,TS),p.path)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),p.path2)
		8:   # water
			var wc:=Color("#3050b0") if _world=="math" else (Color("#5090c0") if _world=="english" else Color("#102888"))
			draw_rect(Rect2(px,py,TS,TS),wc)
			var wv:=0.4+0.6*sin(_time*1.8+(c+r)*0.45)
			for wy in [4,10,16,22,28]: draw_rect(Rect2(px+2,py+wy,TS-4,2),wc.lightened(0.28)*Color(1,1,1,wv))
		9:   # sand
			draw_rect(Rect2(px,py,TS,TS),Color("#e8d880") if ck else Color("#d8c870"))
		10:  # stone
			draw_rect(Rect2(px,py,TS,TS),Color("#706868"))
			draw_rect(Rect2(px+1,py+1,14,14),Color("#808080")); draw_rect(Rect2(px+17,py+1,14,14),Color("#808080"))
			draw_rect(Rect2(px+9,py+17,14,14),Color("#808080")); draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		1:   # tree — draw as tree
			draw_rect(Rect2(px,py,TS,TS),p.g0)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),p.g1)
		_:
			draw_rect(Rect2(px,py,TS,TS),p.g0)

# ── Raised objects (2.5D front-face technique) ────────────────────────────────
func _draw_raised(t:int, px:int, py:int) -> void:
	match t:
		1: _r_tree(px,py)
		2: _r_house(px,py)
		5: _r_gym(px,py)
		11:_r_sign(px,py)

const WH:=20   # wall height for 2.5D front face
const GH:=24   # gym wall height

func _r_tree(px:int,py:int)->void:
	var p:=_pal(); var DK:=Color("#181010")
	draw_rect(Rect2(px+4,py+26,24,7),Color(0,0,0,0.22))
	# Trunk front face
	draw_rect(Rect2(px+12,py+18,8,14),Color("#6a4010"))
	draw_rect(Rect2(px+13,py+18,4,14),Color("#8a5820"))
	draw_rect(Rect2(px+12,py+18,8,14),DK,false,1.0)
	# Layered crown (back-to-front depth)
	draw_rect(Rect2(px+2,py+16,28,14),p.g3)
	draw_rect(Rect2(px+3,py+10,26,18),p.g2)
	draw_rect(Rect2(px+6,py+5,20,17),p.g1)
	draw_rect(Rect2(px+9,py+2,14,14),p.g0)
	draw_rect(Rect2(px+11,py+2,10,8),p.g0.lightened(0.2))
	draw_rect(Rect2(px+12,py+2,6,4),Color(1,1,1,0.22))
	draw_rect(Rect2(px+3,py+10,26,18),DK,false,1.0)

func _r_house(px:int,py:int)->void:
	var p:=_pal(); var DK:=Color("#181010"); var WIN:=Color("#88ccff")
	# Shadow
	draw_rect(Rect2(px+2,py+TS-2,TS-2,WH+2),Color(0,0,0,0.2))
	# ROOF (top face viewed from above)
	draw_rect(Rect2(px,py,TS,TS-WH),p.roof)
	draw_rect(Rect2(px,py,TS,5),p.roof.darkened(0.25))
	draw_rect(Rect2(px+2,py+2,TS-4,3),p.roof.lightened(0.15))
	# Chimney 2.5D
	draw_rect(Rect2(px+22,py-5,6,TS-WH+3),p.roof.darkened(0.3))
	draw_rect(Rect2(px+21,py-7,8,4),DK)
	draw_rect(Rect2(px+22,py-6,6,3),Color("#505050"))
	# FRONT WALL — the 2.5D part
	draw_rect(Rect2(px,py+TS-WH,TS,WH),p.wall)
	draw_rect(Rect2(px+TS-5,py+TS-WH,5,WH),p.wall.darkened(0.2))
	# Windows on front wall
	for wx in [4, 18]:
		draw_rect(Rect2(px+wx,py+TS-WH+2,10,10),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WH+3,8,8),WIN)
		draw_rect(Rect2(px+wx+4,py+TS-WH+3,1,8),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WH+6,8,1),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WH+3,4,4),WIN.lightened(0.4))
	draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)

func _r_gym(px:int,py:int)->void:
	var wc:=_gcol(); var DK:=Color("#181010"); var glow:=0.35+0.35*sin(_time*2.5)
	draw_rect(Rect2(px+2,py+TS-2,TS-2,GH+2),Color(0,0,0,0.2))
	# TOP FACE
	draw_rect(Rect2(px,py,TS,TS-GH),wc.darkened(0.3))
	draw_rect(Rect2(px,py,TS,5),wc.lightened(0.15))
	draw_rect(Rect2(px+2,py+2,TS-4,3),Color(1,1,1,0.12))
	# FRONT WALL 2.5D
	draw_rect(Rect2(px,py+TS-GH,TS,GH),wc)
	draw_rect(Rect2(px+TS-5,py+TS-GH,5,GH),wc.darkened(0.25))
	# Pillars
	draw_rect(Rect2(px+4,py+TS-GH,4,GH),wc.darkened(0.2))
	draw_rect(Rect2(px+TS-8,py+TS-GH,4,GH),wc.darkened(0.2))
	# Band + glow strip
	draw_rect(Rect2(px,py+TS-GH+8,TS,4),wc.lightened(0.15))
	draw_rect(Rect2(px+4,py+TS-4,TS-8,3),wc.lightened(0.5)*Color(1,1,1,glow))
	draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)

func _r_sign(px:int,py:int)->void:
	var DK:=Color("#181010")
	draw_rect(Rect2(px+13,py+10,6,22),Color("#8a5020"))
	draw_rect(Rect2(px+13,py+10,6,22),DK,false,1.0)
	draw_rect(Rect2(px+4,py+4,24,14),Color("#c07830"))
	draw_rect(Rect2(px+4,py+4,24,14),DK,false,1.5)
	draw_rect(Rect2(px+4,py+4,24,2),Color("#e89040"))

func _draw_item_sparkle(px:int,py:int)->void:
	var g=0.5+0.5*sin(_time*4.5); var col=_pal().g0.lightened(0.6)
	draw_rect(Rect2(px+10,py+8,12,16),col*Color(1,1,1,g))
	draw_rect(Rect2(px+12,py+10,8,12),Color(1,1,1,g*0.6))
	draw_rect(Rect2(px+10,py+8,12,16),Color("#181010"),false,1.0)
	draw_rect(Rect2(px+14,py+2,4,8),Color(1,1,1,g))
	draw_rect(Rect2(px+6,py+12,4,4),Color(1,1,1,g*0.4))
	draw_rect(Rect2(px+22,py+12,4,4),Color(1,1,1,g*0.4))

func _draw_gym_banner(gx:int,gy:int)->void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010"); var gcol:=_gcol()
	var gnames:={"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	draw_rect(Rect2(gx-88,gy-24,218,18),DK)
	draw_rect(Rect2(gx-87,gy-23,216,16),Color("#f0f0e8"))
	draw_string(fnt,Vector2(gx-80,gy-10),"★  "+gnames.get(_world,"Gym")+"  ★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)
