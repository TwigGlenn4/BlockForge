class_name Tiles

# const UNDEFINED = {atlas=5, sprite=Vector2i(0,0), id="undefined"}
# static var UNDEFINED = DataTile.new("undefined", DataTexture.new("undefined"))
# const AIR = {atlas=-1, sprite=Vector2i(0,0), id="blockforge:air"}
static var AIR = DataTile.new("air", DataTexture.new("air", -1, Vector2i(0,0)))


static var TERRAIN_ATLAS = 1
static var UNDERGROUND_ATLAS = 3

static var TERRAIN = {
	_ATLAS = TERRAIN_ATLAS,
	DIRT = DataTile.new("blockforge:dirt", DataTexture.new("blockforge:dirt", TERRAIN_ATLAS, Vector2i(1,0))),
	STONE = DataTile.new("blockforge:stone", DataTexture.new("blockforge:stone", TERRAIN_ATLAS, Vector2i(2,0))),
	COBBLESTONE = DataTile.new("blockforge:cobblestone", DataTexture.new("blockforge:cobblestone", TERRAIN_ATLAS, Vector2i(3,0))),
	WATER = DataTile.new("blockforge:water", DataTexture.new("blockforge:water", TERRAIN_ATLAS, Vector2i(4,0))),
	SAND = DataTile.new("blockforge:sand", DataTexture.new("blockforge:sand", TERRAIN_ATLAS, Vector2i(5,0))),
	SNOW = DataTile.new("blockforge:snow", DataTexture.new("blockforge:snow", TERRAIN_ATLAS, Vector2i(6,0)), "blockforge:grass"),
	GRASS = DataTile.new("blockforge:grass", DataTexture.new("blockforge:grass", TERRAIN_ATLAS, Vector2i(7,0))),
	LOG = DataTile.new("blockforge:log", DataTexture.new("blockforge:log", TERRAIN_ATLAS, Vector2i(8,0))),
	LEAVES = DataTile.new("blockforge:leaves", DataTexture.new("blockforge:leaves", TERRAIN_ATLAS, Vector2i(9,0))),
	LAVA = DataTile.new("blockforge:lava", DataTexture.new("blockforge:lava", TERRAIN_ATLAS, Vector2i(10,0))),
}

# Underground atlas (assets/textures/atlas/underground.png)
static var UNDERGROUND = {
	_ATLAS = UNDERGROUND_ATLAS,
	LIMESTONE = DataTile.new("blockforge:limestone", DataTexture.new("blockforge:limestone", UNDERGROUND_ATLAS, Vector2i(0,0))),
	MARBLE = DataTile.new("blockforge:marble", DataTexture.new("blockforge:marble", UNDERGROUND_ATLAS, Vector2i(1,0))),
	ORE_COAL = DataTile.new("blockforge:ore_coal", DataTexture.new("blockforge:ore_coal", UNDERGROUND_ATLAS, Vector2i(2,0))),
	ORE_TIN = DataTile.new("blockforge:ore_tin", DataTexture.new("blockforge:ore_tin", UNDERGROUND_ATLAS, Vector2i(3,0))),
	ORE_COPPER = DataTile.new("blockforge:ore_copper", DataTexture.new("blockforge:ore_copper", UNDERGROUND_ATLAS, Vector2i(4,0))),
	ORE_IRON = DataTile.new("blockforge:ore_iron", DataTexture.new("blockforge:ore_iron", UNDERGROUND_ATLAS, Vector2i(5,0))),
	ORE_GOLD = DataTile.new("blockforge:ore_gold", DataTexture.new("blockforge:ore_gold", UNDERGROUND_ATLAS, Vector2i(6,0))),
	ORE_TITANIUM = DataTile.new("blockforge:ore_titanium", DataTexture.new("blockforge:ore_titanium", UNDERGROUND_ATLAS, Vector2i(7,0))),
	ORE_PLATINUM = DataTile.new("blockforge:ore_platinum", DataTexture.new("blockforge:ore_platinum", UNDERGROUND_ATLAS, Vector2i(8,0))),
	BLACK_SAND = DataTile.new("blockforge:black_sand", DataTexture.new("blockforge:black_sand", UNDERGROUND_ATLAS, Vector2i(9,0))),
	FLINT = DataTile.new("blockforge:flint", DataTexture.new("blockforge:flint", UNDERGROUND_ATLAS, Vector2i(10,0))),
	CLAY = DataTile.new("blockforge:clay", DataTexture.new("blockforge:clay", UNDERGROUND_ATLAS, Vector2i(11,0))),
	OIL = DataTile.new("blockforge:oil", DataTexture.new("blockforge:oil", UNDERGROUND_ATLAS, Vector2i(12,0))),
	SANDSTONE = DataTile.new("blockforge:sandstone", DataTexture.new("blockforge:sandstone", UNDERGROUND_ATLAS, Vector2i(13,0))),
	RED_MARBLE = DataTile.new("blockforge:red_marble", DataTexture.new("blockforge:red_marble", UNDERGROUND_ATLAS, Vector2i(14,0))),
	LAPIS_LAZULI = DataTile.new("blockforge:lapis_lazuli", DataTexture.new("blockforge:lapis_lazuli", UNDERGROUND_ATLAS, Vector2i(15,0))),
}

static var PORTAL_ATLAS = 2
static var PORTAL = {
	_ATLAS = PORTAL_ATLAS,
	BASE_STONE = DataTile.new("blockforge:portal_base_stone", DataTexture.new("blockforge:portal_base_stone", PORTAL_ATLAS, Vector2i(0,0))),
	BASE_COBBLE = DataTile.new("blockforge:portal_base_cobble", DataTexture.new("blockforge:portal_base_cobble", PORTAL_ATLAS, Vector2i(0,1))),
	F1_TOP = DataTile.new("blockforge:portal_top", DataTexture.new("blockforge:portal_top", PORTAL_ATLAS, Vector2i(1,0))),
	F1_BTM = DataTile.new("blockforge:portal_btm", DataTexture.new("blockforge:portal_btm", PORTAL_ATLAS, Vector2i(1,1)), "self", DataTile.INTERACTION.CRAFT)
}

static var GROWABLE = [
	TERRAIN.DIRT,
	TERRAIN.GRASS,
	TERRAIN.SNOW,
]
