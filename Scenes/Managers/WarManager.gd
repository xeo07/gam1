extends Node
class_name WarManager

signal war_declared(state_id: StringName)
signal campaign_started(campaign: Dictionary)
signal campaign_completed(report: Dictionary)
signal war_action_failed(reason: String)
signal war_state_changed

const CAMPAIGN_DURATION_DAYS := 4
const RESULT_DISPLAY_NAMES: Dictionary = {
	&"decisive_victory": "Убедительная победа",
	&"victory": "Победа",
	&"defeat": "Поражение",
	&"decisive_defeat": "Разгром",
}
const RESULT_EFFECTS: Dictionary = {
	&"decisive_victory": {
		"casualty_rate": 0.0,
		"gold_change": 15,
		"military_change": -25,
		"wealth_change": -15,
		"stability_change": -15,
		"population_change": -5,
	},
	&"victory": {
		"casualty_rate": 0.25,
		"gold_change": 8,
		"military_change": -15,
		"wealth_change": -10,
		"stability_change": -8,
		"population_change": -3,
	},
	&"defeat": {
		"casualty_rate": 0.5,
		"gold_change": -5,
		"military_change": -5,
		"wealth_change": 0,
		"stability_change": 3,
		"population_change": -1,
	},
	&"decisive_defeat": {
		"casualty_rate": 0.75,
		"gold_change": -10,
		"military_change": 0,
		"wealth_change": 5,
		"stability_change": 8,
		"population_change": 0,
	},
}

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _current_war_state_id: StringName = &""
var _active_campaign: Dictionary = {}
var _latest_report: Dictionary = {}
var _has_latest_report := false
var _is_save_loading := false


func _ready() -> void:
	add_to_group("war_manager")
	time_manager.day_changed.connect(_on_day_changed)


func can_declare_war(state_id: StringName) -> bool:
	return get_declare_war_failure_reason(state_id).is_empty()


func get_declare_war_failure_reason(state_id: StringName) -> String:
	var state := world_manager.get_state_by_id(state_id)
	if state.is_empty():
		return "Государство не найдено"
	if has_active_campaign() and _active_campaign.get("state_id", &"") == state_id:
		return "Против этого государства уже идёт поход"
	if state.get("status", &"neutral") == &"war":
		return "Война уже объявлена"
	if _current_war_state_id != &"" and _current_war_state_id != state_id:
		return "Сначала завершите текущую войну"
	return ""


func declare_war(state_id: StringName) -> bool:
	var failure_reason := get_declare_war_failure_reason(state_id)
	if not failure_reason.is_empty():
		return _fail_action(failure_reason)
	if not world_manager.set_state_relation_and_status(state_id, -100, &"war"):
		return _fail_action("Государство не найдено")
	_current_war_state_id = state_id
	war_declared.emit(state_id)
	war_state_changed.emit()
	print("War declared:")
	print("State: %s" % state_id)
	return true


func can_start_campaign(state_id: StringName, citizen_ids: Array[int]) -> bool:
	return get_campaign_failure_reason(state_id, citizen_ids).is_empty()


func get_campaign_failure_reason(
	state_id: StringName,
	citizen_ids: Array[int]
) -> String:
	var state := world_manager.get_state_by_id(state_id)
	if state.is_empty():
		return "Государство не найдено"
	if state.get("status", &"neutral") != &"war":
		return "Сначала объявите войну"
	if _current_war_state_id != state_id:
		return "Выбрано другое государство"
	if has_active_campaign():
		return "Поход уже выполняется"
	if citizen_ids.is_empty():
		return "Не выбраны бойцы"

	var unique_ids: Dictionary = {}
	var campaign_strength := 0
	for citizen_id in citizen_ids:
		if unique_ids.has(citizen_id):
			return "Один боец выбран несколько раз"
		unique_ids[citizen_id] = true
		var citizen := population_manager.get_citizen_by_id(citizen_id)
		if citizen.is_empty():
			return "Один из жителей не найден"
		if citizen.get("job", &"unassigned") != &"soldier":
			return "Один из выбранных жителей больше не является солдатом"
		if army_manager.get_assignment(citizen_id).is_empty():
			return "Один из выбранных солдат не назначен в армию"
		campaign_strength += army_manager.calculate_unit_strength(citizen_id)
	if campaign_strength <= 0:
		return "Сила похода равна нулю"
	return ""


