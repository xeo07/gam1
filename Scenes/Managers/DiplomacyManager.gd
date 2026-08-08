extends Node
class_name DiplomacyManager

signal diplomatic_action_completed(
	state_id: StringName,
	action_id: StringName,
	relation_change: int,
	message: String
)
signal diplomatic_action_failed(
	state_id: StringName,
	action_id: StringName,
	reason: String
)

const GIFT_GOLD_COST := 10
const GIFT_RELATION_CHANGE := 10
const INSULT_RELATION_CHANGE := -15
const ACTION_COOLDOWN_DAYS := 3
const GIFT_ACTION_ID := &"gift"
const INSULT_ACTION_ID := &"insult"
const THREAT_ACTION_ID := &"threat"
const AGREEMENT_ACTION_ID := &"agreement"

@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var _last_action_days: Dictionary = {}


func get_relation_label(relation: int) -> String:
	var normalized_relation := clampi(relation, -100, 100)
	if normalized_relation <= -51:
		return "Враждебные"
	if normalized_relation <= -11:
		return "Напряжённые"
	if normalized_relation <= 10:
		return "Нейтральные"
	if normalized_relation <= 50:
		return "Хорошие"
	return "Союзные"


func get_state_relation_label(state_id: StringName) -> String:
	if world_manager.get_state_by_id(state_id).is_empty():
		return ""
	return get_relation_label(world_manager.get_relation(state_id))


func get_relation_summary(state_id: StringName) -> Dictionary:
	if world_manager.get_state_by_id(state_id).is_empty():
		return {}
	return {
		"label": get_state_relation_label(state_id),
		"reasons": world_manager.get_relation_reasons(state_id),
	}


func send_gift(state_id: StringName) -> bool:
	return perform_action(GIFT_ACTION_ID, state_id)


func send_insult(state_id: StringName) -> bool:
	return perform_action(INSULT_ACTION_ID, state_id)


func get_action_preview(action_id: StringName, state_id: StringName) -> Dictionary:
	var state := world_manager.get_state_by_id(state_id)
	if state.is_empty():
		return {}
	return DiplomaticActionResolver.build(action_id, state, _get_third_party(state_id))


func perform_action(action_id: StringName, state_id: StringName) -> bool:
	if not _validate_state_and_cooldown(state_id, action_id):
		return false
	var preview := get_action_preview(action_id, state_id)
	if preview.is_empty():
		_fail_action(state_id, action_id, "Неизвестное действие")
		return false
	var cost := int(preview.get("cost", 0))
	if not resource_manager.has_resource(&"gold", cost):
		_fail_action(state_id, action_id, "Недостаточно золота")
		return false
	resource_manager.remove_resource(&"gold", cost)
	var relation_change := world_manager.add_relation_memory(state_id, action_id, preview["summary"], preview["trust"], preview["fear"], preview["benefit"], preview["duration"])
	var message := String(preview["message"])
	var third: Dictionary = preview.get("third_party", {})
	if not third.is_empty():
		world_manager.add_relation_memory(third["state_id"], &"rival_agreement", third["summary"], third["trust"], third["fear"], third["benefit"], third["duration"])
		message += " %s насторожились." % String(third["state_name"])
	_record_action(state_id)
	_complete_action(state_id, action_id, relation_change, message)
	return true


func _get_third_party(target_id: StringName) -> Dictionary:
	var candidate: Dictionary = {}
	var lowest := 101
	for state in world_manager.get_all_states():
		var state_id: StringName = state.get("id", &"")
		if state_id == target_id:
			continue
		var relation := world_manager.get_relation(state_id)
		if relation < lowest:
			lowest = relation
			candidate = state
	return candidate


func can_perform_action(state_id: StringName) -> bool:
	if world_manager.get_state_by_id(state_id).is_empty():
		return false
	return get_action_cooldown_remaining(state_id) == 0


func get_action_cooldown_remaining(state_id: StringName) -> int:
	if not _last_action_days.has(state_id):
		return 0

	var action_day := int(_last_action_days[state_id])
	var elapsed_days := time_manager.get_absolute_day() - action_day
	return maxi(0, ACTION_COOLDOWN_DAYS - elapsed_days)


func get_save_data() -> Dictionary:
	var action_days: Dictionary = {}
	for state_id_value in _last_action_days.keys():
		action_days[String(state_id_value)] = int(
			_last_action_days[state_id_value]
		)
	return {"action_days": action_days}


func load_save_data(data: Dictionary) -> bool:
	if not data.has("action_days") or not data["action_days"] is Dictionary:
		return false

	var loaded_action_days: Dictionary = {}
	var action_days: Dictionary = data["action_days"]
	for state_id_value in action_days.keys():
		if not state_id_value is String:
			return false
		if not _is_integer_value(action_days[state_id_value]):
			return false
		var state_id := StringName(state_id_value)
		var action_day := int(action_days[state_id_value])
		if world_manager.get_state_by_id(state_id).is_empty():
			return false
		if action_day < 1:
			return false
		loaded_action_days[state_id] = action_day

	_last_action_days = loaded_action_days
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func _validate_state_and_cooldown(
	state_id: StringName,
	action_id: StringName
) -> bool:
	if world_manager.get_state_by_id(state_id).is_empty():
		_fail_action(state_id, action_id, "Государство не найдено")
		return false

	var cooldown_remaining := get_action_cooldown_remaining(state_id)
	if cooldown_remaining > 0:
		_fail_action(
			state_id,
			action_id,
			"Посланник вернётся через %d дн." % cooldown_remaining
		)
		return false
	return true


func _record_action(state_id: StringName) -> void:
	_last_action_days[state_id] = time_manager.get_absolute_day()


func _complete_action(
	state_id: StringName,
	action_id: StringName,
	relation_change: int,
	message: String
) -> void:
	diplomatic_action_completed.emit(
		state_id,
		action_id,
		relation_change,
		message
	)
	print("Diplomatic action:")
	print("State: %s" % state_id)
	print("Action: %s" % action_id)
	print("Relation change: %d" % relation_change)
	print(
		"Cooldown until day: %d"
		% (time_manager.get_absolute_day() + ACTION_COOLDOWN_DAYS)
	)


func _fail_action(
	state_id: StringName,
	action_id: StringName,
	reason: String
) -> void:
	diplomatic_action_failed.emit(state_id, action_id, reason)
