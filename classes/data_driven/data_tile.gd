class_name DataTile

static var _registered = {}

static var UNDEFINED = DataTile.new("undefined", DataTexture.UNDEFINED)

var name: String
var texture: DataTexture
var drops: String
var interactable: INTERACTION

enum INTERACTION {
	NONE,
	CRAFT,
	OPEN_INVENTORY,
	REFUEL
}

func _init(name: String, texture: DataTexture, drop: String = "self", interactable: INTERACTION = INTERACTION.NONE):
	self.name = name
	self.texture = texture

	if drop == "self": # default to drop itself, only override if drop_item given
		self.drops = name
	else:
		self.drops = drop
	
	self.interactable = interactable
	
	DataItem.new(name, texture) # make sure an item for this tile exists
	_registered[name] = self


static func exists(tile_name:String) -> bool:
	return _registered.has(tile_name)

static func tile(tile_name: String) -> DataTile:
	return _registered.get(tile_name, UNDEFINED)

static func is_interactable(tile_name: String) -> bool:
	return tile(tile_name).interactable != INTERACTION.NONE


func _to_string() -> String:
	return name
