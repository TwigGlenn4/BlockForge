extends Node2D
class_name Character

var active_crafting_progress: CraftingProgress = null
@export var CRAFTING_PROGRESS_SCENE: Resource

## Use `Interactor.selected_character_inventory_changed` where possible, it handles reconnecting when `Interactor.selected_character` changes.
signal inventory_changed


var current_pos: Vector2i = Vector2i(0,0)   # block pos Vector
var target_pos: Vector2i = Vector2i(-1,-1)  # block pos Vector
var lerp_timer: float = 0.0

var job_queue: Array[Job] = []
var job_active: Job = Job.NONE

var stats = {
	speed = 10.0 #   Character speed in blocks per second.
}

var inventory: Inventory = Inventory.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	if target_pos != Vector2i(-1,-1):
		var target_pixels: Vector2i = Helpers.pos_block_to_pixel(target_pos)
		position = position.move_toward(target_pixels, delta*(stats.speed*16))
	
	if inventory.contents_changed_check():
		inventory_changed.emit()


func _physics_process(_delta):
	_try_queue_next_job()
	
	current_pos = Helpers.pos_pixel_to_block(position)
	_process_jobs()


func _try_queue_next_job() -> void:
	if (not job_queue.is_empty()) and job_active.type == Job.TYPE.NONE: # if job queue contains job and there is no active job, go to next job
		job_active = job_queue.pop_front()
		target_pos = job_active.pos
		print("Activating "+job_active._to_string())

func add_job(job:Job) -> void:
	job_queue.push_back(job)
	#print("added "+str(job._to_string()))



func _set_target_pos(block_pos:Vector2):
	var goto_job = Job.new(Job.TYPE.GOTO, block_pos)
	print("Prepending "+goto_job._to_string())
	job_queue.push_front(goto_job)



func _teleport_to(block_pos:Vector2):
	position = Helpers.pos_block_to_pixel(block_pos)


func open_inventory():
	print(inventory)


func _process_jobs():
	if position == Vector2(Helpers.pos_block_to_pixel(target_pos)):
		if target_pos == job_active.pos:
			if job_active.type == Job.TYPE.GOTO:
				job_active = Job.NONE
			if job_active.type == Job.TYPE.BREAK:
				_job_break(job_active)
			elif job_active.type == Job.TYPE.PLACE:
				_job_place(job_active)
			elif job_active.type == Job.TYPE.CRAFT:
				_job_craft(job_active)

		target_pos = Vector2i(-1,-1)
		

func _job_break(job) -> void:
	var tile: DataTile = Interactor.world.get_tile_v(job.pos)
	if tile == Tiles.AIR:
		print("Tried to break air at ", str(job.pos), ", character at ", str(current_pos))
		job_active = Job.NONE
		return
	else:
		inventory.add_items(tile.drops, 1)
		# TODO: drop items if inventory full
		Interactor.world.place_tile_v(job.pos, Tiles.AIR)
		print("broke tile ", tile, " at ", job.pos)
	job_active = Job.NONE
	return

func _job_place(job) -> void:
	var world_tile: DataTile = Interactor.world.get_tile_v(job.pos)
	if world_tile != Tiles.AIR:
		print("[Character:_job_place] Position %s is not air at time of job execution, not placing." % [job.pos])
		job_active = Job.NONE
		return
	var tile_string: String = job.data
	var tile: DataTile = DataTile.tile(tile_string)
	if tile:
		if inventory.has(tile_string):
			inventory.remove_items(tile_string)
			Interactor.world.place_tile_v(job.pos, tile)
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
		Interactor.world_canvas_layer.add_child(active_crafting_progress)
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


##
func drop_items(item_name: String, count: int = 1) -> void:
	print("[Character:drop_items()] NOT IMPLEMENTED Dropped %d %s" % [count, item_name])
