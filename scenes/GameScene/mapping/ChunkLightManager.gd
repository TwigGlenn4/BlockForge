# ChunkLightManager — soft PointLight2D + wall LOS shader map (invisible occlusion).
# No LOS cookies. No visible ambient cover.
# TODO: day/night; lava emissive; flicker.
class_name ChunkLightManager
extends Node

const ITEM_LANTERN_DEFAULT := 1
const WALL_LOS_SHADER := "res://scenes/GameScene/mapping/wall_los.gdshader"

@export var lights_root_path: NodePath = ^"../LightsRoot"
@export var decorations_root_path: NodePath = ^"../DecorationsMaps"
@export var chunk_manager_path: NodePath = ^"../ChunkManager"
@export var canvas_modulate_path: NodePath = ^"../WorldCanvasModulate"
@export var populator_path: NodePath = ^"../TileMapPopulator"

@onready var lights_root: Node2D = get_node_or_null(lights_root_path)
@onready var decorations_root: Node2D = get_node_or_null(decorations_root_path)
@onready var chunk_manager: ChunkManager = get_node_or_null(chunk_manager_path)
@onready var canvas_modulate: CanvasModulate = get_node_or_null(canvas_modulate_path)
@onready var populator: TileMapPopulator = get_node_or_null(populator_path)

var _chunk_roots: Dictionary = {} # Vector2i -> Node2D
var _sprite_cache: Dictionary = {} # path -> Texture2D
var _los_textures: Dictionary = {} # Vector2i -> ImageTexture
static var _soft_tex: Texture2D


func _ready() -> void:
	if lights_root == null:
		lights_root = get_node_or_null("../LightsRoot")
	if decorations_root == null:
		decorations_root = get_node_or_null("../DecorationsMaps")
	if chunk_manager == null:
		chunk_manager = get_node_or_null("../ChunkManager") as ChunkManager
	if canvas_modulate == null:
		canvas_modulate = get_node_or_null("../WorldCanvasModulate") as CanvasModulate
	if populator == null:
		populator = get_node_or_null("../TileMapPopulator") as TileMapPopulator
	LightingConfig.reload()
	if canvas_modulate:
		canvas_modulate.color = LightingConfig.ambient_modulate()


static func lantern_item_id() -> int:
	return LightingConfig.source_item_id("lantern", ITEM_LANTERN_DEFAULT)


func sync_chunk(data: ChunkData) -> void:
	if data == null or lights_root == null:
		return
	var key := Vector2i(data.chunk_x, data.chunk_y)
	var root: Node2D = _ensure_chunk_root(key, data)
	while root.get_child_count() > 0:
		var c: Node = root.get_child(0)
		root.remove_child(c)
		c.free()
	_clear_lantern_sprites(key)

	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var cells: PackedInt64Array = data.cells
	var lantern_id: int = lantern_item_id()

	var energy: float = LightingConfig.source_energy("lantern", 3.0)
	var radius_px: float = LightingConfig.source_radius_px("lantern", 360.0)
	var color: Color = LightingConfig.source_color("lantern", Color(1.0, 0.72, 0.35, 1.0))
	var sprite_path: String = LightingConfig.source_sprite("lantern")
	var wall_mask: int = LightingConfig.source_item_cull_mask("lantern", LightingConfig.mask_walls())
	var radius_tiles: int = maxi(1, int(ceil(radius_px / float(ts))))

	var local_lanterns: Array[Vector2i] = []
	for i in cells.size():
		if ChunkData.unpack_item(cells[i]) != lantern_id:
			continue
		var lx: int = i % cs
		var ly: int = int(i / cs)
		var gx: int = data.chunk_x * cs + lx
		var gy: int = data.chunk_y * cs + ly
		local_lanterns.append(Vector2i(gx, gy))
		_add_soft_point_light(root, gx, gy, ts, cs, color, energy, radius_px, wall_mask)
		_add_lantern_sprite(key, data, lx, ly, ts, sprite_path)

	var all_lanterns: Array[Vector2i] = local_lanterns.duplicate()
	_collect_nearby_lanterns(data.chunk_x, data.chunk_y, radius_tiles, lantern_id, all_lanterns)
	_apply_wall_los_map(key, data, all_lanterns, radius_tiles)


func drop_chunk(cx: int, cy: int) -> void:
	var key := Vector2i(cx, cy)
	_clear_lantern_sprites(key)
	_los_textures.erase(key)
	if not _chunk_roots.has(key):
		return
	var root: Node2D = _chunk_roots[key]
	_chunk_roots.erase(key)
	if is_instance_valid(root):
		root.queue_free()


func drop_all() -> void:
	for k in _chunk_roots.keys():
		drop_chunk(k.x, k.y)


func align_to_camera(camera_px: float) -> void:
	var w: int = WorldConfig.world_chunks_wide_max()
	var cs: int = WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var period: float = float(w * cs * ts)
	if period <= 0.0:
		return
	for key in _chunk_roots.keys():
		var k: Vector2i = key
		var root: Node2D = _chunk_roots[k]
		if not is_instance_valid(root):
			continue
		var base_x: float = float(k.x * cs * ts)
		var k_period: float = round((camera_px - base_x) / period)
		root.position.x = base_x + k_period * period


func sync_global_cell(gx: int, gy: int) -> void:
	if chunk_manager == null:
		return
	var ts: int = WorldConfig.tile_size_px()
	var radius_tiles: int = maxi(1, int(ceil(LightingConfig.source_radius_px("lantern", 360.0) / float(ts))))
	var wx: int = Helpers.wrap_block_x(gx)
	var affected: Dictionary = {}
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dy in range(-radius_tiles, radius_tiles + 1):
			affected[chunk_manager.global_to_chunk(wx + dx, gy + dy)] = true
	for k in affected.keys():
		var data: ChunkData = chunk_manager.get_chunk(k.x, k.y)
		if data and _chunk_roots.has(k):
			sync_chunk(data)


