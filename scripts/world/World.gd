# World.gd v1.1 — FIXED: bounds passed to player, NPC loop guard, camera clamp
extends Node2D

signal change_scene(scene_name: String, data: Dictionary)

const TS   := 32
const COLS := 20
const ROWS := 15

const T_GRASS := 0; const T_TREE := 1; const T_HOUSE_TOP := 2; const T_HOUSE_FRONT := 3
const T_PATH  := 4; const T_GYM_TOP := 5; const T_GYM_FRONT := 6; const T_ITEM := 7
const T_WATER := 8; const T_SAND  := 9; const T_STONE := 10
const T_DOOR  := 12; const T_SIGN := 11

const WALKABLE := [T_GRASS, T_PATH, T_ITEM, T_SAND, T_DOOR]

const MAPS := {
"math": [
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
[1,0,0,0,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
[1,0,2,2,8,8,0,2,2,0,0,0,2,2,0,0,0,0,0,1],
[1,0,2,2,8,0,0,2,2,0,0,0,2,2,0,11,11,0,0,1],
[1,0,12,0,0,0,0,12,0,0,0,0,12,0,0,11,0,0,0,1],
[1,0,0,0,4,4,4,4,4,4,4,4,0,0,0,0,7,0,0,1],
[1,0,0,4,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,1],
[1,0,4,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,1],
[1,0,4,0,2,2,0,0,0,0,0,2,2,4,0,7,0,0,0,1],
[1,0,0,4,2,2,0,0,0,0,0,2,2,0,4,0,0,0,0,1],
[1,0,0,0,12,0,4,4,4,6,4,4,4,0,0,0,0,7,0,1],
[1,0,0,0,0,4,5,5,5,5,5,5,5,4,0,0,0,0,0,1],
[1,0,0,0,4,4,4,4,4,4,4,4,4,4,4,0,0,0,0,1],
[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
],
"english": [
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
[1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1],
[1,9,2,2,9,9,9,2,2,9,9,9,2,2,9,9,9,9,9,1],
[1,9,2,2,9,9,9,2,2,9,9,9,2,2,9,11,11,9,9,1],
[1,9,12,9,9,9,9,12,9,9,9,9,12,9,9,11,9,9,9,1],
[1,9,9,9,4,4,4,4,4,4,4,4,9,9,9,9,7,9,9,1],
[1,9,9,4,9,9,9,9,9,9,9,9,4,9,9,9,9,9,9,1],
[1,9,4,9,9,9,9,9,9,9,9,9,9,4,9,9,9,9,9,1],
[1,9,4,9,2,2,9,9,9,9,9,2,2,4,9,7,9,9,9,1],
[1,9,9,4,2,2,9,9,9,9,9,2,2,9,4,9,9,9,9,1],
[1,9,9,9,12,9,4,4,4,6,4,4,4,9,9,9,9,7,9,1],
[1,9,9,9,9,4,5,5,5,5,5,5,5,4,9,9,9,9,9,1],
[1,9,9,9,4,4,4,4,4,4,4,4,4,4,4,9,9,9,9,1],
[1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,1],
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
],
"music": [
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
[1,0,2,2,0,0,0,2,2,0,0,0,2,2,0,0,0,0,0,1],
[1,0,2,2,0,0,0,2,2,0,0,0,2,2,0,11,11,0,0,1],
[1,0,12,0,0,0,0,12,0,0,0,0,12,0,0,11,0,0,0,1],
[1,0,0,0,4,4,4,4,4,4,4,4,0,0,0,0,7,0,0,1],
[1,0,0,4,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,1],
[1,0,4,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,1],
[1,0,4,0,2,2,0,0,10,10,0,2,2,4,0,7,0,0,0,1],
[1,0,0,4,2,2,0,0,10,0,0,2,2,0,4,0,0,0,0,1],
[1,0,0,0,12,0,4,4,4,6,4,4,4,0,0,0,0,7,0,1],
[1,0,0,0,0,4,5,5,5,5,5,5,5,4,0,0,0,0,0,1],
[1,0,0,0,4,4,4,4,4,4,4,4,4,4,4,0,0,0,0,1],
[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
],
}

const WORLD_NPCS := {
"math": [
	{"id":"t_var", "pos":Vector2i(7,2), "shirt":Color("#204488"),"type":"teacher","name":"Prof. Varius","subject":"Variables",
	 "lesson":["📖 LESSON: Variables","A VARIABLE is a letter for an\nunknown value.  Example: x + 3 = 7","To solve: subtract 3 from both sides.\n   x = 7 – 3 = 4","Variables can be any letter:\nx, y, n, t... they all work!","Lesson complete! +75 XP"],"xp":75},
	{"id":"t_eq",  "pos":Vector2i(4,8), "shirt":Color("#106010"),"type":"teacher","name":"Scholar Equa","subject":"Equations",
	 "lesson":["📖 LESSON: Equations","An EQUATION has an equals sign (=).\nBoth sides stay balanced.","2x + 4 = 10\n→ Subtract 4:  2x = 6\n→ Divide by 2: x = 3","Always do the SAME thing\nto BOTH sides!","Lesson complete! +75 XP"],"xp":75},
	{"id":"t_fn",  "pos":Vector2i(11,8),"shirt":Color("#880020"),"type":"teacher","name":"Elder Func","subject":"Functions",
	 "lesson":["📖 LESSON: Functions","A FUNCTION maps every input\nto exactly ONE output.","f(x) = 2x + 1\nIf x = 3:  f(3) = 2(3)+1 = 7","Domain = valid inputs\nRange = all possible outputs","Lesson complete! +75 XP"],"xp":75},
	{"id":"npc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Mathopolis!","Talk to the ? Teachers to\nlearn and earn 75 XP each!","You need Level 5 for the Gym.\nThat's only 400 XP total!"]},
	{"id":"npc2","pos":Vector2i(15,5),"shirt":Color("#30a030"),"xp":50,"lines":["A variable holds the place\nfor what we don't know yet!","Name the unknown and you\nhave begun to solve it."]},
	{"id":"npc3","pos":Vector2i(17,8),"shirt":Color("#a03030"),"xp":50,"lines":["There are 20 gym badges\nin Math World!","Get them all and challenge\nSilver Mountain!"]},
	{"id":"npc4","pos":Vector2i(18,10),"shirt":Color("#9090b0"),"xp":50,"lines":["Algebra: every equation\nholds a hidden truth.","Find x and you find the answer."]},
	{"id":"npc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,"lines":["I won a Knowledge Duel\nby answering all 7 correctly!","Each duel win gives 150 XP!\nChallenge the ⚔ rival nearby."]},
	{"id":"quest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"mq1",
	 "lines":["I lost 3 Formula Stones\naround town!","Find them all and I'll\ngive you 200 XP + Gold!"]},
	{"id":"duel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Rival Kira","accuracy":0.55,"reward_xp":150},
	 "lines":["Knowledge Duel!","7 questions. 3 lives each.","Correct = you attack!\nWrong = you take damage!","Win for 150 XP!"]},
	{"id":"duel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Scholar Zax","accuracy":0.65,"reward_xp":150},
	 "lines":["I'm Scholar Zax!\nChampion duelist!","Think you can beat me\nat algebra questions?"]},
	{"id":"item_sage","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["I have a rare Algebra Scroll!\nTake it — it's worth 150 XP!"]},
],
"english": [
	{"id":"et_noun","pos":Vector2i(7,2),"shirt":Color("#884400"),"type":"teacher","name":"Wordsmith Nora","subject":"Nouns",
	 "lesson":["📖 LESSON: Nouns","A NOUN names a person, place,\nthing, or idea.","Common: city, book, river\nProper: London, Bible, Nile","Collective: flock, team\nAbstract: freedom, joy","Lesson complete! +75 XP"],"xp":75},
	{"id":"et_verb","pos":Vector2i(4,8),"shirt":Color("#006040"),"type":"teacher","name":"Scholar Verbis","subject":"Verbs",
	 "lesson":["📖 LESSON: Verbs","VERBS are action words\nor states of being.","Past: walked  Present: walks\nFuture: will walk","Irregular: go→went, see→saw,\nrun→ran, be→was","Lesson complete! +75 XP"],"xp":75},
	{"id":"et_adj","pos":Vector2i(11,8),"shirt":Color("#602060"),"type":"teacher","name":"Poet Adj","subject":"Adjectives",
	 "lesson":["📖 LESSON: Adjectives","ADJECTIVES describe nouns.\n'The tall ancient tower'","Tall, ancient = adjectives\n→ they describe 'tower'","Comparison:\nbig→bigger→biggest","Lesson complete! +75 XP"],"xp":75},
	{"id":"enpc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Lexicon City!\nWords have power here!","Talk to the ? Teachers first!\nThen challenge the gym!"]},
	{"id":"enpc2","pos":Vector2i(15,5),"shirt":Color("#30a080"),"xp":50,"lines":["Proper nouns are always\ncapitalized!","London, Arix, Monday\nare all proper nouns."]},
	{"id":"enpc3","pos":Vector2i(17,8),"shirt":Color("#cc8830"),"xp":50,"lines":["Nouns, verbs, adjectives...\nthey're the building blocks!","Master them all and\nbecome Kaiser of Language!"]},
	{"id":"enpc4","pos":Vector2i(18,10),"shirt":Color("#b090a0"),"xp":50,"lines":["The pen is mightier\nthan the sword!"]},
	{"id":"enpc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,"lines":["Dueling sharpens knowledge!\nChallenge ⚔ Syl for XP!"]},
	{"id":"equest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"eq1",
	 "lines":["I need 3 Word Scrolls\nfound around the city!","Find them all:\n200 XP + 50 Gold reward!"]},
	{"id":"eduel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Word Rival Syl","accuracy":0.5,"reward_xp":150},
	 "lines":["Grammar duel!","Prove your language skills!","Win for 150 XP!"]},
	{"id":"eduel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Lexicon Rex","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Lexicon Rex!\nThe greatest word duelist!","7 questions. Can you beat me?"]},
	{"id":"eitem","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Ancient Quill!\n+150 XP for you!"]},
],
"music": [
	{"id":"mt_staff","pos":Vector2i(7,2),"shirt":Color("#601088"),"type":"teacher","name":"Maestro Staffa","subject":"Staff & Clefs",
	 "lesson":["📖 LESSON: Staff & Clefs","The MUSICAL STAFF has 5 lines.\nLines (low→high): E G B D F","Spaces spell F-A-C-E from bottom!\n'Every Good Boy Does Fine'","Treble clef = higher notes\nBass clef = lower notes","Lesson complete! +75 XP"],"xp":75},
	{"id":"mt_notes","pos":Vector2i(4,8),"shirt":Color("#008060"),"type":"teacher","name":"Rhythm Master","subject":"Note Values",
	 "lesson":["📖 LESSON: Note Values","NOTE VALUES determine\nhow long a note is held.","Whole = 4 beats  Half = 2\nQuarter = 1  Eighth = ½","In 4/4 time: 4 quarter notes\nfit in one measure!","Lesson complete! +75 XP"],"xp":75},
	{"id":"mt_scale","pos":Vector2i(11,8),"shirt":Color("#800020"),"type":"teacher","name":"Elder Harmona","subject":"Scales",
	 "lesson":["📖 LESSON: Scales","A SCALE is notes in a pattern.\nMajor: W-W-H-W-W-W-H","C Major: C D E F G A B C\nAll white keys on piano!","Major = happy  Minor = sad","Lesson complete! +75 XP"],"xp":75},
	{"id":"mnpc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Harmonia!\nCity of eternal music!","Talk to ? Teachers and\nexplore for items!"]},
	{"id":"mnpc2","pos":Vector2i(15,5),"shirt":Color("#8030c0"),"xp":50,"lines":["Staff has 5 lines.\nSpaces spell F-A-C-E!"]},
	{"id":"mnpc3","pos":Vector2i(17,8),"shirt":Color("#c03060"),"xp":50,"lines":["Whole=4 beats. Half=2.\nQuarter=1. That's rhythm!"]},
	{"id":"mnpc4","pos":Vector2i(18,10),"shirt":Color("#a0a0c0"),"xp":50,"lines":["Music is mathematics\nyou can hear!"]},
	{"id":"mnpc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,"lines":["Duel wins give great XP!\nChallenge ⚔ Dex!"]},
	{"id":"mquest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"muq1",
	 "lines":["3 Musical Notes are lost\naround Harmonia!","Find them: 200 XP + 50 Gold!"]},
	{"id":"mduel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Beat Rival Dex","accuracy":0.45,"reward_xp":150},
	 "lines":["Music theory duel!","7 questions of rhythm\nand notes!","Win for 150 XP!"]},
	{"id":"mduel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Conductor Forte","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Conductor Forte!\nMaster of musical duels!"]},
	{"id":"mitem","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Resonant Note!\n+150 XP of musical wisdom!"]},
],
}

