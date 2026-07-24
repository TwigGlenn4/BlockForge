# WorldConfig — loads data/world_config.yaml via Yaml
class_name WorldConfig
extends RefCounted

const CONFIG_PATH := "res://data/world_config.yaml"

static var _cfg: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_cfg = Yaml.load_yaml(CONFIG_PATH)
	_loaded = true
	WorldConfig.logv("[WorldConfig] Loaded %s" % CONFIG_PATH)


static func _ensure() -> void:
	if not _loaded:
		reload()


static func get_value(key: String, default: Variant = null) -> Variant:
	_ensure()
	return _cfg.get(key, default)


static func chunk_size() -> int:
	return int(get_value("chunk_size", 64))


static func world_chunks_wide_max() -> int:
	return int(get_value("world_chunks_wide_max", 256))


static func world_chunks_tall_max() -> int:
	return int(get_value("world_chunks_tall_max", 16))


static func tile_size_px() -> int:
	return int(get_value("tile_size_px", 16))


static func margin_blocks_preload() -> int:
	return int(get_value("margin_blocks_preload", 8))


static func margin_blocks_unload() -> int:
	return int(get_value("margin_blocks_unload", 256))


static func max_zoom() -> float:
	return float(get_value("max_zoom", 4.0))


static func min_zoom() -> float:
	return float(get_value("min_zoom", 0.125))


static func initial_zoom() -> float:
	return float(get_value("initial_zoom", 0.5))


static func max_active_tilemaps() -> int:
	return int(get_value("max_active_tilemaps", 128))


static func visibility_update_every_n_frames() -> int:
	return maxi(1, int(get_value("visibility_update_every_n_frames", 6)))


static func default_viewport_width_px() -> int:
	return int(get_value("default_viewport_width_px", 2096))


static func default_viewport_height_px() -> int:
	return int(get_value("default_viewport_height_px", 1024))


static func world_seed() -> int:
	return int(get_value("world_seed", 42))


static func player_speed() -> float:
	return float(get_value("player_speed", 10.0))


static func has_key(key: String) -> bool:
	_ensure()
	return _cfg.has(key)


static func superman() -> bool:
	# Missing key => false
	if not has_key("superman"):
		return false
	return bool(get_value("superman", false))


static func debug_grid() -> bool:
	# Missing key => false
	if not has_key("debug_grid"):
		return false
	return bool(get_value("debug_grid", false))


static func debug_clear_world_columns() -> bool:
	# Missing key => false (keep saved columns across runs)
	if not has_key("debug_clear_world_columns"):
		return false
	return bool(get_value("debug_clear_world_columns", false))


static func world_width_tiles() -> int:
	return chunk_size() * world_chunks_wide_max()


static func world_width_px() -> float:
	return float(world_width_tiles() * tile_size_px())


static func world_height_tiles() -> int:
	return chunk_size() * world_chunks_tall_max()


# ===== DEBUG
# print_verbose() often stays silent even with --verbose; use print so timings show up.
static func logv(msg: String) -> void:
	print(msg)
# ===== DEBUG
