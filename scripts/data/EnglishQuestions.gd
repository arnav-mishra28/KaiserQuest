# EnglishQuestions.gd  ——  Language World Question Bank  (3 Gyms, 40+ questions)
extends Node

static func get_gym_leader(n: int) -> Dictionary:
	match n:
		1: return {
			"world":"english","name":"Lexis","title":"Keeper of the Noun Sanctum",
			"badge_name":"Grammar Badge","gym_number":1,"xp_reward":300,"color":Color("#c07010"),
			"intro":["Greetings, "+GameManager.player_name+"!",
			         "I am Lexis, Keeper of\nthe Noun Sanctum!",
			         "Words are weapons here.\nNouns are the first you must master.",
			         "5 questions. Click your answer!\n\nBattle start!"],
			"win":["Splendid! Nouns hold\nno secrets from you!",
			       "The Grammar Badge is yours!\nLanguage has chosen you."],
			"lose":["Words escaped you today.\nStudy with Wordsmith Nora!","Return soon!"]}
		2: return {
			"world":"english","name":"Magistra Verbis","title":"Mistress of the Verb Vault",
			"badge_name":"Verb Badge","gym_number":2,"xp_reward":450,"color":Color("#308840"),
			"intro":["A Grammar Badge! Impressive.",
			         "I am Magistra Verbis,\nMistress of the Verb Vault!",
			         "Verbs are the heartbeat\nof every sentence.",
			         "6 questions. Prove your worth!\n\nBattle start!"],
			"win":["Magnificent! Verbs dance\nfor you now!",
			       "The Verb Badge is yours!\nYour language mastery grows."],
			"lose":["Verbs eluded you.\nStudy with Scholar Verbis!","Return stronger!"]}
		3: return {
			"world":"english","name":"Elder Syntaxis","title":"Sage of Sentence Structure",
			"badge_name":"Sentence Badge","gym_number":3,"xp_reward":600,"color":Color("#6030a0"),
			"intro":["Three subjects mastered?\nShow me.",
			         "I am Elder Syntaxis,\nSage of Sentence Structure!",
			         "Sentences are the highest\nform of language craft.",
			         "7 questions. This will test you!\n\nBattle start!"],
			"win":["Extraordinary! Sentences\nflow through you naturally!",
			       "The Sentence Badge is yours!\nYou are nearing Language Kaiser."],
			"lose":["Sentences still confuse you.\nStudy with Poet Adj!","Return!"]}
	return {}

static func get_gym1_leader() -> Dictionary: return get_gym_leader(1)
static func get_gym2_leader() -> Dictionary: return get_gym_leader(2)
static func get_gym3_leader() -> Dictionary: return get_gym_leader(3)

static func get_gym1_questions() -> Array: return _pool("nouns", 5)
static func get_gym2_questions() -> Array: return _pool("verbs", 6)
static func get_gym3_questions() -> Array: return _pool_multi(["sentences","adjectives"], 7)

