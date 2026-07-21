extends Control

signal start_craft(recipe_id: String)

@export var title: Label
@export var description: Label
@export var result: Label
@export var ingredients: RichTextLabel
@export var craft_button: Button

var recipe

func set_recipe(recipe_id: String) -> void:
	recipe = DataRecipe.find(recipe_id)
	name += "_" + recipe.id
	print("[RecipePage] Setting up page for recipe " + recipe.id)

	title.text = recipe.name
	description.text = recipe.description

	var result_text: String = "Result: "
	for result: ItemStack in recipe.results:
		result_text += str(result.count) + " " + result.item_name + ", "
	result.text = result_text.substr(0, result_text.length()-2)

	_update_contents_inv_quantity()
	Interactor.selected_character.inventory_changed.connect(_update_contents_inv_quantity)


func _on_craft_button_pressed() -> void:
	print("[RecipePage] Craft button pressed for recipe " + recipe.id)
	start_craft.emit(recipe.id)


func _update_contents_inv_quantity():
	var ingredient_text: String = ""

	var all_ingredients_available: bool = true
	for ingredient: ItemStack in recipe.ingredients:
		var num_in_inventory: int = Interactor.selected_character.inventory.count_items(ingredient.item_name)
		ingredient_text += str(ingredient.count) + " " + ingredient.item_name + " ("+str(num_in_inventory)+")\n"
		if num_in_inventory < ingredient.count:
			all_ingredients_available = false
	ingredients.text = ingredient_text.substr(0, ingredient_text.length()-1)

	craft_button.text = "Craft ("+String.num(recipe.duration, 2)+"s)"
	craft_button.disabled = !all_ingredients_available
	if !all_ingredients_available:
		print("[RecipePage] Disabled craft button for recipe " + recipe.id)
