extends SceneTree

const OUTPUT_DIRECTORY := "res://Docs/Baseline"
const MENU_OUTPUT := OUTPUT_DIRECTORY + "/main_menu.png"
const GAME_OUTPUT := OUTPUT_DIRECTORY + "/game_screen.png"
const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"
const CAPTURE_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	_capture_screens.call_deferred()


func _capture_screens() -> void:
	root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))

	var menu_scene := load("res://Scenes/Main/MainMenu.tscn") as PackedScene
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	await _wait_for_render()
	if not _save_viewport(MENU_OUTPUT):
		quit(1)
		return
	menu.queue_free()
	await process_frame

	if not _write_pending_session():
		quit(1)
		return
	var game_scene := load("res://Scenes/Main/Main.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	root.add_child(game)
	await _wait_for_render(6)
	if not _save_viewport(GAME_OUTPUT):
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("Baseline screenshots saved:")
	print(ProjectSettings.globalize_path(MENU_OUTPUT))
	print(ProjectSettings.globalize_path(GAME_OUTPUT))
	quit()


func _wait_for_render(frame_count := 3) -> void:
	for _frame in frame_count:
		await process_frame
	await RenderingServer.frame_post_draw


func _save_viewport(path: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture viewport: %s" % path)
		return false
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save screenshot: %s" % path)
		return false
	return true


func _write_pending_session() -> bool:
	var pending_file := FileAccess.open(PENDING_NEW_GAME_PATH, FileAccess.WRITE)
	if pending_file == null:
		push_error("Could not create baseline session")
		return false
	var pending_data := {
		"kingdom_name": "Контрольное королевство",
		"world_seed": 24680,
		"flag_pixels": _striped_pixels(16, 10, 6, 10),
		"emblem_pixels": _emblem_pixels(),
	}
	pending_file.store_string(JSON.stringify(pending_data))
	pending_file.flush()
	return pending_file.get_error() == OK


func _striped_pixels(width: int, height: int, top_color: int, bottom_color: int) -> Array:
	var pixels: Array = []
	for y in height:
		var row: Array = []
		for _x in width:
			row.append(top_color if y < height / 2 else bottom_color)
		pixels.append(row)
	return pixels


func _emblem_pixels() -> Array:
	var pixels: Array = []
	for y in 12:
		var row: Array = []
		for x in 12:
			var distance_from_center := absi(x - 5) + absi(y - 5)
			row.append(10 if distance_from_center <= 4 else 5)
		pixels.append(row)
	return pixels
