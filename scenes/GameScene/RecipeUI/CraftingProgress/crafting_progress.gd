extends Control
class_name CraftingProgress

@export var recipe_name_label: Label
@export var result_label: Label
@export var progress_bar: ProgressBar
@export var time_left_label: Label
@export var cancel_button: Button

var _recipe: DataRecipe
var _recipe_count_prev: int
var _recipe_count: int
var _job_uuid: UUID
var _time_left: float

## Emits at the end of each crafting operation, including when the job is complete. This signal should spawn the _recipe results.
## A quantity parameter is included in case multiple recipes complete within one frame.
signal craft_complete(job_uuid: UUID, quantity_crafted: int)

## Emits at the end of each crafting operation, including when the job is complete. This signal should update the job status and remove it when `quantity_remaining == 0`
signal update_job_status(job_uuid: UUID, quantity_remaining: int)

## Emits when a crafting job is cancelled. This signal should refund ingredients and cancel the job.
signal craft_cancelled(job_uuid: UUID, quantity_remaining: int)

## setup the CraftingProgress instance with a recipe_id and quantity
func setup(recipe_id: String, num: int, job_uuid: UUID, workstation_pos: Vector2i) -> void:
	_recipe = DataRecipe.find(recipe_id)
	_recipe_count = num
	_recipe_count_prev = _recipe_count
	_job_uuid = job_uuid

	# set position to above workstation
	var pixel_pos = Vector2(Helpers.pos_block_to_pixel(workstation_pos + Vector2i(0,1))) - Vector2(size.x/2, size.y)
	set_position(pixel_pos)
	
	progress_bar.max_value = _recipe.duration
	_time_left = num * _recipe.duration

	_update_text_progress()
	_update_time_left()

	cancel_button.button_up.connect(_on_cancel_pressed)

## The cancel button was pressed. Refund the remaining ingredients, cancel the job, and remove this CraftingProgress instance.
func _on_cancel_pressed() -> void:
	# print("[CraftingProgress] Emitted craft_cancelled(%s, %d)" % [_job_uuid, _recipe_count])
	craft_cancelled.emit(_job_uuid, _recipe_count)
	queue_free()


func _process(delta: float) -> void:
	_time_left -= delta
	# print("[CraftingProgress] time left = " + str(_time_left))
	
	var time_left_progressbar: float = fmod(_time_left, _recipe.duration)
	# print("[CraftingProgress] time left progressbar = " + str(time_left_progressbar))
	
	var progress_bar_new_value = _recipe.duration - time_left_progressbar
	progress_bar.value = progress_bar_new_value
	_update_time_left()

	_recipe_count = maxi(int(ceilf(_time_left / _recipe.duration)), 0) # can never have less than 0 recipes left
	if _recipe_count < _recipe_count_prev:
		var recipes_completed = _recipe_count_prev - _recipe_count
		_recipe_count_prev = _recipe_count
		craft_complete.emit(_job_uuid, recipes_completed)
		# print("[CraftingProgress] Emitted craft_complete(%s, %d)" % [_job_uuid, recipes_completed])

		update_job_status.emit(_job_uuid, _recipe_count)
		# print("[CraftingProgress] Emitted update_job_status(%s, %d)" % [_job_uuid, _recipe_count])
		_update_text_progress()

		
	
	if _time_left <= 0.0:
		# print("[CraftingProgress] Craft done, removing this progress dialog")
		self.visible = false
		queue_free()
	scale = Vector2.ONE / Interactor.main_camera.zoom


func _update_text_progress() -> void:
	var recipe_count_str: String = str(_recipe_count) + "x "

	recipe_name_label.text = recipe_count_str + _recipe.name

	var result_text: String = ""
	for result in _recipe.results:
		result_text += recipe_count_str
		if result.count > 1:
			result_text += str(result.count) + " "
		result_text += result.item_name + "\n"

	result_label.text = result_text.substr(0, result_text.length()-1) # substr to remove trailing '\n'

func _update_time_left() -> void:
	time_left_label.text = Helpers.time_str_sec(_time_left)
