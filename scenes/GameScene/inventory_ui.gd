extends Control

const HOTBAR_SLOTS: int = 8
static var SLOT_TEXTURE = load("res://assets/textures/atlas/inventory_slot.png")

static var HOTBAR_SLOT_SCENE = preload("res://scenes/GameScene/HotbarSlot/HotbarSlot.tscn")

var hotbar: Array[HotbarSlot]
var selected_character: Character

func _ready() -> void:
	get_tree().get_root().size_changed.connect(_window_resized)

	hotbar.resize(HOTBAR_SLOTS)
	for i: int in HOTBAR_SLOTS:
		hotbar[i] = _build_hotbar_slot(i)
		self.add_child(hotbar[i])

	_window_resized()


func _process(_delta: float) -> void:
	if selected_character.inventory.contents_changed_check():
		_update_inventory_contents()
	

func _window_resized() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var target_size: Vector2 = Vector2.ZERO

	if viewport_size.y < viewport_size.x / 2.0:
		target_size.y = viewport_size.y
	else:
		target_size.y = viewport_size.y * 0.75


	target_size.x = target_size.y / float(HOTBAR_SLOTS)
	anchor_left = 1.0 - (target_size.x/viewport_size.x)

	var height_percent: float = target_size.y / viewport_size.y
	anchor_top = (1.0 - height_percent) / 2.0
	anchor_bottom = 1.0 - ((1.0 - height_percent) / 2.0)

	for i: int in hotbar.size():
		var slot = hotbar[i]
		slot.position = Vector2(0, i * target_size.x)
		slot.size = Vector2(target_size.x, target_size.x)
	# print("[InventoryUI_manual] resized to ", size, " at ", position, " viewport size ", viewport_size)

func _on_selected_character_changed(new_char: Character) -> void:
	# store the character reference to show it's inventory
	selected_character = new_char

func _update_inventory_contents() -> void:
	print("[InventoryUI] updating hotbar contents")
	var inv := selected_character.inventory
	for i:int in hotbar.size():
		hotbar[i].set_stack(inv.contents[i])
	

func _build_hotbar_slot(num: int) -> Control:
	var slot: Control = HOTBAR_SLOT_SCENE.instantiate()
	slot.setup(num)
	return slot	
