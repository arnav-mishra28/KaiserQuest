# World.gd v1.0 — Main world scene: expanded map, NPCs, quests, duels
extends Node2D

signal change_scene(scene_name:String, data:Dictionary)

const TS   := 32
const COLS := 20   # expanded world
const ROWS := 15

# ── Tile IDs ──────────────────────────────────────────────────────────────────
const T_GRASS:=0; const T_TREE:=1; const T_HOUSE_TOP:=2; const T_HOUSE_FRONT:=3
const T_PATH:=4;  const T_GYM_TOP:=5; const T_GYM_FRONT:=6; const T_ITEM:=7
const T_WATER:=8; const T_SAND:=9; const T_STONE:=10; const T_FENCE:=10
const T_SIGN:=11

# Walkable tile IDs
const WALKABLE := [T_GRASS, T_PATH, T_ITEM, T_SAND, 12]  # 12 = door tile (grass)

# ── Expanded world maps ───────────────────────────────────────────────────────
const MAPS := {
"math": [
# 20 cols × 15 rows — expanded town with more NPCs and content
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

# ── NPC definitions (teachers give XP, quest givers chain quests, duel NPCs) ──
const WORLD_NPCS := {
"math": [
	# TEACHERS — 3 teachers × 75 XP = 225 XP total
	{"id":"t_var","pos":Vector2i(7,2),"shirt":Color("#204488"),"type":"teacher","name":"Prof. Varius","subject":"Variables",
	 "lesson":["📖 VARIABLES — a symbol for an\nunknown value. Example: x + 3 = 7",
			   "To solve: subtract 3 from both sides.\n   x = 7 - 3 = 4",
			   "Variables can be any letter:\nx, y, n, t... they all work!","Lesson learned! +75 XP!"],"xp":75},
	{"id":"t_eq","pos":Vector2i(4,8),"shirt":Color("#106010"),"type":"teacher","name":"Scholar Equa","subject":"Equations",
	 "lesson":["📖 EQUATIONS have an equals sign (=)\nBoth sides must stay balanced.",
			   "To solve 2x + 4 = 10:\n1. Subtract 4:  2x = 6\n2. Divide by 2: x = 3",
			   "Always do the SAME operation\nto BOTH sides!","Lesson learned! +75 XP!"],"xp":75},
	{"id":"t_fn","pos":Vector2i(11,8),"shirt":Color("#880020"),"type":"teacher","name":"Elder Func","subject":"Functions",
	 "lesson":["📖 FUNCTIONS map every input\nto exactly ONE output.",
			   "f(x) = 2x + 1\nIf x=3:  f(3) = 2(3)+1 = 7",
			   "Domain = valid inputs\nRange = all possible outputs","Lesson learned! +75 XP!"],"xp":75},
	# REGULAR NPCs — each gives XP on first talk (50 XP each = 250 XP total)
	{"id":"npc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,
	 "lines":["Welcome to Mathopolis!\nCity of equations!","The Gym needs Level 5!\nTalk to teachers to level up fast!"]},
	{"id":"npc2","pos":Vector2i(15,5),"shirt":Color("#30a030"),"xp":50,
	 "lines":["A variable holds the place\nfor what we don't know yet!","Name the unknown and you\nhave begun to solve it."]},
	{"id":"npc3","pos":Vector2i(17,8),"shirt":Color("#a03030"),"xp":50,
	 "lines":["20 gym badges in this world.\nGet them all for Silver Mountain!","I heard Kaiser adventurers\ncan earn hundreds of XP per duel!"]},
	{"id":"npc4","pos":Vector2i(18,10),"shirt":Color("#9090b0"),"xp":50,
	 "lines":["Algebra is the language\nof hidden answers.","Every equation is a puzzle.\nFind x!"]},
	{"id":"npc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,
	 "lines":["I once won a Knowledge Duel\nby getting all 7 questions right!","Each duel win gives you XP!\nChallenge the rival nearby."]},
	# QUEST GIVER
	{"id":"quest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"mq1",
	 "lines":["I lost 3 formula stones!\nThey're scattered around town.","Find them all and I'll\nreward you with 200 XP!"]},
	# DUEL CHALLENGERS (2 duels = up to 300 XP)
	{"id":"duel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Rival Kira","accuracy":0.55,"reward_xp":150},
	 "lines":["Hey! Knowledge Duel!","7 questions. First to\nlose 3 lives loses!","Win and I'll give you XP!"]},
	{"id":"duel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Scholar Zax","accuracy":0.65,"reward_xp":150},
	 "lines":["I'm Zax, champion duelist!","Think you can beat me at\nalgebra questions?","Only the best may pass!"]},
	# ITEM KEEPER
	{"id":"item_sage","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["I have a rare Algebra Scroll.\nIt contains great XP!","Press ENTER to receive it\nif you haven't already."]},
],
"english": [
	{"id":"et_noun","pos":Vector2i(7,2),"shirt":Color("#884400"),"type":"teacher","name":"Wordsmith Nora","subject":"Nouns",
	 "lesson":["📖 NOUNS name a person, place,\nthing, or idea.",
			   "Common nouns: city, book, river\nProper nouns: London, Bible, Nile",
			   "Collective: flock, team, class\nAbstract: freedom, joy, love","Lesson learned! +75 XP!"],"xp":75},
	{"id":"et_verb","pos":Vector2i(4,8),"shirt":Color("#006040"),"type":"teacher","name":"Scholar Verbis","subject":"Verbs",
	 "lesson":["📖 VERBS are action words\nor states of being.",
			   "Past: She walked.  Present: walks.\nFuture: will walk.",
			   "Irregular: go→went, see→saw,\nrun→ran, be→was","Lesson learned! +75 XP!"],"xp":75},
	{"id":"et_adj","pos":Vector2i(11,8),"shirt":Color("#602060"),"type":"teacher","name":"Poet Adj","subject":"Adjectives",
	 "lesson":["📖 ADJECTIVES describe nouns.\nExample: 'The tall ancient tower'",
			   "Tall and ancient = adjectives\nThey describe 'tower'",
			   "Comparison: big→bigger→biggest\ngood→better→best","Lesson learned! +75 XP!"],"xp":75},
	{"id":"enpc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Lexicon City!\nWords have power here!","Level 5 lets you challenge\nthe Noun Sanctum gym!"]},
	{"id":"enpc2","pos":Vector2i(15,5),"shirt":Color("#30a080"),"xp":50,"lines":["A proper noun names\na specific thing — and is capitalized!","London, Arix, Monday are\nall proper nouns."]},
	{"id":"enpc3","pos":Vector2i(17,8),"shirt":Color("#cc8830"),"xp":50,"lines":["Nouns, verbs, adjectives...\nthey're the building blocks of language!","Master them all and\nbecome Kaiser of Language!"]},
	{"id":"enpc4","pos":Vector2i(18,10),"shirt":Color("#b090a0"),"xp":50,"lines":["The pen is mightier\nthan the sword.","Master grammar and\nyou can master anything!"]},
	{"id":"enpc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,"lines":["Dueling sharpens your knowledge\nlike no textbook can!","Challenge Syl near the path\nfor XP rewards!"]},
	{"id":"equest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"eq1",
	 "lines":["I need 3 Word Scrolls found\naround Lexicon City!","Each scroll teaches a\nnew vocabulary word. Help me?"]},
	{"id":"eduel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Word Rival Syl","accuracy":0.5,"reward_xp":150},
	 "lines":["Grammar duel time!","Prove your language skills\nagainst mine!","Win for XP!"]},
	{"id":"eduel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Lexicon Rex","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Lexicon Rex!\nThe greatest wordsmith duelist!","7 questions. Can you beat me?"]},
	{"id":"eitem","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Ancient Quill!\nIt holds great wisdom... and XP!"]},
],
"music": [
	{"id":"mt_staff","pos":Vector2i(7,2),"shirt":Color("#601088"),"type":"teacher","name":"Maestro Staffa","subject":"Staff & Clefs",
	 "lesson":["📖 The MUSICAL STAFF has 5 lines.\nLines (low→high): E G B D F",
			   "Spaces spell F-A-C-E from bottom!\n'Every Good Boy Does Fine'",
			   "Treble clef = higher notes\nBass clef = lower notes","Lesson learned! +75 XP!"],"xp":75},
	{"id":"mt_notes","pos":Vector2i(4,8),"shirt":Color("#008060"),"type":"teacher","name":"Rhythm Master","subject":"Note Values",
	 "lesson":["📖 NOTE VALUES determine\nhow long a note is held.",
			   "Whole=4 beats  Half=2 beats\nQuarter=1 beat  Eighth=½ beat",
			   "In 4/4 time: 4 quarter notes\nfit in one measure!","Lesson learned! +75 XP!"],"xp":75},
	{"id":"mt_scale","pos":Vector2i(11,8),"shirt":Color("#800020"),"type":"teacher","name":"Elder Harmona","subject":"Scales",
	 "lesson":["📖 A SCALE is a sequence of notes\nfollowing a specific pattern.",
			   "Major scale: W-W-H-W-W-W-H\n(W=whole step, H=half step)",
			   "C Major: C D E F G A B C\nAll white keys on a piano!","Lesson learned! +75 XP!"],"xp":75},
	{"id":"mnpc1","pos":Vector2i(16,2),"shirt":Color("#e8c030"),"xp":50,"lines":["Welcome to Harmonia!\nCity of eternal music!","The staff has 5 lines.\nSpaces spell F-A-C-E!"]},
	{"id":"mnpc2","pos":Vector2i(15,5),"shirt":Color("#8030c0"),"xp":50,"lines":["Whole notes last 4 beats.\nHalf notes last 2. Quarter = 1.","Count the beat: 1-2-3-4!\nThat's 4/4 time!"]},
	{"id":"mnpc3","pos":Vector2i(17,8),"shirt":Color("#c03060"),"xp":50,"lines":["Major scales sound happy.\nMinor scales sound sad.","The pattern W-W-H-W-W-W-H\nmakes a major scale!"]},
	{"id":"mnpc4","pos":Vector2i(18,10),"shirt":Color("#a0a0c0"),"xp":50,"lines":["Music is mathematics\nyou can hear!","Every rhythm has a\nmathematical structure."]},
	{"id":"mnpc5","pos":Vector2i(16,13),"shirt":Color("#207060"),"xp":50,"lines":["Rhythm duels are my specialty!\nChallenge Dex near the fountain.","Duel wins give great XP bonuses!"]},
	{"id":"mquest1","pos":Vector2i(15,3),"shirt":Color("#20c060"),"type":"quest_giver","quest_id":"muq1",
	 "lines":["Three Musical Notes are\nlost around Harmonia!","Help me find them and\nI'll reward you well!"]},
	{"id":"mduel1","pos":Vector2i(17,5),"shirt":Color("#e05010"),"type":"duel",
	 "opponent":{"name":"Beat Rival Dex","accuracy":0.45,"reward_xp":150},
	 "lines":["Music theory duel!","I challenge you to\na battle of musical knowledge!","Win for XP!"]},
	{"id":"mduel2","pos":Vector2i(18,13),"shirt":Color("#8010e0"),"type":"duel",
	 "opponent":{"name":"Conductor Forte","accuracy":0.6,"reward_xp":150},
	 "lines":["I am Conductor Forte!\nMaster of musical duels!","7 questions stand between\nyou and victory!"]},
	{"id":"mitem","pos":Vector2i(19,7),"shirt":Color("#604020"),"type":"item_trade",
	 "lines":["Take this Resonant Note!\nIt holds ancient musical wisdom and XP!"]},
],
}

