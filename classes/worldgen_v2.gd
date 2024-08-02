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


const QUEUE_DELAY:int = 0; # min seconds between chunk generation starts
var queue_timer:int = 0;

@onready var world = get_node("/root/GameScene/World")
@onready var camera = get_node("/root/GameScene/World/Camera2D")



# Initalize persistent variables used on every chunk.
func setup():
  # Noise
  noise.stone = Helpers.create_noise( world.w_seed + 1, 0.003, 25 )
  noise.dirt = Helpers.create_noise( world.w_seed + 2, 0.001, 10 )
  noise.mountain = Helpers.create_noise( world.w_seed + 3, 0.002, 3 )
  noise.humidity = Helpers.create_noise( world.w_seed + 10, 0.002, 3 )

  noise.cave = {}
  noise.cave.noodle = Helpers.create_noise( world.w_seed + 20, 0.02, 2 )
  noise.cave.tube = Helpers.create_noise( world.w_seed + 21, 0.025, 2 )
  noise.cave.backfill = Helpers.create_noise( world.w_seed + 28, 0.03, 2 )
  noise.cave.occlusion = Helpers.create_noise( world.w_seed + 29, 0.03, 2 ) # Occlude caves at top and bottom

  noise.trees = Helpers.create_noise( world.w_seed + 10, 0.02, 5 )


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
  var trunk_replacable = [DataTile.UNDEFINED, DataTile.tile("bh:leaves")]
  # verify no blockages
  for h in height:
    if world.tile_matches(x, y+h, trunk_replacable) == false:
      print("Tree at obstructed at "+Helpers.coord_string(x, y))
      return false
  
  # save tiles to prevent repeat hash lookups
  var tile_log: DataTile = DataTile.tile("bh:log")
  var tile_leaves: DataTile = DataTile.tile("bh:leaves")

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
      world.place_tile_overwrite(x + lx, y + ly, tile_leaves, [DataTile.UNDEFINED] )
      world.place_tile_overwrite(x - lx, y + ly, tile_leaves, [DataTile.UNDEFINED] )
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
    world.place_tile( x, y, DataTile.tile("bh:portal_base_stone"))
  else:
    world.place_tile( x, y, DataTile.tile("bh:portal_base_cobble"))
  
  # place portal
  world.place_tile( x, y+1, DataTile.tile("bh:portal_btm"))
  world.place_tile( x, y+2, DataTile.tile("bh:portal_top"))
  print("Portal placed at: " + Helpers.coord_string(x, y) )
  return true



#  ------------------
#    WORLDGEN STEPS
#  ------------------

# Dig out caves in one chunk
func dig_caves( chunk ):
  var n = chunk.cx
  var noodle_noise = Helpers.noise_array_2d_offset( noise.cave.noodle, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(n*Chunk.WIDTH, 0), true )
  var tube_noise = Helpers.noise_array_2d_offset( noise.cave.tube, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(n*Chunk.WIDTH, 0) )
  var backfill_noise = Helpers.noise_array_2d_offset( noise.cave.backfill, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(n*Chunk.WIDTH, 0) )
  var occlusion_noise = Helpers.noise_array_2d_offset( noise.cave.occlusion, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(n*Chunk.WIDTH, 0) )

  # print(tube_noise)

  # var start_x = n*Chunk.WIDTH
  var bh_air = DataTile.tile("air")

  for x in Chunk.WIDTH:
    for y in chunk.surface_level[x]:
      var depth_factor = pow(1.02, y) / y * ( 1000 / chunk.surface_level[x])
      var cave_blocked = occlusion_noise[Vector2i(x, y)] * depth_factor > 0.6 || backfill_noise[Vector2i(x, y)] > 0.8

      
      if noodle_noise[Vector2i(x, y)] < 0.05 && backfill_noise[Vector2i(x, y)] < 0.7 && !cave_blocked: 
        chunk.place_tile_chunk_overwrite(x, y, bh_air, WG_Settings.CAVE_NOODLE_REPLACABLE)
        # print("noodle")

      if tube_noise[Vector2i(x, y)] < 0.02 && backfill_noise[Vector2i(x, y)] < 0.8 && !cave_blocked: 
        chunk.place_tile_chunk_overwrite(x, y, bh_air, WG_Settings.CAVE_TUBE_REPLACABLE)
        # print("tube")



func gen_steps_trees( chunk_num ):
  print("  Generating trees...")
  
  var feature_trees = Helpers.noise_array_1d( noise.trees, Chunk.WIDTH, chunk_num*Chunk.WIDTH )
  var tree_placement = Helpers.array_local_max(feature_trees)
  var tree_height = Helpers.array_scale(feature_trees, WG_Settings.TREE_HEIGHT_MAX, WG_Settings.TREE_HEIGHT_MAX)

  
  for x in Chunk.WIDTH:
    var world_x = chunk_num*Chunk.WIDTH + x
    var surface: int = world.get_surface(world_x)
    if tree_placement[x] == 1 && Helpers.is_growable( world.get_tile(world_x, surface ) ) : # Place trees above growable tiles
      gen_feature_tree( world_x, surface+1, clamp( tree_height[x], WG_Settings.TREE_HEIGHT_MIN, WG_Settings.TREE_HEIGHT_MAX ) )



