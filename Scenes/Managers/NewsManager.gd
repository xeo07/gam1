extends Node
class_name NewsManager

signal daily_report_ready(report: Dictionary)
signal foreign_news_ready(report: Dictionary)
signal weekly_edition_ready(edition: Dictionary)

const WEEKLY_EDITION_INTERVAL_DAYS := 7

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager
@onready var economy_manager: EconomyManager = $"../EconomyManager" as EconomyManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var event_journal_manager: EventJournalManager = $"../EventJournalManager" as EventJournalManager

var _latest_report: Dictionary = {}
var _latest_foreign_news: Dictionary = {}
var _latest_weekly_edition: Dictionary = {}
var _last_edition_day := 0


func _ready() -> void:
	stability_manager.stability_day_completed.connect(_on_stability_day_completed)
	world_manager.world_day_processed.connect(_on_world_day_processed)


func get_latest_report() -> Dictionary:
	return _latest_report.duplicate(true)


func has_report() -> bool:
	return not _latest_report.is_empty()


func create_foreign_news(updates: Array[Dictionary]) -> Dictionary:
	var states: Array[Dictionary] = []
	for update in updates:
		states.append({
			"state_id": update.get("state_id", &""),
			"state_name": String(update.get("state_name", "")),
			"summary": _create_state_summary(update),
			"population": int(update.get("population", 0)),
			"military_strength": int(
				update.get("military_strength", 0)
			),
			"wealth": int(update.get("wealth", 0)),
			"stability": int(update.get("stability", 0)),
		})

	return {
		"day": time_manager.day,
		"month": time_manager.month,
		"year": time_manager.year,
		"states": states,
	}


func get_latest_foreign_news() -> Dictionary:
	return _latest_foreign_news.duplicate(true)


func has_foreign_news() -> bool:
	return not _latest_foreign_news.is_empty()


func get_latest_weekly_edition() -> Dictionary:
	return _latest_weekly_edition.duplicate(true)


func has_weekly_edition() -> bool:
	return not _latest_weekly_edition.is_empty()


func create_weekly_edition(absolute_day: int) -> Dictionary:
	var first_day := maxi(1, absolute_day - WEEKLY_EDITION_INTERVAL_DAYS + 1)
	var entries := event_journal_manager.get_entries_between(first_day, absolute_day)
	return NewspaperEdition.create(
		absolute_day / WEEKLY_EDITION_INTERVAL_DAYS,
		absolute_day,
		entries
	)


