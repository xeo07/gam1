extends CanvasLayer
class_name CornerMenuButton

signal menu_button_pressed

@onready var top_bar: PanelContainer = $TopBar
@onready var menu_button: Button = $TopBar/MarginContainer/HBoxContainer/MenuButton

var _bottom_hud_height := 195.0


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: menu_button_pressed.emit())
	get_viewport().size_changed.connect(_queue_position_update)
	_queue_position_update()


func set_bottom_hud_height(height: float) -> void:
	_bottom_hud_height = maxf(height, 0.0)
	_queue_position_update()


func set_interaction_enabled(enabled: bool) -> void:
	menu_button.disabled = not enabled
	menu_button.tooltip_text = (
		"Открыть меню"
		if enabled
		else "Сначала примите решение по текущему событию"
	)


func _queue_position_update() -> void:
	_update_position.call_deferred()


func _update_position() -> void:
	if not is_inside_tree():
		return
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(get_viewport().get_visible_rect().size.x, 60.0)
