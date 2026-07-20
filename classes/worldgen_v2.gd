# WorldGenV2
# Generates the world one chunk at a time
# Only generates as needed with chunk_queue, array of chunk numbers 

extends Node
class_name WorldGenV2

var noise = {}
var chunk_queue = []


signal gentimer_start
signal gentimer_stop
var generation_working = true

signal move_camera(block_pos)
signal character_to_portal(portal_pos)


const QUEUE_DELAY:int = 0; # min seconds between chunk generation starts
var queue_timer:int = 0;

@onready var world = get_node("/root/GameScene/World")



# Initalize persistent variables used on every chunk.
func setup():
	# Noise
	noise.stone = Helpers.create_noise( world.w_seed + 1, 0.003, 3 )
	noise.dirt = Helpers.create_noise( world.w_seed + 2, 0.001, 3 )
	noise.mountain = Helpers.create_noise( world.w_seed + 3, 0.002, 3 )
	noise.humidity = Helpers.create_noise( world.w_seed + 10, 0.002, 3 )
	noise.lava = Helpers.create_noise( world.w_seed + 4, 0.005, 2 )

	Yaml.chunky()

	noise.trees = Helpers.create_noise( world.w_seed + 10, 0.02, 5 )
	noise.layers = Helpers.create_noise( world.w_seed + 40, 0.008, 2 )

	# Ensure underground tiles are registered
	var _ug = Tiles.UNDERGROUND


func queue_chunk( chunk_num:int, target_state:int):
	var queue_arr = [chunk_num, target_state]
	if chunk_queue.find(queue_arr) == -1:
		chunk_queue.push_front(queue_arr)


#  ------------------
#    WORLD FEATURES
#  ------------------

# feature_tree: build a tree at (x,y)
func gen_feature_tree(x, y, height):
	# print("Placing tree at ("+str(x)+", "+str(y)+").")
	var trunk_replacable = [Tiles.AIR, DataTile.tile("blockforge:leaves")]
	# verify no blockages
	for h in height:
		if world.tile_matches(x, y+h, trunk_replacable) == false:
			print("Tree at obstructed at "+Helpers.coord_string(x, y))
			return false
	
	# save tiles to prevent repeat hash lookups
	var tile_log: DataTile = DataTile.tile("blockforge:log")
	var tile_leaves: DataTile = DataTile.tile("blockforge:leaves")

	# place trunk
	for h in height:
		world.place_tile( x, y+h, tile_log )
	
	# Prepare for leaf placement
	var leaf_btm = int( height * 0.4 )
	var width = int( height * 0.75 )
	
	var h = 0
	while width >= 0:
		var ly = leaf_btm + h
		for lx in width:
			world.place_tile_overwrite(x + lx, y + ly, tile_leaves, [Tiles.AIR] )
			world.place_tile_overwrite(x - lx, y + ly, tile_leaves, [Tiles.AIR] )
		width -= 0.5
		h += 1

	return true


# Place a portal. If is_natural is true, use a stone base, otherwise use cobble base.
func gen_feature_portal( x, y, is_natural=false):
	# Test for blockages
	if world.get_tile( x, y+1 ) != Tiles.AIR || world.get_tile( x, y+2 ) != Tiles.AIR:
		print("Portal at obstructed at "+Helpers.coord_string(x, y))
		return false

	#place base
	if is_natural:
		world.place_tile( x, y, DataTile.tile("blockforge:portal_base_stone"))
	else:
		world.place_tile( x, y, DataTile.tile("blockforge:portal_base_cobble"))
	
	# place portal
	world.place_tile( x, y+1, DataTile.tile("blockforge:portal_btm"))
	world.place_tile( x, y+2, DataTile.tile("blockforge:portal_top"))
	print("Portal placed at: " + Helpers.coord_string(x, y) )
	return true



#  ------------------
#    WORLDGEN STEPS
#  ------------------

