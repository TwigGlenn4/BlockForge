extends Node2D
class_name Character

## Use `Interactor.selected_character_inventory_changed` where possible, it handles reconnecting when `Interactor.selected_character` changes.
signal inventory_changed


var current_pos: Vector2i = Vector2i(0,0)   # block pos Vector
var target_pos: Vector2i = Vector2i(-1,-1)  # block pos Vector
var lerp_timer: float = 0.0

var job_queue: Array[DataJob] = []
var job_active: DataJob = DataJob.NONE

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
	if (not job_queue.is_empty()) and job_active.type == DataJob.TYPE.NONE: # if job queue contains job and there is no active job, go to next job
		job_active = job_queue.pop_front()
		target_pos = job_active.pos
		#print("Activating "+job_active._to_string())
	
	current_pos = Helpers.pos_pixel_to_block(position)
	_process_jobs()

	


func add_job(job:DataJob) -> void:
	job_queue.push_back(job)
	#print("added "+str(job._to_string()))



func _set_target_pos(block_pos:Vector2):
	var goto_job = DataJob.new(DataJob.TYPE.GOTO, block_pos)
	print("Prepending "+goto_job._to_string())
	job_queue.push_front(goto_job)



func _teleport_to(block_pos:Vector2):
	position = Helpers.pos_block_to_pixel(block_pos)


func open_inventory():
	print(inventory)


func _process_jobs():
	if position == Vector2(Helpers.pos_block_to_pixel(target_pos)):
		if target_pos == job_active.pos:
			if job_active.type == DataJob.TYPE.BREAK:
				_job_break(job_active)
			elif job_active.type == DataJob.TYPE.PLACE:
				_job_place(job_active)

			job_active = DataJob.NONE # reset to NONE job
		target_pos = Vector2i(-1,-1)
		

func _job_break(job) -> bool:
	var tile: DataTile = Interactor.world.get_tile_v(job.pos)
	if tile == Tiles.AIR:
		print("Tried to break air at ", str(job.pos), ", character at ", str(current_pos))
		return false
	else:
		inventory.add_items(tile.drops, 1)
		# TODO: drop items if inventory full
		Interactor.world.place_tile_v(job.pos, Tiles.AIR)
		print("broke tile ", tile, " at ", job.pos)
	return true

func _job_place(job) -> bool:
	var tile_string: String = job.data
	var tile: DataTile = DataTile.tile(tile_string)
	if tile:
		if inventory.has(tile_string):
			inventory.remove_items(tile_string)
			Interactor.world.place_tile_v(job.pos, tile)
			print("Placed tile ", tile, " at ", job.pos)
			return true
		else:
			print("[Character:_job_place] Inventory is missing item: ", tile_string)
			return false
	else:
		print("[Character:_job_place] Tile does not exist: ", tile_string)
		return false

## Cancel the current job. TODO: cancel job by jobID
func cancel_job() -> bool:
	if job_active && job_active.type != DataJob.TYPE.NONE:
		job_active = DataJob.NONE
		return true
	else:
		print("[Character] Can't cancel DataJob.NONE")
		return false
