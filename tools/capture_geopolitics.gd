extends SceneTree

const OUTPUT := "res://Docs/Interface/geopolitics_1600x900.png"
const PENDING := "user://pending_new_game.json"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	var file := FileAccess.open(PENDING, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kingdom_name": "Контрольное королевство", "world_seed": 24680, "flag_pixels": _pixels(16, 10, 6), "emblem_pixels": _pixels(12, 12, 10)}))
	file.flush()
	var game := (load("res://Scenes/Main/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _frame in 10:
		await process_frame
	var panel := game.get_node("RelationsPanel") as RelationsPanel
	panel.open_panel()
	panel._on_state_selected(0)
	for _frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1600, 900):
		image.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Geopolitics screenshot saved" if error == OK else "Geopolitics screenshot failed")
	quit(0 if error == OK else 1)


func _pixels(width: int, height: int, color: int) -> Array:
	var result: Array = []
	for _y in height:
		var row: Array = []
		for _x in width:
			row.append(color)
		result.append(row)
	return result
