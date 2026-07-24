# Sky above world top, lava below world bottom.
# Tune colors in the inspector (editor-first; no runtime atlas sampling).
class_name WorldBoundsFiller
extends Node2D

@export var sky_color := Color(0.45, 0.7, 0.95, 1.0)
# Approximate average of blockforge:lava atlas tile
@export var lava_color := Color(0.3412, 0.0588, 0.0, 1.0)

var _sky: Polygon2D
var _lava: Polygon2D


func _ready() -> void:
	z_index = -50
	_sky = Polygon2D.new()
	_sky.color = sky_color
	add_child(_sky)
	_lava = Polygon2D.new()
	_lava.color = lava_color
	add_child(_lava)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var center: Vector2 = cam.get_screen_center_position()
	var ts: float = float(WorldConfig.tile_size_px())
	var world_top_px: float = -float(WorldConfig.world_height_tiles()) * ts
	var world_bottom_px: float = 0.0
	var half := view * 0.5
	var left: float = center.x - half.x - ts * 4.0
	var right: float = center.x + half.x + ts * 4.0
	var cam_top: float = center.y - half.y
	var cam_bot: float = center.y + half.y

	if cam_top < world_top_px:
		var y1: float = cam_top - ts
		var y2: float = minf(world_top_px, cam_bot)
		_sky.polygon = PackedVector2Array([
			Vector2(left, y1), Vector2(right, y1), Vector2(right, y2), Vector2(left, y2)
		])
		_sky.visible = true
	else:
		_sky.visible = false

	if cam_bot > world_bottom_px:
		var y1: float = maxf(world_bottom_px, cam_top)
		var y2: float = cam_bot + ts
		_lava.polygon = PackedVector2Array([
			Vector2(left, y1), Vector2(right, y1), Vector2(right, y2), Vector2(left, y2)
		])
		_lava.visible = true
	else:
		_lava.visible = false