# ── Collectible items ─────────────────────────────────────────────────────────
const WORLD_ITEMS := {
"math":    [
	{"id":"ms1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Formula Stone!\n+100 XP! +20 Gold!"},
	{"id":"ms2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found a Crystal Equation!\n+100 XP! +20 Gold!"},
	{"id":"ms3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found an Algebra Scroll!\n+100 XP! +20 Gold!"},
],
"english": [
	{"id":"es1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Word Scroll!\n+100 XP! +20 Gold!"},
	{"id":"es2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found an Ancient Quill!\n+100 XP! +20 Gold!"},
	{"id":"es3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Grammar Tome!\n+100 XP! +20 Gold!"},
],
"music": [
	{"id":"mus1","pos":Vector2i(16,5),"xp":100,"gold":20,"msg":"Found a Musical Note!\n+100 XP! +20 Gold!"},
	{"id":"mus2","pos":Vector2i(18,8),"xp":100,"gold":20,"msg":"Found a Resonant Crystal!\n+100 XP! +20 Gold!"},
	{"id":"mus3","pos":Vector2i(15,12),"xp":100,"gold":20,"msg":"Found a Harmony Scroll!\n+100 XP! +20 Gold!"},
],
}

# Item trade XP (given once per world)
const ITEM_TRADE_XP := {"math":150,"english":150,"music":150}
const ITEM_TRADE_ID := {"math":"math_gift","english":"eng_gift","music":"mus_gift"}

