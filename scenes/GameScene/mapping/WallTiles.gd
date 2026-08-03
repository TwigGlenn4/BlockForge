# WallTiles — foreground terrain_id → background wall terrain_id.
# TODO: replace same-tile mapping with dedicated darker wall atlas variants + AO.
class_name WallTiles
extends RefCounted

## FG tile names that should not leave a background wall.
const NO_WALL: Dictionary = {
	"air": true,
	"blockforge:water": true,
	"blockforge:lava": true,
	"blockforge:log": true,
	"blockforge:leaves": true,
	"blockforge:portal_top": true,
	"blockforge:portal_btm": true,
	"blockforge:portal_base_stone": true,
	"blockforge:portal_base_cobble": true,
}

## Remap surface cover to a sensible wall material.
const WALL_REMAP: Dictionary = {
	"blockforge:grass": "blockforge:dirt",
	"blockforge:snow": "blockforge:dirt",
}


## Wall terrain id for a foreground id. 0 = no wall.
static func wall_id_for(terrain_id: int) -> int:
	if terrain_id <= 0:
		return 0
	var n: String = TileIdRegistry.name_for_id(terrain_id)
	if n.is_empty() or NO_WALL.has(n):
		return 0
	if WALL_REMAP.has(n):
		return TileIdRegistry.id_from_name(str(WALL_REMAP[n]))
	# TODO: dedicated wall tile names (e.g. blockforge:dirt_wall) when atlas exists.
	return terrain_id


## Pack FG + wall. If terrain has no wall of its own, keep wall from `prev_packed`.
static func pack_with_wall(terrain_id: int, item_id: int = 0, prev_packed: int = 0) -> int:
	var wall: int = wall_id_for(terrain_id)
	if wall <= 0:
		wall = ChunkData.unpack_data(prev_packed)
	return ChunkData.pack_cell(terrain_id, item_id, wall)


## Carve FG to air but keep / seed wall so caves show background.
static func carve_air_preserve_wall(packed: int) -> int:
	var wall: int = ChunkData.unpack_data(packed)
	if wall <= 0:
		wall = wall_id_for(ChunkData.unpack_terrain(packed))
	return ChunkData.pack_cell(0, ChunkData.unpack_item(packed), wall)
