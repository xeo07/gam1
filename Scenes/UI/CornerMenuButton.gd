extends CanvasLayer
class_name CornerMenuButton

signal menu_button_pressed

const RIGHT_MARGIN := 20.0
const BUTTON_SIZE := Vector2(52.0, 52.0)

@onready var menu_container: MarginContainer = $MarginContainer
@onready var menu_button: Button = $MarginContainer/MenuButton

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
	var viewport_size := get_viewport().get_visible_rect().size
	var actual_button_size := Vector2(
		maxf(BUTTON_SIZE.x, menu_button.get_combined_minimum_size().x),
		maxf(BUTTON_SIZE.y, menu_button.get_combined_minimum_size().y)
	)
	var available_height := maxf(viewport_size.y - _bottom_hud_height, actual_button_size.y)
	menu_container.position = Vector2(
		maxf(viewport_size.x - actual_button_size.x - RIGHT_MARGIN, 0.0),
		maxf((available_height - actual_button_size.y) * 0.5, 0.0)
	)
	menu_container.size = actual_button_size
