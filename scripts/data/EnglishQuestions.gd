# EnglishQuestions.gd  —  Language World question bank
extends Node

static func get_gym1_questions() -> Array:
	return [
		{
			"q":       "What is a NOUN?",
			"opts":    ["An action word","A describing word",
			            "A person, place, thing, or idea","A connecting word"],
			"ans":     2,
			"explain": "Nouns name things: people (teacher),\nplaces (city), things (book), ideas (freedom)."
		},
		{
			"q":       "Which word is a NOUN\nin this sentence?\n'The brave knight slept.'",
			"opts":    ["brave","slept","The","knight"],
			"ans":     3,
			"explain": "'Knight' is a noun — it names a person.\n'Brave' is an adjective, 'slept' is a verb."
		},
		{
			"q":       "A PROPER NOUN is…",
			"opts":    ["Any noun","A noun naming a specific person or place",
			            "A plural noun","A noun used as a verb"],
			"ans":     1,
			"explain": "Proper nouns name specific things and\nare always capitalized: London, Arix, Monday."
		},
		{
			"q":       "How many nouns are in:\n'The cat and the dog ran.'",
			"opts":    ["1","2","3","0"],
			"ans":     1,
			"explain": "'Cat' and 'dog' are both nouns.\nThat makes 2 nouns in the sentence."
		},
		{
			"q":       "Which is a COLLECTIVE NOUN?",
			"opts":    ["Run","Beautiful","Flock","Quickly"],
			"ans":     2,
			"explain": "'Flock' is a collective noun — it names\na group (a flock of birds)."
		},
	]

static func get_gym1_leader() -> Dictionary:
	return {
		"world":      "english",
		"name":       "Lexis",
		"title":      "Keeper of the Noun Sanctum",
		"badge_name": "Grammar Badge",
		"gym_number": 1,
		"xp_reward":  250,
		"color":      Color("#ffcc44"),
		"intro": [
			"Greetings, young wordsmith!",
			"I am Lexis, Keeper of\nthe Noun Sanctum!",
			"Words are your weapons here.\nNouns are the first you must master.",
			"5 questions stand between you\nand the Grammar Badge.\n\nPress ENTER to begin!"
		],
		"win": [
			"Splendid! Your knowledge of\nnouns is truly impressive!",
			"The Grammar Badge is yours!\nLanguage has chosen you.",
			"Continue your journey through\nLexicon City, future Kaiser!"
		],
		"lose": [
			"Hmm... words escaped you today.",
			"Even the greatest wordsmiths\nstumble at first.",
			"Return to the city and listen\nto what the people say. Then try again!"
		]
	}
