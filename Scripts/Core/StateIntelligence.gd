extends RefCounted
class_name StateIntelligence

const LEVEL_UNKNOWN := 0
const LEVEL_RUMORS := 1
const LEVEL_DIPLOMATIC := 2
const LEVEL_ESPIONAGE := 3
const MAX_LEVEL := LEVEL_ESPIONAGE
const DEGRADATION_DAYS := 14


static func create(
	state_id: StringName,
	level: int,
	updated_day: int,
	source: StringName
) -> Dictionary:
	return {
		"state_id": state_id,
		"level": clampi(level, LEVEL_UNKNOWN, MAX_LEVEL),
		"updated_day": maxi(1, updated_day),
		"source": source,
	}


static func get_age(record: Dictionary, current_day: int) -> int:
	return maxi(0, current_day - int(record.get("updated_day", current_day)))


static func get_effective_level(record: Dictionary, current_day: int) -> int:
	var age := get_age(record, current_day)
	var lost_levels := floori(age / float(DEGRADATION_DAYS))
	return maxi(LEVEL_UNKNOWN, int(record.get("level", LEVEL_UNKNOWN)) - lost_levels)


static func get_freshness(record: Dictionary, current_day: int) -> StringName:
	var age := get_age(record, current_day)
	if age < 7:
		return &"fresh"
	if age < DEGRADATION_DAYS:
		return &"aging"
	return &"stale"


static func improve(
	record: Dictionary,
	new_level: int,
	current_day: int,
	source: StringName
) -> Dictionary:
	return create(
		StringName(record.get("state_id", &"")),
		maxi(get_effective_level(record, current_day), new_level),
		current_day,
		source
	)


static func to_save_data(record: Dictionary) -> Dictionary:
	return {
		"state_id": String(record.get("state_id", &"")),
		"level": int(record.get("level", LEVEL_UNKNOWN)),
		"updated_day": int(record.get("updated_day", 1)),
		"source": String(record.get("source", &"unknown")),
	}


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all(["state_id", "level", "updated_day", "source"]):
		return {"valid": false}
	if not data["state_id"] is String or not data["source"] is String:
		return {"valid": false}
	if not _is_integer_value(data["level"]) or not _is_integer_value(data["updated_day"]):
		return {"valid": false}
	var state_id := StringName(data["state_id"])
	var level := int(data["level"])
	var updated_day := int(data["updated_day"])
	if state_id == &"" or level < LEVEL_UNKNOWN or level > MAX_LEVEL or updated_day < 1:
		return {"valid": false}
	return {
		"valid": true,
		"record": create(state_id, level, updated_day, StringName(data["source"])),
	}


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
