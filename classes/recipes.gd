class_name Recipes

static var PORTAL = {
	GRASSIFY_DIRT = DataRecipe.UNDEFINED,
	REMOVE_GRASS = DataRecipe.UNDEFINED
}

static func register_recipes_temp() -> void:
	PORTAL.GRASSIFY_DIRT = DataRecipe.new("portal_grassify_dirt", "blockforge:portal_btm", 0.6, ["blockforge:dirt"], ["blockforge:grass"], "Grassify Dirt", "Put grass on a dirt block")
	PORTAL.REMOVE_GRASS = DataRecipe.new("portal_remove_grass", "blockforge:portal_btm", 0.6, ["blockforge:grass"], ["blockforge:dirt"], "Remove Grass", "Scrape the grass off this dirt")
