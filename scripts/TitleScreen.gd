# TitleScreen.gd
# Pixel-art title screen for KaiserQuest
extends Node2D

signal start_game

var _alpha:       float = 0.0
var _blink_timer: float = 0.0
var _show_enter:  bool  = true
var _ready_flag:  bool  = false

# Star positions (pre-computed for perf)
const STARS := [
	Vector2(40,  18), Vector2(115, 12), Vector2(195, 40), Vector2(340, 16),
	Vector2(425, 55), Vector2(75,  75), Vector2(395, 85), Vector2(245,  8),
	Vector2(158, 65), Vector2(455, 35), Vector2(28,  95), Vector2(300, 50),
	Vector2(500, 70), Vector2(60, 130), Vector2(420,110), Vector2(200, 95),
]

func _ready() -> void:
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	if _alpha < 1.0:
		_alpha = minf(_alpha + delta * 0.7, 1.0)
		if _alpha >= 1.0:
			_ready_flag = true

	_blink_timer += delta
	if _blink_timer >= 0.55:
		_blink_timer = 0.0
		_show_enter = not _show_enter

	queue_redraw()

func _input(event: InputEvent) -> void:
	if _ready_flag and event.is_action_pressed("ui_accept"):
		start_game.emit()

func _draw() -> void:
	var W := 480.0
	var H := 320.0

	# ── Background ──────────────────────────────────────────────────────────
	draw_rect(Rect2(0, 0, W, H), Color("#050510"))

	# ── Stars ───────────────────────────────────────────────────────────────
	for s in STARS:
		var sz := 2 if int(s.x + s.y) % 3 == 0 else 1
		draw_rect(Rect2(s.x, s.y, sz, sz), Color(1, 1, 1, _alpha * 0.8))

	# ── Mountain silhouettes ─────────────────────────────────────────────────
	var mc := Color(0.08, 0.08, 0.22, _alpha)
	# Left mountain
	draw_colored_polygon(
	PackedVector2Array([Vector2(0,320), Vector2(110,185), Vector2(240,320)]),
	mc
	)
	# Right mountain
	draw_colored_polygon(
	PackedVector2Array([Vector2(210,320), Vector2(355,155), Vector2(480,320)]),
	mc
	)
	# Silver peak highlight
	var pc := Color(0.75, 0.80, 1.0, _alpha)
	draw_colored_polygon(
	PackedVector2Array([Vector2(335,170), Vector2(355,155), Vector2(378,170)]),
	pc
	)

	# ── Title ────────────────────────────────────────────────────────────────
	var fnt := ThemeDB.fallback_font
	var gold  := Color(1.0, 0.84, 0.0, _alpha)
	var white := Color(1.0, 1.0, 1.0, _alpha)
	var grey  := Color(0.65, 0.65, 0.65, _alpha * 0.9)

	draw_string(fnt, Vector2(68, 115), "KAISER", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, gold)
	draw_string(fnt, Vector2(105, 163), "QUEST",  HORIZONTAL_ALIGNMENT_LEFT, -1, 54, white)

	# Separator line
	draw_rect(Rect2(64, 170, 350, 2), Color(1.0, 0.84, 0.0, _alpha * 0.6))

	# Subtitle
	if _alpha > 0.6:
		draw_string(fnt, Vector2(75, 195),
			"Learn · Level Up · Become Kaiser",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, grey)

	# Press ENTER
	if _show_enter and _ready_flag:
		draw_string(fnt, Vector2(148, 265),
			"Press  ENTER  to  Start",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, white)

	# Version tag
	draw_string(fnt, Vector2(398, 312), "v0.1 MVP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.3, 0.4, _alpha))
