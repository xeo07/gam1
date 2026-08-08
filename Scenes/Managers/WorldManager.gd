extends Node
class_name WorldManager

signal states_changed
signal state_updated(state_id: StringName, changes: Dictionary)
signal world_day_processed(
	absolute_day: int,
	updates: Array[Dictionary]
)
signal world_event_occurred(event: Dictionary)

const LEGACY_STATE_IDS: Array[StringName] = [
	&"northrealm",
	&"suncoast",
	&"ironclan",
]
const EXPECTED_STATE_IDS: Array[StringName] = WorldGenerator.AI_STATE_IDS
const VALID_STATUSES: Array[StringName] = StateData.VALID_STATUSES

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager

var _latest_world_updates: Array[Dictionary] = []
var _world_events: Array[Dictionary] = []
var _intelligence: Dictionary = {}
var _last_processed_absolute_day: int
var _initialized := false

var _states: Array[Dictionary] = []


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)
	print("WorldManager initialized.")


func initialize_new_game() -> void:
	if _initialized or not game_session_manager.is_initialized():
		return
	_states = WorldGenerator.generate_states(game_session_manager.get_world_seed())
	_latest_world_updates.clear()
	_world_events.clear()
	_last_processed_absolute_day = time_manager.get_absolute_day()
	_initialize_intelligence(_last_processed_absolute_day)
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


func get_observed_state_by_id(state_id: StringName) -> Dictionary:
	var state := get_state_by_id(state_id)
	if state.is_empty() or not _intelligence.has(state_id):
		return {}
	return StateObservation.create_view(
		state, _intelligence[state_id], time_manager.get_absolute_day()
	)


func get_all_observed_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in _states:
		var state_id := StringName(state.get("id", &""))
		result.append(StateObservation.create_view(
			state, _intelligence.get(state_id, {}), time_manager.get_absolute_day()
		))
	return result


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
		var previous_relation := int(state["relation"])
		var personality := StringName(state.get("personality", &"traditionalist"))
		var bias := StatePersonality.get_daily_bias(personality)

		state["population"] = maxi(
			10,
			previous_population
				+ game_session_manager.get_rng().randi_range(-2, 3)
				+ int(bias.get("population", 0))
		)
		state["military_strength"] = clampi(
			previous_military
				+ game_session_manager.get_rng().randi_range(-2, 2)
				+ int(bias.get("military", 0)),
			0,
			100
		)
		state["wealth"] = clampi(
			previous_wealth
				+ game_session_manager.get_rng().randi_range(-3, 4)
				+ int(bias.get("wealth", 0)),
			0,
			100
		)
		state["stability"] = clampi(
			previous_stability
				+ game_session_manager.get_rng().randi_range(-3, 3)
				+ int(bias.get("stability", 0)),
			0,
			100
		)
		var relation_bias := int(bias.get("relation", 0))
		state["relation_profile"] = RelationProfile.adjust_base(
			state.get("relation_profile", {}), relation_bias, 0, relation_bias
		)
		_sync_relation(state, absolute_day)

		var state_id: StringName = state.get("id", &"")
		var changes: Dictionary = {
			"state_id": state_id,
			"state_name": String(state.get("name", "")),
			"population_change": int(state["population"]) - previous_population,
			"military_change": int(state["military_strength"]) - previous_military,
			"wealth_change": int(state["wealth"]) - previous_wealth,
			"stability_change": int(state["stability"]) - previous_stability,
			"relation_change": int(state["relation"]) - previous_relation,
			"population": int(state["population"]),
			"military_strength": int(state["military_strength"]),
			"wealth": int(state["wealth"]),
			"stability": int(state["stability"]),
			"relation": int(state["relation"]),
			"strategic_goal": state.get("strategic_goal", &"continuity"),
		}
		updates.append(changes)
		state_updated.emit(state_id, changes.duplicate(true))

	var world_event := WorldEventGenerator.try_generate_event(
		_states, absolute_day, game_session_manager.get_rng()
	)
	if not world_event.is_empty():
		_apply_world_event(world_event, updates)
		_world_events.append(world_event.duplicate(true))
		if _world_events.size() > WorldEventGenerator.MAX_EVENT_HISTORY:
			_world_events.pop_front()
		world_event_occurred.emit(world_event.duplicate(true))

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


