# HUD.gd v2.0 — Pokémon Gen 1/2 style HUD with pixel borders
extends CanvasLayer

var _notif:  String = ""; var _notif_t: float = 0.0
const NDUR := 2.5
var _ctrl: Control

func _ready() -> void:
	layer = 9
	_ctrl = _D.new(); _ctrl.set("hud", self)
	add_child(_ctrl)
	GameManager.xp_changed.connect(func(_a,_b,_c): _ctrl.queue_redraw())
	GameManager.level_up.connect(func(lv): _show("LEVEL UP!  Lv."+str(lv)+"!"))
	GameManager.badge_earned.connect(func(b): _show(b+" OBTAINED!"))
	GameManager.hp_changed.connect(func(_a,_b): _ctrl.queue_redraw())
	set_process(true)

func _process(d: float) -> void: _notif_t=max(0.0,_notif_t-d); _ctrl.queue_redraw()
func show_xp_gain(amt: int) -> void: _show("+"+str(amt)+" EXP.PTS!")
func _show(t: String) -> void: _notif=t; _notif_t=NDUR

class _D extends Control:
	var hud
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if hud==null: return
		var fnt:=ThemeDB.fallback_font; var gm:=GameManager
		if gm.active_world=="": return
		var wcol={"math":Color("#2060d0"),"english":Color("#c07010"),"music":Color("#8020c0")}.get(gm.active_world,Color("#404060"))
		const DK:=Color("#181010"); const BG:=Color("#f8f8f0")
		const HP_G:=Color("#50d030"); const HP_Y:=Color("#f8c800"); const HP_R:=Color("#e82020")
		const HP_BK:=Color("#282828")

		# ── Pokémon-style stat panel (top-right) ──────────────────────────
		const PW:=160; const PH:=68; const PX:=480-PW-3; const PY:=3
		# Double border (Gen 1 style)
		draw_rect(Rect2(PX,PY,PW,PH), DK)
		draw_rect(Rect2(PX+2,PY+2,PW-4,PH-4), BG)
		draw_rect(Rect2(PX+2,PY+2,PW-4,PH-4), DK, false, 1.5)
		# Corner ornaments
		for c in [Vector2(PX,PY),Vector2(PX+PW-8,PY),Vector2(PX,PY+PH-8),Vector2(PX+PW-8,PY+PH-8)]:
			draw_rect(Rect2(c.x,c.y,8,8), DK); draw_rect(Rect2(c.x+2,c.y+2,4,4), wcol)
		# Name + level
		draw_string(fnt,Vector2(PX+8,PY+14),gm.player_name.to_upper()+":Lv"+str(gm.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,12,DK)
		# HP bar
		draw_string(fnt,Vector2(PX+6,PY+27),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		var hp_f:=float(gm.get_hp())/float(gm.get_max_hp())
		var hcol:=HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
		draw_rect(Rect2(PX+24,PY+21,PW-28,8), DK)
		draw_rect(Rect2(PX+25,PY+22,PW-30,6), HP_BK)
		draw_rect(Rect2(PX+25,PY+22,int((PW-30)*hp_f),6), hcol)
		draw_string(fnt,Vector2(PX+6,PY+38),str(gm.get_hp())+"/"+str(gm.get_max_hp()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
		# XP bar
		draw_string(fnt,Vector2(PX+6,PY+50),"EXP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		var xp_f:=float(gm.get_xp())/float(gm.get_xp_max())
		draw_rect(Rect2(PX+28,PY+44,PW-32,6), DK)
		draw_rect(Rect2(PX+29,PY+45,PW-34,4), HP_BK)
		draw_rect(Rect2(PX+29,PY+45,int((PW-34)*xp_f),4), wcol.lightened(0.2))
		draw_string(fnt,Vector2(PX+6,PY+60),str(gm.get_xp())+"/"+str(gm.get_xp_max()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,9,DK)

		# ── Badges row ─────────────────────────────────────────────────────
		var badges:=gm.get_badges()
		if badges.size()>0:
			draw_rect(Rect2(PX,PY+PH+2,PW,14), DK)
			draw_rect(Rect2(PX+2,PY+PH+4,PW-4,10), BG)
			var bs:=""; for i in min(badges.size(),6): bs+="★"
			bs+=" "+str(badges.size())+"/20"
			draw_string(fnt,Vector2(PX+6,PY+PH+12),bs,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c07000"))

		# ── Adaptive AI performance strip ─────────────────────────────────
		if gm.active_world != "":
			var summ := AdaptiveAI.get_summary(gm.active_world)
			var diff = summ.get("difficulty", 1)
			var streak = summ.get("streak", 0)
			var xp_mult = summ.get("xp_mult", 1.0)
			var weak = summ.get("weak", [])
			# Only show if we have session data
			if summ.get("sessions", 0) > 0:
				var ay := PY + PH + (16 if badges.size() > 0 else 2)
				draw_rect(Rect2(PX, ay, PW, 13), DK)
				draw_rect(Rect2(PX+2, ay+2, PW-4, 9), Color(0.1, 0.1, 0.18))
				# Difficulty dots
				var diff_i: int = clamp(int(diff), 0, 4)
				var diff_str = "Diff: " + "●".repeat(diff_i) + "○".repeat(4 - diff_i)
				draw_string(fnt, Vector2(PX+6, ay+10), diff_str,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, wcol.lightened(0.3))
				# Streak
				if streak > 1:
					draw_string(fnt, Vector2(PX + PW - 36, ay+10), "🔥"+str(streak),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f8c000"))
			# Weak topic warning
			if weak.size() > 0:
				var wy := PY + PH + (32 if badges.size() > 0 else 18)
				draw_rect(Rect2(PX, wy, PW, 13), DK)
				draw_rect(Rect2(PX+2, wy+2, PW-4, 9), Color(0.2, 0.05, 0.05))
				draw_string(fnt, Vector2(PX+6, wy+10),
					"Weak: " + str(weak[0]).left(12),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#e04040"))

		# ── XP gain notification (Gen 1 style text popup) ──────────────────
		if hud._notif_t>0.0:
			var a:=minf(hud._notif_t/0.3,1.0)
			var ny=70.0-(1.0-hud._notif_t/hud.NDUR)*12.0
			# Notification box with border
			draw_rect(Rect2(156,ny-16,168,20),DK)
			draw_rect(Rect2(158,ny-14,164,16),BG)
			draw_rect(Rect2(158,ny-14,164,16),DK,false,1.5)
			draw_string(fnt,Vector2(164,ny),hud._notif.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,
				DK if a>0.5 else Color(DK.r,DK.g,DK.b,a*2))

		# ── Town name (bottom-left, Gen 1 location banner) ─────────────────
		var world_nodes=Engine.get_main_loop().root.get_tree().get_nodes_in_group("active_world")
		var town:=""
		for w in world_nodes:
			if w.has_method("get") and "TOWN_NAMES" in w:
				town=w.TOWN_NAMES.get(gm.active_world,"")
				break
		# Small location tag
		if town!="":
			draw_rect(Rect2(3,3,130,16),DK); draw_rect(Rect2(5,5,126,12),BG)
			draw_rect(Rect2(5,5,126,12),DK,false,1.5)
			draw_string(fnt,Vector2(9,15),town.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,DK)
