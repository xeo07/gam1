extends Control
class_name MainMenu

const GAME_SCENE := "res://Scenes/Main/Main.tscn"
const SAVE_PATH := "user://kingdoom_save.json"
const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"
const PENDING_LOAD_PATH := "user://pending_load_game.flag"
const LAST_ERROR_PATH := "user://last_menu_error.txt"

@onready var continue_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/LoadGameButton
@onready var settings_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/CreditsButton
@onready var exit_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ExitButton
@onready var main_status_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

@onready var new_game_dialog: Control = $NewGameDialog
@onready var new_game_content: VBoxContainer = $NewGameDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer
@onready var new_game_panel: PanelContainer = $NewGameDialog/Overlay/CenterContainer/PanelContainer
@onready var kingdom_name_line_edit: LineEdit = new_game_content.get_node("BasicSettingsGrid/KingdomNameLineEdit") as LineEdit
@onready var seed_line_edit: LineEdit = new_game_content.get_node("BasicSettingsGrid/SeedContainer/SeedLineEdit") as LineEdit
@onready var random_seed_button: Button = new_game_content.get_node("BasicSettingsGrid/SeedContainer/RandomSeedButton") as Button
@onready var identity_tabs: TabContainer = new_game_content.get_node("SymbolTabs") as TabContainer
@onready var flag_editor: PixelArtEditor = new_game_content.get_node("SymbolTabs/FlagTab/EditorViewport/ScrollContainer/FlagPixelArtEditor") as PixelArtEditor
@onready var emblem_editor: PixelArtEditor = new_game_content.get_node("SymbolTabs/EmblemTab/EditorViewport/ScrollContainer/EmblemPixelArtEditor") as PixelArtEditor
@onready var start_game_button: Button = new_game_content.get_node("BottomButtons/StartGameButton") as Button
@onready var new_game_cancel_button: Button = new_game_content.get_node("BottomButtons/CancelButton") as Button
@onready var new_game_status_label: Label = $NewGameDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

@onready var load_dialog: Control = $LoadDialog
@onready var save_info_label: Label = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveInfoLabel
@onready var load_button: Button = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LoadButton
@onready var delete_button: Button = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DeleteButton
@onready var load_cancel_button: Button = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CancelButton
@onready var load_status_label: Label = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var flag_preview_texture_rect: TextureRect = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/IdentityPreviewContainer/FlagPreviewTextureRect
@onready var emblem_preview_texture_rect: TextureRect = $LoadDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/IdentityPreviewContainer/EmblemPreviewTextureRect

@onready var settings_dialog: SettingsDialog = $SettingsDialog as SettingsDialog
@onready var credits_dialog: Control = $CreditsDialog
@onready var credits_close_button: Button = $CreditsDialog/Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var overwrite_confirmation: ConfirmationDialog = $OverwriteConfirmation
@onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation

var _seed_rng := RandomNumberGenerator.new()
var _pending_kingdom_name := ""
var _pending_world_seed := 0
var _pending_flag_pixels: Array = []
var _pending_emblem_pixels: Array = []
var _flag_generation_index := 0
var _emblem_generation_index := 0


