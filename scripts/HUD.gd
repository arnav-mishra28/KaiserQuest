# HUD.gd
extends CanvasLayer

const FS := 13
const NOTIF_DUR := 2.2

var _notif_text: String = ""
var _notif_timer: float = 0.0
var _draw_node: Control

func _ready() -> void:
	layer = 9

	_draw_node = _HUDDraw.new()
	_draw_node.set("hud", self)
	add_child(_draw_node)

	# ✅ FIXED SIGNALS
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up.connect(_on_level_up)
	GameManager.badge_earned.connect(_on_badge_earned)

	set_process(true)

func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta

	_draw_node.queue_redraw()

func _on_xp_changed(_c,_m,_l):
	_draw_node.queue_redraw()

func _on_level_up(lv):
	_show_notif("LEVEL UP!  Lv." + str(lv))

func _on_badge_earned(b):
	_show_notif("Badge earned: " + b + "!")

func show_xp_gain(a: int):
	_show_notif("+" + str(a) + " XP")

func _show_notif(t: String):
	_notif_text = t
	_notif_timer = NOTIF_DUR

# ─────────────────────────────────────────────────────────────────────────────

class _HUDDraw extends Control:
	var hud

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not hud:
			return

		var fnt := ThemeDB.fallback_font
		var fs  = hud.FS
		var gm  := GameManager

		# ✅ USE ACCESSORS
		var level = gm.get_level()
		var xp    = gm.get_xp()
		var xpmax = gm.get_xp_max()
		var badges = gm.get_badges()

		const PW:=154
		const PH:=38

		var px := 480-PW-4
		var py := 4

		draw_rect(Rect2(px,py,PW,PH),   Color(0,0,0,0.58))
		draw_rect(Rect2(px,py,PW,PH),   Color(0.5,0.6,1,0.55),false,1.5)

		draw_string(fnt,Vector2(px+6,py+fs+2),
			"Lv."+str(level)+"  "+gm.player_name,
			HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("#f0f0f0"))

		var bw := PW-12
		var bx2 := px+6
		var by2 := py+26
		var bh := 7

		var xf := float(xp)/float(xpmax)

		draw_rect(Rect2(bx2,by2,bw,bh),  Color(0.08,0.08,0.18))
		draw_rect(Rect2(bx2,by2,int(bw*xf),bh), Color("#44aaff"))

		draw_string(fnt,Vector2(bx2,by2+bh+10),
			str(xp)+"/"+str(xpmax)+" XP",
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.7,0.9,1))

		# ✅ BADGES
		if badges.size() > 0:
			var bsx := px
			var bsy := py+PH+3

			draw_rect(Rect2(bsx,bsy,PW,18),Color(0,0,0,0.52))

			var bs := ""
			for i in min(badges.size(),5):
				bs += "★"

			bs += " "+str(badges.size())+" Badge"+("s" if badges.size()>1 else "")

			draw_string(fnt,Vector2(bsx+5,bsy+13),bs,
				HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ffd700"))

		# ✅ NOTIFICATION
		if hud._notif_timer > 0.0:
			var alpha := minf(hud._notif_timer/0.4,1.0)
			alpha = minf(alpha,hud._notif_timer)

			var ny = 58.0-(1.0-hud._notif_timer/hud.NOTIF_DUR)*14.0

			draw_rect(Rect2(155,ny-15,170,22),Color(0,0,0,0.62*alpha))

			draw_string(fnt,Vector2(162,ny),hud._notif_text,
				HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.4,1,0.4,alpha))
