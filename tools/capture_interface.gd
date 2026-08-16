extends SceneTree

const OUTPUT_DIRECTORY := "res://Docs/Interface"
const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var capture_size := _requested_size()
	var capture_state := OS.get_environment("KINGDOOM_CAPTURE_STATE")
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
		if capture_state == "tutorial":
			var tutorial_panel := game.get_node("TutorialPanel") as TutorialPanel
			tutorial_panel.open_offer()
			tutorial_panel.call("_on_primary_pressed")
			for _frame in 2:
				await process_frame
		elif capture_state == "daily_report":
			var daily_report_panel := game.get_node("DailyReportPanel") as DailyReportPanel
			daily_report_panel.open_report(_daily_report_fixture())
			for _frame in 2:
				await process_frame
		elif capture_state == "trade":
			var trade_panel := game.get_node("TradePanel") as TradePanel
			trade_panel.open_panel()
			for _frame in 2:
				await process_frame
		elif capture_state == "internal_event":
			var event_manager := game.get_node("EventManager") as EventManager
			var internal_event_panel := game.get_node("InternalEventPanel") as InternalEventPanel
			var event := event_manager.create_event(&"public_petition")
			event_manager.active_event = event.duplicate(true)
			event_manager.has_active_event_flag = true
			internal_event_panel.open_event(event)
			for _frame in 2:
				await process_frame
		elif capture_state == "army":
			var army_panel := game.get_node("ArmyPanel") as ArmyPanel
			army_panel.open_panel()
			for _frame in 2:
				await process_frame
		elif capture_state == "war":
			var war_panel := game.get_node("WarPanel") as WarPanel
			war_panel.open_panel()
			for _frame in 2:
				await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var known_states := [
			"tutorial", "daily_report", "trade", "internal_event", "army", "war"
		]
		var output_name := capture_state if capture_state in known_states else "game"
		var path := "%s/%s_%dx%d.png" % [OUTPUT_DIRECTORY, output_name, capture_size.x, capture_size.y]
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


func _daily_report_fixture() -> Dictionary:
	return {
		"day": 2,
		"month": 1,
		"year": 1,
		"population": 3,
		"population_capacity": 4,
		"buildings_count": 0,
		"army_count": 0,
		"army_strength": 0,
		"economy": {
			"production": {"food": 0, "wood": 0, "stone": 0, "gold": 0},
			"expenses": {"food": 3, "wood": 0, "stone": 0, "gold": 0},
			"net": {"food": -3, "wood": 0, "stone": 0, "gold": 0},
			"shortages": {},
			"hunger_active": false,
			"gold_deficit_active": false,
		},
		"stability": {
			"stability": 70,
			"change": 0,
			"state_name": "Стабильно",
			"average_loyalty": 7.7,
			"reasons": ["Существенных изменений нет"],
		},
	}
