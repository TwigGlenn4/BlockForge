# MappedTilesSaver — save/load currently active (mapped) TileMap chunk set
class_name MappedTilesSaver
extends Node

const STATE_PATH := "user://world_columns/mapped_tiles_state.dat"

@export var chunk_manager_path: NodePath = ^"../ChunkManager"
@export var persistence_path: NodePath = ^"../ChunkPersistence"

@onready var chunk_manager: ChunkManager = get_node_or_null(chunk_manager_path)
@onready var persistence: ChunkPersistence = get_node_or_null(persistence_path)


func _ready() -> void:
	if chunk_manager == null:
		chunk_manager = get_node_or_null("../ChunkManager")
	if persistence == null:
		persistence = get_node_or_null("../ChunkPersistence")


func save_active_chunks() -> void:
	if chunk_manager == null or persistence == null:
		return
	var t0 := Time.get_ticks_msec()
	var keys: Array = chunk_manager.active_keys()
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[MappedTilesSaver] Cannot write %s" % STATE_PATH)
		return
	f.store_32(keys.size())
	var dirty_cols: Dictionary = {}
	for k in keys:
		var key: Vector2i = k
		f.store_32(key.x)
		f.store_32(key.y)
		var data: ChunkData = chunk_manager.get_chunk(key.x, key.y)
		if data != null and data.dirty:
			dirty_cols[key.x] = true
	f.close()
	# One write per dirty column
	for cx in dirty_cols.keys():
		persistence.save_column(chunk_manager.get_column_chunks(int(cx)))
	WorldConfig.logv("[MappedTilesSaver] Saved %d active keys (%d columns) in %d ms" % [
		keys.size(), dirty_cols.size(), Time.get_ticks_msec() - t0
	])


func load_active_keys() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not FileAccess.file_exists(STATE_PATH):
		return out
	var f := FileAccess.open(STATE_PATH, FileAccess.READ)
	if f == null:
		return out
	var n: int = f.get_32()
	for _i in n:
		out.append(Vector2i(f.get_32(), f.get_32()))
	f.close()
	return out
