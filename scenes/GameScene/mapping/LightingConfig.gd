# LightingConfig — loads data/lighting.yaml (ambient + hierarchical sources).
class_name LightingConfig
extends RefCounted

const CONFIG_PATH := "res://data/lighting.yaml"

static var _cfg: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_cfg = Yaml.load_yaml(CONFIG_PATH)
	_loaded = true


static func _ensure() -> void:
	if not _loaded:
		reload()


static func root() -> Dictionary:
	_ensure()
	return _cfg


static func ambient() -> Dictionary:
	_ensure()
	return _cfg.get("ambient", {})


static func sources() -> Dictionary:
	_ensure()
	return _cfg.get("sources", {})


static func source(name: String) -> Dictionary:
	return sources().get(name, {})


static func ambient_modulate() -> Color:
	var a: Dictionary = ambient()
	return _color(a.get("modulate", [0.55, 0.55, 0.62, 1.0]), Color(0.55, 0.55, 0.62, 1.0))


static func source_color(name: String, fallback: Color) -> Color:
	return _color(source(name).get("color", []), fallback)


static func source_energy(name: String, fallback: float) -> float:
	return float(source(name).get("energy", fallback))


static func source_radius_px(name: String, fallback: float) -> float:
	return float(source(name).get("radius_px", fallback))


static func source_sprite(name: String) -> String:
	return str(source(name).get("sprite", ""))


static func source_item_id(name: String, fallback: int = 0) -> int:
	return int(source(name).get("item_id", fallback))


static func masks() -> Dictionary:
	_ensure()
	return _cfg.get("masks", {})


static func mask_blocks() -> int:
	return int(masks().get("blocks", 1))


static func mask_walls() -> int:
	return int(masks().get("walls", 2))


static func mask() -> Dictionary:
	_ensure()
	return _cfg.get("mask", {})


static func mask_leak_radius(fallback: int = 2) -> int:
	return maxi(0, int(mask().get("leak_radius", fallback)))


static func bevel() -> Dictionary:
	_ensure()
	return _cfg.get("bevel", {})


static func bevel_edge_px(fallback: int = 2) -> int:
	return int(bevel().get("edge_px", fallback))


static func bevel_darken(fallback: float = 0.50) -> float:
	return float(bevel().get("darken", fallback))


static func bevel_brighten(fallback: float = 1.50) -> float:
	return float(bevel().get("brighten", fallback))


static func source_item_cull_mask(name: String, fallback: int = 1) -> int:
	return int(source(name).get("item_cull_mask", fallback))


static func _color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is Array and v.size() >= 3:
		var a: float = float(v[3]) if v.size() > 3 else 1.0
		return Color(float(v[0]), float(v[1]), float(v[2]), a)
	return fallback