func _ready() -> void:
	SettingsDialog.apply_saved_settings()
	_seed_rng.randomize()
	continue_button.pressed.connect(_request_load)
	new_game_button.pressed.connect(_open_new_game_dialog)
	load_game_button.pressed.connect(_open_load_dialog)
	settings_button.pressed.connect(settings_dialog.open_dialog)
	credits_button.pressed.connect(_open_credits_dialog)
	exit_button.pressed.connect(_on_exit_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	seed_line_edit.text_changed.connect(_on_seed_text_changed)
	flag_editor.random_requested.connect(_on_random_flag_requested)
	emblem_editor.random_requested.connect(_on_random_emblem_requested)
	start_game_button.pressed.connect(_on_start_game_pressed)
	new_game_cancel_button.pressed.connect(_close_new_game_dialog)
	load_button.pressed.connect(_request_load)
	delete_button.pressed.connect(_request_delete_save)
	load_cancel_button.pressed.connect(_close_load_dialog)
	credits_close_button.pressed.connect(_close_credits_dialog)
	overwrite_confirmation.confirmed.connect(_start_pending_new_game)
	delete_confirmation.confirmed.connect(_delete_save)
	flag_editor.configure("Флаг", 16, 10, "Случайный флаг")
	emblem_editor.configure("Герб", 12, 12, "Случайный герб")
	identity_tabs.set_tab_title(0, "Флаг")
	identity_tabs.set_tab_title(1, "Герб")
	get_viewport().size_changed.connect(_update_new_game_dialog_layout)
	_update_new_game_dialog_layout.call_deferred()
	_update_save_buttons()
	_show_last_error()


func _open_new_game_dialog() -> void:
	kingdom_name_line_edit.text = "Моё королевство"
	seed_line_edit.text = str(_generate_seed())
	_flag_generation_index = 0
	_emblem_generation_index = 0
	new_game_status_label.text = ""
	_generate_flag()
	_generate_emblem()
	identity_tabs.current_tab = 0
	_update_new_game_dialog_layout()
	new_game_dialog.visible = true
	kingdom_name_line_edit.grab_focus()


func _close_new_game_dialog() -> void:
	new_game_dialog.visible = false


func _on_random_seed_pressed() -> void:
	seed_line_edit.text = str(_generate_seed())
	_flag_generation_index = 0
	_emblem_generation_index = 0


func _on_seed_text_changed(_new_text: String) -> void:
	_flag_generation_index = 0
	_emblem_generation_index = 0


func _on_random_flag_requested() -> void:
	_generate_flag()


func _on_random_emblem_requested() -> void:
	_generate_emblem()


func _on_start_game_pressed() -> void:
	var normalized_name := kingdom_name_line_edit.text.strip_edges()
	if normalized_name.length() < 2:
		new_game_status_label.text = "Введите название государства"
		return
	if normalized_name.length() > 24:
		new_game_status_label.text = "Название государства слишком длинное"
		return
	var seed_text := seed_line_edit.text.strip_edges()
	if not seed_text.is_empty() and not seed_text.is_valid_int():
		new_game_status_label.text = "Seed должен быть целым числом"
		return
	_pending_kingdom_name = normalized_name
	_pending_world_seed = int(seed_text) if not seed_text.is_empty() else _generate_seed()
	_pending_flag_pixels = flag_editor.get_pixels()
	_pending_emblem_pixels = emblem_editor.get_pixels()
	if not PixelArtEditor.is_pixel_data_valid(_pending_flag_pixels, 16, 10):
		new_game_status_label.text = "Некорректные данные флага"
		return
	if not PixelArtEditor.is_pixel_data_valid(_pending_emblem_pixels, 12, 12):
		new_game_status_label.text = "Некорректные данные герба"
		return
	if FileAccess.file_exists(SAVE_PATH):
		overwrite_confirmation.dialog_text = (
			"Начало новой игры удалит текущее сохранение. Продолжить?"
		)
		overwrite_confirmation.popup_centered()
		return
	_start_pending_new_game()


func _start_pending_new_game() -> void:
	_remove_file(PENDING_LOAD_PATH)
	if FileAccess.file_exists(SAVE_PATH) and not _remove_file(SAVE_PATH):
		new_game_status_label.text = "Не удалось удалить текущее сохранение"
		return
	var pending_file := FileAccess.open(PENDING_NEW_GAME_PATH, FileAccess.WRITE)
	if pending_file == null:
		new_game_status_label.text = "Не удалось подготовить новую игру"
		return
	var pending_data := {
		"kingdom_name": _pending_kingdom_name,
		"world_seed": _pending_world_seed,
		"flag_pixels": PixelArtEditor.duplicate_pixels(_pending_flag_pixels),
		"emblem_pixels": PixelArtEditor.duplicate_pixels(_pending_emblem_pixels),
		"show_tutorial": true,
	}
	pending_file.store_string(JSON.stringify(pending_data, "\t"))
	pending_file.flush()
	if pending_file.get_error() != OK:
		new_game_status_label.text = "Не удалось подготовить новую игру"
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _request_load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_update_save_buttons()
		return
	_remove_file(PENDING_NEW_GAME_PATH)
	var pending_file := FileAccess.open(PENDING_LOAD_PATH, FileAccess.WRITE)
	if pending_file == null:
		main_status_label.text = "Не удалось подготовить загрузку"
		return
	pending_file.store_string("load")
	pending_file.flush()
	if pending_file.get_error() != OK:
		main_status_label.text = "Не удалось подготовить загрузку"
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _open_load_dialog() -> void:
	load_status_label.text = ""
	load_dialog.visible = true
	_refresh_save_info()


func _close_load_dialog() -> void:
	load_dialog.visible = false


func _refresh_save_info() -> void:
	var info := _read_save_info()
	if not bool(info.get("valid", false)):
		save_info_label.text = "Сохранение повреждено"
		flag_preview_texture_rect.texture = null
		emblem_preview_texture_rect.texture = null
		load_button.disabled = true
		delete_button.disabled = not FileAccess.file_exists(SAVE_PATH)
		return
	save_info_label.text = (
		"Государство: %s\n"
		+ "Дата: День %d, Месяц %d, Год %d\n"
		+ "Жителей: %d\n"
		+ "Зданий: %d\n"
		+ "Seed: %d"
	) % [
		info["kingdom_name"],
		info["day"],
		info["month"],
		info["year"],
		info["population"],
		info["buildings"],
		info["world_seed"],
	]
	load_button.disabled = false
	delete_button.disabled = false
	flag_preview_texture_rect.texture = info["flag_texture"]
	emblem_preview_texture_rect.texture = info["emblem_texture"]


func _read_save_info() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"valid": false}
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return {"valid": false}
	var json := JSON.new()
	if json.parse(save_file.get_as_text()) != OK or not json.data is Dictionary:
		return {"valid": false}
	var data: Dictionary = json.data
	if not _is_integer_value(data.get("save_version", null)):
		return {"valid": false}
	if int(data["save_version"]) != 1:
		return {"valid": false}
	for section in ["session", "time", "population", "buildings"]:
		if not data.has(section) or not data[section] is Dictionary:
			return {"valid": false}
	var session: Dictionary = data["session"]
	var time: Dictionary = data["time"]
	var population: Dictionary = data["population"]
	var buildings: Dictionary = data["buildings"]
	if not session.get("kingdom_name", null) is String:
		return {"valid": false}
	if not session.get("flag_pixels", null) is Array:
		return {"valid": false}
	if not session.get("emblem_pixels", null) is Array:
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(session["flag_pixels"], 16, 10):
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(session["emblem_pixels"], 12, 12):
		return {"valid": false}
	var saved_name := String(session["kingdom_name"]).strip_edges()
	if saved_name.length() < 2 or saved_name.length() > 24:
		return {"valid": false}
	for value in [
		session.get("world_seed", null),
		session.get("rng_state", null),
		time.get("day", null),
		time.get("month", null),
		time.get("year", null),
	]:
		if not _is_integer_value(value):
			return {"valid": false}
	if not population.get("citizens", null) is Array:
		return {"valid": false}
	if not buildings.get("buildings", null) is Array:
		return {"valid": false}
	if int(time["day"]) < 1 or int(time["day"]) > 30:
		return {"valid": false}
	if int(time["month"]) < 1 or int(time["month"]) > 12:
		return {"valid": false}
	if int(time["year"]) < 1:
		return {"valid": false}
	return {
		"valid": true,
		"kingdom_name": saved_name,
		"world_seed": int(session["world_seed"]),
		"day": int(time["day"]),
		"month": int(time["month"]),
		"year": int(time["year"]),
		"population": population["citizens"].size(),
		"buildings": buildings["buildings"].size(),
		"flag_texture": PixelArtEditor.create_texture_from_pixels(session["flag_pixels"]),
		"emblem_texture": PixelArtEditor.create_texture_from_pixels(session["emblem_pixels"]),
	}