# Dig caves: tin-style stringy clumps, then irregular ~10-block caverns at junctions (same noise).
func dig_caves( chunk_num: int ):
	var chunk: Chunk = world.chunks[chunk_num]
	var air: DataTile = Tiles.AIR

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
		var cave_noise = Helpers.noise_array_2d_offset(cave_noisegen, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(chunk_num * Chunk.WIDTH, 0))
		var jitter_gen = Helpers.create_noise(world.w_seed + ("cave_jitter_" + cave_name).hash(), freq * 2.5, 2)
		var jitter_noise = Helpers.noise_array_2d_offset(jitter_gen, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(chunk_num * Chunk.WIDTH, 0))
		var chamber_rng := RandomNumberGenerator.new()
		chamber_rng.seed = world.w_seed + chunk_num * 9176 + cave_name.hash()

		var tunnel_mask: Dictionary = {} # Vector2i -> true
		var carved := 0
		var chambers := 0

		# Pass 1: stringy tunnels (same as tin ore clumps)
		for x in Chunk.WIDTH:
			var y0: int = chunk.lava_top[x]
			var y1: int = chunk.rock_top[x]
			var band_h: int = y1 - y0
			if band_h <= 0:
				continue
			for y in range(y0, y1):
				var local_f: float = float(y - y0) / float(band_h)
				if local_f < min_f or local_f > max_f:
					continue
				var pos := Vector2i(x, y)
				var dist: float = absf(cave_noise[pos] - 0.5)
				if dist <= width:
					chunk.place_tile_chunk(x, y, air)
					tunnel_mask[pos] = true
					carved += 1

		# Pass 2: caverns at vein cores that look like junctions
		var seeds: Array[Vector2i] = []
		for pos in tunnel_mask:
			var dist: float = absf(cave_noise[pos] - 0.5)
			if dist > chamber_core:
				continue
			if _cave_tunnel_branches(tunnel_mask, pos) < chamber_min_branches:
				continue
			# Prefer local core of the vein so one junction → one chamber
			if not _cave_is_local_core(cave_noise, tunnel_mask, pos):
				continue
			seeds.append(pos)

		var used_seeds: Array[Vector2i] = []
		for seed_pos in seeds:
			if chamber_rng.randf() > chamber_chance:
				continue
			var too_close := false
			for prev in used_seeds:
				if seed_pos.distance_squared_to(prev) < 64: # ~8 blocks apart
					too_close = true
					break
			if too_close:
				continue
			var t: float = clampf(jitter_noise[seed_pos], 0.0, 1.0)
			var base_r: float = lerpf(chamber_r_min, chamber_r_max, t)
			var carved_here: int = _cave_carve_irregular(chunk, seed_pos, base_r, chamber_jitter, jitter_noise, air, tunnel_mask)
			if carved_here > 0:
				used_seeds.append(seed_pos)
				chambers += 1
				carved += carved_here

		print("  Chunk %d: cave %s carved %d (%d chambers)" % [chunk_num, cave_name, carved, chambers])


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


func _cave_carve_irregular( chunk: Chunk, center: Vector2i, radius: float, jitter: float, jitter_noise: Dictionary, air: DataTile, tunnel_mask: Dictionary ) -> int:
	var carved := 0
	var r_ceil: int = ceili(radius + jitter * radius)
	for dx in range(-r_ceil, r_ceil + 1):
		for dy in range(-r_ceil, r_ceil + 1):
			var px: int = center.x + dx
			var py: int = center.y + dy
			if px < 0 or px >= Chunk.WIDTH:
				continue
			if py < chunk.lava_top[px] or py >= chunk.rock_top[px]:
				continue
			var pos := Vector2i(px, py)
			var j: float = jitter_noise.get(pos, 0.5)
			var local_r: float = radius * (1.0 + (j - 0.5) * 2.0 * jitter)
			if float(dx * dx + dy * dy) > local_r * local_r:
				continue
			if tunnel_mask.has(pos):
				continue
			chunk.place_tile_chunk(px, py, air)
			tunnel_mask[pos] = true
			carved += 1
	return carved



