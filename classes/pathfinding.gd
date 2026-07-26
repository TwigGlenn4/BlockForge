class_name Pathfinding

# ===== PATHFIND ==== Minimal surface + tree helpers (no A* / no general search)

static func is_tree_tile(pos: Vector2i) -> bool:
	var tile: DataTile = Interactor.world.get_tile_v(pos)
	return tile != null and (
		tile == DataTile.tile("blockforge:log")
		or tile == DataTile.tile("blockforge:leaves")
	)


## True if standing on a tree tile or orthogonally against one (air pocket in canopy).
static func is_in_tree(pos: Vector2i) -> bool:
	if is_tree_tile(pos):
		return true
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := Vector2i(Helpers.wrap_block_x(pos.x + d.x), pos.y + d.y)
		if is_tree_tile(n):
			return true
	return false


## Move onto a neighboring tree cell if `pos` itself is air beside the tree.
static func _step_onto_tree(character: Node, pos: Vector2i) -> Vector2i:
	if is_tree_tile(pos):
		return pos
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := Vector2i(Helpers.wrap_block_x(pos.x + d.x), pos.y + d.y)
		if is_tree_tile(n):
			character.add_job(Job.new(Job.TYPE.GOTO, n))
			return n
	return pos


static func surface_path(character: Node, from: Vector2i, dest: Vector2i) -> void:
	print("surface_path ", str(from), " ", str(dest))
	# Must already be near ground — never use this to leave a tree/canopy
	var here: Vector2i = from
	var dest_x: int = Helpers.wrap_block_x(dest.x)
	here.x = Helpers.wrap_block_x(here.x)
	var sy0: int = Interactor.world.get_surface(here.x)
	if sy0 >= 0:
		var stand0 := Vector2i(here.x, sy0 + 1)
		if here != stand0:
			# Only step down to stand if already at/near surface (caller must climb first)
			if here.y <= sy0 + 2:
				here = stand0
				character.add_job(Job.new(Job.TYPE.GOTO, here))
			else:
				push_warning("[Interactor] surface_path called from elevated y=%d; climb_down first" % here.y)
	var dx: int = sign(dest_x - here.x)
	var w: int = WorldConfig.world_width_tiles()
	if w > 0:
		var direct: int = dest_x - here.x
		if abs(direct) > w / 2 and direct != 0:
			dx = -sign(direct)
	var guard: int = w + 2
	while here.x != dest_x and guard > 0:
		guard -= 1
		here.x = Helpers.wrap_block_x(here.x + dx)
		var y: int = Interactor.world.get_surface(here.x)
		if y < 0:
			continue
		here.y = y + 1 # stand in air above surface
		character.add_job(Job.new(Job.TYPE.GOTO, here))


static func g3_range(a: int, b: int):
	var d: int = sign(b - a)
	if d == 0:
		d = 1
	return range(a, b + d, d)


## Every cell on an L-shaped (axis) path must be tree. horizontal_first = x then y.
static func _axis_tree_clear(from: Vector2i, to: Vector2i, horizontal_first: bool) -> bool:
	if from == to:
		return is_tree_tile(from)
	if horizontal_first:
		for x in g3_range(from.x, to.x):
			if not is_tree_tile(Vector2i(x, from.y)):
				return false
		for y in g3_range(from.y, to.y):
			if not is_tree_tile(Vector2i(to.x, y)):
				return false
	else:
		for y in g3_range(from.y, to.y):
			if not is_tree_tile(Vector2i(from.x, y)):
				return false
		for x in g3_range(from.x, to.x):
			if not is_tree_tile(Vector2i(x, to.y)):
				return false
	return true


static func _emit_axis_jobs(character: Node, cells: Array[Vector2i], from: Vector2i) -> void:
	for cell in cells:
		if cell == from:
			continue
		character.add_job(Job.new(Job.TYPE.GOTO, cell))


