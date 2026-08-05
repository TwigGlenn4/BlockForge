# WallLosLight — Bresenham LOS for wall lighting (no cookies / no visible cover).
# Builds per-chunk LOS factor map for wall_los.gdshader.
# Corner leak: unmask blocked cells visible from lit rim — no extra lights.
class_name WallLosLight
extends RefCounted

const _CARDINALS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)
]


## cs×cs RGBA8: white=receive PointLight2D, black=block. Default white.
static func build_los_image(
	cm: ChunkManager,
	data: ChunkData,
	lanterns: Array[Vector2i],
	radius_tiles: int
) -> Image:
	var cs: int = data.size if data != null and data.size > 0 else WorldConfig.chunk_size()
	var img := Image.create(cs, cs, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	if cm == null or data == null or lanterns.is_empty():
		return img
	var blocked: Dictionary = _blocked_cells(cm, data, lanterns, radius_tiles)
	for g in blocked.keys():
		var local: Vector2i = blocked[g]
		img.set_pixel(local.x, local.y, Color(0, 0, 0, 1))
	return img


static func _blocked_cells(
	cm: ChunkManager,
	data: ChunkData,
	lanterns: Array[Vector2i],
	radius_tiles: int
) -> Dictionary:
	var blocked: Dictionary = {}
	if cm == null or data == null or lanterns.is_empty():
		return blocked
	var cs: int = data.size if data.size > 0 else WorldConfig.chunk_size()
	var r: float = float(maxi(1, radius_tiles))
	var r2: float = r * r
	var lit: Dictionary = {}

	for ly in cs:
		for lx in cs:
			if data.get_wall(lx, ly) <= 0:
				continue
			if ChunkData.unpack_terrain(data.get_cell(lx, ly)) > 0:
				continue
			var gx: int = data.chunk_x * cs + lx
			var gy: int = data.chunk_y * cs + ly
			var in_range := false
			var any_clear := false
			for lamp in lanterns:
				var dx: float = float(gx - lamp.x)
				var dy: float = float(gy - lamp.y)
				if dx * dx + dy * dy > r2:
					continue
				in_range = true
				if los_clear(cm, lamp.x, lamp.y, gx, gy):
					any_clear = true
					break
			if not in_range:
				continue
			var g := Vector2i(gx, gy)
			if any_clear:
				lit[g] = true
			else:
				blocked[g] = Vector2i(lx, ly)

	_unmask_corner_leak(cm, lit, blocked)
	return blocked


static func _unmask_corner_leak(cm: ChunkManager, lit: Dictionary, blocked: Dictionary) -> void:
	if lit.is_empty() or blocked.is_empty():
		return
	var perimeter: Array[Vector2i] = []
	for g in lit.keys():
		var p: Vector2i = g
		if _is_lit_perimeter(cm, p, lit, blocked):
			perimeter.append(p)
	var unmask: Dictionary = {}
	var leak: int = LightingConfig.mask_leak_radius()
	if leak <= 0:
		return
	for p in perimeter:
		for oy in range(-leak, leak + 1):
			for ox in range(-leak, leak + 1):
				if ox == 0 and oy == 0:
					continue
				var b := Vector2i(p.x + ox, p.y + oy)
				if not blocked.has(b) or unmask.has(b):
					continue
				if los_clear(cm, p.x, p.y, b.x, b.y):
					unmask[b] = true
	for b in unmask.keys():
		blocked.erase(b)


static func _is_lit_perimeter(
	cm: ChunkManager, p: Vector2i, lit: Dictionary, blocked: Dictionary
) -> bool:
	for d in _CARDINALS:
		var n: Vector2i = p + d
		if blocked.has(n):
			return true
		if lit.has(n):
			continue
		if _is_solid(cm, n.x, n.y):
			return true
	return false


static func _is_solid(cm: ChunkManager, gx: int, gy: int) -> bool:
	var tid: int = cm.get_terrain_id(gx, gy)
	return tid < 0 or tid > 0


static func los_clear(cm: ChunkManager, x0: int, y0: int, x1: int, y1: int) -> bool:
	if cm == null:
		return false
	var cells: Array[Vector2i] = _bresenham(x0, y0, x1, y1)
	for i in range(1, cells.size() - 1):
		var c: Vector2i = cells[i]
		var tid: int = cm.get_terrain_id(c.x, c.y)
		if tid != 0:
			return false
	return true


static func _bresenham(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		out.append(Vector2i(x, y))
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return out
