# AlgebraQuestions.gd
extends Node
static func get_gym1_questions()->Array: return _pool("variables",5)
static func get_gym1_leader()->Dictionary:
	return {"world":"math","name":"Prof. Axiom","title":"Guardian of the Variable Citadel",
	        "badge_name":"Variable Badge","gym_number":1,"xp_reward":300,"color":Color("#2060d0"),
	        "intro":["Welcome, young "+GameManager.player_name+"!","I am Professor Axiom!\nGuardian of the Variable Citadel!",
	                 "Variables are the foundation\nof all algebra.","5 questions. 3 lives each.\nCorrect = Attack! Wrong = Damage!\n\nPress ENTER to battle!"],
	        "win":["Incredible! Variables hold\nno secrets from you now!","The Variable Badge is yours!\nWear it with pride!","The path to Silver Mountain\nbegins here!"],
	        "lose":["A brave effort...","Variables still hold secrets.\nStudy with the teachers!","Return when you are stronger!"]}
static func get_all_questions()->Array:
	return [
		{"topic":"variables","difficulty":1,"q":"What does a VARIABLE represent?","opts":["A fixed number","A symbol for an unknown","A math operation","A type of equation"],"ans":1,"explain":"Variables (x,y,n) represent\nunknown or changing values."},
		{"topic":"variables","difficulty":1,"q":"If  x = 5,  what is  x + 3 ?","opts":["5","3","8","15"],"ans":2,"explain":"x + 3 = 5 + 3 = 8"},
		{"topic":"variables","difficulty":1,"q":"Solve:   x + 4 = 9","opts":["x=4","x=5","x=13","x=2"],"ans":1,"explain":"Subtract 4 from both sides:\nx = 9 - 4 = 5"},
		{"topic":"variables","difficulty":1,"q":"Which of these is a VARIABLE?","opts":["7","3.14","y","100"],"ans":2,"explain":"Letters like y, x, z are variables."},
		{"topic":"variables","difficulty":1,"q":"If y = 3x and x = 4, find y.","opts":["7","34","12","1"],"ans":2,"explain":"y = 3 × 4 = 12"},
		{"topic":"variables","difficulty":1,"q":"If x = 2, what is 5x?","opts":["7","10","52","25"],"ans":1,"explain":"5x = 5×2 = 10"},
		{"topic":"variables","difficulty":1,"q":"Solve: x - 3 = 7","opts":["x=4","x=10","x=3","x=21"],"ans":1,"explain":"Add 3: x = 7+3 = 10"},
		{"topic":"linear","difficulty":2,"q":"Solve: 2x = 14","opts":["x=7","x=12","x=28","x=2"],"ans":0,"explain":"Divide both sides by 2:\nx = 7"},
		{"topic":"linear","difficulty":2,"q":"Solve: 3x + 1 = 10","opts":["x=3","x=4","x=9","x=11"],"ans":0,"explain":"3x=9, x=3"},
		{"topic":"linear","difficulty":2,"q":"Solve: 5x - 5 = 20","opts":["x=3","x=4","x=5","x=25"],"ans":2,"explain":"5x=25, x=5"},
		{"topic":"functions","difficulty":3,"q":"If f(x) = 2x + 1, find f(3).","opts":["5","6","7","8"],"ans":2,"explain":"f(3) = 2(3)+1 = 7"},
		{"topic":"functions","difficulty":3,"q":"A FUNCTION maps each input to\nhow many outputs?","opts":["Zero","Exactly one","Two","Many"],"ans":1,"explain":"A function maps each input to\nEXACTLY one output."},
	]
static func _pool(topic:String,count:int)->Array:
	var all:=get_all_questions(); var pool:=[]
	for q in all: if q.topic==topic: pool.append(q)
	if pool.size()<count: pool=all.slice(0,count)
	pool.shuffle(); return pool.slice(0,min(count,pool.size()))
static func get_adaptive_questions(world:String,count:int,lv:int)->Array:
	return AdaptiveAI.adaptive_select(get_all_questions(),world,lv,count)