static func _axis_tree_cells(from: Vector2i, to: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if horizontal_first:
		for x in g3_range(from.x, to.x):
			cells.append(Vector2i(x, from.y))
		for y in g3_range(from.y, to.y):
			var c := Vector2i(to.x, y)
			if cells.is_empty() or cells[cells.size() - 1] != c:
				cells.append(c)
	else:
		for y in g3_range(from.y, to.y):
			cells.append(Vector2i(from.x, y))
		for x in g3_range(from.x, to.x):
			var c := Vector2i(x, to.y)
			if cells.is_empty() or cells[cells.size() - 1] != c:
				cells.append(c)
	return cells


## Demi-direct: HV or VH through tree tiles only (no air). False if neither L works.
static func try_tree_connected_path(character: Node, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	if _axis_tree_clear(from, to, true):
		_emit_axis_jobs(character, _axis_tree_cells(from, to, true), from)
		return true
	if _axis_tree_clear(from, to, false):
		_emit_axis_jobs(character, _axis_tree_cells(from, to, false), from)
		return true
	return false


static func find_tree_base(place: Vector2i) -> Vector2i:
	# Prefer this column's lowest log reachable through tree tiles below `place`
	var x: int = Helpers.wrap_block_x(place.x)
	var last_log := Vector2i(-1, -1)
	for y in range(place.y, -1, -1):
		var p := Vector2i(x, y)
		if not is_tree_tile(p):
			break
		if Interactor.world.get_tile_v(p) == DataTile.tile("blockforge:log"):
			last_log = p
	if last_log.x >= 0:
		var y2: int = last_log.y - 1
		while y2 >= 0 and Interactor.world.get_tile_v(Vector2i(x, y2)) == DataTile.tile("blockforge:log"):
			last_log = Vector2i(x, y2)
			y2 -= 1
		print("found tree base at ", str(last_log))
		return last_log
	# Fallback: nearest surface trunk within ±20 columns
	for dx in 21:
		for side in [1, -1]:
			if dx == 0 and side < 0:
				continue
			var bx: int = Helpers.wrap_block_x(place.x + dx * side)
			var by: int = Interactor.world.get_surface(bx) + 1
			if Interactor.world.get_tile_v(Vector2i(bx, by)) == DataTile.tile("blockforge:log"):
				print("found tree base at ", str(Vector2i(bx, by)))
				return Vector2i(bx, by)
	return Vector2i(-1, -1)


## Greedy crawl down through tree tiles; drop only when no tree step remains.
static func climb_down_to_ground(character: Node, from: Vector2i) -> Vector2i:
	var here: Vector2i = from
	var base: Vector2i = find_tree_base(from)
	var guard: int = 256
	while guard > 0 and is_tree_tile(here):
		guard -= 1
		# 1) Prefer descending through tree
		var below := Vector2i(here.x, here.y - 1)
		if is_tree_tile(below):
			here = below
			character.add_job(Job.new(Job.TYPE.GOTO, here))
			continue
		# 2) Sidestep toward trunk base on this row (stay in canopy/trunk)
		var moved := false
		if base.x >= 0 and here.x != base.x:
			var step: int = sign(base.x - here.x)
			var side := Vector2i(Helpers.wrap_block_x(here.x + step), here.y)
			if is_tree_tile(side):
				here = side
				character.add_job(Job.new(Job.TYPE.GOTO, here))
				moved = true
		if moved:
			continue
		# 3) Any horizontal tree neighbor (prefer one that has tree below)
		for step2 in [1, -1]:
			var side2 := Vector2i(Helpers.wrap_block_x(here.x + step2), here.y)
			if not is_tree_tile(side2):
				continue
			here = side2
			character.add_job(Job.new(Job.TYPE.GOTO, here))
			moved = true
			break
		if moved:
			continue
		break # no tree moves left

	# Finish with axis path to base if still in tree and connected by L
	if base.x >= 0 and here != base and is_tree_tile(here):
		if try_tree_connected_path(character, here, base):
			return base

	if base.x >= 0 and here == base:
		return base

	# Already at ground-level tree cell — do not drop through air
	var sy: int = Interactor.world.get_surface(here.x)
	if sy >= 0 and here.y <= sy + 1:
		return here

	# Last resort: drop only if still above ground and no further tree crawl
	if sy >= 0 and here.y > sy + 1:
		var ground := Vector2i(Helpers.wrap_block_x(here.x), sy + 1)
		character.add_job(Job.new(Job.TYPE.GOTO, ground))
		return ground
	return here


## Non-superman move: tree↔tree prefers connected L; else down → surface → up.
static func navigate_to(character: Node, start: Vector2i, end: Vector2i) -> Vector2i:
	# current_pos is often air beside leaves — treat as in-tree and step onto wood first
	if is_in_tree(start):
		start = _step_onto_tree(character, start)
	if is_in_tree(end) and not is_tree_tile(end):
		# Clicked air next to tree destination — aim at the tree cell
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := Vector2i(Helpers.wrap_block_x(end.x + d.x), end.y + d.y)
			if is_tree_tile(n):
				end = n
				break

	var start_tree: bool = is_tree_tile(start)
	var end_tree: bool = is_tree_tile(end)

	if start_tree and end_tree:
		if try_tree_connected_path(character, start, end):
			return end
		var ground: Vector2i = climb_down_to_ground(character, start)
		var base_e: Vector2i = find_tree_base(end)
		if base_e.x < 0:
			base_e = end
		surface_path(character, ground, base_e)
		try_tree_connected_path(character, base_e, end)
		return end

	if start_tree and not end_tree:
		var ground2: Vector2i = climb_down_to_ground(character, start)
		surface_path(character, ground2, end)
		return end

	if not start_tree and end_tree:
		var base_e2: Vector2i = find_tree_base(end)
		if base_e2.x < 0:
			base_e2 = end
		surface_path(character, start, base_e2)
		try_tree_connected_path(character, base_e2, end)
		return end

	surface_path(character, start, end)
	return end
