class_name DataRecipe

## List of all _registered recipes keyed by id
static var _registered: Dictionary[String, DataRecipe] = {}
## Arrays of every recipe made by a workstation, indexed by workstation.
static var workstation_recipe_ids: Dictionary[String, PackedStringArray] = {}

static var UNDEFINED = DataRecipe.new("undefined", "", 0)

# Required members
var id: String
var workstation: String
var duration: float
var ingredients: Array[ItemStack]
var results: Array[ItemStack]

# Informational members
var name: String
var description: String

## DataRecipe Constructor
func _init(id: String, workstation: String, duration: float = 1.0, ingredients: Array[String] = [""], results: Array[String] = [""], name: String = "", description: String = ""):

	assert(!has(id), "[DataRecipe (id:\""+id+"\")] Recipe id already in use: \""+id+"\"")
	self.id = id

	assert(DataTile.tile(workstation), "[DataRecipe (id:\""+id+"\")] Workstation does not exist: \""+workstation+"\"")
	self.workstation = workstation

	assert(duration >= 0.0, "[DataRecipe (id:\""+id+"\")] Duration must not be negative: \""+str(duration)+"\"")
	self.duration = duration

	self.ingredients = _validate_itemstack_list(ingredients)
	if self.ingredients.size() <= 0:
		print("WARN: [DataRecipe (id:\""+id+"\")] Invalid or missing ingredient")

	self.results = _validate_itemstack_list(results)
	if self.results.size() <= 0:
		print("WARN: [DataRecipe (id:\""+id+"\")] Invalid or missing result")

	self.name = name
	self.description = description

	if workstation_recipe_ids.has(workstation):
		workstation_recipe_ids[workstation].append(id)
	else:
		workstation_recipe_ids[workstation] = [id]

	print("[DataRecipe (id:\""+id+"\")] workstation_recipe_ids: " + str(workstation_recipe_ids))

	_registered[id] = self




static func has(recipe_id:String) -> bool:
	return _registered.has(recipe_id)

static func find(recipe_id:String) -> DataRecipe:
	return _registered.get(recipe_id, UNDEFINED)

static func find_workstation_recipe_ids(workstation: String) -> PackedStringArray:
	if workstation_recipe_ids.has(workstation):
		return workstation_recipe_ids[workstation] 
	else:
		return []



func _to_string() -> String:
	return "DataRecipe("+id+")"


func _validate_itemstack_list(itemstring_list: Array[String]) -> Array[ItemStack]:
	var itemstack_list: Array[ItemStack] = []

	if !itemstring_list or itemstring_list.size() == 0 or itemstring_list[0] == "":
		return [] # empty or null list

	for stack_string in itemstring_list:
		var parsed_stack: ItemStack = ItemStack.parse(stack_string)
		var item_string: String = parsed_stack.item_name

		if !DataItem.exists(item_string): # check that item is valid and exists
			print("WARN: [DataRecipe (id:\"",id,"\")] Item does not exist: \"",stack_string,"\"")
			return []

		var item_stack_max: int = parsed_stack.stack_max
		if parsed_stack.count <= 0 or parsed_stack.count >= item_stack_max: # check that count is valid
			print("WARN: [DataRecipe (id:\"",id,"\")] Count (",parsed_stack.count,") must be between 0 and stack_max(",item_stack_max,")")
			return []
		itemstack_list.append(parsed_stack) # this item passed all checks
	# print("[DataRecipe (id:\"",id,"\")] itemstack_list is ", itemstack_list)
	return itemstack_list # all item stacks passed checks
