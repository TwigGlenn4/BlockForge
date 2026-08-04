extends Camera2D

class_name Interactor

const PAN_SPEED = 10
const ZOOM_SPEED = 0.05
const LERP_TIME = 1

static var tilemap_populator: TileMapPopulator

@export var world_interactor: Control
@export var RECIPE_SELECTOR_SCENE: Resource

var active_recipe_selector: Control

# move camera to position
var lerp_target: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	# set static references
	# these don't use get_node_or_null() because these node references aren't optional.
	tilemap_populator = get_node("../Mapping/TileMapPopulator")


func _process(delta):
	# Pan controls
	var movement = Vector2.ZERO
	if Input.is_action_pressed("camera_pan_left"):
		movement += Vector2(-PAN_SPEED, 0)
	if Input.is_action_pressed("camera_pan_right"):
		movement += Vector2(PAN_SPEED, 0)
	if Input.is_action_pressed("camera_pan_up"):
		movement += Vector2(0, -PAN_SPEED)
	if Input.is_action_pressed("camera_pan_down"):
		movement += Vector2(0, PAN_SPEED)
	position += movement * (Vector2.ONE/zoom) * ( delta / 0.0166)

	if lerp_target != Vector2i(-1,-1):
		lerp_timer += delta/LERP_TIME
		clampf(lerp_timer, 0.0, 1.0)
		position = position.lerp(lerp_target, lerp_timer)
		# print("lerped to "+str(position))
		if position == Vector2(lerp_target):
			# print("lerp done, delta = "+str(delta))
			lerp_timer = 0
			lerp_target = Vector2i(-1,-1)

	# Keep cylindrical chunk maps aligned while the camera pans away from the player
	if tilemap_populator and tilemap_populator.has_method("align_layers_to_camera"):
		tilemap_populator.align_layers_to_camera(global_position.x)


# signal functions
## Create a static signal on Interactor and return the signal
## Usage: `static var signal_name: Signal = _create_static_signal("signal_name")`.
## `arg_array` contains params for the signal in the format `{ "name": "arg_name", "type": TYPE_INT }`
static func _create_static_signal(signal_name: String, arg_array: Array = []) -> Signal:
	(Interactor as Object).add_user_signal(signal_name, arg_array)
	return Signal(Interactor, signal_name)

## forward inventory_changed signals from the selected character onwards.
## This listeners to only need Interacter
static func _on_selected_character_inventory_changed_internal() -> void:
	GameScene.selected_character_inventory_changed.emit()


# Zoom controls in _input to properly accept mouse wheel input
func _input(event: InputEvent) -> void:
	_input_camera_movement(event)
	_input_character_inventory(event)
	_input_click_pos_test(event)
	

func _input_camera_movement(event: InputEvent) -> void:
	var new_zoom: Vector2 = zoom
	if event.is_action_pressed("camera_zoom_in"):
		new_zoom += Vector2(ZOOM_SPEED, ZOOM_SPEED)
	if event.is_action_pressed("camera_zoom_out"):
		new_zoom += Vector2(-ZOOM_SPEED, -ZOOM_SPEED)
	
	var zmin: float = WorldConfig.min_zoom()
	var zmax: float = WorldConfig.max_zoom()
	zoom = new_zoom.clamp(Vector2(zmin, zmin), Vector2(zmax, zmax))
	scale = Vector2(1 / zoom.x, 1 / zoom.y)

	if Input.is_action_just_pressed("look_at_portal"): # centers camera on bottom block of portal anim
		_move_to_block(GameScene.world.world_portal_pos)
	if Input.is_action_just_pressed("look_at_character"):
		# print("moving to character")selected_character.current_pos
		_move_to_block(GameScene.selected_character.current_pos)
	
func _input_character_inventory(event: InputEvent) -> void:
	# open inventory
	if event.is_action_pressed("inventory_open"):
		# print("[interactor.gd] open inventory")
		print(GameScene.selected_character.inventory)
		
