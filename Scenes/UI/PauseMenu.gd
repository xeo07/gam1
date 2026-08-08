extends CanvasLayer
class_name PauseMenu

const MAIN_MENU_SCENE := "res://Scenes/Main/MainMenu.tscn"

@onready var content: VBoxContainer = $Overlay/CenterContainer/MedievalFrame/Content
@onready var resume_button: Button = content.get_node("ResumeButton") as Button
@onready var save_button: Button = content.get_node("SaveButton") as Button
@onready var load_button: Button = content.get_node("LoadButton") as Button
@onready var settings_button: Button = content.get_node("SettingsButton") as Button
@onready var main_menu_button: Button = content.get_node("MainMenuButton") as Button
@onready var exit_button: Button = content.get_node("ExitButton") as Button
@onready var status_label: Label = content.get_node("StatusLabel") as Label
@onready var settings_dialog: SettingsDialog = $SettingsDialog as SettingsDialog
@onready var main_menu_confirmation: ConfirmationDialog = $MainMenuConfirmation
@onready var exit_confirmation: ConfirmationDialog = $ExitConfirmation
@onready var save_manager: SaveManager = $"../SaveManager" as SaveManager
@onready var side_menu: SideMenu = $"../SideMenu" as SideMenu

var _operation_error := ""


func _ready() -> void:
	resume_button.pressed.connect(resume_game)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(settings_dialog.open_dialog)
	main_menu_button.pressed.connect(_request_main_menu)
	exit_button.pressed.connect(_request_exit)
	main_menu_confirmation.confirmed.connect(_return_to_main_menu)
	exit_confirmation.confirmed.connect(_exit_game)
	save_manager.save_failed.connect(_on_operation_failed)
	save_manager.load_failed.connect(_on_operation_failed)
	load_button.disabled = not save_manager.has_save_file()


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if settings_dialog.visible:
		settings_dialog.close_dialog()
		return
	resume_game()


func open_menu() -> void:
	side_menu.close_menu()
	status_label.text = ""
	load_button.disabled = not save_manager.has_save_file()
	visible = true
	get_tree().paused = true


func open_settings() -> void:
	open_menu()
	settings_dialog.open_dialog()


func request_main_menu() -> void:
	open_menu()
	_request_main_menu()


func request_exit() -> void:
	open_menu()
	_request_exit()


func resume_game() -> void:
	settings_dialog.close_dialog()
	get_tree().paused = false
	visible = false


func _on_save_pressed() -> void:
	_operation_error = ""
	status_label.text = (
		"Игра сохранена"
		if save_manager.save_game()
		else (_operation_error if not _operation_error.is_empty() else "Не удалось сохранить игру")
	)
	load_button.disabled = not save_manager.has_save_file()


func _on_load_pressed() -> void:
	_operation_error = ""
	if save_manager.load_game():
		status_label.text = "Игра загружена"
		resume_game()
	else:
		status_label.text = (
			_operation_error
			if not _operation_error.is_empty()
			else "Не удалось загрузить игру"
		)


func _on_operation_failed(reason: String) -> void:
	_operation_error = reason


func _request_main_menu() -> void:
	main_menu_confirmation.dialog_text = (
		"Вернуться в главное меню? Несохранённый прогресс будет потерян."
	)
	main_menu_confirmation.popup_centered()


func _request_exit() -> void:
	exit_confirmation.dialog_text = "Выйти из игры?"
	exit_confirmation.popup_centered()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
