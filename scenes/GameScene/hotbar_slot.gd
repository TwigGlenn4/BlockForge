class_name HotbarSlot
extends Control

signal slot_selected(slot_number)

@export var button_bg: TextureButton
@export var item_icon: TextureRect
@export var item_count_label: Label

@export var bg_texture_unselected: Texture2D
@export var bg_texture_selected: Texture2D


var slot_num: int
var selected: bool:
	set(value):
		if selected != value: # if selected has changed
			if value == true:
				button_bg.texture_normal = bg_texture_selected
			else:
				button_bg.texture_normal = bg_texture_unselected
		selected = value

		


func setup(num: int) -> void:
	slot_num = num
	name = name + str(num)

	# ensure icon and count are blanked
	item_icon.visible = false
	item_icon.texture = Texture2D.new()
	item_count_label.text = ""
	
	# set keybind


func set_stack(stack: ItemStack) -> void:
	if stack == null or stack.item_name == "":
		item_icon.visible = false
		item_icon.texture = Texture2D.new()
		item_count_label.text = ""
		return
	
	item_icon.texture = stack.get_item().texture.get_texture()
	item_icon.visible = true
	item_count_label.text = str(stack.count)


func _on_button_bg_pressed() -> void:
	print("[HotbarSlot] slot ", slot_num, " clicked.")
	slot_selected.emit(slot_num)





