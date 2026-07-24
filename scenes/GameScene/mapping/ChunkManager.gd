# ChunkManager — in-memory active ChunkData by Vector2i(chunk_x, chunk_y)
class_name ChunkManager
extends Node

var _chunks: Dictionary = {} # Vector2i -> ChunkData


func has_chunk(cx: int, cy: int) -> bool:
	return _chunks.has(_key(cx, cy))


func get_chunk(cx: int, cy: int) -> ChunkData:
	var k := _key(cx, cy)
	if _chunks.has(k):
		return _chunks[k]
	return null


func put_chunk(data: ChunkData) -> void:
	_chunks[_key(data.chunk_x, data.chunk_y)] = data


func remove_chunk(cx: int, cy: int) -> ChunkData:
	var k := _key(cx, cy)
	if not _chunks.has(k):
		return null
	var c: ChunkData = _chunks[k]
	_chunks.erase(k)
	return c


func active_keys() -> Array:
	return _chunks.keys()


func active_count() -> int:
	return _chunks.size()


func wrap_column(cx: int) -> int:
	# Toroidal-style column indexing for seamless edges.
	# TODO: optional hard bounds mode (clamp instead of wrap)
	var w: int = WorldConfig.world_chunks_wide_max()
	return posmod(cx, w)


func clamp_row(cy: int) -> int:
	return clampi(cy, 0, WorldConfig.world_chunks_tall_max() - 1)


func get_column_chunks(cx: int) -> Array:
	var out: Array = []
	var wcx: int = wrap_column(cx)
	var tall: int = WorldConfig.world_chunks_tall_max()
	for cy in tall:
		var c: ChunkData = get_chunk(wcx, cy)
		if c != null:
			out.append(c)
	return out


func remove_column(cx: int) -> Array:
	var removed: Array = []
	var wcx: int = wrap_column(cx)
	var tall: int = WorldConfig.world_chunks_tall_max()
	for cy in tall:
		var c: ChunkData = remove_chunk(wcx, cy)
		if c != null:
			removed.append(c)
	return removed


func _key(cx: int, cy: int) -> Vector2i:
	return Vector2i(wrap_column(cx), clamp_row(cy))


func global_to_chunk(gx: int, gy: int) -> Vector2i:
	var cs: int = WorldConfig.chunk_size()
	var wx: int = Helpers.wrap_block_x(gx)
	return Vector2i(wrap_column(int(floor(float(wx) / float(cs)))), clamp_row(int(floor(float(gy) / float(cs)))))


func global_to_local(gx: int, gy: int) -> Vector2i:
	var cs: int = WorldConfig.chunk_size()
	var wx: int = Helpers.wrap_block_x(gx)
	return Vector2i(posmod(wx, cs), posmod(gy, cs))


## Terrain id at global block coords (0 = air). Returns -1 if chunk not loaded.
func get_terrain_id(gx: int, gy: int) -> int:
	var tall_px: int = WorldConfig.world_chunks_tall_max() * WorldConfig.chunk_size()
	if gy < 0 or gy >= tall_px:
		return -1
	var cxy := global_to_chunk(gx, gy)
	var data: ChunkData = get_chunk(cxy.x, cxy.y)
	if data == null:
		return -1
	var local := global_to_local(gx, gy)
	return ChunkData.unpack_terrain(data.get_cell(local.x, local.y))


func set_terrain_id(gx: int, gy: int, terrain_id: int) -> bool:
	var tall_px: int = WorldConfig.world_chunks_tall_max() * WorldConfig.chunk_size()
	if gy < 0 or gy >= tall_px:
		return false
	var cxy := global_to_chunk(gx, gy)
	var data: ChunkData = get_chunk(cxy.x, cxy.y)
	if data == null:
		return false
	var local := global_to_local(gx, gy)
	data.set_terrain(local.x, local.y, terrain_id)
	return true


## Highest solid block gy at column gx (skips log/leaves canopy). -1 if unknown/unloaded.
func find_surface_height(gx: int) -> int:
	var cs: int = WorldConfig.chunk_size()
	var wx: int = Helpers.wrap_block_x(gx)
	var cx: int = wrap_column(int(floor(float(wx) / float(cs))))
	var lx: int = posmod(wx, cs)
	var id_log: int = TileIdRegistry.id_from_name("blockforge:log")
	var id_leaves: int = TileIdRegistry.id_from_name("blockforge:leaves")
	var tall: int = WorldConfig.world_chunks_tall_max()
	for cy in range(tall - 1, -1, -1):
		var data: ChunkData = get_chunk(cx, cy)
		if data == null:
			continue
		for ly in range(cs - 1, -1, -1):
			var tid: int = ChunkData.unpack_terrain(data.get_cell(lx, ly))
			if tid == 0 or tid == id_log or tid == id_leaves:
				continue
			return cy * cs + ly
	return -1
