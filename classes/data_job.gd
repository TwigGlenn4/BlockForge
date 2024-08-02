class_name DataJob

enum TYPE {
  NONE,  # for uninitalized jobs
  GOTO,
  BREAK, # data=tool
  PLACE, # data=block
  CRAFT  # data=recipe   data2=count
}

var pos: Vector2i = Vector2i(-1,-1)
var type: TYPE
var data: String
var data2: int

func _init(job_pos:Vector2i=Vector2i(-1,-1), job_type:TYPE=TYPE.NONE, job_data:String = "", job_data2:int=0):
  pos = job_pos
  type = job_type
  data = job_data
  data2 = job_data2

func _to_string():
  var type_str = "none"
  if type == TYPE.GOTO:
    type_str = "goto"
  return "Job: %s %s." % [type_str, pos]