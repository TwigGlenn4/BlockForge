extends Camera2D

class_name Interactor

const PAN_SPEED = 10
const ZOOM_SPEED = 0.05
const LERP_TIME = 1

static var selected_character: Character:
	set(new_char):
		if new_char != selected_character: 
			# disconnect inventory_changed signal from selected_character
			if selected_character && selected_character.inventory_changed.is_connected(_on_selected_character_inventory_changed_internal):
				selected_character.inventory_changed.disconnect(_on_selected_character_inventory_changed_internal)
			# update selected character
			selected_character = new_char
			# reconnect inventory_changed signal to new character
			selected_character.inventory_changed.connect(_on_selected_character_inventory_changed_internal)
			# emit signals that selected_character and inventory have changed
			selected_character_changed.emit(selected_character)
			selected_character_inventory_changed.emit()

## This signal emits when `Interactor.selected_character` changes
static var selected_character_changed: Signal = _create_static_signal("selected_character_changed", ["new_char", typeof(Character)])
## This signal emits when `Interactor.selected_character`'s inventory changes, or when `Interactor.selected_character` itself changes
static var selected_character_inventory_changed: Signal = _create_static_signal("selected_character_inventory_changed")

static var world: World
static var main_ui: CanvasLayer
static var inventory_ui: Control
static var world_canvas_layer: CanvasLayer
static var main_camera: Camera2D

@export var world_interactor: Control
@export var RECIPE_SELECTOR_SCENE: Resource

var active_recipe_selector: Control

var generating_chunks_enabled = false

# move camera to position
var lerp_target: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	# set static references
	selected_character = get_node("/root/GameScene/World/Character")
	world = get_node("/root/GameScene/World")
	main_ui = get_node("/root/GameScene/World/MainCamera/MainUI")
	inventory_ui = get_node("/root/GameScene/World/MainCamera/MainUI/InventoryUI")
	world_canvas_layer = get_node("/root/GameScene/World/WorldCanvasLayer")
	main_camera = self


func _process(delta):
	# Pan controls
	var movement = Vector2.ZERO
	if Input.is_action_pressed("camera_pan_left"):
		movement += Vector2(-PAN_SPEED, 0)
	if Input.is_action_pressed("camera_pan_right"):
		movement += Vector2(PAN_SPEED, 0)
	if Input.is_action_pressed("camera_pan_up"):
		movement += Vector2(0, -PAN_SPEED)
	if Input.is_action_pressed("camera_pan_down"):
		movement += Vector2(0, PAN_SPEED)
	position += movement * (Vector2.ONE/zoom) * ( delta / 0.0166)

	if lerp_target != Vector2i(-1,-1):
		lerp_timer += delta/LERP_TIME
		clampf(lerp_timer, 0.0, 1.0)
		position = position.lerp(lerp_target, lerp_timer)
		# print("lerped to "+str(position))
		if position == Vector2(lerp_target):
			# print("lerp done, delta = "+str(delta))
			lerp_timer = 0
			lerp_target = Vector2i(-1,-1)

	# Keep cylindrical chunk maps aligned while the camera pans away from the player
	var pop := get_node_or_null("../Mapping/TileMapPopulator")
	if pop and pop.has_method("align_layers_to_camera"):
		pop.align_layers_to_camera(global_position.x)

	# Generate 3 chunks at camera
	if generating_chunks_enabled:
		var chunk_num:int = Helpers.pos_pixel_to_block(position).x / Chunk.WIDTH
		if chunk_num > 0 and chunk_num < world.width-1:
			if world.chunks[chunk_num].gen_state != Chunk.GEN_STATE_MAX:
				world.worldgen.queue_chunk(chunk_num, Chunk.GEN_STATE_MAX)
			if world.chunks[chunk_num-1].gen_state != Chunk.GEN_STATE_MAX:
				world.worldgen.queue_chunk(chunk_num-1, Chunk.GEN_STATE_MAX)
			if world.chunks[chunk_num+1].gen_state != Chunk.GEN_STATE_MAX:
				world.worldgen.queue_chunk(chunk_num+1, Chunk.GEN_STATE_MAX)


