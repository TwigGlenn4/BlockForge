extends Control

signal start_craft(recipe_id: String, quantity: int)

@export var title: Label
@export var description: Label
@export var result: Label
@export var ingredients: RichTextLabel
@export var quantity_container: HBoxContainer
@export var quantity_label: Label
@export var quantity_slider: HSlider
@export var quantity_max_label: Label
@export var craft_button: Button

var recipe: DataRecipe
var quantity: int

func _ready() -> void:
	Interactor.selected_character_inventory_changed.connect(_update_contents_inv_quantity)
	quantity_slider.value_changed.connect(_on_quantity_changed)


func set_recipe(recipe_id: String) -> void:
	recipe = DataRecipe.find(recipe_id)
	name += "_" + recipe.id
	# print("[RecipePage] Setting up page for recipe " + recipe.id)

	title.text = recipe.name
	description.text = recipe.description

	quantity = 1

	_update_contents_inv_quantity()
	_update_craft_button()


func _on_craft_button_pressed() -> void:
	# print("[RecipePage] Craft button pressed for %d x %s" % [quantity, recipe.id])
	start_craft.emit(recipe.id, quantity)

func _on_quantity_changed(value: float) -> void:
	quantity = int(value)
	_update_craft_button()



func _update_contents_inv_quantity():
	var ingredient_text: String = ""

	var result_text: String = "Result: "
	for result: ItemStack in recipe.results:
		var num_in_inventory: int = Interactor.selected_character.inventory.count_items(result.item_name)
		result_text += str(result.count) + " " + result.item_name +  " ("+str(num_in_inventory)+"), "
	result.text = result_text.substr(0, result_text.length()-2)

	var max_recipe_quantity: int = 99 # calcs how many recipes can be made using inventory ingredients. Set to max in one craft job.

	for ingredient: ItemStack in recipe.ingredients:
		var num_in_inventory: int = Interactor.selected_character.inventory.count_items(ingredient.item_name)
		ingredient_text += str(ingredient.count) + " " + ingredient.item_name + " ("+str(num_in_inventory)+")\n"

		var max_recipes_this_ingredient: int = num_in_inventory / ingredient.count
		max_recipe_quantity = mini(max_recipe_quantity, max_recipes_this_ingredient)

	ingredients.text = ingredient_text.substr(0, ingredient_text.length()-1)

	var can_craft_recipe = max_recipe_quantity > 0
	craft_button.disabled = !can_craft_recipe

	quantity_container.visible = max_recipe_quantity > 1
	if quantity_container.visible:
		quantity_max_label.text = str(max_recipe_quantity)
		quantity_slider.max_value = max_recipe_quantity
	
	if !can_craft_recipe:
		print("[RecipePage] Disabled craft button for recipe " + recipe.id)


func _update_craft_button() -> void:
	if quantity <= 1:
		craft_button.text = "Craft (%ss)" % [String.num(recipe.duration, 2)]
	else:
		craft_button.text = "Craft %d (%ss)" % [quantity,  String.num(quantity * recipe.duration, 2)]
