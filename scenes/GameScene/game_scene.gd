# This script is for handling things that relate to the entire world instance, including
# static references to commonly needed nodes and signals.

extends Node2D
class_name GameScene

static var world: World
static var main_camera: Interactor
static var inventory_ui: Control
static var main_ui: CanvasLayer
static var world_canvas_layer: CanvasLayer

static var selected_character: Character:
	set(new_char):
		if new_char != selected_character:
			# disconnect inventory_changed signal from selected_character
			if selected_character && selected_character.inventory_changed.is_connected(_on_selected_character_inventory_changed_internal):
				selected_character.inventory_changed.disconnect(_on_selected_character_inventory_changed_internal)
			# update selected character
			selected_character = new_char
			# reconnect inventory_changed signal to new character
			selected_character.inventory_changed.connect(_on_selected_character_inventory_changed_internal)
			# emit signals that selected_character and inventory have changed
			selected_character_changed.emit(selected_character)
			selected_character_inventory_changed.emit()

## This signal emits when `Interactor.selected_character` changes
static var selected_character_changed: Signal = _create_static_signal("selected_character_changed", ["new_char", typeof(Character)])
## This signal emits when `Interactor.selected_character`'s inventory changes, or when `Interactor.selected_character` itself changes
static var selected_character_inventory_changed: Signal = _create_static_signal("selected_character_inventory_changed")


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
	selected_character_inventory_changed.emit()


func _ready():
	# set static references
	# these don't use get_node_or_null() because these node references aren't optional.
	selected_character = get_node("World/Character")
	world = get_node("World")
	main_ui = get_node("World/MainCamera/MainUI")
	inventory_ui = get_node("World/MainCamera/MainUI/InventoryUI")
	world_canvas_layer = get_node("World/WorldCanvasLayer")
	main_camera = get_node("World/MainCamera")