const WORLD_ITEMS := {
"math":    [{"id":"ms1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Formula Stone!\n+100 XP! +20 Gold!"},
			{"id":"ms2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found a Crystal Equation!\n+100 XP! +20 Gold!"},
			{"id":"ms3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found an Algebra Scroll!\n+100 XP! +20 Gold!"}],
"english": [{"id":"es1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Word Scroll!\n+100 XP! +20 Gold!"},
			{"id":"es2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found an Ancient Quill!\n+100 XP! +20 Gold!"},
			{"id":"es3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Grammar Tome!\n+100 XP! +20 Gold!"}],
"music":   [{"id":"mus1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Musical Note!\n+100 XP! +20 Gold!"},
			{"id":"mus2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found a Resonant Crystal!\n+100 XP! +20 Gold!"},
			{"id":"mus3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Harmony Scroll!\n+100 XP! +20 Gold!"}],
}

const ITEM_TRADE_ID := {"math":"math_gift","english":"eng_gift","music":"mus_gift"}
const ITEM_TRADE_XP := 150
const TOWN_NAMES    := {"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP     := {"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}
const GYM_DOOR_POS  := Vector2i(9, 10)   # gym door grid position

var _world:        String   = "math"
var _player:       Node2D   = null
var _npcs:         Array    = []
var _dialog:       Node     = null
var _hud:          Node     = null
var _dialog_open:  bool     = false
var _interact_cool:float    = 0.0   # NPC interaction cooldown (prevents loop)
var _time:         float    = 0.0
var _pending_duel: Dictionary = {}

