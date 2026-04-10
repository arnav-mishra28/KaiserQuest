# WorldSelectScreen.gd  —  3-world selection portal screen
extends Node2D

signal world_chosen(world_id: String)

var _sel:   int   = 0
var _time:  float = 0.0
var _alpha: float = 0.0

const WORLDS := [
	{
		"id":    "math",
		"name":  "MATH WORLD",
		"city":  "Mathopolis",
		"desc":  "Equations are your enemies.\nSolve them to survive!",
		"icon":  "∑",
		"color": Color("#1a5acc"),
		"glow":  Color("#44aaff"),
		"dark":  Color("#0a1a44"),
		"badge": "Variable Badge",
		"gym":   "Variable Citadel"
	},
	{
		"id":    "english",
		"name":  "LANGUAGE WORLD",
		"city":  "Lexicon City",
		"desc":  "Words shape reality.\nMaster the power of language!",
		"icon":  "A",
		"color": Color("#8a4a10"),
		"glow":  Color("#ffcc44"),
		"dark":  Color("#3a1a04"),
		"badge": "Grammar Badge",
		"gym":   "Noun Sanctum"
	},
	{
		"id":    "music",
		"name":  "MUSIC WORLD",
		"city":  "Harmonia",
		"desc":  "Notes are creatures.\nChords are your power!",
		"icon":  "♪",
		"color": Color("#6a14a0"),
		"glow":  Color("#cc44ff"),
		"dark":  Color("#2a0844"),
		"badge": "Rhythm Badge",
		"gym":   "Harmony Hall"
	},
]

func _ready() -> void:
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	_time  += delta
	_alpha  = minf(_alpha + delta * 1.2, 1.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):  _sel = (_sel - 1 + WORLDS.size()) % WORLDS.size()
	elif event.is_action_pressed("ui_right"): _sel = (_sel + 1) % WORLDS.size()
	elif event.is_action_pressed("ui_accept"):
		world_chosen.emit(WORLDS[_sel].id)

