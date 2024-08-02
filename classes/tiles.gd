class_name Tiles

# const UNDEFINED = {atlas=5, sprite=Vector2i(0,0), id="undefined"}
# static var UNDEFINED = DataTile.new("undefined", DataTexture.new("undefined"))
# const AIR = {atlas=-1, sprite=Vector2i(0,0), id="bh:air"}
static var AIR = DataTile.new("air", DataTexture.new("air", -1, Vector2i(0,0)))


static var TERRAIN = {
	_ATLAS = 5,
	# DIRT = {atlas=5, sprite=Vector2i(1,0), id="bh:dirt"},
	DIRT = DataTile.new("bh:dirt", DataTexture.new("bh:dirt", 5, Vector2i(1,0))),
	# STONE = {atlas=5, sprite=Vector2i(2,0), id="bh:stone"},
	STONE = DataTile.new("bh:stone", DataTexture.new("bh:stone", 5, Vector2i(2,0))),
	# COBBLESTONE = {atlas=5, sprite=Vector2i(3,0), id="bh:cobblestone"},
	COBBLESTONE = DataTile.new("bh:cobblestone", DataTexture.new("bh:cobblestone", 5, Vector2i(3,0))),
	# WATER = {atlas=5, sprite=Vector2i(4,0), id="bh:water"},
	WATER = DataTile.new("bh:water", DataTexture.new("bh:water", 5, Vector2i(4,0))),
	# SAND = {atlas=5, sprite=Vector2i(5,0), id="bh:sand"},
	SAND = DataTile.new("bh:sand", DataTexture.new("bh:sand", 5, Vector2i(5,0))),
	# SNOW = {atlas=5, sprite=Vector2i(6,0), id="bh:snow"},
	SNOW = DataTile.new("bh:snow", DataTexture.new("bh:snow", 5, Vector2i(6,0))),
	# GRASS = {atlas=5, sprite=Vector2i(7,0), id="bh:grass"},
	GRASS = DataTile.new("bh:grass", DataTexture.new("bh:grass", 5, Vector2i(7,0))),
	# LOG = {atlas=5, sprite=Vector2i(8,0), id="bh:log"},
	LOG = DataTile.new("bh:log", DataTexture.new("bh:log", 5, Vector2i(8,0))),
	# LEAVES = {atlas=5, sprite=Vector2i(9,0), id="bh:leaves"},
	LEAVES = DataTile.new("bh:leaves", DataTexture.new("bh:leaves", 5, Vector2i(9,0))),
	ORE_TIN = DataTile.new("bh:ore_tin", DataTexture.new("bh:ore_tin", 5, Vector2i(10,0))),
}

static var PORTAL = {
	_ATLAS = 0,
	# BASE_STONE = {atlas=0, sprite=Vector2i(0,0), id="bh:portal_base_stone"},
	BASE_STONE = DataTile.new("bh:portal_base_stone", DataTexture.new("bh:portal_base_stone", 0, Vector2i(0,0))),
	# BASE_COBBLE = {atlas=0, sprite=Vector2i(0,1), id="bh:portal_base_cobble"},
	BASE_COBBLE = DataTile.new("bh:portal_base_cobble", DataTexture.new("bh:portal_base_cobble", 0, Vector2i(0,1))),
	# F1_TOP = {atlas=0, sprite=Vector2i(1,0), id="bh:portal_top"},
	F1_TOP = DataTile.new("bh:portal_top", DataTexture.new("bh:portal_top", 0, Vector2i(1,0))),
	# F1_BTM = {atlas=0, sprite=Vector2i(1,1), id="bh:portal_btm"}
	F1_BTM = DataTile.new("bh:portal_btm", DataTexture.new("bh:portal_btm", 0, Vector2i(1,1)))
}

static var GROWABLE = [
	TERRAIN.DIRT,
	TERRAIN.GRASS,
	TERRAIN.SNOW,
]
