extends Control

@export var recipe_name_label: Label
@export var result_label: Label
@export var progress_bar: ProgressBar
@export var time_left_label: Label
@export var cancel_button: Button

var recipe: DataRecipe
var recipe_count_prev: int
var recipe_count: int
var time_left: float

## Emits at the end of each crafting operation, including when the job is complete. This signal should spawn the recipe results.
## A quantity parameter is included in case multiple recipes complete within one frame.
signal craft_complete(recipe_id: String, quantity_crafted: int)

## Emits at the end of each crafting operation, including when the job is complete. This signal should update the job status and remove it when `quantity_remaining == 0`
## [br]TODO: add job_id param
signal update_job_status(recipe_id: String, quantity_remaining: int)

## setup the CraftingProgress instance with a recipe_id and quantity
func setup(recipe_id: String, num: int) -> void:
	recipe = DataRecipe.find(recipe_id)
	recipe_count = num
	recipe_count_prev = recipe_count

	
	progress_bar.max_value = recipe.duration
	time_left = num * recipe.duration

	_update_text_progress()
	_update_time_left(recipe.duration)

	cancel_button.button_up.connect(_on_cancel_pressed)

## The cancel button was pressed. Refund the remaining ingredients, cancel the job, and remove this CraftingProgress instance.
func _on_cancel_pressed() -> void:
	# TODO: use job ID to cancel job
	Interactor.selected_character.cancel_job()
	visible = false
	queue_free()


func _process(delta: float) -> void:
	time_left -= delta
	# print("[CraftingProgress] time left = " + str(time_left))
	
	var time_left_progressbar: float = fmod(time_left, recipe.duration)
	# print("[CraftingProgress] time left progressbar = " + str(time_left_progressbar))
	
	var progress_bar_new_value = recipe.duration - time_left_progressbar
	progress_bar.value = progress_bar_new_value
	_update_time_left(time_left_progressbar)

	recipe_count = maxi(int(ceilf(time_left / recipe.duration)), 0) # can never have less than 0 recipes left
	if recipe_count < recipe_count_prev:
		var recipes_completed = recipe_count_prev - recipe_count
		recipe_count_prev = recipe_count
		craft_complete.emit(recipe.id, recipes_completed)
		print("[CraftingProgress] Emitted craft_complete(%s, %d)" % [recipe.id, recipes_completed])

		update_job_status.emit(recipe.id, recipe_count)
		print("[CraftingProgress] Emitted update_job_status(%s, %d)" % [recipe.id, recipe_count])
		_update_text_progress()

		
	
	if time_left <= 0.0:
		print("[CraftingProgress] Craft done, removing this progress dialog")
		self.visible = false
		queue_free()


func _update_text_progress() -> void:
	var recipe_count_str: String = str(recipe_count) + "x "

	recipe_name_label.text = recipe_count_str + recipe.name

	var result_text: String = ""
	for result in recipe.results:
		result_text += recipe_count_str
		if result.count > 1:
			result_text += str(result.count) + " "
		result_text += result.item_name + "\n"

	result_label.text = result_text.substr(0, result_text.length()-1) # substr to remove trailing '\n'

func _update_time_left(current_recipe_time_left: float) -> void:
	if recipe_count > 1:
		time_left_label.text = Helpers.time_str_sec(time_left)
	else:
		time_left_label.text = Helpers.time_str_sec(current_recipe_time_left) + " / " + Helpers.time_str_sec(time_left)
