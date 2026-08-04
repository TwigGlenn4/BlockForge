# TileMapPopulator — chunk PackedInt64Array → TileMapLayer nodes (FG / BG walls / Decorations).
# Uses editor TileSet at res://assets/textures/main_tileset.tres (do not build atlases at runtime).
# Streaming creates per-chunk layers under BackgroundMaps, ChunkMaps (FG), DecorationsMaps.
class_name TileMapPopulator
extends Node

const TILESET_PATH := "res://assets/textures/main_tileset.tres"
## Temporary darken for walls until dedicated wall atlas variants exist.
const WALL_MODULATE := Color(0.70, 0.70, 0.70, 1.0)

@export var background_root_path: NodePath = ^"../BackgroundMaps"
@export var maps_root_path: NodePath = ^"../ChunkMaps"
@export var decorations_root_path: NodePath = ^"../DecorationsMaps"
@export var chunk_manager_path: NodePath = ^"../ChunkManager"

@onready var background_root: Node2D = get_node_or_null(background_root_path)
@onready var maps_root: Node2D = get_node_or_null(maps_root_path)
@onready var decorations_root: Node2D = get_node_or_null(decorations_root_path)
@onready var chunk_manager: ChunkManager = get_node_or_null(chunk_manager_path)

var _tileset: TileSet
var _fg_layers: Dictionary = {} # Vector2i -> TileMapLayer
var _bg_layers: Dictionary = {} # Vector2i -> TileMapLayer
var _deco_layers: Dictionary = {} # Vector2i -> TileMapLayer (empty for now)

# Log batching (group consecutive cy per column)
var _batching := false
var _batch_pop_keys: Array[Vector2i] = []
var _batch_pop_ms: int = 0
var _batch_drop_keys: Array[Vector2i] = []
var _batch_drop_ms: int = 0


func _ready() -> void:
	if background_root == null:
		background_root = get_node_or_null("../BackgroundMaps")
	if maps_root == null:
		maps_root = get_node_or_null("../ChunkMaps")
	if decorations_root == null:
		decorations_root = get_node_or_null("../DecorationsMaps")
	if chunk_manager == null:
		chunk_manager = get_node_or_null("../ChunkManager") as ChunkManager
	_tileset = load(TILESET_PATH) as TileSet
	if _tileset == null:
		push_error("[TileMapPopulator] Missing TileSet at %s (create in editor)" % TILESET_PATH)


func has_layer(cx: int, cy: int) -> bool:
	return _fg_layers.has(Vector2i(cx, cy))


func active_layer_count() -> int:
	return _fg_layers.size()


func begin_log_batch() -> void:
	_flush_log_batch() # safety if nested/forgotten end
	_batching = true
	_batch_pop_keys.clear()
	_batch_pop_ms = 0
	_batch_drop_keys.clear()
	_batch_drop_ms = 0


func end_log_batch() -> void:
	_flush_log_batch()
	_batching = false


func populate(data: ChunkData) -> TileMapLayer:
	var t0 := Time.get_ticks_msec()
	var layer := _populate_internal(data)
	var elapsed: int = Time.get_ticks_msec() - t0
	var key := Vector2i(data.chunk_x, data.chunk_y)
	if _batching:
		_batch_pop_keys.append(key)
		_batch_pop_ms += elapsed
	else:
		WorldConfig.logv("[TileMap] Populated chunk %s in %d ms" % [_format_key_ranges([key]), elapsed])
	return layer


func drop_layer(cx: int, cy: int) -> void:
	var t0 := Time.get_ticks_msec()
	var key := Vector2i(cx, cy)
	_free_layer_dict(_fg_layers, key)
	_free_layer_dict(_bg_layers, key)
	_free_layer_dict(_deco_layers, key)
	var elapsed: int = Time.get_ticks_msec() - t0
	if _batching:
		_batch_drop_keys.append(key)
		_batch_drop_ms += elapsed
	else:
		WorldConfig.logv("[TileMap] Dropped chunk %s in %d ms" % [_format_key_ranges([key]), elapsed])


func drop_all() -> void:
	begin_log_batch()
	for k in _fg_layers.keys():
		drop_layer(k.x, k.y)
	end_log_batch()


