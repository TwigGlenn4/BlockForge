class_name DataTexture

static var UNDEFINED := DataTexture.new("undefined")
static var tile_set: TileSet = null

var name: String
var atlas: int
var pos: Vector2i

func _init( texture_name:String, sprite_atlas:int = 0, sprite_pos:Vector2i = Vector2i(0,0) ):
	name = texture_name
	atlas = sprite_atlas
	pos = sprite_pos
	return

func get_texture() -> Texture2D:
	# loat tileset only once
	if tile_set == null:
		print("[DataTexture] loading tile set")
		tile_set = load("uid://dpfjjvmnau73i") # res://assets/textures/main_tileset.tres

	var tile_set_source := tile_set.get_source(atlas) as TileSetAtlasSource
	var texture_region := tile_set_source.get_tile_texture_region(pos)
	var tile_image := tile_set_source.texture.get_image().get_region(texture_region)

	return ImageTexture.create_from_image(tile_image)
	
