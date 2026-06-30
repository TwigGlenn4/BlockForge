extends Label


func _process(_delta: float) -> void:
	if visible:
		text = _create_text()


func _create_text() -> String:

	var output: String = ""
	output += ProjectSettings.get_setting("application/config/name") + ": " + ProjectSettings.get_setting("application/config/version") + "\n"
	output += "Godot: " + Engine.get_version_info().string + "\n"
	output += "Renderer: " + ProjectSettings.get_setting("rendering/renderer/rendering_method") + "\n"
	# output += "GPU: " + RenderingServer.get_video_adapter_name() + "\n"
	var window_size: Vector2i = DisplayServer.window_get_size()
	output += "Viewport: " + str(window_size.x) + "x" + str(window_size.y) + "\n"
	output += "FPS: " + str(Engine.get_frames_per_second()) + "\n"

	return output
