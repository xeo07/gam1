extends Node
class_name ContractManager

signal contract_signed(contract: Dictionary, message: String)
signal contract_ended(contract: Dictionary, reason: String)
signal contract_failed(state_id: StringName, reason: String)
signal contracts_changed

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _contracts: Array[Dictionary] = []


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)


func get_preview(contract_id: StringName, state_id: StringName) -> Dictionary:
	var state := world_manager.get_state_by_id(state_id)
	if state.is_empty():
		return {}
	return DiplomaticContract.get_preview(contract_id, state, world_manager.get_relation(state_id))


func propose(contract_id: StringName, state_id: StringName) -> bool:
	if has_active_contract(state_id):
		return _fail(state_id, "С этим государством уже действует договор")
	var preview := get_preview(contract_id, state_id)
	if preview.is_empty():
		return _fail(state_id, "Неизвестный договор")
	if not bool(preview["accepted"]):
		world_manager.add_relation_memory(state_id, &"rejected_contract", "корона предложила невыгодный договор", -2, 0, -2, 14)
		return _fail(state_id, String(preview["reaction"]))
	var cost := int(preview["cost"])
	if not resource_manager.remove_resource(&"gold", cost):
		return _fail(state_id, "Недостаточно золота для посольства")
	var contract := DiplomaticContract.create_active(contract_id, state_id, time_manager.get_absolute_day())
	_contracts.append(contract)
	world_manager.add_relation_memory(state_id, &"contract_signed", "корона соблюдает заключённый договор", 8, -2, 10, int(preview["duration"]))
	contract_signed.emit(contract.duplicate(true), "%s заключён до дня %d." % [String(preview["name"]), int(contract["end_day"])])
	contracts_changed.emit()
	return true


func break_contract(state_id: StringName, reason: String = "договор разорван короной") -> bool:
	for index in range(_contracts.size()):
		if _contracts[index].get("state_id", &"") == state_id and _contracts[index].get("status", &"") == &"active":
			var contract := _contracts[index]
			contract["status"] = &"broken"
			world_manager.add_relation_memory(state_id, &"contract_broken", reason, -24, 8, -18, 90)
			contract_ended.emit(contract.duplicate(true), "Договор нарушен: %s." % reason)
			contracts_changed.emit()
			return true
	return false


func has_active_contract(state_id: StringName, contract_id: StringName = &"") -> bool:
	for contract in _contracts:
		if contract.get("status", &"") == &"active" and contract.get("state_id", &"") == state_id and (contract_id == &"" or contract.get("contract_id", &"") == contract_id):
			return true
	return false


func get_active_contract(state_id: StringName) -> Dictionary:
	for contract in _contracts:
		if contract.get("status", &"") == &"active" and contract.get("state_id", &"") == state_id:
			var result := contract.duplicate(true)
			result.merge(DiplomaticContract.DEFINITIONS.get(contract.get("contract_id", &""), {}), true)
			return result
	return {}


func get_save_data() -> Dictionary:
	return {"contracts": _contracts.duplicate(true)}


func load_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		_contracts.clear()
		return true
	if not data.get("contracts", null) is Array:
		return false
	var loaded: Array[Dictionary] = []
	for value in data["contracts"]:
		if not value is Dictionary or not DiplomaticContract.DEFINITIONS.has(StringName(value.get("contract_id", ""))):
			return false
		loaded.append(value.duplicate(true))
	_contracts = loaded
	return true


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	var absolute_day := time_manager.get_absolute_day()
	for index in range(_contracts.size()):
		var contract := _contracts[index]
		if contract.get("status", &"") != &"active":
			continue
		if absolute_day >= int(contract["end_day"]):
			contract["status"] = &"expired"
			world_manager.add_relation_memory(contract["state_id"], &"contract_honored", "корона честно исполнила договор", 10, -3, 7, 45)
			contract_ended.emit(contract.duplicate(true), "Срок договора завершён; обязательства исполнены.")
			contracts_changed.emit()
			continue
		match StringName(contract["contract_id"]):
			&"trade_treaty":
				if absolute_day % 3 == 0:
					resource_manager.add_resource(&"gold", 1)
			&"military_obligation":
				if absolute_day - int(contract["last_payment_day"]) >= 7:
					if resource_manager.remove_resource(&"gold", 2):
						contract["last_payment_day"] = absolute_day
					else:
						break_contract(contract["state_id"], "корона не выполнила военное обязательство")


func _fail(state_id: StringName, reason: String) -> bool:
	contract_failed.emit(state_id, reason)
	return false
