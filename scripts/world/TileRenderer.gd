# TileRenderer.gd — Generates pixel-art tiles as ImageTexture at runtime
# No external assets needed — everything generated from color data
extends Node

const TS := 32   # Tile size

# ── Cached textures ───────────────────────────────────────────────────────────
var _cache: Dictionary = {}

static func get_tile(world:String, tile_id:int, c:int, r:int) -> ImageTexture:
	var key := world+"_"+str(tile_id)+"_"+str((c+r)%4)
	if key in _cache: return _cache[key]
	var img := _generate(world, tile_id, c, r)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static var _cache := {}

# ── Palette per world ─────────────────────────────────────────────────────────
static func _pal(world:String)->Dictionary:
	match world:
		"math":    return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),
		                   "g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058"),
		                   "water":Color("#3050b0"),"wall":Color("#c8c8a0"),"roof":Color("#204880")}
		"english": return {"g0":Color("#e8d8a0"),"g1":Color("#d8c890"),"g2":Color("#a87840"),
		                   "g3":Color("#503010"),"path":Color("#f0e090"),"path2":Color("#e0d080"),
		                   "water":Color("#5090c0"),"wall":Color("#f0e8d0"),"roof":Color("#a03818")}
		"music":   return {"g0":Color("#281848"),"g1":Color("#201038"),"g2":Color("#100820"),
		                   "g3":Color("#080410"),"path":Color("#604890"),"path2":Color("#503878"),
		                   "water":Color("#102888"),"wall":Color("#302048"),"roof":Color("#601080")}
	return {"g0":Color("#9bbc0f"),"g1":Color("#8bac0f"),"g2":Color("#306230"),
	        "g3":Color("#0f380f"),"path":Color("#d4c06a"),"path2":Color("#c4b058"),
	        "water":Color("#3050b0"),"wall":Color("#c8c8a0"),"roof":Color("#204880")}

# ── Main tile generator ───────────────────────────────────────────────────────
static func _generate(world:String, tid:int, c:int, r:int)->Image:
	var img := Image.create(TS, TS, false, Image.FORMAT_RGBA8)
	var p   := _pal(world)
	var chk := (c+r)%2==0

	match tid:
		0: _gen_grass(img, p, chk, c, r)
		1: _gen_tree(img, p)
		2: _gen_house_top(img, p)
		3: _gen_house_front(img, p)
		4: _gen_path(img, p, chk, c, r)
		5: _gen_gym_top(img, p, world)
		6: _gen_gym_front(img, p, world)
		7: _gen_water(img, p, c, r)
		8: _gen_sand(img, chk)
		9: _gen_stone(img)
		10: _gen_fence(img, p)
		11: _gen_sign(img, p)
		_: img.fill(Color.MAGENTA)
	return img

# ── GRASS (Gen 2 checkered) ───────────────────────────────────────────────────
static func _gen_grass(img:Image, p:Dictionary, chk:bool, c:int, r:int)->void:
	for y in TS:
		for x in TS:
			var blk := (x/4 + y/4 + c + r) % 2 == 0
			img.set_pixel(x,y, p.g0 if (blk or not chk) else p.g1)
	# Grass blade details
	if (c*7+r*11)%8 == 0:
		for j in range(8,14): img.set_pixel(5, TS-10-j%6, p.g0.lightened(0.3))
		for j in range(6,12): img.set_pixel(13,TS-12-j%6, p.g0.lightened(0.25))
	# Flower
	if (c*11+r*7)%12 == 0:
		var fc := Color("#f880a0") if p.g0.r>0.5 else Color("#f8c030")
		img.set_pixel(14,19,fc); img.set_pixel(15,19,fc)
		img.set_pixel(14,20,fc); img.set_pixel(15,20,fc)

# ── PATH (cobblestone) ────────────────────────────────────────────────────────
static func _gen_path(img:Image, p:Dictionary, chk:bool, c:int, r:int)->void:
	for y in TS:
		for x in TS:
			var blk := (x/4 + y/4 + c + r) % 2 == 0
			img.set_pixel(x,y, p.path if blk else p.path2)
	# Border lines
	for x in TS: img.set_pixel(x,0, p.g2); img.set_pixel(x,TS-1,p.g2)
	for y in TS: img.set_pixel(0,y, p.g2); img.set_pixel(TS-1,y,p.g2)

