extends CanvasLayer
class_name SaveLoadPanel

@onready var save_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveButton
@onready var load_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LoadButton
@onready var delete_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DeleteButton
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var save_manager: SaveManager = $"../SaveManager" as SaveManager


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(close_panel)
	save_manager.game_saved.connect(_on_game_saved)
	save_manager.game_loaded.connect(_on_game_loaded)
	save_manager.save_failed.connect(_on_operation_failed)
	save_manager.load_failed.connect(_on_operation_failed)
	_update_file_buttons()


func open_panel() -> void:
	visible = true
	status_label.text = ""
	_update_file_buttons()


func close_panel() -> void:
	visible = false


func _on_save_pressed() -> void:
	save_manager.save_game()


func _on_load_pressed() -> void:
	save_manager.load_game()


func _on_delete_pressed() -> void:
	if save_manager.delete_save():
		status_label.text = "Сохранение удалено"
		_update_file_buttons()


func _on_game_saved() -> void:
	status_label.text = "Игра сохранена"
	_update_file_buttons()


func _on_game_loaded() -> void:
	status_label.text = "Игра загружена"
	_update_file_buttons()


func _on_operation_failed(reason: String) -> void:
	status_label.text = reason
	_update_file_buttons()


func _update_file_buttons() -> void:
	var save_exists := save_manager.has_save_file()
	load_button.disabled = not save_exists
	delete_button.disabled = not save_exists