# signal functions
## Create a static signal on Interactor and return the signal
## Usage: `static var signal_name: Signal = _create_static_signal("signal_name")`.
## `arg_array` contains params for the signal in the format `{ "name": "arg_name", "type": TYPE_INT }`
static func _create_static_signal(signal_name: String, arg_array: Array = []) -> Signal:
	(Interactor as Object).add_user_signal(signal_name, arg_array)
	return Signal(Interactor, signal_name)

## forward inventory_changed signals from the selected character onwards.
## This listeners to only need Interacter
static func _on_selected_character_inventory_changed_internal() -> void:
	selected_character_inventory_changed.emit()

# ===== PATHFIND ==== Minimal surface + tree helpers (no A* / no general search)

func _is_tree_tile(pos: Vector2i) -> bool:
	var tile: DataTile = world.get_tile_v(pos)
	return tile != null and (
		tile == DataTile.tile("blockforge:log")
		or tile == DataTile.tile("blockforge:leaves")
	)


## True if standing on a tree tile or orthogonally against one (air pocket in canopy).
func _is_in_tree(pos: Vector2i) -> bool:
	if _is_tree_tile(pos):
		return true
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := Vector2i(Helpers.wrap_block_x(pos.x + d.x), pos.y + d.y)
		if _is_tree_tile(n):
			return true
	return false


## Move onto a neighboring tree cell if `pos` itself is air beside the tree.
func _step_onto_tree(character: Node, pos: Vector2i) -> Vector2i:
	if _is_tree_tile(pos):
		return pos
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := Vector2i(Helpers.wrap_block_x(pos.x + d.x), pos.y + d.y)
		if _is_tree_tile(n):
			character.add_job(Job.new(Job.TYPE.GOTO, n))
			return n
	return pos


func surface_path(character: Node, from: Vector2i, dest: Vector2i) -> void:
	print("surface_path ", str(from), " ", str(dest))
	# Must already be near ground — never use this to leave a tree/canopy
	var here: Vector2i = from
	var dest_x: int = Helpers.wrap_block_x(dest.x)
	here.x = Helpers.wrap_block_x(here.x)
	var sy0: int = world.get_surface(here.x)
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
		var y: int = world.get_surface(here.x)
		if y < 0:
			continue
		here.y = y + 1 # stand in air above surface
		character.add_job(Job.new(Job.TYPE.GOTO, here))


func g3_range(a: int, b: int):
	var d: int = sign(b - a)
	if d == 0:
		d = 1
	return range(a, b + d, d)


## Every cell on an L-shaped (axis) path must be tree. horizontal_first = x then y.
func _axis_tree_clear(from: Vector2i, to: Vector2i, horizontal_first: bool) -> bool:
	if from == to:
		return _is_tree_tile(from)
	if horizontal_first:
		for x in g3_range(from.x, to.x):
			if not _is_tree_tile(Vector2i(x, from.y)):
				return false
		for y in g3_range(from.y, to.y):
			if not _is_tree_tile(Vector2i(to.x, y)):
				return false
	else:
		for y in g3_range(from.y, to.y):
			if not _is_tree_tile(Vector2i(from.x, y)):
				return false
		for x in g3_range(from.x, to.x):
			if not _is_tree_tile(Vector2i(x, to.y)):
				return false
	return true


func _emit_axis_jobs(character: Node, cells: Array[Vector2i], from: Vector2i) -> void:
	for cell in cells:
		if cell == from:
			continue
		character.add_job(Job.new(Job.TYPE.GOTO, cell))