func _ready() -> void:
	add_to_group("active_world")
	set_process(true)

func init_world(world_id: String, player_node: Node2D, dialog_node: Node, hud_node: Node) -> void:
	_world  = world_id
	_player = player_node
	_dialog = dialog_node
	_hud    = hud_node
	GameManager.active_world = world_id

	# Add player to group for dialog notification
	if not _player.is_in_group("player"):
		_player.add_to_group("player")
	# Add world to group so dialog can find it
	if not is_in_group("active_world"):
		add_to_group("active_world")

	# Set player start with map bounds passed explicitly
	var gp := GameManager.get_grid_pos()
	if not _is_walkable(gp): gp = Vector2i(7, 7)
	_player.set_grid_start(gp, _get_blocked(), COLS, ROWS)
	_player.connect("interact_at",  _on_interact)
	_player.connect("player_moved", _on_player_moved)

	_spawn_npcs()
	queue_redraw()

func set_dialog_open(v: bool) -> void:
	_dialog_open = v
	if not v:
		# Give 0.3s cooldown after dialog closes to prevent immediate re-trigger
		_interact_cool = 0.3

func _get_blocked() -> Array:
	var blocked := []
	var map = MAPS.get(_world, MAPS.math)
	for r in ROWS:
		for c in COLS:
			if map[r][c] not in WALKABLE:
				blocked.append(Vector2i(c, r))
	return blocked

