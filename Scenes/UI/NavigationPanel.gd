extends CanvasLayer
class_name NavigationPanel

signal section_selected(section: StringName)

const SECTIONS: Array[StringName] = [
	&"overview", &"build", &"population", &"army", &"diplomacy",
	&"trade", &"espionage", &"events", &"world",
]

@onready var panel: PanelContainer = $Panel
@onready var buttons: VBoxContainer = $Panel/Margin/VBox/Buttons

var _selected: StringName = &"overview"


func _ready() -> void:
	for index in mini(SECTIONS.size(), buttons.get_child_count()):
		var button := buttons.get_child(index) as Button
		button.pressed.connect(_select.bind(SECTIONS[index]))
	set_selected(_selected)


func layout(rect: Rect2) -> void:
	panel.position = rect.position
	panel.size = rect.size


func set_selected(section: StringName) -> void:
	_selected = section
	for index in mini(SECTIONS.size(), buttons.get_child_count()):
		var button := buttons.get_child(index) as Button
		button.button_pressed = SECTIONS[index] == section


func _select(section: StringName) -> void:
	set_selected(section)
	section_selected.emit(section)
