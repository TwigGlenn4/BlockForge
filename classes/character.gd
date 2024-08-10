extends Node2D
class_name Character

var current_pos: Vector2i = Vector2i(0,0)   # block pos Vector
var target_pos: Vector2i = Vector2i(-1,-1)  # block pos Vector
var lerp_timer: float = 0.0

var job_queue: Array[DataJob] = []
var job_active: DataJob = DataJob.new()

var stats = {
  speed = 10.0 #   Character speed in blocks per second.
}

var inventory: Inventory

# Called when the node enters the scene tree for the first time.
func _ready():
  pass # Replace with function body.



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

  if target_pos != Vector2i(-1,-1):
    var target_pixels: Vector2i = Helpers.pos_block_to_pixel(target_pos)

    position = position.move_toward(target_pixels, delta*(stats.speed*16))

    if position == Vector2(target_pixels):
      if target_pos == job_active.pos:
        job_active = DataJob.new() # reset to NONE job
      target_pos = Vector2i(-1,-1)
      


func _physics_process(_delta):
  if (not job_queue.is_empty()) and job_active.type == DataJob.TYPE.NONE: # if job queue contains job and there is no active job, go to next job
    job_active = job_queue.pop_front()
    target_pos = job_active.pos
    print("Activating "+job_active._to_string())

  current_pos = Helpers.pos_pixel_to_block(position)
  


func _add_job(job:DataJob):
  job_queue.push_back(job)
  print("added "+str(job._to_string()))



func _set_target_pos(block_pos:Vector2):
  var goto_job = DataJob.new(block_pos, DataJob.TYPE.GOTO)
  print("Prepending "+goto_job._to_string())
  job_queue.push_front(goto_job)



func _teleport_to(block_pos:Vector2):
  position = Helpers.pos_block_to_pixel(block_pos)