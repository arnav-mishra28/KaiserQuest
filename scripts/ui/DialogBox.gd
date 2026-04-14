# DialogBox.gd — Clean state machine, zero re-entry bugs
extends CanvasLayer

const CPS := 36.0

enum State { CLOSED, TYPING, WAITING }

var _state:  int      = State.CLOSED
var _lines:  Array    = []
var _page:   int      = 0
var _full:   String   = ""
var _shown:  String   = ""
var _type_t: float    = 0.0
var _blink_t:float    = 0.0
var _blink:  bool     = true
var _cb:     Callable = Callable()
var _ctrl:   Control

func _ready() -> void:
	layer = 10
	_ctrl = _D.new(); _ctrl.set("db", self)
	add_child(_ctrl); _ctrl.hide()
	set_process(false); set_process_input(false)

# ── Public API ────────────────────────────────────────────────────────────────
func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	if _state != State.CLOSED:   # Already open — ignore completely
		return
	if lines.is_empty():
		if cb.is_valid(): cb.call()
		return
	_lines  = lines.duplicate()
	_page   = 0
	_cb     = cb
	_state  = State.TYPING
	_type_t = 0.0
	_full   = str(_lines[0])
	_shown  = ""
	_ctrl.show()
	set_process(true)
	set_process_input(true)
	_set_player_dialog(true)
	_set_world_dialog(true)

func is_open() -> bool:
	return _state != State.CLOSED

func close() -> void:
	if _state == State.CLOSED: return
	_state = State.CLOSED
	_ctrl.hide()
	set_process(false)
	set_process_input(false)
	_set_player_dialog(false)
	_set_world_dialog(false)
	var cb := _cb; _cb = Callable()
	if cb.is_valid(): cb.call()

# ── Internals ─────────────────────────────────────────────────────────────────
func _set_player_dialog(v: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "dialog_open" in p: p.dialog_open = v

func _set_world_dialog(v: bool) -> void:
	for w in get_tree().get_nodes_in_group("active_world"):
		if w.has_method("set_dialog_open"): w.set_dialog_open(v)

func _process(delta: float) -> void:
	match _state:
		State.TYPING:
			_type_t += delta
			var n := int(_type_t * CPS)
			if n >= _full.length():
				_shown = _full; _state = State.WAITING
			else:
				_shown = _full.substr(0, n)
		State.WAITING:
			_blink_t += delta
			if _blink_t >= 0.46: _blink_t = 0.0; _blink = not _blink
	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED: return
	if event.is_action_pressed("ui_accept"):
		if _state == State.TYPING:
			_shown = _full; _state = State.WAITING
		elif _state == State.WAITING:
			_page += 1
			if _page >= _lines.size():
				close()
			else:
				_full   = str(_lines[_page])
				_shown  = ""
				_type_t = 0.0
				_state  = State.TYPING
		get_viewport().set_input_as_handled()

class _D extends Control:
	var db
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if db == null or db._state == db.State.CLOSED: return
		const W := 480; const H := 320; const BH := 88
		var by := H - BH - 4; var fnt := ThemeDB.fallback_font
		var DK := Color("#181010")
		var wcol := Color("#2060a0")
		if GameManager.active_world == "english": wcol = Color("#c07010")
		elif GameManager.active_world == "music": wcol = Color("#8020c0")
		# Box
		draw_rect(Rect2(4, by, W-8, BH), DK)
		draw_rect(Rect2(5, by+1, W-10, BH-2), Color("#f0f0e0"))
		draw_rect(Rect2(5, by+1, W-10, 14), wcol.lightened(0.35))
		draw_rect(Rect2(5, by+1, W-10, BH-2), wcol*Color(1,1,1,0.18), false, 1.5)
		# Text
		var rows = db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt, Vector2(12, by+10+16+i*16), rows[i],
				HORIZONTAL_ALIGNMENT_LEFT, W-24, 14, DK)
		# Arrow
		if db._state == db.State.WAITING and db._blink:
			draw_string(fnt, Vector2(W-20, by+BH-10), "▼",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffd700"))
		# Page
		if db._lines.size() > 1:
			draw_string(fnt, Vector2(W-52, by+14),
				str(db._page+1)+"/"+str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6,0.6,0.85))