func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= ROWS: return false
	return MAPS.get(_world, MAPS.math)[p.y][p.x] in WALKABLE

# ── NPC Spawning ──────────────────────────────────────────────────────────────
func _spawn_npcs() -> void:
	for n in _npcs:
		if is_instance_valid(n): n.queue_free()
	_npcs.clear()

	var npc_script := load("res://scripts/npc/NPC.gd")
	for ndata in WORLD_NPCS.get(_world, []):
		var n := Area2D.new()
		n.set_script(npc_script)
		n.connect("talk_to", _on_npc_talk)
		add_child(n)
		n.setup(ndata)
		_npcs.append(n)

# ── Interaction ───────────────────────────────────────────────────────────────
func _on_interact(front: Vector2i, _dir: int) -> void:
	# GUARD: don't interact while dialog is open or cooldown active
	if _dialog_open or _interact_cool > 0.0:
		return

	# Check NPCs
	for n in _npcs:
		if is_instance_valid(n) and n.data.get("pos") == front:
			n.activate()
			return

	# Check items (facing them)
	for item in WORLD_ITEMS.get(_world, []):
		if item.pos == front and not GameManager.has_item(item.id):
			_collect_item(item)
			return

	# Check gym door
	if front == GYM_DOOR_POS:
		_try_gym()
		return

	# Sign
	if _tile_at(front) == T_SIGN:
		_show_dialog(["Sign: '" + TOWN_NAMES.get(_world, "") + "'\n\nBecome Kaiser — learn,\nbattle, and conquer!"])

func _on_player_moved(gp: Vector2i) -> void:
	GameManager.set_grid_pos(gp)
	# Auto-collect items when stepping on them
	for item in WORLD_ITEMS.get(_world, []):
		if item.pos == gp and not GameManager.has_item(item.id):
			_collect_item(item)
			return
	# Small random XP on movement (4% chance)
	if randf() < 0.04:
		var amt := randi_range(5, 15)
		GameManager.add_xp(amt)
		if _hud and _hud.has_method("show_xp_gain"):
			_hud.show_xp_gain(amt)

func _on_npc_talk(ndata: Dictionary) -> void:
	# GUARD: prevent re-entry
	if _dialog_open or _interact_cool > 0.0:
		return

	match ndata.get("type", "normal"):
		"teacher":     _handle_teacher(ndata)
		"quest_giver": _handle_quest_giver(ndata)
		"duel":        _handle_duel_invite(ndata)
		"item_trade":  _handle_item_trade(ndata)
		_:             _handle_normal_npc(ndata)