func _axis_tree_cells(from: Vector2i, to: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
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
func try_tree_connected_path(character: Node, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	if _axis_tree_clear(from, to, true):
		_emit_axis_jobs(character, _axis_tree_cells(from, to, true), from)
		return true
	if _axis_tree_clear(from, to, false):
		_emit_axis_jobs(character, _axis_tree_cells(from, to, false), from)
		return true
	return false


func find_tree_base(place: Vector2i) -> Vector2i:
	# Prefer this column's lowest log reachable through tree tiles below `place`
	var x: int = Helpers.wrap_block_x(place.x)
	var last_log := Vector2i(-1, -1)
	for y in range(place.y, -1, -1):
		var p := Vector2i(x, y)
		if not _is_tree_tile(p):
			break
		if world.get_tile_v(p) == DataTile.tile("blockforge:log"):
			last_log = p
	if last_log.x >= 0:
		var y2: int = last_log.y - 1
		while y2 >= 0 and world.get_tile_v(Vector2i(x, y2)) == DataTile.tile("blockforge:log"):
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
			var by: int = world.get_surface(bx) + 1
			if world.get_tile_v(Vector2i(bx, by)) == DataTile.tile("blockforge:log"):
				print("found tree base at ", str(Vector2i(bx, by)))
				return Vector2i(bx, by)
	return Vector2i(-1, -1)


## Greedy crawl down through tree tiles; drop only when no tree step remains.
func climb_down_to_ground(character: Node, from: Vector2i) -> Vector2i:
	var here: Vector2i = from
	var base: Vector2i = find_tree_base(from)
	var guard: int = 256
	while guard > 0 and _is_tree_tile(here):
		guard -= 1
		# 1) Prefer descending through tree
		var below := Vector2i(here.x, here.y - 1)
		if _is_tree_tile(below):
			here = below
			character.add_job(Job.new(Job.TYPE.GOTO, here))
			continue
		# 2) Sidestep toward trunk base on this row (stay in canopy/trunk)
		var moved := false
		if base.x >= 0 and here.x != base.x:
			var step: int = sign(base.x - here.x)
			var side := Vector2i(Helpers.wrap_block_x(here.x + step), here.y)
			if _is_tree_tile(side):
				here = side
				character.add_job(Job.new(Job.TYPE.GOTO, here))
				moved = true
		if moved:
			continue
		# 3) Any horizontal tree neighbor (prefer one that has tree below)
		for step2 in [1, -1]:
			var side2 := Vector2i(Helpers.wrap_block_x(here.x + step2), here.y)
			if not _is_tree_tile(side2):
				continue
			here = side2
			character.add_job(Job.new(Job.TYPE.GOTO, here))
			moved = true
			break
		if moved:
			continue
		break # no tree moves left

	# Finish with axis path to base if still in tree and connected by L
	if base.x >= 0 and here != base and _is_tree_tile(here):
		if try_tree_connected_path(character, here, base):
			return base

	if base.x >= 0 and here == base:
		return base

	# Already at ground-level tree cell — do not drop through air
	var sy: int = world.get_surface(here.x)
	if sy >= 0 and here.y <= sy + 1:
		return here

	# Last resort: drop only if still above ground and no further tree crawl
	if sy >= 0 and here.y > sy + 1:
		var ground := Vector2i(Helpers.wrap_block_x(here.x), sy + 1)
		character.add_job(Job.new(Job.TYPE.GOTO, ground))
		return ground
	return here


## Non-superman move: tree↔tree prefers connected L; else down → surface → up.
func navigate_to(character: Node, start: Vector2i, end: Vector2i) -> Vector2i:
	# current_pos is often air beside leaves — treat as in-tree and step onto wood first
	if _is_in_tree(start):
		start = _step_onto_tree(character, start)
	if _is_in_tree(end) and not _is_tree_tile(end):
		# Clicked air next to tree destination — aim at the tree cell
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := Vector2i(Helpers.wrap_block_x(end.x + d.x), end.y + d.y)
			if _is_tree_tile(n):
				end = n
				break

	var start_tree: bool = _is_tree_tile(start)
	var end_tree: bool = _is_tree_tile(end)

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

# ===== END PATHFIND


# Zoom controls in _input to properly accept mouse wheel input
func _input(event: InputEvent) -> void:
	_input_camera_movement(event)
	_input_character_inventory(event)
	_input_click_pos_test(event)
	

func _input_camera_movement(event: InputEvent) -> void:
	var new_zoom: Vector2 = zoom
	if event.is_action_pressed("camera_zoom_in"):
		new_zoom += Vector2(ZOOM_SPEED, ZOOM_SPEED)
	if event.is_action_pressed("camera_zoom_out"):
		new_zoom += Vector2(-ZOOM_SPEED, -ZOOM_SPEED)
	
	zoom = new_zoom.clamp(Vector2(0.02, 0.02), Vector2(3,3))
	scale = Vector2(1 / zoom.x, 1 / zoom.y)

	if Input.is_action_just_pressed("look_at_portal"): # centers camera on bottom block of portal anim
		_move_to_block(world.world_portal_pos)
	if Input.is_action_just_pressed("look_at_character"):
		# print("moving to character")selected_character.current_pos
		_move_to_block(selected_character.current_pos)
	
func _input_character_inventory(event: InputEvent) -> void:
	# open inventory
	if event.is_action_pressed("inventory_open"):
		# print("[interactor.gd] open inventory")
		print(selected_character.inventory)
		

func _input_block_interact(block_pos: Vector2i) -> bool:
	var tile: DataTile = world.get_tile_v(block_pos)
	if tile == null:
		return false
	if tile.interactable:
		_tile_interacion(block_pos, tile)
		return true
	elif tile != Tiles.AIR:
		# Superman: dig/walk straight to the block. Normal mode: fall through to surface/tree pathfinding.
		if WorldConfig.superman():
			var job: Job = Job.new(Job.TYPE.BREAK, block_pos)
			selected_character.add_job(job)
			return true
		return false
	else:
		var held_item_stack: ItemStack = inventory_ui.get_held_item_stack()
		if held_item_stack:
			print("[Interacter] Held item is " + str(held_item_stack) + ", item string is " + str(held_item_stack.get_item()))
			var job: Job = Job.new(Job.TYPE.PLACE, block_pos, str(held_item_stack.get_item()))
			selected_character.add_job(job)
			return true

	return false

func _input_click_pos_test(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click_right"):
		var click_pos:Vector2 = get_global_mouse_position()
		var block_pos:Vector2i = Helpers.pos_pixel_to_block(click_pos)
		world.place_tile_v(block_pos, DataTile.UNDEFINED)
		print("[Interactor._input_click_pos_test()] clicked at ", block_pos)
	


func _move_to_block(block_pos:Vector2i):
	lerp_target = Helpers.pos_block_to_pixel(block_pos)
	lerp_timer = 0


func _on_world_interactor_click(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		var click_pos:Vector2 = get_global_mouse_position()

		var block_pos:Vector2i = Helpers.pos_pixel_to_block(click_pos)
		print("Clicked at "+str(block_pos))

		if not _input_block_interact(block_pos):

			# ===== PATHFIND GENERAL
			var start:Vector2i = selected_character.current_pos
			var end:Vector2i = Vector2i(Helpers.wrap_block_x(block_pos.x), block_pos.y)

			print("\nstart -> end ",str(start)," -> ",str(end))

			# Superman: fly/walk straight to the clicked cell (no surface follow / tree path)
			if WorldConfig.superman():
				selected_character.job_queue.clear()
				selected_character.job_active = Job.NONE
				selected_character.add_job(Job.new(Job.TYPE.GOTO, end))
				print("path finished (superman direct)")
			else:
				selected_character.job_queue.clear()
				selected_character.job_active = Job.NONE
				var dig_pos: Vector2i = end
				var dig_tile: DataTile = world.get_tile_v(dig_pos)
				var want_dig: bool = (
					dig_tile != null
					and dig_tile != Tiles.AIR
					and not dig_tile.interactable
				)
				var is_tree_click: bool = want_dig and _is_tree_tile(dig_pos)
				# Surface destinations stand in air above ground (not when targeting a tree)
				if not is_tree_click and not _is_in_tree(end):
					var surface_y: int = world.get_surface(end.x)
					if surface_y >= 0:
						end.y = surface_y + 1
				var arrived: Vector2i = navigate_to(selected_character, start, end)
				# After navigating: dig trees, or near-surface blocks (not deep underground shortcuts)
				if want_dig:
					var near_surface: bool = abs(dig_pos.y - arrived.y) <= 2
					if is_tree_click or near_surface:
						selected_character.add_job(Job.new(Job.TYPE.BREAK, dig_pos))
				print("path finished")
			# ===== END PATHFIND GENERAL

func _tile_interacion(block_pos: Vector2i, tile: DataTile) -> void:
	match tile.interactable:
		DataTile.INTERACTION.CRAFT:
			var _grassify_dirt = Recipes.PORTAL.GRASSIFY_DIRT
			print("Interacting with crafting block ", tile.name, " at ", block_pos)

			if active_recipe_selector:
				active_recipe_selector.queue_free()

			active_recipe_selector = RECIPE_SELECTOR_SCENE.instantiate()
			active_recipe_selector.setup(tile.name, block_pos)
			main_ui.add_child(active_recipe_selector)
