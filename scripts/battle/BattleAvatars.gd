# BattleAvatars.gd — Animated 2.5D-style battle sprites
# Player: back view (large, bottom-left) with attack/idle/hurt animations
# Enemy: front view (large, top-right) with idle/hurt/faint animations
extends Node2D

# ── Animation state ───────────────────────────────────────────────────────────
enum Anim { IDLE, ATTACK, HURT, FAINT, VICTORY }

var _p_anim:   int   = Anim.IDLE
var _e_anim:   int   = Anim.IDLE
var _p_anim_t: float = 0.0
var _e_anim_t: float = 0.0
var _time:     float = 0.0
var _p_frame:  int   = 0
var _e_frame:  int   = 0

# Enemy sprite type based on world
var _world:    String = "math"
var _enemy_col: Color = Color("#2060d0")

# Visual positions
const P_X := 40   # Player sprite X
const P_Y := 65   # Player sprite Y
const E_X := 300  # Enemy sprite X
const E_Y := 10   # Enemy sprite Y
const P_SCALE := 2.2  # Player is larger (back view)
const E_SCALE := 2.0  # Enemy slightly smaller

func setup(world: String, enemy_color: Color) -> void:
	_world     = world
	_enemy_col = enemy_color

# ── Trigger animations ────────────────────────────────────────────────────────
func player_attack() -> void:
	_p_anim = Anim.ATTACK; _p_anim_t = 0.0; _p_frame = 0

func enemy_hurt() -> void:
	_e_anim = Anim.HURT; _e_anim_t = 0.0; _e_frame = 0

func player_hurt() -> void:
	_p_anim = Anim.HURT; _p_anim_t = 0.0; _p_frame = 0

func enemy_attack() -> void:
	_e_anim = Anim.ATTACK; _e_anim_t = 0.0; _e_frame = 0

func enemy_faint() -> void:
	_e_anim = Anim.FAINT; _e_anim_t = 0.0; _e_frame = 0

func player_victory() -> void:
	_p_anim = Anim.VICTORY; _p_anim_t = 0.0

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	_p_anim_t += delta
	_e_anim_t += delta

	# Auto-return to idle after animations
	var anim_dur := {Anim.ATTACK: 0.5, Anim.HURT: 0.4, Anim.FAINT: 1.0, Anim.VICTORY: 9999.0}
	if _p_anim != Anim.IDLE and _p_anim_t > anim_dur.get(_p_anim, 0.5):
		if _p_anim != Anim.VICTORY: _p_anim = Anim.IDLE

	if _e_anim != Anim.IDLE and _e_anim_t > anim_dur.get(_e_anim, 0.5):
		if _e_anim != Anim.FAINT: _e_anim = Anim.IDLE

	# Frame update
	_p_frame = int(_p_anim_t / 0.12) % 4
	_e_frame = int(_e_anim_t / 0.12) % 4

	queue_redraw()

# ═════════════════════════════════════════════════════════════════════════════
#  DRAWING
# ═════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	_draw_player_avatar()
	_draw_enemy_avatar()

