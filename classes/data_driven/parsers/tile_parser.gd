class_name TileParser

const BUILTIN_TILE_PATH := "res://data/tiles"
const CURRENT_FORMAT_VERSION := 1

static var parsing_started := false

static func run() -> void:
	if parsing_started:
		return
	parsing_started = true
	print()

	_load_path(BUILTIN_TILE_PATH)

static func _load_path(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		printerr("[TileParser] could not load BUILTIN_TILE_PATH='%s'. Error: %s" % [BUILTIN_TILE_PATH, DirAccess.get_open_error()])
	print("[TileParser] Reading path '%s'" % [path])
	
	for namespace_dirname in dir.get_directories():
		print("[TileParser]   Reading namespace '%s'" % [namespace_dirname])
		var namespace_path := path +"/"+ namespace_dirname
		var namespace_dir := DirAccess.open(namespace_path)
		for filename in namespace_dir.get_files():
			if !filename.ends_with(".yaml"):
				print("[TileParser]     Skipping file not ending in '.yaml' '%s/%s'" % [namespace_dirname, filename])
				continue
			var filepath := namespace_path +"/"+ filename
			_parse_file(filepath)
			
static func _parse_file(path: String) -> void:
	print("[TileParser]     Parsing '%s'" % [path])
	var data := Yaml.load_yaml(path)
	if data["format-version"] == null:
		print("[TileParser]       Could not find key 'format-version', is this file malformed?")
		return
	if data["format-version"] != CURRENT_FORMAT_VERSION:
		print("[TileParser]       Invalid format-version: %d, current format-version is %d" % [data["format-version"], CURRENT_FORMAT_VERSION])
		return
	
	var tile_dict: Dictionary = data["tiles"]
	if !tile_dict:
		print("[TileParser]       Could not find key 'tiles' this is not a DataTile definition file or it is malformed.")
		return
	
	var num_tiles := 0
	for tile_id in tile_dict:
		# print("Calling _parse_tile(%s, %s, %s)" % [path, tile_id, tile_dict[tile_id]])
		if _parse_tile(path, tile_id, tile_dict[tile_id]):
			num_tiles += 1

	print("[TileParser]       Parsed %d tiles." % [num_tiles])
	
static func _parse_tile(path:String, tile_id: String, tile_def: Dictionary) -> bool:
	# verify texture is included
	if !tile_def.has("texture"):
		print("[TileParser]         %s: Tile %s is missing texture." % [path,tile_id])
		return false

	var texture_dict: Dictionary = tile_def["texture"]
	# verify atlas exists and is a String
	# TODO: verify atlas exists.
	if !texture_dict.has("atlas"):
		print("[TileParser]         %s: Tile %s is missing texture atlas." % [path,tile_id])
		return false
	if typeof(texture_dict["atlas"]) != TYPE_STRING:
		print("[TileParser]         %s: Tile %s texture atlas must be a String." % [path,tile_id])
		return false
	
	# verify texture x exists and is int
	if !texture_dict.has("x"):
		print("[TileParser]         %s: Tile %s is missing texture x." % [path,tile_id])
		return false
	if typeof(texture_dict["x"]) != TYPE_INT:
		print("[TileParser]         %s: Tile %s texture x must be an int." % [path,tile_id])
		return false

	# verify texture y exists and is int
	if !texture_dict.has("y"): # use null check for int values because 0 is false
		print("[TileParser]         %s: Tile %s is missing texture y." % [path,tile_id])
		return false
	if typeof(texture_dict["y"]) != TYPE_INT:
		print("[TileParser]         %s: Tile %s texture y must be an int." % [path,tile_id])
		return false
	
	# parse texture
	var texture_atlas = texture_dict["atlas"]
	var texture_x: int = texture_dict["x"]
	var texture_y: int = texture_dict["y"]

	#TODO: replace this with proper atlas name handling in DataTexture
	match texture_atlas:
		"terrain.png":
			texture_atlas = 1
		"portal.png":
			texture_atlas = 2
		"underground.png":
			texture_atlas = 3

	# parse name option
	var name := tile_id # default to self
	if tile_def.has("name"): # check if key exists before accessing
		var name_def: String = tile_def["name"]
		name = name_def

	# parse drops option
	var drops := tile_id # default to self
	if tile_def.has("drops"): # check if key exists before accessing
		var drops_def: String = tile_def["drops"]

		if drops_def == "none":
			drops = ""
		elif drops_def.length() > 0:
			drops = drops_def
	
	# parse background option
	var background := tile_id # default to same tile
	if tile_def.has("background"): # check if key exists before accessing
		var bg_def: String = tile_def["background"]

		if bg_def == "none":
			background = "air"
		elif bg_def.length() >= 0:
			background = bg_def
	
	# parse interaction option
	var interaction := DataTile.INTERACTION.NONE # default to no interaction
	if tile_def.has("interaction"): # check if key exists before accessing
		var interact_def: String = tile_def["interaction"]

		if interact_def == "craft":
			interaction = DataTile.INTERACTION.CRAFT
	

	# parse interaction option
	var deco_layer := false # default to solid layer
	if tile_def.has("deco-layer"): # check if key exists before accessing
		var layer_def: String = str(tile_def["deco-layer"]) # explicit cast to string to safely handle invalid options

		if layer_def.to_lower() == "true":
			deco_layer = true

	# parse group option
	var group_list: PackedStringArray = [] # default to no groups
	if tile_def.has("groups"): # check if key exists before accessing
		var group_def = tile_def["groups"] # explicit cast to string to safely handle invalid options
		if typeof(group_def) == TYPE_ARRAY:
			group_list = PackedStringArray(group_def)
	
	print("[TileParser]       Parsed %-28s: name=%-28s, drops=%-28s, background=%-28s, interaction=%1s, deco-layer=%-5s, texture=%s(%d,%d), groups=%s" % [tile_id, name, drops, background, interaction, deco_layer, texture_atlas, texture_x, texture_y, group_list])
	
	var d_texture = DataTexture.new(tile_id, texture_atlas, Vector2i(texture_x, texture_y))
	Tiles.register(tile_id, d_texture, name, drops, background, interaction, deco_layer, group_list)

	return true
