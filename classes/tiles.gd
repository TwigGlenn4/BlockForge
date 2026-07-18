class_name Tiles

# const UNDEFINED = {atlas=5, sprite=Vector2i(0,0), id="undefined"}
# static var UNDEFINED = DataTile.new("undefined", DataTexture.new("undefined"))
# const AIR = {atlas=-1, sprite=Vector2i(0,0), id="blockforge:air"}
static var AIR = DataTile.new("air", DataTexture.new("air", -1, Vector2i(0,0)))


static var TERRAIN_ATLAS = 1
static var TERRAIN = {
	_ATLAS = TERRAIN_ATLAS,
	# DIRT = {atlas=5, sprite=Vector2i(1,0), id="blockforge:dirt"},
	DIRT = DataTile.new("blockforge:dirt", DataTexture.new("blockforge:dirt", TERRAIN_ATLAS, Vector2i(1,0))),
	# STONE = {atlas=5, sprite=Vector2i(2,0), id="blockforge:stone"},
	STONE = DataTile.new("blockforge:stone", DataTexture.new("blockforge:stone", TERRAIN_ATLAS, Vector2i(2,0))),
	# COBBLESTONE = {atlas=5, sprite=Vector2i(3,0), id="blockforge:cobblestone"},
	COBBLESTONE = DataTile.new("blockforge:cobblestone", DataTexture.new("blockforge:cobblestone", TERRAIN_ATLAS, Vector2i(3,0))),
	# WATER = {atlas=5, sprite=Vector2i(4,0), id="blockforge:water"},
	WATER = DataTile.new("blockforge:water", DataTexture.new("blockforge:water", TERRAIN_ATLAS, Vector2i(4,0))),
	# SAND = {atlas=5, sprite=Vector2i(5,0), id="blockforge:sand"},
	SAND = DataTile.new("blockforge:sand", DataTexture.new("blockforge:sand", TERRAIN_ATLAS, Vector2i(5,0))),
	# SNOW = {atlas=5, sprite=Vector2i(6,0), id="blockforge:snow"},
	SNOW = DataTile.new("blockforge:snow", DataTexture.new("blockforge:snow", TERRAIN_ATLAS, Vector2i(6,0)), "blockforge:grass"),
	# GRASS = {atlas=5, sprite=Vector2i(7,0), id="blockforge:grass"},
	GRASS = DataTile.new("blockforge:grass", DataTexture.new("blockforge:grass", TERRAIN_ATLAS, Vector2i(7,0))),
	# LOG = {atlas=5, sprite=Vector2i(8,0), id="blockforge:log"},
	LOG = DataTile.new("blockforge:log", DataTexture.new("blockforge:log", TERRAIN_ATLAS, Vector2i(8,0))),
	# LEAVES = {atlas=5, sprite=Vector2i(9,0), id="blockforge:leaves"},
	LEAVES = DataTile.new("blockforge:leaves", DataTexture.new("blockforge:leaves", TERRAIN_ATLAS, Vector2i(9,0))),
	ORE_TIN = DataTile.new("blockforge:ore_tin", DataTexture.new("blockforge:ore_tin", TERRAIN_ATLAS, Vector2i(10,0))),
	LIMESTONE = DataTile.new("blockforge:limestone", DataTexture.new("blockforge:limestone", TERRAIN_ATLAS, Vector2i(11,0))),
}

static var PORTAL_ATLAS = 2
static var PORTAL = {
	_ATLAS = PORTAL_ATLAS,
	# BASE_STONE = {atlas=0, sprite=Vector2i(0,0), id="blockforge:portal_base_stone"},
	BASE_STONE = DataTile.new("blockforge:portal_base_stone", DataTexture.new("blockforge:portal_base_stone", PORTAL_ATLAS, Vector2i(0,0))),
	# BASE_COBBLE = {atlas=0, sprite=Vector2i(0,1), id="blockforge:portal_base_cobble"},
	BASE_COBBLE = DataTile.new("blockforge:portal_base_cobble", DataTexture.new("blockforge:portal_base_cobble", PORTAL_ATLAS, Vector2i(0,1))),
	# F1_TOP = {atlas=0, sprite=Vector2i(1,0), id="blockforge:portal_top"},
	F1_TOP = DataTile.new("blockforge:portal_top", DataTexture.new("blockforge:portal_top", PORTAL_ATLAS, Vector2i(1,0))),
	# F1_BTM = {atlas=0, sprite=Vector2i(1,1), id="blockforge:portal_btm"}
	F1_BTM = DataTile.new("blockforge:portal_btm", DataTexture.new("blockforge:portal_btm", PORTAL_ATLAS, Vector2i(1,1)))
}

static var GROWABLE = [
	TERRAIN.DIRT,
	TERRAIN.GRASS,
	TERRAIN.SNOW,
]
