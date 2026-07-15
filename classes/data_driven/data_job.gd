## DataJob Class stores all info about a particular job and belongs to a Character
## Valid Types: NONE, GOTO, BREAK, PLACE, CRAFT

class_name DataJob

## Job types
enum TYPE {
	## For uninitalized Jobs
	NONE,  # for uninitalized jobs
	GOTO,
	## [code]data: String[/code] tool
	BREAK,
	## [code]data: String[/code] block/tile
	PLACE,
	## [code]data: String[/code] recipe, [code]data2: int[/code] count
	CRAFT
}

static var NONE: DataJob = DataJob.new(TYPE.NONE)

var pos: Vector2i = Vector2i(-1,-1) # block position of job
var type: TYPE
## TYPE=BREAK, data = tool[br]
## TYPE=PLACE, data = tileString[br]
## TYPE=CRAFT, data = recipe
var data: String
## TYPE=CRAFT, data2 = count
var data2: int

## DataJob Constructor: All info needed to create a job
## 
## Params: [br]
## [job_pos: Vector2i]: The position the job target exists at. The character should choose where to stand to interact with this location. [br]
## [job_type: DataJob.TYPE]: The type of the job, see DataJob.TYPE [br]
## [job_data: String]: Required for BREAK (tool), PLACE (block/tile), and CRAFT (recipe) job types. [br]
## [job_data2" int]: Required for CRAFT job type: number of times to perform the recipe.
func _init(job_type:TYPE, job_pos:Vector2i = Vector2i.MIN, job_data:String = "_", job_data2:int = -1):
	type = job_type
	pos = job_pos
	data = job_data
	data2 = job_data2
	_validate()

func _to_string():
	var type_str = "none"
	if type == TYPE.GOTO:
		type_str = "goto"
	return "Job: %s %s." % [type_str, pos]

func _validate() -> void:
	if type != TYPE.NONE && pos == Vector2i.MIN:
		assert(pos != null, "[DataJob] Job lacks position")
		return

	match type:
		TYPE.NONE:
			pass
		TYPE.GOTO:
			pass
		TYPE.BREAK:
			# TODO: validate tool
			pass
		TYPE.PLACE:
			assert(data != "_", "[DataJob] PLACE job missing param: data")
			assert(DataTile.exists(data), "[DataJob] PLACE job has invalid data: \"" + data + "\" is not a tile")
		TYPE.CRAFT:
			# TODO: validate crafting
			assert(data != "_", "[DataJob] CRAFT job missing param: data")
			assert(data2 != -1, "[DataJob] CRAFT job missing param: data2")
		_:
			assert(TYPE.has(type), "[DataJob] Invalid job type")
	
	return
			
