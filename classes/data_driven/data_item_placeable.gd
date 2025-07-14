extends DataItem
class_name DataItemPlaceable



# inherited variables from DataItem
# var name: String
# var texture: DataTexture
# var stack_max: int
# var item_type: ITEM_TYPES

var tile: DataTile


func _init(item_name:String, item_tile:DataTile, item_texture:DataTexture = DataTexture.UNDEFINED, item_stack_max:int = 99):
	super(item_name, item_texture, item_stack_max)
	item_type = ITEM_TYPES.PLACEABLE

	tile = item_tile
