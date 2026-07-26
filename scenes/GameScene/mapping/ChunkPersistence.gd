# ChunkPersistence — one file per world column under user://world_columns/
# Always save/load an entire column in one I/O operation (RLE + GZIP).
class_name ChunkPersistence
extends Node

const COLUMNS_DIR := "user://world_columns"


func _ready() -> void:
	# ===== DEBUG
	if WorldConfig.debug_clear_world_columns():
		_debug_clear_world_columns()
	# ===== DEBUG
	DirAccess.make_dir_recursive_absolute(COLUMNS_DIR)


# ===== DEBUG
func _debug_clear_world_columns() -> void:
	var abs_path := ProjectSettings.globalize_path(COLUMNS_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		WorldConfig.logv("[DEBUG] No world_columns to clear at %s" % abs_path)
		return
	var dir := DirAccess.open(COLUMNS_DIR)
	if dir == null:
		push_warning("[DEBUG] Could not open %s to clear" % COLUMNS_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	var removed := 0
	while fname != "":
		if not dir.current_is_dir():
			dir.remove(fname)
			removed += 1
		fname = dir.get_next()
	dir.list_dir_end()
	WorldConfig.logv("[DEBUG] Cleared %d files from %s" % [removed, COLUMNS_DIR])
# ===== DEBUG


func column_path(column_x: int) -> String:
	return "%s/column_%03d.dat" % [COLUMNS_DIR, column_x]


func has_column(column_x: int) -> bool:
	return FileAccess.file_exists(column_path(column_x))


# Save every chunk in the column in one write. `chunks` = Array[ChunkData] same chunk_x.
func save_column(chunks: Array) -> void:
	if chunks.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var cx: int = chunks[0].chunk_x
	var column: Dictionary = {}
	for c in chunks:
		var d: ChunkData = c
		column[d.chunk_y] = d.cells.duplicate()
		d.dirty = false
	_save_column_dict(cx, column)
	WorldConfig.logv("[Chunk] Saved column %d (%d rows) in %d ms" % [
		cx, column.size(), Time.get_ticks_msec() - t0
	])


# Load every row for a column. Returns Array[ChunkData] (may be empty / partial).
func load_column(cx: int) -> Array:
	var t0 := Time.get_ticks_msec()
	var column: Dictionary = _load_column_dict(cx)
	var out: Array = []
	for cy in column.keys():
		var data := ChunkData.new(cx, int(cy))
		data.cells = column[cy]
		data.generated = true
		data.dirty = false
		out.append(data)
	if not out.is_empty():
		WorldConfig.logv("[Chunk] Loaded column %d (%d rows) in %d ms" % [
			cx, out.size(), Time.get_ticks_msec() - t0
		])
	return out


# Back-compat name — prefer save_column().
func save_column_chunks(chunks: Array) -> void:
	save_column(chunks)


func _load_column_dict(cx: int) -> Dictionary:
	var path := column_path(cx)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		push_error("[ChunkPersistence] Failed to open %s" % path)
		return {}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var decoded: PackedInt64Array = _rle_decode(bytes)
	# Encoded as: [row_count, (cy, cell_count, cells...), ...]
	if decoded.is_empty():
		return {}
	var out: Dictionary = {}
	var i := 0
	var row_count: int = int(decoded[i]); i += 1
	for _r in row_count:
		if i >= decoded.size():
			break
		var cy: int = int(decoded[i]); i += 1
		var n: int = int(decoded[i]); i += 1
		var cells := PackedInt64Array()
		cells.resize(n)
		for j in n:
			cells[j] = decoded[i]; i += 1
		out[cy] = cells
	return out


func _save_column_dict(cx: int, column: Dictionary) -> void:
	var encoded := PackedInt64Array()
	encoded.append(column.size())
	var keys: Array = column.keys()
	keys.sort()
	for cy in keys:
		var cells: PackedInt64Array = column[cy]
		encoded.append(int(cy))
		encoded.append(cells.size())
		encoded.append_array(cells)
	var bytes := _rle_encode(encoded)
	var path := column_path(cx)
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		push_error("[ChunkPersistence] Failed to write %s" % path)
		return
	f.store_buffer(bytes)
	f.close()


func _rle_encode(values: PackedInt64Array) -> PackedByteArray:
	var out := PackedByteArray()
	if values.is_empty():
		return out
	var i := 0
	while i < values.size():
		var v: int = values[i]
		var count := 1
		while i + count < values.size() and values[i + count] == v and count < 0xFFFFFFFF:
			count += 1
		out.append_array(_u32_bytes(count))
		out.append_array(_i64_bytes(v))
		i += count
	return out


func _rle_decode(bytes: PackedByteArray) -> PackedInt64Array:
	var out := PackedInt64Array()
	var i := 0
	while i + 12 <= bytes.size():
		var count := _read_u32(bytes, i); i += 4
		var v := _read_i64(bytes, i); i += 8
		for _c in count:
			out.append(v)
	return out


func _u32_bytes(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


func _i64_bytes(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, v)
	return b


func _read_u32(b: PackedByteArray, offset: int) -> int:
	return b.decode_u32(offset)


func _read_i64(b: PackedByteArray, offset: int) -> int:
	return b.decode_s64(offset)
