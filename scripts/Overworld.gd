# Overworld.gd — Multi-world pixel town with elaborate gym buildings
extends Node2D

signal show_dialog(lines: Array)
signal start_gym_battle(gym_data: Dictionary)
signal gain_xp(amount: int, context: String)

# ── World ID (set before adding to scene) ────────────────────────────────────
var world_id: String = "math"

# ── Tile IDs ─────────────────────────────────────────────────────────────────
const TS    := 32
const COLS  := 15
const ROWS  := 10
const GRASS := 0; const TREE  := 1; const HOUSE := 2; const HDOOR := 3
const PATH  := 4; const GWALL := 5; const GDOOR := 6; const ITEM  := 7
const WATER := 8; const FENCE := 9

const WALKABLE := [GRASS, PATH, ITEM]

# ── Shared map layout (same for all worlds, different art) ───────────────────
const MAP := [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,5,5,5,5,5,5,0,0,0,0,1],
	[1,0,0,0,5,5,5,5,5,5,0,2,2,0,1],
	[1,0,0,0,5,5,6,5,5,5,0,2,2,0,1],
	[1,0,0,0,4,4,4,4,4,0,0,3,0,0,1],
	[1,0,0,4,4,0,0,0,0,0,0,0,0,0,1],
	[1,2,2,4,0,0,0,0,0,0,7,0,0,0,1],
	[1,3,0,4,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,4,4,4,4,4,4,4,4,4,4,0,0,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]

# ── Player state ──────────────────────────────────────────────────────────────
var _p_grid:   Vector2i = Vector2i(2, 8)
var _p_pixel:  Vector2  = Vector2(64, 256)
var _p_dir:    int      = 0   # 0=down 1=up 2=left 3=right
var _p_moving: bool     = false
var _p_frame:  int      = 0
var _anim_t:   float    = 0.0
var _anim_global: float = 0.0   # for ambient animations
var _dialog_open: bool  = false
var _gym_cleared: bool  = false
var _tween:    Tween    = null

# ── Config cache ──────────────────────────────────────────────────────────────
var _cfg: Dictionary = {}

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("overworld")
	_cfg         = _get_config()
	_p_grid      = GameManager.get_grid_pos()
	_p_pixel     = Vector2(_p_grid.x * TS, _p_grid.y * TS)
	_gym_cleared = GameManager.has_badge(_cfg.badge_name)
	set_process(true)
	set_process_input(true)

func set_dialog_open(v: bool) -> void:
	_dialog_open = v
	set_process_input(not v)

# ═══════════════════════════════════════════════════════════════════════════════
# WORLD CONFIGS
# ═══════════════════════════════════════════════════════════════════════════════
func _get_config() -> Dictionary:
	match world_id:
		"english": return _cfg_english()
		"music":   return _cfg_music()
		_:         return _cfg_math()

func _cfg_math() -> Dictionary:
	return {
		"town_name":  "Mathopolis",
		"gym_name":   "Axiom Academy",
		"badge_name": "Variable Badge",
		"gym_num":    1,
		"leader":     AlgebraDB.get_gym1_leader(),
		"questions":  AlgebraDB.get_gym1_questions(),
		"pal": {
			"sky":      Color("#0a0a1e"), "grass1": Color("#3a7a28"),
			"grass2":   Color("#2e6a20"), "tree":   Color("#1a3a0e"),
			"tree_lt":  Color("#225014"), "bark":   Color("#4a2808"),
			"path1":    Color("#8899aa"), "path2":  Color("#7788aa"),
			"house_w":  Color("#c0cce0"), "house_r": Color("#223366"),
			"house_win":Color("#aaccff"), "h_door": Color("#4455aa"),
			"fence":    Color("#556677"),
			"gwall":    Color("#1a3a8a"), "groof":  Color("#0a2060"),
			"gaccent":  Color("#44aaff"), "gdoor":  Color("#66ccff"),
			"gsymcol":  Color("#ffffff"), "gsign":  Color("#ffd700"),
		},
		"npcs": [
			{"id":"m_npc1","pos":Vector2i(1,2),"shirt":Color("#e8c830"),"xp":50,
			 "lines":["Psst! The blue tower ahead\nis the Axiom Academy!",
					  "Professor Axiom guards the\nVariable Badge inside.",
					  "Reach Level 5 and\nyou can challenge him!"]},
			{"id":"m_npc2","pos":Vector2i(10,2),"shirt":Color("#30a030"),"xp":50,
			 "lines":["A variable is just a letter\nstanding in for a number.",
					  "Like a mask at a masquerade —\nyou have to reveal who's underneath!",
					  "Solve for x, and unmask\nthe hidden value."]},
			{"id":"m_npc3","pos":Vector2i(13,5),"shirt":Color("#cc3030"),"xp":50,
			 "lines":["This is Mathopolis — city of\nequations and sharp minds!",
					  "Every building here was\ndesigned using perfect geometry.",
					  "Even the path tiles are\nexactly 32 units wide!"]},
			{"id":"m_npc4","pos":Vector2i(4,6),"shirt":Color("#9090b0"),"xp":50,
			 "lines":["I'm studying for the\nAxiom Academy challenge.",
					  "The trick is to isolate x —\nget it alone on one side.",
					  "x + 4 = 9\nSubtract 4 ... x = 5!"]},
		],
		"item": {
			"id":"algebra_scroll","pos":Vector2i(10,6),"xp":200,
			"lines":["You found an Algebra Scroll! ✦",
					 "'A variable holds a place for\nwhat we do not yet know.'",
					 "'Name the unknown, and you\nhave begun to solve the puzzle.'",
					 "+200 XP gained!"]
		},
	}

