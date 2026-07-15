extends Label

var world: World
var camera: Camera2D
var inventory_ui: Control

func _ready() -> void:
	world = get_node("/root/GameScene/World")
	camera = get_node("/root/GameScene/World/MainCamera")
	inventory_ui = get_node("/root/GameScene/World/MainCamera/MainUI/InventoryUI")


func _process(_delta: float) -> void:
	if visible:
		text = _create_text()


func _create_text() -> String:
	var mouse_pos: Vector2 = camera.get_global_mouse_position()
	var output: String = "Cursor Pos: " + str(mouse_pos)

	var block_pos: Vector2i = Helpers.pos_pixel_to_block(mouse_pos)
	output += "\nSelected Block Pos: " + str(block_pos)
	var selected_tile: DataTile = world.get_tile_v(block_pos)
	output += "\nSelected Block: " + str(selected_tile)
	var held_item: String = str(inventory_ui.get_held_item_stack()) # explicit cast to string here makes it null-safe
	output += "\nHeld Item: " + held_item


	return output
