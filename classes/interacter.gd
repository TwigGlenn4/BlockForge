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

@onready var world = get_node("/root/GameScene/World")
@onready var main_ui = get_node("/root/GameScene/World/MainCamera/MainUI")
@onready var inventory_ui = get_node("/root/GameScene/World/MainCamera/MainUI/InventoryUI")

@export var world_interactor: Control
@export var RECIPE_SELECTOR_SCENE: Resource

var active_recipe_selector: Control

var generating_chunks_enabled = false

# move camera to position
var lerp_target: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	# select the first character
	selected_character = get_node("/root/GameScene/World/Character")
	# selected_character_changed.emit(selected_character)


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

# ===== PATHFIND ==== This method needs to be gathered into pathfinding.gd
func surface_path (character:Node, from:Vector2i, dest:Vector2i):
	print("surface_path ",str(from)," ",str(dest))
	var _method: Path.Movement
	var here:Vector2i = from
	var dx:int = sign(dest.x - here.x)
	var dy:int
	while(here.x != dest.x):
		here.x += dx
		var y = world.get_surface(here.x)
		dy = y - here.y
		here.y += dy
		
		if abs(dy) > 1:
			_method = Path.Movement.CLIMB
		elif abs(dy) == 1:
			_method = Path.Movement.HOP
		else:
			_method = Path.Movement.WALK 
			# similar for but lookup blocks for climb in trees, blocks around for CLIMB_RIGHT, blocks above for CRAWL
		
		character.add_job(DataJob.new(DataJob.TYPE.GOTO, here))
		# should add method as another parameter in TYPE.GOTO

func tree_path (character:Node, start:Vector2i, end:Vector2i): # traverse tree
	print("tree_path ",str(start),"",str(end))
	var here:Vector2i
	if start.y>end.y: #dir.DOWN
		here = start
		for x in g3_range(start.x, end.x):
			here.x = x
			character.add_job(DataJob.new(DataJob.TYPE.GOTO, here)) #method = CLIMB
		for y in g3_range(start.y, end.y):
			here.y = y
			character.add_job(DataJob.new(DataJob.TYPE.GOTO, here)) #method = CLIMB
	else: # Dir.UP
		here = start
		for y in g3_range(start.y, end.y):
			here.y = y
			character.add_job(DataJob.new(DataJob.TYPE.GOTO, here)) #method = CLIMB
		for x in g3_range(start.x, end.x):
			here.x = x
			character.add_job(DataJob.new(DataJob.TYPE.GOTO, here)) #method = CLIMB
	return here 

func g3_range(a:int, b:int):
	var d:int = sign(b-a)
	if d == 0: # set step to 1 if sign == 0
		d = 1
	return range(a, b+d, d)
		
func find_tree_base(place:Vector2i): # find nearest trunk
	var base:Vector2i
	var y:int
	var x:int
	for dx in 20:
		x = place.x+dx
		y = world.get_surface(x) + 1
		#print("x,y ",x,",",y)
		# world.place_tile(x,y,DataTile.tile("blockforge:water")) #DEBUG
		# await get_tree().create_timer(1.0).timeout
		if world.get_tile(x, y)==DataTile.tile("blockforge:log"):
			base = Vector2i(x, y)
			break
		x = place.x-dx 
		y = world.get_surface(x) + 1
		if world.get_tile(x, y)==DataTile.tile("blockforge:log"):
			base = Vector2i(x, y)
			break
	#if not is_instance_valid(base): # ===== DEBUG
	#  pass #can't get out of tree
	#  return false
	print("found tree base at ",str(base))
	return base

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
	if tile.interactable:
		_tile_interacion(block_pos, tile)
	elif tile != Tiles.AIR:
		var job: DataJob = DataJob.new(DataJob.TYPE.BREAK, block_pos)
		selected_character.add_job(job)
		return true
	else:
		var held_item_stack: ItemStack = inventory_ui.get_held_item_stack()
		if held_item_stack:
			print("[Interacter] Held item is " + str(held_item_stack) + ", item string is " + str(held_item_stack.get_item()))
			var job: DataJob = DataJob.new(DataJob.TYPE.PLACE, block_pos, str(held_item_stack.get_item()))
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
			var end:Vector2i = block_pos
			var next:Vector2i

			print("\nstart -> end ",str(start)," -> ",str(end))
			var tile = world.get_tile_v(start)
			if tile==DataTile.tile("blockforge:log") or tile==DataTile.tile("blockforge:leaves"):
				next = find_tree_base (start)
				tree_path(selected_character, start, next)
				start = next
			tile = world.get_tile_v(end)
			if tile==DataTile.tile("blockforge:log") or tile==DataTile.tile("blockforge:leaves"):  
				next = find_tree_base(end)
				surface_path(selected_character, start, next)
				tree_path(selected_character, next, end)
			else:
				end.y = world.get_surface(end.x) # pin to surface of earth
				surface_path (selected_character, start, end)
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
			active_recipe_selector.setup(tile.name, self)
			main_ui.add_child(active_recipe_selector)
