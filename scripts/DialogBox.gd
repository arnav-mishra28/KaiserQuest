# DialogBox.gd
extends CanvasLayer

const CPS   := 38.0
const BOX_H := 82
const FS    := 14

var _lines:    Array    = []
var _page:     int      = 0
var _full:     String   = ""
var _shown:    String   = ""
var _typing:   bool     = false
var _type_t:   float    = 0.0
var _done:     bool     = false
var _blink_t:  float    = 0.0
var _blink:    bool     = true
var _callback: Callable = Callable()
var _open:     bool     = false
var _ctrl:     Control

func _ready() -> void:
	layer = 10
	_ctrl = _Drawer.new()
	_ctrl.set("db", self)
	add_child(_ctrl)
	_ctrl.hide()
	set_process(false)
	set_process_input(false)

func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	_lines = lines; _page = 0; _callback = cb
	_begin_page()
	_ctrl.show(); _open = true
	set_process(true); set_process_input(true)
	_notify_overworld(true)

func hide_dialog() -> void:
	_ctrl.hide(); _open = false
	set_process(false); set_process_input(false)
	_notify_overworld(false)

func is_open() -> bool: return _open

func _notify_overworld(v: bool) -> void:
	var ow := get_tree().get_first_node_in_group("overworld")
	if ow and ow.has_method("set_dialog_open"):
		ow.set_dialog_open(v)

func _begin_page() -> void:
	if _page >= _lines.size(): _finish(); return
	_full = str(_lines[_page]); _shown = ""
	_typing = true; _type_t = 0.0; _done = false

func _finish() -> void:
	hide_dialog()
	if _callback.is_valid(): _callback.call()

func _process(delta: float) -> void:
	if _typing:
		_type_t += delta
		var n := int(_type_t * CPS)
		if n >= _full.length():
			_shown = _full; _typing = false; _done = true
		else:
			_shown = _full.substr(0, n)
	_blink_t += delta
	if _blink_t >= 0.45: _blink_t = 0.0; _blink = not _blink
	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _open: return
	if event.is_action_pressed("ui_accept"):
		if _typing: _shown = _full; _typing = false; _done = true
		else: _page += 1; _begin_page()
		get_viewport().set_input_as_handled()

class _Drawer extends Control:
	var db
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if db == null or not db._open: return
		const W:=480; const H:=320; const BH:=82; const FS:=14
		var by := H-BH-4
		var fnt := ThemeDB.fallback_font
		draw_rect(Rect2(4,by,W-8,BH),   Color(0.04,0.04,0.10,0.93))
		draw_rect(Rect2(4,by,W-8,BH),   Color(0.75,0.80,1.00,0.80),false,2.0)
		draw_rect(Rect2(6,by+2,W-12,BH-4),Color(0.35,0.40,0.70,0.35),false,1.0)
		var rows = db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt,Vector2(14,by+8+FS+i*(FS+4)),rows[i],
				HORIZONTAL_ALIGNMENT_LEFT,W-28,FS,Color("#e8e8e8"))
		if db._done and db._blink:
			draw_string(fnt,Vector2(W-22,by+BH-10),"▼",
				HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#ffd700"))
		if db._lines.size() > 1:
			draw_string(fnt,Vector2(W-54,by+15),
				str(db._page+1)+"/"+str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.55,0.55,0.75))
