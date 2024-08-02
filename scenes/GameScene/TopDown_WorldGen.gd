extends TileMap
# Attach to TileMap to use


# Generator Attributes
# Tilemap
@onready var tilemap = get_node("/root/GameScene/TileMap")
# World info
var width = 500
var height = 500
var world_seed = 954645

# Random value
var random = 0

# Noise arrays
var altitude = {}
var biome = {}

# Noise Instance
var noise_generator = FastNoiseLite.new()

#Tile arrays
var tiles = {
	"dirt":Vector2i(1, 0),
	"stone":Vector2i(2, 0),
	"cobblestone":Vector2i(3, 0),
	"water":Vector2i(4,0),
	"sand":Vector2i(5, 0),
	"snow":Vector2i(6, 0)
}

# Biome Array
var biomes = {
	"ocean":{"water":1},
	"beach":{"sand":1},
	"forest":{"dirt":1},
	"mountain":{"snow":1}
}

# Helper funcs

# generate_noise( frequency, octaves, seed )
#	frequency: higher makes more fine details, lower is smoother
#	octaves: how many layers are used
#	seed: the numerical seed to use for random generation
func generate_noise( freq, oct, seed ):
	noise_generator.seed = seed
	noise_generator.frequency = freq
	noise_generator.fractal_octaves = oct
	noise_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var grid = {}
	for x in width:
		for y in height:
			random = ( abs( noise_generator.get_noise_2d(x, y) ) )
			grid[Vector2(x, y) ] = random
	return grid

func choose_tile( data, biome ):
	var actual_biome = data[biome]
	var random_number = randf_range(0.0, 1.0)
	var running_total = 0.0
	for tile in actual_biome:
		running_total = running_total + actual_biome[tile]
		if random_number <= running_total:
			return tile

# Generator functions
func generate_tiles(width, height):
	for x in range(height):
		for y in range(width):
			var pos = Vector2i(x, y)
			var pos_float = Vector2(pos.x, pos.y)
			var alt = altitude[pos_float]
			
			if alt < 0.2:
				biome[pos_float] = "ocean"
				var tile_pos = tiles[choose_tile(biomes, "ocean")]
				tilemap.set_cell(0, pos, 5, tile_pos)
			elif alt < 0.22:
				biome[pos_float] = "beach"
				var tile_pos = tiles[choose_tile(biomes, "beach")]
				tilemap.set_cell(0, pos, 5, tile_pos)
			elif alt < 0.7:
				biome[pos_float] = "forest"
				var tile_pos = tiles[choose_tile(biomes, "forest")]
				tilemap.set_cell(0, pos, 5, tile_pos)
			elif alt >= 0.7:
				biome[pos_float] = "mountain"
				var tile_pos = tiles[choose_tile(biomes, "mountain")]
				tilemap.set_cell(0, pos, 5, tile_pos)

# Hanlde inputs
func _input( event ):
	if event.is_action_pressed("ui_accept"):
		print("Generating new seed...")
		world_seed = randi_range(0, 9999999)
		print("Seed is now " + str(world_seed) + ". Regenerating...")
		#get_tree().reload_current_scene()
		altitude = generate_noise( 0.00050, 25, world_seed)
		generate_tiles( width, height )

# Main function START
func _ready():
	randomize()
	altitude = generate_noise( 0.00050, 25, world_seed)
	generate_tiles( width, height )
	
	# Main function END
