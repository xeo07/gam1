extends Node
class_name StoryChainManager

signal chain_started(chain_id: StringName)
signal chain_developed(chain_id: StringName, choice_id: StringName)
signal chain_completed(chain_id: StringName, choice_id: StringName, effects: Dictionary)

const FIRST_CHAIN_DAY := 4
const DEVELOPMENT_DELAY_DAYS := 2
const CONSEQUENCE_DELAY_DAYS := 2
const NEXT_CHAIN_DELAY_DAYS := 8
const VALID_PHASES: Array[StringName] = [
	&"idle", &"awaiting_choice", &"waiting_development", &"waiting_consequence",
]

@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var event_manager: EventManager = $"../EventManager" as EventManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var event_journal_manager: EventJournalManager = $"../EventJournalManager" as EventJournalManager

var _initialized := false
var _chain_order: Array[StringName] = []
var _chain_index := 0
var _phase: StringName = &"idle"
var _active_chain: StringName = &""
var _selected_choice: StringName = &""
var _target_state_id: StringName = &""
var _development_day := 0
var _consequence_day := 0
var _next_chain_day := FIRST_CHAIN_DAY
var _sequence := 0
var _choice_deadline_day := 0


func _ready() -> void:
	time_manager.day_changed.connect(_on_day_changed)
	event_manager.internal_event_resolved.connect(_on_internal_event_resolved)


func initialize_new_game() -> void:
	_initialize_for_seed(game_session_manager.get_world_seed(), FIRST_CHAIN_DAY)


func get_phase() -> StringName:
	return _phase


func get_active_chain() -> StringName:
	return _active_chain


func get_selected_choice() -> StringName:
	return _selected_choice


func get_choice_deadline_day() -> int:
	return _choice_deadline_day


func get_chain_order() -> Array[StringName]:
	return _chain_order.duplicate()


func get_save_data() -> Dictionary:
	var saved_order: Array[String] = []
	for chain_id in _chain_order:
		saved_order.append(String(chain_id))
	return {
		"initialized": _initialized,
		"chain_order": saved_order,
		"chain_index": _chain_index,
		"phase": String(_phase),
		"active_chain": String(_active_chain),
		"selected_choice": String(_selected_choice),
		"target_state_id": String(_target_state_id),
		"development_day": _development_day,
		"consequence_day": _consequence_day,
		"next_chain_day": _next_chain_day,
		"sequence": _sequence,
		"choice_deadline_day": _choice_deadline_day,
	}


func load_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		_initialize_for_seed(
			game_session_manager.get_world_seed(),
			time_manager.get_absolute_day() + 3
		)
		return true
	if not data.has_all([
		"initialized", "chain_order", "chain_index", "phase", "active_chain",
		"selected_choice", "target_state_id", "development_day", "consequence_day",
		"next_chain_day", "sequence",
	]):
		return false
	if not data["initialized"] is bool or not data["chain_order"] is Array:
		return false
	for field in ["phase", "active_chain", "selected_choice", "target_state_id"]:
		if not data[field] is String:
			return false
	for field in [
		"chain_index", "development_day", "consequence_day", "next_chain_day", "sequence",
	]:
		if not _is_integer(data[field]) or int(data[field]) < 0:
			return false
	var loaded_order: Array[StringName] = []
	var unique: Dictionary = {}
	for value in data["chain_order"]:
		if not value is String:
			return false
		var chain_id := StringName(value)
		if chain_id not in StoryChainDefinition.CHAIN_IDS or unique.has(chain_id):
			return false
		unique[chain_id] = true
		loaded_order.append(chain_id)
	if loaded_order.size() == StoryChainDefinition.CHAIN_IDS.size() - 1 and &"political_unrest" not in loaded_order:
		loaded_order.append(&"political_unrest")
	if loaded_order.size() != StoryChainDefinition.CHAIN_IDS.size():
		return false
	var loaded_index := int(data["chain_index"])
	if loaded_index >= loaded_order.size():
		return false
	var loaded_phase := StringName(data["phase"])
	var loaded_chain := StringName(data["active_chain"])
	var loaded_choice := StringName(data["selected_choice"])
	if loaded_phase not in VALID_PHASES:
		return false
	if loaded_phase == &"idle" and (loaded_chain != &"" or loaded_choice != &""):
		return false
	if loaded_phase != &"idle" and loaded_chain not in StoryChainDefinition.CHAIN_IDS:
		return false
	if loaded_phase in [&"waiting_development", &"waiting_consequence"]:
		if not _is_choice_for_chain(loaded_chain, loaded_choice):
			return false
	_chain_order = loaded_order
	_chain_index = loaded_index
	_phase = loaded_phase
	_active_chain = loaded_chain
	_selected_choice = loaded_choice
	_target_state_id = StringName(data["target_state_id"])
	_development_day = int(data["development_day"])
	_consequence_day = int(data["consequence_day"])
	_next_chain_day = int(data["next_chain_day"])
	_sequence = int(data["sequence"])
	_choice_deadline_day = int(data.get("choice_deadline_day", 0))
	_initialized = bool(data["initialized"])
	return true


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	if not _initialized:
		return
	var absolute_day := time_manager.get_absolute_day()
	if _phase == &"awaiting_choice" and _choice_deadline_day > 0 and absolute_day >= _choice_deadline_day:
		event_manager.resolve_choice(&"ignore_unrest")
		return
	if _phase == &"waiting_development" and absolute_day >= _development_day:
		_publish_development(absolute_day)
		return
	if _phase == &"waiting_consequence" and absolute_day >= _consequence_day:
		_publish_consequence(absolute_day)
		return
	if _phase != &"idle" or absolute_day < _next_chain_day:
		return
	_start_next_chain(absolute_day)


