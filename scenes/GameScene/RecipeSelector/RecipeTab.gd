extends Control

@export var title: Label
@export var result: Label
@export var ingredients: RichTextLabel

func setup(recipe: DataRecipe) -> void:
	title.text = recipe.name
	var result_text = ""
	for result in recipe.results:
		result_text += result
	# result.text = result_text[:-1]