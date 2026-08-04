class_name Tiles

## Dictionary mapping tile_id to its DataTile.
static var _registered_tiles: Dictionary[String, DataTile]

## Dictionary mapping groupnames to an array of tile_ids
## BlockForge builtin groups: `soil`
static var _registered_groups: Dictionary[String, PackedStringArray]

# static var UNDEFINED = DataTile.new("undefined", DataTexture.UNDEFINED)
static var UNDEFINED = register("undefined", DataTexture.UNDEFINED, "Undefined")
static var AIR = DataTile.new("air", DataTexture.new("air", -1, Vector2i(0,0)))

static func register(tile_id: String, texture: DataTexture, _name: String = "", drop: String = "", _background: String = "",
                     interaction: DataTile.INTERACTION = DataTile.INTERACTION.NONE, _deco_layer: bool = false, groups: PackedStringArray = []) -> DataTile:
	
	print("[Tiles] Registering ", tile_id)
	var tile = DataTile.new(tile_id, texture, drop, interaction)
	_registered_tiles.set(tile_id, tile)

	for group: String in groups:
		if _registered_groups.has(group):
			_registered_groups[group].append(tile_id)
		else:
			_registered_groups[group] = PackedStringArray([group])
	return tile


static func exists(tile_id: String) -> bool:
	return _registered_tiles.has(tile_id)

static func find(tile_id) -> DataTile:
	var result: DataTile =  _registered_tiles.get(tile_id)
	if ! result:
		print("[Tiles] tried to find tile_id that doesn't exist: ", tile_id)
	return result

static func get_all_tiles() -> Array[DataTile]:
	return _registered_tiles.values()


static func is_in_group(tile_id: String, group: String) -> bool:
	if not _registered_groups.has(group): # return false if group does not exist
		return false
	return _registered_groups.get(group).has(tile_id)