func _cfg_english() -> Dictionary:
	return {
		"town_name":  "Lexicon City",
		"gym_name":   "The Grand Lexicon",
		"badge_name": "Grammar Badge",
		"gym_num":    1,
		"leader":     EnglishDB.get_gym1_leader(),
		"questions":  EnglishDB.get_gym1_questions(),
		"pal": {
			"sky":      Color("#1a0e08"), "grass1": Color("#5a8040"),
			"grass2":   Color("#4e7035"), "tree":   Color("#2a4010"),
			"tree_lt":  Color("#386018"), "bark":   Color("#6a3818"),
			"path1":    Color("#c8a870"), "path2":  Color("#b89060"),
			"house_w":  Color("#d4b882"), "house_r": Color("#6a2a10"),
			"house_win":Color("#ffd080"), "h_door": Color("#5a2808"),
			"fence":    Color("#8a6030"),
			"gwall":    Color("#8a4a10"), "groof":  Color("#5a2a06"),
			"gaccent":  Color("#ffcc44"), "gdoor":  Color("#ffa020"),
			"gsymcol":  Color("#fff8e0"), "gsign":  Color("#ffd700"),
		},
		"npcs": [
			{"id":"e_npc1","pos":Vector2i(1,2),"shirt":Color("#c06820"),"xp":50,
			 "lines":["Welcome to Lexicon City,\nCity of Words and Wisdom!",
					  "The Grand Lexicon towers over\nall other buildings here.",
					  "Maestra Vera awaits inside —\nshe tests all who enter!"]},
			{"id":"e_npc2","pos":Vector2i(10,2),"shirt":Color("#2060a0"),"xp":50,
			 "lines":["Grammar is the architecture\nof language.",
					  "Without rules, words collapse\ninto noise.",
					  "Learn the rules first —\nthen you can bend them!"]},
			{"id":"e_npc3","pos":Vector2i(13,5),"shirt":Color("#a03050"),"xp":50,
			 "lines":["Every great writer started\nwith the basics.",
					  "Nouns, verbs, adjectives —\nthe building blocks of thought.",
					  "Master Grammar and all\nother subjects become easier."]},
			{"id":"e_npc4","pos":Vector2i(4,6),"shirt":Color("#608030"),"xp":50,
			 "lines":["I keep re-reading my notes\nbefore entering the Lexicon.",
					  "Tip: a noun names things,\na verb shows action.",
					  "Adjectives describe nouns.\nPronounts replace them!"]},
		],
		"item": {
			"id":"ancient_scroll","pos":Vector2i(10,6),"xp":200,
			"lines":["You found an Ancient Scroll! ✦",
					 "'In the beginning was the Word,\nand the Word had grammar.'",
					 "'Every sentence is a small\narchitectural masterpiece.'",
					 "+200 XP gained!"]
		},
	}

func _cfg_music() -> Dictionary:
	return {
		"town_name":  "Harmonia Town",
		"gym_name":   "Harmony Hall",
		"badge_name": "Treble Badge",
		"gym_num":    1,
		"leader":     MusicDB.get_gym1_leader(),
		"questions":  MusicDB.get_gym1_questions(),
		"pal": {
			"sky":      Color("#080018"), "grass1": Color("#2a5a50"),
			"grass2":   Color("#225048"), "tree":   Color("#1a3a30"),
			"tree_lt":  Color("#2a5045"), "bark":   Color("#4a2830"),
			"path1":    Color("#504070"), "path2":  Color("#403060"),
			"house_w":  Color("#3a2858"), "house_r": Color("#1a1040"),
			"house_win":Color("#cc88ff"), "h_door": Color("#5a2880"),
			"fence":    Color("#4a3060"),
			"gwall":    Color("#3a1060"), "groof":  Color("#220840"),
			"gaccent":  Color("#dd44ff"), "gdoor":  Color("#bb22ee"),
			"gsymcol":  Color("#ffccff"), "gsign":  Color("#ffd700"),
		},
		"npcs": [
			{"id":"mu_npc1","pos":Vector2i(1,2),"shirt":Color("#8822aa"),"xp":50,
			 "lines":["Harmonia Town — where\nevery breeze carries a melody!",
					  "Maestro Riko teaches inside\nHarmony Hall.",
					  "You'll need Level 5 to\nenroll in his class!"]},
			{"id":"mu_npc2","pos":Vector2i(10,2),"shirt":Color("#228844"),"xp":50,
			 "lines":["Music Theory is the math\nof sound.",
					  "Learn the staff, the clefs,\nthe note values...",
					  "Then you can read ANY\npiece of music ever written!"]},
			{"id":"mu_npc3","pos":Vector2i(13,5),"shirt":Color("#cc4488"),"xp":50,
			 "lines":["I practice reading music\nevery single day.",
					  "The five lines of the staff\nare like a ladder for notes.",
					  "Higher on the staff =\nhigher the pitch!"]},
			{"id":"mu_npc4","pos":Vector2i(4,6),"shirt":Color("#4488cc"),"xp":50,
			 "lines":["Did you know the treble clef\ncurls around the G line?",
					  "That's why it's sometimes called\nthe G clef!",
					  "Every Good Boy Does Fine —\nE G B D F on the lines."]},
		],
		"item": {
			"id":"music_tablet","pos":Vector2i(10,6),"xp":200,
			"lines":["You found a Music Tablet! ✦",
					 "'Music gives color to the air\nof the moment.' — Karl Lagerfeld",
					 "'Without music, life would be\na mistake.' — Nietzsche",
					 "+200 XP gained!"]
		},
	}

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT & MOVEMENT
# ═══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if _dialog_open or _p_moving:
		return
	var dir := Vector2i.ZERO
	if   event.is_action_pressed("ui_down"):  dir = Vector2i(0,1);  _p_dir = 0
	elif event.is_action_pressed("ui_up"):    dir = Vector2i(0,-1); _p_dir = 1
	elif event.is_action_pressed("ui_left"):  dir = Vector2i(-1,0); _p_dir = 2
	elif event.is_action_pressed("ui_right"): dir = Vector2i(1,0);  _p_dir = 3
	elif event.is_action_pressed("ui_accept"):
		_try_interact(); return
	if dir != Vector2i.ZERO:
		_try_move(_p_grid + dir)

func _try_move(dest: Vector2i) -> void:
	var t := _tile_at(dest)
	if t == GDOOR:
		_try_enter_gym(); return
	if t in WALKABLE:
		_move_to(dest)
		if t == ITEM and dest == _cfg.item.pos and not GameManager.has_item(_cfg.item.id):
			_collect_item()

func _move_to(dest: Vector2i) -> void:
	_p_grid  = dest
	_p_moving = true
	GameManager.set_grid_pos(dest)
	var tpx := Vector2(dest.x * TS, dest.y * TS)
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v:Vector2):_p_pixel=v;queue_redraw(), _p_pixel, tpx, 0.13)
	_tween.tween_callback(func(): _p_moving = false)

func _try_interact() -> void:
	var front := _p_grid + _dir_vec(_p_dir)
	for npc in _cfg.npcs:
		if npc.pos == front: _talk_npc(npc); return
	if front == _cfg.item.pos and not GameManager.has_item(_cfg.item.id):
		_collect_item(); return
	if _tile_at(front) == GDOOR: _try_enter_gym(); return
	if _tile_at(front) == HDOOR: show_dialog.emit(["The door is locked."]); return

