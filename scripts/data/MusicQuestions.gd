# MusicQuestions.gd  —  Music World question bank
extends Node

static func get_gym1_questions() -> Array:
	return [
		{
			"q":       "How many LINES does a standard\nmusical staff have?",
			"opts":    ["3","4","5","6"],
			"ans":     2,
			"explain": "A standard staff has 5 lines.\nNotes sit ON lines and IN the spaces."
		},
		{
			"q":       "What does a TREBLE CLEF tell you?",
			"opts":    ["Play louder","The pitch range for higher notes",
			            "How fast to play","The key signature"],
			"ans":     1,
			"explain": "The treble clef marks the staff for\nhigher-pitched notes (violin, flute, etc)."
		},
		{
			"q":       "How many beats does a\nWHOLE NOTE receive?",
			"opts":    ["1","2","3","4"],
			"ans":     3,
			"explain": "A whole note = 4 beats.\nA half note = 2, a quarter note = 1."
		},
		{
			"q":       "What is the name of the\nspaces on a treble clef staff?\n(bottom to top)",
			"opts":    ["EGBDF","FACE","ACEG","BDFA"],
			"ans":     1,
			"explain": "The 4 spaces spell FACE from bottom to top.\nLines are Every Good Boy Does Fine."
		},
		{
			"q":       "A musical NOTE has two parts:\npitch and…?",
			"opts":    ["Color","Duration","Key","Chord"],
			"ans":     1,
			"explain": "Every note has PITCH (how high/low)\nand DURATION (how long it is held)."
		},
	]

static func get_gym1_leader() -> Dictionary:
	return {
		"world":      "music",
		"name":       "Maestro Resonus",
		"title":      "Conductor of the Harmony Hall",
		"badge_name": "Rhythm Badge",
		"gym_number": 1,
		"xp_reward":  250,
		"color":      Color("#cc44ff"),
		"intro": [
			"Ah, a new student of sound!",
			"I am Maestro Resonus,\nConductor of Harmony Hall!",
			"Music is a language of its own.\nLearn to read it and you hear everything.",
			"5 questions of rhythm and notes\nawait you.  3 lives.\n\nPress ENTER to begin!"
		],
		"win": [
			"Bravo! You hear the music\nin everything, I can tell!",
			"The Rhythm Badge is yours!\nYour ears are tuned to greatness.",
			"The symphony of knowledge\ncontinues — press forward, future Kaiser!"
		],
		"lose": [
			"The notes have not yet\nsung for you today...",
			"Even Beethoven had to\npractice before he composed.",
			"Walk the city, listen\nto the melodies around you.  Return soon."
		]
	}
