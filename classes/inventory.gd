class_name Inventory

var contents: Array[ItemStack]
var _contents_changed: bool


func _init(num_slots:int = 25) -> void:
	contents.resize(num_slots)
	_contents_changed = false


func has(item_name:String, count:int = 1) -> int:
	var num_found = 0
	for stack:ItemStack in contents: # for every stack in contents
		if stack && stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack
			num_found += stack.count
			if num_found >= count:       # if enough items have been found, return num found
				return num_found
	
	return 0 # if there are not enough items that match in the inventory, return 0


# currently assuming items will be referred to with strings, likely to change.
func add_items( item_name:String, count:int = 1) -> int: 
	_contents_changed = true
	print("[Inventory.add_items(%s, %d)]" % [item_name, count])
	for stack:ItemStack in contents: # for every stack in contents
		if stack != null and stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack

			count = stack.add_items(count)

			if count <= 0: # count should only ever be == 0. <= is safety
				return 0
	
	for i:int in contents.size():
		
		if contents[i] == null:
			var stack: ItemStack = ItemStack.new(item_name)
			count = stack.add_items(count)
			print("[Inventory.add_items()] created stack of ", stack)
			contents[i] = stack

			if count <= 0: # count should only ever be == 0. <= is safety
				return 0
				
	print("[Inventory.add_items()] ", count, " items left to drop")
	return count # return count if there are items that could not fit into the inventory.


func remove_items( item_name:String, count:int = 1) -> int: 
	_contents_changed = true
	for i in contents.size(): # for every stack in contents
		var stack: ItemStack = contents[i]
		if stack && stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack

			count = stack.remove_items(count)
			if stack.count <= 0: # this stack has been emptied, remove it
				contents[i] = null # remove this stack of 0 items
			
			if count <= 0: # enough items have been removed, can safely return
				return 0

	return count # return count if there are items that could not fit into the inventory.


func count_items( item_name:String ) -> int:
	var count = 0;
	for stack:ItemStack in contents:
		if stack.item_name == item_name:
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
func contents_changed_check() -> bool:
	if _contents_changed:
		_contents_changed = false
		return true
	
	return false
