# EnglishQuestions.gd
extends Node
static func get_gym1_questions()->Array: return _pool("nouns",5)
static func get_gym1_leader()->Dictionary:
	return {"world":"english","name":"Lexis","title":"Keeper of the Noun Sanctum",
	        "badge_name":"Grammar Badge","gym_number":1,"xp_reward":300,"color":Color("#c07010"),
	        "intro":["Greetings, "+GameManager.player_name+"!","I am Lexis, Keeper of\nthe Noun Sanctum!",
	                 "Words are your weapons here.\nNouns are the first you must master.","5 questions. Correct = Attack!\nWrong = Damage!\n\nPress ENTER to battle!"],
	        "win":["Splendid! Nouns hold no\nsecrets from you now!","The Grammar Badge is yours!\nLanguage has chosen you.","Continue your journey,\nfuture Kaiser of Language!"],
	        "lose":["Hmm... words escaped you.","Study with the Teachers\nand return stronger!","Every great wordsmith\nstumbles at first."]}
static func get_all_questions()->Array:
	return [
		{"topic":"nouns","difficulty":1,"q":"What is a NOUN?","opts":["An action word","A describing word","A person, place, thing, or idea","A connecting word"],"ans":2,"explain":"Nouns name: people, places,\nthings, or ideas."},
		{"topic":"nouns","difficulty":1,"q":"Which word is a NOUN?\n'The brave knight slept.'","opts":["brave","slept","The","knight"],"ans":3,"explain":"'Knight' names a person\n— it is a noun."},
		{"topic":"nouns","difficulty":1,"q":"A PROPER NOUN is…","opts":["Any noun","A noun naming a specific\nperson or place","A plural noun","A noun used as a verb"],"ans":1,"explain":"Proper nouns name specific\nthings — always capitalized."},
		{"topic":"nouns","difficulty":1,"q":"How many nouns in:\n'The cat and the dog ran.'","opts":["1","2","3","0"],"ans":1,"explain":"'Cat' and 'dog' = 2 nouns."},
		{"topic":"nouns","difficulty":1,"q":"Which is a COLLECTIVE NOUN?","opts":["Run","Beautiful","Flock","Quickly"],"ans":2,"explain":"'Flock' names a group\n(a flock of birds)."},
		{"topic":"nouns","difficulty":1,"q":"Which is an ABSTRACT NOUN?","opts":["Table","London","Freedom","River"],"ans":2,"explain":"Abstract nouns name ideas\nor concepts you can't touch."},
		{"topic":"verbs","difficulty":2,"q":"A VERB is a…","opts":["Describing word","Naming word","Action or state word","Connecting word"],"ans":2,"explain":"Verbs express actions (run)\nor states (is, seem)."},
		{"topic":"verbs","difficulty":2,"q":"Which is a VERB?\n'She quickly ran home.'","opts":["She","quickly","ran","home"],"ans":2,"explain":"'Ran' is the action."},
		{"topic":"verbs","difficulty":2,"q":"Correct past tense?","opts":["He runned fast.","She goed home.","They played football.","We sitted down."],"ans":2,"explain":"'Played' is correct past tense."},
		{"topic":"adjectives","difficulty":2,"q":"An ADJECTIVE describes a…","opts":["Verb","Noun","Adverb","Sentence"],"ans":1,"explain":"Adjectives modify nouns:\n'a tall building'."},
		{"topic":"adjectives","difficulty":2,"q":"Find the ADJECTIVE:\n'The old bridge collapsed.'","opts":["The","old","bridge","collapsed"],"ans":1,"explain":"'Old' describes the noun 'bridge'."},
		{"topic":"sentences","difficulty":3,"q":"A complete sentence must have…","opts":["Only a noun","Only a verb","Subject AND predicate","An adjective and noun"],"ans":2,"explain":"Every sentence needs subject\n(who) and predicate (what)."},
	]
static func _pool(topic:String,count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all: if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))
static func get_adaptive_questions(world:String,count:int,lv:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(),world,lv,count)
