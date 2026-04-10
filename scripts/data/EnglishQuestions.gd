# EnglishQuestions.gd — Language World full question bank
extends Node

static func get_gym1_questions()->Array: return _pool("nouns",5)

static func get_gym1_leader()->Dictionary:
	return {
		"world":"english","name":"Lexis","title":"Keeper of the Noun Sanctum",
		"badge_name":"Grammar Badge","gym_number":1,"xp_reward":250,"color":Color("#ffcc44"),
		"intro":["Greetings, young wordsmith!","I am Lexis, Keeper of\nthe Noun Sanctum!",
		         "Words are your weapons.\nNouns are the first you must master.",
		         "5 questions. 3 lives.\n\nPress ENTER to begin!"],
		"win":["Splendid! Nouns hold no\nsecrets from you now!","The Grammar Badge is yours!\nLanguage has chosen you.","Continue through Lexicon City,\nfuture Kaiser of Language!"],
		"lose":["Hmm... words escaped you today.","Even great wordsmiths\nstumble at first.","Return and listen to what\nthe people say. Then try again!"]
	}

static func get_all_questions()->Array:
	return [
		# ── NOUNS (difficulty 1) ──────────────────────────────────────────
		{"topic":"nouns","difficulty":1,"q":"What is a NOUN?","opts":["An action word","A describing word","A person, place, thing, or idea","A connecting word"],"ans":2,"explain":"Nouns name things: people,\nplaces, things, or ideas."},
		{"topic":"nouns","difficulty":1,"q":"Which word is a NOUN?\n'The brave knight slept.'","opts":["brave","slept","The","knight"],"ans":3,"explain":"'Knight' names a person\n— it is a noun."},
		{"topic":"nouns","difficulty":1,"q":"A PROPER NOUN is…","opts":["Any noun","A noun naming a specific\nperson or place","A plural noun","A noun used as a verb"],"ans":1,"explain":"Proper nouns name specific\nthings — always capitalized."},
		{"topic":"nouns","difficulty":1,"q":"How many NOUNS are in:\n'The cat and the dog ran.'","opts":["1","2","3","0"],"ans":1,"explain":"'Cat' and 'dog' = 2 nouns."},
		{"topic":"nouns","difficulty":1,"q":"Which is a COLLECTIVE NOUN?","opts":["Run","Beautiful","Flock","Quickly"],"ans":2,"explain":"'Flock' names a group\n(a flock of birds)."},
		{"topic":"nouns","difficulty":1,"q":"Which is an ABSTRACT NOUN?","opts":["Table","London","Freedom","River"],"ans":2,"explain":"Abstract nouns name ideas\nor concepts you can't touch."},
		{"topic":"nouns","difficulty":1,"q":"'London is beautiful.' — which\nword is a PROPER NOUN?","opts":["is","beautiful","London","a"],"ans":2,"explain":"London is a specific place\n— a proper noun."},
		# ── VERBS (difficulty 2) ──────────────────────────────────────────
		{"topic":"verbs","difficulty":2,"q":"A VERB is a…","opts":["Describing word","Naming word","Action or state word","Connecting word"],"ans":2,"explain":"Verbs express actions (run)\nor states (is, seem)."},
		{"topic":"verbs","difficulty":2,"q":"Which is a VERB?\n'She quickly ran home.'","opts":["She","quickly","ran","home"],"ans":2,"explain":"'Ran' is the action\nin this sentence."},
		{"topic":"verbs","difficulty":2,"q":"Which sentence uses the\ncorrect verb tense?","opts":["He runned fast.","She goed home.","They played football.","We sitted down."],"ans":2,"explain":"'Played' is correct past tense.\nThe others are irregular errors."},
		{"topic":"verbs","difficulty":2,"q":"'He is tall.' — what type\nof verb is 'is'?","opts":["Action verb","Linking verb","Helping verb","Irregular verb"],"ans":1,"explain":"'Is' links subject to description\n— it is a linking verb."},
		# ── ADJECTIVES (difficulty 2) ─────────────────────────────────────
		{"topic":"adjectives","difficulty":2,"q":"An ADJECTIVE describes a…","opts":["Verb","Noun","Adverb","Sentence"],"ans":1,"explain":"Adjectives modify nouns:\n'a tall building' — tall = adjective."},
		{"topic":"adjectives","difficulty":2,"q":"Find the ADJECTIVE:\n'The old bridge collapsed.'","opts":["The","old","bridge","collapsed"],"ans":1,"explain":"'Old' describes the noun\n'bridge' — it is an adjective."},
		# ── SENTENCES (difficulty 3) ──────────────────────────────────────
		{"topic":"sentences","difficulty":3,"q":"A complete sentence must have…","opts":["Only a noun","Only a verb","A subject AND a predicate","An adjective and a noun"],"ans":2,"explain":"Every sentence needs a subject\n(who) and predicate (what they do)."},
		{"topic":"sentences","difficulty":3,"q":"Which is a COMPOUND SENTENCE?","opts":["She ran.","The dog barked.","He sang and she danced.","Beautiful morning."],"ans":2,"explain":"A compound sentence joins two\nindependent clauses with a conjunction."},
	]

static func _pool(topic:String, count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all:
		if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))

static func get_adaptive_questions(world:String, count:int, player_level:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(), world, player_level, count)
