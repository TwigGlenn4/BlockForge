extends Control

const HOTBAR_NUM_SLOTS: int = 8
static var SLOT_TEXTURE = load("res://assets/textures/atlas/inventory_slot.png")

static var HOTBAR_SLOT_SCENE = preload("res://scenes/GameScene/HotbarSlot/HotbarSlot.tscn")

var hotbar: Array[HotbarSlot]
var selected_slot: int = 0

func _ready() -> void:
	_build_hotbar(HOTBAR_NUM_SLOTS)
	_on_hotbar_slot_selected(0)

	get_tree().get_root().size_changed.connect(_window_resized)
	_window_resized()
	Interactor.selected_character_inventory_changed.connect(_on_character_inventory_changed)


func _window_resized() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var slot_height_px: float = hotbar[0].size.y
	var slot_width_anchor: float = slot_height_px / viewport_size.x

	anchor_left = ANCHOR_END - slot_width_anchor


func _on_character_inventory_changed() -> void:
	_update_inventory_contents()

func _update_inventory_contents() -> void:
	print("[InventoryUI] updating hotbar contents")
	var inv := Interactor.selected_character.inventory
	for i:int in hotbar.size():
		hotbar[i].set_stack(inv.contents[i])

func _build_hotbar( num_slots: int) -> void:
	var hotbar_slot_size: float = 1.0 / HOTBAR_NUM_SLOTS ## Hotbar slot size in anchor units

	hotbar.resize(num_slots)
	for i: int in num_slots:
		hotbar[i] = _build_hotbar_slot(i)
		add_child(hotbar[i])

		# position the slot
		var anchor_from_start: float = hotbar_slot_size * i  ## Anchor value for start of hotbar, this var exists to simplify vertical/horizontal hotbar implementation.
		var anchor_from_end: float = anchor_from_start + hotbar_slot_size  ## Anchor value for end of hotbar, this var exists to simplify vertical/horizontal hotbar implementation.
		hotbar[i].anchor_top = anchor_from_start
		hotbar[i].anchor_bottom = anchor_from_end
		# print("[Hotbar] set slot " + str(i) + " anchored from " + str(anchor_from_start) + " to " + str(anchor_from_end))

		# attach hotbar_slot.slot_selected signal
		hotbar[i].slot_selected.connect(_on_hotbar_slot_selected)

func _build_hotbar_slot(num: int) -> Control:
	var slot: Control = HOTBAR_SLOT_SCENE.instantiate()
	slot.setup(num)
	return slot	

func _on_hotbar_slot_selected(selected_slot_num: int) -> void:
	selected_slot = selected_slot_num


func get_held_item_stack() -> ItemStack:
	return Interactor.selected_character.inventory.contents[selected_slot]
