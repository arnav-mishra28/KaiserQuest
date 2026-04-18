# GymStoryline.gd — Full 20 Gym Storyline Data (Autoload)
# ACT 1: Gyms 1-5   (Basics, friendly mentor)
# ACT 2: Gyms 6-12  (Rising challenge, rival appears)
# ACT 3: Gyms 13-20 (Mastery, mixed topics, pressure)
extends Node

# ── 20 Cities / Towns with their gym assignments ─────────────────────────────
const CITIES := [
	# ACT 1 — BEGINNING (Gyms 1–5)
	{"id":"starter_town",  "name":"Pallet Grove",      "world":"math",    "gym":1,  "act":1,
	 "desc":"A peaceful village where\nyour journey begins.",
	 "route_from":[], "route_to":["route_1"]},

	{"id":"mathopolis",    "name":"Mathopolis",         "world":"math",    "gym":2,  "act":1,
	 "desc":"City of equations.\nHome of the Variable Citadel.",
	 "route_from":["route_1"], "route_to":["route_2","route_6"]},

	{"id":"lexicon_city",  "name":"Lexicon City",       "world":"english", "gym":3,  "act":1,
	 "desc":"City of words and wisdom.\nThe Noun Sanctum stands tall.",
	 "route_from":["route_2"], "route_to":["route_3"]},

	{"id":"harmonia",      "name":"Harmonia",           "world":"music",   "gym":4,  "act":1,
	 "desc":"City of eternal music.\nHarmony Hall echoes forever.",
	 "route_from":["route_3"], "route_to":["route_4"]},

	{"id":"crossroads",    "name":"Crossroads Town",    "world":"math",    "gym":5,  "act":1,
	 "desc":"Where all paths meet.\nA place to rest and reflect.",
	 "route_from":["route_4"], "route_to":["route_5","route_8"]},

	# ACT 2 — RISING (Gyms 6–12)
	{"id":"equation_vale", "name":"Equation Vale",      "world":"math",    "gym":6,  "act":2,
	 "desc":"The rival awaits here.\nLinear equations rule this land.",
	 "route_from":["route_5"], "route_to":["route_6"]},

	{"id":"verb_city",     "name":"Verb City",          "world":"english", "gym":7,  "act":2,
	 "desc":"Every word here is an action.\nVerbs animate the streets.",
	 "route_from":["route_6"], "route_to":["route_7"]},

	{"id":"chord_haven",   "name":"Chord Haven",        "world":"music",   "gym":8,  "act":2,
	 "desc":"Chords echo through every wall.\nHarmony and dissonance clash.",
	 "route_from":["route_7"], "route_to":["route_9"]},

	{"id":"function_peak", "name":"Function Peak",      "world":"math",    "gym":9,  "act":2,
	 "desc":"High altitude thinking.\nFunctions reach new heights.",
	 "route_from":["route_8"], "route_to":["route_10"]},

	{"id":"syntax_port",   "name":"Syntax Port",        "world":"english", "gym":10, "act":2,
	 "desc":"A harbor of structured thought.\nSentences sail like ships.",
	 "route_from":["route_9"], "route_to":["route_11"]},

	{"id":"scale_summit",  "name":"Scale Summit",       "world":"music",   "gym":11, "act":2,
	 "desc":"The highest musical city.\nScales ascend to the clouds.",
	 "route_from":["route_10"], "route_to":["route_12"]},

	{"id":"quadratic_mesa","name":"Quadratic Mesa",     "world":"math",    "gym":12, "act":2,
	 "desc":"Curved thinking required.\nQuadratics shape this land.",
	 "route_from":["route_11"], "route_to":["route_13"]},

	# ACT 3 — MASTERY (Gyms 13–20)
	{"id":"grammar_citadel","name":"Grammar Citadel",   "world":"english", "gym":13, "act":3,
	 "desc":"The heart of all language.\nOnly masters enter.",
	 "route_from":["route_12"], "route_to":["route_14"]},

	{"id":"time_keep",     "name":"Time Keep",          "world":"music",   "gym":14, "act":3,
	 "desc":"Where rhythm rules time itself.\nOne wrong beat — defeat.",
	 "route_from":["route_13"], "route_to":["route_15"]},

	{"id":"mixed_ruins",   "name":"The Mixed Ruins",    "world":"math",    "gym":15, "act":3,
	 "desc":"Ancient ruins of all knowledge.\nSubjects blur and blend.",
	 "route_from":["route_14"], "route_to":["route_16"]},

	{"id":"pressure_city", "name":"Pressure City",      "world":"english", "gym":16, "act":3,
	 "desc":"Knowledge under pressure.\nTime limits test the best.",
	 "route_from":["route_15"], "route_to":["route_17"]},

	{"id":"harmony_peak",  "name":"Harmony Peak",       "world":"music",   "gym":17, "act":3,
	 "desc":"Where music meets mathematics.\nAll subjects harmonize.",
	 "route_from":["route_16"], "route_to":["route_18"]},

	{"id":"strategy_vale", "name":"Strategy Vale",      "world":"math",    "gym":18, "act":3,
	 "desc":"Thinking ahead is required.\nThe Fog grows thicker here.",
	 "route_from":["route_17"], "route_to":["route_19"]},

	{"id":"kaiser_gate",   "name":"Kaiser Gate",        "world":"english", "gym":19, "act":3,
	 "desc":"The final city before the peak.\nThe last test of language.",
	 "route_from":["route_18"], "route_to":["route_20"]},

	{"id":"apex_city",     "name":"Apex City",          "world":"music",   "gym":20, "act":3,
	 "desc":"The last city.\nSilver Mountain looms above.",
	 "route_from":["route_19"], "route_to":["silver_route"]},
]

