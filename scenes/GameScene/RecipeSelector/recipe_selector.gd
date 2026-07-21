extends Control

@export var recipe_page: Control
@export var recipe_list: ItemList
@export var main_theme: Theme

var interacter: Camera2D
var workstation: String
var recipe_id_list: PackedStringArray
var selected_character: Character

func setup(workstation: String, interacter: Camera2D) -> void:
	print("[RecipeSelector] Setting up selector for workstation " + workstation)
	self.workstation = workstation
	self.interacter = interacter

	var recipe_ids: PackedStringArray = DataRecipe.find_workstation_recipe_ids(workstation)
	# let _add_recipe() handle populating recipe_id_list to ensure the indexing matches recipe_list items
	recipe_id_list.resize(recipe_ids.size())

	print("[RecipeSelector] Recipe list: " + str(recipe_ids))
	_populate_recipe_tab_container(recipe_ids)
	
	# connect to selected_character_changed signal
	selected_character = Interactor.selected_character
	selected_character.inventory_changed.connect(_on_character_inventory_changed)

	if recipe_id_list.size() >= 0:
		recipe_list.select(0)
		_on_recipe_list_item_selected(0)
	
	_enable_recipes_by_character_inventory()
	
	

func _populate_recipe_tab_container(recipe_ids: PackedStringArray) -> void:
	for recipe_id in recipe_ids:
		var recipe: DataRecipe = DataRecipe.find(recipe_id)
		_add_recipe(recipe)

func _add_recipe(recipe: DataRecipe) -> void:
	var list_index: int = recipe_list.add_item(recipe.name)
	recipe_id_list.set(list_index, recipe.id)
	print("[RecipeSelector] Added recipe " + str(list_index) + ": " + recipe.id)

func _set_active_recipe(recipe_id: String) -> void:
	recipe_page.set_recipe(recipe_id)

func _on_recipe_list_item_selected(index: int) -> void:
	print("[RecipeSelector] Item clicked: " + str(index))
	_set_active_recipe(recipe_id_list.get(index))


func _set_recipe_enabled(index: int, is_enabled: bool) -> void:
	if is_enabled:
		print("[RecipeSelector] Enabling recipe (does nothing for now) ", recipe_id_list.get(index))
	else:
		print("[RecipeSelector] Disabling recipe (does nothing for now) ", recipe_id_list.get(index))

func _enable_recipes_by_character_inventory() -> void:
	print("[RecipeSelector] Filtering recipes by inventory...")
	for index: int in recipe_id_list.size(): # check each recipe in the recipe list
		var recipe_id: String = recipe_id_list.get(index)
		var recipe: DataRecipe = DataRecipe.find(recipe_id)
		var has_all_ingredients: bool = true

		for ingredient: ItemStack in recipe.ingredients: # for each item in ingredients, disable this recipe if any ingredient is missing
			if not selected_character.inventory.has(ingredient.item_name, ingredient.count):
				print("[RecipeSelector] recipe ", recipe_id, " is missing ingredient ", ingredient)
				has_all_ingredients = false
		
		_set_recipe_enabled(index, has_all_ingredients)


func _on_character_inventory_changed() -> void:
	print("[RecipeSelector] Inventory changed, updating enabled recipes")
	_enable_recipes_by_character_inventory()
