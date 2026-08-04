# WallTiles — background wall terrain from depth band (not FG vein/ore).
# Dirt/sand keep identity; grass/snow → dirt. Band tops from ChunkManager / gen arrays.
# TODO: dedicated wall atlas art; full AO shaders (beyond edge bevels).
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

## Remap surface cover to a sensible wall material (dirt belt only).
const WALL_REMAP: Dictionary = {
	"blockforge:grass": "blockforge:dirt",
	"blockforge:snow": "blockforge:dirt",
}


## Wall id for a depth band. soil_id = dirt or sand terrain id for the dirt belt.
static func wall_id_for_band(
	gy: int, lava_top: int, stone_top: int, rock_top: int, soil_id: int
) -> int:
	if gy < lava_top:
		return 0
	if gy < stone_top:
		return TileIdRegistry.id_from_name("blockforge:stone")
	if gy < rock_top:
		return TileIdRegistry.id_from_name("blockforge:cobblestone")
	# Dirt / sand belt (including surface cover).
	if soil_id > 0:
		return soil_id
	return TileIdRegistry.id_from_name("blockforge:dirt")


## Wall from ChunkManager band caches (+ soil). 0 if tops unknown.
static func wall_id_at(gx: int, gy: int, chunk_manager: ChunkManager) -> int:
	if chunk_manager == null:
		return 0
	var tops: Dictionary = chunk_manager.get_band_tops(gx)
	var lt: int = int(tops.get("lava_top", -1))
	var st: int = int(tops.get("stone_top", -1))
	var rt: int = int(tops.get("rock_top", -1))
	var soil: int = int(tops.get("soil_wall", 0))
	if lt < 0 or st < 0 or rt < 0:
		return 0
	return wall_id_for_band(gy, lt, st, rt, soil)


## Legacy: FG → wall (veins copy FG). Prefer pack_fg_with_band_wall / wall_id_for_band.
static func wall_id_for(terrain_id: int) -> int:
	if terrain_id <= 0:
		return 0
	var n: String = TileIdRegistry.name_for_id(terrain_id)
	if n.is_empty() or NO_WALL.has(n):
		return 0
	if WALL_REMAP.has(n):
		return TileIdRegistry.id_from_name(str(WALL_REMAP[n]))
	return terrain_id


## Pack FG + band wall. NO_WALL FG keeps previous wall (or seeds band if empty).
static func pack_fg_with_band_wall(
	terrain_id: int,
	item_id: int,
	gy: int,
	lava_top: int,
	stone_top: int,
	rock_top: int,
	soil_id: int,
	prev_packed: int = 0
) -> int:
	var n: String = TileIdRegistry.name_for_id(terrain_id) if terrain_id > 0 else "air"
	if terrain_id <= 0 or NO_WALL.has(n):
		var wall: int = ChunkData.unpack_data(prev_packed)
		if wall <= 0 and terrain_id > 0:
			# Solid NO_WALL (e.g. still packing) — no wall.
			wall = 0
		return ChunkData.pack_cell(terrain_id, item_id, wall)
	var band_wall: int = wall_id_for_band(gy, lava_top, stone_top, rock_top, soil_id)
	return ChunkData.pack_cell(terrain_id, item_id, band_wall)


## Legacy pack: FG-derived wall. Prefer pack_fg_with_band_wall during gen.
static func pack_with_wall(terrain_id: int, item_id: int = 0, prev_packed: int = 0) -> int:
	var wall: int = wall_id_for(terrain_id)
	if wall <= 0:
		wall = ChunkData.unpack_data(prev_packed)
	return ChunkData.pack_cell(terrain_id, item_id, wall)


## Carve FG to air but keep / seed band wall so caves show background.
static func carve_air_preserve_wall(
	packed: int,
	gy: int = -1,
	lava_top: int = -1,
	stone_top: int = -1,
	rock_top: int = -1,
	soil_id: int = 0
) -> int:
	var wall: int = ChunkData.unpack_data(packed)
	if wall <= 0:
		if gy >= 0 and lava_top >= 0 and stone_top >= 0 and rock_top >= 0:
			wall = wall_id_for_band(gy, lava_top, stone_top, rock_top, soil_id)
		else:
			wall = wall_id_for(ChunkData.unpack_terrain(packed))
	return ChunkData.pack_cell(0, ChunkData.unpack_item(packed), wall)
