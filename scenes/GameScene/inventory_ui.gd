extends Control

const HOTBAR_SLOTS: int = 8

var SLOT_TEXTURE = load("res://assets/textures/atlas/inventory_slot.png")

var hotbar: Array[TextureButton]

func _ready() -> void:
	get_tree().get_root().size_changed.connect(_window_resized)


	hotbar.resize(HOTBAR_SLOTS)
	for i: int in HOTBAR_SLOTS:
		var slot: TextureButton = TextureButton.new()
		slot.name = "HotbarSlot"+str(i)
		slot.texture_normal = SLOT_TEXTURE
		slot.stretch_mode = TextureButton.STRETCH_SCALE
		slot.set_anchors_preset(Control.LayoutPreset.PRESET_CENTER_RIGHT)
		self.add_child(slot)
		hotbar[i] = slot

	_window_resized()

	
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

	# position.x = viewport_size.x - target_size.x

	for i: int in hotbar.size():
		var slot = hotbar[i]
		slot.position = Vector2(0, i * target_size.x)
		slot.size = Vector2(target_size.x, target_size.x)
		



	# size = target_size
	# offset_bottom = 0
	# offset_top = 0
	# offset_left = 0
	# offset_right = 0
	print("[InventoryUI_manual] resized to ", size, " at ", position, " viewport size ", viewport_size)
