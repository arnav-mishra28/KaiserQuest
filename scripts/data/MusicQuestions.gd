# MusicQuestions.gd
extends Node
static func get_gym1_questions()->Array: return _pool("staff",5)
static func get_gym1_leader()->Dictionary:
	return {"world":"music","name":"Maestro Resonus","title":"Conductor of Harmony Hall",
	        "badge_name":"Rhythm Badge","gym_number":1,"xp_reward":300,"color":Color("#8020c0"),
	        "intro":["Ah, "+GameManager.player_name+"!\nA new student of sound!","I am Maestro Resonus,\nConductor of Harmony Hall!",
	                 "Music is a language of its own.\nLearn to read it!","5 questions. Correct = Attack!\nWrong = Damage!\n\nPress ENTER to battle!"],
	        "win":["Bravo! You hear the music\nin everything!","The Rhythm Badge is yours!\nYour ears are tuned for greatness.","The symphony of knowledge\ncontinues forward!"],
	        "lose":["The notes have not sung\nfor you today...","Even Beethoven practiced\nevery single day.","Walk the city, listen to melodies.\nReturn when ready."]}
static func get_all_questions()->Array:
	return [
		{"topic":"staff","difficulty":1,"q":"How many LINES does a\nmusical staff have?","opts":["3","4","5","6"],"ans":2,"explain":"A standard staff has 5 lines.\nNotes sit on lines and in spaces."},
		{"topic":"staff","difficulty":1,"q":"What does the TREBLE CLEF mark?","opts":["Play louder","Higher pitched notes","How fast to play","Key signature"],"ans":1,"explain":"Treble clef = higher notes\n(violin, flute, right hand piano)."},
		{"topic":"staff","difficulty":1,"q":"The spaces on a treble staff\nspell (bottom to top)…","opts":["EGBDF","FACE","ACEG","BDFA"],"ans":1,"explain":"The 4 spaces spell FACE.\nLines: Every Good Boy Does Fine."},
		{"topic":"notes","difficulty":1,"q":"A WHOLE NOTE gets how\nmany beats?","opts":["1","2","3","4"],"ans":3,"explain":"Whole = 4 beats.\nHalf = 2, Quarter = 1."},
		{"topic":"notes","difficulty":1,"q":"A HALF NOTE gets how\nmany beats?","opts":["1","2","3","4"],"ans":1,"explain":"Half note = 2 beats."},
		{"topic":"notes","difficulty":1,"q":"A QUARTER NOTE gets how\nmany beats?","opts":["1","2","3","4"],"ans":0,"explain":"Quarter note = 1 beat."},
		{"topic":"notes","difficulty":1,"q":"A note has pitch and…?","opts":["Color","Duration","Key","Chord"],"ans":1,"explain":"Every note has PITCH (high/low)\nand DURATION (how long)."},
		{"topic":"time","difficulty":2,"q":"In 4/4 time, how many\nbeats per measure?","opts":["2","3","4","8"],"ans":2,"explain":"The top number = beats per measure."},
		{"topic":"time","difficulty":2,"q":"In 3/4 time the beat is…","opts":["1-2","1-2-3","1-2-3-4","1-2-3-4-5"],"ans":1,"explain":"3/4 = three beats per measure (waltz)."},
		{"topic":"scales","difficulty":3,"q":"A MAJOR SCALE has how\nmany notes?","opts":["5","6","7","8"],"ans":3,"explain":"A major scale has 8 notes\n(8th repeats 1st an octave up)."},
		{"topic":"scales","difficulty":3,"q":"The major scale pattern is…","opts":["W-W-H-W-W-W-H","W-H-W-W-H-W-W","H-W-W-W-H-W-W","W-W-W-H-W-W-H"],"ans":0,"explain":"W=whole step, H=half step.\nMajor: W-W-H-W-W-W-H"},
		{"topic":"scales","difficulty":3,"q":"C Major uses…","opts":["All black keys","All white keys","Mixed keys","Only sharps"],"ans":1,"explain":"C Major scale uses all white keys\non a piano!"},
	]
static func _pool(topic:String,count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all: if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))
static func get_adaptive_questions(world:String,count:int,lv:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(),world,lv,count)
