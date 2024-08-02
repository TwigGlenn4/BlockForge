extends Node2D
class_name Character

var current_pos: Vector2i = Vector2i(0,0)   # block pos Vector
var target_pos: Vector2i = Vector2i(-1,-1)  # block pos Vector
var lerp_timer: float = 0.0

var job_queue: Array[DataJob] = []
var job_active: DataJob = DataJob.new()

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
      if target_pos == job_active.pos:
        job_active = DataJob.new() # reset to NONE job
      target_pos = Vector2i(-1,-1)
      

  if (not job_queue.is_empty()) and job_active.type == DataJob.TYPE.NONE: # if job queue contains job and there is no active job, go to next job
    print("Activating "+job_active._to_string())
    job_active = job_queue.pop_front()
    target_pos = job_active.pos

  current_pos = Helpers.pos_pixel_to_block(position)
  

func _add_job(job:DataJob):
  job_queue.push_back(job)
  print("added "+str(job._to_string()))

func _set_target_pos(block_pos:Vector2):
  print("Targeting character to "+str(block_pos))
  target_pos = block_pos