# ── Routes (paths between cities) ─────────────────────────────────────────────
const ROUTES := [
	{"id":"route_1",  "name":"Route 1",  "from":"starter_town","to":"mathopolis",
	 "duels":["Youngster Jay"],"items":["Math Scroll Fragment"],"level_range":[1,5]},
	{"id":"route_2",  "name":"Route 2",  "from":"mathopolis",  "to":"lexicon_city",
	 "duels":["Scholar Mira"],"items":["Old Quill"],"level_range":[5,10]},
	{"id":"route_3",  "name":"Route 3",  "from":"lexicon_city","to":"harmonia",
	 "duels":["Poet Sam"],"items":["Music Note Shard"],"level_range":[10,15]},
	{"id":"route_4",  "name":"Route 4",  "from":"harmonia",    "to":"crossroads",
	 "duels":["Traveler Lee"],"items":["Mixed Crystal"],"level_range":[15,20]},
	{"id":"route_5",  "name":"Route 5",  "from":"crossroads",  "to":"equation_vale",
	 "duels":["RIVAL — Kira"],"items":["Equation Stone"],"level_range":[20,25]},
	{"id":"route_6",  "name":"Route 6",  "from":"equation_vale","to":"verb_city",
	 "duels":["Thinker Rox"],"items":["Verb Crystal"],"level_range":[25,30]},
	{"id":"route_7",  "name":"Route 7",  "from":"verb_city",   "to":"chord_haven",
	 "duels":["Musician Theo"],"items":["Chord Fragment"],"level_range":[30,35]},
	{"id":"route_8",  "name":"Route 8",  "from":"crossroads",  "to":"function_peak",
	 "duels":["Logician Vera"],"items":["Function Gem"],"level_range":[25,35]},
	{"id":"route_9",  "name":"Route 9",  "from":"chord_haven", "to":"syntax_port",
	 "duels":["Grammarian Nix"],"items":["Syntax Map"],"level_range":[35,40]},
	{"id":"route_10", "name":"Route 10", "from":"function_peak","to":"scale_summit",
	 "duels":["RIVAL — Kira (2)"],"items":["Scale Stone"],"level_range":[35,45]},
]

