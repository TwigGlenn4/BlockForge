# TileIdRegistry — small int IDs ↔ TileSet atlas source + atlas coords (0 = air).
# Built from Tiles.get_all_tiles(); atlas indices match editor main_tileset.tres.
class_name TileIdRegistry
extends RefCounted

static var _name_to_id: Dictionary = {}
static var _id_to_atlas: Dictionary = {}
static var _atlas_by_id: Array = [] # index = terrain_id → Dictionary {atlas, pos, name}
static var _next_id: int = 1
static var _ready := false


static func ensure_ready() -> void:
	if _ready:
		return
	_ready = true
	TileParser.run()
	for tile in Tiles.get_all_tiles():
		# Dictionaries include int metadata keys like `_ATLAS`
		if not (tile is DataTile) or tile == DataTile.UNDEFINED:
			continue
		if tile.texture.atlas < 0:
			continue
		_register(tile)
	_rebuild_atlas_array()
	WorldConfig.logv("[TileIdRegistry] Registered %d terrain ids" % (_next_id - 1))


static func _register(tile: DataTile) -> int:
	if _name_to_id.has(tile.tile_id):
		return int(_name_to_id[tile.tile_id])
	var id: int = _next_id
	_next_id += 1
	_name_to_id[tile.tile_id] = id
	_id_to_atlas[id] = {
		"atlas": tile.texture.atlas,
		"pos": tile.texture.pos,
		"name": tile.tile_id,
	}
	return id


static func _rebuild_atlas_array() -> void:
	_atlas_by_id.clear()
	_atlas_by_id.resize(_next_id)
	for id in _id_to_atlas.keys():
		_atlas_by_id[int(id)] = _id_to_atlas[id]


## Dense array for hot loops (index = terrain_id). Call ensure_ready() first.
static func atlas_by_id_array() -> Array:
	ensure_ready()
	if _atlas_by_id.size() != _next_id:
		_rebuild_atlas_array()
	return _atlas_by_id


static func id_from_name(tile_name: String) -> int:
	ensure_ready()
	if tile_name.is_empty() or tile_name == "air":
		return 0
	if _name_to_id.has(tile_name):
		return int(_name_to_id[tile_name])
	if Tiles.exists(tile_name):
		var id: int = _register(Tiles.find(tile_name))
		_rebuild_atlas_array()
		return id
	return 0


static func atlas_for_id(terrain_id: int) -> Dictionary:
	ensure_ready()
	if terrain_id > 0 and terrain_id < _atlas_by_id.size():
		var info: Variant = _atlas_by_id[terrain_id]
		if info != null:
			return info
	return _id_to_atlas.get(terrain_id, {})


static func name_for_id(terrain_id: int) -> String:
	ensure_ready()
	if terrain_id <= 0:
		return "air"
	var info: Dictionary = _id_to_atlas.get(terrain_id, {})
	return str(info.get("name", ""))