# ── TREE TOP (rounded crown, Gen 2 style) ─────────────────────────────────────
static func _gen_tree(img:Image, p:Dictionary)->void:
	img.fill(p.g3)
	# Layered oval crown
	_fill_ellipse(img, 16,14, 14,12, p.g2)
	_fill_ellipse(img, 16,11, 12,10, p.g1)
	_fill_ellipse(img, 16,9,  10, 8, p.g0)
	_fill_ellipse(img, 16,7,   7, 6, p.g0.lightened(0.2))
	# Top gleam
	_fill_ellipse(img, 15,5,   4, 3, Color(1,1,1,0.25))
	# Trunk
	for y in range(22,32):
		for x in range(12,20): img.set_pixel(x,y,Color("#6a4010"))
	for y in range(22,32):
		for x in range(13,16): img.set_pixel(x,y,Color("#8a5820"))
	# Outline
	_outline(img, Color("#181010"))

# ── HOUSE TOP FACE (viewed from above) ────────────────────────────────────────
static func _gen_house_top(img:Image, p:Dictionary)->void:
	img.fill(p.roof)
	# Roof ridge line
	for x in TS: img.set_pixel(x,3,p.roof.lightened(0.2))
	for x in TS: img.set_pixel(x,0,p.roof.darkened(0.2))
	# Window on roof visible
	for y in range(8,20):
		for x in range(6,14): img.set_pixel(x,y,p.wall)
	# Window glow
	for y in range(10,18):
		for x in range(7,13): img.set_pixel(x,y,Color("#a8d8ff"))
	_outline(img, Color("#181010"))

# ── HOUSE FRONT FACE (2.5D wall) ─────────────────────────────────────────────
static func _gen_house_front(img:Image, p:Dictionary)->void:
	img.fill(p.wall)
	# Side shadow
	for y in TS:
		for x in range(TS-5,TS): img.set_pixel(x,y,p.wall.darkened(0.2))
	# Window left
	_draw_window(img, 5, 4, 10, 10, p)
	# Window right
	_draw_window(img, 18, 4, 10, 10, p)
	# Door
	for y in range(15,32):
		for x in range(11,21): img.set_pixel(x,y,Color("#6a3810"))
	for y in range(15,32):
		for x in range(12,15): img.set_pixel(x,y,Color("#7a4820"))
	# Doorknob
	img.set_pixel(19,23,Color("#ffd700")); img.set_pixel(20,23,Color("#ffd700"))
	_outline(img, Color("#181010"))

static func _draw_window(img:Image, wx:int, wy:int, ww:int, wh:int, p:Dictionary)->void:
	# Frame
	for y in range(wy,wy+wh):
		for x in range(wx,wx+ww): img.set_pixel(x,y,Color("#181010"))
	# Glass
	for y in range(wy+1,wy+wh-1):
		for x in range(wx+1,wx+ww-1): img.set_pixel(x,y,Color("#88ccff"))
	# Dividers
	for y in range(wy+1,wy+wh-1): img.set_pixel(wx+ww/2,y,Color("#181010"))
	for x in range(wx+1,wx+ww-1): img.set_pixel(x,wy+wh/2,Color("#181010"))
	# Shine
	for y in range(wy+1,wy+wh/2): img.set_pixel(wx+1,y,Color("#c0e8ff"))

# ── GYM TOP ───────────────────────────────────────────────────────────────────
static func _gen_gym_top(img:Image, p:Dictionary, world:String)->void:
	var wc := _gym_col(world)
	img.fill(wc.darkened(0.3))
	# Roof pattern
	for y in range(0,TS,4):
		for x in TS: img.set_pixel(x,y, wc.darkened(0.1))
	# Trim
	for x in TS: img.set_pixel(x,0, wc.lightened(0.2))
	_outline(img, Color("#181010"))

# ── GYM FRONT ────────────────────────────────────────────────────────────────
static func _gen_gym_front(img:Image, p:Dictionary, world:String)->void:
	var wc := _gym_col(world)
	img.fill(wc)
	# Pillar left
	for y in TS:
		for x in range(2,7): img.set_pixel(x,y,wc.darkened(0.2))
	# Pillar right
	for y in TS:
		for x in range(TS-7,TS-2): img.set_pixel(x,y,wc.darkened(0.2))
	# Mid band
	for y in range(12,16):
		for x in TS: img.set_pixel(x,y,wc.lightened(0.2))
	# Door arch
	for y in range(4,TS):
		for x in range(9,23): img.set_pixel(x,y,wc.darkened(0.4))
	# Door glow outline
	for y in range(4,TS):
		img.set_pixel(9,y, wc.lightened(0.4)); img.set_pixel(22,y, wc.lightened(0.4))
	for x in range(9,23): img.set_pixel(x,4,wc.lightened(0.4))
	# Shine
	for y in range(6,TS-2):
		img.set_pixel(10,y,Color(1,1,1,0.2))
	_outline(img, Color("#181010"))

