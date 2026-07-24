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
