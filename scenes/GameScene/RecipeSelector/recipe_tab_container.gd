extends TabContainer

@export var RECIPE_TAB_SCENE: Resource = preload("res://scenes/GameScene/RecipeSelector/RecipeTab.tscn")

var interacter: Camera2D
var workstation: String
var recipe_list: Array[String]

func setup(workstation: String, interacter: Camera2D) -> void:
	self.workstation = workstation
	self.interacter = interacter
	self.recipe_list = DataRecipe.workstation_recipe_ids[workstation]


func build_recipe_tab(recipe: DataRecipe) -> void:
	var tab: Control = RECIPE_TAB_SCENE.instantiate()
	tab.setup(recipe)