func _talk_npc(npc: Dictionary) -> void:
	var lines: Array = npc.lines.duplicate()
	if not GameManager.has_talked_to(npc.id):
		GameManager.mark_talked(npc.id)
		lines.append("(+" + str(npc.xp) + " XP!)")
		set_process_input(false)
		show_dialog.emit(lines)
		await get_tree().create_timer(0.05).timeout
		gain_xp.emit(npc.xp, "")
	else:
		set_process_input(false)
		show_dialog.emit(lines)

func _collect_item() -> void:
	GameManager.collect_item(_cfg.item.id)
	set_process_input(false)
	show_dialog.emit(_cfg.item.lines)
	gain_xp.emit(_cfg.item.xp, "")
	queue_redraw()

func _try_enter_gym() -> void:
	if _gym_cleared:
		show_dialog.emit(["You already earned the " + _cfg.badge_name + "!\nThe gym leader nods with pride."])
		return
	if not GameManager.can_challenge_gym(_cfg.gym_num):
		show_dialog.emit([
			_cfg.gym_name + " — The gate holds firm!",
			"You need Level " + str(_cfg.gym_num * 5) + " to enter.\nYou are Level " + str(GameManager.get_level()) + ".",
			"Explore " + _cfg.town_name + " to gain XP first!"
		]); return
	var data = _cfg.leader.duplicate()
	data["questions"] = _cfg.questions
	start_gym_battle.emit(data)