# ── WATER (animated-ish) ──────────────────────────────────────────────────────
static func _gen_water(img:Image, p:Dictionary, c:int, r:int)->void:
	img.fill(p.water)
	# Wave rows
	for x in TS:
		var wy := 4 + (x + c*3 + r*5) % 4
		img.set_pixel(x, wy,    p.water.lightened(0.25))
		img.set_pixel(x, wy+8,  p.water.lightened(0.15))
		img.set_pixel(x, wy+16, p.water.lightened(0.1))
	img.set_pixel((c*7+r*5)%TS, (c*3+r*7)%TS, Color(1,1,1,0.4))

# ── SAND ──────────────────────────────────────────────────────────────────────
static func _gen_sand(img:Image, chk:bool)->void:
	var c1 := Color("#e8d880"); var c2 := Color("#d8c870")
	img.fill(c1 if chk else c2)

# ── STONE ─────────────────────────────────────────────────────────────────────
static func _gen_stone(img:Image)->void:
	img.fill(Color("#706868"))
	for y in range(1,15):
		for x in range(1,15): img.set_pixel(x,y,Color("#808080"))
	for y in range(1,15):
		for x in range(17,31): img.set_pixel(x,y,Color("#808080"))
	for y in range(17,31):
		for x in range(9,23): img.set_pixel(x,y,Color("#808080"))
	_outline(img, Color("#181010"))

# ── FENCE ────────────────────────────────────────────────────────────────────
static func _gen_fence(img:Image, p:Dictionary)->void:
	img.fill(Color(0,0,0,0))  # transparent
	for y in range(6,TS+8):
		for x in range(3,7): img.set_pixel(clampi(x,0,31), clampi(y,0,31), Color("#c89040"))
		for x in range(25,29): img.set_pixel(clampi(x,0,31), clampi(y,0,31), Color("#c89040"))
	for y in range(8,12):
		for x in range(3,29): img.set_pixel(clampi(x,0,31), clampi(y,0,31), Color("#c89040"))
	for y in range(18,22):
		for x in range(3,29): img.set_pixel(clampi(x,0,31), clampi(y,0,31), Color("#c89040"))

# ── SIGN ─────────────────────────────────────────────────────────────────────
static func _gen_sign(img:Image, p:Dictionary)->void:
	img.fill(Color(0,0,0,0))
	for y in range(14,TS):
		for x in range(13,19): img.set_pixel(x,y,Color("#8a5020"))
	for y in range(6,16):
		for x in range(4,28): img.set_pixel(x,y,Color("#c07830"))
	for y in range(6,16):
		img.set_pixel(4,y,Color("#181010")); img.set_pixel(27,y,Color("#181010"))
	for x in range(4,28):
		img.set_pixel(x,6,Color("#181010")); img.set_pixel(x,15,Color("#181010"))

# ── Helpers ───────────────────────────────────────────────────────────────────
static func _fill_ellipse(img:Image, cx:int, cy:int, rx:int, ry:int, col:Color)->void:
	for y in range(max(0,cy-ry), min(TS,cy+ry+1)):
		for x in range(max(0,cx-rx), min(TS,cx+rx+1)):
			var nx := float(x-cx)/rx; var ny := float(y-cy)/ry
			if nx*nx + ny*ny <= 1.0: img.set_pixel(x,y,col)

static func _outline(img:Image, col:Color)->void:
	# Simple 1px border
	for x in TS: img.set_pixel(x,0,col); img.set_pixel(x,TS-1,col)
	for y in TS: img.set_pixel(0,y,col); img.set_pixel(TS-1,y,col)

static func _gym_col(world:String)->Color:
	match world:
		"math":    return Color("#1848c8")
		"english": return Color("#c06818")
		"music":   return Color("#8028b8")
	return Color("#1848c8")