static func get_all_questions() -> Array:
	return [
	# ─── NOUNS  (difficulty 1) ──────────────────────────────────────────────
	{"topic":"nouns","difficulty":1,
	 "q":"What is a NOUN?",
	 "opts":["An action word","A describing word","A person, place, thing or idea","A connecting word"],
	 "ans":2,"explain":"Nouns name things: people,\nplaces, objects, and ideas."},

	{"topic":"nouns","difficulty":1,
	 "q":"Find the NOUN:\n'The brave knight slept.'",
	 "opts":["brave","slept","The","knight"],
	 "ans":3,"explain":"'Knight' names a person → noun.\n'Brave' = adjective, 'slept' = verb."},

	{"topic":"nouns","difficulty":1,
	 "q":"A PROPER NOUN is...",
	 "opts":["Any noun","Specific name, always capitalised",
	         "A plural noun","A noun used as a verb"],"ans":1,
	 "explain":"Proper nouns: London, Arix, Monday.\nAlways written with a capital letter."},

	{"topic":"nouns","difficulty":1,
	 "q":"How many NOUNS:\n'The cat and the dog ran.'",
	 "opts":["1","2","3","0"],"ans":1,
	 "explain":"'cat' and 'dog' = 2 nouns."},

	{"topic":"nouns","difficulty":1,
	 "q":"Which is a COLLECTIVE NOUN?",
	 "opts":["Run","Beautiful","Flock","Quickly"],"ans":2,
	 "explain":"'Flock' = a group (of birds).\nCollective nouns name groups."},

	{"topic":"nouns","difficulty":1,
	 "q":"Which is an ABSTRACT NOUN?",
	 "opts":["Table","London","Freedom","River"],"ans":2,
	 "explain":"Abstract nouns = ideas or feelings\nyou can't physically touch."},

	{"topic":"nouns","difficulty":1,
	 "q":"'London is beautiful.' — which is\na PROPER NOUN?",
	 "opts":["is","beautiful","London","a"],"ans":2,
	 "explain":"London = specific place → proper noun.\nAlways capitalised."},

	{"topic":"nouns","difficulty":1,
	 "q":"Which sentence contains a NOUN?",
	 "opts":["She runs fast.","The mountain is tall.","Run quickly!","Slowly, carefully."],"ans":1,
	 "explain":"'mountain' is the noun.\nIt names a thing."},

	# ─── VERBS  (difficulty 2) ──────────────────────────────────────────────
	{"topic":"verbs","difficulty":2,
	 "q":"A VERB is a...",
	 "opts":["Describing word","Naming word","Action or state word","Connecting word"],"ans":2,
	 "explain":"Verbs express actions (run, jump)\nor states (is, seems, feels)."},

	{"topic":"verbs","difficulty":2,
	 "q":"Find the VERB:\n'She quickly ran home.'",
	 "opts":["She","quickly","ran","home"],"ans":2,
	 "explain":"'ran' is the action → verb.\n'quickly' = adverb, 'home' = noun."},

	{"topic":"verbs","difficulty":2,
	 "q":"Which sentence uses the\nCORRECT verb tense?",
	 "opts":["He runned fast.","She goed home.","They played football.","We sitted down."],"ans":2,
	 "explain":"'Played' = correct past tense.\nThe others use wrong irregular forms."},

	{"topic":"verbs","difficulty":2,
	 "q":"'He is tall.' — what type\nof verb is 'is'?",
	 "opts":["Action verb","Linking verb","Helping verb","Irregular verb"],"ans":1,
	 "explain":"'Is' links subject to description\n→ linking verb."},

	{"topic":"verbs","difficulty":2,
	 "q":"PAST TENSE of 'eat' is...",
	 "opts":["eated","eat","ate","eating"],"ans":2,
	 "explain":"'eat' is an irregular verb.\nPast tense = 'ate'."},

	{"topic":"verbs","difficulty":2,
	 "q":"FUTURE TENSE of 'run' is...",
	 "opts":["ran","runs","will run","running"],"ans":2,
	 "explain":"Future tense = will + base verb.\nI will run. She will run."},

	{"topic":"verbs","difficulty":2,
	 "q":"Which word is a VERB?\n'The tired dog slept peacefully.'",
	 "opts":["tired","dog","slept","peacefully"],"ans":2,
	 "explain":"'slept' is the action → verb.\n'tired' = adjective, 'peacefully' = adverb."},

	{"topic":"verbs","difficulty":2,
	 "q":"How many verbs:\n'She sings and dances.'",
	 "opts":["1","2","3","0"],"ans":1,
	 "explain":"'sings' and 'dances' = 2 verbs."},

	# ─── ADJECTIVES  (difficulty 2) ─────────────────────────────────────────
	{"topic":"adjectives","difficulty":2,
	 "q":"An ADJECTIVE describes a...",
	 "opts":["Verb","Noun","Adverb","Sentence"],"ans":1,
	 "explain":"Adjectives modify nouns:\n'a tall building' — tall = adjective."},

	{"topic":"adjectives","difficulty":2,
	 "q":"Find the ADJECTIVE:\n'The old bridge collapsed.'",
	 "opts":["The","old","bridge","collapsed"],"ans":1,
	 "explain":"'old' describes 'bridge' → adjective."},

	{"topic":"adjectives","difficulty":2,
	 "q":"What is the COMPARATIVE of 'big'?",
	 "opts":["most big","bigger","biggest","very big"],"ans":1,
	 "explain":"Comparative = -er form.\nbig → bigger → biggest"},

	{"topic":"adjectives","difficulty":2,
	 "q":"What is the SUPERLATIVE of 'fast'?",
	 "opts":["faster","fastest","most fast","very fast"],"ans":1,
	 "explain":"Superlative = -est form (or most).\nfast → faster → fastest"},

	# ─── SENTENCES  (difficulty 3) ──────────────────────────────────────────
	{"topic":"sentences","difficulty":3,
	 "q":"A complete sentence must have...",
	 "opts":["Only a noun","Only a verb","A subject AND predicate","An adjective and noun"],"ans":2,
	 "explain":"Every sentence = subject (who)\n+ predicate (what they do)."},

	{"topic":"sentences","difficulty":3,
	 "q":"Which is a COMPOUND SENTENCE?",
	 "opts":["She ran.","The dog barked.",
	         "He sang and she danced.","Beautiful morning."],"ans":2,
	 "explain":"Compound = 2 independent clauses\njoined by a conjunction (and, but, or)."},

	{"topic":"sentences","difficulty":3,
	 "q":"A COMPLEX SENTENCE contains...",
	 "opts":["Two main clauses","A main and a subordinate clause",
	         "Only one verb","No conjunctions"],"ans":1,
	 "explain":"Complex = main clause +\nsubordinate clause (because, although…)."},

	{"topic":"sentences","difficulty":3,
	 "q":"Which sentence is in\nPASSIVE VOICE?",
	 "opts":["The dog bit the man.","She wrote the letter.",
	         "The letter was written by her.","They ate the cake."],"ans":2,
	 "explain":"Passive: subject receives action.\n'The letter WAS WRITTEN by her.'"},

	{"topic":"sentences","difficulty":3,
	 "q":"'Although it rained, we played.'\nThis sentence type is...",
	 "opts":["Simple","Compound","Complex","Fragment"],"ans":2,
	 "explain":"'Although it rained' = subordinate.\n'we played' = main. → Complex."},

	# ─── ADVANCED (difficulty 4) ────────────────────────────────────────────
	{"topic":"advanced","difficulty":4,
	 "q":"What is a GERUND?",
	 "opts":["A type of noun","A verb used as a noun","A describing word","A type of clause"],"ans":1,
	 "explain":"Gerund = verb + -ing used as noun.\n'Swimming is fun.' — Swimming = gerund."},

	{"topic":"advanced","difficulty":4,
	 "q":"What is an INFINITIVE?",
	 "opts":["Past tense verb","'to' + base verb","Noun phrase","Adjective clause"],"ans":1,
	 "explain":"Infinitive = to + verb.\n'I want to run.' — to run = infinitive."},

	{"topic":"advanced","difficulty":4,
	 "q":"'He runs quickly.' — 'quickly' is...",
	 "opts":["Adjective","Verb","Adverb","Noun"],"ans":2,
	 "explain":"'quickly' modifies the verb 'runs'\n→ adverb. Adverbs modify verbs."},
	]

static func _pool(topic: String, count: int) -> Array:
	var all := get_all_questions(); var pool: Array = []
	for q in all:
		if q.topic == topic: pool.append(q)
	if pool.size() < count: pool = get_all_questions().duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func _pool_multi(topics: Array, count: int) -> Array:
	var all := get_all_questions(); var pool: Array = []
	for q in all:
		if q.topic in topics: pool.append(q)
	if pool.size() < count: pool = get_all_questions().duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func get_adaptive_questions(world: String, count: int, lv: int) -> Array:
	return AdaptiveAI.adaptive_select(get_all_questions(), world, lv, count)
