# WorldGenV2
# Mapped world generation only — fill_column / fill_chunk_array for ChunkManager streaming.
# Legacy queue_chunk / Chunk[] generation removed.

extends Node
class_name WorldGenV2

var noise = {}

@onready var world = get_node("/root/GameScene/World")


# Initialize persistent noise / config used by every column.
func setup():
	noise.stone = Helpers.create_noise( world.w_seed + 1, 0.003, 3 )
	noise.dirt = Helpers.create_noise( world.w_seed + 2, 0.001, 3 )
	noise.mountain = Helpers.create_noise( world.w_seed + 3, 0.002, 3 )
	noise.humidity = Helpers.create_noise( world.w_seed + 10, 0.002, 3 )
	noise.lava = Helpers.create_noise( world.w_seed + 4, 0.005, 2 )

	Yaml.chunky()

	noise.trees = Helpers.create_noise( world.w_seed + 10, 0.02, 5 )
	noise.layers = Helpers.create_noise( world.w_seed + 40, 0.008, 2 )

	# Ensure underground tiles are registered
	# var _ug = Tiles.UNDERGROUND


func _ready():
	setup()


func _cave_is_local_core( cave_noise: Dictionary, tunnel_mask: Dictionary, pos: Vector2i ) -> bool:
	var v: float = absf(cave_noise[pos] - 0.5)
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var npos: Vector2i = pos + d
		if not tunnel_mask.has(npos):
			continue
		if absf(cave_noise[npos] - 0.5) < v - 0.0001:
			return false
	return true


func _cave_tunnel_branches( tunnel_mask: Dictionary, pos: Vector2i ) -> int:
	# Count cardinal directions that have tunnel cells a few steps out (junction-ish).
	var branches := 0
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var hit := false
		for step in range(1, 5):
			if tunnel_mask.has(pos + dir * step):
				hit = true
				break
		if hit:
			branches += 1
	return branches


