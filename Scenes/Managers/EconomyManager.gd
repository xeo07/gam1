extends Node
class_name EconomyManager

signal daily_production_completed(production: Dictionary)
signal daily_economy_completed(report: Dictionary)

const RESOURCE_NAMES: Array[StringName] = [
	&"food",
	&"wood",
	&"stone",
	&"gold",
]

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager

var _last_processed_absolute_day: int = 0
var _last_economy_report: Dictionary = {}
var _has_economy_report := false


func _ready() -> void:
	_last_processed_absolute_day = time_manager.get_absolute_day()
	time_manager.day_changed.connect(_on_day_changed)


func initialize_new_game() -> void:
	_last_processed_absolute_day = time_manager.get_absolute_day()
	_last_economy_report.clear()
	_has_economy_report = false


func calculate_daily_production() -> Dictionary:
	var production := _empty_resource_dictionary()
	production["food"] = get_active_worker_count(&"farmer") * 2
	production["wood"] = get_active_worker_count(&"woodcutter") * 3
	production["stone"] = get_active_worker_count(&"miner")
	return production


func calculate_daily_expenses() -> Dictionary:
	var breakdown := _calculate_expense_breakdown()
	return {
		"food": (
			int(breakdown["population_food"])
			+ int(breakdown["army_food"])
			+ int(breakdown["building_food"])
		),
		"wood": 0,
		"stone": 0,
		"gold": int(breakdown["army_gold"]) + int(breakdown["building_gold"]),
	}


func apply_production(production: Dictionary) -> void:
	for resource_name in RESOURCE_NAMES:
		var amount := int(production.get(String(resource_name), 0))
		if amount > 0:
			resource_manager.add_resource(resource_name, amount)


func apply_expenses(expenses: Dictionary) -> Dictionary:
	var shortages := _empty_resource_dictionary()
	var breakdown := _calculate_expense_breakdown()
	var food_expense := maxi(int(expenses.get("food", 0)), 0)
	var gold_expense := maxi(int(expenses.get("gold", 0)), 0)

	# Category arrays preserve the required priority within each resource.
	shortages["food"] = _consume_expense_categories(
		&"food",
		food_expense,
		[
			int(breakdown["population_food"]),
			int(breakdown["army_food"]),
			int(breakdown["building_food"]),
		]
	)
	shortages["gold"] = _consume_expense_categories(
		&"gold",
		gold_expense,
		[int(breakdown["army_gold"]), int(breakdown["building_gold"])]
	)

	# No current system produces wood or stone expenses, but keep the public
	# method complete for its four-resource Dictionary contract.
	for resource_name in [&"wood", &"stone"]:
		var key := String(resource_name)
		shortages[key] = _consume_resource(
			resource_name, maxi(int(expenses.get(key, 0)), 0)
		)
	return shortages


func calculate_net(
	production: Dictionary,
	expenses: Dictionary,
	shortages: Dictionary
) -> Dictionary:
	var net := _empty_resource_dictionary()
	for resource_name in RESOURCE_NAMES:
		var key := String(resource_name)
		net[key] = (
			int(production.get(key, 0))
			- int(expenses.get(key, 0))
			+ int(shortages.get(key, 0))
		)
	return net


func get_active_worker_count(job: StringName) -> int:
	if job not in [&"farmer", &"woodcutter", &"miner"]:
		return 0
	var citizens_with_job := 0
	for citizen in population_manager.get_all_citizens():
		if citizen.get("job", &"unassigned") == job:
			citizens_with_job += 1
	return mini(citizens_with_job, get_available_worker_capacity(job))


func get_available_worker_capacity(job: StringName) -> int:
	return building_manager.get_total_worker_capacity(job)


func get_last_economy_report() -> Dictionary:
	return _last_economy_report.duplicate(true)


func has_economy_report() -> bool:
	return _has_economy_report