### gen_steps_ores
func gen_steps_ores( chunk_num:int, ore_name:String, ore_replacable, max_height:int, rarity:float, width:float, depth_factor:float ):
  print("  Generating ores...")
  var ore_noisegen = Helpers.create_noise( world.w_seed + ore_name.hash(), 0.04, 2 )
  var ore_noise = Helpers.noise_array_2d_offset(ore_noisegen, Vector2i(Chunk.WIDTH, Chunk.HEIGHT), Vector2i(chunk_num*Chunk.WIDTH, 0) )
  
  # var chunk: Chunk = world.chunks[chunk_num]
  var ore_tile: DataTile = DataTile.tile(ore_name)
  if ore_tile == DataTile.UNDEFINED:
    return false
  
  var y_max: int = max_height
  if y_max > Chunk.HEIGHT:
    y_max = Chunk.HEIGHT
  var num_ores_placed: int = 0

  # generate ores
  for y in y_max:
    var y_width: float = width + (float(y_max-y)/y_max)*width*depth_factor
    for x in Chunk.WIDTH:
      var pos:Vector2i = Vector2i(x,y)
      var noise_val: float = ore_noise[pos] 
      if noise_val >= rarity-y_width and noise_val <= rarity+y_width:
        if world.place_tile_overwrite(x+(chunk_num*Chunk.WIDTH), y, ore_tile, ore_replacable):
          num_ores_placed += 1
  return num_ores_placed
  




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

    # Digging Caves
    dig_caves(chunk)
    var timer_caves = Time.get_ticks_usec()
    print("  Chunk %d: Caves done in %.3fms." % [n, (timer_caves-timer_terrain)/1000.0])


    world.chunks[n] = chunk
    chunk.write_to_tilemap(world.tilemap)

    chunk.gen_state = 1

    var timer_end = Time.get_ticks_usec()
    print("  Chunk %d: Tilemap done in %.3fms." % [n, (timer_end-timer_caves)/1000.0])
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

  # gen_state 3: Features( trees, ores, more ). Here we use world place_tile to cross chunk borders
  if chunk.gen_state == 2 and target_state >= 3:
    print("Generating Chunk "+str(n)+" state 3: Features.")
    var timer_s3 = Time.get_ticks_usec()

    # Trees
    gen_steps_trees(n)

    var timer_trees = Time.get_ticks_usec()
    print("  Chunk %d: Trees done in %.3fms." % [n, (timer_trees-timer_s3)/1000.0])

    # Ores
    var num_ores: int = gen_steps_ores(n, "bh:ore_tin", WG_Settings.CAVE_TUBE_REPLACABLE, 256, -0.5, 0.12, 1.5)

    var timer_ores = Time.get_ticks_usec()
    print("  Chunk %d: %d ores placed in %.3fms." % [n, num_ores, (timer_ores-timer_trees)/1000.0])

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
  if queue_timer > 0:
    queue_timer -= delta
  if queue_timer <= 0 and len(chunk_queue) > 0:
    queue_timer = QUEUE_DELAY
    print("\nchunk_queue: "+str(chunk_queue))
    var next = chunk_queue.pop_front()
    generate_chunk( next[0], next[1] )

  # Portal generation
  # Select world portal x
  if world.world_portal_pos == Vector2i.ZERO: # World portal not set, 
    world.world_portal_pos.x = rand_from_seed( world.w_seed )[0] % ( world.width_tiles / 2 )
    world.world_portal_pos.x += world.width_tiles * 0.25 # keep portal in middle half.
    var world_portal_chunk = world.world_portal_pos.x/Chunk.WIDTH
    queue_chunk(world_portal_chunk, Chunk.GEN_STATE_MAX) # Queue the portal chunk
    print("Portal will be at "+str(world.world_portal_pos.x)+" in chunk "+ str(world_portal_chunk))
    
    # Move camera to portal chunk
    Helpers.camera_to(camera, Vector2(world.world_portal_pos.x, Chunk.HEIGHT/2))
    print("camera moved to "+ str(Vector2(world.world_portal_pos.x, Chunk.HEIGHT/2)))

    # generate portal if y not set AND the chunk is generated.
  if world.world_portal_pos.y == 0 and world.chunks[world.world_portal_pos.x/Chunk.WIDTH].gen_state == 2:
    world.world_portal_pos.y = world.get_surface(world.world_portal_pos.x )
    gen_feature_portal( world.world_portal_pos.x, world.world_portal_pos.y, true )
    Helpers.camera_to(camera, world.world_portal_pos)
    camera.generating_chunks_enabled = true
  if chunk_queue.size() == 0 and generation_working:
    gentimer_stop.emit()
    generation_working = false
  

