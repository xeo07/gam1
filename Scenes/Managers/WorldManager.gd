extends Node
class_name WorldManager

signal states_changed
signal state_updated(state_id: StringName, changes: Dictionary)
signal world_day_processed(
	absolute_day: int,
	updates: Array[Dictionary]
)

const EXPECTED_STATE_IDS: Array[StringName] = [
	&"northrealm",
	&"suncoast",
	&"ironclan",
]
const VALID_STATUSES: Array[StringName] = [
	&"neutral",
	&"ally",
	&"enemy",
	&"war",
]

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager

var _latest_world_updates: Array[Dictionary] = []
var _last_processed_absolute_day: int
var _initialized := false

const INITIAL_STATES: Array[Dictionary] = [
	{
		"id": &"northrealm",
		"name": "Северное королевство",
		"ruler_name": "Король Эдгар",
		"population": 120,
		"military_strength": 65,
		"wealth": 40,
		"stability": 80,
		"relation": 10,
		"status": &"neutral",
	},
	{
		"id": &"suncoast",
		"name": "Солнечный берег",
		"ruler_name": "Королева Мирра",
		"population": 90,
		"military_strength": 35,
		"wealth": 85,
		"stability": 70,
		"relation": 25,
		"status": &"neutral",
	},
	{
		"id": &"ironclan",
		"name": "Железный клан",
		"ruler_name": "Вождь Гром",
		"population": 75,
		"military_strength": 90,
		"wealth": 30,
		"stability": 55,
		"relation": -20,
		"status": &"neutral",
	},
]

var _states: Array[Dictionary] = []


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)
	print("WorldManager initialized.")


func initialize_new_game() -> void:
	if _initialized or not game_session_manager.is_initialized():
		return
	_states.clear()
	for state in INITIAL_STATES:
		_states.append(state.duplicate(true))
	_latest_world_updates.clear()
	_last_processed_absolute_day = time_manager.get_absolute_day()
	_initialized = true
	print("Loaded states: %d" % _states.size())
	for state in _states:
		_print_state(state)
	emit_states_changed()


func get_all_states() -> Array[Dictionary]:
	var states_copy: Array[Dictionary] = []
	for state in _states:
		states_copy.append(state.duplicate(true))
	return states_copy


func get_state_by_id(state_id: StringName) -> Dictionary:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return {}
	return _states[state_index].duplicate(true)


func process_world_day() -> Array[Dictionary]:
	if not _initialized or not game_session_manager.is_initialized():
		return []
	var absolute_day := time_manager.get_absolute_day()
	if absolute_day <= _last_processed_absolute_day:
		return []
	_last_processed_absolute_day = absolute_day

	var updates: Array[Dictionary] = []
	for state in _states:
		var previous_population := int(state["population"])
		var previous_military := int(state["military_strength"])
		var previous_wealth := int(state["wealth"])
		var previous_stability := int(state["stability"])

		state["population"] = maxi(
			10,
			previous_population + game_session_manager.get_rng().randi_range(-2, 3)
		)
		state["military_strength"] = clampi(
			previous_military + game_session_manager.get_rng().randi_range(-2, 2),
			0,
			100
		)
		state["wealth"] = clampi(
			previous_wealth + game_session_manager.get_rng().randi_range(-3, 4),
			0,
			100
		)
		state["stability"] = clampi(
			previous_stability + game_session_manager.get_rng().randi_range(-3, 3),
			0,
			100
		)

		var state_id: StringName = state.get("id", &"")
		var changes: Dictionary = {
			"state_id": state_id,
			"state_name": String(state.get("name", "")),
			"population_change": int(state["population"]) - previous_population,
			"military_change": int(state["military_strength"]) - previous_military,
			"wealth_change": int(state["wealth"]) - previous_wealth,
			"stability_change": int(state["stability"]) - previous_stability,
			"population": int(state["population"]),
			"military_strength": int(state["military_strength"]),
			"wealth": int(state["wealth"]),
			"stability": int(state["stability"]),
		}
		updates.append(changes)
		state_updated.emit(state_id, changes.duplicate(true))

	_latest_world_updates = _duplicate_updates(updates)
	emit_states_changed()
	world_day_processed.emit(
		absolute_day,
		_duplicate_updates(updates)
	)
	_print_world_updates(absolute_day, updates)
	return _duplicate_updates(updates)


