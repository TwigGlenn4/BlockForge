# TileMapPopulator — chunk PackedInt64Array → TileMapLayer nodes.
# Uses editor TileSet at res://assets/textures/main_tileset.tres (do not build atlases at runtime).
class_name TileMapPopulator
extends Node

const TILESET_PATH := "res://assets/textures/main_tileset.tres"

@export var maps_root_path: NodePath = ^"../ChunkMaps"
@onready var maps_root: Node2D = get_node_or_null(maps_root_path)

var _tileset: TileSet
var _layers: Dictionary = {} # Vector2i -> TileMapLayer

# Log batching (group consecutive cy per column)
var _batching := false
var _batch_pop_keys: Array[Vector2i] = []
var _batch_pop_ms: int = 0
var _batch_drop_keys: Array[Vector2i] = []
var _batch_drop_ms: int = 0


func _ready() -> void:
	if maps_root == null:
		maps_root = get_node_or_null("../ChunkMaps")
	_tileset = load(TILESET_PATH) as TileSet
	if _tileset == null:
		push_error("[TileMapPopulator] Missing TileSet at %s (create in editor)" % TILESET_PATH)


func has_layer(cx: int, cy: int) -> bool:
	return _layers.has(Vector2i(cx, cy))


func active_layer_count() -> int:
	return _layers.size()


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
	if not _layers.has(key):
		return
	var layer: TileMapLayer = _layers[key]
	_layers.erase(key)
	if is_instance_valid(layer):
		layer.queue_free()
	var elapsed: int = Time.get_ticks_msec() - t0
	if _batching:
		_batch_drop_keys.append(key)
		_batch_drop_ms += elapsed
	else:
		WorldConfig.logv("[TileMap] Dropped chunk %s in %d ms" % [_format_key_ranges([key]), elapsed])


func drop_all() -> void:
	begin_log_batch()
	for k in _layers.keys():
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
	for key in _layers.keys():
		var k: Vector2i = key
		var layer: TileMapLayer = _layers[k]
		if not is_instance_valid(layer):
			continue
		var base_x: float = float(k.x * cs * ts)
		var k_period: float = round((camera_px - base_x) / period)
		layer.position.x = base_x + k_period * period


func _populate_internal(data: ChunkData) -> TileMapLayer:
	var key := Vector2i(data.chunk_x, data.chunk_y)
	var layer: TileMapLayer
	var cs: int = WorldConfig.chunk_size()
	var ts: int = WorldConfig.tile_size_px()
	if _layers.has(key):
		layer = _layers[key]
		layer.clear()
	else:
		layer = TileMapLayer.new()
		layer.name = "Chunk_%d_%d" % [data.chunk_x, data.chunk_y]
		layer.tile_set = _tileset
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Align with Helpers.pos_block_to_pixel: block (gx,gy) center at (gx*ts+ts/2, -gy*ts-ts/2).
		# Cell (lx, cs-1-ly) top-left must be at (gx*ts, -(gy+1)*ts) → layer origin below.
		# X may be shifted later by align_layers_to_camera for cylindrical wrap.
		layer.position = Vector2(data.chunk_x * cs * ts, -(data.chunk_y + 1) * cs * ts)
		if maps_root:
			maps_root.add_child(layer)
		_layers[key] = layer

	_sync_debug_outline(layer, cs, ts)

	TileIdRegistry.ensure_ready()
	for ly in cs:
		for lx in cs:
			var terrain_id: int = ChunkData.unpack_terrain(data.get_cell(lx, ly))
			if terrain_id == 0:
				continue
			var info: Dictionary = TileIdRegistry.atlas_for_id(terrain_id)
			if info.is_empty():
				continue
			# TileMap local: y increases downward; our ly is upward from chunk bottom
			var cell := Vector2i(lx, cs - 1 - ly)
			layer.set_cell(cell, int(info["atlas"]), info["pos"])
	return layer


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