# fill_column: generate an entire vertical column (coroutine — yields between phases).
# Returns { "rows", "surfaces", "lava_top", "stone_top", "rock_top", "soil_wall" }. Callers must await.
func fill_column(column_x: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	if noise.is_empty():
		setup()
	TileIdRegistry.ensure_ready()
	# Force underground tile table init for name lookups used below
	# Tiles.UNDERGROUND.size()

	var cs: int = WorldConfig.chunk_size()
	var tall: int = WorldConfig.world_chunks_tall_max()
	var world_h: int = WorldConfig.world_height_tiles()
	var wide: int = WorldConfig.world_chunks_wide_max()
	var wrapped_cx: int = posmod(column_x, wide)

	var id_lava: int = TileIdRegistry.id_from_name("blockforge:lava")
	var id_stone: int = TileIdRegistry.id_from_name("blockforge:stone")
	var id_cobble: int = TileIdRegistry.id_from_name("blockforge:cobblestone")
	var id_dirt: int = TileIdRegistry.id_from_name("blockforge:dirt")
	var id_grass: int = TileIdRegistry.id_from_name("blockforge:grass")
	var id_sand: int = TileIdRegistry.id_from_name("blockforge:sand")
	var id_snow: int = TileIdRegistry.id_from_name("blockforge:snow")
	var id_log: int = TileIdRegistry.id_from_name("blockforge:log")
	var id_leaves: int = TileIdRegistry.id_from_name("blockforge:leaves")

	# Full-height strip: index = gy * cs + lx
	var strip := PackedInt64Array()
	strip.resize(world_h * cs)
	strip.fill(0)

	var lava_top := PackedInt32Array(); lava_top.resize(cs)
	var stone_top := PackedInt32Array(); stone_top.resize(cs)
	var rock_top := PackedInt32Array(); rock_top.resize(cs)
	var surfaces := PackedInt32Array(); surfaces.resize(cs)
	var soil_wall := PackedInt32Array(); soil_wall.resize(cs)
	var growable := PackedByteArray(); growable.resize(cs)

	for lx in cs:
		var hinfo: Dictionary = map_surface_height(wrapped_cx, lx, world_h)
		var lt: int = int(hinfo["lava_top"])
		var st: int = int(hinfo["stone_top"])
		var rt: int = int(hinfo["rock_top"])
		var surface: int = int(hinfo["surface"])
		var mountain_h: int = int(hinfo["mountain_h"])
		var n_hum: float = float(hinfo["humidity"])

		lava_top[lx] = lt
		stone_top[lx] = st
		rock_top[lx] = rt
		surfaces[lx] = surface
		soil_wall[lx] = id_sand if n_hum < WG_Settings.DESERT_HUMIDITY_MAX else id_dirt

		var top_id: int = id_sand
		if n_hum >= WG_Settings.DESERT_HUMIDITY_MAX:
			if mountain_h > WG_Settings.MOUNTAIN_SNOW_ALTITUDE:
				top_id = id_snow
			else:
				top_id = id_grass
		growable[lx] = 1 if bool(hinfo["growable"]) else 0

		for gy in world_h:
			var terrain_id: int = 0
			if gy < lt:
				terrain_id = id_lava
			elif gy < st:
				terrain_id = id_stone
			elif gy < rt:
				terrain_id = id_cobble
			elif gy < surface:
				terrain_id = soil_wall[lx]
			elif gy == surface:
				terrain_id = top_id
			strip[gy * cs + lx] = WallTiles.pack_fg_with_band_wall(
				terrain_id, 0, gy, lt, st, rt, soil_wall[lx]
			)

	await get_tree().process_frame

	# Same pipeline as chunky_filling(): layers → caves → ores
	_map_generate_layers(strip, cs, world_h, wrapped_cx, lava_top, stone_top, rock_top, soil_wall)
	await get_tree().process_frame
	await _map_dig_caves(strip, cs, world_h, wrapped_cx, lava_top, stone_top, rock_top, soil_wall)
	await _map_generate_ores(strip, cs, world_h, wrapped_cx, lava_top, stone_top, rock_top, soil_wall)

	# Trees after underground features
	_map_fill_trees_strip(strip, cs, world_h, wrapped_cx, surfaces, growable, id_log, id_leaves)
	await get_tree().process_frame

	# Portal once (mapped surface dressing) — after trees so canopy cannot overwrite it
	_map_try_place_portal(strip, cs, world_h, wrapped_cx, surfaces, lava_top, stone_top, rock_top, soil_wall)

	# Slice into per-chunk arrays
	var rows: Array = []
	rows.resize(tall)
	for cy in tall:
		var cells := PackedInt64Array()
		cells.resize(cs * cs)
		for ly in cs:
			var gy: int = cy * cs + ly
			for lx in cs:
				cells[ly * cs + lx] = strip[gy * cs + lx] if gy < world_h else 0
		rows[cy] = cells

	WorldConfig.logv("[Chunk] Generated column %d in %d ms" % [wrapped_cx, Time.get_ticks_msec() - t0])
	return {
		"rows": rows,
		"surfaces": surfaces,
		"lava_top": lava_top,
		"stone_top": stone_top,
		"rock_top": rock_top,
		"soil_wall": soil_wall,
	}


# fill_chunk_array: pack one chunk row (uses fill_column; prefer fill_column for streaming).
# TODO: Procedural objects placement (spatial hash / complex objects)
func fill_chunk_array(chunk_x: int, chunk_y: int, out_array: PackedInt64Array) -> void:
	var result: Dictionary = await fill_column(chunk_x)
	var rows: Array = result.get("rows", [])
	var cs: int = WorldConfig.chunk_size()
	var expected: int = cs * cs
	if out_array.size() != expected:
		out_array.resize(expected)
	if chunk_y >= 0 and chunk_y < rows.size():
		var src: PackedInt64Array = rows[chunk_y]
		for i in expected:
			out_array[i] = src[i]
	else:
		out_array.fill(0)


func _map_host_ids(host_names: Array) -> Array:
	var out: Array = []
	for n in host_names:
		out.append(TileIdRegistry.id_from_name(str(n)))
	return out


func _map_strip_overwrite(
	strip: PackedInt64Array, cs: int, world_h: int, lx: int, gy: int, tid: int, hosts: Array,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> bool:
	if lx < 0 or lx >= cs or gy < 0 or gy >= world_h:
		return false
	var idx: int = gy * cs + lx
	var cur: int = ChunkData.unpack_terrain(strip[idx])
	if hosts.find(cur) == -1:
		return false
	strip[idx] = WallTiles.pack_fg_with_band_wall(
		tid, 0, gy, lava_top[lx], stone_top[lx], rock_top[lx], soil_wall[lx], strip[idx]
	)
	return true


func _map_generate_layers(
	strip: PackedInt64Array, cs: int, world_h: int, column_x: int,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.w_seed + column_x * 7919 + 17
	var all_incl: Dictionary = Yaml.chunky("inclusions")
	var layers: Dictionary = Yaml.chunky("layers")

	for layer_name in layers:
		var cfg: Dictionary = layers[layer_name]
		var layer_tid: int = TileIdRegistry.id_from_name(str(cfg.get("tile", "")))
		if layer_tid == 0:
			continue
		var hosts: Array = _map_host_ids(cfg.get("host", []))
		var min_f: float = float(cfg.get("height_min", cfg.get("min_depth_fraction", 0.0)))
		var max_f: float = float(cfg.get("height_max", cfg.get("max_depth_fraction", 1.0)))
		if min_f > max_f:
			var tmp := min_f
			min_f = max_f
			max_f = tmp
		var num_lenses: int = int(cfg.get("number_of_lenses", 1))
		var thick_min: int = int(cfg.get("thickness_min", 2))
		var thick_max: int = int(cfg.get("thickness_max", 6))
		var seg_min: int = int(cfg.get("segment_length_min", 30))
		var seg_max: int = int(cfg.get("segment_length_max", 200))
		var gap_min: int = int(cfg.get("gap_min", 8))
		var gap_max: int = int(cfg.get("gap_max", 40))
		var warp: float = float(cfg.get("noise_warp", 0.1))
		var incl_names: Array = cfg.get("inclusions", [])

		for _lens in num_lenses:
			var x := 0
			while x < cs:
				var seg_len: int = rng.randi_range(seg_min, seg_max)
				var base_thick: float = rng.randf_range(thick_min, thick_max)
				var lens_center_f: float = rng.randf_range(min_f, max_f)
				for li in seg_len:
					var cx: int = x + li
					if cx >= cs:
						break
					var lt: int = lava_top[cx]
					var rt: int = rock_top[cx]
					var rock_h: int = rt - lt
					if rock_h <= 1:
						continue
					var t: float = float(li) / float(maxi(seg_len - 1, 1))
					var taper: float = 1.0 - absf(2.0 * t - 1.0)
					var thickness: int = clampi(int(round(base_thick * taper)), 1, thick_max)
					var nwarp: float = noise.layers.get_noise_2d(
						column_x * cs + cx, lens_center_f * 100.0 + float(_lens) * 17.0
					) * warp
					var center_f: float = clampf(lens_center_f + nwarp, min_f, max_f)
					var center_y: int = lt + int(center_f * rock_h)
					var half: int = thickness / 2
					for dy in range(-half, thickness - half):
						var gy: int = center_y + dy
						if gy < lt or gy >= rt:
							continue
						if _map_strip_overwrite(
							strip, cs, world_h, cx, gy, layer_tid, hosts,
							lava_top, stone_top, rock_top, soil_wall
						):
							for iname in incl_names:
								if not all_incl.has(iname):
									continue
								var icfg: Dictionary = all_incl[iname]
								if not bool(icfg.get("during_layer", true)):
									continue
								if rng.randf() > float(icfg.get("rarity", 0.05)):
									continue
								var itid: int = TileIdRegistry.id_from_name(str(icfg.get("tile", "")))
								if itid != 0:
									var idx: int = gy * cs + cx
									strip[idx] = WallTiles.pack_fg_with_band_wall(
										itid, 0, gy, lava_top[cx], stone_top[cx], rock_top[cx],
										soil_wall[cx], strip[idx]
									)
				x += seg_len + rng.randi_range(gap_min, gap_max)


func _map_dig_caves(
	strip: PackedInt64Array, cs: int, world_h: int, column_x: int,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	var caves: Dictionary = Yaml.chunky("caves")
	for cave_name in caves:
		var cfg: Dictionary = caves[cave_name]
		var min_f: float = float(cfg.get("min_depth_fraction", 0.01))
		var max_f: float = float(cfg.get("max_depth_fraction", 0.99))
		var width: float = float(cfg.get("clump_size", 0.08))
		var freq: float = float(cfg.get("freq", 0.04))
		var chamber_core: float = float(cfg.get("chamber_core", width * 0.25))
		var chamber_r_min: float = float(cfg.get("chamber_radius_min", 4.0))
		var chamber_r_max: float = float(cfg.get("chamber_radius_max", 6.0))
		var chamber_min_branches: int = int(cfg.get("chamber_min_branches", 3))
		var chamber_jitter: float = float(cfg.get("chamber_jitter", 0.35))
		var chamber_chance: float = float(cfg.get("chamber_chance", 0.05))

		var cave_noisegen = Helpers.create_noise(world.w_seed + ("cave_" + cave_name).hash(), freq, 2)
		var cave_noise = Helpers.noise_array_2d_offset(
			cave_noisegen, Vector2i(cs, world_h), Vector2i(column_x * cs, 0)
		)
		await get_tree().process_frame
		var jitter_gen = Helpers.create_noise(world.w_seed + ("cave_jitter_" + cave_name).hash(), freq * 2.5, 2)
		var jitter_noise = Helpers.noise_array_2d_offset(
			jitter_gen, Vector2i(cs, world_h), Vector2i(column_x * cs, 0)
		)
		await get_tree().process_frame
		var chamber_rng := RandomNumberGenerator.new()
		chamber_rng.seed = world.w_seed + column_x * 9176 + cave_name.hash()

		var tunnel_mask: Dictionary = {}
		# Pass 1: tunnels
		for x in cs:
			var y0: int = lava_top[x]
			var y1: int = rock_top[x]
			var band_h: int = y1 - y0
			if band_h <= 0:
				continue
			for y in range(y0, y1):
				var local_f: float = float(y - y0) / float(band_h)
				if local_f < min_f or local_f > max_f:
					continue
				var pos := Vector2i(x, y)
				if absf(float(cave_noise.get(pos, 0.5)) - 0.5) <= width:
					var idx: int = y * cs + x
					strip[idx] = WallTiles.carve_air_preserve_wall(
						strip[idx], y, lava_top[x], stone_top[x], rock_top[x], soil_wall[x]
					)
					tunnel_mask[pos] = true

		# Pass 2: chambers at junctions
		var seeds: Array[Vector2i] = []
		for pos in tunnel_mask:
			if absf(float(cave_noise.get(pos, 0.5)) - 0.5) > chamber_core:
				continue
			if _cave_tunnel_branches(tunnel_mask, pos) < chamber_min_branches:
				continue
			if not _cave_is_local_core(cave_noise, tunnel_mask, pos):
				continue
			seeds.append(pos)

		var used_seeds: Array[Vector2i] = []
		for seed_pos in seeds:
			if chamber_rng.randf() > chamber_chance:
				continue
			var too_close := false
			for prev in used_seeds:
				if seed_pos.distance_squared_to(prev) < 64:
					too_close = true
					break
			if too_close:
				continue
			var jt: float = clampf(float(jitter_noise.get(seed_pos, 0.5)), 0.0, 1.0)
			var base_r: float = lerpf(chamber_r_min, chamber_r_max, jt)
			if _map_cave_carve_irregular(
				strip, cs, world_h, lava_top, stone_top, rock_top, soil_wall, seed_pos, base_r,
				chamber_jitter, jitter_noise, tunnel_mask
			) > 0:
				used_seeds.append(seed_pos)
		await get_tree().process_frame


func _map_cave_carve_irregular(
	strip: PackedInt64Array, cs: int, world_h: int,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array,
	center: Vector2i, radius: float, jitter: float, jitter_noise: Dictionary, tunnel_mask: Dictionary
) -> int:
	var carved := 0
	var r_ceil: int = ceili(radius + jitter * radius)
	for dx in range(-r_ceil, r_ceil + 1):
		for dy in range(-r_ceil, r_ceil + 1):
			var px: int = center.x + dx
			var py: int = center.y + dy
			if px < 0 or px >= cs or py < 0 or py >= world_h:
				continue
			if py < lava_top[px] or py >= rock_top[px]:
				continue
			var pos := Vector2i(px, py)
			var j: float = float(jitter_noise.get(pos, 0.5))
			var local_r: float = radius * (1.0 + (j - 0.5) * 2.0 * jitter)
			if float(dx * dx + dy * dy) > local_r * local_r:
				continue
			if tunnel_mask.has(pos):
				continue
			var idx: int = py * cs + px
			strip[idx] = WallTiles.carve_air_preserve_wall(
				strip[idx], py, lava_top[px], stone_top[px], rock_top[px], soil_wall[px]
			)
			tunnel_mask[pos] = true
			carved += 1
	return carved


func _map_generate_ores(
	strip: PackedInt64Array, cs: int, world_h: int, column_x: int,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	var ores: Dictionary = Yaml.chunky("ores")
	for ore_name in ores:
		var cfg: Dictionary = ores[ore_name]
		var ore_tid: int = TileIdRegistry.id_from_name(str(cfg.get("tile", "")))
		if ore_tid == 0:
			continue
		var hosts: Array = _map_host_ids(cfg.get("host", []))
		var host_layer: String = str(cfg.get("host_layer", "stone"))
		var min_f: float = float(cfg.get("min_depth_fraction", 0.0))
		var max_f: float = float(cfg.get("max_depth_fraction", 1.0))
		var width: float = float(cfg.get("clump_size", cfg.get("width", 0.1)))
		var freq: float = float(cfg.get("freq", 0.04))

		var ore_noisegen = Helpers.create_noise(world.w_seed + str(cfg.get("tile", ore_name)).hash(), freq, 2)
		var ore_noise = Helpers.noise_array_2d_offset(
			ore_noisegen, Vector2i(cs, world_h), Vector2i(column_x * cs, 0)
		)

		for x in cs:
			var bands: Array = _map_ore_y_bands(x, host_layer, lava_top, stone_top, rock_top)
			for band in bands:
				var y0: int = band[0]
				var y1: int = band[1]
				var band_h: int = y1 - y0
				if band_h <= 0:
					continue
				for y in range(y0, y1):
					var local_f: float = float(y - y0) / float(band_h)
					if local_f < min_f or local_f > max_f:
						continue
					var nv: float = float(ore_noise.get(Vector2i(x, y), 0.5))
					if absf(nv - 0.5) <= width:
						_map_strip_overwrite(
							strip, cs, world_h, x, y, ore_tid, hosts,
							lava_top, stone_top, rock_top, soil_wall
						)
		await get_tree().process_frame


func _map_ore_y_bands(
	x: int, host_layer: String,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array
) -> Array:
	var bands: Array = []
	match host_layer:
		"cobble":
			bands.append([stone_top[x], rock_top[x]])
		"stone":
			bands.append([lava_top[x], stone_top[x]])
		"cobble_and_stone":
			bands.append([lava_top[x], stone_top[x]])
			bands.append([stone_top[x], rock_top[x]])
		_:
			bands.append([lava_top[x], rock_top[x]])
	return bands


func _map_fill_trees_strip(
	strip: PackedInt64Array, cs: int, world_h: int, column_x: int,
	surfaces: PackedInt32Array, growable: PackedByteArray,
	id_log: int, id_leaves: int
) -> void:
	# Trees rooted in this column (trunk + in-bounds canopy).
	_map_place_trees_from_column(
		strip, cs, world_h, column_x, column_x, 0, cs,
		surfaces, growable, id_log, id_leaves, true
	)
	# Canopy that hangs in from left/right neighbor columns (air only — never overwrite terrain).
	# Max half-width ≈ TREE_HEIGHT_MAX * 0.75.
	var canopy_max: int = int(WG_Settings.TREE_HEIGHT_MAX * 0.75)
	if canopy_max < 1:
		return
	var wide: int = WorldConfig.world_chunks_wide_max()
	var left_cx: int = posmod(column_x - 1, wide)
	var right_cx: int = posmod(column_x + 1, wide)
	# Left neighbor: only roots near its right edge can overhang into us.
	_map_place_trees_from_column(
		strip, cs, world_h, left_cx, column_x, maxi(0, cs - canopy_max), cs,
		PackedInt32Array(), PackedByteArray(), id_log, id_leaves, false
	)
	# Right neighbor: only roots near its left edge.
	_map_place_trees_from_column(
		strip, cs, world_h, right_cx, column_x, 0, mini(cs, canopy_max),
		PackedInt32Array(), PackedByteArray(), id_log, id_leaves, false
	)


# Place trees whose trunks sit in root_cx. Cells are written into `strip` for target_cx only.
# If place_trunks is false, only leaf overhang into target_cx is applied (air only).
func _map_place_trees_from_column(
	strip: PackedInt64Array, cs: int, world_h: int,
	root_cx: int, target_cx: int, lx0: int, lx1: int,
	surfaces: PackedInt32Array, growable: PackedByteArray,
	id_log: int, id_leaves: int, place_trunks: bool
) -> void:
	if lx0 >= lx1:
		return
	var tree_noise: Array[float] = Helpers.noise_array_1d(noise.trees, cs, root_cx * cs)
	var tree_placement = Helpers.array_local_max(tree_noise)
	var height_noise: Array[float] = tree_noise.duplicate()
	var tree_height = Helpers.array_scale(height_noise, WG_Settings.TREE_HEIGHT_MAX, WG_Settings.TREE_HEIGHT_MIN)

	for lx in range(lx0, lx1):
		if tree_placement[lx] != 1:
			continue
		var surface: int
		var can_grow := true
		if place_trunks:
			if growable.is_empty() or growable[lx] == 0:
				continue
			surface = surfaces[lx]
		else:
			# Neighbor overhang: recompute surface/growable for that root column cell.
			var info: Dictionary = map_surface_height(root_cx, lx, world_h)
			surface = int(info.get("surface", 0))
			can_grow = bool(info.get("growable", false))
			if not can_grow:
				continue
		var th: int = clampi(int(tree_height[lx]), WG_Settings.TREE_HEIGHT_MIN, WG_Settings.TREE_HEIGHT_MAX)
		_map_place_tree_into_strip(
			strip, cs, world_h, root_cx, target_cx, lx, surface + 1, th,
			id_log, id_leaves, place_trunks
		)


# Pick portal X once: center block of the central map column.
func ensure_mapped_portal_x() -> void:
	if world.world_portal_pos != Vector2i.ZERO:
		return
	var cs: int = WorldConfig.chunk_size()
	var center_col: int = WorldConfig.world_chunks_wide_max() / 2
	var x: int = center_col * cs + cs / 2
	world.world_portal_pos = Vector2i(Helpers.wrap_block_x(x), 0)
	WorldConfig.logv("[Chunk] Portal will be at x=%d (center column %d)" % [
		world.world_portal_pos.x, center_col
	])


func _map_strip_set(
	strip: PackedInt64Array, cs: int, world_h: int, lx: int, gy: int, terrain_id: int,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	if lx < 0 or lx >= cs or gy < 0 or gy >= world_h:
		return
	strip[gy * cs + lx] = WallTiles.pack_fg_with_band_wall(
		terrain_id, 0, gy, lava_top[lx], stone_top[lx], rock_top[lx], soil_wall[lx],
		strip[gy * cs + lx]
	)


# Mapped equivalent of surface_dressing portal placement (natural stone base).
func _map_try_place_portal(
	strip: PackedInt64Array, cs: int, world_h: int, wrapped_cx: int, surfaces: PackedInt32Array,
	lava_top: PackedInt32Array, stone_top: PackedInt32Array, rock_top: PackedInt32Array,
	soil_wall: PackedInt32Array
) -> void:
	ensure_mapped_portal_x()
	# y != 0 means already placed this session
	if world.world_portal_pos.y != 0:
		return
	var portal_gx: int = Helpers.wrap_block_x(world.world_portal_pos.x)
	var portal_cx: int = int(floor(float(portal_gx) / float(cs)))
	var wide: int = WorldConfig.world_chunks_wide_max()
	if posmod(portal_cx, wide) != wrapped_cx:
		return

	var lx: int = posmod(portal_gx, cs)
	var surface: int = int(surfaces[lx])
	if surface < 0 or surface + 2 >= world_h:
		push_warning("[Chunk] Portal surface invalid at x=%d surface=%d" % [portal_gx, surface])
		return

	var id_base: int = TileIdRegistry.id_from_name("blockforge:portal_base_stone")
	var id_btm: int = TileIdRegistry.id_from_name("blockforge:portal_btm")
	var id_top: int = TileIdRegistry.id_from_name("blockforge:portal_top")
	_map_strip_set(strip, cs, world_h, lx, surface, id_base, lava_top, stone_top, rock_top, soil_wall)
	_map_strip_set(strip, cs, world_h, lx, surface + 1, id_btm, lava_top, stone_top, rock_top, soil_wall)
	_map_strip_set(strip, cs, world_h, lx, surface + 2, id_top, lava_top, stone_top, rock_top, soil_wall)

	world.world_portal_pos = Vector2i(portal_gx, surface)
	WorldConfig.logv("[Chunk] Portal placed at %s" % Helpers.coord_string(portal_gx, surface))


# Column surface stack for mapping gen (shared by fill_column and tree overhang).
# Returns: lava_top, stone_top, rock_top, surface, mountain_h, humidity, growable.
func map_surface_height(column_x: int, lx: int, world_h: int) -> Dictionary:
	var gx: int = column_x * WorldConfig.chunk_size() + lx
	var n_stone: float = noise.stone.get_noise_1d(gx) + 0.5
	var n_dirt: float = noise.dirt.get_noise_1d(gx) + 0.5
	var n_lava: float = noise.lava.get_noise_1d(gx) + 0.5
	var n_mnt: float = noise.mountain.get_noise_1d(gx) + 0.5
	var n_hum: float = noise.humidity.get_noise_1d(gx) + 0.5

	var mountain_h: int = int(n_mnt * WG_Settings.MOUNTAIN_HEIGHT_SCALE + WG_Settings.MOUNTAIN_HEIGHT_OFFSET)
	var lt: int = int(n_lava * 8.0 + 2.0)
	var depth_stone: int = int(n_stone * WG_Settings.LAYER_COBBLESTONE_SCALE + WG_Settings.LAYER_COBBLESTONE_OFFSET)
	var st: int = lt + mountain_h
	var rt: int = st + depth_stone
	var depth_dirt: int = int(n_dirt * 3.0 + 4.0)
	var surface: int = rt + depth_dirt

	var diff: int = surface - (world_h - 16)
	if diff > 0:
		if mountain_h < diff:
			depth_stone = maxi(0, depth_stone - (diff - mountain_h))
			mountain_h = 0
		else:
			mountain_h -= diff
		st = lt + mountain_h
		rt = st + depth_stone
		surface = rt + depth_dirt

	var growable: bool = n_hum >= WG_Settings.DESERT_HUMIDITY_MAX
	return {
		"lava_top": lt,
		"stone_top": st,
		"rock_top": rt,
		"surface": surface,
		"mountain_h": mountain_h,
		"humidity": n_hum,
		"growable": growable,
	}


func _map_place_tree_into_strip(
	strip: PackedInt64Array, cs: int, world_h: int,
	root_cx: int, target_cx: int, root_lx: int, base_y: int, height: int,
	id_log: int, id_leaves: int, place_trunks: bool
) -> void:
	var wide: int = WorldConfig.world_chunks_wide_max()
	var root_gx: int = root_cx * cs + root_lx

	if place_trunks and root_cx == target_cx:
		for h in height:
			var gy: int = base_y + h
			if gy < 0 or gy >= world_h:
				continue
			var idx: int = gy * cs + root_lx
			var existing: int = ChunkData.unpack_terrain(strip[idx])
			if existing != 0 and existing != id_leaves:
				return
			strip[idx] = WallTiles.pack_with_wall(id_log, 0, strip[idx])

	var leaf_btm: int = int(height * 0.4)
	var width: float = float(int(height * 0.75))
	var h: int = 0
	while width >= 0.0:
		var gy: int = base_y + leaf_btm + h
		var w: int = int(width)
		for ox in w:
			_map_set_leaf_world(strip, cs, world_h, wide, target_cx, root_gx + ox, gy, id_leaves)
			_map_set_leaf_world(strip, cs, world_h, wide, target_cx, root_gx - ox, gy, id_leaves)
		width -= 0.5
		h += 1


# Write a leaf into strip only when the world X falls inside target_cx (air only).
func _map_set_leaf_world(
	strip: PackedInt64Array, cs: int, world_h: int, wide: int,
	target_cx: int, gx: int, gy: int, id_leaves: int
) -> void:
	if gy < 0 or gy >= world_h:
		return
	var world_w: int = wide * cs
	gx = posmod(gx, world_w)
	var cell_cx: int = int(gx / cs)
	if cell_cx != target_cx:
		return
	var lx: int = gx - target_cx * cs
	var idx: int = gy * cs + lx
	if ChunkData.unpack_terrain(strip[idx]) == 0:
		strip[idx] = WallTiles.pack_with_wall(id_leaves, 0, strip[idx])
