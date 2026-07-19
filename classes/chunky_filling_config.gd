# Minimal YAML loader for chunky_filling.yaml (maps + inline lists + scalars).
class_name ChunkyFillingConfig

static var _data: Dictionary = {}
static var _loaded: bool = false

static func get_config() -> Dictionary:
	if not _loaded:
		load_config("res://data/chunky_filling.yaml")
	return _data


static func load_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ChunkyFillingConfig: failed to open %s" % path)
		_data = {}
		_loaded = true
		return _data
	var text := file.get_as_text()
	file.close()
	_data = _parse_yaml(text)
	_loaded = true
	print("ChunkyFillingConfig: loaded %s" % path)
	return _data


static func layers() -> Dictionary:
	return get_config().get("layers", {})


static func ores() -> Dictionary:
	return get_config().get("ores", {})


static func inclusions() -> Dictionary:
	return get_config().get("inclusions", {})


static func caves() -> Dictionary:
	return get_config().get("caves", {})


static func _parse_yaml(text: String) -> Dictionary:
	var root: Dictionary = {}
	var stack: Array = [{"indent": -1, "container": root}]
	for raw in text.split("\n"):
		var line: String = raw
		var hash_i := line.find("#")
		if hash_i >= 0:
			line = line.substr(0, hash_i)
		if line.strip_edges().is_empty():
			continue
		var indent := 0
		while indent < line.length() and line[indent] == " ":
			indent += 1
		var content := line.substr(indent).strip_edges()
		while stack.size() > 1 and indent <= stack[stack.size() - 1]["indent"]:
			stack.pop_back()
		var parent: Dictionary = stack[stack.size() - 1]["container"]
		var colon := content.find(":")
		if colon < 0:
			continue
		var key := content.substr(0, colon).strip_edges()
		var rest := content.substr(colon + 1).strip_edges()
		if rest.is_empty():
			var child: Dictionary = {}
			parent[key] = child
			stack.append({"indent": indent, "container": child})
		else:
			parent[key] = _parse_scalar(rest)
	return root


static func _parse_scalar(s: String) -> Variant:
	if s.begins_with("[") and s.ends_with("]"):
		var inner := s.substr(1, s.length() - 2).strip_edges()
		var out: Array = []
		if inner.is_empty():
			return out
		for part in inner.split(","):
			out.append(_parse_scalar(part.strip_edges()))
		return out
	if s.begins_with("\"") and s.ends_with("\""):
		return s.substr(1, s.length() - 2)
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()
	return s