func gen_steps_trees( chunk_num ):
	print("  Generating trees...")
	
	var feature_trees = Helpers.noise_array_1d( noise.trees, Chunk.WIDTH, chunk_num*Chunk.WIDTH )
	var tree_placement = Helpers.array_local_max(feature_trees)
	var tree_height = Helpers.array_scale(feature_trees, WG_Settings.TREE_HEIGHT_MAX, WG_Settings.TREE_HEIGHT_MIN) 
	# need to include noise in the scale, so that the height is smoothish

	
	for x in Chunk.WIDTH:
		var world_x = chunk_num*Chunk.WIDTH + x
		var surface: int = world.get_surface(world_x)
		if tree_placement[x] == 1 && Helpers.is_growable( world.get_tile(world_x, surface ) ) : # Place trees above growable tiles
			gen_feature_tree( world_x, surface+1, clamp( tree_height[x], WG_Settings.TREE_HEIGHT_MIN, WG_Settings.TREE_HEIGHT_MAX ) )


# surface_dressing: soil, topsoil, trees, and portal for a finished base-terrain chunk
func surface_dressing( chunk_num: int ):
	var chunk: Chunk = world.chunks[chunk_num]
	print("  Surface dressing chunk %d..." % chunk_num)

	# Dirt/sand + topsoil
	for x in Chunk.WIDTH:
		var rock_top: int = chunk.rock_top[x]
		var surface: int = chunk.surface_level[x]
		var world_x: int = chunk_num*Chunk.WIDTH + x

		for y in range(rock_top, surface):
			if chunk.humidity[x] < WG_Settings.DESERT_HUMIDITY_MAX:
				world.place_tile( world_x, y, Chunk.tiles.sand )
			else:
				world.place_tile( world_x, y, Chunk.tiles.dirt )

		if chunk.humidity[x] < WG_Settings.DESERT_HUMIDITY_MAX:
			world.place_tile( world_x, surface, Chunk.tiles.sand )
		elif chunk.mountain_height[x] > WG_Settings.MOUNTAIN_SNOW_ALTITUDE:
			world.place_tile( world_x, surface, Chunk.tiles.snow )
		else:
			world.place_tile( world_x, surface, Chunk.tiles.grass )

	# Portal (once), if this chunk holds the portal column — before trees
	if world.world_portal_pos.y == 0:
		var portal_chunk: int = world.world_portal_pos.x / Chunk.WIDTH
		if chunk_num == portal_chunk:
			world.world_portal_pos.y = world.get_surface(world.world_portal_pos.x)
			gen_feature_portal( world.world_portal_pos.x, world.world_portal_pos.y, true )
			move_camera.emit(world.world_portal_pos)
			character_to_portal.emit(world.world_portal_pos)

	# Trees
	gen_steps_trees(chunk_num)

	# Surface inclusions (flint/clay in dirt, black sand in sand)
	generate_inclusions(chunk_num, false)


### host tiles from config string array
func _hosts_from_cfg( host_names: Array ) -> Array:
	var out: Array = []
	for n in host_names:
		out.append(DataTile.tile(str(n)))
	return out


