extends SceneTree

const OUTPUT_DIRECTORY := "res://Docs/MainMenu"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var capture_size := _requested_size()
	root.size = capture_size
	var arguments := OS.get_cmdline_user_args()
	var requested_scale := 1.0
	if arguments.size() >= 4 and arguments[3].is_valid_float():
		requested_scale = clampf(float(arguments[3]), 0.8, 1.4)
		root.content_scale_factor = requested_scale
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var packed_scene := load("res://Scenes/Main/MainMenu.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load the main menu scene")
		quit(1)
		return
	var menu := packed_scene.instantiate()
	root.add_child(menu)
	for _frame in 8:
		await process_frame
	var state := "menu"
	if arguments.size() >= 3 and arguments[2] == "new_game":
		state = "new_game"
		menu.call("_open_new_game_dialog")
		if arguments.size() >= 4 and arguments[3] == "emblem":
			state = "new_game_emblem"
			var tabs := menu.get_node(
				"NewGameDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SymbolTabs"
			) as TabContainer
			tabs.current_tab = 1
		for _frame in 5:
			await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture the main menu")
		quit(1)
		return
	if image.get_size() != capture_size:
		image.resize(capture_size.x, capture_size.y, Image.INTERPOLATE_LANCZOS)
	var scale_suffix := "" if is_equal_approx(requested_scale, 1.0) else "_scale_%s" % str(requested_scale).replace(".", "_")
	var output_path := "%s/%s_%dx%d%s.png" % [OUTPUT_DIRECTORY, state, capture_size.x, capture_size.y, scale_suffix]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save the main menu screenshot")
		quit(1)
		return
	print("Main menu screenshot saved: %s" % ProjectSettings.globalize_path(output_path))
	quit()


func _requested_size() -> Vector2i:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() >= 2 and arguments[0].is_valid_int() and arguments[1].is_valid_int():
		return Vector2i(maxi(int(arguments[0]), 640), maxi(int(arguments[1]), 360))
	return Vector2i(1280, 720)