func _request_delete_save() -> void:
	delete_confirmation.dialog_text = "Удалить текущее сохранение?"
	delete_confirmation.popup_centered()


func _delete_save() -> void:
	if not _remove_file(SAVE_PATH):
		load_status_label.text = "Не удалось удалить сохранение"
		return
	load_status_label.text = "Сохранение удалено"
	save_info_label.text = "Сохранения нет"
	load_button.disabled = true
	delete_button.disabled = true
	_update_save_buttons()


func _open_credits_dialog() -> void:
	credits_dialog.visible = true


func _close_credits_dialog() -> void:
	credits_dialog.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()


func _update_save_buttons() -> void:
	var has_save := FileAccess.file_exists(SAVE_PATH)
	continue_button.disabled = not has_save
	load_game_button.disabled = not has_save


func _show_last_error() -> void:
	if not FileAccess.file_exists(LAST_ERROR_PATH):
		return
	var error_file := FileAccess.open(LAST_ERROR_PATH, FileAccess.READ)
	if error_file != null:
		main_status_label.text = error_file.get_as_text().strip_edges()
	_remove_file(LAST_ERROR_PATH)


func _generate_seed() -> int:
	return _seed_rng.randi_range(1, 2147483647)


func _generate_flag() -> void:
	var flag_rng := RandomNumberGenerator.new()
	flag_rng.seed = _get_symbol_seed() + 1001 + _flag_generation_index
	_flag_generation_index += 1
	flag_editor.set_pixels(GameSessionManager.generate_default_flag(flag_rng))


func _generate_emblem() -> void:
	var emblem_rng := RandomNumberGenerator.new()
	emblem_rng.seed = _get_symbol_seed() + 2002 + _emblem_generation_index
	_emblem_generation_index += 1
	emblem_editor.set_pixels(GameSessionManager.generate_default_emblem(emblem_rng))


func _get_symbol_seed() -> int:
	var seed_text := seed_line_edit.text.strip_edges()
	return int(seed_text) if seed_text.is_valid_int() else _generate_seed()


func _update_new_game_dialog_layout() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	new_game_panel.custom_minimum_size.x = minf(900.0, maxf(viewport_size.x - 32.0, 760.0))
	identity_tabs.custom_minimum_size.y = clampf(viewport_size.y - 270.0, 235.0, 500.0)


func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