func _on_internal_event_resolved(result: Dictionary) -> void:
	if _phase != &"awaiting_choice":
		return
	var event_id := StringName(result.get("event_id", &""))
	if StoryChainDefinition.chain_from_event(event_id) != _active_chain:
		return
	var choice_id := StringName(result.get("choice_id", &""))
	if not _is_choice_for_chain(_active_chain, choice_id):
		return
	_selected_choice = choice_id
	var absolute_day := time_manager.get_absolute_day()
	_development_day = absolute_day + DEVELOPMENT_DELAY_DAYS
	_consequence_day = _development_day + CONSEQUENCE_DELAY_DAYS
	_phase = &"waiting_development"
	_choice_deadline_day = 0
	_add_journal_entry(
		absolute_day,
		"Решение принято: %s" % String(result.get("event_title", "")),
		String(result.get("result_text", "")),
		2,
		{"stage": "warning", "choice": String(choice_id)}
	)


func _start_next_chain(absolute_day: int) -> void:
	_active_chain = _chain_order[_chain_index]
	_selected_choice = &""
	_target_state_id = _choose_target_state(_chain_index)
	var event_id: StringName = StoryChainDefinition.EVENT_IDS[_active_chain]
	if not event_manager.present_story_event(event_id):
		_active_chain = &""
		_target_state_id = &""
		_next_chain_day = absolute_day + 1
		return
	_phase = &"awaiting_choice"
	_choice_deadline_day = absolute_day + 3 if _active_chain == &"political_unrest" else 0
	var warning := StoryChainDefinition.get_warning(_active_chain)
	_add_journal_entry(
		absolute_day,
		"Предупреждение: %s" % String(warning.get("title", "")),
		String(warning.get("body", "")),
		2,
		{"stage": "warning"}
	)
	chain_started.emit(_active_chain)


func _publish_development(absolute_day: int) -> void:
	var development := StoryChainDefinition.get_development(_active_chain, _selected_choice)
	_add_journal_entry(
		absolute_day,
		String(development["title"]),
		String(development["summary"]),
		2,
		{"stage": "development", "choice": String(_selected_choice)}
	)
	_phase = &"waiting_consequence"
	chain_developed.emit(_active_chain, _selected_choice)


func _publish_consequence(absolute_day: int) -> void:
	var consequence := StoryChainDefinition.get_consequence(_active_chain, _selected_choice)
	var requested_effects: Dictionary = consequence.get("effects", {})
	var applied_effects := _apply_effects(requested_effects)
	_add_journal_entry(
		absolute_day,
		String(consequence["title"]),
		String(consequence["summary"]),
		3,
		{
			"stage": "consequence",
			"choice": String(_selected_choice),
			"effects": applied_effects,
		}
	)
	chain_completed.emit(
		_active_chain, _selected_choice, applied_effects.duplicate(true)
	)
	_chain_index = (_chain_index + 1) % _chain_order.size()
	_phase = &"idle"
	_active_chain = &""
	_selected_choice = &""
	_target_state_id = &""
	_development_day = 0
	_consequence_day = 0
	_next_chain_day = absolute_day + NEXT_CHAIN_DELAY_DAYS
	_choice_deadline_day = 0


func _apply_effects(effects: Dictionary) -> Dictionary:
	var applied := {"food": 0, "wood": 0, "stone": 0, "gold": 0, "stability": 0}
	for resource_name in ResourceManager.RESOURCE_NAMES:
		var amount := maxi(0, int(effects.get(String(resource_name), 0)))
		if amount > 0:
			resource_manager.add_resource(resource_name, amount)
		applied[String(resource_name)] = amount
	var requested_stability := int(effects.get("stability", 0))
	applied["stability"] = stability_manager.apply_external_change(
		requested_stability,
		"Последствие цепочки событий"
	)
	return applied


func _add_journal_entry(
	absolute_day: int,
	title: String,
	summary: String,
	importance: int,
	consequences: Dictionary
) -> void:
	_sequence += 1
	var participants: Array[StringName] = []
	if _target_state_id != &"":
		participants.append(_target_state_id)
	event_journal_manager.add_entry(EventJournalEntry.create(
		"story:%d:%d" % [absolute_day, _sequence],
		absolute_day,
		&"story_chain",
		title,
		summary,
		participants,
		&"confirmed",
		consequences,
		importance
	))


func _initialize_for_seed(world_seed: int, first_day: int) -> void:
	_chain_order = StoryChainDefinition.build_order(world_seed)
	_chain_index = 0
	_phase = &"idle"
	_active_chain = &""
	_selected_choice = &""
	_target_state_id = &""
	_development_day = 0
	_consequence_day = 0
	_next_chain_day = maxi(1, first_day)
	_sequence = 0
	_choice_deadline_day = 0
	_initialized = true


func _choose_target_state(index: int) -> StringName:
	var ids := WorldGenerator.AI_STATE_IDS
	return ids[posmod(game_session_manager.get_world_seed() + index, ids.size())]


func _is_choice_for_chain(chain_id: StringName, choice_id: StringName) -> bool:
	var warning := StoryChainDefinition.get_warning(chain_id)
	for choice_value in warning.get("choices", []):
		if StringName(choice_value.get("choice_id", &"")) == choice_id:
			return true
	return false


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