func get_save_data() -> Dictionary:
	var daily_report := _latest_report.duplicate(true)
	if daily_report.has("stability") and daily_report["stability"] is Dictionary:
		var stability_data: Dictionary = daily_report["stability"]
		stability_data["state_id"] = String(stability_data.get("state_id", &""))
		daily_report["stability"] = stability_data
	var foreign_news := _latest_foreign_news.duplicate(true)
	if foreign_news.has("states") and foreign_news["states"] is Array:
		var saved_states: Array[Dictionary] = []
		for state_value in foreign_news["states"]:
			var state: Dictionary = state_value
			var saved_state := state.duplicate(true)
			saved_state["state_id"] = String(state.get("state_id", &""))
			saved_states.append(saved_state)
		foreign_news["states"] = saved_states

	return {
		"latest_daily_report": daily_report,
		"has_daily_report": has_report(),
		"latest_foreign_news": foreign_news,
		"has_foreign_news": has_foreign_news(),
		"latest_weekly_edition": (
			NewspaperEdition.to_save_data(_latest_weekly_edition)
			if has_weekly_edition()
			else {}
		),
		"has_weekly_edition": has_weekly_edition(),
		"last_edition_day": _last_edition_day,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all([
		"latest_daily_report",
		"has_daily_report",
		"latest_foreign_news",
		"has_foreign_news",
	]):
		return false
	if not data["latest_daily_report"] is Dictionary:
		return false
	if not data["latest_foreign_news"] is Dictionary:
		return false
	if not data["has_daily_report"] is bool:
		return false
	if not data["has_foreign_news"] is bool:
		return false

	var has_loaded_daily := bool(data["has_daily_report"])
	var has_loaded_foreign := bool(data["has_foreign_news"])
	var loaded_daily: Dictionary = data["latest_daily_report"]
	var loaded_foreign: Dictionary = data["latest_foreign_news"]
	if has_loaded_daily != (not loaded_daily.is_empty()):
		return false
	if has_loaded_foreign != (not loaded_foreign.is_empty()):
		return false

	if has_loaded_daily:
		if not _validate_daily_report(loaded_daily):
			return false
		loaded_daily = {
			"day": int(loaded_daily["day"]),
			"month": int(loaded_daily["month"]),
			"year": int(loaded_daily["year"]),
			"economy": _normalize_economy_report(loaded_daily["economy"]),
			"stability": _normalize_stability_data(loaded_daily["stability"]),
			"population": int(loaded_daily["population"]),
			"population_capacity": int(
				loaded_daily["population_capacity"]
			),
			"buildings_count": int(loaded_daily["buildings_count"]),
			"army_count": int(loaded_daily["army_count"]),
			"army_strength": int(loaded_daily["army_strength"]),
		}

	if has_loaded_foreign:
		if not _validate_foreign_news(loaded_foreign):
			return false
		var loaded_states: Array[Dictionary] = []
		for state_value in loaded_foreign["states"]:
			if not state_value is Dictionary:
				return false
			var state: Dictionary = state_value
			loaded_states.append({
				"state_id": StringName(state["state_id"]),
				"state_name": String(state["state_name"]),
				"summary": String(state["summary"]),
				"population": int(state["population"]),
				"military_strength": int(state["military_strength"]),
				"wealth": int(state["wealth"]),
				"stability": int(state["stability"]),
			})
		loaded_foreign = {
			"day": int(loaded_foreign["day"]),
			"month": int(loaded_foreign["month"]),
			"year": int(loaded_foreign["year"]),
			"states": loaded_states,
		}

	_latest_report = loaded_daily.duplicate(true) if has_loaded_daily else {}
	_latest_foreign_news = loaded_foreign.duplicate(true) if has_loaded_foreign else {}
	var has_loaded_weekly := bool(data.get("has_weekly_edition", false))
	var loaded_weekly_value: Variant = data.get("latest_weekly_edition", {})
	if not loaded_weekly_value is Dictionary:
		return false
	var loaded_weekly: Dictionary = loaded_weekly_value
	if has_loaded_weekly != (not loaded_weekly.is_empty()):
		return false
	var last_edition_value: Variant = data.get("last_edition_day", 0)
	if not _is_integer_value(last_edition_value) or int(last_edition_value) < 0:
		return false
	if has_loaded_weekly:
		var parsed_edition := NewspaperEdition.parse_save_data(loaded_weekly)
		if not bool(parsed_edition.get("valid", false)):
			return false
		_latest_weekly_edition = parsed_edition["edition"]
		if int(_latest_weekly_edition["last_day"]) != int(last_edition_value):
			return false
	else:
		_latest_weekly_edition = {}
		if int(last_edition_value) != 0:
			return false
	_last_edition_day = int(last_edition_value)
	return true


func _validate_daily_report(report: Dictionary) -> bool:
	if not report.has_all([
		"day",
		"month",
		"year",
		"economy",
		"stability",
		"population",
		"population_capacity",
		"buildings_count",
		"army_count",
		"army_strength",
	]):
		return false
	if not report["economy"] is Dictionary:
		return false
	if not report["stability"] is Dictionary:
		return false
	for numeric_field in [
		"day",
		"month",
		"year",
		"population",
		"population_capacity",
		"buildings_count",
		"army_count",
		"army_strength",
	]:
		if not _is_integer_value(report[numeric_field]):
			return false
		if int(report[numeric_field]) < 0:
			return false
	return (
		_validate_economy_report(report["economy"])
		and _validate_stability_data(report["stability"])
	)


func _validate_foreign_news(report: Dictionary) -> bool:
	if not report.has_all(["day", "month", "year", "states"]):
		return false
	if not report["states"] is Array:
		return false
	for date_field in ["day", "month", "year"]:
		if not _is_integer_value(report[date_field]):
			return false

	for state_value in report["states"]:
		if not state_value is Dictionary:
			return false
		var state: Dictionary = state_value
		if not state.has_all([
			"state_id",
			"state_name",
			"summary",
			"population",
			"military_strength",
			"wealth",
			"stability",
		]):
			return false
		for string_field in ["state_id", "state_name", "summary"]:
			if not state[string_field] is String:
				return false
		for numeric_field in [
			"population",
			"military_strength",
			"wealth",
			"stability",
		]:
			if not _is_integer_value(state[numeric_field]):
				return false
	return true


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
		var section: Dictionary = report[section_name]
		normalized[section_name] = {
			"food": int(section["food"]),
			"wood": int(section["wood"]),
			"stone": int(section["stone"]),
			"gold": int(section["gold"]),
		}
	normalized["population"] = int(report["population"])
	normalized["soldiers"] = int(report["soldiers"])
	normalized["buildings"] = int(report["buildings"])
	normalized["hunger_active"] = bool(report["hunger_active"])
	normalized["gold_deficit_active"] = bool(report["gold_deficit_active"])
	return normalized


func _validate_stability_data(data: Dictionary) -> bool:
	if not data.has_all([
		"stability",
		"change",
		"state_id",
		"state_name",
		"average_loyalty",
		"reasons",
	]):
		return false
	if not _is_integer_value(data["stability"]):
		return false
	if not _is_integer_value(data["change"]):
		return false
	if not data["state_id"] is String or not data["state_name"] is String:
		return false
	if not (data["average_loyalty"] is int or data["average_loyalty"] is float):
		return false
	if not data["reasons"] is Array:
		return false
	var stability_value := int(data["stability"])
	var change := int(data["change"])
	var average_loyalty := float(data["average_loyalty"])
	if stability_value < 0 or stability_value > 100:
		return false
	if change < -10 or change > 3:
		return false
	if average_loyalty < 0.0 or average_loyalty > 10.0:
		return false
	if StringName(data["state_id"]) not in [
		&"prosperous", &"stable", &"tense", &"unstable", &"critical"
	]:
		return false
	for reason in data["reasons"]:
		if not reason is String:
			return false
	return true


func _normalize_stability_data(data: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	for reason in data["reasons"]:
		reasons.append(String(reason))
	return {
		"stability": int(data["stability"]),
		"change": int(data["change"]),
		"state_id": StringName(data["state_id"]),
		"state_name": String(data["state_name"]),
		"average_loyalty": float(data["average_loyalty"]),
		"reasons": reasons,
	}


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func _on_stability_day_completed(stability_data: Dictionary) -> void:
	var economy := economy_manager.get_last_economy_report()
	if economy.is_empty():
		return
	if (
		_latest_report.get("day", -1) == time_manager.day
		and _latest_report.get("month", -1) == time_manager.month
		and _latest_report.get("year", -1) == time_manager.year
	):
		return
	var report: Dictionary = {
		"day": time_manager.day,
		"month": time_manager.month,
		"year": time_manager.year,
		"economy": economy.duplicate(true),
		"stability": stability_data.duplicate(true),
		"population": population_manager.get_population_count(),
		"population_capacity": population_manager.get_population_capacity(),
		"buildings_count": building_manager.get_all_buildings().size(),
		"army_count": army_manager.get_all_assignments().size(),
		"army_strength": army_manager.calculate_total_military_strength(),
	}

	_latest_report = report.duplicate(true)
	daily_report_ready.emit(report.duplicate(true))
	_print_daily_report(report)


func _on_world_day_processed(
	absolute_day: int,
	_updates: Array[Dictionary]
) -> void:
	if absolute_day % WEEKLY_EDITION_INTERVAL_DAYS != 0:
		return
	if absolute_day <= _last_edition_day:
		return

	var edition := create_weekly_edition(absolute_day)
	_latest_weekly_edition = edition.duplicate(true)
	_last_edition_day = absolute_day
	weekly_edition_ready.emit(edition.duplicate(true))
	_print_weekly_edition(edition)


func _create_state_summary(update: Dictionary) -> String:
	var messages: Array[String] = []
	var population_change := int(update.get("population_change", 0))
	var military_change := int(update.get("military_change", 0))
	var wealth_change := int(update.get("wealth_change", 0))
	var stability_change := int(update.get("stability_change", 0))

	if population_change >= 2:
		messages.append("Население заметно выросло.")
	elif population_change <= -2:
		messages.append("Население сократилось.")

	if military_change >= 2:
		messages.append("Государство усиливает армию.")
	elif military_change <= -2:
		messages.append("Военная сила государства ослабла.")

	if wealth_change >= 3:
		messages.append("Казна государства пополнилась.")
	elif wealth_change <= -3:
		messages.append("Государство испытывает финансовые трудности.")

	if stability_change >= 2:
		messages.append("Внутренняя стабильность укрепилась.")
	elif stability_change <= -2:
		messages.append("В государстве растёт напряжение.")

	if messages.is_empty():
		return "Существенных изменений не замечено."
	return " ".join(PackedStringArray(messages))


func _print_daily_report(report: Dictionary) -> void:
	print("Daily report created:")
	print(
		"Day %d, Month %d, Year %d"
		% [report["day"], report["month"], report["year"]]
	)
	print(
		"Population: %d/%d"
		% [report["population"], report["population_capacity"]]
	)
	print("Buildings: %d" % int(report["buildings_count"]))


func _print_foreign_news(report: Dictionary) -> void:
	var states: Array = report.get("states", [])
	print("Foreign news created:")
	print(
		"Day %d, Month %d, Year %d"
		% [report["day"], report["month"], report["year"]]
	)
	print("States included: %d" % states.size())


func _print_weekly_edition(edition: Dictionary) -> void:
	var articles: Array = edition.get("articles", [])
	print("Weekly newspaper created:")
	print(
		"Issue %d | Days %d-%d"
		% [edition["issue_number"], edition["first_day"], edition["last_day"]]
	)
	print("Headline: %s" % String(edition["headline"]))
	print("Articles: %d" % articles.size())
