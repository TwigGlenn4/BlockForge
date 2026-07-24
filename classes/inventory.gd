class_name Inventory

var contents: Array[ItemStack]
var _contents_changed: bool


func _init(num_slots:int = 25) -> void:
	contents.resize(num_slots)
	_contents_changed = false

## Check if the inventory contains `count` number of `item_name` items.
func has(item_name:String, count:int = 1) -> bool:
	var num_found = 0
	for stack:ItemStack in contents: # for every stack in contents
		if stack && stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack
			num_found += stack.count
			if num_found >= count:       # if enough items have been found, return num found
				return true
	
	return false # if there are not enough items that match in the inventory, return 0

func has_recipe_ingredients(recipe_id: String, recipe_count: int = 1) -> bool:
	var recipe: DataRecipe = DataRecipe.find(recipe_id)
	var has_all_ingredients: bool = true

	for ingredient: ItemStack in recipe.ingredients: # for each item in ingredients, disable this recipe if any ingredient is missing
		var items_needed: int = ingredient.count * recipe_count
		if not self.has(ingredient.item_name, items_needed):
			print("[Inventory:has_recipe_ingredients] inventory has less than %d of %s for recipe %s" % [items_needed, ingredient.item_name, recipe_id])
			has_all_ingredients = false
	return has_all_ingredients


# currently assuming items will be referred to with strings, likely to change.
## Add a number of (untracked) items to the inventory, stacking into existing stacks where possible.
## Returns the number of leftover items that don't fit into the inventory
func add_items( item_name:String, count:int = 1) -> int: 
	_contents_changed = true
	# print("[Inventory.add_items(%s, %d)]" % [item_name, count])
	# add to existing stacks
	for stack:ItemStack in contents: # for every stack in contents
		if stack != null and stack.item_name == item_name:    # if the item name matches, stack into this stack
			count = stack.add_items(count)

			if count <= 0:
				return 0
	
	# create new stack(s) if needed
	for i:int in contents.size():
		if contents[i] == null:
			var stack: ItemStack = ItemStack.new(item_name)
			count = stack.add_items(count)
			print("[Inventory.add_items()] created stack of ", stack)
			contents[i] = stack

			if count <= 0:
				return 0
				
	print("[Inventory.add_items()] ", count, " items left to drop")
	return count # return count if there are items that could not fit into the inventory.


## Remove items from the inventory if enough items exist. Does not make any changes if there are not enough items to remove.
func remove_items( item_name:String, count:int = 1) -> bool: 
	if has(item_name, count):
		_contents_changed = true
		for i in contents.size(): # for every stack in contents
			var stack: ItemStack = contents[i]
			if stack && stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack

				count = stack.remove_items(count)
				if stack.count <= 0: # this stack has been emptied, remove it
					contents[i] = null # remove this stack of 0 items
				
				if count <= 0: # enough items have been removed, can safely return
					return true

	return false # return count if there are items that could not fit into the inventory.

## Count how many `item_name` items are in the inventory
func count_items( item_name:String ) -> int:
	var count = 0;
	for stack:ItemStack in contents:
		if stack && stack.item_name == item_name:
			count += stack.count

	return count

func _to_string() -> String:
	var num_stacks = 0
	var output_string: String = ""

	for stack in contents:
		if stack != null:
			num_stacks += 1
			output_string += "\n\t" + str(stack)
	
	output_string = "Inventory(" + str(num_stacks) + "/" + str(contents.size()) + " slots): " + output_string

	return output_string


## Check if inventory contents have changed since last check
## ONLY CALL THIS ONCE PER FRAME! This is only safe with one caller, so Character manages this and sends `inventory_changed` signal. [br]
## Use `Interactor.selected_character_inventory_changed` where possible, it handles reconnecting when `Interactor.selected_character` changes.
func contents_changed_check() -> bool:
	if _contents_changed:
		_contents_changed = false
		return true
	
	return false
