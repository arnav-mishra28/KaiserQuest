# HUD.gd — Heads-Up Display
extends CanvasLayer

var _notif_text:  String = ""
var _notif_timer: float  = 0.0
const NOTIF_DUR           := 2.2

var _draw_ctrl: Control

func _ready() -> void:
	layer = 9
	_draw_ctrl = _HUDDraw.new()
	_draw_ctrl.hud = self
	add_child(_draw_ctrl)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up_occurred.connect(_on_level_up)
	GameManager.badge_earned.connect(_on_badge_earned)
	set_process(true)

func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta
	_draw_ctrl.queue_redraw()

func _on_xp_changed(_cur: int, _max: int, _lv: int) -> void:
	_draw_ctrl.queue_redraw()

func _on_level_up(new_level: int) -> void:
	_show_notif("LEVEL UP!  Lv." + str(new_level))

func _on_badge_earned(badge_name: String) -> void:
	_show_notif("Badge: " + badge_name + "!")

func show_xp_gain(amount: int) -> void:
	_show_notif("+" + str(amount) + " XP")

func _show_notif(text: String) -> void:
	_notif_text  = text
	_notif_timer = NOTIF_DUR

# ── Inner draw class — NO references to outer constants ──────────────────────
class _HUDDraw extends Control:
	var hud: Node   # typed as Node to avoid inference errors

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if hud == null:
			return

		var fnt:    Font   = ThemeDB.fallback_font
		var fs:     int    = 13
		var gm             = GameManager

		# ── Top-right panel ──────────────────────────────────────────────────
		var panel_w: int = 150
		var panel_h: int = 36
		var px:      int = 480 - panel_w - 4
		var py:      int = 4

		draw_rect(Rect2(px, py, panel_w, panel_h),
			Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(px, py, panel_w, panel_h),
			Color(0.6, 0.6, 1.0, 0.5), false, 1.5)

		# Level + name
		draw_string(fnt, Vector2(px + 6, py + fs + 2),
			"Lv." + str(gm.player_level) + "  " + str(gm.player_name),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0))

		# XP bar
		var bar_x:   int   = px + 6
		var bar_y:   int   = py + 24
		var bar_w:   int   = panel_w - 12
		var bar_h:   int   = 6
		var xp_frac: float = float(gm.player_xp) / float(gm.xp_to_next_level)

		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h),
			Color(0.1, 0.1, 0.2))
		draw_rect(Rect2(bar_x, bar_y, int(bar_w * xp_frac), bar_h),
			Color(0.27, 0.67, 1.0))
		draw_string(fnt, Vector2(bar_x, bar_y + bar_h + 10),
			str(gm.player_xp) + " / " + str(gm.xp_to_next_level) + " XP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.9, 1.0))

		# ── Badge strip ──────────────────────────────────────────────────────
		var badges = gm.badges
		if badges.size() > 0:
			var bx: int = px
			var by: int = py + panel_h + 4
			draw_rect(Rect2(bx, by, panel_w, 18), Color(0.0, 0.0, 0.0, 0.50))
			var txt: String = ""
			for _i: int in mini(badges.size(), 3):
				txt += "★ "
			txt += "Badges: " + str(badges.size())
			draw_string(fnt, Vector2(bx + 5, by + 13),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.84, 0.0))

		# ── XP / level-up notification ───────────────────────────────────────
		var timer: float = (hud as Node).get("_notif_timer")
		if timer > 0.0:
			var alpha: float = minf(minf(timer / 0.4, 1.0), timer)
			var notif: String = (hud as Node).get("_notif_text")
			var ny: float = 60.0 - (1.0 - timer / 2.2) * 15.0
			draw_rect(Rect2(150, ny - 14, 170, 22), Color(0.0, 0.0, 0.0, 0.6 * alpha))
			draw_string(fnt, Vector2(158, ny),
				notif, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.4, 1.0, 0.4, alpha))
