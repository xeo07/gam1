extends SceneTree

const OUTPUT_DIRECTORY := "res://Docs/Interface"
const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var capture_size := _requested_size()
	for _capture_index in 1:
		DisplayServer.window_set_size(capture_size)
		root.size = capture_size
		for _resize_frame in 4:
			await process_frame
		if not _write_pending_session():
			quit(1)
			return
		var scene := load("res://Scenes/Main/Main.tscn") as PackedScene
		var game := scene.instantiate()
		root.add_child(game)
		for _frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "%s/game_%dx%d.png" % [OUTPUT_DIRECTORY, capture_size.x, capture_size.y]
		if image != null and not image.is_empty() and image.get_size() != capture_size:
			image.resize(capture_size.x, capture_size.y, Image.INTERPOLATE_LANCZOS)
		if image == null or image.is_empty() or image.save_png(ProjectSettings.globalize_path(path)) != OK:
			push_error("Could not capture %s" % path)
			quit(1)
			return
		game.queue_free()
		await process_frame
	print("Interface screenshot saved for %dx%d" % [capture_size.x, capture_size.y])
	quit()


func _requested_size() -> Vector2i:
	var value := OS.get_environment("KINGDOOM_CAPTURE_SIZE")
	var parts := value.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1280, 720)


func _write_pending_session() -> bool:
	var file := FileAccess.open(PENDING_NEW_GAME_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"kingdom_name": "Контрольное королевство", "world_seed": 24680, "flag_pixels": _pixels(16, 10, 6), "emblem_pixels": _pixels(12, 12, 10), "show_tutorial": false}))
	file.flush()
	return file.get_error() == OK


func _pixels(width: int, height: int, color: int) -> Array:
	var result: Array = []
	for _y in height:
		var row: Array = []
		for _x in width:
			row.append(color)
		result.append(row)
	return result
