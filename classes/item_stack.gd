class_name ItemStack

var item_name:String
var count:int
var stack_max: int
var tracked: bool # determines if item_list should be used. 
var item_list: Array[DataItem] = [] # Needed for TOOL, ARMOR, and CONTAINER items to retain individual data.


func _init( item_name_string:String ):
	item_name = item_name_string
	count = 0

	var data_item = DataItem.item(item_name)
	stack_max = data_item.stack_max

	if data_item.tracked():
		tracked = true
		item_list.resize(data_item.stack_max)
	else:
		tracked = false


func add_items( num:int ) -> int: # adds items and returns remainder to add if stack is full.
	if tracked:
		print("[ItemStack.add_items(%d)]: %s is tracked. Use ItemStack.add_tracked_item( item_name:DataItem )" % [num, item_name])
		return 0

	if num < 0:
		print("[ItemStack.add_items(%d)]: Can't add negative items. Use ItemStack.remove_items( num:int )" % [num])
		return 0
	
	if count + num <= stack_max: # there is enough space left in the stack to add num items
		print("[ItemStack.add_items(%d)] adding %d items to stack." % [num, num])
		count += num
		return 0
	
	# there is not enough space to add num items
	# add as many as we can and return number of remaining items
	var remainder = count + num - stack_max
	count = stack_max
	print("[ItemStack.add_items(%d)] adding %d items to stack with %d leftover" % [num, num, remainder])
	return remainder


func remove_items( num:int ) -> bool: # removes items and returns remainder to remove if stack is empty
	if tracked:
		print("[ItemStack.remove_items(%d)]: %s is tracked. Use ItemStack.remove_tracked_item( item_name:DataItem )" % [num, item_name])
		return 0

	if num < 0:
		print("[ItemStack.remove_items(%d)]: Can't remove negative items. Use ItemStack.add_items( num:int )" % [num])
		return 0
	
	if count <= num: # not enough items
		var remainder = num - count
		count = 0
		return remainder
	
	# count > num
	count -= num
	return 0

func _to_string() -> String:
	return str(item_name, " ", count)
