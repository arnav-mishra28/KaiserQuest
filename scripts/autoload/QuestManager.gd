# QuestManager.gd — Side quest system (autoload)
extends Node

# ── Quest definitions per world ───────────────────────────────────────────────
const QUESTS := {
	"math": [
		{
			"id":       "mq_lost_equation",
			"title":    "The Lost Equation",
			"giver":    "Equa the Scholar",
			"giver_id": "mq_giver1",
			"steps": [
				"Find the 3 hidden formula stones\nscattered around Mathopolis.",
				"Stone 1 found! Keep searching...",
				"Stone 2 found! One more to go...",
				"All 3 stones found! Return to Equa."
			],
			"reward_xp":   150,
			"reward_text": "Equa rewards you with\n+150 XP and the Equation Charm!",
			"item_ids":    ["mstone1","mstone2","mstone3"],
			"positions":   [Vector2i(13,3), Vector2i(13,7), Vector2i(1,3)]
		},
		{
			"id":       "mq_variable_hunt",
			"title":    "Variable Hunt",
			"giver":    "Old Professor Calc",
			"giver_id": "mq_giver2",
			"steps": [
				"Answer the Professor's quiz\nwithout using a hint.",
				"Quiz complete! Return to the Professor."
			],
			"reward_xp":   100,
			"reward_text": "+100 XP! The Professor smiles\nwith pride.",
			"item_ids":    [],
			"quiz": [
				{"q":"If x=7, what is 2x+1?","opts":["14","15","16","13"],"ans":1,"topic":"variables","difficulty":1},
				{"q":"Solve: 3x = 12","opts":["x=3","x=4","x=6","x=9"],"ans":1,"topic":"variables","difficulty":1},
			]
		},
		{
			"id":       "mq_elder_test",
			"title":    "The Elder's Trial",
			"giver":    "Elder Pythagoras",
			"giver_id": "mq_giver3",
			"steps": [
				"The Elder challenges you to\nfind the pattern in the ruins.",
				"Examine all 4 ancient rune tiles\naround the town square.",
				"All runes examined! Report back."
			],
			"reward_xp":   200,
			"reward_text": "+200 XP! The Elder bestows upon\nyou the Ancient Rune Token!",
			"item_ids":    ["rune1","rune2","rune3","rune4"],
			"positions":   [Vector2i(2,2), Vector2i(13,2), Vector2i(2,7), Vector2i(13,7)]
		},
	],
	"english": [
		{
			"id":       "eq_noun_collector",
			"title":    "The Noun Collector",
			"giver":    "Wordsmith Vela",
			"giver_id": "eq_giver1",
			"steps": [
				"Find 3 Word Scrolls hidden\naround Lexicon City.",
				"Scroll 1 found!",
				"Scroll 2 found!",
				"All scrolls found! Return to Vela."
			],
			"reward_xp":   150,
			"reward_text": "+150 XP! Vela teaches you a\nrare vocabulary secret!",
			"item_ids":    ["escroll1","escroll2","escroll3"],
			"positions":   [Vector2i(13,3), Vector2i(13,7), Vector2i(1,3)]
		},
		{
			"id":       "eq_grammar_test",
			"title":    "Grammar Gauntlet",
			"giver":    "Gramma Sylvia",
			"giver_id": "eq_giver2",
			"steps": [
				"Pass Sylvia's grammar quiz!",
				"Quiz complete! Return to Sylvia."
			],
			"reward_xp":   100,
			"reward_text": "+100 XP! Your grammar shines!",
			"item_ids":    [],
			"quiz": [
				{"q":"Which is a PROPER NOUN?","opts":["city","river","London","book"],"ans":2,"topic":"nouns","difficulty":1},
				{"q":"How many nouns:\n'The cat sat on a mat.'","opts":["1","2","3","4"],"ans":1,"topic":"nouns","difficulty":1},
			]
		},
		{
			"id":       "eq_library_mystery",
			"title":    "The Library Mystery",
			"giver":    "Librarian Codex",
			"giver_id": "eq_giver3",
			"steps": [
				"A book went missing from the\nLibrary Sanctum.",
				"Check 4 bookshelves for clues.",
				"Clues gathered! Return to Codex."
			],
			"reward_xp":   200,
			"reward_text": "+200 XP! The mystery is solved.\nCodex gives you a Rare Word Card!",
			"item_ids":    ["shelf1","shelf2","shelf3","shelf4"],
			"positions":   [Vector2i(2,2), Vector2i(13,2), Vector2i(2,7), Vector2i(13,7)]
		},
	],
	"music": [
		{
			"id":       "muq_lost_notes",
			"title":    "The Lost Notes",
			"giver":    "Musician Aria",
			"giver_id": "muq_giver1",
			"steps": [
				"Find 3 Musical Notes scattered\naround Harmonia.",
				"Note 1 found!",
				"Note 2 found!",
				"All notes found! Return to Aria."
			],
			"reward_xp":   150,
			"reward_text": "+150 XP! Aria plays a beautiful\nmelody just for you!",
			"item_ids":    ["mnote1","mnote2","mnote3"],
			"positions":   [Vector2i(13,3), Vector2i(13,7), Vector2i(1,3)]
		},
		{
			"id":       "muq_rhythm_test",
			"title":    "The Rhythm Test",
			"giver":    "Beat Master Tempo",
			"giver_id": "muq_giver2",
			"steps": [
				"Tempo challenges you to\nhis rhythm quiz!",
				"Quiz complete! Return to Tempo."
			],
			"reward_xp":   100,
			"reward_text": "+100 XP! Your rhythm is perfect!",
			"item_ids":    [],
			"quiz": [
				{"q":"A QUARTER NOTE gets how\nmany beats?","opts":["1","2","3","4"],"ans":0,"topic":"notes","difficulty":1},
				{"q":"How many lines on\na musical staff?","opts":["3","4","5","6"],"ans":2,"topic":"staff","difficulty":1},
			]
		},
		{
			"id":       "muq_concert_prep",
			"title":    "Concert Preparation",
			"giver":    "Conductor Allegro",
			"giver_id": "muq_giver3",
			"steps": [
				"Help Allegro prepare for the\ngreat Harmonia Concert!",
				"Collect 4 instrument pieces\nhidden around the city.",
				"All pieces collected! The concert\ncan begin!"
			],
			"reward_xp":   200,
			"reward_text": "+200 XP! The concert is a\nmasterpiece. Allegro is proud!",
			"item_ids":    ["inst1","inst2","inst3","inst4"],
			"positions":   [Vector2i(2,2), Vector2i(13,2), Vector2i(2,7), Vector2i(13,7)]
		},
	],
}

func get_quests(world:String)->Array:
	return QUESTS.get(world,[])

func get_active_quest(world:String)->Dictionary:
	for q in QUESTS.get(world,[]):
		if not GameManager.quest_done(q.id): return q
	return {}

func get_quest_step(quest:Dictionary)->int:
	if quest.is_empty(): return 0
	var collected:=0
	for iid in quest.get("item_ids",[]):
		if GameManager.has_item(iid): collected+=1
	return collected

func all_items_collected(quest:Dictionary)->bool:
	for iid in quest.get("item_ids",[]): if not GameManager.has_item(iid): return false
	return true
