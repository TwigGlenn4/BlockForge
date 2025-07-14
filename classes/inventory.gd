class_name Inventory

var contents: Array[ItemStack]


func _init(num_slots:int):
	contents.resize(num_slots)


func has(item_name:String, count:int = 1):
	var num_found = 0
	for stack:ItemStack in contents: # for every stack in contents
		if stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack
			num_found += stack.count
			if num_found >= count:       # if enough items have been found, return true
				return true
	
	return false # if there are not enough items that match in the inventory, return false


# currently assuming items will be referred to with strings, likely to change.
func add_items( item_name:String, count:int = 1) -> int: 
	for stack:ItemStack in contents: # for every stack in contents
		if stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack

			count = stack.add_items(count)

			if count <= 0: # count should only ever be == 0. <= is safety
				return 0

	return count # return count if there are items that could not fit into the inventory.


func remove_items( item_name:String, count:int = 1) -> int: 
	for stack:ItemStack in contents: # for every stack in contents
		if stack.item_name == item_name:    # if the item name matches, increment num_found by the number of items in the stack

			count = stack.remove_items(count)

			if count <= 0: # count should only ever be == 0. <= is safety
				return 0

	return count # return count if there are items that could not fit into the inventory.


func count_items( item_name:String ) -> int:
	var count = 0;
	for stack:ItemStack in contents:
		if stack.item_name == item_name:
			count += stack.count

	return count