# Quest definitions
const WORLD_QUESTS := {
"mq1": {"title":"Lost Formula Stones","item_ids":["ms1","ms2","ms3"],"reward_xp":200,"reward_gold":50,
		"reward_msg":"All 3 stones found!\n+200 XP! +50 Gold!"},
"eq1": {"title":"Missing Word Scrolls","item_ids":["es1","es2","es3"],"reward_xp":200,"reward_gold":50,
		"reward_msg":"All 3 scrolls found!\n+200 XP! +50 Gold!"},
"muq1":{"title":"The Lost Notes","item_ids":["mus1","mus2","mus3"],"reward_xp":200,"reward_gold":50,
		"reward_msg":"All 3 notes found!\n+200 XP! +50 Gold!"},
}

const TOWN_NAMES  := {"math":"Mathopolis","english":"Lexicon City","music":"Harmonia"}
const BADGE_MAP   := {"math":"Variable Badge","english":"Grammar Badge","music":"Rhythm Badge"}
const GYM_ENTRY   := {"math":Vector2i(9,10),"english":Vector2i(9,10),"music":Vector2i(9,10)}

# ── Runtime state ─────────────────────────────────────────────────────────────
var _world:  String   = "math"
var _player: Node2D   = null
var _npcs:   Array    = []
var _dialog: Node     = null
var _hud:    Node     = null
var _dialog_open:bool = false
var _time:   float    = 0.0

# For deferred actions after dialog
var _pending_battle: Dictionary = {}
var _pending_duel:   Dictionary = {}

func _ready()->void:
	set_process(true)

func init_world(world_id:String, player_node:Node2D, dialog_node:Node, hud_node:Node)->void:
	_world  = world_id
	_player = player_node
	_dialog = dialog_node
	_hud    = hud_node

	GameManager.active_world = world_id

	# Set player start position
	var gp := GameManager.get_grid_pos()
	if not _is_walkable_tile(gp): gp = Vector2i(7,7)
	_player.set_grid_start(gp, _get_blocked())
	_player.connect("interact_at",   _on_interact)
	_player.connect("player_moved",  _on_player_moved)

	# Spawn NPCs
	_spawn_npcs()
	queue_redraw()