# ── PLAYER AVATAR (back view, large, Gen 1/2 style) ───────────────────────────
func _draw_player_avatar() -> void:
	var s  := P_SCALE
	var px := float(P_X)
	var py := float(P_Y)
	var fr := _p_frame

	# Animation offsets
	var bob_y := sin(_time * 2.0) * 2.0 * s
	var attack_x := 0.0
	var hurt_x   := 0.0
	var alpha    := 1.0

	match _p_anim:
		Anim.ATTACK:
			attack_x = sin(_p_anim_t * 12.0) * 8.0 * s if _p_anim_t < 0.25 else -sin(_p_anim_t * 8.0) * 4.0 * s
		Anim.HURT:
			hurt_x = sin(_p_anim_t * 20.0) * 5.0 * s
			alpha  = 1.0 - _p_anim_t * 0.5
		Anim.VICTORY:
			bob_y = sin(_time * 4.0) * 5.0 * s

	px += attack_x + hurt_x
	py += bob_y

	var leg_bob := sin(_time * 3.0) * 2.0 * s if _p_anim == Anim.IDLE else 0.0
	var col := Color(1, 1, 1, alpha)

	# Scale helper
	var ts := int(4 * s)  # tile_size scaled
	var hs := int(2 * s)  # half scale

	func r(x:float,y:float,w:float,h:float,c:Color)->void:
		draw_rect(Rect2(px+x*s, py+y*s, w*s, h*s), c*col)

	# Shadow
	r(2, 46, 30, 6, Color(0,0,0,0.25*alpha))

	# Shoes
	r(4+leg_bob*0.5, 40, 12, 6, Color("#181010"))
	r(4+leg_bob*0.5, 41, 10, 5, Color("#282828"))
	r(20-leg_bob*0.5, 40, 12, 6, Color("#181010"))
	r(20-leg_bob*0.5, 41, 10, 5, Color("#282828"))

	# Pants/legs
	r(6, 28, 10, 14, Color("#1828a0"))
	r(6, 28, 10, 14, Color("#181010"), false, 1.0/s)
	r(20, 28, 10, 14, Color("#1828a0"))
	r(20, 28, 10, 14, Color("#181010"), false, 1.0/s)

	# Belt
	r(4, 26, 28, 4, Color("#502808"))
	r(14, 26, 8, 4, Color("#ffd700"))

	# Shirt body (Red — the protagonist)
	r(4, 14, 28, 14, Color("#c01010"))
	r(4, 14, 28, 4, Color("#e01818"))
	r(4, 22, 28, 6, Color("#a00c0c"))
	r(4, 14, 28, 14, Color("#181010"), false, 1.0/s)
	r(14, 14, 8, 5, Color("#e8e8e8"))  # collar

	# Arms
	r(0, 15, 6, 14, Color("#f0c890"))
	r(0, 15, 6, 14, Color("#181010"), false, 1.0/s)
	r(30, 15, 6, 14, Color("#f0c890"))
	r(30, 15, 6, 14, Color("#181010"), false, 1.0/s)

	# Hands
	r(-1, 26, 7, 6, Color("#f0c890"))
	r(30, 26, 7, 6, Color("#f0c890"))

	# Neck
	r(15, 10, 6, 6, Color("#f0c890"))

	# Head
	r(8, 0, 20, 14, Color("#f0c890"))
	r(8, 0, 20, 14, Color("#181010"), false, 1.0/s)
	r(9, 0, 18, 5, Color("#f8d8a8"))

	# Cap
	r(7, 0, 22, 6, Color("#c01010"))
	r(5, 4, 26, 4, Color("#c01010"))
	r(6, 1, 20, 3, Color("#e02020"))
	r(7, 0, 22, 6, Color("#181010"), false, 1.0/s)

	# Cap badge
	r(16, 1, 6, 4, Color("#ffd700"))
	r(17, 1, 4, 3, Color("#ffe880"))

	# Eyes
	r(11, 8, 4, 4, Color("#181010"))
	r(21, 8, 4, 4, Color("#181010"))
	r(12, 8, 2, 2, Color(1,1,1,0.7))
	r(22, 8, 2, 2, Color(1,1,1,0.7))

	# Attack effect: energy orb at hand
	if _p_anim == Anim.ATTACK and _p_anim_t < 0.4:
		var oe := _p_anim_t / 0.4
		var oc := {"math":Color("#44aaff"),"english":Color("#ffcc44"),"music":Color("#cc44ff")}.get(_world, Color.WHITE)
		draw_circle(Vector2(px+36*s, py+30*s), (8+oe*12)*s, Color(oc.r,oc.g,oc.b,0.8*(1-oe)))
		draw_circle(Vector2(px+36*s, py+30*s), (4+oe*6)*s, Color(1,1,1,0.6*(1-oe)))

	# Victory pose: raised arm
	if _p_anim == Anim.VICTORY:
		r(28, 8, 6, 16, Color("#f0c890"))
		r(28, 8, 6, 16, Color("#181010"), false, 1.0/s)