## Try to interact with a block. Returns true if the block is interactable, or the tile can be broken, or a tile can be placed.
## False should cause a goto job
func _input_block_interact(block_pos: Vector2i) -> bool:
	var tile: DataTile = GameScene.world.get_tile_v(block_pos)
	if tile == null:
		return false
	if tile.interactable:
		_tile_interacion(block_pos, tile)
		return true
	elif tile != DataTile.AIR:
		print("[Interactor] Creating BREAK Job.")
		var job: Job = Job.new(Job.TYPE.BREAK, block_pos)
		GameScene.selected_character.add_job(job)
		return true
	else:
		var held_item_stack: ItemStack = GameScene.inventory_ui.get_held_item_stack()
		if held_item_stack:
			print("[Interacter] Held item is " + str(held_item_stack) + ", item string is " + str(held_item_stack.get_item()))
			print("[Interactor] Creating PLACE Job.")
			var job: Job = Job.new(Job.TYPE.PLACE, block_pos, str(held_item_stack.get_item()))
			GameScene.selected_character.add_job(job)
			return true

	return false

func _input_click_pos_test(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click_right"):
		var click_pos:Vector2 = get_global_mouse_position()
		var block_pos:Vector2i = Helpers.pos_pixel_to_block(click_pos)
		GameScene.world.place_tile_v(block_pos, DataTile.UNDEFINED)
		print("[Interactor._input_click_pos_test()] clicked at ", block_pos)
	


func _move_to_block(block_pos:Vector2i):
	lerp_target = Helpers.pos_block_to_pixel(block_pos)
	lerp_timer = 0


func _on_world_interactor_click(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		var click_pos:Vector2 = get_global_mouse_position()

		var block_pos:Vector2i = Helpers.pos_pixel_to_block(click_pos)
		print("[Interactor] Clicked at "+str(block_pos))

		if not _input_block_interact(block_pos):
			print("[Interactor] Creating GOTO Job.")

			var job: Job = Job.new(Job.TYPE.GOTO, block_pos)
			GameScene.selected_character.add_job(job)

			
			# TODO: Re-implement this nearby-job logic in Pathfinding
			# # ===== PATHFIND GENERAL
			# var start:Vector2i = GameScene.selected_character.current_pos
			# var end:Vector2i = Vector2i(Helpers.wrap_block_x(block_pos.x), block_pos.y)

			# print("\nstart -> end ",str(start)," -> ",str(end))

			# # Superman: fly/walk straight to the clicked cell (no surface follow / tree path)
			# if WorldConfig.superman():
			# 	GameScene.selected_character.add_job(Job.new(Job.TYPE.GOTO, end))
			# 	print("path finished (superman direct)")
			# else:
			# 	var dig_pos: Vector2i = end
			# 	var dig_tile: DataTile = GameScene.world.get_tile_v(dig_pos)
			# 	var want_dig: bool = (
			# 		dig_tile != null
			# 		and dig_tile != DataTile.AIR
			# 		and not dig_tile.interactable
			# 	)
			# 	var is_tree_click: bool = want_dig and Pathfinding.is_tree_tile(dig_pos)
			# 	# Surface destinations stand in air above ground (not when targeting a tree)
			# 	if not is_tree_click and not Pathfinding.is_in_tree(end):
			# 		var surface_y: int = GameScene.world.get_surface(end.x)
			# 		if surface_y >= 0:
			# 			end.y = surface_y + 1
			# 	# var arrived: Vector2i = Pathfinding.navigate_to(GameScene.selected_character, start, end)
			# 	# After navigating: dig trees, or near-surface blocks (not deep underground shortcuts)
			# 	if want_dig:
			# 		var near_surface: bool = abs(dig_pos.y - end.y) <= 2
			# 		if is_tree_click or near_surface:
			# 			GameScene.selected_character.add_job(Job.new(Job.TYPE.BREAK, dig_pos))
			# 	print("path finished")
			# # ===== END PATHFIND GENERAL

func _tile_interacion(block_pos: Vector2i, tile: DataTile) -> void:
	match tile.interactable:
		DataTile.INTERACTION.CRAFT:
			print("Interacting with crafting block ", tile.name, " at ", block_pos)

			if active_recipe_selector:
				active_recipe_selector.queue_free()

			active_recipe_selector = RECIPE_SELECTOR_SCENE.instantiate()
			active_recipe_selector.setup(tile.name, block_pos)
			GameScene.main_ui.add_child(active_recipe_selector)
