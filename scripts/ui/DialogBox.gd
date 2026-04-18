# DialogBox.gd — Authentic Gen 1/2 Pokémon-style dialog box
# Double-line border, corner ornaments, white interior, pixel typewriter text
extends CanvasLayer

const CPS := 38.0   # chars per second

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
	_ctrl = _Drawer.new(); _ctrl.set("db", self)
	add_child(_ctrl); _ctrl.hide()
	set_process(false); set_process_input(false)

func show_lines(lines: Array, cb: Callable = Callable()) -> void:
	if _state != State.CLOSED: return
	if lines.is_empty(): if cb.is_valid(): cb.call(); return
	_lines=lines.duplicate(); _page=0; _cb=cb
	_state=State.TYPING; _type_t=0.0; _full=str(_lines[0]); _shown=""
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
			if n >= _full.length(): _shown=_full; _state=State.WAITING
			else: _shown=_full.substr(0,n)
		State.WAITING:
			_blink_t+=delta; if _blink_t>=0.5: _blink_t=0.0; _blink=not _blink
	_ctrl.queue_redraw()

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED: return
	if event.is_action_pressed("ui_accept"):
		if _state == State.TYPING:
			_shown=_full; _state=State.WAITING
		elif _state == State.WAITING:
			_page+=1
			if _page >= _lines.size(): close()
			else: _full=str(_lines[_page]); _shown=""; _type_t=0.0; _state=State.TYPING
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
#  Gen 1/2 Pokémon dialog box renderer
# ══════════════════════════════════════════════════════════════════════════════
class _Drawer extends Control:
	var db
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if db == null or db._state == db.State.CLOSED: return
		const W := 480; const H := 320; const BH := 80
		var by  := H - BH - 2
		var fnt := ThemeDB.fallback_font

		# ── Authentic Gen 1/2 dialog box ──────────────────────────────────
		# Layer 1: outer black border
		draw_rect(Rect2(2, by, W-4, BH), Color("#181010"))
		# Layer 2: white fill
		draw_rect(Rect2(4, by+2, W-8, BH-4), Color("#f8f8f0"))
		# Layer 3: inner black border (double-border effect)
		draw_rect(Rect2(4, by+2, W-8, BH-4), Color("#181010"), false, 2.0)
		# Layer 4: inner white line (creates gap between borders)
		draw_rect(Rect2(8, by+6, W-16, BH-12), Color("#f8f8f0"))
		draw_rect(Rect2(8, by+6, W-16, BH-12), Color("#181010"), false, 2.0)

		# ── Corner ornaments (the red/dark dots in Gen 1) ──────────────────
		_draw_corner(by, W, BH)

		# ── Text ──────────────────────────────────────────────────────────
		# Gen 1 uses monospace-style uppercase text
		var rows = db._shown.split("\n")
		for i in rows.size():
			draw_string(fnt, Vector2(18, by+22+i*18), rows[i].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, W-36, 14, Color("#181010"))

		# ── Continue arrow (▼ blinking) ───────────────────────────────────
		if db._state == db.State.WAITING and db._blink:
			# Pokémon-style down triangle arrow
			draw_colored_polygon(
	PackedVector2Array([
		Vector2(W-20, by+BH-14),
		Vector2(W-10, by+BH-14),
		Vector2(W-15, by+BH-8)
	]),
	Color("#181010")
)

		# ── Page counter ──────────────────────────────────────────────────
		if db._lines.size() > 1:
			draw_string(fnt, Vector2(W-50, by+10),
				str(db._page+1)+"/"+str(db._lines.size()),
				HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#606060"))

	func _draw_corner(by:int, W:int, BH:int) -> void:
		# Gen 1-style corner dots at all 4 corners of outer border
		var corners := [
			Vector2(2, by),         Vector2(W-10, by),
			Vector2(2, by+BH-8),    Vector2(W-10, by+BH-8)
		]
		for c in corners:
			# Dark square 8x8
			draw_rect(Rect2(c.x, c.y, 8, 8), Color("#181010"))
			# Red/accent 4x4 inside
			draw_rect(Rect2(c.x+2, c.y+2, 4, 4), Color("#c81818"))
