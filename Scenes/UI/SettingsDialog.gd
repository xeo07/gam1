extends Control
class_name SettingsDialog

const SETTINGS_PATH := "user://settings.json"
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var fullscreen_check_box: CheckBox = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var window_size_option_button: OptionButton = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WindowSizeOptionButton
@onready var ui_scale_slider: HSlider = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/UiScaleSlider
@onready var master_volume_slider: HSlider = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SfxVolumeSlider
@onready var apply_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ApplyButton
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	window_size_option_button.clear()
	for size in WINDOW_SIZES:
		window_size_option_button.add_item("%d × %d" % [size.x, size.y])
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(close_dialog)
	_load_controls_from_settings()


func open_dialog() -> void:
	_load_controls_from_settings()
	visible = true


func close_dialog() -> void:
	visible = false


func _on_apply_pressed() -> void:
	var size_index := window_size_option_button.selected
	if size_index < 0 or size_index >= WINDOW_SIZES.size():
		size_index = 0
	var selected_size := WINDOW_SIZES[size_index]
	var settings := {
		"fullscreen": fullscreen_check_box.button_pressed,
		"window_width": selected_size.x,
		"window_height": selected_size.y,
		"ui_scale": clampf(
			snappedf(float(ui_scale_slider.value), 0.1),
			0.8,
			1.4
		),
		"master_volume": clampf(float(master_volume_slider.value), 0.0, 1.0),
		"music_volume": clampf(float(music_volume_slider.value), 0.0, 1.0),
		"sfx_volume": clampf(float(sfx_volume_slider.value), 0.0, 1.0),
	}
	if _write_settings(settings):
		apply_settings(settings)


func _load_controls_from_settings() -> void:
	var settings := read_settings()
	fullscreen_check_box.button_pressed = bool(settings["fullscreen"])
	var saved_size := Vector2i(
		int(settings["window_width"]),
		int(settings["window_height"])
	)
	var size_index := WINDOW_SIZES.find(saved_size)
	window_size_option_button.select(maxi(size_index, 0))
	ui_scale_slider.value = float(settings["ui_scale"])
	master_volume_slider.value = float(settings["master_volume"])
	music_volume_slider.value = float(settings["music_volume"])
	sfx_volume_slider.value = float(settings["sfx_volume"])


static func apply_saved_settings() -> void:
	apply_settings(read_settings())


static func apply_settings(settings: Dictionary) -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return
	var window := scene_tree.root
	if window == null:
		return
	var audio_manager := scene_tree.root.get_node_or_null("AudioManager")
	if audio_manager != null:
		audio_manager.apply_volume_settings(settings)
	window.content_scale_factor = float(settings.get("ui_scale", 1.0))
	var fullscreen := bool(settings.get("fullscreen", false))
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = Vector2i(
			int(settings.get("window_width", 1280)),
			int(settings.get("window_height", 720))
		)


static func read_settings() -> Dictionary:
	var defaults := {
		"fullscreen": false,
		"window_width": 1280,
		"window_height": 720,
		"ui_scale": 1.0,
		"master_volume": 0.85,
		"music_volume": 0.65,
		"sfx_volume": 0.8,
	}
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults
	var settings_file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if settings_file == null:
		return defaults
	var json := JSON.new()
	if json.parse(settings_file.get_as_text()) != OK or not json.data is Dictionary:
		return defaults
	var data: Dictionary = json.data
	if not _is_valid_settings(data):
		return defaults
	return {
		"fullscreen": bool(data["fullscreen"]),
		"window_width": int(data["window_width"]),
		"window_height": int(data["window_height"]),
		"ui_scale": float(data["ui_scale"]),
		"master_volume": float(data.get("master_volume", defaults["master_volume"])),
		"music_volume": float(data.get("music_volume", defaults["music_volume"])),
		"sfx_volume": float(data.get("sfx_volume", defaults["sfx_volume"])),
	}


static func _write_settings(settings: Dictionary) -> bool:
	var settings_file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if settings_file == null:
		return false
	settings_file.store_string(JSON.stringify(settings, "\t"))
	settings_file.flush()
	return settings_file.get_error() == OK


static func _is_valid_settings(data: Dictionary) -> bool:
	if not data.has_all(["fullscreen", "window_width", "window_height", "ui_scale"]):
		return false
	if not data["fullscreen"] is bool:
		return false
	if not _is_integer_value(data["window_width"]):
		return false
	if not _is_integer_value(data["window_height"]):
		return false
	if not (data["ui_scale"] is int or data["ui_scale"] is float):
		return false
	var size := Vector2i(int(data["window_width"]), int(data["window_height"]))
	var scale := float(data["ui_scale"])
	if size not in WINDOW_SIZES or scale < 0.8 or scale > 1.4:
		return false
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		if not data.has(key):
			continue
		if not (data[key] is int or data[key] is float):
			return false
		var volume := float(data[key])
		if volume < 0.0 or volume > 1.0:
			return false
	return true


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
