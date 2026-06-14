extends Camera2D

const PAN_SPEED = 10
const ZOOM_SPEED = 0.05
const LERP_TIME = 1

@onready var world = get_node("/root/GameScene/World")
@onready var selected_character = get_node("/root/GameScene/World/Character")

var generating_chunks_enabled = false

# move camera to position
var lerp_target: Vector2i = Vector2i(-1,-1)
var lerp_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


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
		
		character.add_job(DataJob.new(here, DataJob.TYPE.GOTO))
		# should add method as another parameter in TYPE.GOTO

func tree_path (character:Node, start:Vector2i, end:Vector2i): # traverse tree
	print("tree_path ",str(start),"",str(end))
	var here:Vector2i
	if start.y>end.y: #dir.DOWN
		here = start
		for x in g3_range(start.x, end.x):
			here.x = x
			character.add_job(DataJob.new(here, DataJob.TYPE.GOTO)) #method = CLIMB
		for y in g3_range(start.y, end.y):
			here.y = y
			character.add_job(DataJob.new(here, DataJob.TYPE.GOTO)) #method = CLIMB
	else: # Dir.UP
		here = start
		for y in g3_range(start.y, end.y):
			here.y = y
			character.add_job(DataJob.new(here, DataJob.TYPE.GOTO)) #method = CLIMB
		for x in g3_range(start.x, end.x):
			here.x = x
			character.add_job(DataJob.new(here, DataJob.TYPE.GOTO)) #method = CLIMB
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



func _input_camera_movement(event: InputEvent) -> void:
	var new_zoom: Vector2 = zoom
	if event.is_action_pressed("camera_zoom_in"):
		new_zoom += Vector2(ZOOM_SPEED, ZOOM_SPEED)
	if event.is_action_pressed("camera_zoom_out"):
		new_zoom += Vector2(-ZOOM_SPEED, -ZOOM_SPEED)
	
	zoom = new_zoom.clamp(Vector2(0.02, 0.02), Vector2(3,3))
	scale = Vector2(1 / zoom.x, 1 / zoom.y)

	if event.is_action_pressed("print_pointer_location"):
		print("Mouse is at: ", get_global_mouse_position()/16)
	
	if Input.is_action_pressed("look_at_portal"): # centers camera on bottom block of portal anim
		_move_to_block(world.world_portal_pos)
	if Input.is_action_pressed("look_at_character"):
		# print("moving to character")selected_character.current_pos
		_move_to_block(selected_character.current_pos)
	
func _input_character_inventory(event: InputEvent) -> void:
	# open inventory
	if event.is_action_pressed("inventory_open"):
		# print("[interactor.gd] open inventory")
		selected_character.open_inventory()

func _input_block_interact(block_pos: Vector2i) -> bool:
	var tile: DataTile = world.get_tile_v(block_pos)
	if tile != DataTile.UNDEFINED:
		var job: DataJob = DataJob.new(block_pos, DataJob.TYPE.BREAK)
		selected_character.add_job(job)
		return true
	return false
	


func _move_to_block(block_pos:Vector2i):
	lerp_target = Helpers.pos_block_to_pixel(block_pos)
	lerp_timer = 0