func _tile_at(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= ROWS or pos.x < 0 or pos.x >= COLS: return TREE
	return MAP[pos.y][pos.x]

func _dir_vec(d: int) -> Vector2i:
	match d:
		0:
			return Vector2i(0, 1)
		1:
			return Vector2i(0, -1)
		2:
			return Vector2i(-1, 0)
		3:
			return Vector2i(1, 0)

	return Vector2i.ZERO

# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS & DRAW
# ═══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	_anim_t      += delta
	_anim_global += delta
	if _anim_t >= 0.22:
		_anim_t  = 0.0
		_p_frame = 1 - _p_frame
	queue_redraw()

func _draw() -> void:
	var p = _cfg.pal
	_draw_sky(p)
	_draw_tiles(p)
	_draw_decorations(p)
	_draw_gym_building(p)   # elaborate gym drawn OVER gym_wall tiles
	_draw_npcs(p)
	_draw_item_glow(p)
	_draw_player(p)
	_draw_hud_overlay(p)

# ── Sky ───────────────────────────────────────────────────────────────────────
func _draw_sky(p: Dictionary) -> void:
	draw_rect(Rect2(0, 0, 480, 320), p.sky)

# ── Tiles ─────────────────────────────────────────────────────────────────────
func _draw_tiles(p: Dictionary) -> void:
	for r in ROWS:
		for c in COLS:
			var t = MAP[r][c]
			var rx := c * TS; var ry := r * TS
			_draw_tile(t, rx, ry, c, r, p)

func _draw_tile(t:int,rx:int,ry:int,c:int,r:int,p:Dictionary)->void:
	var even := (c+r)%2 == 0
	match t:
		GRASS:
			draw_rect(Rect2(rx,ry,TS,TS), p.grass1 if even else p.grass2)
			# Subtle blades of grass detail
			if (c*7+r*3)%5 == 0:
				draw_rect(Rect2(rx+8,ry+6,2,8),   p.grass1.lightened(0.15))
				draw_rect(Rect2(rx+20,ry+12,2,6),  p.grass2.lightened(0.1))
			if (c*3+r*11)%7 == 0:
				draw_rect(Rect2(rx+14,ry+20,2,9),  p.grass1.lightened(0.12))

		TREE:
			# Ground
			draw_rect(Rect2(rx,ry,TS,TS), p.grass2)
			# Canopy layers (3 shades for depth)
			draw_rect(Rect2(rx+2,ry+2,28,24),  p.tree)
			draw_rect(Rect2(rx+4,ry+4,24,20),  p.tree_lt)
			draw_rect(Rect2(rx+7,ry+6,18,14),  p.tree_lt.lightened(0.12))
			# Canopy highlight (top-left)
			draw_rect(Rect2(rx+8,ry+6,8,6),    p.tree_lt.lightened(0.22))
			# Canopy shadow (bottom)
			draw_rect(Rect2(rx+4,ry+20,24,6),  p.tree.darkened(0.1))
			# Trunk
			draw_rect(Rect2(rx+11,ry+24,10,8), p.bark)
			draw_rect(Rect2(rx+12,ry+25,4,6),  p.bark.lightened(0.2))  # highlight
			# Root shadow
			draw_rect(Rect2(rx+10,ry+31,12,2), Color(0,0,0,0.25))

		HOUSE:
			# Wall
			draw_rect(Rect2(rx,ry+6,TS,TS-6), p.house_w)
			# Roof (triangular-ish using two rects)
			draw_rect(Rect2(rx,ry,TS,10), p.house_r)
			draw_rect(Rect2(rx+2,ry+2,TS-4,5), p.house_r.lightened(0.1))
			# Roof shadow underneath
			draw_rect(Rect2(rx,ry+10,TS,3), p.house_r.darkened(0.3))
			# Window
			draw_rect(Rect2(rx+5,ry+14,22,14), p.house_win)
			draw_rect(Rect2(rx+5,ry+14,22,14), Color(0,0,0,0.7), false, 1.0)
			# Window cross divider
			draw_rect(Rect2(rx+15,ry+14,2,14), Color(0,0,0,0.5))
			draw_rect(Rect2(rx+5, ry+20,22,2), Color(0,0,0,0.5))
			# Window light reflection
			draw_rect(Rect2(rx+7,ry+16,6,5), Color(1,1,1,0.18))
			# Wall bottom shadow
			draw_rect(Rect2(rx,ry+TS-4,TS,4), Color(0,0,0,0.15))

		HDOOR:
			draw_rect(Rect2(rx,ry,TS,TS), p.grass1 if even else p.grass2)
			# Door arch frame
			draw_rect(Rect2(rx+7,ry+5,18,26), p.h_door.darkened(0.2))
			draw_rect(Rect2(rx+8,ry+6,16,24), p.h_door)
			# Door top arch hint
			draw_rect(Rect2(rx+8,ry+6,16,5), p.h_door.lightened(0.15))
			# Door panels
			draw_rect(Rect2(rx+10,ry+12,6,10), p.h_door.lightened(0.1))
			draw_rect(Rect2(rx+18,ry+12,6,10), p.h_door.lightened(0.1))
			# Door knob
			draw_rect(Rect2(rx+19,ry+20,4,4), Color("#ffd700"))
			draw_rect(Rect2(rx+20,ry+21,2,2), Color("#ffee88"))  # highlight
			# Step
			draw_rect(Rect2(rx+6,ry+29,20,3), p.h_door.darkened(0.3))

		PATH:
			draw_rect(Rect2(rx,ry,TS,TS), p.path1 if even else p.path2)
			# Stone texture — individual "stones"
			var stone_c = p.path1.darkened(0.12)
			var highlight_c = p.path1.lightened(0.08)
			draw_rect(Rect2(rx+2, ry+3, 10,10), stone_c)
			draw_rect(Rect2(rx+14,ry+2, 14, 9), stone_c)
			draw_rect(Rect2(rx+3, ry+16,12,11), stone_c)
			draw_rect(Rect2(rx+18,ry+14,11,12), stone_c)
			# Mortar lines (lighter gaps)
			draw_rect(Rect2(rx+1, ry+13,TS-2,2), highlight_c)
			draw_rect(Rect2(rx+13,ry+2, 2,TS-4), highlight_c)
			# Edge shadow
			draw_rect(Rect2(rx,ry+TS-2,TS,2), Color(0,0,0,0.08))

		GWALL, GDOOR:
			# These tiles are drawn over by _draw_gym_building — just fill with base color
			draw_rect(Rect2(rx,ry,TS,TS), p.gwall)

		ITEM:
			draw_rect(Rect2(rx,ry,TS,TS), p.grass1 if even else p.grass2)
			# Same grass detail
			if not GameManager.has_item(_cfg.item.id):
				# Glow circle under item
				var glow := 0.5+sin(_anim_global*3.5)*0.45
				draw_rect(Rect2(rx+6,ry+18,20,6), Color(p.gaccent.r,p.gaccent.g,p.gaccent.b,0.25*glow))
				# Item orb
				draw_rect(Rect2(rx+10,ry+8,12,14), p.gaccent*Color(1,1,1,glow))
				draw_rect(Rect2(rx+12,ry+10,8,10), Color(1,1,1,0.5*glow))
				# Sparkle cross
				draw_rect(Rect2(rx+15,ry+3,2,5),  Color(1,1,1,glow))
				draw_rect(Rect2(rx+12,ry+5,8,2),  Color(1,1,1,glow))
				draw_rect(Rect2(rx+22,ry+10,5,2), Color(1,1,1,glow*0.7))

		WATER:
			var wc := Color(0.1,0.4,0.8,1)
			draw_rect(Rect2(rx,ry,TS,TS), wc)
			# Wave lines
			for wi in range(2):
				var woff := int(_anim_global*12)%16
				draw_rect(Rect2(rx+((woff+wi*8)%28),ry+6+wi*10,14,2), Color(0.3,0.6,1,0.5))

# ── Decorations (flowers, misc ambiance) ─────────────────────────────────────
func _draw_decorations(p: Dictionary) -> void:
	# Scatter small flowers on grass based on position hash
	var flower_positions := [
		Vector2i(1,5), Vector2i(5,6), Vector2i(8,7), Vector2i(11,5),
		Vector2i(13,2), Vector2i(12,7), Vector2i(2,7), Vector2i(9,5)
	]
	for fp in flower_positions:
		if MAP[fp.y][fp.x] != GRASS: continue
		var fx = fp.x*TS; var fy = fp.y*TS
		match world_id:
			"math":    # small cyan dots
				draw_rect(Rect2(fx+8,fy+22,4,4),  Color(0.5,0.8,1,0.9))
				draw_rect(Rect2(fx+20,fy+18,4,4), Color(0.3,0.6,1,0.9))
			"english": # small golden flowers
				draw_rect(Rect2(fx+8,fy+20,3,3),  Color(1,0.8,0.2,0.9))
				draw_rect(Rect2(fx+18,fy+24,3,3), Color(1,0.6,0.2,0.9))
			"music":   # small purple/pink petals
				draw_rect(Rect2(fx+7,fy+20,4,4),  Color(0.9,0.3,1,0.9))
				draw_rect(Rect2(fx+20,fy+16,4,4), Color(0.6,0.2,1,0.9))

	# Fence segments along border trees (decorative inner fence)
	var fence_c = p.fence
	for c2 in [2, 3, 10, 11, 12]:
		draw_rect(Rect2(c2*TS+4, 8*TS+1, TS-8, 5), fence_c)
		draw_rect(Rect2(c2*TS+8, 8*TS-4, 4, 8), fence_c)
		draw_rect(Rect2(c2*TS+20, 8*TS-4, 4, 8), fence_c)

# ═══════════════════════════════════════════════════════════════════════════════
# GYM BUILDING (elaborate pixel art, drawn over gym_wall tiles)
# Gym occupies: cols 3-9 (7 tiles = 224px), rows 1-3 (3 tiles = 96px)
# Top-left pixel: (3*32, 1*32) = (96, 32)
# ═══════════════════════════════════════════════════════════════════════════════
func _draw_gym_building(p: Dictionary) -> void:
	const GX := 96;  const GY := 32   # pixel origin
	const GW := 224; const GH := 96   # pixel dimensions
	match world_id:
		"english": _gym_english(GX, GY, GW, GH, p)
		"music":   _gym_music(GX, GY, GW, GH, p)
		_:         _gym_math(GX, GY, GW, GH, p)

func _gym_math(gx:int,gy:int,gw:int,gh:int,p:Dictionary)->void:
	var fnt := ThemeDB.fallback_font
	# ── Foundation shadow ─────────────────────────────────────────────────────
	draw_rect(Rect2(gx+6,gy+gh-2,gw-4,8), Color(0,0,0,0.35))
	# ── Main walls (3-color layered facade) ───────────────────────────────────
	draw_rect(Rect2(gx,    gy+20, gw,   gh-20), p.gwall)                   # main wall
	draw_rect(Rect2(gx+4,  gy+20, gw-8, gh-24), p.gwall.lightened(0.08))  # inner lighter
	# ── Geometric grid overlay on facade ─────────────────────────────────────
	for xi in range(4):
		draw_rect(Rect2(gx+28+xi*50, gy+25, 2, gh-30), p.groof * Color(1,1,1,0.5))
	for yi in range(2):
		draw_rect(Rect2(gx+4, gy+42+yi*20, gw-8, 1), p.groof * Color(1,1,1,0.4))
	# ── Stepped roof (4 tiers) ────────────────────────────────────────────────
	draw_rect(Rect2(gx,    gy+14, gw,    14), p.groof.lightened(0.05))    # tier 1
	draw_rect(Rect2(gx+6,  gy+8,  gw-12, 10), p.groof.lightened(0.12))   # tier 2
	draw_rect(Rect2(gx+14, gy+3,  gw-28, 8),  p.groof.lightened(0.18))   # tier 3 (apex)
	# Roof edge trim
	draw_rect(Rect2(gx,    gy+14, gw,    2), p.gaccent*Color(1,1,1,0.7))
	draw_rect(Rect2(gx+6,  gy+8,  gw-12, 2), p.gaccent*Color(1,1,1,0.5))
	# Roof corner ornaments (small squares)
	for ci in [0, 1]:
		var ox2 = gx + ci * (gw - 12)
		draw_rect(Rect2(ox2, gy+12, 12, 12), p.gaccent.darkened(0.2))
		draw_rect(Rect2(ox2+2,gy+14,8,8), p.gaccent)
	# ── Pillars (6 pillars along width) ──────────────────────────────────────
	var pillar_c = p.gwall.lightened(0.2)
	var cap_c    = p.gaccent.darkened(0.15)
	for pi in range(6):
		var px2 := gx + 12 + pi * 34
		draw_rect(Rect2(px2,    gy+20, 10, gh-20), pillar_c)                # shaft
		draw_rect(Rect2(px2-1,  gy+18, 12, 5),    cap_c)                    # capital
		draw_rect(Rect2(px2-1,  gy+gh-5,12, 5),   cap_c)                    # base
		draw_rect(Rect2(px2+1,  gy+23, 4, gh-32), pillar_c.lightened(0.15)) # highlight
	# ── Windows (3 arched formula-display windows) ────────────────────────────
	var win_positions := [gx+22, gx+89, gx+156]
	for wx2 in win_positions:
		# Window frame
		draw_rect(Rect2(wx2,   gy+26, 42, 40), p.groof.darkened(0.2))
		# Arched top
		draw_rect(Rect2(wx2+2, gy+24, 38, 8),  p.groof)
		draw_rect(Rect2(wx2+8, gy+22, 26, 6),  p.groof.lightened(0.15))
		# Window glass (glowing cyan/formula color)
		draw_rect(Rect2(wx2+2, gy+28, 38, 34), p.gaccent.darkened(0.4))
		draw_rect(Rect2(wx2+4, gy+30, 34, 30), p.gaccent.darkened(0.25))
		# Window reflection
		draw_rect(Rect2(wx2+4, gy+30, 8, 14),  Color(1,1,1,0.2))
		# Formula glyph in window
		draw_string(
	ThemeDB.fallback_font,
	Vector2(wx2+8, gy+52),
	"x² =",
	HORIZONTAL_ALIGNMENT_LEFT,
	-1,
	14,
	p.gaccent
)
	# ── Central entrance arch ─────────────────────────────────────────────────
	var cx2 := gx + gw/2 - 18
	draw_rect(Rect2(cx2-4, gy+20, 44, gh-20), p.groof.darkened(0.1))       # arch bg
	draw_rect(Rect2(cx2,   gy+20, 36, gh-20), p.gdoor.darkened(0.2))        # door bg
	draw_rect(Rect2(cx2+2, gy+22, 32, gh-26), p.gdoor)                      # door face
	draw_rect(Rect2(cx2+4, gy+24, 28, gh-32), p.gdoor.lightened(0.1))       # door center
	# Door shine
	draw_rect(Rect2(cx2+5, gy+26, 6, 16), Color(1,1,1,0.22))
	# Door handle
	draw_rect(Rect2(cx2+23,gy+55, 5, 8),  Color("#cccccc"))
	draw_rect(Rect2(cx2+24,gy+56, 3, 6),  Color("#ffffff"))
	# Arch top decoration
	draw_rect(Rect2(cx2-2, gy+18, 40, 6), p.gaccent.darkened(0.1))
	draw_rect(Rect2(cx2+4, gy+16, 28, 6), p.gaccent.lightened(0.1))
	# Keystone
	draw_rect(Rect2(cx2+14, gy+12, 8, 8), p.gsign)
	draw_rect(Rect2(cx2+15, gy+13, 6, 6), Color(1,1,1,0.9))
	# ── Sign above entrance ───────────────────────────────────────────────────
	draw_rect(Rect2(gx+62,  gy+3,  100, 14), p.gsign.darkened(0.2))
	draw_rect(Rect2(gx+64,  gy+4,  96,  12), p.gsign)
	draw_string(fnt, Vector2(gx+68, gy+13), "AXIOM ACADEMY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08,0.08,0.2))
	# ── Giant Sigma symbol on right panel ────────────────────────────────────
	draw_string(fnt, Vector2(gx+180, gy+72), "Σ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, p.gaccent * Color(1,1,1,0.8))
	# ── Equation on left panel ────────────────────────────────────────────────
	draw_string(fnt, Vector2(gx+10, gy+62), "x+4=9",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, p.gaccent * Color(1,1,1,0.7))
	# ── Animated pulsing accent light on roof ridge ───────────────────────────
	var pulse := 0.5 + sin(_anim_global * 2.5) * 0.45
	draw_rect(Rect2(gx+14, gy+3, gw-28, 2), p.gaccent * Color(1,1,1,pulse))

func _gym_english(gx:int,gy:int,gw:int,gh:int,p:Dictionary)->void:
	var fnt := ThemeDB.fallback_font
	# ── Foundation ────────────────────────────────────────────────────────────
	draw_rect(Rect2(gx+4,gy+gh-2,gw-4,10), Color(0,0,0,0.35))
	# ── Stone block facade ────────────────────────────────────────────────────
	draw_rect(Rect2(gx, gy+16, gw, gh-16), p.gwall)
	# Stone block lines (horizontal courses)
	for yi in range(3):
		draw_rect(Rect2(gx, gy+30+yi*18, gw, 2), p.gwall.darkened(0.18))
	# Stone block vertical joints (staggered)
	for xi in range(5):
		draw_rect(Rect2(gx+22+xi*40, gy+16, 2, 18), p.gwall.darkened(0.12))
		draw_rect(Rect2(gx+40+xi*40, gy+32, 2, 18), p.gwall.darkened(0.12))
		draw_rect(Rect2(gx+30+xi*40, gy+50, 2, 18), p.gwall.darkened(0.12))
	# Stone highlight (top edge of each course)
	for yi in range(3):
		draw_rect(Rect2(gx, gy+28+yi*18, gw, 1), p.gwall.lightened(0.15))
	# ── Peaked Gothic roof ───────────────────────────────────────────────────
	# Central spire
	draw_rect(Rect2(gx+gw/2-6, gy,   12, 20), p.groof.lightened(0.2))     # spire
	draw_rect(Rect2(gx+gw/2-2, gy-4, 4,  6),  p.gsign)                    # spire tip
	# Main roof sections
	draw_rect(Rect2(gx,    gy+8,  gw,   12), p.groof.lightened(0.08))
	draw_rect(Rect2(gx+10, gy+4,  gw-20,8), p.groof.lightened(0.15))
	# Battlements / crenellations
	for bi in range(10):
		var bx2 := gx + bi * 22
		draw_rect(Rect2(bx2,    gy+8,  14, 8), p.groof.lightened(0.1))
		draw_rect(Rect2(bx2+14, gy+8,  8,  4), p.groof.darkened(0.1))
	# Roof edge gold trim
	draw_rect(Rect2(gx, gy+16, gw, 3), p.gaccent * Color(1,1,1,0.7))
	# ── Ivy / vine decoration ─────────────────────────────────────────────────
	var ivy_c := Color(0.2, 0.5, 0.1, 0.7)
	for ii in range(8):
		var ix := gx + 10 + ii * 26
		draw_rect(Rect2(ix,    gy+16, 4, 14), ivy_c)
		draw_rect(Rect2(ix-3,  gy+22, 4, 8),  ivy_c.lightened(0.1))
		draw_rect(Rect2(ix+4,  gy+26, 4, 6),  ivy_c.lightened(0.05))
	# ── Arched windows (4 Gothic style) ──────────────────────────────────────
	var wpos := [gx+16, gx+70, gx+136, gx+190]
	for wx2 in wpos:
		# Outer stone arch
		draw_rect(Rect2(wx2,   gy+22, 28, 44), p.groof.darkened(0.15))
		# Pointed arch top
		draw_rect(Rect2(wx2+4, gy+18, 20, 8),  p.groof)
		draw_rect(Rect2(wx2+8, gy+16, 12, 6),  p.groof.lightened(0.1))
		# Window glass (warm amber glow)
		draw_rect(Rect2(wx2+2, gy+24, 24, 38), Color(0.5,0.3,0.05,0.9))
		draw_rect(Rect2(wx2+4, gy+26, 20, 34), p.gaccent.darkened(0.3))
		# Stained divisions (Gothic tracery)
		draw_rect(Rect2(wx2+13,gy+24, 2,  38), p.groof.darkened(0.2))
		draw_rect(Rect2(wx2+2, gy+38, 24, 2),  p.groof.darkened(0.2))
		# Glass highlight
		draw_rect(Rect2(wx2+5, gy+27, 5, 12),  Color(1,0.9,0.6,0.25))
	# ── Grand entrance portal ─────────────────────────────────────────────────
	var cx2 := gx + gw/2 - 20
	# Pilasters (flat pillars flanking door)
	draw_rect(Rect2(cx2-8,  gy+18, 12, gh-18), p.groof.lightened(0.12))
	draw_rect(Rect2(cx2+36, gy+18, 12, gh-18), p.groof.lightened(0.12))
	# Door surround
	draw_rect(Rect2(cx2,    gy+20, 40, gh-20), p.groof.darkened(0.1))
	draw_rect(Rect2(cx2+2,  gy+22, 36, gh-22), p.gdoor.darkened(0.15))
	draw_rect(Rect2(cx2+4,  gy+24, 32, gh-26), p.gdoor)
	# Door panels
	draw_rect(Rect2(cx2+6,  gy+30, 12, 16), p.gdoor.lightened(0.12))
	draw_rect(Rect2(cx2+22, gy+30, 12, 16), p.gdoor.lightened(0.12))
	# Door knocker (open book symbol)
	draw_rect(Rect2(cx2+14, gy+50, 12, 8), p.gaccent.darkened(0.1))
	draw_rect(Rect2(cx2+17, gy+51, 6, 6),  p.gaccent.lightened(0.2))
	# Pointed door arch
	draw_rect(Rect2(cx2,    gy+18, 40, 6), p.groof.lightened(0.1))
	draw_rect(Rect2(cx2+6,  gy+14, 28, 8), p.groof.lightened(0.2))
	draw_rect(Rect2(cx2+13, gy+10, 14, 8), p.gsign)   # gold keystone
	# ── Open Book sign above entrance ────────────────────────────────────────
	draw_rect(Rect2(gx+70,  gy+4,  84, 12), p.gsign.darkened(0.2))
	draw_rect(Rect2(gx+72,  gy+5,  80, 10), p.gsign)
	draw_string(fnt, Vector2(gx+76, gy+13), "GRAND LEXICON",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2,0.1,0.0))
	# Quill decorations left and right of sign
	draw_rect(Rect2(gx+62,  gy+3,  6, 16), Color(1,0.95,0.7))
	draw_rect(Rect2(gx+56,  gy+2,  10, 5), Color(1,0.9,0.6))
	draw_rect(Rect2(gx+158, gy+3,  6, 16), Color(1,0.95,0.7))
	draw_rect(Rect2(gx+158, gy+2,  10, 5), Color(1,0.9,0.6))
	# ── Animated golden glow pulse ────────────────────────────────────────────
	var pulse := 0.5 + sin(_anim_global * 2.0) * 0.4
	draw_rect(Rect2(gx, gy+16, gw, 2), p.gaccent * Color(1,1,1,pulse))

func _gym_music(gx:int,gy:int,gw:int,gh:int,p:Dictionary)->void:
	var fnt := ThemeDB.fallback_font
	# ── Foundation ────────────────────────────────────────────────────────────
	draw_rect(Rect2(gx+4,gy+gh,gw-4,8), Color(0,0,0,0.35))
	# ── Curved concert hall facade ────────────────────────────────────────────
	draw_rect(Rect2(gx, gy+14, gw, gh-14), p.gwall)
	draw_rect(Rect2(gx+4, gy+18, gw-8, gh-22), p.gwall.lightened(0.06))
	# Curved dome roof effect (3 arcing rects)
	draw_rect(Rect2(gx,    gy+6,  gw,    12), p.groof.lightened(0.1))
	draw_rect(Rect2(gx+8,  gy+2,  gw-16, 9),  p.groof.lightened(0.18))
	draw_rect(Rect2(gx+20, gy-2,  gw-40, 8),  p.groof.lightened(0.25))
	# Roof highlight trim
	draw_rect(Rect2(gx,    gy+14, gw,    3),   p.gaccent * Color(1,1,1,0.7))
	draw_rect(Rect2(gx+8,  gy+10, gw-16, 2),  p.gaccent * Color(1,1,1,0.5))
	# Dome spire / finial
	draw_rect(Rect2(gx+gw/2-3, gy-8, 6, 12), p.gsign.darkened(0.1))
	draw_rect(Rect2(gx+gw/2-1, gy-10,2, 4),  Color(1,0.8,0,1))
	# ── Musical staff lines across facade ─────────────────────────────────────
	for li in range(5):
		var ly := gy + 34 + li * 10
		draw_rect(Rect2(gx+8, ly, gw-16, 1), p.gaccent * Color(1,1,1,0.25))
	# ── Colorful stained-glass windows ────────────────────────────────────────
	var win_cols := [
		Color(0.9,0.3,1,0.8), Color(0.4,0.7,1,0.8),
		Color(1,0.5,0.2,0.8), Color(0.3,1,0.6,0.8)
	]
	var wpos2 := [gx+14, gx+68, gx+130, gx+184]
	for wi2 in wpos2.size():
		var wx2 = wpos2[wi2]
		var wc  = win_cols[wi2]
		# Window arch frame
		draw_rect(Rect2(wx2,    gy+20, 30, 50), p.groof.darkened(0.2))
		draw_rect(Rect2(wx2+4,  gy+16, 22, 10), p.groof)
		draw_rect(Rect2(wx2+8,  gy+14, 14, 6),  p.groof.lightened(0.15))
		# Glass (animated hue shift for music world!)
		var shift := 0.5 + sin(_anim_global * 1.5 + wi2) * 0.4
		draw_rect(Rect2(wx2+2,  gy+22, 26, 44), wc * Color(1,1,1,shift))
		draw_rect(Rect2(wx2+5,  gy+24, 20, 38), wc.lightened(0.1) * Color(1,1,1,0.5))
		# Tracery divisions
		draw_rect(Rect2(wx2+14, gy+22, 2,  44), p.groof.darkened(0.3))
		draw_rect(Rect2(wx2+2,  gy+40, 26, 2),  p.groof.darkened(0.3))
		# Glass shine
		draw_rect(Rect2(wx2+4,  gy+24, 5, 10),  Color(1,1,1,0.3))
		# Floating note on window
		draw_string(fnt, Vector2(wx2+4, gy+56), ["♩","♪","♫","♬"][wi2],
			HORIZONTAL_ALIGNMENT_LEFT,-1,14, Color(1,1,1,0.6))
	# ── Grand curved entrance ─────────────────────────────────────────────────
	var cx2 := gx + gw/2 - 22
	# Columns flanking door
	draw_rect(Rect2(cx2-10, gy+16, 14, gh-16), p.gwall.lightened(0.2))
	draw_rect(Rect2(cx2-10, gy+14, 14, 5),     p.gaccent.darkened(0.1))
	draw_rect(Rect2(cx2+40, gy+16, 14, gh-16), p.gwall.lightened(0.2))
	draw_rect(Rect2(cx2+40, gy+14, 14, 5),     p.gaccent.darkened(0.1))
	# Column fluting (vertical lines)
	for fi in range(3):
		draw_rect(Rect2(cx2-8+fi*4, gy+18, 1, gh-20), p.groof.darkened(0.1))
		draw_rect(Rect2(cx2+42+fi*4,gy+18, 1, gh-20), p.groof.darkened(0.1))
	# Door opening
	draw_rect(Rect2(cx2,   gy+18, 44, gh-18), p.groof.darkened(0.25))
	draw_rect(Rect2(cx2+2, gy+20, 40, gh-20), p.gdoor.darkened(0.1))
	draw_rect(Rect2(cx2+4, gy+22, 36, gh-24), p.gdoor.lightened(0.05))
	# Door panels
	draw_rect(Rect2(cx2+6,  gy+28, 14, 20), p.gdoor.lightened(0.15))
	draw_rect(Rect2(cx2+24, gy+28, 14, 20), p.gdoor.lightened(0.15))
	# Gold handles
	draw_rect(Rect2(cx2+18, gy+50, 4, 8), p.gsign)
	draw_rect(Rect2(cx2+26, gy+50, 4, 8), p.gsign)
	# Door arch (rounded)
	draw_rect(Rect2(cx2,    gy+16, 44, 6),  p.groof.lightened(0.15))
	draw_rect(Rect2(cx2+6,  gy+12, 32, 8),  p.groof.lightened(0.22))
	draw_rect(Rect2(cx2+14, gy+8,  16, 8),  p.gaccent.darkened(0.1))
	# ── Treble clef on left panel ─────────────────────────────────────────────
	draw_string(fnt, Vector2(gx+8, gy+76), "𝄞",
		HORIZONTAL_ALIGNMENT_LEFT,-1,32, p.gaccent * Color(1,1,1,0.85))
	# ── Musical notes floating on right ──────────────────────────────────────
	var note_y := gy + 52 + int(sin(_anim_global * 2.2) * 4)
	draw_string(fnt, Vector2(gx+178, note_y), "♪♫",
		HORIZONTAL_ALIGNMENT_LEFT,-1,18, p.gaccent * Color(1,1,1,0.8))
	# ── Sign banner ───────────────────────────────────────────────────────────
	draw_rect(Rect2(gx+68,  gy+3,  88, 12), p.gsign.darkened(0.2))
	draw_rect(Rect2(gx+70,  gy+4,  84, 10), p.gsign)
	draw_string(fnt, Vector2(gx+76, gy+12), "HARMONY HALL",
		HORIZONTAL_ALIGNMENT_LEFT,-1,10, Color(0.15,0.02,0.25))
	# ── Pulsing ambient glow along roof edge ─────────────────────────────────
	var pulse := 0.5 + sin(_anim_global * 3.0) * 0.45
	draw_rect(Rect2(gx, gy+14, gw, 2), p.gaccent * Color(1,1,1,pulse))

# ── Item glow (needs to update every frame) ───────────────────────────────────
func _draw_item_glow(_p: Dictionary) -> void:
	pass   # handled inside ITEM tile drawing

# ── NPC sprites ───────────────────────────────────────────────────────────────
func _draw_npcs(p: Dictionary) -> void:
	for npc in _cfg.npcs:
		_draw_npc_sprite(npc.pos.x * TS, npc.pos.y * TS, npc.shirt, p)

func _draw_npc_sprite(px:int,py:int,shirt:Color,_p:Dictionary)->void:
	# Shadow
	draw_rect(Rect2(px+6,py+29,20,4), Color(0,0,0,0.2))
	# Shoes
	draw_rect(Rect2(px+6, py+26, 8, 5), Color(0.12,0.08,0.05))
	draw_rect(Rect2(px+18,py+26, 8, 5), Color(0.12,0.08,0.05))
	# Pants (dark with slight blue tint)
	draw_rect(Rect2(px+7, py+18,8, 10), Color(0.15,0.2,0.5))
	draw_rect(Rect2(px+17,py+18,8, 10), Color(0.15,0.2,0.5))
	# Belt
	draw_rect(Rect2(px+6, py+17,20, 2), Color(0.35,0.22,0.1))
	draw_rect(Rect2(px+14,py+17, 4, 2), Color(0.7,0.6,0.1))  # buckle
	# Shirt
	draw_rect(Rect2(px+5, py+9, 22,10), shirt)
	draw_rect(Rect2(px+7, py+10,18, 8), shirt.lightened(0.1))  # highlight
	# Arms
	draw_rect(Rect2(px+1, py+10, 5, 9), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+26,py+10, 5, 9), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+2, py+10, 2, 4), Color(1,0.85,0.7,0.5))  # arm highlight
	# Neck
	draw_rect(Rect2(px+13,py+6, 6, 5), Color(0.95,0.78,0.64))
	# Head
	draw_rect(Rect2(px+8, py+1,16,10), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+9, py+2,10, 6), Color(0.98,0.82,0.68))  # face highlight
	# Hair (style varies by hash)
	draw_rect(Rect2(px+8, py+1,16, 5), Color(0.38,0.22,0.06))
	draw_rect(Rect2(px+6, py+3, 4, 4), Color(0.38,0.22,0.06))  # sideburn
	draw_rect(Rect2(px+22,py+3, 4, 4), Color(0.38,0.22,0.06))
	# Eyes
	draw_rect(Rect2(px+11,py+7, 3, 3), Color(0.1,0.1,0.15))
	draw_rect(Rect2(px+18,py+7, 3, 3), Color(0.1,0.1,0.15))
	draw_rect(Rect2(px+11,py+7, 1, 1), Color(0.8,0.9,1))  # eye shine L
	draw_rect(Rect2(px+18,py+7, 1, 1), Color(0.8,0.9,1))  # eye shine R

