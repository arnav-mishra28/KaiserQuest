# KaiserScreen.gd — Kaiser Certification Screen
# "You have become the Master of Knowledge."
extends Node2D

var _time:     float  = 0.0
var _phase:    int    = 0   # 0=fade-in 1=display 2=seal-animate 3=done
var _phase_t:  float  = 0.0
var _stars:    Array  = []
var _sparks:   Array  = []
var _seal_r:   float  = 0.0  # seal reveal radius
var _text_a:   float  = 0.0  # text alpha
var _blink:    bool   = true
var _blink_t:  float  = 0.0

const GOLD := Color("#ffd700")
const SILV := Color("#c0c8ff")
const DK   := Color("#181010")
const BG   := Color("#f8f8e8")

func _ready() -> void:
	set_process(true); set_process_input(true)
	# Stars
	for i in 80:
		_stars.append({
			"x": randf()*480, "y": randf()*320,
			"size": randf_range(1.0, 3.0),
			"a": randf(),
			"speed": randf_range(0.5, 2.0),
		})
	# Trigger sparks on load
	for i in 60:
		_sparks.append({
			"x": 240.0 + randf_range(-10,10),
			"y": 160.0 + randf_range(-10,10),
			"vx": randf_range(-4.0, 4.0),
			"vy": randf_range(-5.0, -0.5),
			"life": randf_range(0.5, 2.5),
			"max": 2.0,
			"col": [GOLD, SILV, Color("#ffffff"), Color("#ffeeaa")].pick_random(),
			"size": randf_range(2.0, 6.0),
		})

func _input(ev: InputEvent) -> void:
	if _phase >= 3 and ev.is_action_pressed("ui_accept"):
		# Return to world map
		get_parent().call_deferred("_show_world_map")

func _process(delta: float) -> void:
	_time += delta; _phase_t += delta; _blink_t += delta
	if _blink_t >= 0.55: _blink_t = 0.0; _blink = not _blink
	match _phase:
		0:
			_text_a = minf(_phase_t / 1.5, 1.0)
			if _phase_t >= 1.5: _phase = 1; _phase_t = 0.0
		1:
			_seal_r = minf(_phase_t / 2.0, 1.0) * 90.0
			if _phase_t >= 2.0: _phase = 2; _phase_t = 0.0
		2:
			_text_a = 1.0
			if _phase_t >= 1.0: _phase = 3; _phase_t = 0.0
	# Particles
	for i in range(_sparks.size()-1,-1,-1):
		var s := _sparks[i]
		s.x += s.vx; s.y += s.vy; s.vy += 0.08; s.life -= delta
		if s.life <= 0: _sparks.remove_at(i)
	for s in _stars:
		s.a = fmod(s.a + delta * s.speed * 0.3, 1.0)
	queue_redraw()

