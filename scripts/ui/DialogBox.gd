# DialogBox.gd
extends CanvasLayer
const CPS:=36.0
var _lines:Array=[]; var _page:int=0; var _full:String=""; var _shown:String=""
var _typing:bool=false; var _type_t:float=0.0; var _done:bool=false
var _blink_t:float=0.0; var _blink:bool=true; var _cb:Callable=Callable()
var _open:bool=false; var _ctrl:Control
func _ready()->void:
	layer=10; _ctrl=_D.new(); _ctrl.set("db",self); add_child(_ctrl); _ctrl.hide()
	set_process(false); set_process_input(false)
func show_lines(lines:Array,cb:Callable=Callable())->void:
	_lines=lines; _page=0; _cb=cb; _begin()
	_ctrl.show(); _open=true; set_process(true); set_process_input(true)
	var ow:=get_tree().get_first_node_in_group("overworld")
	if ow and ow.has_method("set_dialog_open"): ow.set_dialog_open(true)
func hide_dialog()->void:
	_ctrl.hide(); _open=false; set_process(false); set_process_input(false)
	var ow:=get_tree().get_first_node_in_group("overworld")
	if ow and ow.has_method("set_dialog_open"): ow.set_dialog_open(false)
func is_open()->bool: return _open
func _begin()->void:
	if _page>=_lines.size(): _finish(); return
	_full=str(_lines[_page]); _shown=""; _typing=true; _type_t=0.0; _done=false
func _finish()->void:
	hide_dialog(); if _cb.is_valid(): _cb.call()
func _process(delta:float)->void:
	if _typing:
		_type_t+=delta; var n:=int(_type_t*CPS)
		if n>=_full.length(): _shown=_full; _typing=false; _done=true
		else: _shown=_full.substr(0,n)
	_blink_t+=delta; if _blink_t>=0.46: _blink_t=0.0; _blink=not _blink
	_ctrl.queue_redraw()
func _input(ev:InputEvent)->void:
	if not _open: return
	if ev.is_action_pressed("ui_accept"):
		if _typing: _shown=_full; _typing=false; _done=true
		else: _page+=1; _begin()
		get_viewport().set_input_as_handled()
class _D extends Control:
	var db
	func _ready()->void: set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_IGNORE
	func _draw()->void:
		if db==null or not db._open: return
		const W:=480;const H:=320;const BH:=86
		var by:=H-BH-4; var fnt:=ThemeDB.fallback_font; var DK:=Color("#181010")
		draw_rect(Rect2(4,by,W-8,BH),DK)
		draw_rect(Rect2(5,by+1,W-10,BH-2),Color("#f0f0e0"))
		draw_rect(Rect2(5,by+1,W-10,14),Color("#2060a0"))
		var rows=db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt,Vector2(12,by+9+16+i*16),rows[i],HORIZONTAL_ALIGNMENT_LEFT,W-24,14,DK)
		if db._done and db._blink:
			draw_string(fnt,Vector2(W-22,by+BH-10),"▼",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffd700"))
		if db._lines.size()>1:
			draw_string(fnt,Vector2(W-52,by+15),str(db._page+1)+"/"+str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.6,0.6,0.8))