# generate_layers: multiple tapered horizontal lenses at random depths within height_min..height_max
# Layer inclusions (oil/sandstone/red marble/lapis) are placed while writing the layer.
# Process limestone before marble so marble can overwrite limestone on overlap.
func generate_layers( chunk_num: int ):
	var chunk: Chunk = world.chunks[chunk_num]
	var rng := RandomNumberGenerator.new()
	rng.seed = world.w_seed + chunk_num * 7919 + 17
	var all_incl: Dictionary = Yaml.chunky("inclusions")
	var layers: Dictionary = Yaml.chunky("layers")

	for layer_name in layers:
		var cfg: Dictionary = layers[layer_name]
		var layer_tile: DataTile = DataTile.tile(str(cfg.get("tile", "")))
		if layer_tile == DataTile.UNDEFINED:
			continue
		var hosts: Array = _hosts_from_cfg(cfg.get("host", []))
		# Prefer height_min/max; fall back to legacy min/max_depth_fraction
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
			while x < Chunk.WIDTH:
				var seg_len: int = rng.randi_range(seg_min, seg_max)
				var base_thick: float = rng.randf_range(thick_min, thick_max)
				# Per-lens random depth within [height_min, height_max]
				var lens_center_f: float = rng.randf_range(min_f, max_f)
				for lx in seg_len:
					var cx: int = x + lx
					if cx >= Chunk.WIDTH:
						break
					var lava_top: int = chunk.lava_top[cx]
					var rock_top: int = chunk.rock_top[cx]
					var rock_h: int = rock_top - lava_top
					if rock_h <= 1:
						continue
					# taper: 0 at ends, 1 at center
					var t: float = float(lx) / float(maxi(seg_len - 1, 1))
					var taper: float = 1.0 - absf(2.0 * t - 1.0)
					var thickness: int = int(round(base_thick * taper))
					thickness = clampi(thickness, 1, thick_max)

					var nwarp: float = noise.layers.get_noise_2d(chunk_num * Chunk.WIDTH + cx, lens_center_f * 100.0 + float(_lens) * 17.0) * warp
					var center_f: float = clampf(lens_center_f + nwarp, min_f, max_f)
					var center_y: int = lava_top + int(center_f * rock_h)
					var half: int = thickness / 2
					for dy in range(-half, thickness - half):
						var gy: int = center_y + dy
						if gy < lava_top or gy >= rock_top:
							continue
						var world_x: int = chunk_num * Chunk.WIDTH + cx
						if world.place_tile_overwrite(world_x, gy, layer_tile, hosts):
							for iname in incl_names:
								if not all_incl.has(iname):
									continue
								var icfg: Dictionary = all_incl[iname]
								if not bool(icfg.get("during_layer", true)):
									continue
								if rng.randf() > float(icfg.get("rarity", 0.05)):
									continue
								var itile: DataTile = DataTile.tile(str(icfg.get("tile", "")))
								if itile != DataTile.UNDEFINED:
									world.place_tile(world_x, gy, itile)
				x += seg_len + rng.randi_range(gap_min, gap_max)


# generate_ores: noise clumps constrained to host layer depth bands (config-driven)
func generate_ores( chunk_num: int ):
	var chunk: Chunk = world.chunks[chunk_num]
	var ores: Dictionary = Yaml.chunky("ores")
	for ore_name in ores:
		var cfg: Dictionary = ores[ore_name]
		var ore_tile: DataTile = DataTile.tile(str(cfg.get("tile", "")))
		if ore_tile == DataTile.UNDEFINED:
			continue
		var hosts: Array = _hosts_from_cfg(cfg.get("host", []))
		var host_layer: String = str(cfg.get("host_layer", "stone"))
		var min_f: float = float(cfg.get("min_depth_fraction", 0.0))
		var max_f: float = float(cfg.get("max_depth_fraction", 1.0))
		var width: float = float(cfg.get("clump_size", cfg.get("width", 0.1)))
		var freq: float = float(cfg.get("freq", 0.04))

		var ore_noisegen = Helpers.create_noise(world.w_seed + str(cfg.get("tile", ore_name)).hash(), freq, 2)
		var ore_noise = Helpers.noise_array_2d_offset(ore_noisegen, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(chunk_num * Chunk.WIDTH, 0))
		var placed := 0

		for x in Chunk.WIDTH:
			var bands: Array = _ore_y_bands(chunk, x, host_layer)
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
					# Fixed noise center 0.5; abundance via freq + clump_size only
					var noise_val: float = ore_noise[Vector2i(x, y)]
					if absf(noise_val - 0.5) <= width:
						if world.place_tile_overwrite(x + chunk_num * Chunk.WIDTH, y, ore_tile, hosts):
							placed += 1
		print("  Chunk %d: %s placed %d" % [chunk_num, ore_name, placed])


