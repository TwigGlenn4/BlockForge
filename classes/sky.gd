extends Parallax2D

const SKY_PATH := "res://assets/textures/background/blue-sky-overlay-seamless-ish.png"
const SCROLL_SCALE := Vector2(0.15, 0.1)
const TILE_SCALE := 4.0

@onready var sprite: Sprite2D = $SkySprite

var _tile_size: Vector2 = Vector2.ZERO


func _ready():
	z_index = -100
	scroll_scale = SCROLL_SCALE
	_load_sky_texture()


func _load_sky_texture():
	var img := Image.new()
	var err := img.load(SKY_PATH)
	if err != OK:
		push_error("Sky: failed to load %s (error %s)" % [SKY_PATH, err])
		return
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = true
	sprite.scale = Vector2(TILE_SCALE, TILE_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tile_size = sprite.texture.get_size() * TILE_SCALE
	repeat_size = _tile_size
	_update_repeat_coverage()


func _process(_delta):
	_update_repeat_coverage()


# Parallax2D only draws repeat_times copies — grow that with zoom so tiles fill the view
func _update_repeat_coverage():
	if _tile_size.x <= 0.0 or _tile_size.y <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view_world: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var times_x: int = int(ceili(view_world.x / _tile_size.x)) + 2
	var times_y: int = int(ceili(view_world.y / _tile_size.y)) + 2
	repeat_times = maxi(times_x, times_y)