func _handle_teacher(t: Dictionary) -> void:
	var lines  = t.get("lesson", []).duplicate()
	var already:= GameManager.learned_from(t.id)
	if not already:
		GameManager.mark_learned(t.id)
		_show_dialog(lines, func():
			GameManager.add_xp(t.get("xp", 75))
			if _hud: _hud.show_xp_gain(t.get("xp", 75))
		)
	else:
		lines.append("(Already learned — no bonus XP)")
		_show_dialog(lines)

func _handle_quest_giver(ndata: Dictionary) -> void:
	var qid = ndata.get("quest_id", "")
	if GameManager.quest_done(qid):
		_show_dialog(["Thanks again, " + GameManager.player_name + "!\nQuest already complete!"])
		return
	_show_dialog(ndata.get("lines", []))

func _handle_duel_invite(ndata: Dictionary) -> void:
	# Store duel opponent — launch AFTER dialog fully closes (not in callback)
	_pending_duel = ndata.get("opponent", {})
	var lines = ndata.get("lines", []).duplicate()
	lines.append("Dialog will close.\nDuel starts in 1 second...")
	_show_dialog(lines)
	# Launch duel via timer (NOT in dialog callback — avoids loop)
	get_tree().create_timer(0.8).connect("timeout", func():
		if not _pending_duel.is_empty() and not _dialog_open:
			var d := _pending_duel.duplicate()
			_pending_duel = {}
			change_scene.emit("duel", {"opponent": d, "world": _world})
	)

func _handle_item_trade(ndata: Dictionary) -> void:
	var trade_id = ITEM_TRADE_ID.get(_world, "gift")
	if GameManager.has_item(trade_id):
		_show_dialog(["You already received this gift!\nOnly one per world."])
		return
	GameManager.collect_item(trade_id)
	_show_dialog(ndata.get("lines", []), func():
		GameManager.add_xp(ITEM_TRADE_XP)
		if _hud: _hud.show_xp_gain(ITEM_TRADE_XP)
	)

func _handle_normal_npc(ndata: Dictionary) -> void:
	var lines   = ndata.get("lines", []).duplicate()
	var npc_xp  = ndata.get("xp", 0)
	var first   = npc_xp > 0 and not GameManager.has_talked(ndata.id)
	if first:
		GameManager.mark_talked(ndata.id)
		lines.append("(+" + str(npc_xp) + " XP for listening!)")
		_show_dialog(lines, func():
			GameManager.add_xp(npc_xp)
			if _hud: _hud.show_xp_gain(npc_xp)
		)
	else:
		_show_dialog(lines)

func _collect_item(item: Dictionary) -> void:
	GameManager.collect_item(item.id)
	GameManager.add_xp(item.get("xp", 100))
	GameManager.add_gold(item.get("gold", 0))
	if _hud: _hud.show_xp_gain(item.get("xp", 100))
	_show_dialog([item.get("msg", "Found an item!")])
	_check_quest_progress()
	queue_redraw()

func _check_quest_progress() -> void:
	for qid in ["mq1", "eq1", "muq1"]:
		if GameManager.quest_done(qid): continue
		var q := QuestManager.get_quests(_world)
		for qd in q:
			if qd.id != qid: continue
			if QuestManager.all_items_collected(qd):
				GameManager.complete_quest(qid)
				GameManager.add_xp(qd.get("reward_xp", 200))
				GameManager.add_gold(qd.get("reward_gold", 50))
				if _hud: _hud.show_xp_gain(qd.get("reward_xp", 200))
				_show_dialog([qd.get("reward_msg", "Quest complete!")])
				return

func _try_gym() -> void:
	var badge = BADGE_MAP.get(_world, "")
	if GameManager.has_badge(badge):
		_show_dialog(["You already hold the " + badge + "!", "The gym leader bows respectfully."])
		return
	if not GameManager.can_challenge_gym(1):
		var need_xp = max(0, 5 * GameManager.XP_BASE - ((GameManager.get_level()-1)*GameManager.XP_BASE + GameManager.get_xp()))
		_show_dialog([
			"⚠  GYM SEALED  ⚠",
			"You need  Level 5  to enter.",
			"Your Level: " + str(GameManager.get_level()) + "\nXP still needed: " + str(need_xp),
			"Talk to ? Teachers and ⚔ Duel NPCs\nto gain XP quickly!"
		])
		return
	var teachers = WORLD_NPCS.get(_world, [])
	var learned  := 0
	for t in teachers:
		if t.get("type","") == "teacher" and GameManager.learned_from(t.id): learned += 1
	if learned == 0:
		_show_dialog(["The gym door is locked!", "Talk to the Teachers (? icon)\nand learn at least 1 lesson!", "Learning unlocks the gym."])
		return
	var db_map := {"math": AlgebraDB, "english": EnglishDB, "music": MusicDB}
	var db     = db_map.get(_world, AlgebraDB)
	var gdata  = db.get_gym1_leader()
	gdata["questions"] = db.get_gym1_questions()
	gdata["world"]     = _world
	AdaptiveAI.start_session(_world)
	change_scene.emit("battle", gdata)

