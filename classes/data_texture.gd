class_name DataTexture

# var UNDEFINED = DataTexture.new("undefined")

var name:String = ""
var atlas:int = 0
var pos:Vector2i = Vector2i(0, 0)

func _init( texture_name:String, sprite_atlas:int = 0, sprite_pos:Vector2i = Vector2i(0,0) ):
  name = texture_name
  atlas = sprite_atlas
  pos = sprite_pos
  return