func _ensure_chunk_root(key: Vector2i, data: ChunkData) -> Node2D:
	if _chunk_roots.has(key):
		var existing: Node2D = _chunk_roots[key]
		if is_instance_valid(existing):
			return existing
	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var root := Node2D.new()
	root.name = "Lights_%d_%d" % [data.chunk_x, data.chunk_y]
	root.position = Vector2(data.chunk_x * cs * ts, -(data.chunk_y + 1) * cs * ts)
	lights_root.add_child(root)
	_chunk_roots[key] = root
	return root


func _collect_nearby_lanterns(
	cx: int, cy: int, radius_tiles: int, lantern_id: int, out: Array[Vector2i]
) -> void:
	if chunk_manager == null:
		return
	var cs: int = WorldConfig.chunk_size()
	var chunk_r: int = int(ceil(float(radius_tiles) / float(cs))) + 1
	var seen: Dictionary = {}
	for p in out:
		seen[p] = true
	for dcx in range(-chunk_r, chunk_r + 1):
		for dcy in range(-chunk_r, chunk_r + 1):
			if dcx == 0 and dcy == 0:
				continue
			var ncx: int = chunk_manager.wrap_column(cx + dcx)
			var ncy: int = cy + dcy
			var ndata: ChunkData = chunk_manager.get_chunk(ncx, ncy)
			if ndata == null:
				continue
			var ncs: int = ndata.size
			var cells: PackedInt64Array = ndata.cells
			for i in cells.size():
				if ChunkData.unpack_item(cells[i]) != lantern_id:
					continue
				var lx: int = i % ncs
				var ly: int = int(i / ncs)
				var p := Vector2i(ncx * ncs + lx, ncy * ncs + ly)
				if not seen.has(p):
					seen[p] = true
					out.append(p)


func _add_soft_point_light(
	root: Node2D, gx: int, gy: int, ts: int, cs: int,
	color: Color, energy: float, radius_px: float, wall_mask: int
) -> void:
	var light := PointLight2D.new()
	light.name = "L_%d_%d" % [gx, gy]
	light.color = color
	light.energy = energy
	light.texture = _soft_light_texture()
	light.texture_scale = (radius_px * 2.0) / 64.0
	light.range_item_cull_mask = wall_mask
	light.shadow_enabled = false
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var wx: int = Helpers.wrap_block_x(gx)
	var lx: int = posmod(wx, cs)
	var ly: int = posmod(gy, cs)
	light.position = Vector2(
		float(lx * ts) + float(ts) * 0.5,
		float((cs - 1 - ly) * ts) + float(ts) * 0.5
	)
	root.add_child(light)


func _apply_wall_los_map(
	key: Vector2i, data: ChunkData, lanterns: Array[Vector2i], radius_tiles: int
) -> void:
	if populator == null or not populator.has_method("set_wall_los_texture"):
		return
	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var img: Image = WallLosLight.build_los_image(chunk_manager, data, lanterns, radius_tiles)
	var tex: ImageTexture
	if _los_textures.has(key):
		tex = _los_textures[key]
		tex.set_image(img)
	else:
		tex = ImageTexture.create_from_image(img)
		_los_textures[key] = tex
	populator.set_wall_los_texture(key.x, key.y, tex, ts, cs)


func _deco_layer_for(key: Vector2i) -> TileMapLayer:
	if populator and populator.has_method("get_deco_layer"):
		return populator.get_deco_layer(key.x, key.y)
	if decorations_root == null:
		return null
	return decorations_root.get_node_or_null("Deco_%d_%d" % [key.x, key.y]) as TileMapLayer


func _clear_lantern_sprites(key: Vector2i) -> void:
	var deco: TileMapLayer = _deco_layer_for(key)
	if deco == null:
		return
	var holder: Node = deco.get_node_or_null("LanternSprites")
	if holder == null or not is_instance_valid(holder):
		return
	# Must free immediately — queue_free leaves the node in-tree until end of frame,
	# so _add_lantern_sprite would parent new sprites onto a dying holder (flicker/vanish).
	deco.remove_child(holder)
	holder.free()


func _add_lantern_sprite(
	key: Vector2i, data: ChunkData, lx: int, ly: int, ts: int, sprite_path: String
) -> void:
	if sprite_path.is_empty():
		return
	var deco: TileMapLayer = _deco_layer_for(key)
	if deco == null:
		return
	var holder: Node2D = deco.get_node_or_null("LanternSprites") as Node2D
	if holder != null and (not is_instance_valid(holder) or holder.is_queued_for_deletion()):
		holder = null
	if holder == null:
		holder = Node2D.new()
		holder.name = "LanternSprites"
		deco.add_child(holder)
	var spr := Sprite2D.new()
	spr.name = "Lantern_%d_%d" % [lx, ly]
	spr.texture = _load_sprite(sprite_path)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	spr.position = Vector2(
		float(lx * ts) + float(ts) * 0.5,
		float((cs - 1 - ly) * ts) + float(ts) * 0.5
	)
	holder.add_child(spr)


func _load_sprite(path: String) -> Texture2D:
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.8, 0.3, 1.0))
		tex = ImageTexture.create_from_image(img)
	_sprite_cache[path] = tex
	return tex


static func _soft_light_texture() -> Texture2D:
	if _soft_tex != null:
		return _soft_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mid := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var dx: float = (float(x) - mid) / mid
			var dy: float = (float(y) - mid) / mid
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex
