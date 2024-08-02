extends Node

class_name WorldGenerator

@onready var world = get_node("/root/GameScene/World")
@onready var tilemap = get_node("/root/GameScene/World/TileMap")
@onready var camera = get_node("/root/GameScene/World/Camera2D")
@onready var progressbar = get_node("/root/GameScene/World/Camera2D/Control/GeneratorProgress")


signal timer_start
signal timer_stop

var generating_progress = -1
var num_features = 3
var generators = {}

var chunk_threads = []


### FEATURE FUNCTIONS

# feature_tree: build a tree at (x,y)
func gen_feature_tree(x, y, height):
	# print("Placing tree at ("+str(x)+", "+str(y)+").")
	var trunk_replacable = [DataTile.UNDEFINED, Tiles.TERRAIN.LEAVES]
	# verify no blockages
	for h in height:
		if world.tile_matches(x, y+h, trunk_replacable) == false:
			print("Tree at obstructed at "+Helpers.coord_string(x, y))
			return false
	# place trunk
	for h in height:
		world.place_tile( x, y+h, Tiles.TERRAIN.LOG )
	
	# Prepare for leaf placement
	var leaf_btm = int( height * 0.4 )
	var width = int( height * 0.75 )
	
	var h = 0
	while width >= 0:
		var ly = leaf_btm + h
		for lx in width:
			world.place_tile_overwrite(x + lx, y + ly, Tiles.TERRAIN.LEAVES, [DataTile.UNDEFINED] )
			world.place_tile_overwrite(x - lx, y + ly, Tiles.TERRAIN.LEAVES, [DataTile.UNDEFINED] )
		width -= 0.5
		h += 1

	return true


# Place a portal. If is_natural is true, use a stone base, otherwise use cobble base.
func gen_feature_portal( x, y, is_natural=false):
	# Test for blockages
	if world.get_tile( x, y+1 ) != DataTile.UNDEFINED || world.get_tile( x, y+2 ) != DataTile.UNDEFINED:
		print("Portal at obstructed at "+Helpers.coord_string(x, y))
		return false

	#place base
	if is_natural:
		world.place_tile( x, y, Tiles.PORTAL.BASE_STONE)
	else:
		world.place_tile( x, y, Tiles.PORTAL.BASE_COBBLE)
	
	# place portal
	world.place_tile( x, y+1, Tiles.PORTAL.F1_BTM)
	world.place_tile( x, y+2, Tiles.PORTAL.F1_TOP)
	print("Portal placed at: " + Helpers.coord_string(x, y) )
	return true



### GENERATION STEPS

func gen_steps_caves( wseed: int ):
	print("Generating Caves...")

	var CAVE_REPLACABLE = [ Tiles.TERRAIN.STONE, Tiles.TERRAIN.COBBLESTONE ]
	
	var noodle_gen = Helpers.create_noise( wseed + 20, 0.02, 2 )
	var noodle_noise = Helpers.noise_array_2d( noodle_gen, Vector2i(world.width_tiles, Chunk.HEIGHT), true )

	var tube_gen = Helpers.create_noise( wseed + 21, 0.025, 2 )
	var tube_noise = Helpers.noise_array_2d( tube_gen, Vector2i(world.width_tiles, Chunk.HEIGHT) )

	var backfill_gen = Helpers.create_noise( wseed + 28, 0.03, 2 )
	var backfill_noise = Helpers.noise_array_2d( backfill_gen, Vector2i(world.width_tiles, Chunk.HEIGHT) )

	var occlusion_gen = Helpers.create_noise( wseed + 29, 0.03, 2 ) # Occlude caves at top and bottom
	var occlusion_noise = Helpers.noise_array_2d( occlusion_gen, Vector2i(world.width_tiles, Chunk.HEIGHT) )

	for x in world.width_tiles:
		for y in world.get_surface(x):
			var depth_factor = pow(1.02, y) / y * ( 1000 / world.get_surface(x))
			var cave_blocked = occlusion_noise[Vector2i(x, y)] * depth_factor > 0.6 || backfill_noise[Vector2i(x, y)] > 0.8

			if noodle_noise[Vector2i(x, y)] < 0.05 && backfill_noise[Vector2i(x, y)] < 0.7 && !cave_blocked: 
				world.place_tile_overwrite(x, y, Tiles.AIR, CAVE_REPLACABLE)
			
			if tube_noise[Vector2i(x, y)] < 0.02 && backfill_noise[Vector2i(x, y)] < 0.8 && !cave_blocked: 
				world.place_tile_overwrite(x, y, Tiles.AIR, CAVE_REPLACABLE)
			
			# if cave_blocked: 
			# 	world.place_tile(x, y, DataTile.UNDEFINED)


func gen_steps_trees( wseed: int ):
	print("Generating trees...")

	var tree_gen = Helpers.create_noise( wseed + 10, 0.02, 5 )
	var feature_trees = Helpers.noise_array_1d( tree_gen, world.width_tiles )

	var tree_placement = Helpers.array_local_max(feature_trees)
	var tree_height = Helpers.array_scale(feature_trees, 8, 3)

	
	for x in range( 0, world.width_tiles ):
		var surface: int = world.get_surface(x)
		if tree_placement[x] == 1 && Helpers.is_growable( world.get_tile(x, surface ) ) : # Place trees above growable tiles
			gen_feature_tree( x, surface+1, clamp( tree_height[x], WG_Settings.TREE_HEIGHT_MIN, WG_Settings.TREE_HEIGHT_MAX ) )


func gen_steps_world_portal():
	# Select a location for the World Portal.
	world.world_portal_pos.x = rand_from_seed( world.w_seed )[0] % ( world.width_tiles / 2 )
	world.world_portal_pos.x += world.width_tiles * 0.25 # keep portal in middle half.
	world.world_portal_pos.y = world.get_surface(world.world_portal_pos.x )

	# Build World Portal
	gen_feature_portal( world.world_portal_pos.x, world.world_portal_pos.y, true )



### GENERATION FUNCTIONS

# generate an array of chunks sized by save_data[world_size] Vector2i in world_data.gd
func generate_world( ):
	timer_start.emit()
	world.tilemap = tilemap
	var wseed = world.w_seed
	chunk_threads.resize(world.width)

	# Noise generators
	generators.stone = Helpers.create_noise( wseed + 1, 0.003, 25 )
	generators.dirt = Helpers.create_noise( wseed + 2, 0.001, 10 )
	generators.mountain = Helpers.create_noise( wseed + 3, 0.002, 3 )
	generators.humidity = Helpers.create_noise( wseed + 10, 0.002, 3 )
	# temperature_gen for snow

	# Start generating chunks.
	world.chunks.resize(world.width)
	generating_progress = 0

	for i in world.width:
		chunk_thread_start( i )
	
	#TEST: PASS get_tile
	# testing_get_tile()



### UNIT TESTING FUNCTIONS

func testing_place_outside_world():
	print("TEST: place outside world")
	world.place_tile( -5, -5, Tiles.TERRAIN.COBBLESTONE )
	world.place_tile( 5, -5, Tiles.TERRAIN.COBBLESTONE )
	world.place_tile( -5, 5, Tiles.TERRAIN.COBBLESTONE )
	world.place_tile( world.width_tiles+5, Chunk.HEIGHT+5, Tiles.TERRAIN.COBBLESTONE )
	world.place_tile( world.width_tiles-5, Chunk.HEIGHT+5, Tiles.TERRAIN.COBBLESTONE )
	world.place_tile( world.width_tiles+5, Chunk.HEIGHT-5, Tiles.TERRAIN.COBBLESTONE )


func testing_get_tile():
	var testx = 1233
	var testy = 222
	var wp = world.world_portal_pos
	print("tile at " + Helpers.coord_string(testx, testy) + " is: "+ world.get_tile(testx, testy).id)
	print("tile at " + Helpers.coord_string(testx, testy+200) + " is: "+ world.get_tile(testx, testy+200).id)
	print("tile at " + Helpers.coord_string(wp.x, wp.y) + " is: "+ world.get_tile(wp.x, wp.y).id)




func regen_world():
	tilemap.clear()
	world.chunks = []
	world.world_portal_pos = Vector2i.ZERO
	world.w_seed = randi()
	print("Regenerating world with seed: "+str(world.w_seed))
	generate_world()

func chunk_thread_start( chunk_x: int ):
	var thread = Thread.new()
	thread.start( chunk_thread_working.bind(chunk_x) )
	chunk_threads[chunk_x] = thread

func chunk_thread_working( chunk_x: int):
	print("Threaded Function started")

	var chunk = Chunk.generate_chunk_threadsafe( chunk_x, generators )

	call_deferred("chunk_thread_done", chunk_x)
	return chunk

func chunk_thread_done( chunk_x: int ):
	var chunk = chunk_threads[chunk_x].wait_to_finish()
	world.chunks[chunk_x] = chunk
	chunk.write_to_tilemap( tilemap )
	generating_progress += 1



### GODOT FUNCTIONS

func _ready():
	progressbar.init( world.width + num_features )
	generate_world()


func _input(event):
	if event.is_action_pressed("world_regenerate"):
		regen_world()


func _process( _delta ):
	progressbar.setval( generating_progress )

	# Generate and focus portal
	if generating_progress == world.width:

		gen_steps_world_portal()
		# Helpers.camera_to( camera, Vector2(world.world_portal_pos.x*16, -world.world_portal_pos.y*16), Vector2(2, 2) )
		generating_progress += 1


	# Generate trees
	elif generating_progress == world.width + 1:
		gen_steps_caves( world.w_seed )
		generating_progress += 1

	# Generate trees
	elif generating_progress == world.width + 2:
		gen_steps_trees( world.w_seed )
		generating_progress += 1


	if generating_progress == world.width + num_features:
		generating_progress = -1
		print("Done Generating")
		timer_stop.emit()
		progressbar.done()
