## Job Class stores all info about a particular job and belongs to a Character
## Valid Types: NONE, GOTO, BREAK, PLACE, CRAFT

class_name Job

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

static var NONE: Job = Job.new(TYPE.NONE)

var pos: Vector2i = Vector2i(-1,-1) # block position of job
var type: TYPE
## TYPE=BREAK, data = tool[br]
## TYPE=PLACE, data = tileString[br]
## TYPE=CRAFT, data = recipe
var data: String
## TYPE=CRAFT, data2 = count
var data2: int

var _uuid: PackedByteArray

## Job Constructor: All info needed to create a job
## 
## Params: [br]
## [job_pos: Vector2i]: The position the job target exists at. The character should choose where to stand to interact with this location. [br]
## [job_type: Job.TYPE]: The type of the job, see Job.TYPE [br]
## [job_data: String]: Required for BREAK (tool), PLACE (block/tile), and CRAFT (recipe) job types. [br]
## [job_data2" int]: Required for CRAFT job type: number of times to perform the recipe.
func _init(job_type:TYPE, job_pos:Vector2i = Vector2i.MIN, job_data:String = "_", job_data2:int = -1):
	type = job_type
	pos = job_pos
	data = job_data
	data2 = job_data2
	_uuid = UUID.uuidbin()
	_validate()

func _to_string():
	var job_string: String = ""
	match type:
		TYPE.GOTO:
			job_string = "Job(GOTO, %s)" % [pos]
		TYPE.BREAK:
			job_string = "Job(BREAK, %s, tool=%s)" % [pos, data]
		TYPE.PLACE:
			job_string = "Job(PLACE, %s, tile=%s)" % [pos, data]
		TYPE.CRAFT:
			job_string = "Job(CRAFT, %s, recipe=%s, quantity=%d)" % [pos, data, data2]
		_:
			job_string = "Job(NONE, %s)" % [pos]
	
	return "%s {_uuid=%s}" % [job_string, _uuid]

func _validate() -> void:
	if type != TYPE.NONE && pos == Vector2i.MIN:
		assert(pos != null, "[Job] Job lacks position")
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
			assert(data != "_", "[Job] PLACE job missing param: data")
			assert(DataTile.exists(data), "[Job] PLACE job has invalid data: \"" + data + "\" is not a tile")
		TYPE.CRAFT:
			# TODO: validate crafting
			assert(data != "_", "[Job] CRAFT job missing param: data")
			assert(data2 != -1, "[Job] CRAFT job missing param: data2")
		_:
			assert(TYPE.has(type), "[Job] Invalid job type")
	
	return

func get_uuid() -> PackedByteArray:
	return _uuid

func uuid_matches(other_uuid: PackedByteArray) -> bool:
	return _uuid == other_uuid
