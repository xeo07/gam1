extends Node
class_name ArmyManager

signal army_changed
signal unit_assignment_failed(citizen_id: int, reason: String)
signal equipment_changed(citizen_id: int, unit_type: StringName, equipped: bool)

const UNIT_TYPES: Array[StringName] = [
	&"militia",
	&"archer",
	&"heavy_infantry",
]
const UNIT_DISPLAY_NAMES: Dictionary = {
	&"militia": "Ополченец",
	&"archer": "Лучник",
	&"heavy_infantry": "Тяжёлый пехотинец",
}
const UNIT_EQUIPMENT: Dictionary = {
	&"archer": &"northern_bows",
	&"heavy_infantry": &"iron_weapons",
}

@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var special_goods_manager: SpecialGoodsManager = $"../SpecialGoodsManager" as SpecialGoodsManager

var _assignments: Array[Dictionary] = []
var _is_mutating: bool = false
var _is_save_loading: bool = false


func _ready() -> void:
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.citizen_updated.connect(_on_citizen_updated)
	special_goods_manager.special_goods_changed.connect(_on_special_goods_changed)


func get_available_unit_types() -> Array[StringName]:
	var unit_types_copy: Array[StringName] = []
	for unit_type in UNIT_TYPES:
		unit_types_copy.append(unit_type)
	return unit_types_copy


func get_unit_display_name(unit_type: StringName) -> String:
	return String(UNIT_DISPLAY_NAMES.get(unit_type, "Неизвестный тип войск"))


func is_valid_unit_type(unit_type: StringName) -> bool:
	return unit_type in UNIT_TYPES


func assign_unit_type(citizen_id: int, unit_type: StringName) -> bool:
	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty():
		return _fail_assignment(citizen_id, "Житель не найден")
	if citizen.get("job", &"unassigned") != &"soldier":
		return _fail_assignment(citizen_id, "Житель не является солдатом")
	if not is_valid_unit_type(unit_type):
		return _fail_assignment(citizen_id, "Неизвестный тип войск")
	if _is_citizen_locked_by_war(citizen_id):
		return _fail_assignment(citizen_id, "Боец находится в походе")

	var assignment_index := _find_assignment_index(citizen_id)
	_is_mutating = true
	if assignment_index != -1:
		_return_assignment_equipment(_assignments[assignment_index])
		_assignments[assignment_index] = _make_assignment(citizen_id, unit_type)
	else:
		_assignments.append(_make_assignment(citizen_id, unit_type))
	_is_mutating = false

	print("Army assignment:")
	print("Citizen: %d" % citizen_id)
	print("Unit type: %s" % unit_type)
	_emit_army_changed()
	return true


func remove_from_army(citizen_id: int) -> bool:
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return false
	if _is_citizen_locked_by_war(citizen_id):
		return _fail_assignment(citizen_id, "Боец находится в походе")

	_is_mutating = true
	_return_assignment_equipment(_assignments[assignment_index])
	_assignments.remove_at(assignment_index)
	_is_mutating = false
	_emit_army_changed()
	return true


func equip_unit(citizen_id: int) -> bool:
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return _fail_assignment(citizen_id, "Военное назначение не найдено")

	var assignment := _assignments[assignment_index]
	var unit_type: StringName = assignment["unit_type"]
	if unit_type == &"militia" or bool(assignment["equipped"]):
		return true
	if _is_citizen_locked_by_war(citizen_id):
		return _fail_assignment(citizen_id, "Боец находится в походе")

	var goods_id: StringName = UNIT_EQUIPMENT[unit_type]
	if not special_goods_manager.has_goods(goods_id, 1):
		var reason := (
			"Недостаточно северных луков"
			if goods_id == &"northern_bows"
			else "Недостаточно железного оружия"
		)
		return _fail_assignment(citizen_id, reason)

	_is_mutating = true
	var removed := special_goods_manager.remove_goods(goods_id, 1)
	if removed:
		_assignments[assignment_index]["equipped"] = true
	_is_mutating = false
	if not removed:
		return _fail_assignment(citizen_id, "Не удалось экипировать бойца")

	_emit_equipment_changed(citizen_id, unit_type, true)
	return true


func unequip_unit(citizen_id: int) -> bool:
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return _fail_assignment(citizen_id, "Военное назначение не найдено")

	var assignment := _assignments[assignment_index]
	var unit_type: StringName = assignment["unit_type"]
	if _is_citizen_locked_by_war(citizen_id):
		return _fail_assignment(citizen_id, "Боец находится в походе")
	if unit_type == &"militia" or not bool(assignment["equipped"]):
		return true

	_is_mutating = true
	_return_assignment_equipment(assignment)
	_assignments[assignment_index]["equipped"] = false
	_is_mutating = false
	_emit_equipment_changed(citizen_id, unit_type, false)
	return true


