extends Node
class_name TerritoryManager

signal territory_acquired(territory: Dictionary, message: String)
signal territory_reported(report: Dictionary)
signal territories_changed

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var war_manager: WarManager = $"../WarManager" as WarManager
@onready var contract_manager: ContractManager = $"../ContractManager" as ContractManager
@onready var story_chain_manager: StoryChainManager = $"../StoryChainManager" as StoryChainManager

var _territories: Array[Dictionary] = []


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)
	war_manager.campaign_completed.connect(_on_campaign_completed)
	contract_manager.contract_ended.connect(_on_contract_ended)
	story_chain_manager.chain_completed.connect(_on_chain_completed)


func acquire(source: StringName, origin_state_id: StringName = &"") -> bool:
	var territory_id := StringName("%s:%s" % [source, String(origin_state_id) if origin_state_id != &"" else "capital"])
	for territory in _territories:
		if territory.get("id", &"") == territory_id:
			return false
	var name := _build_name(source, origin_state_id)
	var territory := TerritoryData.create(territory_id, name, source, origin_state_id, time_manager.get_absolute_day())
	_territories.append(territory)
	var stability_cost := -4 if source == &"war" else -2
	stability_manager.apply_external_change(stability_cost, "Присоединение территории: %s" % name)
	var message := "%s вошла в состав королевства. Доход: %d золота, снабжение: %d еды каждые 5 дней." % [name, int(territory["gold_income"]), int(territory["food_supply"])]
	territory_acquired.emit(territory.duplicate(true), message)
	territories_changed.emit()
	return true


func get_territories() -> Array[Dictionary]:
	return _territories.duplicate(true)


func get_summary() -> String:
	if _territories.is_empty():
		return "Территории: только коронные земли"
	var names: Array[String] = []
	for territory in _territories:
		names.append(String(territory["name"]))
	return "Территории (%d): %s" % [_territories.size(), ", ".join(PackedStringArray(names))]


func get_save_data() -> Dictionary:
	return {"territories": _territories.duplicate(true)}


func load_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		_territories.clear()
		return true
	if not data.get("territories", null) is Array:
		return false
	var loaded: Array[Dictionary] = []
	for value in data["territories"]:
		if not value is Dictionary or not TerritoryData.is_valid(value):
			return false
		loaded.append(value.duplicate(true))
	_territories = loaded
	return true


func _on_campaign_completed(report: Dictionary) -> void:
	if report.get("result", &"") in [&"victory", &"decisive_victory"]:
		acquire(&"war", StringName(report.get("state_id", &"")))


func _on_contract_ended(contract: Dictionary, _reason: String) -> void:
	if contract.get("status", &"") == &"expired" and contract.get("contract_id", &"") == &"trade_treaty":
		acquire(&"treaty", StringName(contract.get("state_id", &"")))


func _on_chain_completed(chain_id: StringName, choice_id: StringName, _effects: Dictionary) -> void:
	if chain_id == &"political_unrest" and choice_id == &"public_inquiry":
		acquire(&"crisis")


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	if _territories.is_empty() or time_manager.get_absolute_day() % 5 != 0:
		return
	var income := 0
	var supply := 0
	var unrest := 0
	for territory in _territories:
		income += int(territory["gold_income"])
		supply += int(territory["food_supply"])
		unrest += int(territory["unrest"])
	var supplied := resource_manager.remove_resource(&"food", supply)
	if supplied:
		resource_manager.add_resource(&"gold", income)
	else:
		unrest += 2
	var stability_change := stability_manager.apply_external_change(-unrest, "Содержание присоединённых территорий") if unrest > 0 else 0
	territory_reported.emit({"day": time_manager.get_absolute_day(), "income": income if supplied else 0, "supply": supply if supplied else 0, "stability": stability_change, "supplied": supplied})


func _build_name(source: StringName, state_id: StringName) -> String:
	var state := world_manager.get_state_by_id(state_id)
	var state_name := String(state.get("name", "соседней державы"))
	match source:
		&"war": return "Пограничная провинция %s" % state_name
		&"treaty": return "Торговая фактория %s" % state_name
		_: return "Возвращённые земли заговорщиков"