# ── Act narrative hooks ─────────────────────────────────────────────────────
const ACT_INTROS := {
	1: [
		"The world was bright once.",
		"Every village had scholars.\nEvery child could read the stars.",
		"Then... the Fog came.",
		"A young traveler named "+"{name}"+" set out\nfrom Pallet Grove.",
		"No one believed they could make\na difference.",
		"But knowledge is a light\nthat the Fog cannot extinguish.",
		"Your journey begins.",
	],
	2: [
		"Five badges. The world\nhas noticed your progress.",
		"But so has the Fog.",
		"A rival appears — Kira.\nThey seek the same goal.",
		"'Only one can become Kaiser.'\nKira's words echo.",
		"The challenges grow harder.\nThe Fog grows thicker.",
		"But you keep going.",
	],
	3: [
		"Twelve badges. The world\nbegins to remember.",
		"Villages relit their lamps.\nBooks opened on their own.",
		"Kira is ahead — but not\nbecause they are smarter.",
		"Because they never stopped.",
		"Neither will you.",
		"The final gyms await.\nSilver Mountain is near.",
		"Show the world what knowledge\ntruly looks like.",
	],
}

# ── Gym leaders (all 20) ──────────────────────────────────────────────────────
static func get_gym_leader_data(gym_num: int) -> Dictionary:
	var leaders := _all_leaders()
	return leaders.get(gym_num, {})

