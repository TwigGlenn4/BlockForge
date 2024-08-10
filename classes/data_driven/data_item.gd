class_name DataItem

static var all_items = {}

static var UNDEFINED = DataItem.new("undefined", DataTexture.UNDEFINED)

enum ITEM_TYPES {
  MATERIAL = 0,   # Has no functionality of its own, may be a crafting ingredient
  PLACEABLE = 1,  # Can be placed as a tile
  CONSUMABLE = 2, # Can be used as an item (food, potions?, etc)
  ARMOR = 3,      # Is armor
  TOOL = 4,       # Is a tool
  CONTAINER = 5,
}

var name: String
var texture: DataTexture
var stack_max: int
var item_type: ITEM_TYPES

func _init(item_name:String, item_texture:DataTexture = DataTexture.UNDEFINED, item_stack_max:int = 99):
  name = item_name
  texture = item_texture
  stack_max = item_stack_max
  item_type = ITEM_TYPES.MATERIAL
  all_items[name] = self


static func exists(tile_name:String) -> bool:
  return all_items.has(tile_name)


static func item(tile_name:String) -> DataItem:
  if DataTile.exists(tile_name):
    return all_items[tile_name]
  else:
    return UNDEFINED


func tracked() -> bool:
  if item_type == DataItem.ITEM_TYPES.TOOL or item_type == DataItem.ITEM_TYPES.ARMOR or item_type == DataItem.ITEM_TYPES.CONTAINER:
    return true
  return false