func _ore_y_bands( chunk: Chunk, x: int, host_layer: String ) -> Array:
	# returns array of [y_min, y_max) bands in chunk-local coords
	var bands: Array = []
	match host_layer:
		"cobble":
			bands.append([chunk.stone_top[x], chunk.rock_top[x]])
		"stone":
			bands.append([chunk.lava_top[x], chunk.stone_top[x]])
		"cobble_and_stone":
			bands.append([chunk.lava_top[x], chunk.stone_top[x]])
			bands.append([chunk.stone_top[x], chunk.rock_top[x]])
		_:
			bands.append([chunk.lava_top[x], chunk.rock_top[x]])
	return bands


# generate_inclusions: non-layer inclusions (dirt/sand). Layer inclusions happen in generate_layers.
func generate_inclusions( chunk_num: int, during_layer_only: bool = false ):
	var chunk: Chunk = world.chunks[chunk_num]
	var rng := RandomNumberGenerator.new()
	rng.seed = world.w_seed + chunk_num * 4999 + 91

	var inclusions: Dictionary = Yaml.chunky("inclusions")
	for iname in inclusions:
		var cfg: Dictionary = inclusions[iname]
		var during: bool = bool(cfg.get("during_layer", false))
		if during_layer_only and not during:
			continue
		if not during_layer_only and during:
			continue
		var itile: DataTile = DataTile.tile(str(cfg.get("tile", "")))
		if itile == DataTile.UNDEFINED:
			continue
		var hosts: Array = _hosts_from_cfg(cfg.get("host", []))
		var rarity: float = float(cfg.get("rarity", 0.05))
		var clump: float = float(cfg.get("clump_size", 0.1))
		var incl_noise = Helpers.create_noise(world.w_seed + str(cfg.get("tile", iname)).hash(), 0.06, 2)
		var noise_map = Helpers.noise_array_2d_offset(incl_noise, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(chunk_num * Chunk.WIDTH, 0))

		var placed := 0
		for x in Chunk.WIDTH:
			var y_hi: int = chunk.surface_level[x] + 1
			for y in y_hi:
				var nv: float = noise_map[Vector2i(x, y)]
				# clump around low noise values
				if nv < rarity and absf(nv - rarity * 0.5) < clump:
					if world.place_tile_overwrite(x + chunk_num * Chunk.WIDTH, y, itile, hosts):
						placed += 1
		if placed > 0:
			print("  Chunk %d: inclusion %s placed %d" % [chunk_num, iname, placed])


# chunky_filling: sedimentary lenses, caves, then ore clumps
func chunky_filling( chunk_num: int ):
	print("  Chunky filling chunk %d..." % chunk_num)

	generate_layers(chunk_num)
	dig_caves(chunk_num)
	generate_ores(chunk_num)


