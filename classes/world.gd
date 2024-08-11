extends Node

class_name World


# save_data is the parts that should be written to the save file.
var	w_name = "" # name of world to be displayed in menus
var w_seed: int = 0 # Seed to use for world generation
var width: int = 4 # Width of world in chunks 
var width_tiles: int = width * Chunk.WIDTH # Width of world in tiles
var chunks = [] # Array to be filled with chunks
var world_portal_pos: Vector2i = Vector2i.ZERO # Location of the base of the World Portal
var tilemap: TileMap 
var worldgen: WorldGenV2



# Called when the node enters the scene tree for the first time.
func _ready():
  tilemap = get_node("/root/GameScene/World/TileMap")
  worldgen = get_node("/root/GameScene/World/WorldGen")
  chunks.resize(width)

  for n in width:
    chunks[n] = Chunk.new(n)



# func _init( world_name, world_seed, num_chunks ):
# 	w_name = world_name
# 	w_seed = world_seed
# 	width = num_chunks
# 	width_tiles = num_chunks * Chunk.WIDTH


# get_chunk_at_x(): gets the chunk at a given global x coordinate
func get_chunk_at_x( gx: int ):
  var chunk_num = gx / Chunk.WIDTH
  if chunk_num < 0 || chunk_num >= width:
    print("Failed to access chunk "+str(chunk_num)+" outside world.")
    return 
  return chunks[chunk_num]

func get_tile_v( v: Vector2i ):
  return get_tile(v.x, v.y)

# get_tile(): returns the tile stored in chunk.grid at given global coordinates.
func get_tile( gx: int, gy: int ):
  # handle tiles outside world
  if gx < 0 || gx >= width_tiles || gy < 0 || gy >= Chunk.HEIGHT: # Don't attempt to get tiles outside of the world.
    return DataTile.UNDEFINED

  var chunk = get_chunk_at_x(gx)
  var pos_local = Vector2i(gx % Chunk.WIDTH, gy)

  if !chunk.grid.has(pos_local): # If the pos does not exist in the grid, don't error.
    return DataTile.UNDEFINED
  return chunk.grid[pos_local]


# tile_match(): return true if the tile at (gx, gy) is contained in array match_arr
func tile_matches( gx: int, gy: int, match_arr ):
  var existing_tile = get_tile(gx, gy)
  if match_arr.find(existing_tile) == -1:
    return false
  else:
    return true


# get_surface(): returns the surface level at given global x coordinate
func get_surface( gx: int ):
  var chunk = get_chunk_at_x(gx)
  return int( chunk.surface_level[ gx % Chunk.WIDTH ] )


# place_tile(): place a tile at given global coordinates
func place_tile( x: int, y: int , tile):
  if x < 0 || x >= width_tiles || y < 0 || y >= Chunk.HEIGHT:
    # print("Tile not placed outside world at "+ Helpers.coord_string(x, y))
    return false
  var chunk = get_chunk_at_x(x)
  var lx = x % Chunk.WIDTH # local x

  var pos = Vector2i(lx, y)
  var pos_tile = Vector2i(chunk.cx*Chunk.WIDTH + lx, -y)

  chunk.grid[pos] = tile
  # tilemap.set_cell(0, pos_tile, tile.atlas, tile.pos )
  tilemap.set_cell(0, pos_tile, tile.texture.atlas, tile.texture.pos )
  return true


# place_tile_overwrite(): place a tile if the exisitng tile is contained in overwrite_tiles array. Returns true if placed.
func place_tile_overwrite(x: int, y: int, tile, overwrite_tiles):
  if tile_matches(x, y, overwrite_tiles):
    return place_tile( x, y, tile )
  else:
    # print("Did not overwrite "+existing_tile.id+" at "+Helpers.coord_string(x, y))
    return false
    

# place_tile_chunk(): Place a tile based on chunk coordinates. Should be slightly more performant than place_tile where chunk is already known.
func place_tile_chunk(chunk, x, y, tile):
  var pos = Vector2i(x, y)
  var pos_tile = Vector2i(chunk.cx*Chunk.WIDTH + x, -y)
  chunk.grid[pos] = tile
  # tilemap.set_cell(0, pos_tile, tile.atlas, tile.sprite )
  tilemap.set_cell(0, pos_tile, tile.texture.atlas, tile.texture.pos )

