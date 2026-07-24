extends Control

@export var recipe_page: Control
@export var recipe_list: ItemList
@export var close_button: Button

@export var main_theme: Theme
@export var CRAFTING_PROGRESS_SCENE: Resource

var workstation: String
var workstation_pos: Vector2i
var recipe_id_list: PackedStringArray

func setup(workstation: String, workstation_pos: Vector2i) -> void:
	print("[RecipeSelector] Setting up selector for workstation " + workstation)
	self.workstation = workstation
	self.workstation_pos = workstation_pos

	var recipe_ids: PackedStringArray = DataRecipe.find_workstation_recipe_ids(workstation)
	# let _add_recipe() handle populating recipe_id_list to ensure the indexing matches recipe_list items
	recipe_id_list.resize(recipe_ids.size())

	# print("[RecipeSelector] Recipe list: " + str(recipe_ids))
	_populate_recipe_tab_container(recipe_ids)
	
	# connect to selected_character_changed signal
	# Interactor.selected_character_inventory_changed.connect(_on_character_inventory_changed) # disabled while _enable_recipes_by_character_inventory() does nothing
	# _enable_recipes_by_character_inventory()

	if recipe_id_list.size() >= 0:
		recipe_list.select(0)
		_on_recipe_list_item_selected(0)
	

	recipe_page.start_craft.connect(_on_start_craft)
	
	

func _populate_recipe_tab_container(recipe_ids: PackedStringArray) -> void:
	for recipe_id in recipe_ids:
		var recipe: DataRecipe = DataRecipe.find(recipe_id)
		_add_recipe(recipe)

func _add_recipe(recipe: DataRecipe) -> void:
	var list_index: int = recipe_list.add_item(recipe.name)
	recipe_id_list.set(list_index, recipe.id)
	# print("[RecipeSelector] Added recipe " + str(list_index) + ": " + recipe.id)

func _set_active_recipe(recipe_id: String) -> void:
	recipe_page.set_recipe(recipe_id)

func _on_recipe_list_item_selected(index: int) -> void:
	# print("[RecipeSelector] Item clicked: " + str(index))
	_set_active_recipe(recipe_id_list.get(index))

func _on_close_button_pressed() -> void:
	queue_free()

func _set_recipe_enabled(index: int, is_enabled: bool) -> void:
	if is_enabled:
		print("[RecipeSelector] Enabling recipe (does nothing for now) ", recipe_id_list.get(index))
	else:
		print("[RecipeSelector] Disabling recipe (does nothing for now) ", recipe_id_list.get(index))

## Unused for now, eventually may want to gray out recipes in recipe_list here
func _enable_recipes_by_character_inventory() -> void:
	print("[RecipeSelector] Filtering recipes by inventory...")
	for index: int in recipe_id_list.size(): # check each recipe in the recipe list	
		var recipe_id: String = recipe_id_list.get(index)
		_set_recipe_enabled(index, Interactor.selected_character.inventory.has_recipe_ingredients(recipe_id))


func _on_character_inventory_changed() -> void:
	print("[RecipeSelector] Inventory changed, updating enabled recipes")
	# _enable_recipes_by_character_inventory()

func _on_start_craft(recipe_id: String, quantity: int) -> void:
	self.visible = false
	Interactor.selected_character.add_job(Job.new(Job.TYPE.CRAFT, workstation_pos, recipe_id, quantity))
	self.queue_free()