# Overall chunk generation.
func generate_chunk( n: int, target_state: int = 3):

	if n < 0 or n > world.width:
		print("generate_chunk(n=%d, target_state=%d): invalid n." % [n , target_state])
		return false

	var chunk: Chunk = world.chunks[n]
	print("Chunk %d: target:%d" % [n, target_state])
	
	if chunk.gen_state == 0:
		print("Generating Chunk "+str(n)+" state 1: Terrain & Caves.")
		var timer_start = Time.get_ticks_usec()

		# Forming Terrain
		chunk = Chunk.generate_chunk_threadsafe(n, noise) # overwrites chunk, but at gen_state=0 everything is empty
		var timer_terrain = Time.get_ticks_usec()
		print("  Chunk %d: Terrain done in %.3fms." % [n, (timer_terrain-timer_start)/1000.0])

		world.chunks[n] = chunk
		chunky_filling(n)
		var timer_filling = Time.get_ticks_usec()
		print("  Chunk %d: Chunky filling done in %.3fms." % [n, (timer_filling-timer_terrain)/1000.0])

		chunk.write_to_tilemap(world.tilemap)

		chunk.gen_state = 1

		var timer_end = Time.get_ticks_usec()
		print("  Chunk %d: Tilemap done in %.3fms." % [n, (timer_end-timer_filling)/1000.0])
		print("  Chunk %d: gen_state = 1 in %.3fms." % [n, (timer_end-timer_start)/1000.0])
	
	if chunk.gen_state >= target_state: # Target exists and is now (or was) at or above it's target state
		return true

	if  chunk.gen_state == 1 && target_state >= 2:
		print("Generating Chunk "+str(n)+" state 2: Gen neighbors to state 1.")
		var timer_s2 = Time.get_ticks_usec()

		# check neighbors
		var left = n-1
		var right = n+1
		var gen_left: bool = left > 0 and world.chunks[left].gen_state < 1
		var gen_right: bool = right < world.width and world.chunks[right].gen_state < 1
		
		# requeue this chunk if either neighbor needs generation AND this chunk needs to go further
		var requeue = gen_left or gen_right && target_state > 2
		if requeue: 
			print("  Chunk %d: Requeuing after neighbors..." % [n])
			queue_chunk(n, target_state)
		# generate neighbors as needed
		if gen_left:
			queue_chunk(left, 1)
		if gen_right:
			queue_chunk(right, 1)

		chunk.gen_state = 2

		var timer_s2_end = Time.get_ticks_usec()
		print("  Chunk %d: gen_state = 2 in %.3fms." % [n, (timer_s2_end-timer_s2)/1000.0])
		if requeue:
			return false

	# gen_state 3: Surface dressing (soil, topsoil, trees, portal) and ores
	if chunk.gen_state == 2 and target_state >= 3:
		print("Generating Chunk "+str(n)+" state 3: Surface dressing.")
		var timer_s3 = Time.get_ticks_usec()

		surface_dressing(n)

		var timer_dressing = Time.get_ticks_usec()
		print("  Chunk %d: Surface dressing done in %.3fms." % [n, (timer_dressing-timer_s3)/1000.0])

		# Stage 3 done
		chunk.gen_state = 3

		var timer_s3_end = Time.get_ticks_usec()
		print("  Chunk %d: gen_state = 3 in %.3fms." % [n, (timer_s3_end-timer_s3)/1000.0])

	

	
	
func _ready():
	gentimer_start.emit()
	setup()
	queue_timer = QUEUE_DELAY
	for i in world.width:
		chunk_queue.append([i, 3])
	# chunk_queue = [[2, 3]]
	# chunk_queue = [[2,3],[6,3],[4,3]]


func _physics_process(delta):
	# Portal X selection (placement happens in surface_dressing)
	if world.world_portal_pos == Vector2i.ZERO: # World portal not set, 
		world.world_portal_pos.x = rand_from_seed( world.w_seed )[0] % ( world.width_tiles / 2 )
		world.world_portal_pos.x += world.width_tiles * 0.25 # keep portal in middle half.
		var world_portal_chunk = world.world_portal_pos.x/Chunk.WIDTH
		queue_chunk(world_portal_chunk, Chunk.GEN_STATE_MAX) # Queue the portal chunk
		print("Portal will be at "+str(world.world_portal_pos.x)+" in chunk "+ str(world_portal_chunk))
		
		# Move camera to portal chunk
		move_camera.emit(Vector2i(world.world_portal_pos.x, Chunk.HEIGHT/2))
		print("camera moved to "+ str(Vector2(world.world_portal_pos.x, Chunk.HEIGHT/2)))

	if queue_timer > 0:
		queue_timer -= delta
	if queue_timer <= 0 and len(chunk_queue) > 0:
		queue_timer = QUEUE_DELAY
		print("\nchunk_queue: "+str(chunk_queue))
		var next = chunk_queue.pop_front()
		generate_chunk( next[0], next[1] )

	if chunk_queue.size() == 0 and generation_working:
		gentimer_stop.emit()
		generation_working = false
	