static func _all_leaders() -> Dictionary:
	return {
		# ── ACT 1 ───────────────────────────────────────────────────────────
		1: {"name":"Prof. Sprout",   "title":"Teacher of Pallet Grove",
			"world":"math",    "badge":"Seedling Badge","xp":200,
			"color":Color("#60b030"),
			"intro":["Welcome, young "+GameManager.player_name+"!","I am Prof. Sprout.\nLet me teach you the basics!","Variables are where\nall algebra begins.","3 questions. Take your time."],
			"win":["Well done! You have\nlearned your first lesson!","The Seedling Badge is yours!"],
			"lose":["Don't worry! Review with\nthe villagers and try again."]},

		2: {"name":"Prof. Axiom",    "title":"Guardian of the Variable Citadel",
			"world":"math",    "badge":"Variable Badge","xp":300,
			"color":Color("#2060d0"),
			"intro":["I am Professor Axiom!\nVariables are my domain.","Solve them all!","5 questions. 3 lives. Begin!"],
			"win":["Variables bow to you now!\nThe Variable Badge is yours!"],
			"lose":["Study with the teachers!\nReturn when stronger."]},

		3: {"name":"Lexis",          "title":"Keeper of the Noun Sanctum",
			"world":"english", "badge":"Grammar Badge","xp":300,
			"color":Color("#c07010"),
			"intro":["I am Lexis!\nKnowledge of nouns is power.","5 questions begin!"],
			"win":["Nouns bend to your will!\nGrammar Badge is yours!"],
			"lose":["Words escaped you.\nStudy with Wordsmith Nora!"]},

		4: {"name":"Maestro Resonus","title":"Conductor of Harmony Hall",
			"world":"music",   "badge":"Rhythm Badge","xp":300,
			"color":Color("#8020c0"),
			"intro":["I am Maestro Resonus!\nMusic flows through this hall.","5 questions of rhythm await!"],
			"win":["The Rhythm Badge is yours!\nMusic sings for you."],
			"lose":["Study with Maestro Staffa!\nReturn."]},

		5: {"name":"Elder Crossway",  "title":"Sage of the Crossroads",
			"world":"math",    "badge":"Crossroads Badge","xp":400,
			"color":Color("#806020"),
			"intro":["Every path meets at\nthe Crossroads, "+GameManager.player_name+".","5 Act 1 final test.\nAre you ready?"],
			"win":["ACT 1 COMPLETE!\nThe Crossroads Badge!","The world grows brighter\nwith every badge earned."],
			"lose":["Review all you've learned.\nThe crossroads waits."]},

		# ── ACT 2 ───────────────────────────────────────────────────────────
		6: {"name":"Magistra Lin",   "title":"Master of the Equation Tower",
			"world":"math",    "badge":"Equation Badge","xp":450,
			"color":Color("#10a060"),
			"intro":["I am Magistra Lin!\nLinear equations are my weapon.","Your rival Kira\nchallenged me yesterday.","Can you do better?\n6 questions!"],
			"win":["Equation Badge!\nYou surpassed your rival today."],
			"lose":["Equations defeated you.\nStudy and return."]},

		7: {"name":"Magistra Verbis","title":"Mistress of the Verb Vault",
			"world":"english", "badge":"Verb Badge","xp":450,
			"color":Color("#308840"),
			"intro":["Action is everything here.\nI am Magistra Verbis!","6 questions on verbs!"],
			"win":["Verbs flow through you!\nVerb Badge earned!"],
			"lose":["Verbs eluded you.\nStudy Scholar Verbis!"]},

		8: {"name":"Maestra Harmona","title":"Guardian of the Chord Citadel",
			"world":"music",   "badge":"Harmony Badge","xp":450,
			"color":Color("#c040a0"),
			"intro":["Chords are combinations\nof knowledge. I am Harmona!","6 questions on chords!"],
			"win":["Harmony Badge earned!\nChords sing for you!"],
			"lose":["Return when stronger!"]},

		9: {"name":"Elder Quadrix",  "title":"Sage of Function Peak",
			"world":"math",    "badge":"Function Badge","xp":500,
			"color":Color("#c04020"),
			"intro":["Functions govern the universe.\nI am Elder Quadrix!","7 hard questions!"],
			"win":["Function Badge!\nMathematics opens its doors."],
			"lose":["Functions still elude you.\nStudy Elder Func!"]},

		10: {"name":"Elder Syntaxis","title":"Sage of Sentence Structure",
			"world":"english", "badge":"Sentence Badge","xp":500,
			"color":Color("#6030a0"),
			"intro":["Sentences are the highest\nlanguage art. I am Syntaxis!","7 questions on sentences!"],
			"win":["Sentence Badge!\nLanguage mastery grows."],
			"lose":["Return stronger!"]},

		11: {"name":"Grandmaster Scala","title":"Sage of Scale Summit",
			"world":"music",   "badge":"Scale Badge","xp":500,
			"color":Color("#2080c0"),
			"intro":["Scales are the architecture\nof music. I am Scala!","7 questions on scales!"],
			"win":["Scale Badge!\nMusic theory blossoms."],
			"lose":["Return!"]},

		12: {"name":"Prof. Parabola","title":"Keeper of the Quadratic Mesa",
			"world":"math",    "badge":"Quadratic Badge","xp":550,
			"color":Color("#902020"),
			"intro":["Curves and arcs define\nthis land. ACT 2 FINALE!","7 questions. Your rival\nis close behind!"],
			"win":["ACT 2 COMPLETE!\nQuadratic Badge!","Your rival Kira\nwatches from afar..."],
			"lose":["Review quadratics.\nThe rival advances!"]},

		# ── ACT 3 ───────────────────────────────────────────────────────────
		13: {"name":"Arch-Lexis",    "title":"Master of Grammar Citadel",
			"world":"english", "badge":"Arch Badge","xp":600,
			"color":Color("#a03080"),
			"intro":["ACT 3 BEGINS.\nOnly masters enter here.","I am Arch-Lexis.\nMixed questions. Time pressure.","7 questions!"],
			"win":["Arch Badge! The world\ngrows brighter still!"],
			"lose":["Return. The Fog recedes\nonly for the worthy."]},

		14: {"name":"Maestro Tempo", "title":"Keeper of Time Keep",
			"world":"music",   "badge":"Tempo Badge","xp":600,
			"color":Color("#204080"),
			"intro":["Time is rhythm.\nI am Maestro Tempo!","One wrong beat.\nDefeat.\n7 questions!"],
			"win":["Tempo Badge!\nYour rhythm is perfect."],
			"lose":["The beat faltered.\nReturn!"]},

		15: {"name":"The Archivist", "title":"Guardian of the Mixed Ruins",
			"world":"math",    "badge":"Ruin Badge","xp":650,
			"color":Color("#706050"),
			"intro":["These ruins blend all\nknowledge into one.\nI am The Archivist!","Mixed questions.\n8 questions!"],
			"win":["Ruin Badge! Ancient\nknowledge flows through you!"],
			"lose":["The ruins hold secrets\nyou have not mastered. Return!"]},

		16: {"name":"Speed-Lexis",   "title":"Champion of Pressure City",
			"world":"english", "badge":"Pressure Badge","xp":650,
			"color":Color("#c03010"),
			"intro":["Pressure reveals truth!\nI am Speed-Lexis!","Time limit: 8 sec/question!\n8 questions. No mercy!"],
			"win":["Pressure Badge!\nYou think fast AND right."],
			"lose":["Pressure broke you.\nReturn stronger!"]},

		17: {"name":"Harmonia Prime","title":"Sage of Harmony Peak",
			"world":"music",   "badge":"Peak Badge","xp":700,
			"color":Color("#8040c0"),
			"intro":["Here music meets math.\nAll knowledge harmonizes.\nI am Harmonia Prime!","8 questions!"],
			"win":["Peak Badge!\nKnowledge harmonizes within you."],
			"lose":["The peak is steep.\nReturn!"]},

		18: {"name":"Strategist Rex","title":"Master of Strategy Vale",
			"world":"math",    "badge":"Strategy Badge","xp":700,
			"color":Color("#405080"),
			"intro":["Think ahead or fall behind.\nI am Strategist Rex!","The Fog is thick here.\n9 questions!"],
			"win":["Strategy Badge!\nThe Fog retreats before you."],
			"lose":["The Fog advances.\nReturn!"]},

		19: {"name":"Kaiser Lexus",  "title":"Champion of Kaiser Gate",
			"world":"english", "badge":"Gate Badge","xp":750,
			"color":Color("#c08010"),
			"intro":["One badge remains\nbefore Silver Mountain.","I am Kaiser Lexus.\nThe final language test.\n9 questions!"],
			"win":["Gate Badge!\nSilver Mountain is in sight!","Your rival Kira waits\nat the summit too..."],
			"lose":["The gate remains shut.\nReturn!"]},

		20: {"name":"Maestro Apex",  "title":"The Last Guardian",
			"world":"music",   "badge":"Apex Badge","xp":800,
			"color":Color("#2060a0"),
			"intro":["20th gym.\nYou have come so far.","I am Maestro Apex.\nThe final test before the Oracle.","10 questions.\nGive everything you have."],
			"win":["APEX BADGE!\nALL 20 GYMS CLEARED!","Silver Mountain awaits.\nThe Oracle judges you now.","Go, Kaiser. The world\nneeds you."],
			"lose":["So close...\nReturn! The Oracle waits."]},
	}

