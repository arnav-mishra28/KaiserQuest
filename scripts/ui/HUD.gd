# HUD.gd
extends CanvasLayer
var _notif:String=""; var _notif_t:float=0.0
const NDUR:=2.5; var _ctrl:Control
func _ready()->void:
	layer=9; _ctrl=_D.new(); _ctrl.set("hud",self); add_child(_ctrl)
	GameManager.xp_changed.connect(func(_a,_b,_c): _ctrl.queue_redraw())
	GameManager.level_up.connect(func(lv): _show("LEVEL UP!  Lv."+str(lv)+"  ✓"))
	GameManager.badge_earned.connect(func(b): _show("Badge: "+b+"!"))
	GameManager.hp_changed.connect(func(_a,_b): _ctrl.queue_redraw())
	set_process(true)
func _process(d:float)->void: _notif_t=max(0.0,_notif_t-d); _ctrl.queue_redraw()
func show_xp_gain(amt:int)->void: _show("+"+str(amt)+" XP")
func _show(t:String)->void: _notif=t; _notif_t=NDUR
class _D extends Control:
	var hud
	func _ready()->void: set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_IGNORE
	func _draw()->void:
		if hud==null: return
		var fnt:=ThemeDB.fallback_font; var gm:=GameManager; var DK:=Color("#181010")
		if gm.active_world=="": return
		var wcol={"math":Color("#2060d0"),"english":Color("#c07010"),"music":Color("#8020c0")}.get(gm.active_world,Color("#404060"))
		const PW:=162; const PX:=480-PW-4; const PY:=4
		draw_rect(Rect2(PX,PY,PW,72),DK); draw_rect(Rect2(PX+1,PY+1,PW-2,70),Color("#f0f0e0"))
		draw_rect(Rect2(PX+1,PY+1,PW-2,13),wcol.lightened(0.3))
		draw_rect(Rect2(PX+3,PY+3,6,6),wcol)
		draw_string(fnt,Vector2(PX+13,PY+12),gm.player_name+"  Lv."+str(gm.get_level()),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DK)
		# HP bar
		draw_string(fnt,Vector2(PX+4,PY+26),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		var hp_f:=float(gm.get_hp())/float(gm.get_max_hp())
		var hcol:=Color("#48c840") if hp_f>0.5 else (Color("#f8d010") if hp_f>0.25 else Color("#e02020"))
		draw_rect(Rect2(PX+22,PY+19,PW-26,8),DK); draw_rect(Rect2(PX+23,PY+20,PW-28,6),Color("#686868"))
		draw_rect(Rect2(PX+23,PY+20,int((PW-28)*hp_f),6),hcol)
		draw_string(fnt,Vector2(PX+4,PY+36),str(gm.get_hp())+"/"+str(gm.get_max_hp()),HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		# XP bar
		draw_string(fnt,Vector2(PX+4,PY+48),"XP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		var xp_f:=float(gm.get_xp())/float(gm.get_xp_max())
		draw_rect(Rect2(PX+22,PY+41,PW-26,7),DK); draw_rect(Rect2(PX+23,PY+42,PW-28,5),Color("#686868"))
		draw_rect(Rect2(PX+23,PY+42,int((PW-28)*xp_f),5),wcol)
		draw_string(fnt,Vector2(PX+4,PY+57),str(gm.get_xp())+"/"+str(gm.get_xp_max()),HORIZONTAL_ALIGNMENT_LEFT,-1,9,DK)
		# Gold
		draw_string(fnt,Vector2(PX+4,PY+68),"G: "+str(gm.get_gold()),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c07000"))
		# Badges
		var badges:=gm.get_badges()
		if badges.size()>0:
			draw_rect(Rect2(PX,PY+74,PW,14),DK); draw_rect(Rect2(PX+1,PY+75,PW-2,12),Color("#f8f8e8"))
			var bs:=""; for i in min(badges.size(),5): bs+="★"
			bs+=" "+str(badges.size())+"/20"
			draw_string(fnt,Vector2(PX+4,PY+85),bs,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c07000"))
		# XP notification
		if hud._notif_t>0.0:
			var a:=minf(hud._notif_t/0.35,1.0)
			var ny=66.0-(1.0-hud._notif_t/hud.NDUR)*14.0
			draw_rect(Rect2(158,ny-15,164,18),DK); draw_rect(Rect2(159,ny-14,162,16),Color("#f0f8e0",a))
			draw_string(fnt,Vector2(166,ny),hud._notif,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.05,0.5,0.05,a))
