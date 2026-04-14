# DialogBox.gd — FIXED: re-entrant guard prevents infinite NPC dialog loop
extends CanvasLayer

const CPS := 36.0

var _lines:    Array    = []
var _page:     int      = 0
var _full:     String   = ""
var _shown:    String   = ""
var _typing:   bool     = false
var _type_t:   float    = 0.0
var _done:     bool     = false
var _blink_t:  float    = 0.0
var _blink:    bool     = true
var _cb:       Callable = Callable()
var _open:     bool     = false
var _ctrl:     Control
var _busy:     bool     = false   # RE-ENTRANT GUARD — prevents double-open

func _ready() -> void:
	layer = 10
	_ctrl = _Drawer.new()
	_ctrl.set("db", self)
	add_child(_ctrl)
	_ctrl.hide()
	set_process(false)
	set_process_input(false)

func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	# GUARD: if already open, do NOT open again
	if _open or _busy:
		return
	if lines.is_empty():
		if cb.is_valid(): cb.call()
		return

	_busy  = true
	_lines = lines
	_page  = 0
	_cb    = cb
	_begin()
	_ctrl.show()
	_open = true
	set_process(true)
	set_process_input(true)
	_notify_overworld(true)

func hide_dialog() -> void:
	_ctrl.hide()
	_open  = false
	_busy  = false
	set_process(false)
	set_process_input(false)
	_notify_overworld(false)

func is_open() -> bool:
	return _open

func _notify_overworld(v: bool) -> void:
	# Notify World node
	var world := get_tree().get_nodes_in_group("active_world")
	for w in world:
		if w.has_method("set_dialog_open"):
			w.set_dialog_open(v)
	# Also notify player directly
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if "dialog_open" in p:
			p.dialog_open = v

func _begin() -> void:
	if _page >= _lines.size():
		_finish()
		return
	_full   = str(_lines[_page])
	_shown  = ""
	_typing = true
	_type_t = 0.0
	_done   = false

func _finish() -> void:
	var cb := _cb
	_cb    = Callable()   # clear callback BEFORE calling it (prevent re-entry)
	hide_dialog()
	if cb.is_valid():
		cb.call()

func _process(delta: float) -> void:
	if _typing:
		_type_t += delta
		var n := int(_type_t * CPS)
		if n >= _full.length():
			_shown  = _full
			_typing = false
			_done   = true
		else:
			_shown = _full.substr(0, n)

	_blink_t += delta
	if _blink_t >= 0.46:
		_blink_t = 0.0
		_blink   = not _blink

	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_accept"):
		if _typing:
			# Skip typewriter
			_shown  = _full
			_typing = false
			_done   = true
		else:
			_page += 1
			_begin()
		get_viewport().set_input_as_handled()

# ── Inner draw class ──────────────────────────────────────────────────────────
class _Drawer extends Control:
	var db

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if db == null or not db._open:
			return

		const W  := 480
		const H  := 320
		const BH := 86
		var by  := H - BH - 4
		var fnt := ThemeDB.fallback_font
		var DK  := Color("#181010")

		# Outer border
		draw_rect(Rect2(4, by, W-8, BH), DK)
		# Background
		draw_rect(Rect2(5, by+1, W-10, BH-2), Color("#f0f0e0"))
		# Header stripe (world color)
		var wcol := Color("#2060a0")
		if GameManager.active_world == "english": wcol = Color("#c07010")
		elif GameManager.active_world == "music":  wcol = Color("#8020c0")
		draw_rect(Rect2(5, by+1, W-10, 14), wcol.lightened(0.3))
		# Inner border
		draw_rect(Rect2(5, by+1, W-10, BH-2), Color(wcol.r*0.5, wcol.g*0.5, wcol.b*0.5, 0.3), false, 1.5)

		# Text lines
		var rows = db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt, Vector2(12, by + 9 + 16 + i * 16),
				rows[i], HORIZONTAL_ALIGNMENT_LEFT, W - 24, 14, DK)

		# Continue arrow (blinking)
		if db._done and db._blink:
			draw_string(fnt, Vector2(W - 22, by + BH - 10),
				"▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffd700"))

		# Page counter
		if db._lines.size() > 1:
			draw_string(fnt, Vector2(W - 52, by + 14),
				str(db._page + 1) + "/" + str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.8))
