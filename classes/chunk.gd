# Chunk class
class_name Chunk


const WIDTH: int = 128
const HEIGHT: int = 512

var cx: int = 0
var grid: Dictionary[Vector2i, DataTile] = {}
var humidity: Array[float] = []

var surface_level: Array[int] = []
var rock_top: Array[int] = [] # y where soil starts (above lava/stone/cobble)
var lava_top: Array[int] = [] # y where stone starts (above lava)
var stone_top: Array[int] = [] # y where cobble starts (above stone/mountain)
var mountain_height: Array[int] = [] # used for snow topsoil check
var depth_dirt: Array[int] = [] # soil thickness per column

# TODO: Test if caching tiles here is actually useful
static var tiles: Dictionary[String, DataTile] = {
	stone = DataTile.tile("blockforge:stone"),
	cobblestone = DataTile.tile("blockforge:cobblestone"),
	dirt = DataTile.tile("blockforge:dirt"),
	grass = DataTile.tile("blockforge:grass"),
	snow = DataTile.tile("blockforge:snow"),
	sand = DataTile.tile("blockforge:sand"),
	lava = DataTile.tile("blockforge:lava"),
}

# Store chunk generation progress
# Because features may cross chunk borders, the neighboring chunks should exist and have terrain first.
# 0 = nothing, 1 = terrain & caves, 2 = waiting on nieghbors, 3 = features(trees, ores)
var gen_state = 0
const GEN_STATE_MAX = 3

func _init(chunk_x):
	cx = chunk_x


# For every location in grid, if the position has a tile set, place that tile on the tilemap.
func write_to_tilemap( tilemap ):
	for x in WIDTH:
		for y in HEIGHT:
			var pos = Vector2i(x, y)
			if( grid.has(pos) ):
				var pos_tile = Vector2i(cx*WIDTH + x, -y)
				# tilemap.set_cell(pos_tile, grid[pos].atlas, grid[pos].sprite )
				tilemap.set_cell(pos_tile, grid[pos].texture.atlas, grid[pos].texture.pos )


# place_tile_chunk(): Place a tile based on chunk coordinates. Should be slightly more performant than place_tile where chunk is already known.
func place_tile_chunk( x:int, y:int, tile):
	var pos = Vector2i(x, y)
	grid[pos] = tile

# place_tile_chunk_overwrite(): Place a tile based on chunk coordinates IF the existing tile is in overwrite_tiles
func place_tile_chunk_overwrite( x:int, y:int, tile,  overwrite_tiles):
	var pos = Vector2i(x, y)

	if grid.has(pos):
		var existing_tile = grid[pos]

		if overwrite_tiles.find(existing_tile) != -1:
			grid[pos] = tile
			return true
	return false


# using Chunk x and a dict of generators, return a chunk with base terrain (lava/stone/cobble).
# Soil, topsoil, trees, and portal are applied later by WorldGenV2.surface_dressing().
static func generate_chunk_threadsafe( chunk_x: int, gen ):
	# print("Generating chunk " + str(chunk_x) + "...")
	var chunk = Chunk.new(chunk_x)

	var x_offset: int = WIDTH * chunk_x
	var depth_stone: Array[float] = Helpers.noise_array_1d( gen.stone, WIDTH, x_offset)
	var depth_dirt_noise: Array[float] = Helpers.noise_array_1d( gen.dirt, WIDTH, x_offset)
	var depth_lava: Array[float] = Helpers.noise_array_1d( gen.lava, WIDTH, x_offset)
	var mountain: Array[float] = Helpers.noise_array_1d( gen.mountain, WIDTH, x_offset)
	chunk.humidity = Helpers.noise_array_1d( gen.humidity, WIDTH, x_offset )

	# scale the arrays
	mountain = Helpers.array_scale(mountain, WG_Settings.MOUNTAIN_HEIGHT_SCALE, WG_Settings.MOUNTAIN_HEIGHT_OFFSET)
	depth_stone = Helpers.array_scale(depth_stone, WG_Settings.LAYER_COBBLESTONE_SCALE, WG_Settings.LAYER_COBBLESTONE_OFFSET) # 32 + (0 to 64)
	depth_dirt_noise = Helpers.array_scale(depth_dirt_noise, 3, 4) # should make the depth 3 + (0 to 4)
	depth_lava = Helpers.array_scale(depth_lava, 8, 2) # bottom lava layer 2 + (0 to 8) = 2..10

	chunk.surface_level.resize(WIDTH)
	chunk.rock_top.resize(WIDTH)
	chunk.lava_top.resize(WIDTH)
	chunk.stone_top.resize(WIDTH)
	chunk.mountain_height.resize(WIDTH)
	chunk.depth_dirt.resize(WIDTH)


	for x in range(WIDTH):

		chunk.lava_top[x] = depth_lava[x]
		chunk.stone_top[x] = depth_lava[x] + mountain[x]
		chunk.rock_top[x] = depth_lava[x] + mountain[x] + depth_stone[x]
		chunk.depth_dirt[x] = depth_dirt_noise[x]
		chunk.mountain_height[x] = mountain[x]
		chunk.surface_level[x] = chunk.rock_top[x] + chunk.depth_dirt[x]
		var diff = chunk.surface_level[x] - HEIGHT - 16
		if( diff > 0 ): # minimum 16 blocks between surface and chunk ceiling
			
			if mountain[x] < diff:
				depth_stone[x] = depth_stone[x] - (diff - mountain[x])
				mountain[x] = 0
			else:
				mountain[x] = mountain[x] - diff

			chunk.mountain_height[x] = mountain[x]
			chunk.stone_top[x] = depth_lava[x] + mountain[x]
			chunk.rock_top[x] = depth_lava[x] + mountain[x] + depth_stone[x]
			chunk.surface_level[x] = chunk.rock_top[x] + chunk.depth_dirt[x]
			
			# print("Reducing height by "+ str(diff) + " at x=" + str(x))
			print("surface at x="+ str(x) + " is reduced to y=" + str(chunk.surface_level[x]))
		
		# Base layers only — soil/topsoil applied in surface_dressing
		for y in range( 0, chunk.rock_top[x]):

			if y < chunk.lava_top[x]: 		# Lava layer (bottom of world)
				chunk.place_tile_chunk( x, y, tiles.lava)

			elif y < chunk.stone_top[x]:	# Mountain layer
				chunk.place_tile_chunk( x, y, tiles.stone)
			
			elif y < chunk.rock_top[x]:		# Stone layer
				chunk.place_tile_chunk( x, y, tiles.cobblestone)

	# print("Done generating chunk " + str(chunk_x) + "...")
	return chunk
