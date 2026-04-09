# AlgebraQuestions.gd
# Question bank for Algebra story mode (Autoload)
extends Node

# ── Gym 1: Variables ──────────────────────────────────────────────────────────
func get_gym1_questions() -> Array:
	return [
		{
			"q":       "What is a variable in algebra?",
			"opts":    [
				"A number that never changes",
				"A symbol representing an unknown value",
				"A type of equation",
				"A mathematical operation"
			],
			"ans":     1,
			"explain": "A variable (like x, y, or n) is a symbol\nthat represents an unknown or changing value."
		},
		{
			"q":       "If  x = 5,  what is  x + 3 ?",
			"opts":    ["5", "3", "8", "15"],
			"ans":     2,
			"explain": "Substitute x = 5:\nx + 3  =  5 + 3  =  8"
		},
		{
			"q":       "Solve for x:\n   x + 4 = 9",
			"opts":    ["x = 4", "x = 5", "x = 13", "x = 2"],
			"ans":     1,
			"explain": "Subtract 4 from both sides:\nx  =  9 - 4  =  5"
		},
		{
			"q":       "Which of these is a variable?",
			"opts":    ["7", "3.14", "y", "100"],
			"ans":     2,
			"explain": "Letters like  y, x, z  are variables.\n7, 3.14, and 100 are constants (fixed numbers)."
		},
		{
			"q":       "If  y = 3x  and  x = 4,  what is y ?",
			"opts":    ["7", "34", "12", "1"],
			"ans":     2,
			"explain": "Substitute x = 4:\ny  =  3 × 4  =  12"
		},
	]

# ── Gym 1 Leader Data ─────────────────────────────────────────────────────────
func get_gym1_leader() -> Dictionary:
	return {
		"name":       "Prof. Axiom",
		"title":      "Guardian of the Variable Keep",
		"badge_name": "Variable Badge",
		"gym_number": 1,
		"xp_reward":  250,
		"intro": [
			"Greetings, young scholar!",
			"I am Professor Axiom,\nGuardian of the Variable Keep!",
			"Variables are the very foundation\nof all algebra.",
			"Prove your mastery with 5 questions.\nYou have 3 lives.\n\n  — Press ENTER to begin —"
		],
		"win": [
			"Magnificent! You truly understand\nthe power of variables!",
			"The Variable Badge is yours!\nWear it with pride.",
			"May it guide your path toward\nbecoming Kaiser of Algebra!"
		],
		"lose": [
			"A valiant effort...",
			"But the Variable Keep still holds\nits secrets from you.",
			"Review your notes, rest, and\nreturn when you are ready!"
		]
	}
