extends Node

class_name World


# save_data is the parts that should be written to the save file.
var w_name = "" # name of world to be displayed in menus
var w_seed: int = 0 # Seed to use for world generation
var world_portal_pos: Vector2i = Vector2i.ZERO # Location of the base of the World Portal

# Mapped world bounds (tiles / logical chunk columns from WorldConfig)
var width: int:
	get:
		return WorldConfig.world_chunks_wide_max()
var width_tiles: int:
	get:
		return WorldConfig.world_width_tiles()

var worldgen: WorldGenV2
var chunk_manager: ChunkManager
var tile_populator: TileMapPopulator


func _ready():
	worldgen = get_node("/root/GameScene/World/WorldGen")
	chunk_manager = get_node_or_null("Mapping/ChunkManager") as ChunkManager
	tile_populator = get_node_or_null("Mapping/TileMapPopulator") as TileMapPopulator
	if chunk_manager == null or tile_populator == null:
		push_error("[World] Mapping/ChunkManager and Mapping/TileMapPopulator are required.")


func get_tile_v( v: Vector2i ) -> DataTile:
	return get_tile(v.x, v.y)


# get_tile(): returns the tile at given global coordinates.
func get_tile( gx: int, gy: int ) -> DataTile:
	if chunk_manager == null:
		return null
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
	if chunk_manager == null:
		return -1
	return chunk_manager.find_surface_height(gx)


# place_tile(): place a tile at given global coordinates
func place_tile( x: int, y: int, tile: DataTile) -> bool:
	if chunk_manager == null:
		return false
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


## Place or clear a lantern light at (x,y). Uses item_id; does not change terrain/wall.
func set_torch(x: int, y: int, enabled: bool = true) -> bool:
	return set_lantern(x, y, enabled)


func set_lantern(x: int, y: int, enabled: bool = true) -> bool:
	if chunk_manager == null:
		return false
	var item_id: int = ChunkLightManager.lantern_item_id() if enabled else 0
	if not chunk_manager.set_item_id(x, y, item_id):
		return false
	if tile_populator and tile_populator.light_manager:
		tile_populator.light_manager.sync_global_cell(Helpers.wrap_block_x(x), y)
	return true


# place_tile_overwrite(): place a tile if the existing tile is contained in overwrite_tiles array. Returns true if placed.
func place_tile_overwrite(x: int, y: int, tile, overwrite_tiles):
	if tile_matches(x, y, overwrite_tiles):
		return place_tile( x, y, tile )
	else:
		return false
