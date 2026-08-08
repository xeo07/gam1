extends CanvasLayer
class_name WarPanel

const STATUS_DISPLAY_NAMES: Dictionary = {
	&"neutral": "Нейтральный",
	&"ally": "Союзник",
	&"enemy": "Враг",
	&"war": "В состоянии войны",
}

@onready var state_option_button: OptionButton = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StateOptionButton
@onready var state_status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StateStatusLabel
@onready var relation_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RelationLabel
@onready var enemy_strength_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/EnemyStrengthLabel
@onready var declare_war_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DeclareWarButton
@onready var campaign_status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CampaignStatusLabel
@onready var soldiers_list: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SoldiersScrollContainer/SoldiersList
@onready var selected_strength_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SelectedStrengthLabel
@onready var start_campaign_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StartCampaignButton
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var war_manager: WarManager = $"../WarManager" as WarManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var _state_ids: Array[StringName] = []
var _selected_state_id: StringName = &""
var _selected_citizen_ids: Array[int] = []


func _ready() -> void:
	state_option_button.item_selected.connect(_on_state_selected)
	declare_war_button.pressed.connect(_on_declare_war_pressed)
	start_campaign_button.pressed.connect(_on_start_campaign_pressed)
	close_button.pressed.connect(close_panel)
	war_manager.war_declared.connect(_on_war_declared)
	war_manager.campaign_started.connect(_on_campaign_started)
	war_manager.campaign_completed.connect(_on_campaign_completed)
	war_manager.war_action_failed.connect(_on_war_action_failed)
	war_manager.war_state_changed.connect(_on_war_state_changed)
	army_manager.army_changed.connect(_on_army_changed)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.citizen_updated.connect(_on_citizen_updated)
	world_manager.states_changed.connect(_on_states_changed)
	time_manager.day_changed.connect(_on_time_changed)
	time_manager.time_loaded.connect(_on_time_changed)


func open_panel() -> void:
	visible = true
	status_label.text = ""
	refresh_panel()


func close_panel() -> void:
	visible = false


func refresh_panel() -> void:
	_populate_states()
	_rebuild_soldiers()
	_update_state_details()
	_update_campaign_status()
	_update_selected_strength()
	_update_buttons()


func _populate_states() -> void:
	var states := world_manager.get_all_observed_states()
	state_option_button.clear()
	_state_ids.clear()
	for state in states:
		var state_id: StringName = state.get("id", &"")
		_state_ids.append(state_id)
		state_option_button.add_item(String(state.get("name", "")))
	if _state_ids.is_empty():
		_selected_state_id = &""
		return
	var selected_index := _state_ids.find(_selected_state_id)
	if selected_index == -1:
		selected_index = 0
		_selected_state_id = _state_ids[0]
	state_option_button.select(selected_index)


func _rebuild_soldiers() -> void:
	for child in soldiers_list.get_children():
		soldiers_list.remove_child(child)
		child.queue_free()
	var available_ids: Dictionary = {}
	for assignment in army_manager.get_all_assignments():
		var citizen_id := int(assignment["citizen_id"])
		var citizen := population_manager.get_citizen_by_id(citizen_id)
		if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
			continue
		var is_locked := war_manager.is_citizen_on_campaign(citizen_id)
		if not is_locked:
			available_ids[citizen_id] = true
		var checkbox := CheckBox.new()
		checkbox.text = _format_soldier(citizen, assignment)
		checkbox.disabled = is_locked
		checkbox.button_pressed = (
			citizen_id in _selected_citizen_ids and not is_locked
		)
		checkbox.toggled.connect(_on_soldier_toggled.bind(citizen_id))
		soldiers_list.add_child(checkbox)
	var preserved_ids: Array[int] = []
	for citizen_id in _selected_citizen_ids:
		if available_ids.has(citizen_id):
			preserved_ids.append(citizen_id)
	_selected_citizen_ids = preserved_ids
	if soldiers_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "Назначенных бойцов нет"
		soldiers_list.add_child(empty_label)


func _on_state_selected(index: int) -> void:
	if index < 0 or index >= _state_ids.size():
		return
	_selected_state_id = _state_ids[index]
	status_label.text = ""
	_update_state_details()
	_update_buttons()


func _on_soldier_toggled(pressed: bool, citizen_id: int) -> void:
	if pressed:
		if citizen_id not in _selected_citizen_ids:
			_selected_citizen_ids.append(citizen_id)
	else:
		_selected_citizen_ids.erase(citizen_id)
	_update_selected_strength()
	_update_buttons()