# ── Player sprite ─────────────────────────────────────────────────────────────
func _draw_player(_p: Dictionary) -> void:
	var px := int(_p_pixel.x)
	var py := int(_p_pixel.y)
	var fr := _p_frame if _p_moving else 0
	var lo := -3 if fr == 0 else 3   # left leg offset
	var ro :=  3 if fr == 0 else -3  # right leg offset

	# Shadow
	draw_rect(Rect2(px+5,py+30,22,4), Color(0,0,0,0.22))
	# Shoes (animated with legs)
	draw_rect(Rect2(px+6+lo, py+27, 9,5), Color(0.08,0.06,0.04))
	draw_rect(Rect2(px+17+ro,py+27, 9,5), Color(0.08,0.06,0.04))
	# Legs (separate L/R to show walking)
	draw_rect(Rect2(px+7+lo, py+18,9,11), Color(0.1,0.18,0.55))
	draw_rect(Rect2(px+16+ro,py+18,9,11), Color(0.1,0.18,0.55))
	# Belt
	draw_rect(Rect2(px+6,py+17,20,2), Color(0.3,0.18,0.08))
	# Shirt / jacket (red classic style)
	draw_rect(Rect2(px+4, py+9, 24,10), Color(0.75,0.12,0.12))
	draw_rect(Rect2(px+6, py+10,20, 8), Color(0.82,0.15,0.15))  # lighter center
	# Jacket collar detail
	draw_rect(Rect2(px+11,py+9, 10, 3), Color(0.9,0.9,0.9))
	# Arms
	draw_rect(Rect2(px+0, py+9,  5,10), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+27,py+9,  5,10), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+1, py+10, 2, 4), Color(1,0.85,0.7,0.4))
	# Neck
	draw_rect(Rect2(px+13,py+5, 6,5), Color(0.95,0.78,0.64))
	# Head
	draw_rect(Rect2(px+7, py+0,18,10), Color(0.95,0.78,0.64))
	draw_rect(Rect2(px+9, py+1,12, 6), Color(0.98,0.82,0.68))
	# Cap (red) with brim
	draw_rect(Rect2(px+6, py+0,20, 5), Color(0.75,0.12,0.12))    # cap body
	draw_rect(Rect2(px+4, py+4,24, 3), Color(0.65,0.10,0.10))    # brim shadow
	draw_rect(Rect2(px+5, py+3,22, 3), Color(0.82,0.15,0.15))    # brim top
	# Cap button
	draw_rect(Rect2(px+14,py+0, 4, 2), Color(0.9,0.9,0.1))
	# Eyes (direction-aware)
	if _p_dir == 0:   # down
		draw_rect(Rect2(px+10,py+7,3,3), Color(0.1,0.1,0.15))
		draw_rect(Rect2(px+19,py+7,3,3), Color(0.1,0.1,0.15))
		draw_rect(Rect2(px+10,py+7,1,1), Color(1,1,1))
		draw_rect(Rect2(px+19,py+7,1,1), Color(1,1,1))
	elif _p_dir == 1: # up — only hair visible
		draw_rect(Rect2(px+6,py+0,20,9), Color(0.28,0.18,0.06))
	elif _p_dir == 2: # left
		draw_rect(Rect2(px+9, py+7,3,3), Color(0.1,0.1,0.15))
		draw_rect(Rect2(px+9, py+7,1,1), Color(1,1,1))
	elif _p_dir == 3: # right
		draw_rect(Rect2(px+20,py+7,3,3), Color(0.1,0.1,0.15))
		draw_rect(Rect2(px+20,py+7,1,1), Color(1,1,1))

# ── HUD Overlay (town name + mini level indicator) ────────────────────────────
func _draw_hud_overlay(p: Dictionary) -> void:
	var fnt := ThemeDB.fallback_font
	# Location name pill
	draw_rect(Rect2(5, 5, 148, 22), Color(0,0,0,0.50))
	draw_rect(Rect2(5, 5, 148, 22), p.gaccent * Color(1,1,1,0.3), false, 1.0)
	draw_rect(Rect2(7, 7, 10, 10), p.gaccent)   # small world color dot
	draw_string(fnt, Vector2(22, 21), _cfg.town_name,
		HORIZONTAL_ALIGNMENT_LEFT,-1,13, Color("#f0f0f0"))
	# Gym hint if not cleared
	if not _gym_cleared:
		var need_lv = _cfg.gym_num * 5
		if GameManager.get_level() < need_lv:
			draw_rect(Rect2(5, 31, 148, 16), Color(0,0,0,0.45))
			draw_string(
	fnt,
	Vector2(8, 43),
	"Gym needs Lv." + str(need_lv) + " (You: " + str(GameManager.get_level()) + ")",
	HORIZONTAL_ALIGNMENT_LEFT,
	-1,
	11,
	Color(1.0, 0.7, 0.3)
)