func _get_blocked()->Array:
	var blocked := []
	var map = MAPS.get(_world, MAPS.math)
	for r in ROWS:
		for c in COLS:
			var t = map[r][c]
			if t not in WALKABLE:
				blocked.append(Vector2i(c,r))
	return blocked

func _is_walkable_tile(p:Vector2i)->bool:
	if p.x<0 or p.x>=COLS or p.y<0 or p.y>=ROWS: return false
	return MAPS.get(_world,MAPS.math)[p.y][p.x] in WALKABLE

# ── NPC SPAWNING ──────────────────────────────────────────────────────────────
func _spawn_npcs()->void:
	# Clear old NPCs
	for n in _npcs: if is_instance_valid(n): n.queue_free()
	_npcs.clear()

	var npc_script := load("res://scripts/npc/NPC.gd")
	for ndata in WORLD_NPCS.get(_world,[]):
		var n := Area2D.new()
		n.set_script(npc_script)
		n.connect("talk_to", _on_npc_talk)
		add_child(n)
		n.setup(ndata)
		_npcs.append(n)

# ── INTERACTION ───────────────────────────────────────────────────────────────
func _on_interact(front:Vector2i, _dir:int)->void:
	if _dialog_open: return

	# Check NPC
	for n in _npcs:
		if is_instance_valid(n) and n.data.get("pos") == front:
			n.activate(); return

	# Check items
	for item in WORLD_ITEMS.get(_world,[]):
		if item.pos == front and not GameManager.has_item(item.id):
			_collect_item(item); return

	# Check gym door
	var gym_door = GYM_ENTRY.get(_world, Vector2i(9,10))
	if front == gym_door:
		_try_gym(); return

	# Check tile type
	var t := _tile_at(front)
	if t == T_SIGN:
		_show_dialog(["Sign: '"+TOWN_NAMES.get(_world,"")+"'\nBecome Kaiser — learn and\nconquer the knowledge world!"])

func _on_player_moved(gp:Vector2i)->void:
	GameManager.set_grid_pos(gp)
	# Auto-step on items
	for item in WORLD_ITEMS.get(_world,[]):
		if item.pos == gp and not GameManager.has_item(item.id):
			_collect_item(item); return
	# Check for hidden items
	_check_hidden_xp(gp)

func _check_hidden_xp(gp:Vector2i)->void:
	# Every ~10 tiles stepped, chance of a small XP bonus (simulate random encounters)
	if randf() < 0.04:  # 4% chance per step
		var amt := randi_range(5,15)
		GameManager.add_xp(amt)
		if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(amt)

func _collect_item(item:Dictionary)->void:
	GameManager.collect_item(item.id)
	GameManager.add_xp(item.get("xp",100))
	GameManager.add_gold(item.get("gold",0))
	if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(item.get("xp",100))
	_show_dialog([item.get("msg","Found an item!")])
	# Check quest completion
	_check_quest_progress()
	queue_redraw()

func _check_quest_progress()->void:
	var active_quests := ["mq1", "eq1", "muq1"]
	for qid in active_quests:
		if GameManager.quest_done(qid): continue
		var q = WORLD_QUESTS.get(qid,{})
		if q.is_empty(): continue
		var done := true
		for iid in q.get("item_ids",[]):
			if not GameManager.has_item(iid): done = false; break
		if done:
			GameManager.complete_quest(qid)
			GameManager.add_xp(q.get("reward_xp",200))
			GameManager.add_gold(q.get("reward_gold",50))
			if _hud and _hud.has_method("show_xp_gain"): _hud.show_xp_gain(q.get("reward_xp",200))
			_show_dialog([q.get("reward_msg","Quest complete!")])

func _on_npc_talk(ndata:Dictionary)->void:
	if _dialog_open: return
	match ndata.get("type","normal"):
		"teacher":   _handle_teacher(ndata)
		"quest_giver": _handle_quest_giver(ndata)
		"duel":      _handle_duel_invite(ndata)
		"item_trade":_handle_item_trade(ndata)
		_:           _handle_normal_npc(ndata)

func _handle_teacher(t:Dictionary)->void:
	var lines = t.get("lesson",[]).duplicate()
	var already := GameManager.learned_from(t.id)
	if not already:
		GameManager.mark_learned(t.id)
		_show_dialog(lines, func():
			GameManager.add_xp(t.get("xp",75))
			if _hud: _hud.show_xp_gain(t.get("xp",75))
		)
	else:
		lines.append("(Already learned — no bonus XP)")
		_show_dialog(lines)

func _handle_quest_giver(ndata:Dictionary)->void:
	var qid = ndata.get("quest_id","")
	if GameManager.quest_done(qid):
		_show_dialog(["Thanks again! Quest complete!"]); return
	_show_dialog(ndata.get("lines",[]))

func _handle_duel_invite(ndata:Dictionary)->void:
	_pending_duel = ndata.get("opponent",{})
	var lines = ndata.get("lines",[]).duplicate()
	lines.append("Press ENTER again to start the duel!")
	_show_dialog(lines, func():
		if not _pending_duel.is_empty():
			change_scene.emit("duel", {"opponent":_pending_duel,"world":_world})
			_pending_duel = {}
	)

