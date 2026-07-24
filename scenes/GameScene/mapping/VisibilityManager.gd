# VisibilityManager — stream columns from viewport + zoom + margin.
# Column gen is coroutine-based; disk load preferred over regenerate.
class_name VisibilityManager
extends Node

signal column_needed(column_x) # int — request full vertical column generation

@export var chunk_manager_path: NodePath = ^"../ChunkManager"
@export var persistence_path: NodePath = ^"../ChunkPersistence"
@export var populator_path: NodePath = ^"../TileMapPopulator"
@export var player_path: NodePath = ^"../../Character"

@onready var chunk_manager: ChunkManager = get_node_or_null(chunk_manager_path)
@onready var persistence: ChunkPersistence = get_node_or_null(persistence_path)
@onready var populator: TileMapPopulator = get_node_or_null(populator_path)
@onready var player: Node2D = get_node_or_null(player_path)

var _generator: Node = null # WorldGenV2 / WorldGenerator providing fill_chunk_array
var _streaming_enabled := false
var _last_player_tile: Vector2i = Vector2i(0x7fffffff, 0x7fffffff)
# Columns currently generating (coroutine in flight) — never start a second gen
var _generating: Dictionary = {} # int -> true

var _frame_counter: int = 0
var _force_update := false
var _hold_repaint := false
var _last_viewport_size: Vector2i = Vector2i.ZERO
var _last_load_min_cx: int = 0
var _last_load_max_cx: int = -1


func _ready() -> void:
	if chunk_manager == null:
		chunk_manager = get_node_or_null("../ChunkManager")
	if persistence == null:
		persistence = get_node_or_null("../ChunkPersistence")
	if populator == null:
		populator = get_node_or_null("../TileMapPopulator")
	if player == null:
		player = get_node_or_null("../../Character")
	var vp := get_viewport()
	if vp:
		_last_viewport_size = vp.get_visible_rect().size
		if not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)


func set_generator(gen: Node) -> void:
	_generator = gen
	# Do not enable streaming yet — WorldInitializer calls begin_streaming() after spawn.


# Called after player is placed on the surface so visibility uses the real camera position.
func begin_streaming() -> void:
	_streaming_enabled = true
	_hold_repaint = false
	if populator and populator.maps_root:
		populator.maps_root.visible = true
	_last_player_tile = Vector2i(0x7fffffff, 0x7fffffff)
	_force_update = true
	var vp := get_viewport()
	if vp:
		_last_viewport_size = Vector2i(vp.get_visible_rect().size)


func _on_viewport_size_changed() -> void:
	if not _streaming_enabled:
		var vp := get_viewport()
		if vp:
			_last_viewport_size = Vector2i(vp.get_visible_rect().size)
		return
	var vp := get_viewport()
	if vp == null:
		return
	var sz: Vector2i = Vector2i(vp.get_visible_rect().size)
	if sz == _last_viewport_size:
		return
	var grew: bool = sz.x > _last_viewport_size.x or sz.y > _last_viewport_size.y
	_last_viewport_size = sz
	request_visibility_update(grew) # hold repaint when viewport grows


# Camera / external: zoom-out or other coverage expansion.
func request_visibility_update(hold_until_loaded: bool = false) -> void:
	_force_update = true
	if hold_until_loaded:
		_begin_hold_repaint()


func notify_zoom_out() -> void:
	request_visibility_update(true)


func _process(_delta: float) -> void:
	if not _streaming_enabled:
		return
	if player == null or chunk_manager == null:
		return

	_frame_counter += 1
	var every_n: int = WorldConfig.visibility_update_every_n_frames()
	var tile: Vector2i = Helpers.pos_pixel_to_block(Vector2i(player.global_position))
	if tile != _last_player_tile:
		_last_player_tile = tile

	var due: bool = _force_update or (_frame_counter % every_n) == 0
	if not due and not _hold_repaint:
		return
	# While holding, keep refreshing on the throttle (and forced) until coverage ready
	if not due and _hold_repaint:
		_end_hold_if_ready()
		return

	_force_update = false
	update_visibility()
	_end_hold_if_ready()