# ── Get act for a gym number ──────────────────────────────────────────────────
static func get_act(gym_num: int) -> int:
	if gym_num <= 5:  return 1
	if gym_num <= 12: return 2
	return 3

static func get_act_name(act: int) -> String:
	match act:
		1: return "ACT 1 — BEGINNING"
		2: return "ACT 2 — RISING"
		3: return "ACT 3 — MASTERY"
	return ""

static func get_city_for_gym(gym_num: int) -> Dictionary:
	for c in CITIES:
		if c.gym == gym_num: return c
	return {}

static func get_questions_for_gym(gym_num: int, count: int) -> Array:
	var city := get_city_for_gym(gym_num)
	var world = city.get("world", "math")
	var db_map := {"math":AlgebraDB,"english":EnglishDB,"music":MusicDB}
	var db = db_map.get(world, AlgebraDB)
	var all_q = db.get_all_questions()
	# Higher gym = harder questions
	var min_diff = max(1, gym_num / 7)
	var filtered: Array = []
	for q in all_q:
		if q.get("difficulty",1) >= min_diff: filtered.append(q)
	if filtered.size() < count: filtered = all_q.duplicate()
	var pool := AdaptiveAI.adaptive_select(filtered, world, GameManager.get_level(), count)
	return pool

static func get_rival_dialog(encounter: int) -> Array:
	match encounter:
		1: return [
			"Wait! I know you from\nPallet Grove!",
			"I'm Kira. I'm going to\nbecome Kaiser before you!",
			"Knowledge Duel — right now!\nLet's see what you've learned!",
		]
		2: return [
			"You again... "+GameManager.player_name+".",
			"I've been training harder\nthan anyone.",
			"But so have you, I can tell.",
			"One day we'll fight for\nthe final badge. Not today.",
			"...Keep going.",
		]
		3: return [
			"Silver Mountain is ahead.",
			"I'll be honest with you:\nI'm scared too.",
			"The Oracle judges everything\nyou've ever learned.",
			"May the best Kaiser win.",
		]
	return ["The rival nods silently."]
