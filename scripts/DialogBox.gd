# DialogBox.gd — Pokémon-style typewriter dialog panel
extends CanvasLayer

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
	_ctrl.db = self
	add_child(_ctrl)
	_ctrl.hide()
	set_process(false)
	set_process_input(false)

func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	_lines    = lines
	_page     = 0
	_callback = cb
	_begin_page()
	_ctrl.show()
	_open = true
	set_process(true)
	set_process_input(true)
	_notify_overworld(true)

func hide_dialog() -> void:
	_ctrl.hide()
	_open = false
	set_process(false)
	set_process_input(false)
	_notify_overworld(false)

func is_open() -> bool:
	return _open

func _notify_overworld(v: bool) -> void:
	var ow: Node = get_tree().get_first_node_in_group("overworld")
	if ow and ow.has_method("set_dialog_open"):
		ow.set_dialog_open(v)

func _begin_page() -> void:
	if _page >= _lines.size():
		_finish()
		return
	_full   = str(_lines[_page])
	_shown  = ""
	_typing = true
	_type_t = 0.0
	_done   = false

func _finish() -> void:
	hide_dialog()
	if _callback.is_valid():
		_callback.call()

func _process(delta: float) -> void:
	if _typing:
		_type_t += delta
		var n: int = int(_type_t * 38.0)
		if n >= _full.length():
			_shown  = _full
			_typing = false
			_done   = true
		else:
			_shown = _full.substr(0, n)
	_blink_t += delta
	if _blink_t >= 0.45:
		_blink_t = 0.0
		_blink   = not _blink
	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_accept"):
		if _typing:
			_shown  = _full
			_typing = false
			_done   = true
		else:
			_page += 1
			_begin_page()
		get_viewport().set_input_as_handled()

# ── Inner draw class — uses only literals, no outer class references ──────────
class _Drawer extends Control:
	var db: Node   # DialogBox instance

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if db == null:
			return
		var is_open: bool = db.get("_open")
		if not is_open:
			return

		# All constants are literals here — no cross-class constant access
		const W:  int = 480
		const H:  int = 320
		const BH: int = 82
		const FS: int = 14

		var by:  int  = H - BH - 4
		var fnt: Font = ThemeDB.fallback_font

		# Panel
		draw_rect(Rect2(4, by, W - 8, BH),
			Color(0.04, 0.04, 0.10, 0.93))
		draw_rect(Rect2(4, by, W - 8, BH),
			Color(0.75, 0.80, 1.00, 0.80), false, 2.0)
		draw_rect(Rect2(6, by + 2, W - 12, BH - 4),
			Color(0.35, 0.40, 0.70, 0.35), false, 1.0)

		# Text — read shown via get() to avoid untyped inference
		var shown:  String              = db.get("_shown")
		var rows:   PackedStringArray   = shown.split("\n")
		for i: int in rows.size():
			draw_string(fnt,
				Vector2(14, by + 8 + FS + i * (FS + 4)),
				rows[i],
				HORIZONTAL_ALIGNMENT_LEFT, W - 28, FS,
				Color(0.93, 0.93, 0.93))

		# Continue arrow
		var done:  bool = db.get("_done")
		var blink: bool = db.get("_blink")
		if done and blink:
			draw_string(fnt, Vector2(W - 22, by + BH - 10),
				"▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1.0, 0.84, 0.0))

		# Page counter
		var lines_arr: Array = db.get("_lines")
		var page:      int   = db.get("_page")
		if lines_arr.size() > 1:
			draw_string(fnt, Vector2(W - 54, by + 15),
				str(page + 1) + "/" + str(lines_arr.size()),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.55, 0.55, 0.75))
