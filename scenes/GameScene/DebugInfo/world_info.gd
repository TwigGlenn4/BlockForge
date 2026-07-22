extends Label

var camera: Camera2D

func _ready() -> void:
	camera = get_node("/root/GameScene/World/MainCamera")


func _process(_delta: float) -> void:
	if visible:
		text = _create_text()


func _create_text() -> String:
	var mouse_pos: Vector2 = camera.get_global_mouse_position()
	var output: String = "Cursor Pos: " + str(mouse_pos)

	var block_pos: Vector2i = Helpers.pos_pixel_to_block(mouse_pos)
	output += "\nSelected Block Pos: " + str(block_pos)
	var selected_tile: DataTile = Interactor.world.get_tile_v(block_pos)
	output += "\nSelected Block: " + str(selected_tile)
	var held_item: String = str(Interactor.inventory_ui.get_held_item_stack()) # explicit cast to string here makes it null-safe
	output += "\nHeld Item: " + held_item


	return output
