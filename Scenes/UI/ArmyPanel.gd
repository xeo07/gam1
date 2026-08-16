extends CanvasLayer
class_name ArmyPanel

@onready var content_root: VBoxContainer = $Overlay/GameAreaMargin/CenterContainer/PanelContainer/MarginContainer/VBoxContainer
@onready var summary_label: Label = content_root.get_node("Header/SummaryLabel") as Label
@onready var soldiers_list: ItemList = content_root.get_node("MainContent/MainSplit/CitizensColumn/SoldiersList") as ItemList
@onready var details_root: VBoxContainer = content_root.get_node("MainContent/MainSplit/DetailsPanel/DetailsMargin/VBoxContainer") as VBoxContainer
@onready var citizen_label: Label = details_root.get_node("CitizenLabel") as Label
@onready var current_unit_label: Label = details_root.get_node("CurrentUnitLabel") as Label
@onready var unit_type_option_button: OptionButton = details_root.get_node("UnitTypeOptionButton") as OptionButton
@onready var assign_button: Button = details_root.get_node("AssignButton") as Button
@onready var equipment_label: Label = details_root.get_node("EquipmentLabel") as Label
@onready var equip_button: Button = details_root.get_node("EquipmentButtons/EquipButton") as Button
@onready var unequip_button: Button = details_root.get_node("EquipmentButtons/UnequipButton") as Button
@onready var remove_button: Button = details_root.get_node("RemoveButton") as Button
@onready var strength_label: Label = details_root.get_node("StrengthLabel") as Label
@onready var status_label: Label = content_root.get_node("StatusLabel") as Label
@onready var close_button: Button = content_root.get_node("CloseButton") as Button
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var special_goods_manager: SpecialGoodsManager = $"../SpecialGoodsManager" as SpecialGoodsManager

var _soldier_ids: Array[int] = []
var _selected_citizen_id: int = -1


