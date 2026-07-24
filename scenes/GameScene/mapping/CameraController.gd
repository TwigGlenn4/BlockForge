# Camera follows player; zoom limits from WorldConfig.
# Dig/pathfinding click handlers are stubs until digging slice; inventory signal preserved.
class_name CameraController
extends Camera2D

signal selected_character_changed(new_char: Character)

@export var player_path: NodePath = ^"../Character"
@export var populator_path: NodePath = ^"../Mapping/TileMapPopulator"
@export var visibility_path: NodePath = ^"../Mapping/VisibilityManager"
@export var world_interactor: Control

@onready var player: Node2D = get_node_or_null(player_path)

const ZOOM_STEP := 0.05


func _ready() -> void:
	if player == null:
		player = get_node_or_null("../Character")
	# Camera zoom scales the whole 2D view. Keep node scale at 1.
	scale = Vector2.ONE
	if player:
		player.scale = Vector2.ONE
	var z: float = clampf(WorldConfig.initial_zoom(), WorldConfig.min_zoom(), WorldConfig.max_zoom())
	zoom = Vector2(z, z)
	_update_filter()
	if player:
		selected_character_changed.emit(player)


func _process(_delta: float) -> void:
	if player == null:
		player = get_node_or_null(player_path)
		if player == null:
			return
	global_position = player.global_position
	_handle_zoom_input()
	var pop := get_node_or_null(populator_path)
	if pop and pop.has_method("align_layers_to_camera"):
		pop.align_layers_to_camera(global_position.x)


func _handle_zoom_input() -> void:
	var z: float = zoom.x
	var prev: float = z
	if Input.is_action_just_pressed("camera_zoom_in"):
		z += ZOOM_STEP
	if Input.is_action_just_pressed("camera_zoom_out"):
		z -= ZOOM_STEP
	z = clampf(z, WorldConfig.min_zoom(), WorldConfig.max_zoom())
	if not is_equal_approx(z, zoom.x):
		var zoomed_out: bool = z < prev
		zoom = Vector2(z, z)
		_update_filter()
		if zoomed_out:
			var vis := get_node_or_null(visibility_path)
			if vis and vis.has_method("notify_zoom_out"):
				vis.notify_zoom_out()


func _update_filter() -> void:
	if zoom.x >= WorldConfig.max_zoom() * 0.9:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _on_world_interactor_click(event: InputEvent) -> void:
	if not event.is_action_pressed("click"):
		return
	if player == null:
		player = get_node_or_null(player_path)
	if player == null:
		return
	var click_pos: Vector2 = get_global_mouse_position()
	var block_pos: Vector2i = _nearest_block(click_pos)
	if player.has_method("move_to_block"):
		player.move_to_block(block_pos)
	elif player is Character:
		(player as Character).move_to_block(block_pos)


func _nearest_block(pixel: Vector2) -> Vector2i:
	var ts: float = float(WorldConfig.tile_size_px())
	return Vector2i(
		Helpers.wrap_block_x(int(round((pixel.x - ts * 0.5) / ts))),
		int(round(-pixel.y / ts))
	)


func _move_to_block(block_pos: Vector2i) -> void:
	var bx := Vector2i(Helpers.wrap_block_x(block_pos.x), block_pos.y)
	if player:
		player.global_position = Helpers.pos_block_to_pixel(bx)
		if player.has_method("_wrap_world_x"):
			player._wrap_world_x()
	global_position = Helpers.pos_block_to_pixel(bx)
