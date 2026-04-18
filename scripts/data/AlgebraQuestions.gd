# AlgebraQuestions.gd  ——  Math World Question Bank  (3 Gyms, 40+ questions)
extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  GYM LEADERS
# ══════════════════════════════════════════════════════════════════════════════
static func get_gym_leader(n: int) -> Dictionary:
	match n:
		1: return {
			"world":"math","name":"Prof. Axiom","title":"Guardian of the Variable Citadel",
			"badge_name":"Variable Badge","gym_number":1,"xp_reward":300,"color":Color("#2060d0"),
			"intro":["Welcome, young "+GameManager.player_name+"!",
			         "I am Professor Axiom!\nGuardian of the Variable Citadel!",
			         "Variables are the foundation\nof all algebra.",
			         "5 questions. 3 lives.\nClick or press ENTER to answer!\n\nBattle start!"],
			"win":["Incredible! You understand\nvariables perfectly!",
			       "The Variable Badge is yours!\nWear it with pride!",
			       "The path to Silver Mountain\nhas begun!"],
			"lose":["Variables still hold secrets.\nStudy with the Teachers!","Return when stronger!"]}
		2: return {
			"world":"math","name":"Magistra Lin","title":"Master of the Equation Tower",
			"badge_name":"Equation Badge","gym_number":2,"xp_reward":450,"color":Color("#10a060"),
			"intro":["So you have the Variable Badge!\nImpressive.",
			         "I am Magistra Lin, Master\nof the Equation Tower!",
			         "Linear equations are my domain.\nCan you solve them under pressure?",
			         "6 questions. 3 lives.\nGood luck!\n\nBattle start!"],
			"win":["Magnificent! Linear equations\nbend to your will!",
			       "The Equation Badge is yours!\nYour algebra grows strong."],
			"lose":["Linear equations defeated you.\nPractice with Scholar Equa!","Return when ready!"]}
		3: return {
			"world":"math","name":"Elder Quadrix","title":"Sage of the Function Peaks",
			"badge_name":"Function Badge","gym_number":3,"xp_reward":600,"color":Color("#c04020"),
			"intro":["Three badges means true dedication.",
			         "I am Elder Quadrix,\nSage of the Function Peaks!",
			         "Functions are the language\nof mathematics itself.",
			         "7 questions. 3 lives.\nThis will test you!\n\nBattle start!"],
			"win":["Extraordinary! Functions reveal\ntheir secrets to you!",
			       "The Function Badge is yours!\nYou are becoming a true Kaiser."],
			"lose":["Functions still elude you.\nStudy with Elder Func!","Return when you are stronger!"]}
	return {}

# Convenience aliases used by World.gd
static func get_gym1_leader() -> Dictionary: return get_gym_leader(1)
static func get_gym2_leader() -> Dictionary: return get_gym_leader(2)
static func get_gym3_leader() -> Dictionary: return get_gym_leader(3)

static func get_gym1_questions() -> Array: return _pool("variables", 5)
static func get_gym2_questions() -> Array: return _pool("linear", 6)
static func get_gym3_questions() -> Array: return _pool_multi(["functions","quadratic"], 7)