func _ready() -> void:
	soldiers_list.item_selected.connect(_on_soldier_selected)
	assign_button.pressed.connect(_on_assign_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	close_button.pressed.connect(close_panel)
	army_manager.army_changed.connect(_on_army_changed)
	army_manager.equipment_changed.connect(_on_equipment_changed)
	army_manager.unit_assignment_failed.connect(_on_assignment_failed)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.citizen_updated.connect(_on_citizen_updated)
	special_goods_manager.special_goods_changed.connect(_on_special_goods_changed)
	_populate_unit_types()
	_clear_details()
	_update_summary()


func open_panel() -> void:
	visible = true
	status_label.text = ""
	_populate_unit_types()
	refresh_soldiers()


func close_panel() -> void:
	visible = false


func refresh_soldiers() -> void:
	var soldiers := army_manager.get_soldier_citizens()
	soldiers_list.clear()
	_soldier_ids.clear()
	for soldier in soldiers:
		var citizen_id := int(soldier["id"])
		_soldier_ids.append(citizen_id)
		soldiers_list.add_item(_format_soldier(soldier))

	_update_summary()
	var selected_index := _soldier_ids.find(_selected_citizen_id)
	if selected_index == -1:
		_selected_citizen_id = -1
		if soldiers.is_empty():
			soldiers_list.add_item("Солдат нет")
			soldiers_list.set_item_disabled(0, true)
		_clear_details()
		return
	soldiers_list.select(selected_index)
	_show_details(_selected_citizen_id)


func _on_soldier_selected(index: int) -> void:
	if index < 0 or index >= _soldier_ids.size():
		return
	_selected_citizen_id = _soldier_ids[index]
	status_label.text = ""
	_show_details(_selected_citizen_id)


func _on_assign_pressed() -> void:
	if _selected_citizen_id == -1 or unit_type_option_button.selected == -1:
		return
	var unit_type: StringName = unit_type_option_button.get_item_metadata(
		unit_type_option_button.selected
	)
	if army_manager.assign_unit_type(_selected_citizen_id, unit_type):
		status_label.text = "Тип войск назначен"


func _on_equip_pressed() -> void:
	if _selected_citizen_id == -1:
		return
	if army_manager.equip_unit(_selected_citizen_id):
		status_label.text = "Боец экипирован"


func _on_unequip_pressed() -> void:
	if _selected_citizen_id == -1:
		return
	if army_manager.unequip_unit(_selected_citizen_id):
		status_label.text = "Экипировка снята"


func _on_remove_pressed() -> void:
	if _selected_citizen_id == -1:
		return
	if army_manager.remove_from_army(_selected_citizen_id):
		status_label.text = "Житель убран из армии"


func _on_army_changed() -> void:
	if visible:
		refresh_soldiers()
	else:
		_update_summary()


func _on_equipment_changed(
	citizen_id: int,
	_unit_type: StringName,
	_equipped: bool
) -> void:
	if visible and citizen_id == _selected_citizen_id:
		_show_details(citizen_id)


func _on_assignment_failed(citizen_id: int, reason: String) -> void:
	if visible and citizen_id == _selected_citizen_id:
		status_label.text = reason
		_update_buttons(army_manager.get_assignment(citizen_id))


func _on_population_changed(_total_population: int) -> void:
	if visible:
		refresh_soldiers()


func _on_citizen_updated(citizen_id: int) -> void:
	if not visible:
		return
	if citizen_id == _selected_citizen_id:
		var citizen := population_manager.get_citizen_by_id(citizen_id)
		if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
			_selected_citizen_id = -1
	refresh_soldiers()


func _on_special_goods_changed(_goods: Dictionary) -> void:
	if visible:
		_show_details(_selected_citizen_id)


func _show_details(citizen_id: int) -> void:
	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
		_selected_citizen_id = -1
		_clear_details()
		return

	citizen_label.text = "Житель: #%d %s" % [citizen_id, String(citizen["name"])]
	var assignment := army_manager.get_assignment(citizen_id)
	if assignment.is_empty():
		current_unit_label.text = "Тип войск: не назначен"
		equipment_label.text = "Снаряжение: отсутствует"
		strength_label.text = "Сила бойца: 0"
		_select_unit_type(&"militia")
	else:
		var unit_type: StringName = assignment["unit_type"]
		current_unit_label.text = "Тип войск: %s" % army_manager.get_unit_display_name(unit_type)
		equipment_label.text = _get_equipment_text(assignment)
		strength_label.text = "Сила бойца: %d" % army_manager.calculate_unit_strength(citizen_id)
		_select_unit_type(unit_type)
	_set_details_controls_visible(true)
	_update_buttons(assignment)


func _update_buttons(assignment: Dictionary) -> void:
	var has_selection := _selected_citizen_id != -1
	assign_button.disabled = not has_selection
	remove_button.disabled = not has_selection or assignment.is_empty()
	equip_button.disabled = true
	unequip_button.disabled = true
	equip_button.tooltip_text = ""

	if assignment.is_empty():
		equip_button.tooltip_text = "Сначала назначьте тип войск"
		return
	var unit_type: StringName = assignment["unit_type"]
	var equipped := bool(assignment["equipped"])
	if unit_type == &"militia":
		return
	unequip_button.disabled = not equipped
	if equipped:
		return

	var goods_id := &"northern_bows" if unit_type == &"archer" else &"iron_weapons"
	if special_goods_manager.has_goods(goods_id, 1):
		equip_button.disabled = false
	else:
		equip_button.tooltip_text = (
			"Недостаточно северных луков"
			if goods_id == &"northern_bows"
			else "Недостаточно железного оружия"
		)


func _populate_unit_types() -> void:
	unit_type_option_button.clear()
	for unit_type in army_manager.get_available_unit_types():
		var item_index := unit_type_option_button.item_count
		unit_type_option_button.add_item(army_manager.get_unit_display_name(unit_type))
		unit_type_option_button.set_item_metadata(item_index, unit_type)


func _select_unit_type(unit_type: StringName) -> void:
	for item_index in unit_type_option_button.item_count:
		if unit_type_option_button.get_item_metadata(item_index) == unit_type:
			unit_type_option_button.select(item_index)
			return


func _format_soldier(citizen: Dictionary) -> String:
	var citizen_id := int(citizen["id"])
	var assignment := army_manager.get_assignment(citizen_id)
	if assignment.is_empty():
		return "#%d %s — не назначен" % [citizen_id, String(citizen["name"])]
	var unit_name := army_manager.get_unit_display_name(assignment["unit_type"])
	var equipment_status := "экипирован" if bool(assignment["equipped"]) else "без снаряжения"
	return "#%d %s — %s [%s]" % [
		citizen_id,
		String(citizen["name"]),
		unit_name,
		equipment_status,
	]


func _get_equipment_text(assignment: Dictionary) -> String:
	var unit_type: StringName = assignment["unit_type"]
	if unit_type == &"militia":
		return "Снаряжение: не требуется"
	if not bool(assignment["equipped"]):
		return "Снаряжение: отсутствует"
	if unit_type == &"archer":
		return "Снаряжение: Северные луки"
	return "Снаряжение: Железное оружие"


func _update_summary() -> void:
	summary_label.text = "Солдат: %d | Сила армии: %d" % [
		army_manager.get_soldier_citizens().size(),
		army_manager.calculate_total_military_strength(),
	]


func _clear_details() -> void:
	citizen_label.text = "Выберите бойца в списке слева"
	current_unit_label.text = ""
	equipment_label.text = ""
	strength_label.text = ""
	assign_button.disabled = true
	equip_button.disabled = true
	unequip_button.disabled = true
	remove_button.disabled = true
	equip_button.tooltip_text = "Сначала назначьте тип войск"
	_set_details_controls_visible(false)


func _set_details_controls_visible(has_selection: bool) -> void:
	for control in [
		current_unit_label,
		strength_label,
		unit_type_option_button,
		assign_button,
		equipment_label,
		equip_button.get_parent(),
		remove_button,
	]:
		(control as Control).visible = has_selection
