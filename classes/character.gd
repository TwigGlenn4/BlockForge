extends Node2D
class_name Character

var active_crafting_progress: CraftingProgress = null
@export var CRAFTING_PROGRESS_SCENE: Resource

## Use `Interactor.selected_character_inventory_changed` where possible, it handles reconnecting when `Interactor.selected_character` changes.
signal inventory_changed


var current_pos: Vector2i = Vector2i(0,0)   ## block pos Vector
var target_pos: Vector2i = Vector2i(-1,-1)  ## block pos Vector
var lerp_timer: float = 0.0

var job_queue: Array[Job] = []
var job_active: Job = Job.NONE

## A Path object or null (no path)
var _path_to_job: Path = null

var stats = {
	speed = 10.0 # Character speed in blocks per second.
}

var inventory: Inventory = Inventory.new()

func _ready():
	stats.speed = WorldConfig.player_speed()


func _process(delta):
	if _path_to_job && target_pos == Vector2i(-1, -1):
		target_pos = _path_to_job.next()
	
	if target_pos != Vector2i(-1, -1):
		var target_pixels: Vector2 = Helpers.wrapped_target_pixel(position.x, target_pos)
		position = position.move_toward(
			target_pixels,
			delta * (stats.speed * float(WorldConfig.tile_size_px()))
		)
		_wrap_world_x()

	# update target_pos to next point on _path_to_job when reached
	if _path_to_job && position == Helpers.wrapped_target_pixel(position.x, target_pos):
		target_pos = _path_to_job.pop_next()
	if _path_to_job && _path_to_job.size() <= 0:
		_path_to_job = null
		
	
	if inventory.contents_changed_check():
		inventory_changed.emit()


func _physics_process(_delta):
	_try_queue_next_job()
	_wrap_world_x()
	current_pos = Helpers.pos_pixel_to_block(Vector2i(position))
	current_pos.x = Helpers.wrap_block_x(current_pos.x)
	_process_jobs()


# Keep player on the cylinder [0, world_width_px).
func _wrap_world_x() -> void:
	var world_width_px: float = WorldConfig.world_width_px()
	if world_width_px <= 0.0:
		return
	var before: float = position.x
	position.x = Helpers.wrap_pixel_x(position.x)
	if not is_equal_approx(before, position.x) and target_pos != Vector2i(-1, -1):
		target_pos.x = Helpers.wrap_block_x(target_pos.x)


func _try_queue_next_job() -> void:
	if (not job_queue.is_empty()) and job_active.type == Job.TYPE.NONE:
		job_active = job_queue.pop_front()
		_pathfind_to(job_active.pos)
		print("[Character] Activating "+job_active._to_string())


func add_job(job:Job) -> void:
	job_queue.push_back(job)


func _set_target_pos(block_pos:Vector2):
	var goto_job = Job.new(Job.TYPE.GOTO, block_pos)
	print("[Character] Prepending "+goto_job._to_string())
	job_queue.push_front(goto_job)


func _teleport_to(block_pos:Vector2):
	var block_pos_wrapped := Vector2i(Helpers.wrap_block_x(int(block_pos.x)), int(block_pos.y))
	position = Helpers.pos_block_to_pixel(block_pos_wrapped)
	_wrap_world_x()


func open_inventory():
	print(inventory)


func _process_jobs():
	# do nothing if invalid target_pos or further than 0.5 pixels from target
	if target_pos == Vector2i(-1, -1):
		return
	if position.distance_to(Helpers.wrapped_target_pixel(position.x, target_pos)) >= 0.5:
		return

	# snap to the nearest block (already passed position is <0.5px from target condition above)
	var nearest_block := Vector2i(Helpers.wrap_block_x(target_pos.x), target_pos.y)
	position = Vector2(Helpers.pos_block_to_pixel(nearest_block)) # don't need to call _wrap_world_x() as the position in `nearest_block` is already wrapped
	current_pos = nearest_block

	if not _path_to_job: # pathing has finished
		# var distance = target_pos.distance_squared_to(job_active.pos)
		# print("[Character._process_jobs] distance_squared from active job: ", distance)

		if current_pos == job_active.pos:
			if job_active.type == Job.TYPE.GOTO:
				job_active = Job.NONE
			elif job_active.type == Job.TYPE.BREAK:
				_job_break(job_active)
			elif job_active.type == Job.TYPE.PLACE:
				_job_place(job_active)
			elif job_active.type == Job.TYPE.CRAFT:
				_job_craft(job_active)
			target_pos = Vector2i(-1, -1)

		else:
			print("[Character._process_jobs] pathfind didn't leave me exactly at job pos, nocliping to job pos: ", job_active)
			target_pos = job_active.pos


func _job_break(job) -> void:
	var tile: DataTile = GameScene.world.get_tile_v(job.pos)
	if tile == Tiles.AIR:
		print("[Character] Tried to break air at ", str(job.pos), ", character at ", str(current_pos))
		job_active = Job.NONE
		return
	else:
		inventory.add_items(tile.drops, 1)
		# TODO: drop items if inventory full
		GameScene.world.place_tile_v(job.pos, Tiles.AIR)
		print("[Character] broke tile ", tile, " at ", job.pos)
	job_active = Job.NONE
	return


