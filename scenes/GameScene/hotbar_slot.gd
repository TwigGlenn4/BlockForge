class_name HotbarSlot
extends Control

signal slot_selected(slot_number)

@export var button_bg: TextureButton
@export var item_icon: TextureRect
@export var item_count_label: Label

var slot_num: int
var selected: bool


func setup(num: int) -> void:
	slot_num = num
	name = name + str(num)

	# ensure icon and count are blanked
	item_icon.visible = false
	item_icon.texture = null
	item_count_label.text = ""
	
	# set keybind


func set_stack(stack: ItemStack) -> void:
	if stack == null or stack.item_name == "":
		item_icon.visible = false
		item_icon.texture = null
		item_count_label.text = ""
		return
	
	item_icon.texture = stack.get_item().texture.get_texture()
	item_icon.visible = true
	item_count_label.text = str(stack.count)


func _on_button_bg_pressed() -> void:
	print("[HotbarSlot] slot ", slot_num, " clicked.")
	slot_selected.emit(slot_num)
