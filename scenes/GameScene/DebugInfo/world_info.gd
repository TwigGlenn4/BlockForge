extends Label

var world: World
var camera: Camera2D

func _ready() -> void:
	world = get_node("/root/GameScene/World")
	camera = get_node("/root/GameScene/World/MainCamera")


func _process(_delta: float) -> void:
	if visible:
		text = _create_text()


func _create_text() -> String:
	var mouse_pos: Vector2 = camera.get_global_mouse_position()
	var output: String = "Cursor Pos: " + str(mouse_pos) + "\n"

	var block_pos: Vector2i = Helpers.pos_pixel_to_block(mouse_pos)
	output += "Selected Block Pos: " + str(block_pos) + "\n"
	var selected_tile: DataTile = world.get_tile_v(block_pos)
	output += "Selected Block: " + str(selected_tile)


	return output