func _show_dialog(lines: Array, cb: Callable = Callable()) -> void:
	if _dialog and _dialog.has_method("show_lines"):
		_dialog.show_lines(lines, cb)

func _tile_at(p: Vector2i) -> int:
	if p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= ROWS: return T_TREE
	return MAPS.get(_world, MAPS.math)[p.y][p.x]

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	if _interact_cool > 0.0:
		_interact_cool -= delta

	# Depth-sort NPCs by row
	for n in _npcs:
		if is_instance_valid(n):
			n.z_index = n.data.get("pos", Vector2i(0,0)).y

	# ESC = back to world map
	if Input.is_action_just_pressed("ui_cancel") and not _dialog_open:
		change_scene.emit("world_map", {})

	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
#  DRAWING — 2.5D painter's algorithm (back-to-front per row)
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	if not _player: return
	var map = MAPS.get(_world, MAPS.math)

	# Camera — centered on player, HARD CLAMPED to world bounds
	var px  := _player.position
	var cam := Vector2(
		clamp(px.x - 240.0, 0.0, COLS * TS - 480.0),
		clamp(px.y - 160.0, 0.0, ROWS * TS - 320.0)
	)

	# Draw base tiles
	for r in ROWS:
		for c in COLS:
			var sx := int(c * TS - cam.x)
			var sy := int(r * TS - cam.y)
			if sx < -TS or sx > 480 or sy < -TS or sy > 320: continue
			_draw_ground(map[r][c], sx, sy, c, r)

	# Draw items
	for item in WORLD_ITEMS.get(_world, []):
		if not GameManager.has_item(item.id):
			var sx := int(item.pos.x * TS - cam.x)
			var sy := int(item.pos.y * TS - cam.y)
			_draw_item_sparkle(sx, sy)

	# Draw raised objects + entities back-to-front
	for r in ROWS:
		for c in COLS:
			var t  = map[r][c]
			var sx := int(c * TS - cam.x)
			var sy := int(r * TS - cam.y)
			if sx < -TS or sx > 480 or sy < -TS or sy > 320: continue
			if t in [T_TREE, T_HOUSE_TOP, T_GYM_TOP, T_SIGN]:
				_draw_raised(t, sx, sy)

	# ── Gym banner ────────────────────────────────────────────────────────
	var gym_sx := int(GYM_DOOR_POS.x * TS - cam.x)
	var gym_sy := int(GYM_DOOR_POS.y * TS - cam.y)
	_draw_gym_banner(gym_sx, gym_sy)

	# Draw UI overlay (always on top)
	_draw_ui()

# ── GROUND TILES ─────────────────────────────────────────────────────────────
func _get_pal() -> Dictionary:
	match _world:
		"math":    return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058")}
		"english": return {"g0":Color("#e8d8a0"),"g1":Color("#d8c890"),"g2":Color("#a87840"),"g3":Color("#503010"),"path":Color("#f0e090"),"path2":Color("#e0d080")}
		"music":   return {"g0":Color("#281848"),"g1":Color("#201038"),"g2":Color("#100820"),"g3":Color("#080410"),"path":Color("#604890"),"path2":Color("#503878")}
	return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058")}

func _gym_col() -> Color:
	match _world:
		"math":
			return Color("#2060d0")
		"english":
			return Color("#c07010")
		"music":
			return Color("#8020c0")
		_:
			return Color("#2060d0")  # fallback

