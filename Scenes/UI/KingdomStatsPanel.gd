extends CanvasLayer
class_name KingdomStatsPanel

const CONTENT_PATH := "Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer"

@onready var content: VBoxContainer = get_node(CONTENT_PATH) as VBoxContainer
@onready var kingdom_name_label: Label = content.get_node("KingdomNameLabel") as Label
@onready var date_label: Label = content.get_node("DateLabel") as Label
@onready var stability_label: Label = content.get_node("StabilityLabel") as Label
@onready var internal_state_label: Label = content.get_node("InternalStateLabel") as Label
@onready var average_loyalty_label: Label = content.get_node("AverageLoyaltyLabel") as Label
@onready var population_label: Label = content.get_node("PopulationLabel") as Label
@onready var army_label: Label = content.get_node("ArmyLabel") as Label
@onready var buildings_label: Label = content.get_node("BuildingsLabel") as Label
@onready var territories_label: Label = content.get_node("TerritoriesLabel") as Label
@onready var production_label: Label = content.get_node("ProductionLabel") as Label
@onready var expenses_label: Label = content.get_node("ExpensesLabel") as Label
@onready var shortages_label: Label = content.get_node("ShortagesLabel") as Label
@onready var reasons_list: VBoxContainer = content.get_node(
	"ReasonsScrollContainer/ReasonsList"
) as VBoxContainer
@onready var close_button: Button = content.get_node("CloseButton") as Button

@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var economy_manager: EconomyManager = $"../EconomyManager" as EconomyManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager
@onready var territory_manager: TerritoryManager = $"../TerritoryManager" as TerritoryManager


func _ready() -> void:
	close_button.pressed.connect(close_panel)
	game_session_manager.kingdom_name_changed.connect(
		func(_name: String) -> void: _refresh_if_open()
	)
	game_session_manager.session_initialized.connect(_refresh_if_open)
	time_manager.day_changed.connect(
		func(_day: int, _month: int, _year: int) -> void: _refresh_if_open()
	)
	time_manager.time_loaded.connect(
		func(_day: int, _month: int, _year: int) -> void: _refresh_if_open()
	)
	stability_manager.stability_changed.connect(
		func(_value: int, _change: int, _reasons: Array[String]) -> void:
			_refresh_if_open()
	)
	stability_manager.internal_state_changed.connect(
		func(_state_id: StringName) -> void: _refresh_if_open()
	)
	stability_manager.stability_day_completed.connect(
		func(_data: Dictionary) -> void: _refresh_if_open()
	)
	economy_manager.daily_economy_completed.connect(
		func(_report: Dictionary) -> void: _refresh_if_open()
	)
	population_manager.population_changed.connect(
		func(_count: int) -> void: _refresh_if_open()
	)
	population_manager.population_capacity_changed.connect(
		func(_count: int, _capacity: int) -> void: _refresh_if_open()
	)
	population_manager.citizen_updated.connect(
		func(_citizen_id: int) -> void: _refresh_if_open()
	)
	army_manager.army_changed.connect(_refresh_if_open)
	building_manager.building_placed.connect(
		func(_building: Dictionary) -> void: _refresh_if_open()
	)
	building_manager.buildings_loaded.connect(_refresh_if_open)
	territory_manager.territories_changed.connect(_refresh_if_open)
	territory_manager.territory_reported.connect(func(_report: Dictionary) -> void: _refresh_if_open())


func open_panel() -> void:
	visible = true
	refresh_panel()


func close_panel() -> void:
	visible = false


func refresh_panel() -> void:
	kingdom_name_label.text = "Государство: %s" % game_session_manager.get_kingdom_name()
	date_label.text = "Дата: День %d, Месяц %d, Год %d" % [
		time_manager.day,
		time_manager.month,
		time_manager.year,
	]
	stability_label.text = "Стабильность: %d/100 (%s)" % [
		stability_manager.get_stability(),
		_format_change(stability_manager.get_last_stability_change()),
	]
	internal_state_label.text = (
		"Состояние: %s" % stability_manager.get_internal_state_name()
	)
	average_loyalty_label.text = (
		"Средняя верность: %.1f/10" % stability_manager.get_average_loyalty()
	)
	population_label.text = "Население: %d/%d" % [
		population_manager.get_population_count(),
		population_manager.get_population_capacity(),
	]
	army_label.text = "Армия: %d бойца, сила %d" % [
		army_manager.get_all_assignments().size(),
		army_manager.calculate_total_military_strength(),
	]
	buildings_label.text = (
		"Зданий: %d" % building_manager.get_all_buildings().size()
	)
	territories_label.text = territory_manager.get_summary()
	_update_economy_summary()
	_rebuild_reasons()


func _update_economy_summary() -> void:
	if not economy_manager.has_economy_report():
		production_label.text = "Экономический отчёт ещё не создан"
		expenses_label.visible = false
		shortages_label.visible = false
		return

	var report := economy_manager.get_last_economy_report()
	var production: Dictionary = report.get("production", {})
	var expenses: Dictionary = report.get("expenses", {})
	var shortages: Dictionary = report.get("shortages", {})
	production_label.text = _format_resources("Производство", production, "+")
	expenses_label.text = _format_resources("Расходы", expenses, "-")
	shortages_label.text = _format_shortages(shortages)
	expenses_label.visible = true
	shortages_label.visible = true


func _rebuild_reasons() -> void:
	for child in reasons_list.get_children():
		reasons_list.remove_child(child)
		child.queue_free()
	var reasons := stability_manager.get_last_change_reasons()
	if reasons.is_empty():
		reasons.append("Существенных изменений нет")
	for reason in reasons:
		var label := Label.new()
		label.text = "• %s" % reason
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reasons_list.add_child(label)


func _format_resources(title: String, values: Dictionary, prefix: String) -> String:
	return "%s: еда %s%d, дерево %s%d, камень %s%d, золото %s%d" % [
		title,
		prefix,
		int(values.get("food", 0)),
		prefix,
		int(values.get("wood", 0)),
		prefix,
		int(values.get("stone", 0)),
		prefix,
		int(values.get("gold", 0)),
	]


func _format_shortages(shortages: Dictionary) -> String:
	var entries: Array[String] = []
	for resource_name in ["food", "wood", "stone", "gold"]:
		var amount := int(shortages.get(resource_name, 0))
		if amount <= 0:
			continue
		var display_name := String({
			"food": "еда",
			"wood": "дерево",
			"stone": "камень",
			"gold": "золото",
		}.get(resource_name, resource_name))
		entries.append("%s %d" % [display_name, amount])
	if entries.is_empty():
		return "Дефициты: нет"
	return "Дефициты: %s" % ", ".join(PackedStringArray(entries))


func _format_change(change: int) -> String:
	return "+%d" % change if change > 0 else str(change)


func _refresh_if_open() -> void:
	if visible:
		refresh_panel()