# ══════════════════════════════════════════════════════════════════════════════
#  FULL QUESTION BANK  (4 topics × difficulty 1–4)
# ══════════════════════════════════════════════════════════════════════════════
static func get_all_questions() -> Array:
	return [
	# ─── VARIABLES  (difficulty 1) ──────────────────────────────────────────
	{"topic":"variables","difficulty":1,
	 "q":"What does a VARIABLE represent\nin algebra?",
	 "opts":["A fixed number","A symbol for an unknown","A math operation","An equation type"],
	 "ans":1,"explain":"Variables (x, y, n…) stand in\nfor unknown or changing values."},

	{"topic":"variables","difficulty":1,
	 "q":"If  x = 5,  what is  x + 3?",
	 "opts":["5","3","8","15"],"ans":2,
	 "explain":"Substitute: x + 3 = 5 + 3 = 8"},

	{"topic":"variables","difficulty":1,
	 "q":"Solve for x:    x + 4 = 9",
	 "opts":["x = 4","x = 5","x = 13","x = 2"],"ans":1,
	 "explain":"Subtract 4 both sides:\nx = 9 − 4 = 5"},

	{"topic":"variables","difficulty":1,
	 "q":"Which of these is a VARIABLE?",
	 "opts":["7","3.14","y","100"],"ans":2,
	 "explain":"Letters (x, y, z) are variables.\nNumbers like 7 are constants."},

	{"topic":"variables","difficulty":1,
	 "q":"If  y = 3x  and  x = 4,  find y.",
	 "opts":["7","34","12","1"],"ans":2,
	 "explain":"y = 3 × 4 = 12"},

	{"topic":"variables","difficulty":1,
	 "q":"If  x = 2,  what is  5x?",
	 "opts":["7","10","52","25"],"ans":1,
	 "explain":"5x = 5 × 2 = 10"},

	{"topic":"variables","difficulty":1,
	 "q":"Solve:    x − 3 = 7",
	 "opts":["x = 4","x = 10","x = 3","x = 21"],"ans":1,
	 "explain":"Add 3 to both sides:\nx = 7 + 3 = 10"},

	{"topic":"variables","difficulty":1,
	 "q":"Constants are values that\n___ change.",
	 "opts":["always","sometimes","do not","randomly"],"ans":2,
	 "explain":"Constants (like 5 or π) never change.\nVariables can change."},

	# ─── LINEAR EQUATIONS  (difficulty 2) ───────────────────────────────────
	{"topic":"linear","difficulty":2,
	 "q":"Solve:    2x = 14",
	 "opts":["x = 7","x = 12","x = 28","x = 2"],"ans":0,
	 "explain":"Divide both sides by 2:\nx = 14 ÷ 2 = 7"},

	{"topic":"linear","difficulty":2,
	 "q":"Solve:    3x + 1 = 10",
	 "opts":["x = 3","x = 4","x = 9","x = 11"],"ans":0,
	 "explain":"Subtract 1: 3x = 9\nDivide by 3: x = 3"},

	{"topic":"linear","difficulty":2,
	 "q":"Solve:    5x − 5 = 20",
	 "opts":["x = 3","x = 4","x = 5","x = 25"],"ans":2,
	 "explain":"Add 5: 5x = 25\nDivide by 5: x = 5"},

	{"topic":"linear","difficulty":2,
	 "q":"Which equation is LINEAR?",
	 "opts":["x² = 4","x³ + 1 = 0","2x + 3 = 7","x² − x = 0"],"ans":2,
	 "explain":"Linear = highest power is 1.\n2x + 3 = 7 has no exponents."},

	{"topic":"linear","difficulty":2,
	 "q":"Solve:    x/4 = 3",
	 "opts":["x = 7","x = 12","x = 0.75","x = 1"],"ans":1,
	 "explain":"Multiply both sides by 4:\nx = 3 × 4 = 12"},

	{"topic":"linear","difficulty":2,
	 "q":"Solve:    2x − 6 = 0",
	 "opts":["x = 6","x = 3","x = 0","x = 12"],"ans":1,
	 "explain":"Add 6: 2x = 6\nDivide by 2: x = 3"},

	{"topic":"linear","difficulty":2,
	 "q":"If  4x = 36,  what is x?",
	 "opts":["x = 4","x = 9","x = 32","x = 40"],"ans":1,
	 "explain":"x = 36 ÷ 4 = 9"},

	{"topic":"linear","difficulty":2,
	 "q":"Solve:    x + 8 = 2x − 4",
	 "opts":["x = 4","x = 12","x = 6","x = 2"],"ans":1,
	 "explain":"x − 2x = −4 − 8\n−x = −12  →  x = 12"},

	{"topic":"linear","difficulty":2,
	 "q":"What is the SLOPE in y = 3x + 2?",
	 "opts":["2","3","x","0"],"ans":1,
	 "explain":"y = mx + b form.\nThe slope m = 3."},

	# ─── FUNCTIONS  (difficulty 3) ───────────────────────────────────────────
	{"topic":"functions","difficulty":3,
	 "q":"If f(x) = 2x + 1,  find f(3).",
	 "opts":["5","6","7","8"],"ans":2,
	 "explain":"f(3) = 2(3) + 1 = 6 + 1 = 7"},

	{"topic":"functions","difficulty":3,
	 "q":"A FUNCTION maps each input to\nhow many outputs?",
	 "opts":["Zero","Exactly one","Two","Many"],"ans":1,
	 "explain":"Definition: each input maps\nto EXACTLY one output."},

	{"topic":"functions","difficulty":3,
	 "q":"What is the DOMAIN of a function?",
	 "opts":["The output values","The graph","The valid input set","The equation type"],"ans":2,
	 "explain":"Domain = all valid INPUT values\nthat the function accepts."},

	{"topic":"functions","difficulty":3,
	 "q":"If g(x) = x² ,  find g(4).",
	 "opts":["8","12","16","4"],"ans":2,
	 "explain":"g(4) = 4² = 4 × 4 = 16"},

	{"topic":"functions","difficulty":3,
	 "q":"What is the RANGE of a function?",
	 "opts":["The input values","All possible outputs","The domain","The slope"],"ans":1,
	 "explain":"Range = all possible OUTPUT\nvalues the function produces."},

	{"topic":"functions","difficulty":3,
	 "q":"If h(x) = 3x − 5,  find h(0).",
	 "opts":["0","−5","5","3"],"ans":1,
	 "explain":"h(0) = 3(0) − 5 = 0 − 5 = −5"},

	{"topic":"functions","difficulty":3,
	 "q":"Which represents a FUNCTION?",
	 "opts":["One input, two outputs","Two inputs, one output",
	         "Each input, exactly one output","Many inputs, no output"],"ans":2,
	 "explain":"A function: each input gives\nexactly one output. Always."},

	# ─── QUADRATICS  (difficulty 4) ─────────────────────────────────────────
	{"topic":"quadratic","difficulty":4,
	 "q":"What is the STANDARD FORM\nof a quadratic?",
	 "opts":["y = mx + b","ax² + bx + c = 0","x = a + b","y = x + c"],"ans":1,
	 "explain":"Standard form: ax² + bx + c = 0\nwhere a ≠ 0."},

	{"topic":"quadratic","difficulty":4,
	 "q":"How many solutions can a\nquadratic have at most?",
	 "opts":["1","2","3","Infinite"],"ans":1,
	 "explain":"A quadratic (degree 2) has\nat most 2 real solutions."},

	{"topic":"quadratic","difficulty":4,
	 "q":"Solve:    x² = 9",
	 "opts":["x = 3","x = ±3","x = 4.5","x = 9"],"ans":1,
	 "explain":"x² = 9  →  x = ±√9 = ±3\nTwo solutions: 3 and −3."},

	{"topic":"quadratic","difficulty":4,
	 "q":"The VERTEX of y = x² is at…",
	 "opts":["(1, 1)","(0, 0)","(−1, 1)","(0, 1)"],"ans":1,
	 "explain":"y = x² has vertex at (0, 0)\n— the minimum point."},

	{"topic":"quadratic","difficulty":4,
	 "q":"Which value does the DISCRIMINANT\n(b²−4ac) determine?",
	 "opts":["The vertex","The slope","Number of real solutions","The y-intercept"],"ans":2,
	 "explain":"Discriminant > 0: 2 solutions\n= 0: 1 solution  < 0: no real solutions"},

	{"topic":"quadratic","difficulty":4,
	 "q":"Factor:    x² + 5x + 6",
	 "opts":["(x+1)(x+6)","(x+2)(x+3)","(x+3)(x+2)","(x−2)(x−3)"],"ans":1,
	 "explain":"(x+2)(x+3) = x²+5x+6 ✓\n2×3=6 and 2+3=5"},
	]

# ── Pool helpers ──────────────────────────────────────────────────────────────
static func _pool(topic: String, count: int) -> Array:
	var all := get_all_questions(); var pool: Array = []
	for q in all:
		if q.topic == topic: pool.append(q)
	if pool.size() < count:
		pool = get_all_questions().duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func _pool_multi(topics: Array, count: int) -> Array:
	var all := get_all_questions(); var pool: Array = []
	for q in all:
		if q.topic in topics: pool.append(q)
	if pool.size() < count:
		pool = get_all_questions().duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

static func get_adaptive_questions(world: String, count: int, lv: int) -> Array:
	return AdaptiveAI.adaptive_select(get_all_questions(), world, lv, count)