# Place each column's TileMaps at the cylinder image nearest the camera (seamless seam).
func align_layers_to_camera(camera_px: float) -> void:
	var w: int = WorldConfig.world_chunks_wide_max()
	var cs: int = WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var period: float = float(w * cs * ts)
	if period <= 0.0:
		return
	_align_dict(_bg_layers, camera_px, period, cs, ts)
	_align_dict(_fg_layers, camera_px, period, cs, ts)
	_align_dict(_deco_layers, camera_px, period, cs, ts)


func _align_dict(layers: Dictionary, camera_px: float, period: float, cs: int, ts: int) -> void:
	for key in layers.keys():
		var k: Vector2i = key
		var layer: TileMapLayer = layers[k]
		if not is_instance_valid(layer):
			continue
		var base_x: float = float(k.x * cs * ts)
		var k_period: float = round((camera_px - base_x) / period)
		layer.position.x = base_x + k_period * period


func _populate_internal(data: ChunkData) -> TileMapLayer:
	var key := Vector2i(data.chunk_x, data.chunk_y)
	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	var fg: TileMapLayer = _ensure_layer(_fg_layers, maps_root, key, data, "Chunk", cs, ts, Color.WHITE)
	var bg: TileMapLayer = _ensure_layer(
		_bg_layers, background_root, key, data, "Wall", cs, ts, WALL_MODULATE
	)
	# Decorations: create empty layer for streaming parity (no cells yet).
	var _deco: TileMapLayer = _ensure_layer(
		_deco_layers, decorations_root, key, data, "Deco", cs, ts, Color.WHITE
	)

	_sync_debug_outline(fg, cs, ts)

	var atlas_by_id: Array = TileIdRegistry.atlas_by_id_array()
	var cells: PackedInt64Array = data.cells
	var n: int = cells.size()
	for i in n:
		var packed: int = cells[i]
		var terrain_id: int = ChunkData.unpack_terrain(packed)
		var wall_id: int = ChunkData.unpack_data(packed)
		var lx: int = i % cs
		var ly: int = int(i / cs)
		# Backfill wall for older saves / missing wall bits — prefer band base.
		if wall_id <= 0 and terrain_id > 0:
			var gx: int = data.chunk_x * cs + lx
			var gy: int = data.chunk_y * cs + ly
			if chunk_manager:
				wall_id = WallTiles.wall_id_at(gx, gy, chunk_manager)
			if wall_id <= 0:
				wall_id = WallTiles.wall_id_for(terrain_id)
		var cell := Vector2i(lx, cs - 1 - ly)
		_set_layer_cell_cached(fg, cell, terrain_id, atlas_by_id)
		_set_layer_cell_cached(bg, cell, wall_id, atlas_by_id)
	return fg


func _ensure_layer(
	dict: Dictionary, root: Node2D, key: Vector2i, data: ChunkData,
	prefix: String, cs: int, ts: int, modulate: Color
) -> TileMapLayer:
	var layer: TileMapLayer
	if dict.has(key):
		layer = dict[key]
		layer.clear()
	else:
		layer = TileMapLayer.new()
		layer.name = "%s_%d_%d" % [prefix, data.chunk_x, data.chunk_y]
		layer.tile_set = _tileset
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.modulate = modulate
		# Align with Helpers.pos_block_to_pixel; X may shift via align_layers_to_camera.
		layer.position = Vector2(data.chunk_x * cs * ts, -(data.chunk_y + 1) * cs * ts)
		if root:
			root.add_child(layer)
		dict[key] = layer
	return layer


## Skip air/empty writes after clear(); only paint solid cells.
func _set_layer_cell_cached(
	layer: TileMapLayer, cell: Vector2i, terrain_id: int, atlas_by_id: Array
) -> void:
	if terrain_id <= 0:
		return
	if terrain_id >= atlas_by_id.size():
		return
	var info: Variant = atlas_by_id[terrain_id]
	if info == null:
		return
	var d: Dictionary = info
	if d.is_empty():
		return
	layer.set_cell(cell, int(d["atlas"]), d["pos"])