func _draw() -> void:
	const W := 480.0; const H := 320.0
	var fnt := ThemeDB.fallback_font

	# ── BG ────────────────────────────────────────────────────────────────────
	draw_rect(Rect2(0,0,W,H), Color("#050510"))
	# Starfield
	for i in 24:
		var sx := float((i * 53 + 7) % 480)
		var sy := float((i * 37 + 11) % 200)
		var tw := 0.4 + 0.6 * sin(_time * 1.5 + i)
		draw_rect(Rect2(sx, sy, 2, 2), Color(1,1,1, tw * _alpha * 0.6))

	# ── Header ────────────────────────────────────────────────────────────────
	draw_rect(Rect2(0, 0, W, 36), Color(0,0,0,0.65))
	draw_string(fnt, Vector2(14, 24),
		"Choose Your World", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffd700"))
	draw_string(fnt, Vector2(310, 24),
		"← → Navigate  |  ENTER Select",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.55, 0.75))

	# ── World Cards ───────────────────────────────────────────────────────────
	const CW := 140.0; const CH := 230.0
	const GAP := 8.0
	var total_w := CW * 3 + GAP * 2
	var start_x := (W - total_w) / 2.0

	for i in WORLDS.size():
		var wd  = WORLDS[i]
		var cx  := start_x + i * (CW + GAP)
		var cy  := 46.0
		var sel := (i == _sel)
		var pulse := 0.7 + 0.3 * sin(_time * 3.0) if sel else 0.0

		# Card background
		draw_rect(Rect2(cx, cy, CW, CH), wd.dark)
		# Glow border if selected
		if sel:
			draw_rect(Rect2(cx-2, cy-2, CW+4, CH+4),
				wd.glow * Color(1,1,1, 0.5 + pulse * 0.4), false, 3.0)
		draw_rect(Rect2(cx, cy, CW, CH),
			wd.color * Color(1,1,1, 0.6 + pulse * 0.3), false, 2.0)

		# Inner pixel "art" area  — world-themed scene
		draw_rect(Rect2(cx+4, cy+4, CW-8, 100), Color(0,0,0,0.4))
		_draw_world_scene(i, cx+4, cy+4, CW-8, 100)

		# Big icon
		draw_string(fnt, Vector2(cx+8, cy+118),
			wd.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			wd.glow * Color(1,1,1, _alpha))

		# Name
		draw_string(fnt, Vector2(cx+4, cy+148),
			wd.name, HORIZONTAL_ALIGNMENT_LEFT, CW-8, 12, Color("#ffffff"))

		# City
		draw_string(fnt, Vector2(cx+4, cy+164),
			wd.city, HORIZONTAL_ALIGNMENT_LEFT, CW-8, 11, wd.glow)

		# Description
		var dlines = wd.desc.split("\n")
		for di in dlines.size():
			draw_string(fnt, Vector2(cx+4, cy+180 + di*14),
				dlines[di], HORIZONTAL_ALIGNMENT_LEFT, CW-8, 11,
				Color(0.75, 0.80, 0.75))

		# Badge preview
		if GameManager.has_badge(wd.badge):
			draw_string(fnt, Vector2(cx+4, cy+CH-18),
				"★ " + wd.badge, HORIZONTAL_ALIGNMENT_LEFT, CW-8, 10, Color("#ffd700"))

		# Selection highlight
		if sel:
			draw_rect(Rect2(cx, cy, CW, CH), wd.glow * Color(1,1,1,0.08))

	# ── Bottom instruction ─────────────────────────────────────────────────────
	draw_rect(Rect2(0, H-28, W, 28), Color(0,0,0,0.60))
	draw_string(fnt, Vector2(W/2 - 100, H-10),
		"Press  ENTER  to  enter  " + WORLDS[_sel].city,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e8e8e8"))

# ── Per-world mini scene in card ─────────────────────────────────────────────
func _draw_world_scene(idx: int, ox: float, oy: float, w: float, h: float) -> void:
	match idx:
		0:  # Math — blue grid world
			draw_rect(Rect2(ox, oy, w, h), Color("#0a1a3a"))
			# Grid lines
			for gx in range(0, int(w), 14):
				draw_rect(Rect2(ox+gx, oy, 1, h), Color(0.2, 0.4, 0.8, 0.3))
			for gy in range(0, int(h), 14):
				draw_rect(Rect2(ox, oy+gy, w, 1), Color(0.2, 0.4, 0.8, 0.3))
			# Equation enemies
			draw_string(ThemeDB.fallback_font, Vector2(ox+6, oy+28), "x+3=?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#44aaff"))
			draw_string(ThemeDB.fallback_font, Vector2(ox+6, oy+52), "y=2x",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#88ccff"))
			# Crystal spire (gym)
			draw_rect(Rect2(ox+w-28, oy+20, 20, 60), Color("#1a4acc"))
			draw_colored_polygon(
	PackedVector2Array([
		Vector2(ox+w-32, oy+20),
		Vector2(ox+w-18, oy+5),
		Vector2(ox+w-4,  oy+20)
	]),
	Color("#44aaff")
)
		1:  # English — warm library world
			draw_rect(Rect2(ox, oy, w, h), Color("#2a1a08"))
			# Book-lined shelves
			for bx in range(0, int(w)-12, 10):
				var bc := Color(0.5+float(bx%30)/60.0, 0.2, 0.1)
				draw_rect(Rect2(ox+bx+1, oy+h-30, 8, 24), bc)
				draw_rect(Rect2(ox+bx+1, oy+h-30, 8, 3), Color(1.0,0.9,0.6))
			# Shelf plank
			draw_rect(Rect2(ox, oy+h-32, w, 4), Color(0.4, 0.25, 0.1))
			# Letter floating
			draw_string(ThemeDB.fallback_font, Vector2(ox+10, oy+32), "Grammar",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffcc44"))
			draw_string(ThemeDB.fallback_font, Vector2(ox+16, oy+52), "Nouns •",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffaa22"))
		2:  # Music — purple concert world
			draw_rect(Rect2(ox, oy, w, h), Color("#180828"))
			# Staff lines
			for sl in range(5):
				draw_rect(Rect2(ox+4, oy+20+sl*10, w-8, 1), Color(0.7,0.5,1.0,0.6))
			# Notes
			var note_positions := [Vector2(10,18), Vector2(28,28), Vector2(46,23), Vector2(64,33)]
			for np in note_positions:
				draw_rect(Rect2(ox+np.x, oy+np.y+14, 10, 8), Color("#cc44ff"))
				draw_rect(Rect2(ox+np.x+8, oy+np.y, 2, 14), Color("#cc44ff"))
			# Glow
			draw_rect(Rect2(ox, oy, w, h), Color(0.5,0.0,0.8, 0.06))