func update_visibility() -> void:
	var t0 := Time.get_ticks_msec()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var ts: float = float(WorldConfig.tile_size_px())
	var cs: int = WorldConfig.chunk_size()
	var view: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var center_px: Vector2 = cam.get_screen_center_position()
	var preload_px: float = float(WorldConfig.margin_blocks_preload()) * ts
	var unload_px: float = float(WorldConfig.margin_blocks_unload()) * ts

	# Load / keep generating within viewport + preload margin
	var load_min_cx: int = int(floor((center_px.x - view.x * 0.5 - preload_px) / (cs * ts)))
	var load_max_cx: int = int(floor((center_px.x + view.x * 0.5 + preload_px) / (cs * ts)))
	# Drop only when outside viewport + unload margin (lazier than load)
	var keep_min_cx: int = int(floor((center_px.x - view.x * 0.5 - unload_px) / (cs * ts)))
	var keep_max_cx: int = int(floor((center_px.x + view.x * 0.5 + unload_px) / (cs * ts)))
	_last_load_min_cx = load_min_cx
	_last_load_max_cx = load_max_cx

	for cx in range(load_min_cx, load_max_cx + 1):
		var wcx: int = chunk_manager.wrap_column(cx)
		_ensure_column(wcx)

	var keep: Dictionary = {}
	for cx in range(keep_min_cx, keep_max_cx + 1):
		keep[Vector2i(chunk_manager.wrap_column(cx), -1)] = true

	var max_active: int = WorldConfig.max_active_tilemaps()
	if populator and populator.active_layer_count() > max_active:
		_drop_farthest_columns(center_px, max_active)

	# Drop whole columns only when outside the wider unload band
	var drop_cols: Dictionary = {}
	for key in chunk_manager.active_keys():
		var k: Vector2i = key
		if not keep.has(Vector2i(k.x, -1)):
			# Don't unload a column mid-generation (let it finish + save to disk)
			if _generating.has(k.x):
				continue
			drop_cols[k.x] = true
	for cx in drop_cols.keys():
		_unload_column(int(cx))

	var updated := 0
	if populator:
		populator.begin_log_batch()
	for key in chunk_manager.active_keys():
		var k: Vector2i = key
		if populator and not populator.has_layer(k.x, k.y):
			populator.populate(chunk_manager.get_chunk(k.x, k.y))
			updated += 1
	if populator:
		populator.end_log_batch()

	if updated > 0:
		WorldConfig.logv("[Visibility] Updated %d chunks in %d ms" % [updated, Time.get_ticks_msec() - t0])


func _begin_hold_repaint() -> void:
	_hold_repaint = true
	if populator and populator.maps_root:
		populator.maps_root.visible = false


func _end_hold_if_ready() -> void:
	if not _hold_repaint:
		return
	if not _viewport_coverage_ready():
		return
	_hold_repaint = false
	if populator and populator.maps_root:
		populator.maps_root.visible = true
	WorldConfig.logv("[Visibility] Viewport coverage ready — repaint resumed")


func _viewport_coverage_ready() -> bool:
	if chunk_manager == null or populator == null:
		return false
	if _last_load_max_cx < _last_load_min_cx:
		return false
	var tall: int = WorldConfig.world_chunks_tall_max()
	for cx in range(_last_load_min_cx, _last_load_max_cx + 1):
		var wcx: int = chunk_manager.wrap_column(cx)
		if not _column_ready(wcx):
			return false
		if _generating.has(wcx):
			return false
		for cy in tall:
			if not populator.has_layer(wcx, cy):
				return false
	return true


func _column_ready(column_x: int) -> bool:
	var tall: int = WorldConfig.world_chunks_tall_max()
	return chunk_manager.get_column_chunks(column_x).size() >= tall


