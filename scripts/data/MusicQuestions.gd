# MusicQuestions.gd  ——  Music World Question Bank  (3 Gyms, 40+ questions)
extends Node

static func get_gym_leader(n: int) -> Dictionary:
	match n:
		1: return {
			"world":"music","name":"Maestro Resonus","title":"Conductor of Harmony Hall",
			"badge_name":"Rhythm Badge","gym_number":1,"xp_reward":300,"color":Color("#8020c0"),
			"intro":["Ah, a student of sound!\nI am Maestro Resonus!",
			         "Conductor of Harmony Hall\nand guardian of the staff.",
			         "Music is a language.\nLearn to read it.",
			         "5 questions. Click your answer!\n\nBattle start!"],
			"win":["Bravo! You hear the music\nin everything!",
			       "The Rhythm Badge is yours!\nYour ears are tuned for greatness."],
			"lose":["Notes escaped you today.\nStudy with Maestro Staffa!","Return soon!"]}
		2: return {
			"world":"music","name":"Maestra Harmona","title":"Guardian of the Chord Citadel",
			"badge_name":"Harmony Badge","gym_number":2,"xp_reward":450,"color":Color("#c040a0"),
			"intro":["Rhythm Badge! You have talent.",
			         "I am Maestra Harmona,\nGuardian of the Chord Citadel!",
			         "Chords are combinations\nof notes played together.",
			         "6 questions. Make music!\n\nBattle start!"],
			"win":["Magnificent! Chords sing\nfor you now!",
			       "The Harmony Badge is yours!\nYour music theory grows deep."],
			"lose":["Chords still puzzle you.\nStudy with Rhythm Master!","Return stronger!"]}
		3: return {
			"world":"music","name":"Grandmaster Scala","title":"Sage of the Scale Peaks",
			"badge_name":"Scale Badge","gym_number":3,"xp_reward":600,"color":Color("#2080c0"),
			"intro":["Two badges! You have\nproven yourself.",
			         "I am Grandmaster Scala,\nSage of the Scale Peaks!",
			         "Scales are the architecture\nof all music.",
			         "7 questions. This will test you!\n\nBattle start!"],
			"win":["Extraordinary! Scales rise\nand fall for you!",
			       "The Scale Badge is yours!\nYou are nearing Music Kaiser."],
			"lose":["Scales still elude you.\nStudy with Elder Harmona!","Return!"]}
	return {}

static func get_gym1_leader() -> Dictionary: return get_gym_leader(1)
static func get_gym2_leader() -> Dictionary: return get_gym_leader(2)
static func get_gym3_leader() -> Dictionary: return get_gym_leader(3)

static func get_gym1_questions() -> Array: return _pool("staff", 5)
static func get_gym2_questions() -> Array: return _pool_multi(["notes","chords"], 6)
static func get_gym3_questions() -> Array: return _pool_multi(["scales","time"], 7)

