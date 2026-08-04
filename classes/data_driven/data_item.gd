class_name DataItem

static var all_items: Dictionary[String, DataItem] = {}

static var UNDEFINED = DataItem.new("undefined", DataTexture.UNDEFINED)

enum ITEM_TYPES {
	SIMPLE,   # Has no functionality of its own, may be a crafting ingredient
	PLACEABLE,  # Can be placed as a tile
	CONSUMABLE, # Can be used as an item (food, potions?, etc)
	ARMOR,      # Can go in correct armor slot and has durability
	TOOL,       # Has durability
	CONTAINER,  # Tracks items inside the container
}

var item_id: String
var texture: DataTexture
var name: String
var stack_max: int
var item_type: ITEM_TYPES

func _init(item_id:String, item_texture:DataTexture = DataTexture.UNDEFINED, name: String = "", item_stack_max:int = 99):
	self.item_id = item_id
	texture = item_texture
	stack_max = item_stack_max
	self.name = name
	item_type = ITEM_TYPES.SIMPLE
	all_items[item_id] = self


static func exists(tile_name:String) -> bool:
	return all_items.has(tile_name)


static func item(tile_name:String) -> DataItem:
	if Tiles.exists(tile_name):
		return all_items[tile_name]
	else:
		return UNDEFINED


func _to_string() -> String:
	return str(item_id)


func tracked() -> bool:
	if item_type == DataItem.ITEM_TYPES.TOOL or item_type == DataItem.ITEM_TYPES.ARMOR or item_type == DataItem.ITEM_TYPES.CONTAINER:
		return true
	return false