func remove_casualty(citizen_id: int) -> bool:
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return false
	_assignments.remove_at(assignment_index)
	_emit_army_changed()
	return true


func get_assignment(citizen_id: int) -> Dictionary:
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return {}
	return _assignments[assignment_index].duplicate(true)


func get_all_assignments() -> Array[Dictionary]:
	return _duplicate_assignments(_assignments)


func get_soldier_citizens() -> Array[Dictionary]:
	var soldiers: Array[Dictionary] = []
	for citizen in population_manager.get_all_citizens():
		if citizen.get("job", &"unassigned") == &"soldier":
			soldiers.append(citizen.duplicate(true))
	return soldiers


func get_unit_count(unit_type: StringName) -> int:
	if not is_valid_unit_type(unit_type):
		return 0
	var count := 0
	for assignment in _assignments:
		if assignment["unit_type"] == unit_type:
			count += 1
	return count


func get_equipped_unit_count(unit_type: StringName) -> int:
	if not is_valid_unit_type(unit_type):
		return 0
	var count := 0
	for assignment in _assignments:
		if assignment["unit_type"] == unit_type and bool(assignment["equipped"]):
			count += 1
	return count


func calculate_unit_strength(citizen_id: int) -> int:
	var assignment := get_assignment(citizen_id)
	if assignment.is_empty():
		return 0
	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty():
		return 0

	var unit_type: StringName = assignment["unit_type"]
	var equipped := bool(assignment["equipped"])
	var base_strength := 1
	match unit_type:
		&"militia":
			base_strength = 2
		&"archer":
			base_strength = 5 if equipped else 1
		&"heavy_infantry":
			base_strength = 7 if equipped else 1

	var attribute_bonus := (
		floori(float(citizen.get("strength", 0)) / 5.0)
		+ floori(float(citizen.get("loyalty", 0)) / 5.0)
	)
	return base_strength + attribute_bonus


func calculate_total_military_strength() -> int:
	var total_strength := 0
	for assignment in _assignments:
		total_strength += calculate_unit_strength(int(assignment["citizen_id"]))
	return total_strength


func emit_current_army() -> void:
	army_changed.emit()


func get_save_data() -> Dictionary:
	var saved_assignments: Array[Dictionary] = []
	for assignment in _assignments:
		saved_assignments.append({
			"citizen_id": int(assignment["citizen_id"]),
			"unit_type": String(assignment["unit_type"]),
			"equipped": bool(assignment["equipped"]),
		})
	return {
		"assignments": saved_assignments,
		"equipped_goods": {
			"northern_bows": get_equipped_unit_count(&"archer"),
			"iron_weapons": get_equipped_unit_count(&"heavy_infantry"),
		},
	}


func is_save_data_equipment_consistent(data: Dictionary) -> bool:
	var parsed := _parse_save_data(data, false)
	return bool(parsed.get("valid", false))


func load_save_data(data: Dictionary) -> bool:
	var parsed := _parse_save_data(data, true)
	if not bool(parsed.get("valid", false)):
		return false
	_assignments = parsed["assignments"]
	_emit_army_changed()
	return true


func begin_save_load() -> void:
	_is_save_loading = true


func end_save_load() -> void:
	_is_save_loading = false


func _parse_save_data(data: Dictionary, validate_citizens: bool) -> Dictionary:
	if not data.has_all(["assignments", "equipped_goods"]):
		return {"valid": false}
	if not data["assignments"] is Array or not data["equipped_goods"] is Dictionary:
		return {"valid": false}

	var equipped_goods: Dictionary = data["equipped_goods"]
	if equipped_goods.size() != 2:
		return {"valid": false}
	for goods_id in ["northern_bows", "iron_weapons"]:
		if not equipped_goods.has(goods_id):
			return {"valid": false}
		if not _is_integer_value(equipped_goods[goods_id]):
			return {"valid": false}
		if int(equipped_goods[goods_id]) < 0:
			return {"valid": false}
	for goods_id_value in equipped_goods.keys():
		if not goods_id_value is String:
			return {"valid": false}
		if goods_id_value not in ["northern_bows", "iron_weapons"]:
			return {"valid": false}

	var loaded_assignments: Array[Dictionary] = []
	var citizen_ids: Dictionary = {}
	var equipped_bows := 0
	var equipped_weapons := 0
	for assignment_value in data["assignments"]:
		if not assignment_value is Dictionary:
			return {"valid": false}
		var assignment: Dictionary = assignment_value
		if not assignment.has_all(["citizen_id", "unit_type", "equipped"]):
			return {"valid": false}
		if not _is_integer_value(assignment["citizen_id"]):
			return {"valid": false}
		if not assignment["unit_type"] is String or not assignment["equipped"] is bool:
			return {"valid": false}

		var citizen_id := int(assignment["citizen_id"])
		var unit_type := StringName(assignment["unit_type"])
		var equipped: bool = assignment["equipped"]
		if citizen_id < 1 or citizen_ids.has(citizen_id):
			return {"valid": false}
		if not is_valid_unit_type(unit_type):
			return {"valid": false}
		if unit_type == &"militia" and not equipped:
			return {"valid": false}
		if validate_citizens:
			var citizen := population_manager.get_citizen_by_id(citizen_id)
			if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
				return {"valid": false}

		citizen_ids[citizen_id] = true
		if equipped and unit_type == &"archer":
			equipped_bows += 1
		elif equipped and unit_type == &"heavy_infantry":
			equipped_weapons += 1
		loaded_assignments.append({
			"citizen_id": citizen_id,
			"unit_type": unit_type,
			"equipped": equipped,
		})

	if equipped_bows != int(equipped_goods["northern_bows"]):
		return {"valid": false}
	if equipped_weapons != int(equipped_goods["iron_weapons"]):
		return {"valid": false}
	return {"valid": true, "assignments": loaded_assignments}


