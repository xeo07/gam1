extends Node
class_name SpyManager

signal spy_mission_started(state_id: StringName, completion_day: int)
signal spy_mission_failed(state_id: StringName, reason: String)
signal spy_report_ready(report: Dictionary)

const SPY_GOLD_COST := 15
const SPY_MISSION_DURATION_DAYS := 3

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _active_missions: Dictionary = {}
var _latest_reports: Dictionary = {}


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)


func start_spy_mission(state_id: StringName) -> bool:
	if world_manager.get_state_by_id(state_id).is_empty():
		_fail_mission(state_id, "Государство не найдено")
		return false
	if has_active_mission(state_id):
		_fail_mission(state_id, "Шпион уже выполняет задание")
		return false
	if not resource_manager.has_resource(&"gold", SPY_GOLD_COST):
		_fail_mission(state_id, "Недостаточно золота")
		return false

	resource_manager.remove_resource(&"gold", SPY_GOLD_COST)
	var started_day := time_manager.get_absolute_day()
	var completion_day := started_day + SPY_MISSION_DURATION_DAYS
	_active_missions[state_id] = {
		"state_id": state_id,
		"started_day": started_day,
		"completion_day": completion_day,
	}

	spy_mission_started.emit(state_id, completion_day)
	print("Spy mission started:")
	print("State: %s" % state_id)
	print("Completion day: %d" % completion_day)
	return true


func has_active_mission(state_id: StringName) -> bool:
	return _active_missions.has(state_id)


func get_mission_days_remaining(state_id: StringName) -> int:
	if not has_active_mission(state_id):
		return 0

	var mission: Dictionary = _active_missions[state_id]
	return maxi(
		0,
		int(mission.get("completion_day", 0))
		- time_manager.get_absolute_day()
	)


func get_active_missions() -> Array[Dictionary]:
	var missions_copy: Array[Dictionary] = []
	for mission_value in _active_missions.values():
		var mission: Dictionary = mission_value
		missions_copy.append(mission.duplicate(true))
	return missions_copy


func get_latest_report(state_id: StringName) -> Dictionary:
	if not _latest_reports.has(state_id):
		return {}
	var report: Dictionary = _latest_reports[state_id]
	return report.duplicate(true)


func get_save_data() -> Dictionary:
	var active_missions: Array[Dictionary] = []
	for mission_value in _active_missions.values():
		var mission: Dictionary = mission_value
		active_missions.append({
			"state_id": String(mission.get("state_id", &"")),
			"started_day": int(mission.get("started_day", 0)),
			"completion_day": int(mission.get("completion_day", 0)),
		})

	var latest_reports: Array[Dictionary] = []
	for report_value in _latest_reports.values():
		var report: Dictionary = report_value
		var saved_report := report.duplicate(true)
		saved_report["state_id"] = String(report.get("state_id", &""))
		saved_report["status"] = String(report.get("status", &"neutral"))
		latest_reports.append(saved_report)

	return {
		"active_missions": active_missions,
		"latest_reports": latest_reports,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["active_missions", "latest_reports"]):
		return false
	if not data["active_missions"] is Array:
		return false
	if not data["latest_reports"] is Array:
		return false

	var loaded_missions: Dictionary = {}
	for mission_value in data["active_missions"]:
		if not mission_value is Dictionary:
			return false
		var mission: Dictionary = mission_value
		if not mission.has_all([
			"state_id",
			"started_day",
			"completion_day",
		]):
			return false
		if not mission["state_id"] is String:
			return false
		if not _is_integer_value(mission["started_day"]):
			return false
		if not _is_integer_value(mission["completion_day"]):
			return false
		var mission_state_id := StringName(mission["state_id"])
		var started_day := int(mission["started_day"])
		var completion_day := int(mission["completion_day"])
		if world_manager.get_state_by_id(mission_state_id).is_empty():
			return false
		if loaded_missions.has(mission_state_id):
			return false
		if started_day < 1 or completion_day < started_day:
			return false
		loaded_missions[mission_state_id] = {
			"state_id": mission_state_id,
			"started_day": started_day,
			"completion_day": completion_day,
		}

	var loaded_reports: Dictionary = {}
	for report_value in data["latest_reports"]:
		if not report_value is Dictionary:
			return false
		var report: Dictionary = report_value
		if not report.has_all([
			"state_id",
			"state_name",
			"ruler_name",
			"population",
			"military_strength",
			"wealth",
			"stability",
			"relation",
			"status",
			"report_day",
			"report_month",
			"report_year",
		]):
			return false
		for string_field in [
			"state_id",
			"state_name",
			"ruler_name",
			"status",
		]:
			if not report[string_field] is String:
				return false
		for numeric_field in [
			"population",
			"military_strength",
			"wealth",
			"stability",
			"relation",
			"report_day",
			"report_month",
			"report_year",
		]:
			if not _is_integer_value(report[numeric_field]):
				return false
		var report_state_id := StringName(report["state_id"])
		if loaded_reports.has(report_state_id):
			return false
		var loaded_report := report.duplicate(true)
		loaded_report["state_id"] = report_state_id
		loaded_report["status"] = StringName(report["status"])
		for numeric_field in [
			"population",
			"military_strength",
			"wealth",
			"stability",
			"relation",
			"report_day",
			"report_month",
			"report_year",
		]:
			loaded_report[numeric_field] = int(report[numeric_field])
		loaded_reports[report_state_id] = loaded_report

	_active_missions = loaded_missions
	_latest_reports = loaded_reports
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	var completed_state_ids: Array[StringName] = []
	var current_day := time_manager.get_absolute_day()

	for state_id_value in _active_missions.keys():
		var state_id := StringName(state_id_value)
		var mission: Dictionary = _active_missions[state_id]
		if current_day >= int(mission.get("completion_day", 0)):
			completed_state_ids.append(state_id)

	for state_id in completed_state_ids:
		_complete_mission(state_id)


func _complete_mission(state_id: StringName) -> void:
	var state := world_manager.get_state_by_id(state_id)
	_active_missions.erase(state_id)
	if state.is_empty():
		_fail_mission(state_id, "Государство не найдено")
		return

	var report: Dictionary = {
		"state_id": state_id,
		"state_name": String(state.get("name", "")),
		"ruler_name": String(state.get("ruler_name", "")),
		"population": int(state.get("population", 0)),
		"military_strength": int(state.get("military_strength", 0)),
		"wealth": int(state.get("wealth", 0)),
		"stability": int(state.get("stability", 0)),
		"relation": int(state.get("relation", 0)),
		"status": StringName(state.get("status", &"neutral")),
		"report_day": time_manager.day,
		"report_month": time_manager.month,
		"report_year": time_manager.year,
	}

	_latest_reports[state_id] = report.duplicate(true)
	spy_report_ready.emit(report.duplicate(true))
	print("Spy report ready:")
	print("State: %s" % state_id)
	print(
		"Report date: Day %d, Month %d, Year %d"
		% [report["report_day"], report["report_month"], report["report_year"]]
	)


func _fail_mission(state_id: StringName, reason: String) -> void:
	spy_mission_failed.emit(state_id, reason)