func _job_place(job) -> void:
	var world_tile: DataTile = GameScene.world.get_tile_v(job.pos)
	if world_tile != Tiles.AIR:
		print("[Character:_job_place] Position %s is not air at time of job execution, not placing." % [job.pos])
		job_active = Job.NONE
		return
	var tile_string: String = job.data
	var tile: DataTile = DataTile.tile(tile_string)
	if tile:
		if inventory.has(tile_string):
			inventory.remove_items(tile_string)
			GameScene.world.place_tile_v(job.pos, tile)
			print("Placed tile ", tile, " at ", job.pos)
			job_active = Job.NONE
			return
		else:
			print("[Character:_job_place] Inventory is missing item: ", tile_string)
			job_active = Job.NONE
			return
	else:
		print("[Character:_job_place] Tile does not exist: ", tile_string)
		job_active = Job.NONE
		return


func _job_craft(job) -> void:
	# Verify we still have the ingredients
	if(!inventory.has_recipe_ingredients(job.data, job.data2)):
		print("[Character:_job_craft] Cancelled Job due to missing ingredients: ", job)
		job_active = Job.NONE
		return
	# open CraftingProgress (only once)
	if( active_crafting_progress == null ):
		active_crafting_progress = CRAFTING_PROGRESS_SCENE.instantiate()
		GameScene.world_canvas_layer.add_child(active_crafting_progress)
		active_crafting_progress.setup(job.data, job.data2, job.get_uuid(), job.pos)
		# remove items from inventory
		var recipe = DataRecipe.find(job.data)
		for ingredient: ItemStack in recipe.ingredients:
			inventory.remove_items(ingredient.item_name, ingredient.count * job.data2)
		# update inventory when craft_complete (attach signal)
		active_crafting_progress.craft_complete.connect(_on_craft_complete)
		# update job when update_job_status fires (attach signal)
		# finally remove job when update_job_status returns quantity 0
		active_crafting_progress.update_job_status.connect(_on_update_craft_job_status)
		# connect craft_cancelled to return leftover ingredients
		active_crafting_progress.craft_cancelled.connect(_on_craft_cancelled)
	else:
		var active_craft_progress_type: int = typeof(active_crafting_progress)
		print("[Character:_job_craft()] active_crafting_progress is not null: type = %d (%s)" % [active_craft_progress_type, type_string(active_craft_progress_type)])
	return


func _on_craft_complete(job_uuid: UUID, quantity_crafted: int) -> void:
	if !job_active.uuid_matches(job_uuid):
		print("[Character:_on_craft_complete()] job_uuid did not match active_job")
		return

	var recipe = DataRecipe.find(job_active.data)
	for result: ItemStack in recipe.results:
		print("[Character:_on_craft_complete()] attempting to add %d of %s to inventory" % [quantity_crafted * result.count, result.item_name])
		var items_left_over = inventory.add_items(result.item_name, quantity_crafted * result.count)

		if items_left_over > 0:
			print("[Character:_on_craft_complete()] dropping %d of %s that did not fit in inventory" % [items_left_over, result.item_name])
			drop_items(result.item_name, items_left_over)


func _on_update_craft_job_status(job_uuid: UUID, quantity_remaining: int) -> void:
	if !job_active.uuid_matches(job_uuid):
		print("[Character:_on_update_craft_job_status()] job_uuid did not match active_job")
		return

	job_active.data2 = quantity_remaining

	if quantity_remaining <= 0:
		print("[Character] Craft job finished: ", job_active)
		job_active = Job.NONE
		active_crafting_progress.queue_free()


func _on_craft_cancelled(job_uuid: UUID, quantity_remaining: int) -> void:
	if !job_active.uuid_matches(job_uuid):
		print("[Character:_on_craft_cancelled()] job_uuid did not match active_job")
		return

	# refund items
	var recipe = DataRecipe.find(job_active.data)
	for ingredient: ItemStack in recipe.ingredients:
		print("[Character:_on_craft_cancelled()] attempting to refund %d of %s to inventory" % [quantity_remaining * ingredient.count, ingredient.item_name])
		var items_left_over = inventory.add_items(ingredient.item_name, quantity_remaining * ingredient.count)

		if items_left_over > 0:
			print("[Character:_on_craft_cancelled()] dropping %d of %s that did not fit in inventory" % [items_left_over, ingredient.item_name])
			drop_items(ingredient.item_name, items_left_over)
	# cancel job
	job_active = Job.NONE


## Cancel the current job. TODO: cancel job by jobID
func cancel_job() -> bool:
	if job_active && job_active.type != Job.TYPE.NONE:
		job_active = Job.NONE
		return true
	else:
		print("[Character] Can't cancel Job.NONE")
		return false


func drop_items(item_name: String, count: int = 1) -> void:
	print("[Character:drop_items()] NOT IMPLEMENTED Dropped %d %s" % [count, item_name])


## Pathfind to the destination. Return true if pathfinding was successful
func _pathfind_to(destination: Vector2i) -> bool:
	if _path_to_job && _path_to_job.front() == destination:
		print("[Character]._pathfind_to() already pathing to destination.")
		return true
	
	if WorldConfig.superman():
		print("[Character] Superman Pathing to ", destination)
		_path_to_job = Path.new()
		_path_to_job.add_point(destination)
		return true
	print("[Character] Pathfinding from %s to %s." % [current_pos, destination])
	_path_to_job = Pathfinding.navigate(current_pos, destination)
	target_pos = Vector2i(-1, -1)

	if _path_to_job.size() <= 0: # if path is length 0, null it to avoid calling .destionation() on an empty path
		print("[Character] Pathfinding created null path")
		_path_to_job = null
	
	return _path_to_job != null
