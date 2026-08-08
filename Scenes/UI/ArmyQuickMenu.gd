extends CanvasLayer
class_name ArmyQuickMenu

const HUD_HEIGHT := 195.0

signal army_pressed
signal war_pressed

@onready var click_blocker: Control = $ClickBlocker
@onready var popup_panel: PanelContainer = $PopupPanel
@onready var content: VBoxContainer = $PopupPanel/MarginContainer/VBoxContainer


func _ready() -> void:
	click_blocker.gui_input.connect(_on_click_outside)
	(content.get_node("ArmyButton") as Button).pressed.connect(
		func() -> void: _emit_and_close(army_pressed)
	)
	(content.get_node("WarButton") as Button).pressed.connect(
		func() -> void: _emit_and_close(war_pressed)
	)
	(content.get_node("CloseButton") as Button).pressed.connect(close_menu)
	get_viewport().size_changed.connect(_update_position)


func open_menu() -> void:
	_update_position()
	visible = true


func close_menu() -> void:
	visible = false


func is_menu_open() -> bool:
	return visible


func _update_position() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	popup_panel.position = Vector2(70.0, maxf(viewport_size.y - HUD_HEIGHT - popup_panel.size.y - 8.0, 8.0))


func _on_click_outside(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close_menu()
		click_blocker.accept_event()


func _emit_and_close(action_signal: Signal) -> void:
	action_signal.emit()
	close_menu()
