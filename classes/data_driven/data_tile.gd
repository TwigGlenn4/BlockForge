class_name DataTile

static var _registered = {}

static var UNDEFINED = DataTile.new("undefined", DataTexture.UNDEFINED)
static var AIR = DataTile.new("air", DataTexture.new("air", -1, Vector2i(0,0)))

var tile_id: String
var texture: DataTexture
var name: String
var drops: String
var background: String
var interactable: INTERACTION
var deco_layer: bool

enum INTERACTION {
	NONE,
	CRAFT,
	OPEN_INVENTORY,
	REFUEL
}

func _init(tile_id: String, texture: DataTexture, name: String = "", drop: String = "", background: String = "", interactable: INTERACTION = INTERACTION.NONE, deco_layer: bool = false):
	self.tile_id = tile_id
	self.texture = texture
	self.name = name
	self.drops = drop
	self.background = background
	self.interactable = interactable
	self.deco_layer = deco_layer


	
	DataItem.new(tile_id, texture, name) # make sure an item for this tile exists
	_registered[tile_id] = self


# static func exists(tile_id:String) -> bool:
# 	return _registered.has(tile_id)

# static func tile(tile_id: String) -> DataTile:
# 	return _registered.get(tile_id, UNDEFINED)

# static func is_interactable(tile_id: String) -> bool:
# 	return tile(tile_id).interactable != INTERACTION.NONE


func _to_string() -> String:
	return tile_id