func _handle_item_trade(ndata:Dictionary)->void:
	var trade_id = ITEM_TRADE_ID.get(_world,"gift")
	if GameManager.has_item(trade_id):
		_show_dialog(["You already received this gift!"]); return
	GameManager.collect_item(trade_id)
	var xp = ITEM_TRADE_XP.get(_world,150)
	_show_dialog(ndata.get("lines",[]), func():
		GameManager.add_xp(xp)
		if _hud: _hud.show_xp_gain(xp)
	)

func _handle_normal_npc(ndata:Dictionary)->void:
	var lines = ndata.get("lines",[]).duplicate()
	var npc_xp = ndata.get("xp",0)
	if npc_xp > 0 and not GameManager.has_talked(ndata.id):
		GameManager.mark_talked(ndata.id)
		lines.append("(+"+str(npc_xp)+" XP for listening!)")
		_show_dialog(lines, func():
			GameManager.add_xp(npc_xp)
			if _hud: _hud.show_xp_gain(npc_xp)
		)
	else:
		_show_dialog(lines)

func _try_gym()->void:
	var badge = BADGE_MAP.get(_world,"")
	if GameManager.has_badge(badge):
		_show_dialog(["You already hold the "+badge+"!","The gym leader bows with respect."]); return
	if not GameManager.can_challenge_gym(1):
		_show_dialog([
			"⚠ GYM SEALED ⚠",
			"Required: Level 5\nYour Level: "+str(GameManager.get_level()),
			"Talk to Teachers and challenge\nDuels to gain XP!\n\nYou need "+str(max(0,400-GameManager.get_xp())+" more XP")
		]); return
	# Check lessons
	var teachers = WORLD_NPCS.get(_world,[])
	var learned := 0
	for t in teachers:
		if t.get("type","")=="teacher" and GameManager.learned_from(t.id): learned+=1
	if learned == 0:
		_show_dialog(["The gym door is locked!","Speak with the Teachers (? icons)\nto unlock the gym!","Learn at least 1 lesson first."]); return
	# Launch gym battle
	var db_map := {"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db = db_map.get(_world,AlgebraDB)
	var gym_data = db.get_gym1_leader()
	gym_data["questions"] = db.get_gym1_questions()
	gym_data["world"] = _world
	AdaptiveAI.start_session(_world)
	_show_dialog(gym_data.get("intro",["Ready?"]), func():
		change_scene.emit("battle", gym_data)
	)

func _tile_at(p:Vector2i)->int:
	if p.x<0 or p.x>=COLS or p.y<0 or p.y>=ROWS: return T_TREE
	return MAPS.get(_world,MAPS.math)[p.y][p.x]

func _show_dialog(lines:Array, callback:Callable=Callable())->void:
	_dialog_open = true
	if _player: _player.dialog_open = true
	if _dialog and _dialog.has_method("show_lines"):
		_dialog.show_lines(lines, func():
			_dialog_open = false
			if _player: _player.dialog_open = false
			if callback.is_valid(): callback.call()
		)

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta:float)->void:
	_time += delta
	# Update NPC z-indices for depth sorting
	for n in _npcs:
		if is_instance_valid(n):
			n.z_index = n.data.get("pos",Vector2i(0,0)).y
	# Back to world map
	if Input.is_action_just_pressed("ui_cancel") and not _dialog_open:
		change_scene.emit("world_map",{})
	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
#  2.5D WORLD RENDERING — back-to-front painter's algorithm
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	if not _player: return
	var map = MAPS.get(_world, MAPS.math)

	# Camera: center on player
	var cam := _player.position - Vector2(240,160)
	cam.x = clamp(cam.x, 0, COLS*TS-480)
	cam.y = clamp(cam.y, 0, ROWS*TS-320)

	# Draw tiles + objects back-to-front (row by row for depth)
	for r in ROWS:
		for c in COLS:
			var px := int(c*TS - cam.x)
			var py := int(r*TS - cam.y)
			if px < -TS or px > 480 or py < -TS or py > 320: continue
			_draw_tile(map[r][c], px, py, c, r)

	# Draw items
	for item in WORLD_ITEMS.get(_world,[]):
		if not GameManager.has_item(item.id):
			var px := int(item.pos.x*TS - cam.x)
			var py := int(item.pos.y*TS - cam.y)
			_draw_item_sparkle(px, py)

	# Draw UI overlay
	_draw_ui_overlay(cam)