# ── ENEMY AVATAR (front view, Gen 1/2 scaled) ──────────────────────────────────
func _draw_enemy_avatar() -> void:
	var s  := E_SCALE
	var ex := float(E_X)
	var ey := float(E_Y)

	var bob_y  := sin(_time * 1.6) * 2.0 * s
	var hurt_x := 0.0
	var alpha  := 1.0

	match _e_anim:
		Anim.HURT:
			hurt_x = sin(_e_anim_t * 22.0) * 6.0 * s
			alpha  = 1.0 - _e_anim_t * 0.6
		Anim.FAINT:
			ey += _e_anim_t * 80.0 * s
			alpha = maxf(0.0, 1.0 - _e_anim_t * 2.0)
		Anim.ATTACK:
			hurt_x = -sin(_e_anim_t * 12.0) * 8.0 * s

	ex += hurt_x
	ey += bob_y

	var col := Color(1, 1, 1, alpha)
	var ec := _enemy_col

	func r(x:float,y:float,w:float,h:float,c:Color)->void:
		draw_rect(Rect2(ex+x*s, ey+y*s, w*s, h*s), c*col)

	# Platform shadow
	r(2, 54, 34, 8, Color(0,0,0,0.2*alpha))

	# Shoes
	r(5, 48, 10, 6, Color("#181010"))
	r(22, 48, 10, 6, Color("#181010"))

	# Legs
	r(7, 36, 8, 14, Color(ec.r*0.4, ec.g*0.4, ec.b*0.5, alpha))
	r(22, 36, 8, 14, Color(ec.r*0.4, ec.g*0.4, ec.b*0.5, alpha))
	r(7, 36, 8, 14, Color("#181010"), false, 1.0/s)
	r(22, 36, 8, 14, Color("#181010"), false, 1.0/s)

	# Body (robe/outfit colored by world)
	r(4, 18, 30, 20, ec.darkened(0.2))
	r(4, 18, 30, 6, ec.lightened(0.15))
	r(4, 18, 30, 20, Color("#181010"), false, 1.0/s)

	# Decorative collar/tie
	r(14, 20, 10, 16, Color(1,1,1,0.2*alpha))
	r(16, 22, 6, 14, ec.lightened(0.4))

	# Arms
	r(0, 20, 5, 14, Color("#f0c890"))
	r(0, 20, 5, 14, Color("#181010"), false, 1.0/s)
	r(32, 20, 5, 14, Color("#f0c890"))
	r(32, 20, 5, 14, Color("#181010"), false, 1.0/s)

	# Head
	r(9, 6, 20, 14, Color("#f0c890"))
	r(9, 6, 20, 14, Color("#181010"), false, 1.0/s)
	r(10, 6, 18, 5, Color("#f8d8a8"))

	# Hair
	r(9, 6, 20, 5, Color("#302010"))
	r(10, 6, 16, 3, Color("#504020"))

	# Eyes (front-facing, serious expression)
	r(13, 12, 4, 4, Color("#181010"))
	r(21, 12, 4, 4, Color("#181010"))
	r(14, 12, 2, 2, Color(1,1,1,0.7*alpha))
	r(22, 12, 2, 2, Color(1,1,1,0.7*alpha))

	# Glasses (all leaders wear glasses)
	r(12, 12, 6, 5, Color("#181010"), false, 1.0/s)
	r(20, 12, 6, 5, Color("#181010"), false, 1.0/s)
	r(18, 14, 2, 1, Color("#181010"))

	# World-specific aura/effect
	var pulse := 0.5 + 0.5 * sin(_time * 2.5)
	match _world:
		"math":   # Blue circuit glow
			draw_circle(Vector2(ex+19*s, ey+28*s), 18*s, Color(0.2,0.5,1.0,0.1*pulse*alpha))
			for i in 3:
				var ang := _time*2.0 + i*TAU/3
				var cx := ex+19*s + cos(ang)*14*s
				var cy := ey+28*s + sin(ang)*14*s
				draw_circle(Vector2(cx,cy), 3*s, Color(0.3,0.6,1.0,0.6*pulse*alpha))
		"english": # Gold script swirls
			for i in 3:
				var ang := _time*1.5 + i*TAU/3
				draw_rect(Rect2(ex+(16+cos(ang)*12)*s, ey+(28+sin(ang)*12)*s, 4*s, 4*s),
					Color(1.0,0.8,0.0,0.5*pulse*alpha))
		"music":  # Purple musical notes
			for i in 4:
				var nx := ex+(8+i*7)*s
				var ny := ey+(2-sin(_time*2+i))*s*3
				draw_rect(Rect2(nx, ny, 4*s, 5*s), Color(0.7,0.2,1.0,0.7*pulse*alpha))
				draw_rect(Rect2(nx+3*s, ny-4*s, 1.5*s, 5*s), Color(0.7,0.2,1.0,0.6*alpha))

	# Attack beam effect
	if _e_anim == Anim.ATTACK and _e_anim_t < 0.5:
		var t := _e_anim_t / 0.5
		draw_line(Vector2(ex+19*s, ey+28*s), Vector2(P_X+20*P_SCALE, P_Y+20*P_SCALE),
			Color(ec.r, ec.g, ec.b, (1-t)*0.8), 3.0*s)
