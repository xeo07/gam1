extends CanvasLayer
class_name SideMenu

const PREFERRED_MENU_WIDTH := 280.0
const EDGE_MARGIN := 10.0
const TOP_MARGIN := 70.0

signal save_pressed
signal load_pressed
signal settings_pressed
signal main_menu_pressed
signal exit_pressed

@onready var click_blocker: ColorRect = $ClickBlocker
@onready var menu_anchor: Control = $MenuAnchor
@onready var menu_panel: PanelContainer = $MenuAnchor/PanelContainer
@onready var menu_margin: MarginContainer = $MenuAnchor/PanelContainer/MarginContainer
@onready var system_buttons: VBoxContainer = $MenuAnchor/PanelContainer/MarginContainer/VBoxContainer
@onready var save_button: Button = system_buttons.get_node("SaveButton") as Button
@onready var load_button: Button = system_buttons.get_node("LoadButton") as Button
@onready var settings_button: Button = system_buttons.get_node("SettingsButton") as Button
@onready var main_menu_button: Button = system_buttons.get_node("MainMenuButton") as Button
@onready var exit_button: Button = system_buttons.get_node("ExitButton") as Button
@onready var close_button: Button = system_buttons.get_node("CloseButton") as Button

var _bottom_hud_height := 195.0


func _ready() -> void:
	click_blocker.gui_input.connect(_on_click_blocker_gui_input)
	save_button.pressed.connect(func() -> void: _emit_and_close(save_pressed))
	load_button.pressed.connect(func() -> void: _emit_and_close(load_pressed))
	settings_button.pressed.connect(func() -> void: _emit_and_close(settings_pressed))
	main_menu_button.pressed.connect(func() -> void: _emit_and_close(main_menu_pressed))
	exit_button.pressed.connect(func() -> void: _emit_and_close(exit_pressed))
	close_button.pressed.connect(close_menu)
	get_viewport().size_changed.connect(_queue_layout_update)
	_queue_layout_update()


func set_bottom_hud_height(height: float) -> void:
	_bottom_hud_height = maxf(height, 0.0)
	_queue_layout_update()


func open_menu() -> void:
	_update_layout()
	visible = true


func close_menu() -> void:
	visible = false


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func is_menu_open() -> bool:
	return visible


func _queue_layout_update() -> void:
	_update_layout.call_deferred()


func _update_layout() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var available_height := maxf(viewport_size.y - _bottom_hud_height, 1.0)
	_apply_compact_layout(available_height < 400.0)
	var menu_width := minf(PREFERRED_MENU_WIDTH, maxf(viewport_size.x - EDGE_MARGIN * 2.0, 1.0))
	var menu_height := menu_panel.get_combined_minimum_size().y
	menu_anchor.size = Vector2(menu_width, menu_height)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_anchor.position = Vector2(EDGE_MARGIN, minf(TOP_MARGIN, maxf(available_height - menu_anchor.size.y, EDGE_MARGIN)))


func _apply_compact_layout(compact: bool) -> void:
	var button_height := 32.0 if compact else 44.0
	var separation := 2 if compact else 8
	var margin := 6 if compact else 14
	system_buttons.add_theme_constant_override("separation", separation)
	for button in [save_button, load_button, settings_button, main_menu_button, exit_button, close_button]:
		button.custom_minimum_size.y = button_height
	menu_margin.add_theme_constant_override("margin_left", margin)
	menu_margin.add_theme_constant_override("margin_top", margin)
	menu_margin.add_theme_constant_override("margin_right", margin)
	menu_margin.add_theme_constant_override("margin_bottom", margin)


func _on_click_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			close_menu()
			click_blocker.accept_event()


func _emit_and_close(action_signal: Signal) -> void:
	action_signal.emit()
	close_menu()
