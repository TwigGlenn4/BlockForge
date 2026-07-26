# Generic full-screen loading overlay. Optional TextureRect for a future splash graphic.
class_name LoadingScreen
extends CanvasLayer

@export var backdrop: ColorRect
@export var graphic: TextureRect
@export var progress_bar: ProgressBar
@export var status_label: Label

var _step: int = 0
var _max_steps: int = 1


func _ready() -> void:
	layer = 100
	visible = true
	if graphic:
		graphic.visible = graphic.texture != null
	if progress_bar:
		progress_bar.value = 0.0
	if status_label:
		status_label.text = "Loading…"


func begin(max_steps: int, message: String = "Loading…") -> void:
	_max_steps = maxi(1, max_steps)
	_step = 0
	visible = true
	if progress_bar:
		progress_bar.max_value = float(_max_steps)
		progress_bar.value = 0.0
	set_status(message)


func set_status(message: String) -> void:
	if status_label:
		status_label.text = message


func advance(message: String = "") -> void:
	_step = mini(_step + 1, _max_steps)
	if progress_bar:
		progress_bar.value = float(_step)
	if not message.is_empty():
		set_status(message)


func finish() -> void:
	if progress_bar:
		progress_bar.value = float(_max_steps)
	visible = false
