extends Node

class_name World


# save_data is the parts that should be written to the save file.
var	w_name = "" # name of world to be displayed in menus
var w_seed: int = 0 # Seed to use for world generation
var width: int = 4 # Width of world in chunks (legacy Chunk[])
var width_tiles: int = width * Chunk.WIDTH # Width of world in tiles (legacy)
var chunks: Array[Chunk] = [] # Array to be filled with chunks (legacy)
var world_portal_pos: Vector2i = Vector2i.ZERO # Location of the base of the World Portal
var tilemap: TileMapLayer
var worldgen: WorldGenV2

# Mapped chunk system (preferred when present)
var chunk_manager: ChunkManager
var tile_populator: TileMapPopulator


func _ready():
	tilemap = get_node("/root/GameScene/World/Foreground")
	worldgen = get_node("/root/GameScene/World/WorldGen")
	chunk_manager = get_node_or_null("Mapping/ChunkManager") as ChunkManager
	tile_populator = get_node_or_null("Mapping/TileMapPopulator") as TileMapPopulator

	tilemap.position.y = -tilemap.rendering_quadrant_size # fix tilemap position seeming to be top-left of bottom-left cell. I think this is because I chose to work in the positive-y quadrant instead of negative-y
	chunks.resize(width)

	for n in width:
		chunks[n] = Chunk.new(n)


func _uses_mapped() -> bool:
	return chunk_manager != null


# get_chunk_at_x(): gets the chunk at a given global x coordinate (legacy)
func get_chunk_at_x( gx: int ) -> Chunk:
	var chunk_num = gx / Chunk.WIDTH
	if chunk_num < 0 || chunk_num >= width:
		print("Failed to access chunk "+str(chunk_num)+" outside world.")
		return null
	return chunks[chunk_num]

func get_tile_v( v: Vector2i ) -> DataTile:
	return get_tile(v.x, v.y)

# get_tile(): returns the tile at given global coordinates.
func get_tile( gx: int, gy: int ) -> DataTile:
	if _uses_mapped():
		return _get_tile_mapped(gx, gy)

	# legacy path
	if gx < 0 || gx >= width_tiles || gy < 0 || gy >= Chunk.HEIGHT:
		return null

	var chunk = get_chunk_at_x(gx)
	if chunk == null:
		return null
	var pos_local = Vector2i(gx % Chunk.WIDTH, gy)

	if !chunk.grid.has(pos_local):
		return Tiles.AIR
	return chunk.grid[pos_local]


func _get_tile_mapped(gx: int, gy: int) -> DataTile:
	var tid: int = chunk_manager.get_terrain_id(gx, gy)
	if tid < 0:
		return null # unloaded / out of bounds
	if tid == 0:
		return Tiles.AIR
	var tile_name: String = TileIdRegistry.name_for_id(tid)
	if tile_name.is_empty() or tile_name == "air":
		return Tiles.AIR
	return DataTile.tile(tile_name)


# tile_match(): return true if the tile at (gx, gy) is contained in array match_arr
func tile_matches( gx: int, gy: int, match_arr ):
	var existing_tile = get_tile(gx, gy)
	if match_arr.find(existing_tile) == -1:
		return false
	else:
		return true


# get_surface(): returns the surface level (solid ground, skips canopy) at global x
func get_surface( gx: int ):
	if _uses_mapped():
		return chunk_manager.find_surface_height(gx)

	var chunk = get_chunk_at_x(gx)
	if chunk == null:
		return -1
	return int( chunk.surface_level[ gx % Chunk.WIDTH ] )


# place_tile(): place a tile at given global coordinates
func place_tile( x: int, y: int, tile: DataTile) -> bool:
	if _uses_mapped():
		return _place_tile_mapped(x, y, tile)

	if x < 0 || x >= width_tiles || y < 0 || y >= Chunk.HEIGHT:
		return false

	var chunk = get_chunk_at_x(x)
	if chunk == null:
		return false
	var lx = x % Chunk.WIDTH # local x

	var pos = Vector2i(lx, y)
	var pos_tile = Vector2i(chunk.cx*Chunk.WIDTH + lx, -y)

	chunk.grid[pos] = tile
	if tile == null:
		tilemap.set_cell(pos_tile)
	else:
		tilemap.set_cell(pos_tile, tile.texture.atlas, tile.texture.pos )
	return true


func _place_tile_mapped(x: int, y: int, tile: DataTile) -> bool:
	var terrain_id: int = 0
	if tile != null and tile != Tiles.AIR and tile != DataTile.UNDEFINED:
		terrain_id = TileIdRegistry.id_from_name(tile.name)
	if not chunk_manager.set_terrain_id(x, y, terrain_id):
		return false
	if tile_populator:
		tile_populator.set_global_cell(x, y, terrain_id)
	return true


func place_tile_v(pos: Vector2i, tile: DataTile) -> bool:
	return place_tile(pos.x, pos.y, tile)


# place_tile_overwrite(): place a tile if the exisitng tile is contained in overwrite_tiles array. Returns true if placed.
func place_tile_overwrite(x: int, y: int, tile, overwrite_tiles):
	if tile_matches(x, y, overwrite_tiles):
		return place_tile( x, y, tile )
	else:
		return false


# place_tile_chunk(): Place a tile based on chunk coordinates. Should be slightly more performant than place_tile where chunk is already known.
func place_tile_chunk(chunk, x, y, tile):
	var pos = Vector2i(x, y)
	var pos_tile = Vector2i(chunk.cx*Chunk.WIDTH + x, -y)
	chunk.grid[pos] = tile
	tilemap.set_cell(pos_tile, tile.texture.atlas, tile.texture.pos )
