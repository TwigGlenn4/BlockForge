# ChunkData — 64x64 PackedInt64Array + bit packing
# Layout (LSB→MSB): terrain_id 0-15 | item_id 16-31 | data 32-47 | bit63 reserved
# How to test: var c = ChunkData.new(0,0); c.set_terrain(1,1,5); print(c.get_cell(1,1))
class_name ChunkData
extends RefCounted

const TERRAIN_MASK := 0xFFFF
const ITEM_SHIFT := 16
const ITEM_MASK := 0xFFFF
const DATA_SHIFT := 32
const DATA_MASK := 0xFFFF
const RESERVED_BIT := 1 << 63

var chunk_x: int = 0
var chunk_y: int = 0
var cells: PackedInt64Array = PackedInt64Array()
var dirty: bool = false
var generated: bool = false


func _init(p_x: int = 0, p_y: int = 0) -> void:
	chunk_x = p_x
	chunk_y = p_y
	var n: int = WorldConfig.chunk_size() * WorldConfig.chunk_size()
	cells.resize(n)
	cells.fill(0)


static func pack_cell(terrain_id: int, item_id: int = 0, data: int = 0) -> int:
	var v: int = (terrain_id & TERRAIN_MASK)
	v |= (item_id & ITEM_MASK) << ITEM_SHIFT
	v |= (data & DATA_MASK) << DATA_SHIFT
	return v & ~RESERVED_BIT


static func unpack_terrain(cell: int) -> int:
	return cell & TERRAIN_MASK


static func unpack_item(cell: int) -> int:
	return (cell >> ITEM_SHIFT) & ITEM_MASK


static func unpack_data(cell: int) -> int:
	return (cell >> DATA_SHIFT) & DATA_MASK


func index(local_x: int, local_y: int) -> int:
	return local_y * WorldConfig.chunk_size() + local_x


func get_cell(local_x: int, local_y: int) -> int:
	return cells[index(local_x, local_y)]


func set_cell_packed(local_x: int, local_y: int, packed: int) -> void:
	cells[index(local_x, local_y)] = packed & ~RESERVED_BIT
	dirty = true


func set_terrain(local_x: int, local_y: int, terrain_id: int) -> void:
	var cur: int = get_cell(local_x, local_y)
	set_cell_packed(local_x, local_y, pack_cell(terrain_id, unpack_item(cur), unpack_data(cur)))
