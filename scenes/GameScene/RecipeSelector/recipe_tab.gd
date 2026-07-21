extends Control

signal start_craft(recipe_id: String)

@export var title: Label
@export var result: Label
@export var ingredients: RichTextLabel

var recipe

func setup(recipe_id: String) -> void:
	recipe = DataRecipe.find(recipe_id)
	name += "_" + recipe.id

	title.text = recipe.name
	print("[RecipeTab] Setting up tab for recipe " + recipe.id)

	var result_text: String = ""
	for result: ItemStack in recipe.results:
		result_text += str(result.count) + " " + result.item_name + ", "
	result.text = result_text.substr(0, result_text.length()-2)

	var ingredient_text: String = "Time: " + String.num(recipe.duration, 1) + "sec"
	for ingredient: ItemStack in recipe.ingredients:
		ingredient_text += "\n" + str(ingredient.count) + " " + ingredient.item_name 
	ingredients.text = ingredient_text

func _on_craft_button_pressed() -> void:
	print("[RecipeTab] Craft button pressed for recipe " + recipe.id)
	start_craft.emit(recipe.id)
