class_name DataTile

static var all_tiles = {}

static var UNDEFINED = DataTile.new("undefined", DataTexture.UNDEFINED)

var name:String
var texture:DataTexture
var drops:String


func _init( tile_name:String, tile_texture:DataTexture, drop_item:String="undefined" ):
	name = tile_name
	texture = tile_texture

	if drop_item == "undefined": # default to drop itself, only override if drop_item given
		drops = tile_name
	else:
		drops = drop_item

	DataItem.new(tile_name, tile_texture) # make sure an item for this tile exists

	all_tiles[name] = self


static func exists(tile_name:String) -> bool:
	return all_tiles.has(tile_name)

static func tile(tile_name:String) -> DataTile:
	if DataTile.exists(tile_name):
		return all_tiles[tile_name]
	else:
		return UNDEFINED

func _to_string() -> String:
	return name