func _draw_ground(t:int,px:int,py:int,c:int,r:int)->void:
	var pal:=_get_pal(); var chk:=(c+r)%2==0; var DK:=Color("#181010")
	match t:
		T_GRASS,T_ITEM,T_DOOR,T_TREE,T_HOUSE_TOP,T_HOUSE_FRONT,T_GYM_TOP,T_GYM_FRONT,T_SIGN:
			draw_rect(Rect2(px,py,TS,TS),pal.g0)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),pal.g1)
			if (c*7+r*11)%8==0:
				draw_rect(Rect2(px+5,py+21,2,7),pal.g0.lightened(0.3))
				draw_rect(Rect2(px+14,py+19,2,9),pal.g0.lightened(0.25))
		T_PATH:
			draw_rect(Rect2(px,py,TS,TS),pal.path)
			for dy in range(0,TS,4):
				for dx in range(0,TS,4):
					if ((dx/4+dy/4+c+r)%2)==0: draw_rect(Rect2(px+dx,py+dy,4,4),pal.path2)
			draw_rect(Rect2(px,py,TS,1),pal.g2); draw_rect(Rect2(px,py+TS-1,TS,1),pal.g2)
		T_WATER:
			var wv:=0.4+0.6*sin(_time*1.8+(c+r)*0.45)
			var wc:=Color("#3050b0") if _world=="math" else (Color("#5090c0") if _world=="english" else Color("#102888"))
			draw_rect(Rect2(px,py,TS,TS),wc)
			for wy in [4,10,16,22,28]:
				draw_rect(Rect2(px+2,py+wy,TS-4,2),wc.lightened(0.28)*Color(1,1,1,wv))
		T_SAND:
			draw_rect(Rect2(px,py,TS,TS),Color("#e8d880") if chk else Color("#d8c870"))
		T_STONE:
			draw_rect(Rect2(px,py,TS,TS),Color("#706868"))
			draw_rect(Rect2(px+1,py+1,14,14),Color("#808080")); draw_rect(Rect2(px+17,py+1,14,14),Color("#808080"))
			draw_rect(Rect2(px+9,py+17,14,14),Color("#808080")); draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)
		_:
			draw_rect(Rect2(px,py,TS,TS),pal.g0)

# ── RAISED OBJECTS (2.5D depth trick) ────────────────────────────────────────
const WALL_H:=20; const GYM_WH:=24

func _draw_raised(t:int,px:int,py:int)->void:
	match t:
		T_TREE:     _iso_tree(px,py)
		T_HOUSE_TOP:_iso_house(px,py)
		T_GYM_TOP:  _iso_gym(px,py)
		T_SIGN:     _iso_sign(px,py)

func _iso_tree(px:int,py:int)->void:
	var pal:=_get_pal(); var DK:=Color("#181010")
	draw_rect(Rect2(px+4,py+26,24,7),Color(0,0,0,0.22))
	draw_rect(Rect2(px+12,py+18,8,14),Color("#6a4010"))
	draw_rect(Rect2(px+13,py+18,4,14),Color("#8a5820"))
	draw_rect(Rect2(px+12,py+18,8,14),DK,false,1.0)
	draw_rect(Rect2(px+2,py+16,28,14),pal.g3)
	draw_rect(Rect2(px+3,py+10,26,18),pal.g2)
	draw_rect(Rect2(px+6,py+5,20,17),pal.g1)
	draw_rect(Rect2(px+9,py+2,14,14),pal.g0)
	draw_rect(Rect2(px+11,py+2,10,8),pal.g0.lightened(0.2))
	draw_rect(Rect2(px+12,py+2,6,4),Color(1,1,1,0.2))
	draw_rect(Rect2(px+3,py+10,26,18),DK,false,1.0)

func _iso_house(px:int,py:int)->void:
	var pal:=_get_pal(); var DK:=Color("#181010")
	var wall=pal.get("wall",Color("#c8c8a0")); var roof=pal.get("roof",Color("#204880"))
	var win:=Color("#88ccff")
	draw_rect(Rect2(px+2,py+TS-2,TS-2,WALL_H+2),Color(0,0,0,0.2))
	draw_rect(Rect2(px,py,TS,TS-WALL_H),roof)
	draw_rect(Rect2(px,py,TS,5),roof.darkened(0.25))
	draw_rect(Rect2(px+2,py+2,TS-4,3),roof.lightened(0.15))
	draw_rect(Rect2(px+22,py-5,6,TS-WALL_H+3),roof.darkened(0.3))
	draw_rect(Rect2(px+21,py-7,8,4),DK)
	draw_rect(Rect2(px,py+TS-WALL_H,TS,WALL_H),wall)
	draw_rect(Rect2(px+TS-5,py+TS-WALL_H,5,WALL_H),wall.darkened(0.2))
	for wx in [4,18]:
		draw_rect(Rect2(px+wx,py+TS-WALL_H+2,10,10),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WALL_H+3,8,8),win)
		draw_rect(Rect2(px+wx+4,py+TS-WALL_H+3,1,8),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WALL_H+6,8,1),DK)
		draw_rect(Rect2(px+wx+1,py+TS-WALL_H+3,4,4),win.lightened(0.4))
	draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)

