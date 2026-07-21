class_name DataRecipe

## List of all _registered recipes keyed by id
static var _registered: Dictionary[String, DataRecipe] = {}
## Arrays of every recipe made by a workstation, indexed by workstation.
static var workstation_recipe_ids: Dictionary[String, Array] = {}

static var UNDEFINED = DataRecipe.new("undefined", "", 0)

# Required members
var id: String
var workstation: String
var duration: float
var ingredients: Array[String]
var results: Array[String]

# Optional members
var name: String
var description: String

## DataRecipe Constructor
func _init(id: String, workstation: String, duration: float = 1.0, ingredients: Array[String] = [""], results: Array[String] = [""], name: String = "", description: String = ""):

	assert(!has(id), "[DataRecipe (id:\""+id+"\")] Recipe id already in use: \""+id+"\"")
	self.id = id

	assert(DataTile.has(workstation), "[DataRecipe (id:\""+id+"\")] Workstation does not exist: \""+workstation+"\"")
	self.workstation = workstation

	assert(duration >= 0.0, "[DataRecipe (id:\""+id+"\")] Duration must not be negative: \""+str(duration)+"\"")
	self.duration = duration

	assert(_validate_itemstack_list(ingredients), "[DataRecipe (id:\""+id+"\")] Invalid ingredient")
	self.ingredients = ingredients

	assert(_validate_itemstack_list(results), "[DataRecipe (id:\""+id+"\")] Invalid result")
	self.results = results

	self.name = name
	self.description = description

	workstation_recipe_ids[workstation].append(self)

	_registered[id] = self




static func has(recipe_id:String) -> bool:
	return _registered.has(recipe_id)

static func find(recipe_id:String) -> DataTile:
	return _registered.get(recipe_id, UNDEFINED)

func _to_string() -> String:
	return "DataRecipe("+id+")"


func _validate_itemstack_list(itemstack_list: Array[String]) -> bool:
	if !itemstack_list or itemstack_list.size() == 0 or itemstack_list[0] == "":
		return true # empty or null list

	for i in itemstack_list.size():
		var parse_result: Dictionary = ItemStack.parse(itemstack_list[i])
		var item_string: String = parse_result["item"]

		if !DataItem.exists(item_string): # check that item is valid and exists
			print("[DataRecipe (id:\"",id,"\")] Item does not exist: \"",itemstack_list[i],"\"")
			return false

		var item_stack_max: int = DataItem.item(item_string).stack_max
		if parse_result["count"] <= 0 or parse_result["count"] >= item_stack_max: # check that count is valid
			print("[DataRecipe (id:\"",id,"\")] Count must be between 0 and stack_max(",item_stack_max,")")
			return false
	return true # all item stacks passed checks


		
		