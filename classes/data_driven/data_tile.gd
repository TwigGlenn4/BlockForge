class_name DataTile

static var all_tiles = {}

static var UNDEFINED = DataTile.new("undefined", DataTexture.UNDEFINED)

var name:String
var texture:DataTexture
var drops:String


func _init( tile_name:String, tile_texture:DataTexture, drop_item:String="" ):
	name = tile_name
	texture = tile_texture
	drops = drop_item
	all_tiles[name] = self


static func exists(tile_name:String) -> bool:
	return all_tiles.has(tile_name)

static func tile(tile_name:String) -> DataTile:
	if DataTile.exists(tile_name):
		return all_tiles[tile_name]
	else:
		return UNDEFINED