func _on_declare_war_pressed() -> void:
	if _selected_state_id == &"":
		return
	if war_manager.declare_war(_selected_state_id):
		status_label.text = "Война объявлена."
		refresh_panel()


func _on_start_campaign_pressed() -> void:
	if _selected_state_id == &"":
		return
	var selected_ids := _get_selected_ids()
	if war_manager.start_campaign(_selected_state_id, selected_ids):
		_selected_citizen_ids.clear()
		status_label.text = "Войско отправлено. Возвращение через 4 дня."
		refresh_panel()


func _update_state_details() -> void:
	var state := world_manager.get_observed_state_by_id(_selected_state_id)
	if state.is_empty():
		state_status_label.text = ""
		relation_label.text = ""
		enemy_strength_label.text = ""
		return
	state_status_label.text = "Статус: %s\nСведения: %s, %s" % [
		String(state.get("status_text", "неизвестно")),
		String(state.get("source_text", "неизвестно")),
		String(state.get("freshness_text", "")),
	]
	relation_label.text = "Отношения: %s" % String(state.get("relation_text", "неизвестно"))
	enemy_strength_label.text = "Военная сила противника: %s" % String(state.get("military_text", "неизвестно"))


func _update_campaign_status() -> void:
	if not war_manager.has_active_campaign():
		campaign_status_label.text = "Активного похода нет"
		return
	var campaign := war_manager.get_active_campaign()
	var state := world_manager.get_observed_state_by_id(campaign.get("state_id", &""))
	campaign_status_label.text = "Поход против %s: осталось %d дн." % [
		String(state.get("name", "")),
		war_manager.get_campaign_days_remaining(),
	]


func _update_selected_strength() -> void:
	var total_strength := 0
	for citizen_id in _selected_citizen_ids:
		total_strength += army_manager.calculate_unit_strength(citizen_id)
	selected_strength_label.text = "Выбрано бойцов: %d | Сила похода: %d" % [
		_selected_citizen_ids.size(),
		total_strength,
	]


func _update_buttons() -> void:
	var declare_reason := war_manager.get_declare_war_failure_reason(_selected_state_id)
	declare_war_button.disabled = not declare_reason.is_empty()
	declare_war_button.tooltip_text = declare_reason
	var campaign_reason := war_manager.get_campaign_failure_reason(
		_selected_state_id,
		_get_selected_ids()
	)
	start_campaign_button.disabled = not campaign_reason.is_empty()
	start_campaign_button.tooltip_text = campaign_reason


func _format_soldier(citizen: Dictionary, assignment: Dictionary) -> String:
	var citizen_id := int(citizen["id"])
	var unit_type: StringName = assignment["unit_type"]
	var unit_name := army_manager.get_unit_display_name(unit_type)
	var equipment_text := ""
	if unit_type != &"militia":
		equipment_text = (
			" [экипирован]"
			if bool(assignment["equipped"])
			else " [без снаряжения]"
		)
	return "#%d %s — %s%s — сила %d" % [
		citizen_id,
		String(citizen["name"]),
		unit_name,
		equipment_text,
		army_manager.calculate_unit_strength(citizen_id),
	]


func _get_selected_ids() -> Array[int]:
	var selected_ids: Array[int] = []
	for citizen_id in _selected_citizen_ids:
		selected_ids.append(citizen_id)
	return selected_ids


func _on_war_declared(state_id: StringName) -> void:
	_selected_state_id = state_id
	if visible:
		refresh_panel()


func _on_campaign_started(_campaign: Dictionary) -> void:
	if visible:
		refresh_panel()


func _on_campaign_completed(_report: Dictionary) -> void:
	_selected_citizen_ids.clear()
	if visible:
		refresh_panel()


func _on_war_action_failed(reason: String) -> void:
	if visible:
		status_label.text = reason


func _on_war_state_changed() -> void:
	if visible:
		refresh_panel()


func _on_army_changed() -> void:
	if visible:
		refresh_panel()


func _on_population_changed(_population: int) -> void:
	if visible:
		refresh_panel()


func _on_citizen_updated(_citizen_id: int) -> void:
	if visible:
		refresh_panel()


func _on_states_changed() -> void:
	if visible:
		refresh_panel()


func _on_time_changed(_day: int, _month: int, _year: int) -> void:
	if visible:
		refresh_panel()
