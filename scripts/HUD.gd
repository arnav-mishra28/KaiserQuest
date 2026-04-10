# HUD.gd  —  Persistent heads-up display
extends CanvasLayer

const FS := 13
var _notif:String=""; var _notif_t:float=0.0
const NOTIF_DUR:=2.4
var _ctrl:Control

func _ready()->void:
	layer=9
	_ctrl=_HUDDraw.new(); _ctrl.set("hud",self); add_child(_ctrl)
	GameManager.xp_changed.connect(func(_a,_b,_c): _ctrl.queue_redraw())
	GameManager.level_up.connect(func(lv): _show("LEVEL UP!  Lv."+str(lv)))
	GameManager.badge_earned.connect(func(b): _show("Badge earned: "+b+"!"))
	set_process(true)

func _process(delta:float)->void:
	if _notif_t>0.0: _notif_t-=delta
	_ctrl.queue_redraw()

func show_xp_gain(amt:int)->void: _show("+"+str(amt)+" XP")
func _show(txt:String)->void: _notif=txt; _notif_t=NOTIF_DUR

class _HUDDraw extends Control:
	var hud
	func _ready()->void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter=MOUSE_FILTER_IGNORE
	func _draw()->void:
		if hud==null: return
		var fnt:=ThemeDB.fallback_font; var gm:=GameManager
		if gm.active_world=="": return
		var wcol={
			"math":Color("#44aaff"),"english":Color("#ffcc44"),"music":Color("#cc44ff")
		}.get(gm.active_world,Color.WHITE)

		# ── Stats panel (top-right) ───────────────────────────────────────
		const PW:=154; const PH:=38
		const PX:=480-PW-4; const PY:=4
		draw_rect(Rect2(PX,PY,PW,PH),Color(0,0,0,0.58))
		draw_rect(Rect2(PX,PY,PW,PH),wcol*Color(1,1,1,0.55),false,1.5)
		# World dot
		draw_rect(Rect2(PX+4,PY+4,6,6),wcol)
		# Name + level
		draw_string(fnt,Vector2(PX+14,PY+hud.FS+2),
			gm.player_name+"  Lv."+str(gm.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,hud.FS,Color("#ffffff"))
		# XP bar
		const BX:=PX+4; const BY:=PY+24; const BW:=PW-8; const BH:=7
		var frac:=float(gm.get_xp())/float(gm.get_xp_max())
		draw_rect(Rect2(BX,BY,BW,BH),Color(0.08,0.08,0.14))
		draw_rect(Rect2(BX,BY,int(BW*frac),BH),wcol)
		draw_rect(Rect2(BX,BY,BW,BH),Color(0,0,0,0.35),false,1.0)
		draw_string(fnt,Vector2(BX,BY+BH+11),
			str(gm.get_xp())+"/"+str(gm.get_xp_max())+" XP",
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,wcol*Color(1,1,1,0.9))

		# ── Badges ───────────────────────────────────────────────────────
		var badges:=gm.get_badges()
		if badges.size()>0:
			var bx:=PX; var by2:=PY+PH+4
			draw_rect(Rect2(bx,by2,PW,18),Color(0,0,0,0.52))
			var bstr:=""
			for i in min(badges.size(),3): bstr+="★ "
			bstr+="Badges: "+str(badges.size())
			draw_string(fnt,Vector2(bx+5,by2+13),bstr,
				HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#ffd700"))

		# ── XP / Level notification ──────────────────────────────────────
		if hud._notif_t>0.0:
			var a:=minf(hud._notif_t/0.35,1.0)
			var rise=(1.0-hud._notif_t/hud.NOTIF_DUR)*14.0
			var ny=58.0-rise
			draw_rect(Rect2(158,ny-15,164,21),Color(0,0,0,0.65*a))
			draw_string(fnt,Vector2(166,ny),hud._notif,
				HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.35,1.0,0.35,a))