func _draw() -> void:
	const W := 480.0; const H := 320.0
	var fnt := ThemeDB.fallback_font

	# ── Dark parchment background ─────────────────────────────────────────
	draw_rect(Rect2(0,0,W,H), Color(0.08,0.06,0.02))
	for y in range(0,int(H),4):
		for x in range(0,int(W),4):
			if ((x/4+y/4)%2)==0:
				draw_rect(Rect2(x,y,4,4), Color(0.10,0.08,0.04,0.6))

	# ── Star field ────────────────────────────────────────────────────────
	for s in _stars:
		draw_rect(Rect2(s.x,s.y,s.size,s.size), Color(1,1,0.9,s.a*_text_a))

	# ── Sparks ────────────────────────────────────────────────────────────
	for s in _sparks:
		var a := clampf(s.life/s.max,0.0,1.0)
		draw_rect(Rect2(s.x,s.y,s.size,s.size), Color(s.col.r,s.col.g,s.col.b,a))

	# ── Gold decorative border ────────────────────────────────────────────
	if _text_a > 0.1:
		draw_rect(Rect2(8,8,W-16,H-16), Color(GOLD.r,GOLD.g,GOLD.b,_text_a*0.5), false, 3.0)
		draw_rect(Rect2(12,12,W-24,H-24), Color(GOLD.r,GOLD.g,GOLD.b,_text_a*0.25), false, 1.5)
		# Corner diamonds
		for cx in [10.0, W-18.0]:
			for cy in [10.0, H-18.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx+4,cy), Vector2(cx+8,cy+4), Vector2(cx+4,cy+8), Vector2(cx,cy+4)]),
					PackedColorArray([GOLD,GOLD,GOLD,GOLD]))
				_text_a_multiply_color_alpha(PackedColorArray([]))

	# ── Animated seal ring ────────────────────────────────────────────────
	var cr := _seal_r
	if cr > 0:
		# Outer rings
		draw_arc(Vector2(W/2,H/2), cr,      0, TAU, 64, Color(GOLD.r,GOLD.g,GOLD.b,_text_a*0.9), 3.0)
		draw_arc(Vector2(W/2,H/2), cr-6.0,  0, TAU, 64, Color(GOLD.r,GOLD.g,GOLD.b,_text_a*0.5), 1.5)
		draw_arc(Vector2(W/2,H/2), cr+8.0,  0, TAU, 48, Color(SILV.r,SILV.g,SILV.b,_text_a*0.4), 1.0)
		# Radiating lines (8-point star shape)
		for i in 8:
			var angle := float(i) / 8.0 * TAU + _time * 0.2
			var x1 := W/2 + cos(angle) * (cr - 12)
			var y1 := H/2 + sin(angle) * (cr - 12)
			var x2 := W/2 + cos(angle) * (cr + 12)
			var y2 := H/2 + sin(angle) * (cr + 12)
			draw_line(Vector2(x1,y1), Vector2(x2,y2), Color(GOLD.r,GOLD.g,GOLD.b,_text_a*0.7), 2.0)
		# Inner filled circle
		draw_circle(Vector2(W/2,H/2), cr - 10.0, Color(0.06,0.04,0.01,0.95))
		# Big K
		draw_string(fnt, Vector2(W/2-14, H/2+14), "K",
			HORIZONTAL_ALIGNMENT_LEFT,-1,44, Color(GOLD.r,GOLD.g,GOLD.b,_text_a))

	# ── "KAISER" title ────────────────────────────────────────────────────
	if _text_a > 0.3:
		var ta := (_text_a - 0.3) * 1.43
		# Shadow
		draw_string(fnt, Vector2(106, 46), "KAISER OF KNOWLEDGE",
			HORIZONTAL_ALIGNMENT_LEFT,-1,24, Color(0,0,0,0.6*ta))
		# Main text
		draw_string(fnt, Vector2(104, 44), "KAISER OF KNOWLEDGE",
			HORIZONTAL_ALIGNMENT_LEFT,-1,24, Color(GOLD.r,GOLD.g,GOLD.b,ta))
		# Separator
		draw_rect(Rect2(60, 52, 360, 2), Color(GOLD.r,GOLD.g,GOLD.b,ta*0.6))

	# ── Player name ───────────────────────────────────────────────────────
	if _text_a > 0.5:
		var ta := (_text_a - 0.5) * 2.0
		var name := GameManager.player_name.to_upper()
		draw_string(fnt, Vector2(240 - len(name)*7, 266),
			name, HORIZONTAL_ALIGNMENT_LEFT,-1,18, Color(SILV.r,SILV.g,SILV.b,ta))
		draw_string(fnt, Vector2(152, 284),
			"has restored the light of the world",
			HORIZONTAL_ALIGNMENT_LEFT,-1,12, Color(0.8,0.8,0.7,ta*0.8))

	# ── "Press ENTER" ──────────────────────────────────────────────────────
	if _phase >= 3 and _blink:
		draw_rect(Rect2(148,298,184,16), Color(0,0,0,0.5))
		draw_string(fnt, Vector2(156,311), "Press ENTER to continue",
			HORIZONTAL_ALIGNMENT_LEFT,-1,13, Color(1,1,1,0.9))

	# ── Glowing badges row ────────────────────────────────────────────────
	if _text_a > 0.6:
		var ta := (_text_a - 0.6) * 2.5
		var badges := GameManager.get_badges()
		var bx := 20.0
		for i in min(badges.size(), 20):
			var glow := 0.5 + 0.5 * sin(_time * 2.0 + i * 0.4)
			draw_rect(Rect2(bx+i*22, 56, 18, 8), Color(GOLD.r,GOLD.g,GOLD.b,ta*glow))

# Helper to avoid error on empty array
func _text_a_multiply_color_alpha(_arr: PackedColorArray) -> void: pass
