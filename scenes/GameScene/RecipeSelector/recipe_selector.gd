extends Control

@export var RECIPE_TAB_SCENE: Resource = preload("res://scenes/GameScene/RecipeSelector/RecipeTab.tscn")
@export var recipe_tab_container: TabContainer

var interacter: Camera2D
var workstation: String
var recipe_id_list: PackedStringArray

func setup(workstation: String, interacter: Camera2D) -> void:
	print("[RecipeSelector] Setting up selector for workstation " + workstation)
	self.workstation = workstation
	self.interacter = interacter
	self.recipe_id_list = DataRecipe.find_workstation_recipe_ids(workstation)

	print("[RecipeSelector] Recipe list: " + str(recipe_id_list))
	_populate_recipe_tab_container()


func _populate_recipe_tab_container() -> void:
	for recipe_id in recipe_id_list:
		recipe_tab_container.add_child(_build_recipe_tab(recipe_id))

func _build_recipe_tab(recipe_id: String) -> Control:
	var tab: Control = RECIPE_TAB_SCENE.instantiate()
	tab.setup(recipe_id)
	return tab
