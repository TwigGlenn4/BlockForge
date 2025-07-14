extends DataItem
class_name DataItemArmor


enum ARMOR_TYPE {
	HELMET = 0,
	CHESTPLATE = 1,
	LEGGINGS = 2,
	BOOTS = 3
}


# inherited variables from DataItem
# var name: String
# var texture: DataTexture
# var stack_max: int
# var item_type: ITEM_TYPES

var type: ARMOR_TYPE
var protection: float    # damage_taken = damage - damage * (protection/100). Reduces incoming damage by protection percent. damage=10 and protection=80 -> damage_taken=2
var durability_max: int  # number of hits before breaking


func _init(item_name:String, armor_type:ARMOR_TYPE, armor_protection:int, armor_durability_max: int, item_texture:DataTexture = DataTexture.UNDEFINED, item_stack_max:int = 99):
	super(item_name, item_texture, item_stack_max)
	item_type = ITEM_TYPES.ARMOR

	type = armor_type
	protection = armor_protection
	durability_max = armor_durability_max