func _set_layer_cell(layer: TileMapLayer, cell: Vector2i, terrain_id: int) -> void:
	if terrain_id <= 0:
		layer.set_cell(cell)
		return
	var info: Dictionary = TileIdRegistry.atlas_for_id(terrain_id)
	if info.is_empty():
		layer.set_cell(cell)
		return
	layer.set_cell(cell, int(info["atlas"]), info["pos"])


func _free_layer_dict(dict: Dictionary, key: Vector2i) -> void:
	if not dict.has(key):
		return
	var layer: TileMapLayer = dict[key]
	dict.erase(key)
	if is_instance_valid(layer):
		layer.queue_free()


## Update FG only when mining/placing. Background walls are never overwritten by place.
func set_global_cell(gx: int, gy: int, terrain_id: int) -> void:
	var cs: int = WorldConfig.chunk_size()
	var wx: int = Helpers.wrap_block_x(gx)
	var cx: int = posmod(int(floor(float(wx) / float(cs))), WorldConfig.world_chunks_wide_max())
	var cy: int = int(floor(float(gy) / float(cs)))
	var key := Vector2i(cx, cy)
	if not _fg_layers.has(key):
		return
	var lx: int = posmod(wx, cs)
	var ly: int = posmod(gy, cs)
	var cell := Vector2i(lx, cs - 1 - ly)
	var fg: TileMapLayer = _fg_layers[key]
	if is_instance_valid(fg):
		_set_layer_cell(fg, cell, terrain_id)


func _sync_debug_outline(layer: TileMapLayer, cs: int, ts: int) -> void:
	var want: bool = WorldConfig.debug_grid()
	var existing: Node = layer.get_node_or_null("DebugChunkOutline")
	if want and existing == null:
		_add_debug_outline(layer, cs, ts)
	elif not want and existing != null:
		existing.queue_free()


# ===== DEBUG
func _add_debug_outline(layer: TileMapLayer, cs: int, ts: int) -> void:
	var s: float = float(cs * ts)
	var inset := 1.0
	var line := Line2D.new()
	line.name = "DebugChunkOutline"
	line.width = 2.0
	line.default_color = Color(1.0, 0.0, 0.0, 1.0)
	line.antialiased = false
	line.z_index = 100
	line.z_as_relative = false
	line.points = PackedVector2Array([
		Vector2(inset, inset),
		Vector2(s - inset, inset),
		Vector2(s - inset, s - inset),
		Vector2(inset, s - inset),
		Vector2(inset, inset),
	])
	layer.add_child(line)
# ===== DEBUG


func _flush_log_batch() -> void:
	if not _batch_pop_keys.is_empty():
		WorldConfig.logv("[TileMap] Populated chunk %s in %d ms" % [
			_format_key_ranges(_batch_pop_keys), _batch_pop_ms
		])
		_batch_pop_keys.clear()
		_batch_pop_ms = 0
	if not _batch_drop_keys.is_empty():
		WorldConfig.logv("[TileMap] Dropped chunk %s in %d ms" % [
			_format_key_ranges(_batch_drop_keys), _batch_drop_ms
		])
		_batch_drop_keys.clear()
		_batch_drop_ms = 0


# Format keys as "(137,0-15)" or "(137,0-2),(137,5-7),(138,0-1)"
func _format_key_ranges(keys: Array) -> String:
	if keys.is_empty():
		return "()"
	var by_col: Dictionary = {} # cx -> Array[int] cy
	for k in keys:
		var key: Vector2i = k
		if not by_col.has(key.x):
			by_col[key.x] = []
		var ys: Array = by_col[key.x]
		if ys.find(key.y) == -1:
			ys.append(key.y)
	var col_keys: Array = by_col.keys()
	col_keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for cx in col_keys:
		var ys: Array = by_col[cx]
		ys.sort()
		var i := 0
		while i < ys.size():
			var y0: int = int(ys[i])
			var y1: int = y0
			while i + 1 < ys.size() and int(ys[i + 1]) == y1 + 1:
				i += 1
				y1 = int(ys[i])
			if y0 == y1:
				parts.append("(%d,%d)" % [cx, y0])
			else:
				parts.append("(%d,%d-%d)" % [cx, y0, y1])
			i += 1
	return ",".join(parts)