# Fire-and-forget from streaming; prefer disk, else start coroutine gen once.
func _ensure_column(column_x: int) -> void:
	if _column_ready(column_x):
		return
	if _generating.has(column_x):
		return
	if _try_load_column(column_x):
		return
	_generating[column_x] = true
	_generate_column_async(column_x)


# Awaitable for boot / callers that need the column fully ready.
func ensure_column(column_x: int) -> void:
	if _column_ready(column_x):
		return
	if _try_load_column(column_x):
		return
	if not _generating.has(column_x):
		_generating[column_x] = true
		await _generate_column_async(column_x)
		return
	while _generating.has(column_x):
		await get_tree().process_frame
	if not _column_ready(column_x):
		_try_load_column(column_x)


# Load saved column from disk into memory + TileMaps. Returns true if loaded.
func _try_load_column(column_x: int) -> bool:
	var tall: int = WorldConfig.world_chunks_tall_max()
	if persistence == null:
		return false
	if not persistence.has_column(column_x):
		return false
	var loaded: Array = persistence.load_column(column_x)
	if loaded.size() < tall:
		return false
	if populator:
		populator.begin_log_batch()
	for c in loaded:
		var data: ChunkData = c
		chunk_manager.put_chunk(data)
		if populator:
			populator.populate(data)
	if populator:
		populator.end_log_batch()
	column_needed.emit(column_x)
	return true


func _generate_column_async(column_x: int) -> void:
	# TODO: Async/threaded generation (WorkerThreadPool) for fill_column heavy work
	var tall: int = WorldConfig.world_chunks_tall_max()
	var rows: Array = []
	if _generator == null or not _generator.has_method("fill_column"):
		push_error("[Visibility] Generator missing fill_column")
		_generating.erase(column_x)
		return
	rows = await _generator.fill_column(column_x)

	# Materialize rows → ChunkData, always save to disk before populate
	var col: Array = []
	for cy in tall:
		var data := ChunkData.new(column_x, cy)
		if cy < rows.size():
			data.cells = rows[cy]
		data.generated = true
		data.dirty = true
		col.append(data)
		chunk_manager.put_chunk(data)
	if persistence and not col.is_empty():
		persistence.save_column(col)
	if populator:
		populator.begin_log_batch()
		for c in col:
			populator.populate(c as ChunkData)
		populator.end_log_batch()
	_generating.erase(column_x)
	column_needed.emit(column_x)


func _unload_column(column_x: int) -> void:
	var col: Array = chunk_manager.get_column_chunks(column_x)
	if col.is_empty():
		return
	var dirty := false
	for c in col:
		if (c as ChunkData).dirty:
			dirty = true
			break
	if dirty and persistence:
		persistence.save_column(col)
	if populator:
		populator.begin_log_batch()
		for c in col:
			var d: ChunkData = c
			populator.drop_layer(d.chunk_x, d.chunk_y)
		populator.end_log_batch()
	chunk_manager.remove_column(column_x)


func _drop_farthest_columns(center_px: Vector2, keep: int) -> void:
	while populator.active_layer_count() > keep:
		var keys: Array = chunk_manager.active_keys()
		if keys.is_empty():
			break
		var col_dist: Dictionary = {} # cx -> min dist sq
		var cs: int = WorldConfig.chunk_size()
		var ts: int = WorldConfig.tile_size_px()
		for k in keys:
			var key: Vector2i = k
			if _generating.has(key.x):
				continue
			var chunk_center := Vector2((key.x + 0.5) * cs * ts, -((key.y + 0.5) * cs * ts))
			var d: float = chunk_center.distance_squared_to(center_px)
			if not col_dist.has(key.x) or d < float(col_dist[key.x]):
				col_dist[key.x] = d
		var drop_cx: int = -1
		var farthest_d := -1.0
		for cx in col_dist.keys():
			var d: float = float(col_dist[cx])
			if d > farthest_d:
				farthest_d = d
				drop_cx = int(cx)
		if drop_cx < 0:
			break
		_unload_column(drop_cx)
		WorldConfig.logv("[Expiration] Dropped farthest column %d" % drop_cx)