func start_campaign(state_id: StringName, citizen_ids: Array[int]) -> bool:
	var failure_reason := get_campaign_failure_reason(state_id, citizen_ids)
	if not failure_reason.is_empty():
		return _fail_action(failure_reason)
	var state := world_manager.get_state_by_id(state_id)
	var started_day := time_manager.get_absolute_day()
	var campaign_ids: Array[int] = []
	var player_strength := 0
	for citizen_id in citizen_ids:
		campaign_ids.append(citizen_id)
		player_strength += army_manager.calculate_unit_strength(citizen_id)
	_active_campaign = {
		"state_id": state_id,
		"started_day": started_day,
		"completion_day": started_day + CAMPAIGN_DURATION_DAYS,
		"citizen_ids": campaign_ids,
		"player_strength": player_strength,
		"enemy_strength": int(state.get("military_strength", 0)),
	}
	campaign_started.emit(get_active_campaign())
	war_state_changed.emit()
	print("Campaign started:")
	print("State: %s" % state_id)
	print("Completion day: %d" % int(_active_campaign["completion_day"]))
	print("Soldiers: %d" % campaign_ids.size())
	print("Player strength: %d" % player_strength)
	print("Enemy strength: %d" % int(_active_campaign["enemy_strength"]))
	return true


func is_citizen_on_campaign(citizen_id: int) -> bool:
	if not has_active_campaign():
		return false
	var citizen_ids: Array = _active_campaign.get("citizen_ids", [])
	return citizen_id in citizen_ids


func get_active_campaign() -> Dictionary:
	return _active_campaign.duplicate(true)


func has_active_campaign() -> bool:
	return not _active_campaign.is_empty()


func get_campaign_days_remaining() -> int:
	if not has_active_campaign():
		return 0
	return maxi(
		0,
		int(_active_campaign["completion_day"]) - time_manager.get_absolute_day()
	)


func get_current_war_state_id() -> StringName:
	return _current_war_state_id


func get_latest_report() -> Dictionary:
	return _latest_report.duplicate(true)


func has_latest_report() -> bool:
	return _has_latest_report


func emit_war_state_changed() -> void:
	war_state_changed.emit()


func get_save_data() -> Dictionary:
	return {
		"current_war_state_id": String(_current_war_state_id),
		"active_campaign": _campaign_to_save_data(_active_campaign),
		"latest_report": _report_to_save_data(_latest_report),
		"has_latest_report": _has_latest_report,
	}


func is_save_data_consistent_with_sections(
	data: Dictionary,
	world_data: Dictionary,
	army_data: Dictionary
) -> bool:
	var parsed := _parse_save_data(data, false, false)
	if not bool(parsed.get("valid", false)):
		return false
	if not world_data.has("states") or not world_data["states"] is Array:
		return false
	if not army_data.has("assignments") or not army_data["assignments"] is Array:
		return false

	var current_state_id: StringName = parsed["current_war_state_id"]
	var war_state_ids: Array[StringName] = []
	for state_value in world_data["states"]:
		if not state_value is Dictionary:
			return false
		var state: Dictionary = state_value
		if not state.get("id", null) is String or not state.get("status", null) is String:
			return false
		if StringName(state["status"]) == &"war":
			war_state_ids.append(StringName(state["id"]))
	if current_state_id == &"":
		if not war_state_ids.is_empty():
			return false
	else:
		if war_state_ids.size() != 1 or war_state_ids[0] != current_state_id:
			return false

	var assignment_ids: Dictionary = {}
	for assignment_value in army_data["assignments"]:
		if not assignment_value is Dictionary:
			return false
		var assignment: Dictionary = assignment_value
		if not _is_integer_value(assignment.get("citizen_id", null)):
			return false
		assignment_ids[int(assignment["citizen_id"])] = true
	var campaign: Dictionary = parsed["active_campaign"]
	if not campaign.is_empty():
		for citizen_id in campaign["citizen_ids"]:
			if not assignment_ids.has(citizen_id):
				return false
	return true


func load_save_data(data: Dictionary) -> bool:
	var parsed := _parse_save_data(data, true, not _is_save_loading)
	if not bool(parsed.get("valid", false)):
		return false
	_current_war_state_id = parsed["current_war_state_id"]
	_active_campaign = parsed["active_campaign"]
	_latest_report = parsed["latest_report"]
	_has_latest_report = parsed["has_latest_report"]
	war_state_changed.emit()
	return true


func begin_save_load() -> void:
	_is_save_loading = true