func _draw_tile(t:int, px:int, py:int, c:int, r:int)->void:
	var pal := _get_pal()
	var chk := (c+r)%2==0
	var DK  := Color("#181010")

	match t:
		T_GRASS:  _t_grass(px,py,pal,chk,c,r)
		T_TREE:   _t_grass(px,py,pal,chk,c,r); _t_tree_iso(px,py,pal)
		T_HOUSE_TOP:   _t_grass(px,py,pal,chk,c,r); _t_house_iso(px,py,pal)
		T_HOUSE_FRONT: _t_grass(px,py,pal,chk,c,r)  # front drawn by house_top
		12:  # walkable door tile
			_t_grass(px,py,pal,chk,c,r)
			_t_door_step(px,py,pal)
		T_PATH:   _t_path(px,py,pal,chk,c,r)
		T_GYM_TOP:  _t_path(px,py,pal,chk,c,r); _t_gym_iso(px,py,pal)
		T_GYM_FRONT:_t_path(px,py,pal,chk,c,r)
		T_ITEM:   _t_grass(px,py,pal,chk,c,r)
		T_WATER:  _t_water(px,py,pal,c,r)
		T_SAND:   _t_sand(px,py,chk)
		T_STONE:  _t_stone(px,py)
		T_SIGN:   _t_grass(px,py,pal,chk,c,r); _t_sign_iso(px,py,pal)
		_:  # TREE or unknown = dense tree
			if t==T_TREE:
				_t_grass(px,py,pal,chk,c,r); _t_tree_iso(px,py,pal)
			else:
				_t_grass(px,py,pal,chk,c,r); _t_tree_iso(px,py,pal)

# ── GRASS ─────────────────────────────────────────────────────────────────────
func _t_grass(px:int,py:int,pal:Dictionary,chk:bool,c:int,r:int)->void:
	draw_rect(Rect2(px,py,TS,TS), pal.g0)
	# Checker pattern (Gen 2 hallmark)
	for dy in range(0,TS,4):
		for dx in range(0,TS,4):
			if ((dx/4+dy/4+c+r)%2)==0:
				draw_rect(Rect2(px+dx,py+dy,4,4), pal.g1)
	# Grass blades (sparse detail)
	if (c*7+r*11)%8==0:
		draw_rect(Rect2(px+5, py+21,2,7), pal.g0.lightened(0.3))
		draw_rect(Rect2(px+14,py+19,2,9), pal.g0.lightened(0.25))
	# Flowers
	if (c*11+r*7)%14==0:
		var fc := Color("#f880a0") if pal.g0.r>0.5 else Color("#f8c030")
		draw_rect(Rect2(px+14,py+19,4,4), fc)

# ── PATH ──────────────────────────────────────────────────────────────────────
func _t_path(px:int,py:int,pal:Dictionary,chk:bool,c:int,r:int)->void:
	draw_rect(Rect2(px,py,TS,TS), pal.path)
	for dy in range(0,TS,4):
		for dx in range(0,TS,4):
			if ((dx/4+dy/4+c+r)%2)==0:
				draw_rect(Rect2(px+dx,py+dy,4,4), pal.path2)
	# Border
	draw_rect(Rect2(px,py,TS,1),     pal.g2)
	draw_rect(Rect2(px,py+TS-1,TS,1),pal.g2)
	draw_rect(Rect2(px,py,1,TS),     pal.g2)
	draw_rect(Rect2(px+TS-1,py,1,TS),pal.g2)
	# Pebble
	if (c*5+r*9)%6==0:
		draw_rect(Rect2(px+6,py+8,4,3), pal.g3)

# ── WATER ────────────────────────────────────────────────────────────────────
func _t_water(px:int,py:int,pal:Dictionary,c:int,r:int)->void:
	draw_rect(Rect2(px,py,TS,TS), pal.water)
	var wv := 0.4+0.6*sin(_time*1.8+(c+r)*0.45)
	for wy in [4,10,16,22,28]:
		var sh := int(sin(_time*2.0+(c+r)*0.5)*2)
		draw_rect(Rect2(px+2,py+wy+sh, TS-4,2), pal.water.lightened(0.28)*Color(1,1,1,wv))

# ── SAND ─────────────────────────────────────────────────────────────────────
func _t_sand(px:int,py:int,chk:bool)->void:
	draw_rect(Rect2(px,py,TS,TS), Color("#e8d880") if chk else Color("#d8c870"))

# ── STONE ────────────────────────────────────────────────────────────────────
func _t_stone(px:int,py:int)->void:
	draw_rect(Rect2(px,py,TS,TS), Color("#706868"))
	draw_rect(Rect2(px+1,py+1,  14,14), Color("#808080"))
	draw_rect(Rect2(px+17,py+1, 14,14), Color("#808080"))
	draw_rect(Rect2(px+9,py+17, 14,14), Color("#808080"))
	draw_rect(Rect2(px,py,TS,TS), Color("#181010"), false, 1.0)

# ── DOOR STEP ────────────────────────────────────────────────────────────────
func _t_door_step(px:int,py:int,pal:Dictionary)->void:
	draw_rect(Rect2(px+6,py+26,20,6), pal.path)
	draw_rect(Rect2(px+6,py+26,20,1), pal.path2)

