# DialogBox.gd — Context-aware Gen 1/2 style dialog
# WORLD mode:  full bottom bar (80px tall) — classic Pokémon style
# BATTLE mode: compact top banner (48px) — doesn't cover battle screen
extends CanvasLayer

const CPS := 40.0

enum State { CLOSED, TYPING, WAITING }
var _state:   int      = State.CLOSED
var _lines:   Array    = []
var _page:    int      = 0
var _full:    String   = ""
var _shown:   String   = ""
var _type_t:  float    = 0.0
var _blink_t: float    = 0.0
var _blink:   bool     = true
var _cb:      Callable = Callable()
var _ctrl:    Control

# Context: "world" = bottom bar (80px), "battle" = top compact banner (48px)
# Set this BEFORE calling show_lines()
var context:  String = "world"

func _ready() -> void:
	layer = 10
	_ctrl = _D.new(); _ctrl.set("db", self)
	add_child(_ctrl); _ctrl.hide()
	set_process(false); set_process_input(false)

func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	if _state != State.CLOSED: return
	if lines.is_empty(): if cb.is_valid(): cb.call(); return
	_lines = lines.duplicate(); _page = 0; _cb = cb
	_state = State.TYPING; _type_t = 0.0
	_full = str(_lines[0]); _shown = ""
	_ctrl.show(); set_process(true); set_process_input(true)
	_notify(true)

func is_open() -> bool: return _state != State.CLOSED

func close() -> void:
	if _state == State.CLOSED: return
	_state = State.CLOSED; _ctrl.hide()
	set_process(false); set_process_input(false)
	_notify(false)
	var cb := _cb; _cb = Callable()
	if cb.is_valid(): cb.call()

func _notify(v: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "dialog_open" in p: p.dialog_open = v
	for w in get_tree().get_nodes_in_group("active_world"):
		if w.has_method("set_dialog_open"): w.set_dialog_open(v)

func _process(delta: float) -> void:
	match _state:
		State.TYPING:
			_type_t += delta
			var n := int(_type_t * CPS)
			if n >= _full.length(): _shown = _full; _state = State.WAITING
			else: _shown = _full.substr(0, n)
		State.WAITING:
			_blink_t += delta
			if _blink_t >= 0.5: _blink_t = 0.0; _blink = not _blink
	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED: return
	if event.is_action_pressed("ui_accept"):
		if _state == State.TYPING:
			_shown = _full; _state = State.WAITING
		elif _state == State.WAITING:
			_page += 1
			if _page >= _lines.size(): close()
			else:
				_full = str(_lines[_page]); _shown = ""
				_type_t = 0.0; _state = State.TYPING
		get_viewport().set_input_as_handled()

# ── Draw ──────────────────────────────────────────────────────────────────────
class _D extends Control:
	var db
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if db == null or db._state == db.State.CLOSED: return
		var fnt := ThemeDB.fallback_font
		if db.context == "battle":
			_draw_battle(fnt)
		else:
			_draw_world(fnt)

	# ── World mode: full bottom bar ────────────────────────────────────────
	func _draw_world(fnt: Font) -> void:
		const W := 480; const H := 320; const BH := 80
		var by := H - BH - 2
		# Double border
		draw_rect(Rect2(2, by, W-4, BH), Color("#181010"))
		draw_rect(Rect2(4, by+2, W-8, BH-4), Color("#f8f8f0"))
		draw_rect(Rect2(4, by+2, W-8, BH-4), Color("#181010"), false, 2.0)
		draw_rect(Rect2(8, by+6, W-16, BH-12), Color("#f8f8f0"))
		draw_rect(Rect2(8, by+6, W-16, BH-12), Color("#181010"), false, 1.5)
		# Corner ornaments
		for cv in [Vector2(2,by), Vector2(W-10,by), Vector2(2,by+BH-8), Vector2(W-10,by+BH-8)]:
			draw_rect(Rect2(cv.x, cv.y, 8, 8), Color("#181010"))
			draw_rect(Rect2(cv.x+2, cv.y+2, 4, 4), Color("#c81818"))
		# Text
		var rows = db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt, Vector2(18, by+22+i*18), rows[i].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, W-36, 13, Color("#181010"))
		# Arrow
		if db._state == db.State.WAITING and db._blink:
			draw_colored_polygon(
	PackedVector2Array([
		Vector2(W-20, by+BH-14),
		Vector2(W-10, by+BH-14),
		Vector2(W-15, by+BH-8)
	]),
	Color("#181010")
)
		# Page counter
		if db._lines.size() > 1:
			draw_string(fnt, Vector2(W-52, by+10), str(db._page+1)+"/"+str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT,-1,9, Color("#606060"))

	# ── Battle mode: compact top banner (doesn't cover battle area) ────────
	func _draw_battle(fnt: Font) -> void:
		const W := 480; const H := 320; const BH := 44
		const BY := 2   # anchored to TOP — below HUD, above all battle content
		# Semi-transparent dark panel
		draw_rect(Rect2(2, BY, W-4, BH), Color("#181010"))
		draw_rect(Rect2(4, BY+2, W-8, BH-4), Color("#f0f0e8", 0.97))
		draw_rect(Rect2(4, BY+2, W-8, BH-4), Color("#181010"), false, 1.5)
		# Blue header stripe (indicates important message)
		draw_rect(Rect2(4, BY+2, W-8, 10), Color("#2050a0", 0.25))
		# Text (2 lines max in compact mode)
		var rows = db._shown.split("\n")
		for i in min(rows.size(), 2):
			draw_string(fnt, Vector2(14, BY+16+i*16), rows[i].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, W-56, 12, Color("#181010"))
		# Continue indicator (right side)
		if db._state == db.State.WAITING and db._blink:
			draw_string(fnt, Vector2(W-22, BY+BH-6), "▶",
				HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#181010"))
		# Page badge
		if db._lines.size() > 1:
			var pg := str(db._page+1)+"/"+str(db._lines.size())
			draw_rect(Rect2(W-46, BY+2, 42, 12), Color("#181010", 0.5))
			draw_string(fnt, Vector2(W-44, BY+12), pg,
				HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#ffffff"))
