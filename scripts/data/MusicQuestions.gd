# MusicQuestions.gd — Music World full question bank
extends Node

static func get_gym1_questions()->Array: return _pool("staff",5)

static func get_gym1_leader()->Dictionary:
	return {
		"world":"music","name":"Maestro Resonus","title":"Conductor of Harmony Hall",
		"badge_name":"Rhythm Badge","gym_number":1,"xp_reward":250,"color":Color("#cc44ff"),
		"intro":["Ah, a new student of sound!","I am Maestro Resonus,\nConductor of Harmony Hall!",
		         "Music is a language of its own.\nLearn to read it.",
		         "5 questions. 3 lives.\n\nPress ENTER to begin!"],
		"win":["Bravo! You hear the music\nin everything now!","The Rhythm Badge is yours!\nYour ears are tuned for greatness.","The symphony of knowledge\ncontinues — press forward!"],
		"lose":["The notes have not sung\nfor you today...","Even Beethoven had to\npractice every day.","Walk the city, listen\nto the melodies. Return soon."]
	}

static func get_all_questions()->Array:
	return [
		# ── STAFF & CLEFS (difficulty 1) ──────────────────────────────────
		{"topic":"staff","difficulty":1,"q":"How many LINES does a standard\nmusical staff have?","opts":["3","4","5","6"],"ans":2,"explain":"A standard staff has 5 lines.\nNotes sit on lines and in spaces."},
		{"topic":"staff","difficulty":1,"q":"What does the TREBLE CLEF mark?","opts":["Play louder","Higher pitched note range","How fast to play","The key signature"],"ans":1,"explain":"Treble clef = higher notes\n(violin, flute, right hand piano)."},
		{"topic":"staff","difficulty":1,"q":"The spaces on a treble staff\nspell (bottom to top)…","opts":["EGBDF","FACE","ACEG","BDFA"],"ans":1,"explain":"The 4 spaces spell FACE.\nLines: Every Good Boy Does Fine."},
		{"topic":"staff","difficulty":1,"q":"What does a BASS CLEF represent?","opts":["High pitched notes","Tempo","Lower pitched note range","Volume"],"ans":2,"explain":"Bass clef = lower notes\n(cello, tuba, left hand piano)."},
		# ── NOTE VALUES (difficulty 1) ────────────────────────────────────
		{"topic":"notes","difficulty":1,"q":"A WHOLE NOTE receives how\nmany beats?","opts":["1","2","3","4"],"ans":3,"explain":"Whole note = 4 beats.\nHalf = 2, Quarter = 1."},
		{"topic":"notes","difficulty":1,"q":"A HALF NOTE receives how\nmany beats?","opts":["1","2","3","4"],"ans":1,"explain":"Half note = 2 beats\n(half of a whole note)."},
		{"topic":"notes","difficulty":1,"q":"A QUARTER NOTE receives how\nmany beats?","opts":["1","2","3","4"],"ans":0,"explain":"Quarter note = 1 beat\n(a quarter of a whole note)."},
		{"topic":"notes","difficulty":1,"q":"A musical note has two parts:\npitch and…","opts":["Color","Duration","Key","Chord"],"ans":1,"explain":"Every note has PITCH (high/low)\nand DURATION (how long)."},
		# ── TIME SIGNATURES (difficulty 2) ────────────────────────────────
		{"topic":"time","difficulty":2,"q":"In 4/4 time, how many\nbeats per measure?","opts":["2","3","4","8"],"ans":2,"explain":"The top number (4) tells you\nbeats per measure."},
		{"topic":"time","difficulty":2,"q":"In 3/4 time the beat count is…","opts":["1-2","1-2-3","1-2-3-4","1-2-3-4-5"],"ans":1,"explain":"3/4 = three beats per measure\n(waltz time)."},
		{"topic":"time","difficulty":2,"q":"What does the BOTTOM number\nin a time signature mean?","opts":["Tempo","Beats per measure","Which note gets one beat","Volume"],"ans":2,"explain":"Bottom number = note type\nthat gets one beat (4=quarter note)."},
		# ── SCALES (difficulty 3) ─────────────────────────────────────────
		{"topic":"scales","difficulty":3,"q":"A MAJOR SCALE has how\nmany notes?","opts":["5","6","7","8"],"ans":3,"explain":"A major scale has 8 notes\n(the 8th repeats the 1st an octave up)."},
		{"topic":"scales","difficulty":3,"q":"The pattern of a MAJOR SCALE is…","opts":["W-W-H-W-W-W-H","W-H-W-W-H-W-W","H-W-W-W-H-W-W","W-W-W-H-W-W-H"],"ans":0,"explain":"W=whole step, H=half step.\nMajor scale: W-W-H-W-W-W-H"},
		{"topic":"scales","difficulty":3,"q":"How many SEMITONES in an octave?","opts":["6","8","10","12"],"ans":3,"explain":"An octave spans 12 semitones\n(all white and black keys)."},
	]

static func _pool(topic:String, count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all:
		if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))

static func get_adaptive_questions(world:String, count:int, player_level:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(), world, player_level, count)
