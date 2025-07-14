extends DataItem
class_name DataItemTool


enum TOOL_TYPES {
	NONE = 0,
	SWORD = 1,
	PICKAXE = 2,
	AXE = 3,
	SHOVEL = 4,
	BOW = 5
}


# inherited variables from DataItem
# var name: String
# var texture: DataTexture
# var stack_max: int
# var item_type: ITEM_TYPES

var type: TOOL_TYPES
var speed: float         # seconds_to_break = block.hardness / speed
var durability_max: int  # number of uses before tool breaks
var attack_damage: int   # how much HP is removed from entities when attacked


func _init(item_name:String, tool_type:TOOL_TYPES, tool_speed:int, tool_durability_max: int, tool_attack_damage: int = 1, item_texture:DataTexture = DataTexture.UNDEFINED, item_stack_max:int = 99):
	super(item_name, item_texture, item_stack_max)
	item_type = ITEM_TYPES.TOOL

	type = tool_type
	speed = tool_speed
	durability_max = tool_durability_max
	attack_damage = tool_attack_damage

