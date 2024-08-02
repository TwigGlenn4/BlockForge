extends Node2D
class_name Character

var current_pos: Vector2i = Vector2i(0,0)
var target_pos: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
  pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
  var target_pixels: Vector2i = Helpers.pos_block_to_pixel(target_pos)

  if target_pos != Vector2i(-1,-1):
    lerp_timer += delta*0.04
    position = position.lerp(target_pixels, lerp_timer)
    # print("lerped to "+str(position))
    if position == Vector2(target_pixels):
      lerp_timer = 0
      target_pos = Vector2i(-1,-1)


  current_pos = Helpers.pos_pixel_to_block(position)
  

func _go_to_portal(pixel_pos:Vector2):
  print("Targeting character to "+str(pixel_pos))
  target_pos = pixel_pos