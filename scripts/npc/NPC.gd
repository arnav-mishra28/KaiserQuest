# NPC.gd — Area2D NPC base — teachers, quest givers, duel challengers
extends Area2D

signal talk_to(npc:Dictionary)

const TILE_SIZE := 32

# NPC data (set by World when spawning)
var data: Dictionary = {}

var _time: float = 0.0

func _ready()->void:
	# Face south by default
	queue_redraw()
	set_process(true)
	if data.get("wander", false):
		_start_wander()

func setup(npc_data:Dictionary)->void:
	data = npc_data
	var gp:Vector2i = data.get("pos", Vector2i(0,0))
	position = Vector2(gp.x*TILE_SIZE + TILE_SIZE/2,
					   gp.y*TILE_SIZE + TILE_SIZE/2)
	z_index  = gp.y
	queue_redraw()

func _process(delta:float)->void:
	_time += delta
	queue_redraw()

func activate()->void:
	talk_to.emit(data)

func _start_wander()->void:
	pass  # future: random movement

# ═══════════════════════════════════════════════════════════════════════════════
#  PIXEL ART NPC DRAWING
# ═══════════════════════════════════════════════════════════════════════════════
func _draw()->void:
	var typ     = data.get("type","normal")
	var shirt   = data.get("shirt", Color("#e8c030"))
	var has_new := _has_new_content()
	_draw_npc_body(-TILE_SIZE/2, -TILE_SIZE/2, shirt)
	_draw_icon(typ, has_new)

func _has_new_content()->bool:
	match data.get("type","normal"):
		"teacher":
			return not GameManager.learned_from(data.get("id",""))
		"quest_giver":
			return not GameManager.quest_done(data.get("quest_id",""))
		"duel":
			return true
	return false

func _draw_icon(typ:String, has_new:bool)->void:
	if not has_new and typ != "duel": return
	var fnt := ThemeDB.fallback_font
	var ox  := -TILE_SIZE/2
	var oy  := -TILE_SIZE/2
	var bob := int(sin(_time*4.0)*2)

	match typ:
		"teacher":
			var ic := Color("#ffd700") if has_new else Color("#888888")
			draw_rect(Rect2(ox+11,oy-13+bob,10,10), Color("#181010"))
			draw_rect(Rect2(ox+12,oy-12+bob, 8, 8), ic)
			draw_string(fnt,Vector2(ox+14,oy-4+bob),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#181010"))
		"quest_giver":
			draw_rect(Rect2(ox+11,oy-13+bob,10,10), Color("#181010"))
			draw_rect(Rect2(ox+12,oy-12+bob, 8, 8), Color("#ffd700"))
			draw_string(fnt,Vector2(ox+14,oy-4+bob),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#181010"))
		"duel":
			draw_rect(Rect2(ox+11,oy-13+bob,10,10), Color("#181010"))
			draw_rect(Rect2(ox+12,oy-12+bob, 8, 8), Color("#e03010"))
			draw_string(fnt,Vector2(ox+13,oy-4+bob),"⚔",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#ffffff"))

func _draw_npc_body(ox:int, oy:int, shirt:Color)->void:
	var DK   := Color("#181010")
	var SKN  := Color("#f0c890")
	var HAIR := Color("#301808")
	var PNT  := Color("#2040a0")

	# Shadow
	draw_rect(Rect2(ox+6,oy+30,20,5), Color(0,0,0,0.2))
	# Shoes
	draw_rect(Rect2(ox+6,oy+26, 8,5),  DK); draw_rect(Rect2(ox+7,oy+27,6,4),  Color("#282828"))
	draw_rect(Rect2(ox+18,oy+26,8,5),  DK); draw_rect(Rect2(ox+19,oy+27,6,4), Color("#282828"))
	# Pants
	draw_rect(Rect2(ox+7,oy+16,  8,12), PNT); draw_rect(Rect2(ox+7,oy+16, 8,12),DK,false,1.0)
	draw_rect(Rect2(ox+17,oy+16, 8,12), PNT); draw_rect(Rect2(ox+17,oy+16,8,12),DK,false,1.0)
	draw_rect(Rect2(ox+8,oy+16,  4,12), PNT.lightened(0.12))
	# Belt
	draw_rect(Rect2(ox+6,oy+15,20,3),  Color("#503010"))
	draw_rect(Rect2(ox+14,oy+15,4,3),  Color("#d0a018"))
	# Shirt
	draw_rect(Rect2(ox+5,oy+8, 22,9),  shirt)
	draw_rect(Rect2(ox+5,oy+8, 22,3),  shirt.lightened(0.28))
	draw_rect(Rect2(ox+5,oy+13,22,4),  shirt.darkened(0.18))
	draw_rect(Rect2(ox+5,oy+8, 22,9),  DK, false, 1.0)
	# Arms
	draw_rect(Rect2(ox+1,oy+9,  5,10), SKN); draw_rect(Rect2(ox+1,oy+9,5,10),DK,false,1.0)
	draw_rect(Rect2(ox+26,oy+9, 5,10), SKN); draw_rect(Rect2(ox+26,oy+9,5,10),DK,false,1.0)
	# Neck
	draw_rect(Rect2(ox+13,oy+5, 6,5),  SKN)
	# Head
	draw_rect(Rect2(ox+8,oy+0, 16,11), SKN); draw_rect(Rect2(ox+8,oy+0,16,11),DK,false,1.0)
	draw_rect(Rect2(ox+9,oy+0, 14,4),  SKN.lightened(0.2))
	# Hair
	draw_rect(Rect2(ox+8,oy+0, 16,4),  HAIR)
	draw_rect(Rect2(ox+9,oy+0, 12,2),  HAIR.lightened(0.2))
	# Eyes
	draw_rect(Rect2(ox+11,oy+7,3,3),   DK)
	draw_rect(Rect2(ox+18,oy+7,3,3),   DK)
	draw_rect(Rect2(ox+12,oy+7,1,2),   Color(1,1,1,0.65))
	draw_rect(Rect2(ox+19,oy+7,1,2),   Color(1,1,1,0.65))