# ── 2.5D TREE ─────────────────────────────────────────────────────────────────
func _t_tree_iso(px:int,py:int,pal:Dictionary)->void:
	var DK := Color("#181010")
	# Shadow
	draw_rect(Rect2(px+4,py+26,24,7), Color(0,0,0,0.22))
	# Trunk (front face visible = 2.5D)
	draw_rect(Rect2(px+12,py+18,8,14), Color("#6a4010"))
	draw_rect(Rect2(px+13,py+18,4,14), Color("#8a5820"))
	draw_rect(Rect2(px+12,py+18,8,14), DK, false, 1.0)
	# Crown layers (bottom to top, darker outer to lighter inner)
	draw_rect(Rect2(px+2,py+16,28,14), pal.g3)           # shadow outline
	draw_rect(Rect2(px+3,py+10,26,18), pal.g2)           # outer crown
	draw_rect(Rect2(px+6,py+5, 20,17), pal.g1)           # mid crown
	draw_rect(Rect2(px+9,py+2, 14,14), pal.g0)           # inner crown
	draw_rect(Rect2(px+11,py+2,10,8), pal.g0.lightened(0.2))  # highlight
	draw_rect(Rect2(px+12,py+2,6, 4), Color(1,1,1,0.2))  # specular
	# Crown outline
	draw_rect(Rect2(px+3,py+10,26,18), DK, false, 1.0)

# ── 2.5D HOUSE ────────────────────────────────────────────────────────────────
const HOUSE_WALL_H := 22

func _t_house_iso(px:int,py:int,pal:Dictionary)->void:
	var DK := Color("#181010")
	# Shadow under house
	draw_rect(Rect2(px+2,py+TS-2,TS-2,HOUSE_WALL_H+2), Color(0,0,0,0.2))
	# ROOF (top face — seen from above)
	draw_rect(Rect2(px,py,TS,TS-HOUSE_WALL_H), pal.roof)
	draw_rect(Rect2(px,py,TS,5), pal.roof.darkened(0.25))
	draw_rect(Rect2(px+2,py+2,TS-4,3), pal.roof.lightened(0.15))
	# Chimney (2.5D: shows side + front)
	draw_rect(Rect2(px+22,py-5, 6,TS-HOUSE_WALL_H+3), pal.roof.darkened(0.3))
	draw_rect(Rect2(px+21,py-7, 8,4), DK)
	draw_rect(Rect2(px+22,py-6, 6,3), Color("#505050"))
	# FRONT WALL (the magic of 2.5D — visible wall below roof)
	draw_rect(Rect2(px,py+TS-HOUSE_WALL_H, TS, HOUSE_WALL_H), pal.wall)
	draw_rect(Rect2(px+TS-5,py+TS-HOUSE_WALL_H, 5, HOUSE_WALL_H), pal.wall.darkened(0.2))  # side shadow
	# Windows on front wall
	_draw_window_iso(px+4, py+TS-HOUSE_WALL_H+2, 10, 10, pal)
	_draw_window_iso(px+18,py+TS-HOUSE_WALL_H+2, 10, 10, pal)
	# Outline
	draw_rect(Rect2(px,py,TS,TS+HOUSE_WALL_H-TS), DK, false, 1.0)
	draw_rect(Rect2(px,py,TS,TS),                 DK, false, 1.0)

func _draw_window_iso(wx:int,wy:int,ww:int,wh:int,pal:Dictionary)->void:
	var DK := Color("#181010")
	draw_rect(Rect2(wx,wy,ww,wh),        DK)
	draw_rect(Rect2(wx+1,wy+1,ww-2,wh-2),Color("#88ccff"))
	draw_rect(Rect2(wx+ww/2,wy+1,1,wh-2),DK)  # vertical divider
	draw_rect(Rect2(wx+1,wy+wh/2,ww-2,1),DK)  # horizontal divider
	draw_rect(Rect2(wx+1,wy+1,4,4),      Color("#c0e8ff"))  # top-left shine

# ── 2.5D GYM ─────────────────────────────────────────────────────────────────
const GYM_WALL_H := 24

func _t_gym_iso(px:int,py:int,pal:Dictionary)->void:
	var wc  := _gym_col()
	var DK  := Color("#181010")
	var glow:= 0.35 + 0.35*sin(_time*2.5)

	# Shadow
	draw_rect(Rect2(px+2,py+TS-2,TS-2,GYM_WALL_H+2), Color(0,0,0,0.2))
	# TOP face
	draw_rect(Rect2(px,py,TS,TS-GYM_WALL_H), wc.darkened(0.3))
	draw_rect(Rect2(px,py,TS,5), wc.lightened(0.15))
	draw_rect(Rect2(px+2,py+2,TS-4,3), Color(1,1,1,0.12))
	# FRONT WALL (2.5D)
	draw_rect(Rect2(px,py+TS-GYM_WALL_H,TS,GYM_WALL_H), wc)
	draw_rect(Rect2(px+TS-5,py+TS-GYM_WALL_H,5,GYM_WALL_H), wc.darkened(0.25))
	# Pillars
	draw_rect(Rect2(px+4,py+TS-GYM_WALL_H,4,GYM_WALL_H), wc.darkened(0.2))
	draw_rect(Rect2(px+TS-8,py+TS-GYM_WALL_H,4,GYM_WALL_H), wc.darkened(0.2))
	# Horizontal band
	draw_rect(Rect2(px,py+TS-GYM_WALL_H+8,TS,4), wc.lightened(0.15))
	# Glow strip
	draw_rect(Rect2(px+4,py+TS-4,TS-8,3), wc.lightened(0.5)*Color(1,1,1,glow))
	# Mid banner
	draw_rect(Rect2(px,py+TS-GYM_WALL_H-2,TS,2), wc.lightened(0.3))
	draw_rect(Rect2(px,py,TS,TS+GYM_WALL_H-TS), DK, false, 1.0)
	draw_rect(Rect2(px,py,TS,TS),                DK, false, 1.0)