func get_latest_world_updates() -> Array[Dictionary]:
	return _duplicate_updates(_latest_world_updates)


func get_save_data() -> Dictionary:
	var states: Array[Dictionary] = []
	for state in _states:
		states.append({
			"id": String(state.get("id", &"")),
			"name": String(state.get("name", "")),
			"ruler_name": String(state.get("ruler_name", "")),
			"population": int(state.get("population", 10)),
			"military_strength": int(state.get("military_strength", 0)),
			"wealth": int(state.get("wealth", 0)),
			"stability": int(state.get("stability", 0)),
			"relation": int(state.get("relation", 0)),
			"status": String(state.get("status", &"neutral")),
		})

	var latest_updates: Array[Dictionary] = []
	for update in _latest_world_updates:
		var saved_update := update.duplicate(true)
		saved_update["state_id"] = String(update.get("state_id", &""))
		latest_updates.append(saved_update)

	return {
		"states": states,
		"last_processed_absolute_day": _last_processed_absolute_day,
		"latest_world_updates": latest_updates,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all([
		"states",
		"last_processed_absolute_day",
		"latest_world_updates",
	]):
		return false
	if not data["states"] is Array:
		return false
	if not data["latest_world_updates"] is Array:
		return false
	if not _is_integer_value(data["last_processed_absolute_day"]):
		return false
	if data["states"].size() != EXPECTED_STATE_IDS.size():
		return false

	var loaded_states: Array[Dictionary] = []
	var state_ids: Dictionary = {}
	for state_value in data["states"]:
		if not state_value is Dictionary:
			return false
		var state: Dictionary = state_value
		if not state.has_all([
			"id",
			"name",
			"ruler_name",
			"population",
			"military_strength",
			"wealth",
			"stability",
			"relation",
			"status",
		]):
			return false
		for string_field in ["id", "name", "ruler_name", "status"]:
			if not state[string_field] is String:
				return false
		for numeric_field in [
			"population",
			"military_strength",
			"wealth",
			"stability",
			"relation",
		]:
			if not _is_integer_value(state[numeric_field]):
				return false

		var state_id := StringName(state["id"])
		var population := int(state["population"])
		var military_strength := int(state["military_strength"])
		var wealth := int(state["wealth"])
		var stability := int(state["stability"])
		var relation := int(state["relation"])
		var status := StringName(state["status"])
		if state_id == &"" or state_ids.has(state_id):
			return false
		if population < 10:
			return false
		if military_strength < 0 or military_strength > 100:
			return false
		if wealth < 0 or wealth > 100:
			return false
		if stability < 0 or stability > 100:
			return false
		if relation < -100 or relation > 100:
			return false
		if status not in VALID_STATUSES:
			return false

		state_ids[state_id] = true
		loaded_states.append({
			"id": state_id,
			"name": String(state["name"]),
			"ruler_name": String(state["ruler_name"]),
			"population": population,
			"military_strength": military_strength,
			"wealth": wealth,
			"stability": stability,
			"relation": relation,
			"status": status,
		})

	for expected_state_id in EXPECTED_STATE_IDS:
		if not state_ids.has(expected_state_id):
			return false

	var loaded_updates: Array[Dictionary] = []
	for update_value in data["latest_world_updates"]:
		if not update_value is Dictionary:
			return false
		var update: Dictionary = update_value
		if not update.has_all([
			"state_id",
			"state_name",
			"population_change",
			"military_change",
			"wealth_change",
			"stability_change",
			"population",
			"military_strength",
			"wealth",
			"stability",
		]):
			return false
		if not update["state_id"] is String:
			return false
		if not update["state_name"] is String:
			return false
		for numeric_field in [
			"population_change",
			"military_change",
			"wealth_change",
			"stability_change",
			"population",
			"military_strength",
			"wealth",
			"stability",
		]:
			if not _is_integer_value(update[numeric_field]):
				return false
		if not state_ids.has(StringName(update["state_id"])):
			return false
		var loaded_update := update.duplicate(true)
		loaded_update["state_id"] = StringName(update["state_id"])
		for numeric_field in [
			"population_change",
			"military_change",
			"wealth_change",
			"stability_change",
			"population",
			"military_strength",
			"wealth",
			"stability",
		]:
			loaded_update[numeric_field] = int(update[numeric_field])
		loaded_updates.append(loaded_update)

	var loaded_last_day := int(data["last_processed_absolute_day"])
	if loaded_last_day < 1:
		return false

	_states = loaded_states
	_latest_world_updates = loaded_updates
	_last_processed_absolute_day = loaded_last_day
	_initialized = true
	emit_states_changed()
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func get_relation(state_id: StringName) -> int:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return 0
	return int(_states[state_index]["relation"])


func change_state_wealth(state_id: StringName, amount: int) -> bool:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false

	var current_wealth := int(_states[state_index]["wealth"])
	_states[state_index]["wealth"] = clampi(current_wealth + amount, 0, 100)
	emit_states_changed()
	return true


func can_state_pay(state_id: StringName, amount: int) -> bool:
	if amount < 0:
		return false
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false
	return int(_states[state_index]["wealth"]) >= amount


func set_relation(state_id: StringName, value: int) -> bool:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false

	_states[state_index]["relation"] = clampi(value, -100, 100)
	emit_states_changed()
	return true


func change_relation(state_id: StringName, amount: int) -> bool:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false

	var new_relation := int(_states[state_index]["relation"]) + amount
	_states[state_index]["relation"] = clampi(new_relation, -100, 100)
	emit_states_changed()
	return true


func set_state_status(state_id: StringName, status: StringName) -> bool:
	if status not in VALID_STATUSES:
		return false
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false
	_states[state_index]["status"] = status
	emit_states_changed()
	return true


func set_state_relation_and_status(
	state_id: StringName,
	relation: int,
	status: StringName
) -> bool:
	if status not in VALID_STATUSES:
		return false
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false
	_states[state_index]["relation"] = clampi(relation, -100, 100)
	_states[state_index]["status"] = status
	emit_states_changed()
	return true


func apply_war_result(
	state_id: StringName,
	military_change: int,
	wealth_change: int,
	stability_change: int,
	population_change: int
) -> bool:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false
	var state := _states[state_index]
	state["military_strength"] = clampi(
		int(state["military_strength"]) + military_change,
		0,
		100
	)
	state["wealth"] = clampi(int(state["wealth"]) + wealth_change, 0, 100)
	state["stability"] = clampi(
		int(state["stability"]) + stability_change,
		0,
		100
	)
	state["population"] = maxi(10, int(state["population"]) + population_change)
	emit_states_changed()
	return true


func emit_states_changed() -> void:
	states_changed.emit()


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	process_world_day()


func _duplicate_updates(updates: Array[Dictionary]) -> Array[Dictionary]:
	var updates_copy: Array[Dictionary] = []
	for update in updates:
		updates_copy.append(update.duplicate(true))
	return updates_copy


func _find_state_index(state_id: StringName) -> int:
	for index in _states.size():
		if _states[index]["id"] == state_id:
			return index
	return -1


func _print_state(state: Dictionary) -> void:
	var state_text := (
		"State %s: %s | ruler=%s, population=%d, military=%d, "
		+ "wealth=%d, stability=%d, relation=%d, status=%s"
	) % [
		state["id"],
		state["name"],
		state["ruler_name"],
		state["population"],
		state["military_strength"],
		state["wealth"],
		state["stability"],
		state["relation"],
		state["status"],
	]
	print(state_text)


func _print_world_updates(
	absolute_day: int,
	updates: Array[Dictionary]
) -> void:
	print("World day processed: %d" % absolute_day)
	for update in updates:
		print("")
		print("State: %s" % update["state_id"])
		print("Population change: %d" % update["population_change"])
		print("Military change: %d" % update["military_change"])
		print("Wealth change: %d" % update["wealth_change"])
		print("Stability change: %d" % update["stability_change"])
