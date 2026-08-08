extends CanvasLayer
class_name InternalEventPanel

signal panel_closed

const RESOURCE_DISPLAY_NAMES: Dictionary = {
	&"food": "еды",
	&"wood": "дерева",
	&"stone": "камня",
	&"gold": "золота",
}
const EFFECT_DISPLAY_NAMES: Dictionary = {
	&"food": "Еда",
	&"wood": "Дерево",
	&"stone": "Камень",
	&"gold": "Золото",
}
const RESOURCE_NAMES: Array[StringName] = [
	&"food", &"wood", &"stone", &"gold",
]

@onready var content: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer
@onready var title_label: Label = content.get_node("TitleLabel") as Label
@onready var date_label: Label = content.get_node("DateLabel") as Label
@onready var body_label: Label = content.get_node("BodyScroll/BodyLabel") as Label
@onready var choices_title_label: Label = content.get_node("ChoicesTitleLabel") as Label
@onready var choices_scroll: ScrollContainer = content.get_node("ChoicesScroll") as ScrollContainer
@onready var choices_container: VBoxContainer = choices_scroll.get_node("ChoicesContainer") as VBoxContainer
@onready var status_label: Label = content.get_node("StatusLabel") as Label
@onready var result_container: PanelContainer = content.get_node("ResultContainer") as PanelContainer
@onready var result_content: VBoxContainer = result_container.get_node("VBoxContainer") as VBoxContainer
@onready var result_text_label: Label = result_content.get_node("ResultTextLabel") as Label
@onready var applied_effects_label: Label = result_content.get_node("AppliedEffectsLabel") as Label
@onready var continue_button: Button = result_content.get_node("ContinueButton") as Button
@onready var event_manager: EventManager = $"../EventManager" as EventManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _current_event: Dictionary = {}
var _choice_buttons: Dictionary = {}
var _showing_result := false


func _ready() -> void:
	continue_button.pressed.connect(close_result)
	event_manager.internal_event_ready.connect(_on_internal_event_ready)
	event_manager.internal_event_resolved.connect(_on_internal_event_resolved)
	event_manager.internal_event_failed.connect(_on_internal_event_failed)
	resource_manager.resources_changed.connect(_on_resources_changed)
	result_container.visible = false


func open_event(event: Dictionary) -> void:
	if event.is_empty():
		return
	_current_event = event.duplicate(true)
	_showing_result = false
	visible = true
	title_label.text = String(_current_event.get("title", "Внутреннее событие"))
	date_label.text = "Дата: День %d, Месяц %d, Год %d" % [
		int(_current_event.get("created_day", 0)),
		int(_current_event.get("created_month", 0)),
		int(_current_event.get("created_year", 0)),
	]
	body_label.text = String(_current_event.get("body", ""))
	status_label.text = ""
	choices_title_label.visible = true
	choices_scroll.visible = true
	result_container.visible = false
	_rebuild_choices()


func close_result() -> void:
	if event_manager.has_active_event() or not _showing_result:
		return
	visible = false
	_showing_result = false
	_current_event.clear()
	get_viewport().gui_release_focus()
	panel_closed.emit()


func hide_panel() -> void:
	var was_visible := visible
	visible = false
	_showing_result = false
	_current_event.clear()
	get_viewport().gui_release_focus()
	if was_visible:
		panel_closed.emit()


func is_showing_result() -> bool:
	return visible and _showing_result


func _on_internal_event_ready(event: Dictionary) -> void:
	open_event(event)


func _on_internal_event_resolved(result: Dictionary) -> void:
	_showing_result = true
	visible = true
	choices_title_label.visible = false
	choices_scroll.visible = false
	status_label.text = ""
	result_container.visible = true
	result_text_label.text = String(result.get("result_text", ""))
	applied_effects_label.text = _format_applied_effects(
		result.get("applied_effects", {})
	)


func _on_internal_event_failed(reason: String) -> void:
	if visible and not _showing_result:
		status_label.text = reason


func _on_resources_changed(
	_food: int,
	_wood: int,
	_stone: int,
	_gold: int
) -> void:
	if visible and not _showing_result:
		_update_choice_availability()


func _rebuild_choices() -> void:
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
	for choice_value in _current_event.get("choices", []):
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var choice_id: StringName = choice.get("choice_id", &"")
		var choice_panel := PanelContainer.new()
		var choice_content := VBoxContainer.new()
		choice_content.add_theme_constant_override("separation", 4)
		choice_panel.add_child(choice_content)

		var choice_title := Label.new()
		choice_title.text = String(choice.get("text", ""))
		choice_title.theme_type_variation = &"SectionTitleLabel"
		choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_content.add_child(choice_title)

		var description_label := Label.new()
		description_label.text = String(choice.get("description", ""))
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_content.add_child(description_label)

		var requirements_label := Label.new()
		requirements_label.text = _format_requirements(choice)
		requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_content.add_child(requirements_label)

		var choice_button := Button.new()
		choice_button.text = "Выбрать"
		choice_button.pressed.connect(_on_choice_pressed.bind(choice_id))
		choice_content.add_child(choice_button)
		choices_container.add_child(choice_panel)
		_choice_buttons[choice_id] = choice_button
	_update_choice_availability()


func _update_choice_availability() -> void:
	for choice_id_value in _choice_buttons:
		var choice_id := StringName(choice_id_value)
		var button: Button = _choice_buttons[choice_id_value]
		var reason := event_manager.get_choice_failure_reason(choice_id)
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason


func _on_choice_pressed(choice_id: StringName) -> void:
	status_label.text = ""
	event_manager.resolve_choice(choice_id)


func _format_requirements(choice: Dictionary) -> String:
	var requirements: Dictionary = choice.get("requirements", {})
	var resources: Dictionary = requirements.get("resources", {})
	var parts: Array[String] = []
	for resource_name in RESOURCE_NAMES:
		var amount := int(resources.get(String(resource_name), 0))
		if amount > 0:
			parts.append("%d %s" % [
				amount,
				String(RESOURCE_DISPLAY_NAMES[resource_name]),
			])
	if parts.is_empty():
		return "Ресурсы не требуются"
	return "Требуется: %s" % ", ".join(PackedStringArray(parts))


func _format_applied_effects(applied_effects: Dictionary) -> String:
	var lines: Array[String] = []
	var resources: Dictionary = applied_effects.get("resources", {})
	for resource_name in RESOURCE_NAMES:
		var amount := int(resources.get(String(resource_name), 0))
		if amount != 0:
			lines.append("%s: %s" % [
				String(EFFECT_DISPLAY_NAMES[resource_name]),
				_format_signed(amount),
			])
	var stability_change := int(applied_effects.get("stability", 0))
	if stability_change != 0:
		lines.append("Стабильность: %s" % _format_signed(stability_change))
	var loyalty_change := int(applied_effects.get("loyalty_all", 0))
	if loyalty_change != 0:
		lines.append("Верность жителей: %s" % _format_signed(loyalty_change))
	if lines.is_empty():
		return "Состояние государства не изменилось."
	return "\n".join(PackedStringArray(lines))


func _format_signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
