# WorldInitializer — generate center columns, place player on surface, set camera
# How to integrate: child of World/Mapping; paths optional (defaults to sibling/parent nodes)
class_name WorldInitializer
extends Node

@export var chunk_manager_path: NodePath = ^"../ChunkManager"
@export var persistence_path: NodePath = ^"../ChunkPersistence"
@export var populator_path: NodePath = ^"../TileMapPopulator"
@export var visibility_path: NodePath = ^"../VisibilityManager"
@export var player_path: NodePath = ^"../../Character"
@export var camera_path: NodePath = ^"../../MainCamera"
@export var worldgen_path: NodePath = ^"../../WorldGen"

var chunk_manager: ChunkManager
var visibility: VisibilityManager
var player: Node2D
var camera: Camera2D
var worldgen: Node


func _ready() -> void:
	call_deferred("_boot")


func _resolve_nodes() -> bool:
	chunk_manager = _resolve(chunk_manager_path, "../ChunkManager") as ChunkManager
	visibility = _resolve(visibility_path, "../VisibilityManager") as VisibilityManager
	player = _resolve(player_path, "../../Character") as Node2D
	camera = _resolve(camera_path, "../../MainCamera") as Camera2D
	worldgen = _resolve(worldgen_path, "../../WorldGen")
	if chunk_manager == null or visibility == null or player == null or camera == null or worldgen == null:
		push_error("[Init] Missing required Mapping nodes (ChunkManager/Visibility/Character/Camera/WorldGen)")
		return false
	return true


func _resolve(path: NodePath, fallback: String) -> Node:
	if path != NodePath("") and path != NodePath():
		var n := get_node_or_null(path)
		if n:
			return n
	return get_node_or_null(fallback)


func _apply_viewport_window_size() -> void:
	var w: int = WorldConfig.default_viewport_width_px()
	var h: int = WorldConfig.default_viewport_height_px()
	var win := get_window()
	if win == null:
		return
	win.size = Vector2i(w, h)
	WorldConfig.logv("[Init] Window content size set to %dx%d from world_config" % [w, h])


func _boot() -> void:
	if not _resolve_nodes():
		return
	var t0 := Time.get_ticks_msec()
	WorldConfig.reload()
	_apply_viewport_window_size()
	TileIdRegistry.ensure_ready()

	# Apply seed to legacy World if present
	var world := get_node_or_null("/root/GameScene/World")
	if world and "w_seed" in world:
		world.w_seed = WorldConfig.world_seed()

	if worldgen and worldgen.has_method("setup"):
		worldgen.setup()

	visibility.set_generator(worldgen)

	var center_col: int = WorldConfig.world_chunks_wide_max() / 2
	for dx in range(-1, 2):
		var cx: int = chunk_manager.wrap_column(center_col + dx)
		await visibility.ensure_column(cx)

	# Ensure portal column exists so crafting station is reachable after boot
	if worldgen and worldgen.has_method("ensure_mapped_portal_x"):
		worldgen.ensure_mapped_portal_x()
	if world and "world_portal_pos" in world:
		var portal_col: int = int(world.world_portal_pos.x) / WorldConfig.chunk_size()
		portal_col = chunk_manager.wrap_column(portal_col)
		await visibility.ensure_column(portal_col)

	var spawn := _find_spawn(center_col)
	# Match Helpers.pos_block_to_pixel so camera/character align with tiles
	player.global_position = Helpers.pos_block_to_pixel(spawn)
	if "current_pos" in player:
		player.current_pos = spawn

	camera.global_position = player.global_position
	var z: float = WorldConfig.initial_zoom()
	camera.zoom = Vector2(z, z)

	if "stats" in player and player.stats is Dictionary:
		player.stats.speed = WorldConfig.player_speed()

	# Start streaming only after spawn so visibility doesn't unload center columns
	# while the camera is still at the origin.
	visibility.begin_streaming()

	WorldConfig.logv("[Init] World ready at spawn %s in %d ms" % [str(spawn), Time.get_ticks_msec() - t0])


func _find_spawn(center_col: int) -> Vector2i:
	var cs: int = WorldConfig.chunk_size()
	var gx: int = center_col * cs + cs / 2
	var gy: int = chunk_manager.find_surface_height(gx)
	if gy < 0:
		push_warning("[Init] No surface found at column %d; using fallback" % center_col)
		return Vector2i(gx, cs)
	var spawn := Vector2i(gx, gy + 1) # stand in air cell above surface
	WorldConfig.logv("[Init] Surface at gy=%d → spawn %s" % [gy, str(spawn)])
	return spawn
