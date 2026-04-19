# HUD.gd — Stats overlay (CanvasLayer)
extends CanvasLayer
var _notif: String=""; var _notif_t: float=0.0
const NDUR:=2.5
var _ctrl: Control
func _ready()->void:
	layer=9; _ctrl=_D.new(); _ctrl.set("hud",self); add_child(_ctrl)
	GameManager.xp_changed.connect(func(_a,_b,_c): _ctrl.queue_redraw())
	GameManager.level_up.connect(func(lv): _show("LEVEL UP! Lv."+str(lv)+"!"))
	GameManager.badge_earned.connect(func(b): _show(b+" EARNED!"))
	GameManager.hp_changed.connect(func(_a,_b): _ctrl.queue_redraw())
	set_process(true)
func _process(d:float)->void: _notif_t=max(0.0,_notif_t-d); _ctrl.queue_redraw()
func show_xp_gain(amt:int)->void: _show("+"+str(amt)+" EXP!")
func _show(t:String)->void: _notif=t; _notif_t=NDUR

class _D extends Control:
	var hud
	func _ready()->void: set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_IGNORE
	func _draw()->void:
		if hud==null: return
		var fnt:=ThemeDB.fallback_font; var gm:=GameManager
		if gm.active_subject=="": return
		var key:=gm.active_subject+":"+gm.active_branch
		var wcol=SubjectDB.SUBJECTS.get(gm.active_subject,{}).get("color",Color("#404060"))
		const DK:=Color("#181010"); const BG:=Color("#f8f8f0")
		const HP_G:=Color("#50d030"); const HP_Y:=Color("#f8c800"); const HP_R:=Color("#e82020")
		const HP_BK:=Color("#282828")
		const PW:=160; const PH:=72; const PX:=480-PW-3; const PY:=3
		draw_rect(Rect2(PX,PY,PW,PH),DK)
		draw_rect(Rect2(PX+2,PY+2,PW-4,PH-4),BG)
		draw_rect(Rect2(PX+2,PY+2,PW-4,PH-4),DK,false,1.5)
		draw_rect(Rect2(PX+2,PY+2,PW-4,14),wcol*Color(1,1,1,0.2))
		for cv in [Vector2(PX,PY),Vector2(PX+PW-8,PY),Vector2(PX,PY+PH-8),Vector2(PX+PW-8,PY+PH-8)]:
			draw_rect(Rect2(cv.x,cv.y,8,8),DK); draw_rect(Rect2(cv.x+2,cv.y+2,4,4),wcol)
		draw_string(fnt,Vector2(PX+8,PY+14),gm.player_name.to_upper()+":Lv"+str(gm.get_level()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,12,DK)
		# HP bar
		var hp_f:=float(gm.get_hp())/float(gm.get_max_hp())
		var hcol:=HP_G if hp_f>0.5 else (HP_Y if hp_f>0.25 else HP_R)
		draw_string(fnt,Vector2(PX+6,PY+26),"HP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		draw_rect(Rect2(PX+22,PY+20,PW-28,8),DK); draw_rect(Rect2(PX+23,PY+21,PW-30,6),HP_BK)
		draw_rect(Rect2(PX+23,PY+21,int((PW-30)*hp_f),6),hcol)
		if not gm.get_hp()==gm.get_max_hp():
			draw_string(fnt,Vector2(PX+PW-52,PY+38),str(gm.get_hp())+"/"+str(gm.get_max_hp()),
				HORIZONTAL_ALIGNMENT_LEFT,-1,9,DK)
		# XP bar
		var xp_f:=float(gm.get_xp())/float(gm.get_xp_max())
		draw_string(fnt,Vector2(PX+6,PY+40),"XP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,DK)
		draw_rect(Rect2(PX+22,PY+34,PW-28,6),DK); draw_rect(Rect2(PX+23,PY+35,PW-30,4),HP_BK)
		draw_rect(Rect2(PX+23,PY+35,int((PW-30)*xp_f),4),wcol.lightened(0.2))
		draw_string(fnt,Vector2(PX+6,PY+52),str(gm.get_xp())+"/"+str(gm.get_xp_max()),
			HORIZONTAL_ALIGNMENT_LEFT,-1,9,DK)
		# Badges
		var badges:=gm.get_badges()
		if badges.size()>0:
			draw_rect(Rect2(PX,PY+PH+2,PW,14),DK)
			draw_rect(Rect2(PX+2,PY+PH+4,PW-4,10),BG)
			var bs:=""; for i in min(badges.size(),6): bs+="★"
			bs+=" "+str(badges.size())+"/20"
			draw_string(fnt,Vector2(PX+5,PY+PH+12),bs,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c07000"))
		# AI stats
		var summ:=AdaptiveAI.get_summary(key)
		if summ.get("sessions",0)>0:
			var ay:=PY+PH+(16 if badges.size()>0 else 2)
			draw_rect(Rect2(PX,ay,PW,13),DK)
			draw_rect(Rect2(PX+2,ay+2,PW-4,9),Color(0.08,0.08,0.16))
			var diff=summ.get("difficulty",1)
			var dstr:="Diff:"
			for di in diff: dstr+="●"
			for di in 4-diff: dstr+="○"
			draw_string(fnt,Vector2(PX+5,ay+10),dstr,HORIZONTAL_ALIGNMENT_LEFT,-1,9,wcol.lightened(0.3))
			var streak=summ.get("streak",0)
			if streak>1:
				draw_string(fnt,Vector2(PX+PW-32,ay+10),"x"+str(streak),
					HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#f8c000"))
		# Notification
		if hud._notif_t>0.0:
			var a=minf(hud._notif_t/0.3,1.0); var ny=60.0-(1.0-hud._notif_t/hud.NDUR)*12.0
			draw_rect(Rect2(156,ny-15,168,20),Color(0,0,0,0.65*a))
			draw_string(fnt,Vector2(164,ny),hud._notif.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.35,1.0,0.35,a))
