# ChunkManager — in-memory active ChunkData by Vector2i(chunk_x, chunk_y)
class_name ChunkManager
extends Node

var _chunks: Dictionary = {} # Vector2i -> ChunkData
## Per-column surface gy (wrapped world x). -1 = unknown; unload keeps stale values.
var _surface: PackedInt32Array = PackedInt32Array()
## Band tops per wrapped world x (−1 = unknown). soil_wall = dirt/sand terrain id (0 = unknown).
var _lava_top: PackedInt32Array = PackedInt32Array()
var _stone_top: PackedInt32Array = PackedInt32Array()
var _rock_top: PackedInt32Array = PackedInt32Array()
var _soil_wall: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_init_surface_cache()


func _init_surface_cache() -> void:
	var w: int = WorldConfig.world_width_tiles()
	_surface.resize(w)
	_surface.fill(-1)
	_lava_top.resize(w)
	_lava_top.fill(-1)
	_stone_top.resize(w)
	_stone_top.fill(-1)
	_rock_top.resize(w)
	_rock_top.fill(-1)
	_soil_wall.resize(w)
	_soil_wall.fill(0)


func _ensure_surface_cache() -> void:
	if _surface.size() != WorldConfig.world_width_tiles():
		_init_surface_cache()


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
	var cur: int = data.get_cell(local.x, local.y)
	var wall: int = ChunkData.unpack_data(cur)
	# Dig to air → keep wall. Place solid → do not overwrite existing background wall.
	data.set_cell_packed(
		local.x, local.y,
		ChunkData.pack_cell(terrain_id, ChunkData.unpack_item(cur), wall)
	)
	_invalidate_surface(gx)
	return true


func get_wall_id(gx: int, gy: int) -> int:
	var tall_px: int = WorldConfig.world_chunks_tall_max() * WorldConfig.chunk_size()
	if gy < 0 or gy >= tall_px:
		return -1
	var cxy := global_to_chunk(gx, gy)
	var data: ChunkData = get_chunk(cxy.x, cxy.y)
	if data == null:
		return -1
	var local := global_to_local(gx, gy)
	return data.get_wall(local.x, local.y)


## Scan+store surface for every local-x in chunk column. Call after load (no gen surfaces).
func cache_column_surfaces(cx: int) -> void:
	_ensure_surface_cache()
	var cs: int = WorldConfig.chunk_size()
	var wcx: int = wrap_column(cx)
	for lx in cs:
		var wx: int = Helpers.wrap_block_x(wcx * cs + lx)
		var h: int = _scan_surface_height(wx)
		_surface[wx] = h


## Seed surface cache from fill_column's per-lx heights (avoids rescan after gen).
func seed_column_surfaces(cx: int, surfaces: PackedInt32Array) -> void:
	_ensure_surface_cache()
	var cs: int = WorldConfig.chunk_size()
	var wcx: int = wrap_column(cx)
	var n: int = mini(cs, surfaces.size())
	for lx in n:
		var wx: int = Helpers.wrap_block_x(wcx * cs + lx)
		var h: int = surfaces[lx]
		_surface[wx] = h if h >= 0 else -1


## Seed lava/stone/rock tops + dirt-belt soil wall id from fill_column.
func seed_column_band_tops(
	cx: int,
	lava_top: PackedInt32Array,
	stone_top: PackedInt32Array,
	rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	_ensure_surface_cache()
	var cs: int = WorldConfig.chunk_size()
	var wcx: int = wrap_column(cx)
	var n: int = mini(cs, lava_top.size())
	n = mini(n, stone_top.size())
	n = mini(n, rock_top.size())
	n = mini(n, soil_wall.size())
	for lx in n:
		var wx: int = Helpers.wrap_block_x(wcx * cs + lx)
		_lava_top[wx] = lava_top[lx] if lava_top[lx] >= 0 else -1
		_stone_top[wx] = stone_top[lx] if stone_top[lx] >= 0 else -1
		_rock_top[wx] = rock_top[lx] if rock_top[lx] >= 0 else -1
		_soil_wall[wx] = soil_wall[lx] if soil_wall[lx] > 0 else 0


## Fill band tops via map_surface_height when loading a column without gen arrays.
## `height_fn(column_x, lx, world_h) -> Dictionary` like WorldGenV2.map_surface_height.
func cache_column_band_tops(cx: int, height_fn: Callable) -> void:
	_ensure_surface_cache()
	if not height_fn.is_valid():
		return
	var cs: int = WorldConfig.chunk_size()
	var wcx: int = wrap_column(cx)
	var world_h: int = WorldConfig.world_height_tiles()
	var id_dirt: int = TileIdRegistry.id_from_name("blockforge:dirt")
	var id_sand: int = TileIdRegistry.id_from_name("blockforge:sand")
	for lx in cs:
		var wx: int = Helpers.wrap_block_x(wcx * cs + lx)
		var hinfo: Dictionary = height_fn.call(wcx, lx, world_h)
		_lava_top[wx] = int(hinfo.get("lava_top", -1))
		_stone_top[wx] = int(hinfo.get("stone_top", -1))
		_rock_top[wx] = int(hinfo.get("rock_top", -1))
		var n_hum: float = float(hinfo.get("humidity", 1.0))
		_soil_wall[wx] = id_sand if n_hum < WG_Settings.DESERT_HUMIDITY_MAX else id_dirt


func get_lava_top(gx: int) -> int:
	_ensure_surface_cache()
	return _lava_top[Helpers.wrap_block_x(gx)]


func get_stone_top(gx: int) -> int:
	_ensure_surface_cache()
	return _stone_top[Helpers.wrap_block_x(gx)]


func get_rock_top(gx: int) -> int:
	_ensure_surface_cache()
	return _rock_top[Helpers.wrap_block_x(gx)]


func get_soil_wall(gx: int) -> int:
	_ensure_surface_cache()
	return _soil_wall[Helpers.wrap_block_x(gx)]


## { lava_top, stone_top, rock_top, soil_wall } for wrapped gx.
func get_band_tops(gx: int) -> Dictionary:
	_ensure_surface_cache()
	var wx: int = Helpers.wrap_block_x(gx)
	return {
		"lava_top": _lava_top[wx],
		"stone_top": _stone_top[wx],
		"rock_top": _rock_top[wx],
		"soil_wall": _soil_wall[wx],
	}


func _invalidate_surface(gx: int) -> void:
	_ensure_surface_cache()
	_surface[Helpers.wrap_block_x(gx)] = -1
	# Band tops are seed-stable; do not clear on dig/place.


## Highest solid block gy at column gx (skips log/leaves canopy). -1 if unknown.
func find_surface_height(gx: int) -> int:
	_ensure_surface_cache()
	var wx: int = Helpers.wrap_block_x(gx)
	var cached: int = _surface[wx]
	if cached >= 0:
		return cached
	var h: int = _scan_surface_height(wx)
	if h >= 0:
		_surface[wx] = h
	return h


func _scan_surface_height(gx: int) -> int:
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
		var cells: PackedInt64Array = data.cells
		var dcs: int = data.size
		for ly in range(dcs - 1, -1, -1):
			var tid: int = ChunkData.unpack_terrain(cells[ly * dcs + lx])
			if tid == 0 or tid == id_log or tid == id_leaves:
				continue
			return cy * cs + ly
	return -1
