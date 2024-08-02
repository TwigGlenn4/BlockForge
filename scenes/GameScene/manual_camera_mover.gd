extends Camera2D

const PAN_SPEED = 10
const ZOOM_SPEED = 0.05

@onready var world = get_node("/root/GameScene/World")

var generating_chunks_enabled = false

# Called when the node enters the scene tree for the first time.
func _ready():
  pass # Replace with function body.


func _physics_process(delta):
  # Pan controls
  var movement = Vector2.ZERO
  if Input.is_action_pressed("camera_pan_left"):
    movement += Vector2(-PAN_SPEED, 0)
  if Input.is_action_pressed("camera_pan_right"):
    movement += Vector2(PAN_SPEED, 0)
  if Input.is_action_pressed("camera_pan_up"):
    movement += Vector2(0, -PAN_SPEED)
  if Input.is_action_pressed("camera_pan_down"):
    movement += Vector2(0, PAN_SPEED)
  position += movement * (Vector2.ONE/zoom) * ( delta / 0.0166)

  if Input.is_action_pressed("look_at_portal"): # centers camera on bottom block of portal anim
    position = Helpers.pos_block_to_pixel(world.world_portal_pos)


  # Generate 3 chunks at camera
  if generating_chunks_enabled:
    var chunk_num:int = Helpers.pos_pixel_to_block(position).x / Chunk.WIDTH
    if chunk_num > 0 and chunk_num < world.width-1:
      if world.chunks[chunk_num].gen_state != Chunk.GEN_STATE_MAX:
        world.worldgen.queue_chunk(chunk_num, Chunk.GEN_STATE_MAX)
      if world.chunks[chunk_num-1].gen_state != Chunk.GEN_STATE_MAX:
        world.worldgen.queue_chunk(chunk_num-1, Chunk.GEN_STATE_MAX)
      if world.chunks[chunk_num+1].gen_state != Chunk.GEN_STATE_MAX:
        world.worldgen.queue_chunk(chunk_num+1, Chunk.GEN_STATE_MAX)


# Zoom controls in _input to properly accept mouse wheel input
func _input(event):
  if event.is_action_pressed("camera_zoom_in"):
    zoom += Vector2(ZOOM_SPEED, ZOOM_SPEED)
  if event.is_action_pressed("camera_zoom_out"):
    zoom += Vector2(-ZOOM_SPEED, -ZOOM_SPEED)
  
  zoom = zoom.clamp(Vector2(0.02, 0.02), Vector2(3,3))
  scale = Vector2(1 / zoom.x, 1 / zoom.y)

  if event.is_action_pressed("print_pointer_location"):
    print("Mouse is at: ", get_global_mouse_position()/16)
