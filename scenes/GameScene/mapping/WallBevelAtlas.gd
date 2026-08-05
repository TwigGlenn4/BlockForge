# WallBevelAtlas — runtime 16 edge/bevel variants per wall material (4-bit T/R/B/L).
# Edge darken/brighten from data/lighting.yaml → LightingConfig.bevel_*.
# Applied at TileMap populate (after worldgen cave carve) and refreshed when FG is mined.
# TODO: optional AO / soft gradients; dedicated wall base textures (see WallTiles).
class_name WallBevelAtlas
extends RefCounted

const EDGE_TOP := 1
const EDGE_RIGHT := 2
const EDGE_BOTTOM := 4
const EDGE_LEFT := 8

const SOURCE_ID_BASE := 100

static var _ready: bool = false
static var _bg_tileset: TileSet
static var _wall_source: Dictionary = {} # wall_id -> source_id
static var _next_source: int = SOURCE_ID_BASE


static func background_tileset(base: TileSet) -> TileSet:
	_ensure(base)
	return _bg_tileset


static func _ensure(base: TileSet) -> void:
	if _ready and _bg_tileset != null:
		return
	_bg_tileset = base.duplicate(true)
	_wall_source.clear()
	_next_source = SOURCE_ID_BASE
	_ready = true


static func source_id_for(wall_id: int, base_tileset: TileSet) -> int:
	if wall_id <= 0:
		return -1
	_ensure(base_tileset)
	if _wall_source.has(wall_id):
		return int(_wall_source[wall_id])
	var src_id: int = _create_source_for_wall(wall_id)
	if src_id < 0:
		return -1
	_wall_source[wall_id] = src_id
	return src_id


static func atlas_coords_for_mask(mask: int) -> Vector2i:
	var m: int = mask & 15
	return Vector2i(m % 4, int(m / 4))


## Bit set = side abuts solid FG. Open air sides stay plain.
static func edge_mask_at(gx: int, gy: int, chunk_manager: ChunkManager) -> int:
	if chunk_manager == null:
		return 0
	var mask := 0
	if _is_solid_neighbor(chunk_manager, gx, gy + 1):
		mask |= EDGE_TOP
	if _is_solid_neighbor(chunk_manager, gx + 1, gy):
		mask |= EDGE_RIGHT
	if _is_solid_neighbor(chunk_manager, gx, gy - 1):
		mask |= EDGE_BOTTOM
	if _is_solid_neighbor(chunk_manager, gx - 1, gy):
		mask |= EDGE_LEFT
	return mask


static func _is_solid_neighbor(cm: ChunkManager, gx: int, gy: int) -> bool:
	var tid: int = cm.get_terrain_id(gx, gy)
	if tid < 0:
		return true
	return tid > 0


static func generate_variants(base: Image, tile_size: int = 16) -> Image:
	var ts: int = tile_size
	if base.get_width() != ts or base.get_height() != ts:
		base = base.duplicate()
		base.resize(ts, ts, Image.INTERPOLATE_NEAREST)
	var out := Image.create(ts * 4, ts * 4, false, Image.FORMAT_RGBA8)
	for mask in 16:
		var variant: Image = _apply_edges(base, mask, ts)
		var dx: int = (mask % 4) * ts
		var dy: int = int(mask / 4) * ts
		out.blit_rect(variant, Rect2i(0, 0, ts, ts), Vector2i(dx, dy))
	return out


static func _apply_edges(base: Image, mask: int, ts: int) -> Image:
	var img: Image = base.duplicate()
	if mask == 0:
		return img
	var edge_px: int = LightingConfig.bevel_edge_px()
	var darken: float = LightingConfig.bevel_darken()
	var brighten: float = LightingConfig.bevel_brighten()
	var top: bool = (mask & EDGE_TOP) != 0
	var right: bool = (mask & EDGE_RIGHT) != 0
	var bottom: bool = (mask & EDGE_BOTTOM) != 0
	var left: bool = (mask & EDGE_LEFT) != 0
	for y in ts:
		for x in ts:
			var factor := 1.0
			if top and y < edge_px:
				factor *= darken
			if right and x >= ts - edge_px:
				factor *= darken
			if bottom and y >= ts - edge_px:
				factor *= brighten
			if left and x < edge_px:
				factor *= brighten
			if factor == 1.0:
				continue
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			c.r = clampf(c.r * factor, 0.0, 1.0)
			c.g = clampf(c.g * factor, 0.0, 1.0)
			c.b = clampf(c.b * factor, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return img


static func _create_source_for_wall(wall_id: int) -> int:
	var info: Dictionary = TileIdRegistry.atlas_for_id(wall_id)
	if info.is_empty():
		return -1
	var base_atlas: int = int(info["atlas"])
	var base_pos: Vector2i = info["pos"]
	var src: TileSetAtlasSource = _bg_tileset.get_source(base_atlas) as TileSetAtlasSource
	if src == null or src.texture == null:
		return -1
	var full: Image = src.texture.get_image()
	if full == null:
		return -1
	var region: Rect2i = src.get_tile_texture_region(base_pos)
	var tile_img: Image = full.get_region(region)
	var ts: int = WorldConfig.tile_size_px()
	var sheet: Image = generate_variants(tile_img, ts)
	var tex := ImageTexture.create_from_image(sheet)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(ts, ts)
	for mask in 16:
		atlas.create_tile(atlas_coords_for_mask(mask))

	var sid: int = _next_source
	_next_source += 1
	if _bg_tileset.has_source(sid):
		_bg_tileset.remove_source(sid)
	_bg_tileset.add_source(atlas, sid)
	return sid
