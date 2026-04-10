# AlgebraQuestions.gd  —  Math World question bank
extends Node

static func get_gym1_questions() -> Array:
	return [
		{
			"q":       "What does a VARIABLE represent\nin algebra?",
			"opts":    ["A fixed number","A symbol for an unknown value",
			            "A math operation","A type of equation"],
			"ans":     1,
			"explain": "Variables (x, y, n…) are symbols that\nhold unknown or changing values."
		},
		{
			"q":       "If  x = 5,  what is  x + 3 ?",
			"opts":    ["5","3","8","15"],
			"ans":     2,
			"explain": "Substitute x = 5:\n  x + 3  =  5 + 3  =  8"
		},
		{
			"q":       "Solve:   x + 4 = 9",
			"opts":    ["x = 4","x = 5","x = 13","x = 2"],
			"ans":     1,
			"explain": "Subtract 4 from both sides:\n  x  =  9 – 4  =  5"
		},
		{
			"q":       "Which of these is a VARIABLE?",
			"opts":    ["7","3.14","y","100"],
			"ans":     2,
			"explain": "Letters like y, x, z are variables.\nNumbers like 7 or 100 are constants."
		},
		{
			"q":       "If  y = 3x  and  x = 4,  find y.",
			"opts":    ["7","34","12","1"],
			"ans":     2,
			"explain": "Substitute x = 4:\n  y  =  3 × 4  =  12"
		},
	]

static func get_gym1_leader() -> Dictionary:
	return {
		"world":      "math",
		"name":       "Prof. Axiom",
		"title":      "Guardian of the Variable Citadel",
		"badge_name": "Variable Badge",
		"gym_number": 1,
		"xp_reward":  250,
		"color":      Color("#44aaff"),
		"intro": [
			"Welcome, young Arix!",
			"I am Professor Axiom,\nGuardian of the Variable Citadel!",
			"Variables are the foundation\nof all algebra.",
			"Answer 5 questions correctly.\nYou have 3 lives.\n\nPress ENTER to begin!"
		],
		"win": [
			"Incredible!  You have proven\nyour mastery of variables!",
			"The Variable Badge is yours!\nWear it with pride, future Kaiser.",
			"The path to Silver Mountain\nbegins here!"
		],
		"lose": [
			"A brave effort, young scholar...",
			"But variables still hold\ntheir secrets from you.",
			"Review your notes and return\nwhen you are stronger!"
		]
	}
