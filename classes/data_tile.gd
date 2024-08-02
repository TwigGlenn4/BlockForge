class_name DataTile

static var all_tiles = {}

static var UNDEFINED = DataTile.new("undefined", DataTexture.new("undefined"))

var name:String
var texture:DataTexture
var drops:String

func _init( tile_name:String, tile_texture:DataTexture, drop_item:String="" ):
	if not DataTile.exists(tile_name):
		name = tile_name
		texture = tile_texture
		drops = drop_item
		all_tiles[name] = self
	return


static func exists(tile_name:String):
	return all_tiles.has(tile_name)

static func tile(tile_name:String):
	if DataTile.exists(tile_name):
		return all_tiles[tile_name]
	else:
		return UNDEFINED