func get_save_data() -> Dictionary:
	return {
		"last_processed_absolute_day": _last_processed_absolute_day,
		"last_economy_report": _last_economy_report.duplicate(true),
		"has_economy_report": _has_economy_report,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all([
		"last_processed_absolute_day",
		"last_economy_report",
		"has_economy_report",
	]):
		return false
	if not _is_integer_value(data["last_processed_absolute_day"]):
		return false
	if not data["last_economy_report"] is Dictionary:
		return false
	if not data["has_economy_report"] is bool:
		return false

	var loaded_day := int(data["last_processed_absolute_day"])
	var loaded_has_report: bool = data["has_economy_report"]
	var loaded_report: Dictionary = data["last_economy_report"]
	if loaded_day < 0 or loaded_day != time_manager.get_absolute_day():
		return false
	if loaded_has_report != (not loaded_report.is_empty()):
		return false
	if loaded_has_report and not _validate_economy_report(loaded_report):
		return false

	_last_processed_absolute_day = loaded_day
	_last_economy_report = (
		_normalize_economy_report(loaded_report) if loaded_has_report else {}
	)
	_has_economy_report = loaded_has_report
	return true


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	var absolute_day := time_manager.get_absolute_day()
	if absolute_day <= _last_processed_absolute_day:
		return
	_last_processed_absolute_day = absolute_day

	var production := calculate_daily_production()
	apply_production(production)
	var expenses := calculate_daily_expenses()
	var shortages := apply_expenses(expenses)
	var hunger_active := int(shortages["food"]) > 0
	if hunger_active:
		population_manager.apply_loyalty_change_to_all(-1)

	var report := {
		"production": production.duplicate(true),
		"expenses": expenses.duplicate(true),
		"net": calculate_net(production, expenses, shortages),
		"shortages": shortages.duplicate(true),
		"population": population_manager.get_population_count(),
		"soldiers": army_manager.get_all_assignments().size(),
		"buildings": building_manager.get_all_buildings().size(),
		"hunger_active": hunger_active,
		"gold_deficit_active": int(shortages["gold"]) > 0,
	}
	_last_economy_report = report.duplicate(true)
	_has_economy_report = true

	daily_production_completed.emit(production.duplicate(true))
	daily_economy_completed.emit(report.duplicate(true))
	_print_economy_day(report)


func _calculate_expense_breakdown() -> Dictionary:
	var army_food := 0
	var army_gold := 0
	for assignment in army_manager.get_all_assignments():
		var unit_type: StringName = assignment.get("unit_type", &"")
		match unit_type:
			&"archer":
				army_food += 1
			&"heavy_infantry":
				army_food += 1
				army_gold += 1

	var building_upkeep := building_manager.get_total_daily_upkeep()
	return {
		"population_food": population_manager.get_population_count(),
		"army_food": army_food,
		"building_food": int(building_upkeep.get("food", 0)),
		"army_gold": army_gold,
		"building_gold": int(building_upkeep.get("gold", 0)),
	}


func _consume_resource(resource_name: StringName, requested: int) -> int:
	if requested <= 0:
		return 0
	var available := _get_resource_amount(resource_name)
	var paid := mini(available, requested)
	if paid > 0:
		resource_manager.remove_resource(resource_name, paid)
	return requested - paid


func _consume_expense_categories(
	resource_name: StringName,
	total_expense: int,
	categories: Array
) -> int:
	var remaining := total_expense
	var shortage := 0
	for category_value in categories:
		if remaining <= 0:
			break
		var requested := mini(maxi(int(category_value), 0), remaining)
		shortage += _consume_resource(resource_name, requested)
		remaining -= requested
	if remaining > 0:
		shortage += _consume_resource(resource_name, remaining)
	return shortage


func _get_resource_amount(resource_name: StringName) -> int:
	match resource_name:
		&"food":
			return resource_manager.food
		&"wood":
			return resource_manager.wood
		&"stone":
			return resource_manager.stone
		&"gold":
			return resource_manager.gold
	return 0


func _empty_resource_dictionary() -> Dictionary:
	return {"food": 0, "wood": 0, "stone": 0, "gold": 0}


func _validate_economy_report(report: Dictionary) -> bool:
	if not report.has_all([
		"production",
		"expenses",
		"net",
		"shortages",
		"population",
		"soldiers",
		"buildings",
		"hunger_active",
		"gold_deficit_active",
	]):
		return false
	for section_name in ["production", "expenses", "net", "shortages"]:
		if not report[section_name] is Dictionary:
			return false
		var section: Dictionary = report[section_name]
		if not section.has_all(["food", "wood", "stone", "gold"]):
			return false
		for resource_name in ["food", "wood", "stone", "gold"]:
			if not _is_integer_value(section[resource_name]):
				return false
			if section_name != "net" and int(section[resource_name]) < 0:
				return false
	for count_name in ["population", "soldiers", "buildings"]:
		if not _is_integer_value(report[count_name]):
			return false
		if int(report[count_name]) < 0:
			return false
	return (
		report["hunger_active"] is bool
		and report["gold_deficit_active"] is bool
	)


func _normalize_economy_report(report: Dictionary) -> Dictionary:
	var normalized := {}
	for section_name in ["production", "expenses", "net", "shortages"]:
		var source: Dictionary = report[section_name]
		normalized[section_name] = {
			"food": int(source["food"]),
			"wood": int(source["wood"]),
			"stone": int(source["stone"]),
			"gold": int(source["gold"]),
		}
	normalized["population"] = int(report["population"])
	normalized["soldiers"] = int(report["soldiers"])
	normalized["buildings"] = int(report["buildings"])
	normalized["hunger_active"] = bool(report["hunger_active"])
	normalized["gold_deficit_active"] = bool(report["gold_deficit_active"])
	return normalized


func _print_economy_day(report: Dictionary) -> void:
	var production: Dictionary = report["production"]
	var expenses: Dictionary = report["expenses"]
	var net: Dictionary = report["net"]
	var shortages: Dictionary = report["shortages"]
	print("Economy day completed:")
	print("Day: %d" % time_manager.get_absolute_day())
	print(
		"Production food/wood/stone/gold: %d/%d/%d/%d"
		% [production["food"], production["wood"], production["stone"], production["gold"]]
	)
	print(
		"Expenses food/wood/stone/gold: %d/%d/%d/%d"
		% [expenses["food"], expenses["wood"], expenses["stone"], expenses["gold"]]
	)
	print(
		"Net food/wood/stone/gold: %d/%d/%d/%d"
		% [net["food"], net["wood"], net["stone"], net["gold"]]
	)
	print(
		"Shortages food/wood/stone/gold: %d/%d/%d/%d"
		% [shortages["food"], shortages["wood"], shortages["stone"], shortages["gold"]]
	)
	print("Hunger: %s" % str(report["hunger_active"]))
	print("Gold deficit: %s" % str(report["gold_deficit_active"]))
	print("Active workers:")
	print(
		"Farmers: %d/%d"
		% [get_active_worker_count(&"farmer"), get_available_worker_capacity(&"farmer")]
	)
	print(
		"Woodcutters: %d/%d"
		% [get_active_worker_count(&"woodcutter"), get_available_worker_capacity(&"woodcutter")]
	)
	print(
		"Miners: %d/%d"
		% [get_active_worker_count(&"miner"), get_available_worker_capacity(&"miner")]
	)


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
