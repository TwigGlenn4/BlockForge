extends Camera2D

const PAN_SPEED = 10
const ZOOM_SPEED = 0.05
const LERP_TIME = 0.5

@onready var world = get_node("/root/GameScene/World")
@onready var selected_character = get_node("/root/GameScene/World/Character")

var generating_chunks_enabled = false

# move camera to position
var lerp_target: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
  pass # Replace with function body.


func _process(delta):
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

  if lerp_target != Vector2i(-1,-1):
    lerp_timer += delta/LERP_TIME
    clampf(lerp_timer, 0.0, 1.0)
    position = position.lerp(lerp_target, lerp_timer)
    # print("lerped to "+str(position))
    if position == Vector2(lerp_target):
      print("lerp done, delta = "+str(delta))
      lerp_timer = 0
      lerp_target = Vector2i(-1,-1)

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
  
  if Input.is_action_pressed("look_at_portal"): # centers camera on bottom block of portal anim
    _move_to_block(world.world_portal_pos)

  
  if Input.is_action_just_pressed("click"):
    var click_pos:Vector2 = get_global_mouse_position()
    print("click_pos = "+str(click_pos))

    var block_pos:Vector2i = Helpers.pos_pixel_to_block(click_pos)
    print("block_pos = "+str(block_pos))
    selected_character._set_target_pos(block_pos)


func _move_to_block(block_pos:Vector2i):
  lerp_target = Helpers.pos_block_to_pixel(block_pos)
  lerp_timer = 0