func end_save_load() -> void:
	_is_save_loading = false


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	if not has_active_campaign():
		return
	if time_manager.get_absolute_day() < int(_active_campaign["completion_day"]):
		war_state_changed.emit()
		return
	_complete_campaign()


func _complete_campaign() -> void:
	var campaign := get_active_campaign()
	var state_id: StringName = campaign["state_id"]
	var state := world_manager.get_state_by_id(state_id)
	var result := _calculate_result(
		int(campaign["player_strength"]),
		int(campaign["enemy_strength"])
	)
	var effects: Dictionary = RESULT_EFFECTS[result]
	var sent_ids: Array[int] = []
	for citizen_id in campaign["citizen_ids"]:
		sent_ids.append(int(citizen_id))
	var casualty_ids := _calculate_casualties(
		sent_ids,
		float(effects["casualty_rate"]),
		result
	)
	var survivor_ids: Array[int] = []
	for citizen_id in sent_ids:
		if citizen_id not in casualty_ids:
			survivor_ids.append(citizen_id)

	for citizen_id in casualty_ids:
		army_manager.remove_casualty(citizen_id)
		population_manager.remove_citizen(citizen_id)

	world_manager.apply_war_result(
		state_id,
		int(effects["military_change"]),
		int(effects["wealth_change"]),
		int(effects["stability_change"]),
		int(effects["population_change"])
	)
	var gold_change := _apply_gold_change(int(effects["gold_change"]))
	world_manager.set_state_relation_and_status(state_id, -100, &"enemy")

	var report: Dictionary = {
		"state_id": state_id,
		"state_name": String(state.get("name", "")),
		"result": result,
		"result_name": String(RESULT_DISPLAY_NAMES[result]),
		"started_day": int(campaign["started_day"]),
		"completion_day": int(campaign["completion_day"]),
		"report_day": time_manager.day,
		"report_month": time_manager.month,
		"report_year": time_manager.year,
		"player_strength": int(campaign["player_strength"]),
		"enemy_strength": int(campaign["enemy_strength"]),
		"sent_citizen_ids": sent_ids.duplicate(),
		"casualty_ids": casualty_ids.duplicate(),
		"survivor_ids": survivor_ids.duplicate(),
		"gold_change": gold_change,
		"enemy_military_change": int(effects["military_change"]),
		"enemy_wealth_change": int(effects["wealth_change"]),
		"enemy_stability_change": int(effects["stability_change"]),
		"enemy_population_change": int(effects["population_change"]),
	}
	_active_campaign = {}
	_current_war_state_id = &""
	_latest_report = report.duplicate(true)
	_has_latest_report = true
	campaign_completed.emit(report.duplicate(true))
	war_state_changed.emit()
	print("Campaign completed:")
	print("State: %s" % state_id)
	print("Result: %s" % result)
	print("Player strength: %d" % int(campaign["player_strength"]))
	print("Enemy strength: %d" % int(campaign["enemy_strength"]))
	print("Casualties: %d" % casualty_ids.size())
	print("Gold change: %d" % gold_change)


func _calculate_result(player_strength: int, enemy_strength: int) -> StringName:
	var strength_ratio := float(player_strength) / maxf(1.0, float(enemy_strength))
	if strength_ratio >= 1.35:
		return &"decisive_victory"
	if strength_ratio >= 1.0:
		return &"victory"
	if strength_ratio >= 0.75:
		return &"defeat"
	return &"decisive_defeat"


func _calculate_casualties(
	citizen_ids: Array[int],
	casualty_rate: float,
	result: StringName
) -> Array[int]:
	var casualty_count := floori(float(citizen_ids.size()) * casualty_rate)
	if result != &"decisive_victory" and not citizen_ids.is_empty():
		casualty_count = maxi(1, casualty_count)
	var candidates := citizen_ids.duplicate()
	candidates.sort_custom(_is_weaker_citizen)
	var casualties: Array[int] = []
	for index in mini(casualty_count, candidates.size()):
		casualties.append(candidates[index])
	return casualties


func _is_weaker_citizen(first_id: int, second_id: int) -> bool:
	var first_strength := army_manager.calculate_unit_strength(first_id)
	var second_strength := army_manager.calculate_unit_strength(second_id)
	if first_strength == second_strength:
		return first_id < second_id
	return first_strength < second_strength


func _apply_gold_change(requested_change: int) -> int:
	if requested_change >= 0:
		resource_manager.add_resource(&"gold", requested_change)
		return requested_change
	var actual_loss := mini(resource_manager.gold, -requested_change)
	resource_manager.remove_resource(&"gold", actual_loss)
	return -actual_loss


