extends Control
class_name JobVisualizer

static var _all_visualizers: Dictionary[UUID, JobVisualizer]

@export var button: Button
@export var icon: TextureRect

@export var texture_job_goto: Texture2D
@export var texture_job_break: Texture2D

var _character: Character
var _job_id: UUID
var _job_type: Job.TYPE

func setup(character: Character, job: Job) -> void:
	self._character = character
	self._job_id = job.get_uuid()
	self._job_type = job.type

	_all_visualizers.set(_job_id, self)

	match job.type:
		Job.TYPE.NONE:
			icon.texture = null
		Job.TYPE.GOTO:
			icon.texture = texture_job_goto
		Job.TYPE.BREAK:
			icon.texture = texture_job_break
		Job.TYPE.PLACE:
			var tile := Tiles.find(job.data)
			var texture := tile.texture.get_texture()
			icon.texture = texture
		Job.TYPE.CRAFT:
			var recipe := DataRecipe.find(job.data)
			var stack: ItemStack = recipe.results.front()
			var item := stack.get_item()
			var texture := item.texture.get_texture()
			icon.texture = texture
	
	button.pressed.connect(_on_button_pressed)

	GameScene.world_canvas_layer.add_child(self)
	var job_pos_pxl: Vector2i = Helpers.pos_block_to_pixel(job.pos)
	position = job_pos_pxl + Vector2i(-8, -16)

	GameScene.selected_character_changed.connect(_on_selected_character_changed)

## Only visible when owned by the selected _character
func _on_selected_character_changed(new_char: Character) -> void:
	visible = _character == new_char
	

func _on_button_pressed() -> void:
	print("[JobVisualizer] pressed job with id ", _job_id)
	if _job_type == Job.TYPE.CRAFT:
		print("[JobVisualizer] Can't cancel craft job by clicking!")
	else:
		_character.cancel_job(_job_id)

static func remove_by_uuid(job_id: UUID) -> void:
	var job_vis = _all_visualizers.get(job_id)
	if job_vis:
		job_vis.queue_free()