func get_world_events() -> Array[Dictionary]:
	return _duplicate_updates(_world_events)


func get_intelligence(state_id: StringName) -> Dictionary:
	if not _intelligence.has(state_id):
		return {}
	var record: Dictionary = _intelligence[state_id]
	var result := record.duplicate(true)
	result["age_days"] = StateIntelligence.get_age(record, time_manager.get_absolute_day())
	result["effective_level"] = StateIntelligence.get_effective_level(
		record, time_manager.get_absolute_day()
	)
	result["freshness"] = StateIntelligence.get_freshness(
		record, time_manager.get_absolute_day()
	)
	return result


func improve_intelligence(
	state_id: StringName,
	level: int,
	source: StringName
) -> bool:
	if _find_state_index(state_id) == -1 or not _intelligence.has(state_id):
		return false
	_intelligence[state_id] = StateIntelligence.improve(
		_intelligence[state_id], level, time_manager.get_absolute_day(), source
	)
	return true


func get_save_data() -> Dictionary:
	var states: Array[Dictionary] = []
	for state in _states:
		states.append(StateData.to_save_data(state))

	var latest_updates: Array[Dictionary] = []
	for update in _latest_world_updates:
		var saved_update := update.duplicate(true)
		saved_update["state_id"] = String(update.get("state_id", &""))
		latest_updates.append(saved_update)
	var world_events: Array[Dictionary] = []
	for event in _world_events:
		world_events.append(WorldEventGenerator.to_save_data(event))
	var intelligence: Array[Dictionary] = []
	for state_id in _intelligence:
		intelligence.append(StateIntelligence.to_save_data(_intelligence[state_id]))

	return {
		"states": states,
		"last_processed_absolute_day": _last_processed_absolute_day,
		"latest_world_updates": latest_updates,
		"world_events": world_events,
		"intelligence": intelligence,
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
	if (
		data["states"].size() != WorldGenerator.AI_STATE_IDS.size()
		and data["states"].size() != LEGACY_STATE_IDS.size()
	):
		return false

	var loaded_states: Array[Dictionary] = []
	var state_ids: Dictionary = {}
	for state_value in data["states"]:
		var parsed_state := StateData.parse_save_data(state_value)
		if not bool(parsed_state.get("valid", false)):
			return false
		var state: Dictionary = parsed_state["state"]
		var state_id: StringName = state["id"]
		if state_ids.has(state_id):
			return false
		state_ids[state_id] = true
		loaded_states.append(state)

	var expected_state_ids := (
		WorldGenerator.AI_STATE_IDS
		if loaded_states.size() == WorldGenerator.AI_STATE_IDS.size()
		else LEGACY_STATE_IDS
	)
	for expected_state_id in expected_state_ids:
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

	var loaded_events: Array[Dictionary] = []
	var saved_events: Variant = data.get("world_events", [])
	if not saved_events is Array:
		return false
	for event_value in saved_events:
		var parsed_event := WorldEventGenerator.parse_save_data(event_value)
		if not bool(parsed_event.get("valid", false)):
			return false
		var loaded_event: Dictionary = parsed_event["event"]
		if not state_ids.has(loaded_event["state_id"]):
			return false
		loaded_events.append(loaded_event)
	if loaded_events.size() > WorldEventGenerator.MAX_EVENT_HISTORY:
		return false

	var loaded_intelligence: Dictionary = {}
	var saved_intelligence: Variant = data.get("intelligence", [])
	if not saved_intelligence is Array:
		return false
	for intelligence_value in saved_intelligence:
		var parsed_intelligence := StateIntelligence.parse_save_data(intelligence_value)
		if not bool(parsed_intelligence.get("valid", false)):
			return false
		var record: Dictionary = parsed_intelligence["record"]
		var intelligence_state_id: StringName = record["state_id"]
		if not state_ids.has(intelligence_state_id) or loaded_intelligence.has(intelligence_state_id):
			return false
		loaded_intelligence[intelligence_state_id] = record
	if not loaded_intelligence.is_empty() and loaded_intelligence.size() != loaded_states.size():
		return false

	var loaded_last_day := int(data["last_processed_absolute_day"])
	if loaded_last_day < 1:
		return false

	_states = loaded_states
	for state in _states:
		_sync_relation(state, loaded_last_day)
	_latest_world_updates = loaded_updates
	_world_events = loaded_events
	_intelligence = loaded_intelligence
	_last_processed_absolute_day = loaded_last_day
	if _intelligence.is_empty():
		_initialize_intelligence(loaded_last_day, &"legacy_rumor")
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


func get_relation_components(state_id: StringName) -> Dictionary:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return {}
	return RelationProfile.get_components(
		_states[state_index].get("relation_profile", {}),
		time_manager.get_absolute_day()
	)


func get_relation_reasons(state_id: StringName) -> Array[String]:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return []
	return RelationProfile.get_reason_lines(
		_states[state_index].get("relation_profile", {}),
		time_manager.get_absolute_day()
	)


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

	_states[state_index]["relation_profile"] = RelationProfile.create_from_legacy(value)
	_sync_relation(_states[state_index], time_manager.get_absolute_day())
	emit_states_changed()
	return true


func change_relation(state_id: StringName, amount: int) -> bool:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return false

	_states[state_index]["relation_profile"] = RelationProfile.adjust_base(
		_states[state_index].get("relation_profile", {}), amount, 0, amount
	)
	_sync_relation(_states[state_index], time_manager.get_absolute_day())
	emit_states_changed()
	return true


func add_relation_memory(
	state_id: StringName,
	memory_id: StringName,
	summary: String,
	trust_change: int,
	fear_change: int,
	benefit_change: int,
	duration_days: int = RelationProfile.DEFAULT_MEMORY_DURATION_DAYS
) -> int:
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return 0
	var previous_relation := int(_states[state_index]["relation"])
	var absolute_day := time_manager.get_absolute_day()
	_states[state_index]["relation_profile"] = RelationProfile.add_memory(
		_states[state_index].get("relation_profile", {}),
		"%s:%d" % [String(memory_id), absolute_day],
		absolute_day,
		summary,
		trust_change,
		fear_change,
		benefit_change,
		duration_days
	)
	_sync_relation(_states[state_index], absolute_day)
	emit_states_changed()
	return int(_states[state_index]["relation"]) - previous_relation


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
	_states[state_index]["relation_profile"] = RelationProfile.create_from_legacy(relation)
	_sync_relation(_states[state_index], time_manager.get_absolute_day())
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


func _sync_relation(state: Dictionary, absolute_day: int) -> void:
	var profile: Dictionary = state.get(
		"relation_profile",
		RelationProfile.create_from_legacy(int(state.get("relation", 0)))
	)
	state["relation_profile"] = RelationProfile.prune_expired(profile, absolute_day)
	state["relation"] = RelationProfile.get_score(state["relation_profile"], absolute_day)


func _apply_world_event(event: Dictionary, updates: Array[Dictionary]) -> void:
	var state_id := StringName(event.get("state_id", &""))
	var state_index := _find_state_index(state_id)
	if state_index == -1:
		return
	WorldEventGenerator.apply_event(_states[state_index], event)
	var effects: Dictionary = event.get("effects", {})
	for update in updates:
		if update.get("state_id", &"") != state_id:
			continue
		for field in ["population", "military_strength", "wealth", "stability", "relation"]:
			var change_field := (
				"military_change" if field == "military_strength" else "%s_change" % field
			)
			update[change_field] = int(update.get(change_field, 0)) + int(effects.get(field, 0))
			update[field] = int(_states[state_index].get(field, 0))
		update["event"] = event.duplicate(true)
		break


func _initialize_intelligence(
	absolute_day: int,
	source: StringName = &"world_start"
) -> void:
	_intelligence.clear()
	for state in _states:
		var state_id := StringName(state.get("id", &""))
		_intelligence[state_id] = StateIntelligence.create(
			state_id, StateIntelligence.LEVEL_RUMORS, absolute_day, source
		)


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