func _campaign_to_save_data(campaign: Dictionary) -> Dictionary:
	if campaign.is_empty():
		return {}
	var citizen_ids: Array[int] = []
	for citizen_id in campaign["citizen_ids"]:
		citizen_ids.append(int(citizen_id))
	return {
		"state_id": String(campaign["state_id"]),
		"started_day": int(campaign["started_day"]),
		"completion_day": int(campaign["completion_day"]),
		"citizen_ids": citizen_ids,
		"player_strength": int(campaign["player_strength"]),
		"enemy_strength": int(campaign["enemy_strength"]),
	}


func _report_to_save_data(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {}
	var saved_report := report.duplicate(true)
	saved_report["state_id"] = String(report["state_id"])
	saved_report["result"] = String(report["result"])
	return saved_report


func _parse_save_data(
	data: Dictionary,
	validate_runtime: bool,
	validate_world_status: bool
) -> Dictionary:
	if not data.has_all([
		"current_war_state_id",
		"active_campaign",
		"latest_report",
		"has_latest_report",
	]):
		return {"valid": false}
	if not data["current_war_state_id"] is String:
		return {"valid": false}
	if not data["active_campaign"] is Dictionary or not data["latest_report"] is Dictionary:
		return {"valid": false}
	if not data["has_latest_report"] is bool:
		return {"valid": false}

	var current_state_id := StringName(data["current_war_state_id"])
	if current_state_id != &"":
		if current_state_id not in WorldManager.EXPECTED_STATE_IDS:
			return {"valid": false}
		if validate_world_status:
			var current_state := world_manager.get_state_by_id(current_state_id)
			if current_state.is_empty() or current_state.get("status", &"neutral") != &"war":
				return {"valid": false}

	var parsed_campaign := _parse_campaign(
		data["active_campaign"],
		current_state_id,
		validate_runtime
	)
	if not bool(parsed_campaign.get("valid", false)):
		return {"valid": false}
	var active_campaign: Dictionary = parsed_campaign["campaign"]
	if current_state_id == &"" and not active_campaign.is_empty():
		return {"valid": false}

	var has_report: bool = data["has_latest_report"]
	var latest_report: Dictionary = {}
	if has_report:
		var parsed_report := _parse_report(data["latest_report"])
		if not bool(parsed_report.get("valid", false)):
			return {"valid": false}
		latest_report = parsed_report["report"]
	elif not data["latest_report"].is_empty():
		return {"valid": false}
	return {
		"valid": true,
		"current_war_state_id": current_state_id,
		"active_campaign": active_campaign,
		"latest_report": latest_report,
		"has_latest_report": has_report,
	}


func _parse_campaign(
	data: Dictionary,
	current_state_id: StringName,
	validate_runtime: bool
) -> Dictionary:
	if data.is_empty():
		return {"valid": true, "campaign": {}}
	if not data.has_all([
		"state_id",
		"started_day",
		"completion_day",
		"citizen_ids",
		"player_strength",
		"enemy_strength",
	]):
		return {"valid": false}
	if not data["state_id"] is String or not data["citizen_ids"] is Array:
		return {"valid": false}
	for numeric_field in ["started_day", "completion_day", "player_strength", "enemy_strength"]:
		if not _is_integer_value(data[numeric_field]):
			return {"valid": false}
	var state_id := StringName(data["state_id"])
	if state_id == &"" or state_id != current_state_id:
		return {"valid": false}
	if state_id not in WorldManager.EXPECTED_STATE_IDS:
		return {"valid": false}
	var started_day := int(data["started_day"])
	var completion_day := int(data["completion_day"])
	var player_strength := int(data["player_strength"])
	var enemy_strength := int(data["enemy_strength"])
	if started_day < 1 or completion_day < started_day:
		return {"valid": false}
	if player_strength <= 0 or enemy_strength < 0:
		return {"valid": false}

	var citizen_ids: Array[int] = []
	var unique_ids: Dictionary = {}
	for citizen_id_value in data["citizen_ids"]:
		if not _is_integer_value(citizen_id_value):
			return {"valid": false}
		var citizen_id := int(citizen_id_value)
		if citizen_id < 1 or unique_ids.has(citizen_id):
			return {"valid": false}
		if validate_runtime:
			var citizen := population_manager.get_citizen_by_id(citizen_id)
			if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
				return {"valid": false}
			if army_manager.get_assignment(citizen_id).is_empty():
				return {"valid": false}
		unique_ids[citizen_id] = true
		citizen_ids.append(citizen_id)
	if citizen_ids.is_empty():
		return {"valid": false}
	return {
		"valid": true,
		"campaign": {
			"state_id": state_id,
			"started_day": started_day,
			"completion_day": completion_day,
			"citizen_ids": citizen_ids,
			"player_strength": player_strength,
			"enemy_strength": enemy_strength,
		},
	}


func _parse_report(data: Dictionary) -> Dictionary:
	var required_fields := [
		"state_id", "state_name", "result", "result_name", "started_day",
		"completion_day", "report_day", "report_month", "report_year",
		"player_strength", "enemy_strength", "sent_citizen_ids",
		"casualty_ids", "survivor_ids", "gold_change",
		"enemy_military_change", "enemy_wealth_change",
		"enemy_stability_change", "enemy_population_change",
	]
	if not data.has_all(required_fields):
		return {"valid": false}
	for string_field in ["state_id", "state_name", "result", "result_name"]:
		if not data[string_field] is String:
			return {"valid": false}
	for array_field in ["sent_citizen_ids", "casualty_ids", "survivor_ids"]:
		if not data[array_field] is Array:
			return {"valid": false}
	for numeric_field in [
		"started_day", "completion_day", "report_day", "report_month",
		"report_year", "player_strength", "enemy_strength", "gold_change",
		"enemy_military_change", "enemy_wealth_change",
		"enemy_stability_change", "enemy_population_change",
	]:
		if not _is_integer_value(data[numeric_field]):
			return {"valid": false}
	var state_id := StringName(data["state_id"])
	var result := StringName(data["result"])
	if state_id not in WorldManager.EXPECTED_STATE_IDS or not RESULT_DISPLAY_NAMES.has(result):
		return {"valid": false}
	if String(data["result_name"]) != String(RESULT_DISPLAY_NAMES[result]):
		return {"valid": false}
	if int(data["started_day"]) < 1 or int(data["completion_day"]) < int(data["started_day"]):
		return {"valid": false}
	if int(data["report_day"]) < 1 or int(data["report_day"]) > TimeManager.DAYS_IN_MONTH:
		return {"valid": false}
	if int(data["report_month"]) < 1 or int(data["report_month"]) > TimeManager.MONTHS_IN_YEAR:
		return {"valid": false}
	if int(data["report_year"]) < 1 or int(data["player_strength"]) <= 0:
		return {"valid": false}
	if int(data["enemy_strength"]) < 0:
		return {"valid": false}

	var parsed_arrays: Dictionary = {}
	for array_field in ["sent_citizen_ids", "casualty_ids", "survivor_ids"]:
		var parsed_ids: Array[int] = []
		var unique_ids: Dictionary = {}
		for citizen_id_value in data[array_field]:
			if not _is_integer_value(citizen_id_value):
				return {"valid": false}
			var citizen_id := int(citizen_id_value)
			if citizen_id < 1 or unique_ids.has(citizen_id):
				return {"valid": false}
			unique_ids[citizen_id] = true
			parsed_ids.append(citizen_id)
		parsed_arrays[array_field] = parsed_ids
	var sent_ids: Array = parsed_arrays["sent_citizen_ids"]
	var casualty_ids: Array = parsed_arrays["casualty_ids"]
	var survivor_ids: Array = parsed_arrays["survivor_ids"]
	if sent_ids.is_empty() or casualty_ids.size() + survivor_ids.size() != sent_ids.size():
		return {"valid": false}
	for citizen_id in casualty_ids:
		if citizen_id not in sent_ids or citizen_id in survivor_ids:
			return {"valid": false}
	for citizen_id in survivor_ids:
		if citizen_id not in sent_ids:
			return {"valid": false}

	var report := data.duplicate(true)
	report["state_id"] = state_id
	report["result"] = result
	for numeric_field in [
		"started_day", "completion_day", "report_day", "report_month",
		"report_year", "player_strength", "enemy_strength", "gold_change",
		"enemy_military_change", "enemy_wealth_change",
		"enemy_stability_change", "enemy_population_change",
	]:
		report[numeric_field] = int(data[numeric_field])
	report["sent_citizen_ids"] = parsed_arrays["sent_citizen_ids"]
	report["casualty_ids"] = parsed_arrays["casualty_ids"]
	report["survivor_ids"] = parsed_arrays["survivor_ids"]
	return {"valid": true, "report": report}


func _fail_action(reason: String) -> bool:
	war_action_failed.emit(reason)
	return false


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
