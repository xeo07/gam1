extends CanvasLayer
class_name DailyReportPanel

const CONTENT_PATH := "Overlay/CenterContainer/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer"

@onready var content: VBoxContainer = get_node(CONTENT_PATH) as VBoxContainer
@onready var date_label: Label = content.get_node("DateLabel") as Label
@onready var production_food_label: Label = content.get_node("ProductionFoodLabel") as Label
@onready var production_wood_label: Label = content.get_node("ProductionWoodLabel") as Label
@onready var production_stone_label: Label = content.get_node("ProductionStoneLabel") as Label
@onready var production_gold_label: Label = content.get_node("ProductionGoldLabel") as Label
@onready var expense_food_label: Label = content.get_node("ExpenseFoodLabel") as Label
@onready var expense_wood_label: Label = content.get_node("ExpenseWoodLabel") as Label
@onready var expense_stone_label: Label = content.get_node("ExpenseStoneLabel") as Label
@onready var expense_gold_label: Label = content.get_node("ExpenseGoldLabel") as Label
@onready var net_food_label: Label = content.get_node("NetFoodLabel") as Label
@onready var net_wood_label: Label = content.get_node("NetWoodLabel") as Label
@onready var net_stone_label: Label = content.get_node("NetStoneLabel") as Label
@onready var net_gold_label: Label = content.get_node("NetGoldLabel") as Label
@onready var shortage_label: Label = content.get_node("ShortageLabel") as Label
@onready var hunger_label: Label = content.get_node("HungerLabel") as Label
@onready var gold_deficit_label: Label = content.get_node("GoldDeficitLabel") as Label
@onready var stability_label: Label = content.get_node("StabilityLabel") as Label
@onready var internal_state_label: Label = content.get_node("InternalStateLabel") as Label
@onready var average_loyalty_label: Label = content.get_node("AverageLoyaltyLabel") as Label
@onready var stability_reasons_list: VBoxContainer = content.get_node("StabilityReasonsList") as VBoxContainer
@onready var population_label: Label = content.get_node("PopulationLabel") as Label
@onready var buildings_label: Label = content.get_node("BuildingsLabel") as Label
@onready var army_count_label: Label = content.get_node("ArmyCountLabel") as Label
@onready var army_strength_label: Label = content.get_node("ArmyStrengthLabel") as Label
@onready var close_button: Button = content.get_node("CloseButton") as Button
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager


func _ready() -> void:
	close_button.pressed.connect(close_report)
	news_manager.daily_report_ready.connect(_on_daily_report_ready)


func open_report(report: Dictionary) -> void:
	if (
		report.is_empty()
		or not report.get("economy", null) is Dictionary
		or not report.get("stability", null) is Dictionary
	):
		return

	var economy: Dictionary = report["economy"]
	var stability_data: Dictionary = report["stability"]
	var production: Dictionary = economy.get("production", {})
	var expenses: Dictionary = economy.get("expenses", {})
	var net: Dictionary = economy.get("net", {})
	var shortages: Dictionary = economy.get("shortages", {})
	date_label.text = "Дата: День %d, Месяц %d, Год %d" % [
		int(report.get("day", 0)),
		int(report.get("month", 0)),
		int(report.get("year", 0)),
	]
	_set_resource_labels(
		production,
		production_food_label,
		production_wood_label,
		production_stone_label,
		production_gold_label,
		"+"
	)
	_set_resource_labels(
		expenses,
		expense_food_label,
		expense_wood_label,
		expense_stone_label,
		expense_gold_label,
		"-"
	)
	net_food_label.text = "Еда: %s" % _format_signed(int(net.get("food", 0)))
	net_wood_label.text = "Дерево: %s" % _format_signed(int(net.get("wood", 0)))
	net_stone_label.text = "Камень: %s" % _format_signed(int(net.get("stone", 0)))
	net_gold_label.text = "Золото: %s" % _format_signed(int(net.get("gold", 0)))
	shortage_label.text = _format_shortages(shortages)
	hunger_label.text = (
		"Голод: да, верность жителей снизилась"
		if bool(economy.get("hunger_active", false))
		else "Голод: нет"
	)
	gold_deficit_label.text = "Дефицит золота: %s" % (
		"да" if bool(economy.get("gold_deficit_active", false)) else "нет"
	)
	stability_label.text = "Стабильность: %d (%s)" % [
		int(stability_data.get("stability", 0)),
		_format_signed(int(stability_data.get("change", 0))),
	]
	internal_state_label.text = (
		"Состояние: %s" % String(stability_data.get("state_name", ""))
	)
	average_loyalty_label.text = "Средняя верность: %.1f/10" % float(
		stability_data.get("average_loyalty", 0.0)
	)
	_rebuild_stability_reasons(stability_data.get("reasons", []))
	population_label.text = "Население: %d/%d" % [
		int(report.get("population", 0)),
		int(report.get("population_capacity", 0)),
	]
	buildings_label.text = "Зданий: %d" % int(report.get("buildings_count", 0))
	army_count_label.text = (
		"Назначенных бойцов: %d" % int(report.get("army_count", 0))
	)
	army_strength_label.text = (
		"Сила армии: %d" % int(report.get("army_strength", 0))
	)
	visible = true


func close_report() -> void:
	visible = false


func _set_resource_labels(
	values: Dictionary,
	food_target: Label,
	wood_target: Label,
	stone_target: Label,
	gold_target: Label,
	prefix: String
) -> void:
	food_target.text = "Еда: %s%d" % [prefix, int(values.get("food", 0))]
	wood_target.text = "Дерево: %s%d" % [prefix, int(values.get("wood", 0))]
	stone_target.text = "Камень: %s%d" % [prefix, int(values.get("stone", 0))]
	gold_target.text = "Золото: %s%d" % [prefix, int(values.get("gold", 0))]


func _format_signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	if value < 0:
		return str(value)
	return "0"


func _format_shortages(shortages: Dictionary) -> String:
	var entries: Array[String] = []
	for resource_name in ["food", "wood", "stone", "gold"]:
		var amount := int(shortages.get(resource_name, 0))
		if amount <= 0:
			continue
		var display_name: String
		match resource_name:
			"food":
				display_name = "еда"
			"wood":
				display_name = "дерево"
			"stone":
				display_name = "камень"
			_:
				display_name = "золото"
		entries.append("%s: %d" % [display_name, amount])
	if entries.is_empty():
		return "Дефицитов нет"
	return "Дефицит: %s" % ", ".join(PackedStringArray(entries))


func _rebuild_stability_reasons(reasons_value: Variant) -> void:
	for child in stability_reasons_list.get_children():
		stability_reasons_list.remove_child(child)
		child.queue_free()
	var reasons: Array = reasons_value if reasons_value is Array else []
	if reasons.is_empty():
		reasons = ["Существенных изменений нет"]
	for reason in reasons:
		var label := Label.new()
		label.text = "• %s" % String(reason)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stability_reasons_list.add_child(label)


func _on_daily_report_ready(report: Dictionary) -> void:
	open_report(report)
