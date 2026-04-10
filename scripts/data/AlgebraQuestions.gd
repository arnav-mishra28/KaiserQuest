# AlgebraQuestions.gd — Math World full question bank
extends Node

static func get_gym1_questions()->Array:
	return _pool("variables",5)

static func get_gym1_leader()->Dictionary:
	return {
		"world":"math","name":"Prof. Axiom","title":"Guardian of the Variable Citadel",
		"badge_name":"Variable Badge","gym_number":1,"xp_reward":250,"color":Color("#44aaff"),
		"intro":["Welcome, young Arix!","I am Professor Axiom,\nGuardian of the Variable Citadel!",
		         "Variables are the foundation\nof all algebra.",
		         "5 questions. 3 lives.\n\nPress ENTER to begin!"],
		"win":["Incredible! Variables hold\nno secrets from you now!","The Variable Badge is yours!\nWear it with pride.","The path to Silver Mountain\nbegins here!"],
		"lose":["A brave effort...","Variables still hold their\nsecrets from you.","Explore more and return\nwhen you are stronger!"]
	}

# Full question pool with topics and difficulties
static func get_all_questions()->Array:
	return [
		# ── VARIABLES (difficulty 1) ──────────────────────────────────────
		{"topic":"variables","difficulty":1,"q":"What does a VARIABLE represent\nin algebra?","opts":["A fixed number","A symbol for an unknown value","A math operation","A type of equation"],"ans":1,"explain":"Variables (x, y, n…) represent\nunknown or changing values."},
		{"topic":"variables","difficulty":1,"q":"If  x = 5,  what is  x + 3 ?","opts":["5","3","8","15"],"ans":2,"explain":"Substitute x=5:\nx + 3 = 5 + 3 = 8"},
		{"topic":"variables","difficulty":1,"q":"Solve:   x + 4 = 9","opts":["x=4","x=5","x=13","x=2"],"ans":1,"explain":"Subtract 4 from both sides:\nx = 9 – 4 = 5"},
		{"topic":"variables","difficulty":1,"q":"Which of these is a VARIABLE?","opts":["7","3.14","y","100"],"ans":2,"explain":"Letters like y, x, z are variables.\nNumbers are constants."},
		{"topic":"variables","difficulty":1,"q":"If  y = 3x  and  x = 4,  find y.","opts":["7","34","12","1"],"ans":2,"explain":"y = 3×4 = 12"},
		{"topic":"variables","difficulty":1,"q":"If  x = 2,  what is  5x ?","opts":["7","10","52","25"],"ans":1,"explain":"5x = 5×2 = 10"},
		{"topic":"variables","difficulty":1,"q":"Solve:   x - 3 = 7","opts":["x=4","x=10","x=3","x=21"],"ans":1,"explain":"Add 3 to both sides:\nx = 7 + 3 = 10"},
		# ── LINEAR EQUATIONS (difficulty 2) ──────────────────────────────
		{"topic":"linear","difficulty":2,"q":"Solve:   2x = 14","opts":["x=7","x=12","x=28","x=2"],"ans":0,"explain":"Divide both sides by 2:\nx = 14÷2 = 7"},
		{"topic":"linear","difficulty":2,"q":"Solve:   3x + 1 = 10","opts":["x=3","x=4","x=9","x=11"],"ans":0,"explain":"Subtract 1: 3x=9\nDivide by 3: x=3"},
		{"topic":"linear","difficulty":2,"q":"Solve:   5x - 5 = 20","opts":["x=3","x=4","x=5","x=25"],"ans":2,"explain":"Add 5: 5x=25\nDivide by 5: x=5"},
		{"topic":"linear","difficulty":2,"q":"Which equation is LINEAR?","opts":["x²=4","x³+1=0","2x+3=7","x²-x=0"],"ans":2,"explain":"A linear equation has no\npowers — highest degree is 1."},
		{"topic":"linear","difficulty":2,"q":"Solve:   x/4 = 3","opts":["x=7","x=12","x=0.75","x=1"],"ans":1,"explain":"Multiply both sides by 4:\nx = 3×4 = 12"},
		# ── FUNCTIONS (difficulty 3) ──────────────────────────────────────
		{"topic":"functions","difficulty":3,"q":"A FUNCTION maps each input to\nhow many outputs?","opts":["Zero","Exactly one","Two","Many"],"ans":1,"explain":"A function maps each input\nto EXACTLY one output."},
		{"topic":"functions","difficulty":3,"q":"If f(x) = 2x + 1,  find f(3).","opts":["5","6","7","8"],"ans":2,"explain":"f(3) = 2(3)+1 = 6+1 = 7"},
		{"topic":"functions","difficulty":3,"q":"What is the DOMAIN of a function?","opts":["The output values","The graph shape","The set of valid inputs","The equation type"],"ans":2,"explain":"Domain = all valid INPUT values\nfor the function."},
	]

static func _pool(topic:String, count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all:
		if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))

static func get_adaptive_questions(world:String, count:int, player_level:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(), world, player_level, count)
