# Chunk class
class_name Chunk


const WIDTH: int = 128
const HEIGHT: int = 512

var cx = 0
var grid = {}
var surface_level = []
var humidity = []

static var tiles = {
	stone = DataTile.tile("blockforge:stone"),
	cobblestone = DataTile.tile("blockforge:cobblestone"),
	dirt = DataTile.tile("blockforge:dirt"),
	grass = DataTile.tile("blockforge:grass"),
	snow = DataTile.tile("blockforge:snow"),
	sand = DataTile.tile("blockforge:sand"),
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
				# tilemap.set_cell(0, pos_tile, grid[pos].atlas, grid[pos].sprite )
				tilemap.set_cell(0, pos_tile, grid[pos].texture.atlas, grid[pos].texture.pos )


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


# using Chunk x and a dict of generators, return a chunk generated to the terrain step.
static func generate_chunk_threadsafe( chunk_x: int, gen ):
	# print("Generating chunk " + str(chunk_x) + "...")
	var chunk = Chunk.new(chunk_x)

	var x_offset = WIDTH * chunk_x
	var depth_stone = Helpers.noise_array_1d( gen.stone, WIDTH, x_offset)
	var depth_dirt = Helpers.noise_array_1d( gen.dirt, WIDTH, x_offset)
	var mountain = Helpers.noise_array_1d( gen.mountain, WIDTH, x_offset)
	chunk.humidity = Helpers.noise_array_1d( gen.humidity, WIDTH, x_offset )
	# var feature_trees = Helpers.noise_array_1d( tree_gen, Chunk.WIDTH, x_offset )

	# scale the arrays
	mountain = Helpers.array_scale(mountain, WG_Settings.MOUNTAIN_HEIGHT_SCALE, WG_Settings.MOUNTAIN_HEIGHT_OFFSET)
	depth_stone = Helpers.array_scale(depth_stone, WG_Settings.LAYER_COBBLESTONE_SCALE, WG_Settings.LAYER_COBBLESTONE_OFFSET) # 32 + (0 to 64)
	depth_dirt = Helpers.array_scale(depth_dirt, 3, 4) # should make the depth 3 + (0 to 4)
	
	# var tree_placement = array_local_max(feature_trees)
	# var tree_height = array_scale(feature_trees, 8, 3)

	chunk.surface_level.resize(WIDTH)
	

	for x in range(WIDTH):

		chunk.surface_level[x] = mountain[x] + depth_stone[x] + depth_dirt[x] 
		var diff = chunk.surface_level[x] - HEIGHT - 16
		if( diff > 0 ): # minimum 16 blocks between surface and chunk ceiling
			
			if mountain[x] < diff:
				depth_stone[x] = depth_stone[x] - (diff - mountain[x])
				mountain[x] = 0
			else:
				mountain[x] = mountain[x] - diff
			
			chunk.surface_level[x] = chunk.surface_level[x] - diff
			
			# print("Reducing height by "+ str(diff) + " at x=" + str(x))
			print("surface at x="+ str(x) + " is reduced to y=" + str(chunk.surface_level[x]))
		
		# truncate surface_level to int
		chunk.surface_level[x] = int(chunk.surface_level[x])

		for y in range( 0, chunk.surface_level[x]):

			if y < mountain[x]:	# Mountain layer
				chunk.place_tile_chunk( x, y, tiles.stone)
			
			elif y < mountain[x]+depth_stone[x]:	# Stone layer
				chunk.place_tile_chunk( x, y, tiles.cobblestone)

			elif y < mountain[x]+depth_stone[x]+depth_dirt[x]:	# Soil layer
				if( chunk.humidity[x] < WG_Settings.DESERT_HUMIDITY_MAX ):
					chunk.place_tile_chunk( x, y, tiles.sand)
				else:
					chunk.place_tile_chunk( x, y, tiles.dirt)
			
			if( chunk.humidity[x] < WG_Settings.DESERT_HUMIDITY_MAX ): # Topsoil
				chunk.place_tile_chunk( x, mountain[x]+depth_stone[x]+depth_dirt[x], tiles.sand )
			elif( mountain[x] > WG_Settings.MOUNTAIN_SNOW_ALTITUDE ):
				chunk.place_tile_chunk( x, mountain[x]+depth_stone[x]+depth_dirt[x], tiles.snow )
			else:
				chunk.place_tile_chunk( x, mountain[x]+depth_stone[x]+depth_dirt[x], tiles.grass )

	# print("Done generating chunk " + str(chunk_x) + "...")
	return chunk
