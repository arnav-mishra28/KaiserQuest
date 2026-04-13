# HUD.gd v0.5
extends CanvasLayer

const FS:=12
var _notif:String=""; var _notif_t:float=0.0
const NOTIF_DUR:=2.6
var _ctrl:Control

func _ready()->void:
	layer=9; _ctrl=_D.new(); _ctrl.set("hud",self); add_child(_ctrl)
	GameManager.xp_changed.connect(func(_a,_b,_c): _ctrl.queue_redraw())
	GameManager.level_up.connect(func(lv): _show("LEVEL UP!  Lv."+str(lv)))
	GameManager.badge_earned.connect(func(b): _show("Badge: "+b+"!"))
	GameManager.hp_changed.connect(func(_a,_b): _ctrl.queue_redraw())
	set_process(true)

func _process(_d:float)->void: _notif_t=max(0.0,_notif_t-_d); _ctrl.queue_redraw()
func show_xp_gain(amt:int)->void: _show("+"+str(amt)+" XP")
func _show(txt:String)->void: _notif=txt; _notif_t=NOTIF_DUR

class _D extends Control:
	var hud
	func _ready()->void:
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_IGNORE
	func _draw()->void:
		if hud==null: return
		var fnt:=ThemeDB.fallback_font; var gm:=GameManager
		if gm.active_world=="": return
		var wcol={"math":Color("#2060d0"),"english":Color("#c07010"),"music":Color("#8020c0")}.get(gm.active_world,Color("#404060"))
		const PW:=160; const PX:=480-PW-4; const PY:=4

		# ── Stats panel ────────────────────────────────────────────────────
		draw_rect(Rect2(PX,PY,PW,60),Color("#181010"))
		draw_rect(Rect2(PX+1,PY+1,PW-2,58),Color("#f0f0e0"))
		draw_rect(Rect2(PX+1,PY+1,PW-2,12),wcol.lightened(0.3))

		# Name + Level
		draw_string(fnt,Vector2(PX+4,PY+11),
			gm.player_name+"  Lv."+str(gm.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,hud.FS,Color("#181010"))

		# HP bar (Pokémon style)
		draw_string(fnt,Vector2(PX+4,PY+24),"HP:",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#181010"))
		var hp_frac:=float(gm.get_hp())/float(gm.get_max_hp())
		var hcol:=Color("#48c840") if hp_frac>0.5 else (Color("#f8d010") if hp_frac>0.25 else Color("#e02020"))
		draw_rect(Rect2(PX+24,PY+18,PW-28,7),Color("#181010"))
		draw_rect(Rect2(PX+25,PY+19,PW-30,5),Color("#606060"))
		draw_rect(Rect2(PX+25,PY+19,int((PW-30)*hp_frac),5),hcol)
		draw_string(fnt,Vector2(PX+4,PY+34),str(gm.get_hp())+"/"+str(gm.get_max_hp()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#303030"))

		# XP bar
		draw_string(fnt,Vector2(PX+4,PY+44),"XP:",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#181010"))
		var xp_f:=float(gm.get_xp())/float(gm.get_xp_max())
		draw_rect(Rect2(PX+24,PY+38,PW-28,6),Color("#181010"))
		draw_rect(Rect2(PX+25,PY+39,PW-30,4),Color("#606060"))
		draw_rect(Rect2(PX+25,PY+39,int((PW-30)*xp_f),4),wcol)
		draw_string(fnt,Vector2(PX+4,PY+54),str(gm.get_xp())+"/"+str(gm.get_xp_max()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#404040"))

		# Badges row
		var badges:=gm.get_badges()
		if badges.size()>0:
			draw_rect(Rect2(PX,PY+62,PW,14),Color("#181010"))
			draw_rect(Rect2(PX+1,PY+63,PW-2,12),Color("#f8f8e8"))
			var bstr:=""; for i in min(badges.size(),5): bstr+="★"
			bstr+=" ×"+str(badges.size())
			draw_string(fnt,Vector2(PX+4,PY+73),bstr,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c07000"))

		# ── Notification ──────────────────────────────────────────────────
		if hud._notif_t>0.0:
			var a:=minf(hud._notif_t/0.4,1.0)
			var ny=65.0-(1.0-hud._notif_t/hud.NOTIF_DUR)*12.0
			draw_rect(Rect2(162,ny-14,156,17),Color("#181010"))
			draw_rect(Rect2(163,ny-13,154,15),Color("#f0f8e0",a))
			draw_string(fnt,Vector2(170,ny),hud._notif,HORIZONTAL_ALIGNMENT_LEFT,-1,12,
				Color(0.1,0.5,0.1,a))