func _on_population_changed(_total_population: int) -> void:
	if _is_save_loading:
		return
	_remove_invalid_assignments()


func _on_citizen_updated(citizen_id: int) -> void:
	if _is_save_loading:
		return
	var assignment_index := _find_assignment_index(citizen_id)
	if assignment_index == -1:
		return
	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
		if _is_citizen_locked_by_war(citizen_id) and not citizen.is_empty():
			population_manager.assign_job(citizen_id, &"soldier")
			_fail_assignment(citizen_id, "Боец находится в походе")
		else:
			remove_from_army(citizen_id)
	else:
		_emit_army_changed()


func _on_special_goods_changed(_goods: Dictionary) -> void:
	if not _is_mutating and not _is_save_loading:
		_emit_army_changed()


func _remove_invalid_assignments() -> void:
	var invalid_citizen_ids: Array[int] = []
	for assignment in _assignments:
		var citizen_id := int(assignment["citizen_id"])
		var citizen := population_manager.get_citizen_by_id(citizen_id)
		if citizen.is_empty() or citizen.get("job", &"unassigned") != &"soldier":
			invalid_citizen_ids.append(citizen_id)
	if invalid_citizen_ids.is_empty():
		return

	_is_mutating = true
	for citizen_id in invalid_citizen_ids:
		var assignment_index := _find_assignment_index(citizen_id)
		if assignment_index == -1:
			continue
		_return_assignment_equipment(_assignments[assignment_index])
		_assignments.remove_at(assignment_index)
	_is_mutating = false
	_emit_army_changed()


func _return_assignment_equipment(assignment: Dictionary) -> void:
	if not bool(assignment.get("equipped", false)):
		return
	var unit_type: StringName = assignment.get("unit_type", &"")
	if UNIT_EQUIPMENT.has(unit_type):
		special_goods_manager.add_goods(UNIT_EQUIPMENT[unit_type], 1)


func _make_assignment(citizen_id: int, unit_type: StringName) -> Dictionary:
	return {
		"citizen_id": citizen_id,
		"unit_type": unit_type,
		"equipped": unit_type == &"militia",
	}


func _find_assignment_index(citizen_id: int) -> int:
	for index in _assignments.size():
		if int(_assignments[index]["citizen_id"]) == citizen_id:
			return index
	return -1


func _is_citizen_locked_by_war(citizen_id: int) -> bool:
	var war_manager := get_tree().get_first_node_in_group("war_manager")
	if war_manager == null or not war_manager.has_method("is_citizen_on_campaign"):
		return false
	return bool(war_manager.call("is_citizen_on_campaign", citizen_id))


func _duplicate_assignments(assignments: Array[Dictionary]) -> Array[Dictionary]:
	var assignments_copy: Array[Dictionary] = []
	for assignment in assignments:
		assignments_copy.append(assignment.duplicate(true))
	return assignments_copy


func _fail_assignment(citizen_id: int, reason: String) -> bool:
	unit_assignment_failed.emit(citizen_id, reason)
	return false


func _emit_equipment_changed(
	citizen_id: int,
	unit_type: StringName,
	equipped: bool
) -> void:
	equipment_changed.emit(citizen_id, unit_type, equipped)
	print("Army equipment:")
	print("Citizen: %d" % citizen_id)
	print("Unit type: %s" % unit_type)
	print("Equipped: %s" % str(equipped))
	_emit_army_changed()


func _emit_army_changed() -> void:
	emit_current_army()
	print("Army summary:")
	print("Soldiers assigned: %d" % _assignments.size())
	print("Military strength: %d" % calculate_total_military_strength())


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