# ── SIGN ─────────────────────────────────────────────────────────────────────
func _t_sign_iso(px:int,py:int,pal:Dictionary)->void:
	var DK := Color("#181010")
	draw_rect(Rect2(px+13,py+10,6,22), Color("#8a5020"))
	draw_rect(Rect2(px+13,py+10,6,22), DK, false, 1.0)
	draw_rect(Rect2(px+4, py+4, 24,14), Color("#c07830"))
	draw_rect(Rect2(px+4, py+4, 24,14), DK, false, 1.5)
	draw_rect(Rect2(px+4, py+4, 24,2),  Color("#e89040"))

# ── ITEM SPARKLE ─────────────────────────────────────────────────────────────
func _draw_item_sparkle(px:int,py:int)->void:
	var pal := _get_pal()
	var g   := 0.5+0.5*sin(_time*4.5)
	var g2  := 0.5+0.5*sin(_time*4.5+PI)
	var col = pal.g0.lightened(0.6)
	draw_rect(Rect2(px+10,py+8,  12,16), col*Color(1,1,1,g))
	draw_rect(Rect2(px+12,py+10,  8,12), Color(1,1,1,g*0.6))
	draw_rect(Rect2(px+10,py+8,  12,16), Color("#181010"), false, 1.0)
	draw_rect(Rect2(px+14,py+2,   4, 8), Color(1,1,1,g))
	draw_rect(Rect2(px+10,py+5,  12, 3), Color(1,1,1,g2*0.5))
	draw_rect(Rect2(px+6, py+12,  4, 4), Color(1,1,1,g2*0.4))
	draw_rect(Rect2(px+22,py+12,  4, 4), Color(1,1,1,g2*0.4))

# ── UI OVERLAY ────────────────────────────────────────────────────────────────
func _draw_ui_overlay(_cam:Vector2)->void:
	var fnt := ThemeDB.fallback_font
	var DK  := Color("#181010")

	# Town name
	draw_rect(Rect2(3,3,138,18), DK)
	draw_rect(Rect2(4,4,136,16), Color("#f0f8f0"))
	draw_rect(Rect2(4,4,136,6),  _get_pal().g1)
	draw_string(fnt,Vector2(8,18), TOWN_NAMES.get(_world,""), HORIZONTAL_ALIGNMENT_LEFT,-1,12, DK)

	# ESC hint
	draw_rect(Rect2(330,3,148,14), DK)
	draw_rect(Rect2(331,4,146,12), Color("#f0f0e0"))
	draw_string(fnt,Vector2(335,14),"ESC = World Map",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)

	# XP to level 5 progress (if below level 5)
	if GameManager.get_level() < 5:
		var need := 5*GameManager.XP_BASE
		var have := (GameManager.get_level()-1)*GameManager.XP_BASE + GameManager.get_xp()
		var pct  := float(have)/float(need)
		draw_rect(Rect2(3,23,190,14), DK)
		draw_rect(Rect2(4,24,188,12), Color("#f0f8f0"))
		draw_rect(Rect2(4,24,int(188*pct),12), Color("#48c840"))
		draw_string(fnt,Vector2(7,34),"Gym unlock: Lv.5  ("+str(int(pct*100))+"%)",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)

	# Gym banner above row 11 gym (y = 11*32 - cam_y + something)
	var gnames := {"math":"Variable Citadel","english":"Noun Sanctum","music":"Harmony Hall"}
	var gcol   := _gym_col()
	draw_rect(Rect2(130,TS*11-22,220,18), DK)
	draw_rect(Rect2(131,TS*11-21,218,16), Color("#f0f0e8"))
	draw_string(fnt,Vector2(140,TS*11-8),"★  "+gnames.get(_world,"Gym")+"  ★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,gcol)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_pal()->Dictionary:
	match _world:
		"math":    return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),
						   "g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058"),
						   "water":Color("#3050b0"),"wall":Color("#c8c8a0"),"roof":Color("#204880")}
		"english": return {"g0":Color("#e8d8a0"),"g1":Color("#d8c890"),"g2":Color("#a87840"),
						   "g3":Color("#503010"),"path":Color("#f0e090"),"path2":Color("#e0d080"),
						   "water":Color("#5090c0"),"wall":Color("#f0e8d0"),"roof":Color("#a03818")}
		"music":   return {"g0":Color("#281848"),"g1":Color("#201038"),"g2":Color("#100820"),
						   "g3":Color("#080410"),"path":Color("#604890"),"path2":Color("#503878"),
						   "water":Color("#102888"),"wall":Color("#302048"),"roof":Color("#601080")}
	return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),"g3":Color("#0f380f"),
			"path":Color("#d4c06a"),"path2":Color("#c4b058"),"water":Color("#3050b0"),
			"wall":Color("#c8c8a0"),"roof":Color("#204880")}

func _gym_col()->Color:
	match _world:
		"math":    return Color("#2060d0")
		"english": return Color("#c07010")
		"music":   return Color("#8020c0")
	return Color("#2060d0")
