extends Node
class_name EventJournalManager

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 200

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var messenger_manager: MessengerManager = $"../MessengerManager" as MessengerManager
@onready var war_manager: WarManager = $"../WarManager" as WarManager
@onready var diplomacy_manager: DiplomacyManager = $"../DiplomacyManager" as DiplomacyManager

var _entries: Array[Dictionary] = []
var _sequence := 0


func _ready() -> void:
	world_manager.world_event_occurred.connect(_on_world_event)
	spy_manager.spy_mission_resolved.connect(_on_spy_resolved)
	messenger_manager.report_ready.connect(_on_messenger_report)
	war_manager.war_declared.connect(_on_war_declared)
	war_manager.campaign_completed.connect(_on_campaign_completed)
	diplomacy_manager.diplomatic_action_completed.connect(_on_diplomatic_action)


func add_entry(entry: Dictionary) -> bool:
	var parsed := EventJournalEntry.parse_save_data(
		EventJournalEntry.to_save_data(entry)
	)
	if not bool(parsed.get("valid", false)):
		return false
	var normalized: Dictionary = parsed["entry"]
	for existing in _entries:
		if existing.get("id", "") == normalized.get("id", ""):
			return false
	_entries.append(normalized)
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(normalized.duplicate(true))
	return true


func get_entries() -> Array[Dictionary]:
	return _duplicate_entries(_entries)


func get_entries_between(first_day: int, last_day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		var entry_day := int(entry.get("day", 0))
		if entry_day >= first_day and entry_day <= last_day:
			result.append(entry.duplicate(true))
	return result


func get_save_data() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry in _entries:
		entries.append(EventJournalEntry.to_save_data(entry))
	return {"entries": entries, "sequence": _sequence}


func load_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		_entries.clear()
		_sequence = 0
		return true
	if not data.get("entries", null) is Array:
		return false
	if not (data.get("sequence", null) is int or data.get("sequence", null) is float):
		return false
	var entries: Array[Dictionary] = []
	var ids: Dictionary = {}
	for value in data["entries"]:
		var parsed := EventJournalEntry.parse_save_data(value)
		if not bool(parsed.get("valid", false)):
			return false
		var entry: Dictionary = parsed["entry"]
		if ids.has(entry["id"]):
			return false
		ids[entry["id"]] = true
		entries.append(entry)
	if entries.size() > MAX_ENTRIES or int(data["sequence"]) < 0:
		return false
	_entries = entries
	_sequence = int(data["sequence"])
	return true


func _on_world_event(event: Dictionary) -> void:
	add_entry(EventJournalEntry.create(
		String(event.get("id", _next_id("world"))),
		int(event.get("day", time_manager.get_absolute_day())),
		&"foreign_affairs",
		String(event.get("title", "Событие за границей")),
		"%s %s" % [String(event.get("cause", "")), String(event.get("summary", ""))],
		[StringName(event.get("state_id", &""))],
		&"reported",
		event.get("effects", {}),
		2
	))


func _on_spy_resolved(state_id: StringName, outcome: Dictionary) -> void:
	var outcome_id := StringName(outcome.get("id", &"failed"))
	add_entry(EventJournalEntry.create(
		_next_id("spy"), time_manager.get_absolute_day(), &"espionage",
		"Исход шпионской миссии",
		String(outcome.get("message", "Миссия завершена")),
		[state_id], &"confirmed",
		{"relation": int(outcome.get("relation_change", 0)), "outcome": String(outcome_id)},
		3 if outcome_id == &"exposed" else 1
	))


func _on_messenger_report(report: Dictionary) -> void:
	add_entry(EventJournalEntry.create(
		_next_id("messenger"), int(report.get("report_day", time_manager.get_absolute_day())),
		&"diplomacy", "Возвращение гонца", String(report.get("summary", "Гонец вернулся")),
		[StringName(report.get("state_id", &""))], &"confirmed", {"intelligence": "diplomatic"}, 1
	))


func _on_war_declared(state_id: StringName) -> void:
	var state := world_manager.get_observed_state_by_id(state_id)
	add_entry(EventJournalEntry.create(
		_next_id("war"), time_manager.get_absolute_day(), &"war",
		"Объявлена война", "Наше государство объявило войну державе %s." % String(state.get("name", "")),
		[state_id], &"confirmed", {"status": "war"}, 3
	))


func _on_campaign_completed(report: Dictionary) -> void:
	add_entry(EventJournalEntry.create(
		_next_id("campaign"), time_manager.get_absolute_day(), &"war",
		"Завершён военный поход", String(report.get("result_name", "Получен военный отчёт")),
		[StringName(report.get("state_id", &""))], &"confirmed",
		{"gold": int(report.get("gold_change", 0)), "enemy_military": int(report.get("enemy_military_change", 0))}, 3
	))


func _on_diplomatic_action(
	state_id: StringName,
	action_id: StringName,
	relation_change: int,
	message: String
) -> void:
	add_entry(EventJournalEntry.create(
		_next_id("diplomacy"), time_manager.get_absolute_day(), &"diplomacy",
		"Дипломатический поступок", message, [state_id], &"confirmed",
		{"action": String(action_id), "relation_change": relation_change},
		2 if action_id == &"insult" else 1
	))


func _next_id(prefix: String) -> String:
	_sequence += 1
	return "%s:%d:%d" % [prefix, time_manager.get_absolute_day(), _sequence]


func _duplicate_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		result.append(entry.duplicate(true))
	return result
