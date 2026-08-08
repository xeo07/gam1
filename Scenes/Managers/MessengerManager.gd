extends Node
class_name MessengerManager

signal mission_started(state_id: StringName, completion_day: int)
signal mission_failed(state_id: StringName, reason: String)
signal report_ready(report: Dictionary)

const GOLD_COST := 5
const DURATION_DAYS := 2
const RISK_TEXT := "Низкий риск: гонец может опоздать, но не раскрывает тайны"
const BENEFIT_TEXT := "Результат: дипломатические сведения и широкие диапазоны"

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _active_missions: Dictionary = {}
var _latest_reports: Dictionary = {}


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)


func start_mission(state_id: StringName) -> bool:
	if world_manager.get_state_by_id(state_id).is_empty():
		_fail(state_id, "Государство не найдено")
		return false
	if has_active_mission(state_id):
		_fail(state_id, "Гонец уже находится в пути")
		return false
	if not resource_manager.has_resource(&"gold", GOLD_COST):
		_fail(state_id, "Недостаточно золота")
		return false
	resource_manager.remove_resource(&"gold", GOLD_COST)
	var started_day := time_manager.get_absolute_day()
	var completion_day := started_day + DURATION_DAYS
	_active_missions[state_id] = {
		"state_id": state_id,
		"started_day": started_day,
		"completion_day": completion_day,
	}
	mission_started.emit(state_id, completion_day)
	return true


func has_active_mission(state_id: StringName) -> bool:
	return _active_missions.has(state_id)


func get_days_remaining(state_id: StringName) -> int:
	if not has_active_mission(state_id):
		return 0
	return maxi(0, int(_active_missions[state_id].get("completion_day", 0)) - time_manager.get_absolute_day())


func get_latest_report(state_id: StringName) -> Dictionary:
	if not _latest_reports.has(state_id):
		return {}
	return _latest_reports[state_id].duplicate(true)


func get_save_data() -> Dictionary:
	var missions: Array[Dictionary] = []
	for mission_value in _active_missions.values():
		var mission: Dictionary = mission_value
		missions.append({
			"state_id": String(mission.get("state_id", &"")),
			"started_day": int(mission.get("started_day", 0)),
			"completion_day": int(mission.get("completion_day", 0)),
		})
	var reports: Array[Dictionary] = []
	for report_value in _latest_reports.values():
		var report: Dictionary = report_value
		var saved_report := report.duplicate(true)
		saved_report["state_id"] = String(report.get("state_id", &""))
		reports.append(saved_report)
	return {"active_missions": missions, "latest_reports": reports}


func load_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		_active_missions.clear()
		_latest_reports.clear()
		return true
	if not data.get("active_missions", null) is Array or not data.get("latest_reports", null) is Array:
		return false
	var missions: Dictionary = {}
	for value in data["active_missions"]:
		if not value is Dictionary or not value.has_all(["state_id", "started_day", "completion_day"]):
			return false
		if not value["state_id"] is String:
			return false
		var state_id := StringName(value["state_id"])
		var started_day := int(value["started_day"])
		var completion_day := int(value["completion_day"])
		if world_manager.get_state_by_id(state_id).is_empty() or missions.has(state_id):
			return false
		if started_day < 1 or completion_day < started_day:
			return false
		missions[state_id] = {"state_id": state_id, "started_day": started_day, "completion_day": completion_day}
	var reports: Dictionary = {}
	for value in data["latest_reports"]:
		if not value is Dictionary or not value.has_all(["state_id", "report_day", "summary"]):
			return false
		if not value["state_id"] is String or not value["summary"] is String:
			return false
		var state_id := StringName(value["state_id"])
		if world_manager.get_state_by_id(state_id).is_empty() or reports.has(state_id):
			return false
		reports[state_id] = {"state_id": state_id, "report_day": int(value["report_day"]), "summary": String(value["summary"])}
	_active_missions = missions
	_latest_reports = reports
	return true


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	var completed: Array[StringName] = []
	for state_id in _active_missions:
		if time_manager.get_absolute_day() >= int(_active_missions[state_id]["completion_day"]):
			completed.append(StringName(state_id))
	for state_id in completed:
		_complete_mission(state_id)


func _complete_mission(state_id: StringName) -> void:
	_active_missions.erase(state_id)
	if not world_manager.improve_intelligence(state_id, StateIntelligence.LEVEL_DIPLOMATIC, &"messenger"):
		_fail(state_id, "Гонец не смог найти государство")
		return
	var observed := world_manager.get_observed_state_by_id(state_id)
	var report := {
		"state_id": state_id,
		"report_day": time_manager.get_absolute_day(),
		"summary": "Гонец вернулся. Получены дипломатические сведения о государстве %s." % String(observed.get("name", "")),
	}
	_latest_reports[state_id] = report.duplicate(true)
	report_ready.emit(report.duplicate(true))


func _fail(state_id: StringName, reason: String) -> void:
	mission_failed.emit(state_id, reason)