func _iso_gym(px:int,py:int)->void:
	var wc:=_gym_col(); var DK:=Color("#181010"); var glow:=0.35+0.35*sin(_time*2.5)
	draw_rect(Rect2(px+2,py+TS-2,TS-2,GYM_WH+2),Color(0,0,0,0.2))
	draw_rect(Rect2(px,py,TS,TS-GYM_WH),wc.darkened(0.3))
	draw_rect(Rect2(px,py,TS,5),wc.lightened(0.15))
	draw_rect(Rect2(px+2,py+2,TS-4,3),Color(1,1,1,0.12))
	draw_rect(Rect2(px,py+TS-GYM_WH,TS,GYM_WH),wc)
	draw_rect(Rect2(px+TS-5,py+TS-GYM_WH,5,GYM_WH),wc.darkened(0.25))
	draw_rect(Rect2(px+4,py+TS-GYM_WH,4,GYM_WH),wc.darkened(0.2))
	draw_rect(Rect2(px+TS-8,py+TS-GYM_WH,4,GYM_WH),wc.darkened(0.2))
	draw_rect(Rect2(px,py+TS-GYM_WH+8,TS,4),wc.lightened(0.15))
	draw_rect(Rect2(px+4,py+TS-4,TS-8,3),wc.lightened(0.5)*Color(1,1,1,glow))
	draw_rect(Rect2(px,py,TS,TS),DK,false,1.0)

func _iso_sign(px:int,py:int)->void:
	var DK:=Color("#181010")
	draw_rect(Rect2(px+13,py+10,6,22),Color("#8a5020")); draw_rect(Rect2(px+13,py+10,6,22),DK,false,1.0)
	draw_rect(Rect2(px+4,py+4,24,14),Color("#c07830")); draw_rect(Rect2(px+4,py+4,24,14),DK,false,1.5)
	draw_rect(Rect2(px+4,py+4,24,2),Color("#e89040"))

# ── GYM BANNER ────────────────────────────────────────────────────────────────
func _draw_gym_banner(gx:int,gy:int)->void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010"); var gcol:=_gym_col()
	var gnames:={"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	var bx:=gx-90; var by:=gy-24
	draw_rect(Rect2(bx,by,218,18),DK); draw_rect(Rect2(bx+1,by+1,216,16),Color("#f0f0e8"))
	draw_string(fnt,Vector2(bx+10,by+13),"★  "+gnames.get(_world,"Gym")+"  ★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)

# ── ITEM SPARKLE ─────────────────────────────────────────────────────────────
func _draw_item_sparkle(px:int,py:int)->void:
	var pal:=_get_pal(); var g:=0.5+0.5*sin(_time*4.5)
	var col=pal.g0.lightened(0.6)
	draw_rect(Rect2(px+10,py+8,12,16),col*Color(1,1,1,g))
	draw_rect(Rect2(px+12,py+10,8,12),Color(1,1,1,g*0.6))
	draw_rect(Rect2(px+10,py+8,12,16),Color("#181010"),false,1.0)
	draw_rect(Rect2(px+14,py+2,4,8),Color(1,1,1,g))
	draw_rect(Rect2(px+6,py+12,4,4),Color(1,1,1,g*0.4))
	draw_rect(Rect2(px+22,py+12,4,4),Color(1,1,1,g*0.4))

# ── UI OVERLAY ────────────────────────────────────────────────────────────────
func _draw_ui()->void:
	var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010"); var pal:=_get_pal()
	# Town name
	draw_rect(Rect2(3,3,140,18),DK); draw_rect(Rect2(4,4,138,16),Color("#f0f8f0"))
	draw_rect(Rect2(4,4,138,6),pal.g2)
	draw_string(fnt,Vector2(8,18),TOWN_NAMES.get(_world,""),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#f0f8f0"))
	# ESC hint
	draw_rect(Rect2(330,3,148,14),DK); draw_rect(Rect2(331,4,146,12),Color("#f0f0e0"))
	draw_string(fnt,Vector2(335,14),"ESC = World Map",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
	# Lesson tracker
	var teachers=WORLD_NPCS.get(_world,[]); var learned:=0
	for t in teachers: if t.get("type","")=="teacher" and GameManager.learned_from(t.id): learned+=1
	draw_rect(Rect2(3,23,140,14),DK); draw_rect(Rect2(4,24,138,12),Color("#f0f8f0"))
	draw_string(fnt,Vector2(8,34),"Lessons: "+str(learned)+"/3",HORIZONTAL_ALIGNMENT_LEFT,-1,10,pal.g2.lightened(0.3))
	# XP to Lv5 progress bar
	if GameManager.get_level()<5:
		var have:=(GameManager.get_level()-1)*GameManager.XP_BASE+GameManager.get_xp()
		var need:=5*GameManager.XP_BASE; var pct:=float(have)/float(need)
		draw_rect(Rect2(3,39,190,14),DK); draw_rect(Rect2(4,40,188,12),Color("#f0f8f0"))
		draw_rect(Rect2(4,40,int(188*pct),12),Color("#48c840"))
		draw_string(fnt,Vector2(7,50),"Lv5 unlock: "+str(int(pct*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