static func get_all_questions() -> Array:
	return [
	# ─── STAFF & CLEFS  (difficulty 1) ──────────────────────────────────────
	{"topic":"staff","difficulty":1,
	 "q":"How many LINES does a standard\nmusical staff have?",
	 "opts":["3","4","5","6"],"ans":2,
	 "explain":"A standard staff = 5 lines.\nNotes sit ON lines and IN spaces."},

	{"topic":"staff","difficulty":1,
	 "q":"What does the TREBLE CLEF mark?",
	 "opts":["Play louder","Higher-pitched note range",
	         "How fast to play","The key signature"],"ans":1,
	 "explain":"Treble clef = higher notes\n(violin, flute, right-hand piano)."},

	{"topic":"staff","difficulty":1,
	 "q":"The SPACES on a treble staff\nspell (bottom to top)...",
	 "opts":["EGBDF","FACE","ACEG","BDFA"],"ans":1,
	 "explain":"4 spaces = F-A-C-E.\nLines = Every Good Boy Does Fine."},

	{"topic":"staff","difficulty":1,
	 "q":"What does the BASS CLEF represent?",
	 "opts":["High notes","Tempo","Lower note range","Volume"],"ans":2,
	 "explain":"Bass clef = lower notes\n(cello, bass guitar, left-hand piano)."},

	{"topic":"staff","difficulty":1,
	 "q":"A musical note has two parts:\npitch and...",
	 "opts":["Color","Duration","Key","Chord"],"ans":1,
	 "explain":"Every note: PITCH (high/low)\nand DURATION (how long)."},

	{"topic":"staff","difficulty":1,
	 "q":"The lines on a treble staff are\n(bottom to top)...",
	 "opts":["EGBDF","FACE","ACEG","BDFA"],"ans":0,
	 "explain":"Lines = E-G-B-D-F.\nMemory: Every Good Boy Does Fine."},

	# ─── NOTE VALUES  (difficulty 1) ────────────────────────────────────────
	{"topic":"notes","difficulty":1,
	 "q":"A WHOLE NOTE receives how many beats?",
	 "opts":["1","2","3","4"],"ans":3,
	 "explain":"Whole note = 4 beats.\nHalf = 2, Quarter = 1, Eighth = ½."},

	{"topic":"notes","difficulty":1,
	 "q":"A HALF NOTE receives how many beats?",
	 "opts":["1","2","3","4"],"ans":1,
	 "explain":"Half note = 2 beats.\n(Half of a whole note's 4 beats.)"},

	{"topic":"notes","difficulty":1,
	 "q":"A QUARTER NOTE receives how many beats?",
	 "opts":["1","2","3","4"],"ans":0,
	 "explain":"Quarter note = 1 beat.\nIt's a quarter of a whole note."},

	{"topic":"notes","difficulty":1,
	 "q":"An EIGHTH NOTE receives how many beats?",
	 "opts":["4","2","1","½"],"ans":3,
	 "explain":"Eighth note = ½ beat.\nTwo eighth notes = one quarter note."},

	{"topic":"notes","difficulty":2,
	 "q":"A DOTTED HALF NOTE holds...",
	 "opts":["2 beats","3 beats","4 beats","2.5 beats"],"ans":1,
	 "explain":"Dot adds half the note's value:\n2 + 1 = 3 beats."},

	{"topic":"notes","difficulty":2,
	 "q":"How many QUARTER NOTES\nequal one WHOLE NOTE?",
	 "opts":["2","3","4","8"],"ans":2,
	 "explain":"Whole = 4 beats.\nQuarter = 1 beat. 4 × 1 = 4."},

	# ─── CHORDS  (difficulty 2) ──────────────────────────────────────────────
	{"topic":"chords","difficulty":2,
	 "q":"A CHORD is...",
	 "opts":["A single note","Two or more notes played together",
	         "A musical rest","A type of clef"],"ans":1,
	 "explain":"Chord = multiple notes\nplayed simultaneously."},

	{"topic":"chords","difficulty":2,
	 "q":"A MAJOR chord sounds...",
	 "opts":["Sad and dark","Bright and happy","Tense and unresolved","Quiet"],"ans":1,
	 "explain":"Major chords have a bright,\nhappy quality (like C-E-G)."},

	{"topic":"chords","difficulty":2,
	 "q":"A MINOR chord sounds...",
	 "opts":["Bright and happy","Sad or dark","Angry","Silent"],"ans":1,
	 "explain":"Minor chords have a darker,\nsadder quality (like A-C-E)."},

	{"topic":"chords","difficulty":2,
	 "q":"How many notes in a basic TRIAD?",
	 "opts":["2","3","4","5"],"ans":1,
	 "explain":"A triad = 3 notes:\nroot, third, and fifth."},

	{"topic":"chords","difficulty":3,
	 "q":"The notes C-E-G form a...",
	 "opts":["C minor triad","G major triad","C major triad","A minor triad"],"ans":2,
	 "explain":"C-E-G = C major triad.\nC is the root, E is major third, G is fifth."},

	{"topic":"chords","difficulty":3,
	 "q":"What is the TONIC chord?",
	 "opts":["Built on the 4th degree","Built on the 1st degree (root)",
	         "Built on the 5th degree","A dissonant chord"],"ans":1,
	 "explain":"Tonic = chord built on scale degree 1.\nIt's the 'home' chord."},

	# ─── TIME SIGNATURES  (difficulty 2) ────────────────────────────────────
	{"topic":"time","difficulty":2,
	 "q":"In 4/4 time, how many\nbeats per measure?",
	 "opts":["2","3","4","8"],"ans":2,
	 "explain":"Top number = beats per measure.\n4/4 = 4 beats per measure."},

	{"topic":"time","difficulty":2,
	 "q":"In 3/4 time the beat count is...",
	 "opts":["1-2","1-2-3","1-2-3-4","1-2-3-4-5"],"ans":1,
	 "explain":"3/4 = three beats per measure.\nThis is waltz time."},

	{"topic":"time","difficulty":2,
	 "q":"The BOTTOM number in a time signature\nindicates...",
	 "opts":["Tempo","Beats per measure","Which note gets one beat","Volume"],"ans":2,
	 "explain":"Bottom number = note type.\n4 = quarter note gets the beat."},

	{"topic":"time","difficulty":3,
	 "q":"6/8 time has __ beats per measure\nwith __ as the beat unit.",
	 "opts":["6 beats, eighth note","2 beats, dotted quarter",
	         "3 beats, quarter note","4 beats, eighth note"],"ans":1,
	 "explain":"6/8 = felt in 2 dotted-quarter beats.\n6 eighth notes per measure."},

	# ─── SCALES  (difficulty 3) ──────────────────────────────────────────────
	{"topic":"scales","difficulty":3,
	 "q":"A MAJOR SCALE has how many notes?",
	 "opts":["5","6","7","8"],"ans":3,
	 "explain":"Major scale = 8 notes\n(the 8th repeats the first, one octave up)."},

	{"topic":"scales","difficulty":3,
	 "q":"The pattern of whole and half steps\nin a MAJOR SCALE is...",
	 "opts":["W-W-H-W-W-W-H","W-H-W-W-H-W-W","H-W-W-W-H-W-W","W-W-W-H-W-W-H"],"ans":0,
	 "explain":"W=whole step, H=half step.\nMajor scale: W-W-H-W-W-W-H"},

	{"topic":"scales","difficulty":3,
	 "q":"How many SEMITONES in an octave?",
	 "opts":["6","8","10","12"],"ans":3,
	 "explain":"12 semitones (half steps)\nspan one octave (all 12 piano keys)."},

	{"topic":"scales","difficulty":3,
	 "q":"A PENTATONIC SCALE has how many notes?",
	 "opts":["3","5","7","8"],"ans":1,
	 "explain":"Penta = five. Pentatonic = 5 notes.\nWidely used in blues and folk music."},

	{"topic":"scales","difficulty":4,
	 "q":"The C MAJOR SCALE consists of...",
	 "opts":["All black keys","C-D-E-F-G-A-B","C-D-Eb-F-G-Ab-Bb","C-E-G-B-D"],"ans":1,
	 "explain":"C major = all white keys:\nC-D-E-F-G-A-B-C"},

	{"topic":"scales","difficulty":4,
	 "q":"A NATURAL MINOR SCALE follows\nthe pattern...",
	 "opts":["W-W-H-W-W-W-H","W-H-W-W-H-W-W","H-W-W-H-W-W-W","W-W-W-H-W-W-H"],"ans":1,
	 "explain":"Natural minor = W-H-W-W-H-W-W.\nThis is the Aeolian mode."},
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
