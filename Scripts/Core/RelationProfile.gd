extends RefCounted
class_name RelationProfile

const MAX_MEMORIES := 20
const DEFAULT_MEMORY_DURATION_DAYS := 42


static func create_from_legacy(relation: int) -> Dictionary:
	var normalized := clampi(relation, -100, 100)
	return {
		"base_trust": normalized,
		"base_fear": 0,
		"base_benefit": normalized,
		"memories": [],
	}


static func adjust_base(
	profile: Dictionary,
	trust_change: int,
	fear_change: int,
	benefit_change: int
) -> Dictionary:
	var result := _normalized_profile(profile)
	result["base_trust"] = clampi(int(result["base_trust"]) + trust_change, -100, 100)
	result["base_fear"] = clampi(int(result["base_fear"]) + fear_change, 0, 100)
	result["base_benefit"] = clampi(int(result["base_benefit"]) + benefit_change, -100, 100)
	return result


static func add_memory(
	profile: Dictionary,
	memory_id: String,
	absolute_day: int,
	summary: String,
	trust_change: int,
	fear_change: int,
	benefit_change: int,
	duration_days: int = DEFAULT_MEMORY_DURATION_DAYS
) -> Dictionary:
	var result := prune_expired(profile, absolute_day)
	var memories: Array = result["memories"]
	memories.append({
		"id": memory_id,
		"day": maxi(1, absolute_day),
		"summary": summary,
		"trust": clampi(trust_change, -100, 100),
		"fear": clampi(fear_change, -100, 100),
		"benefit": clampi(benefit_change, -100, 100),
		"duration_days": maxi(1, duration_days),
	})
	while memories.size() > MAX_MEMORIES:
		memories.pop_front()
	result["memories"] = memories
	return result


static func prune_expired(profile: Dictionary, absolute_day: int) -> Dictionary:
	var result := _normalized_profile(profile)
	var active: Array[Dictionary] = []
	for memory_value in result["memories"]:
		var memory: Dictionary = memory_value
		if absolute_day - int(memory["day"]) < int(memory["duration_days"]):
			active.append(memory.duplicate(true))
	result["memories"] = active
	return result


static func get_components(profile: Dictionary, absolute_day: int) -> Dictionary:
	var normalized := _normalized_profile(profile)
	var trust := int(normalized["base_trust"])
	var fear := int(normalized["base_fear"])
	var benefit := int(normalized["base_benefit"])
	for memory_value in normalized["memories"]:
		var memory: Dictionary = memory_value
		var remaining := _remaining_ratio(memory, absolute_day)
		trust += roundi(float(memory["trust"]) * remaining)
		fear += roundi(float(memory["fear"]) * remaining)
		benefit += roundi(float(memory["benefit"]) * remaining)
	return {
		"trust": clampi(trust, -100, 100),
		"fear": clampi(fear, 0, 100),
		"benefit": clampi(benefit, -100, 100),
	}


static func get_score(profile: Dictionary, absolute_day: int) -> int:
	var components := get_components(profile, absolute_day)
	return clampi(roundi(
		(float(components["trust"]) + float(components["benefit"])) / 2.0
		- float(components["fear"]) * 0.35
	), -100, 100)


static func get_reason_lines(profile: Dictionary, absolute_day: int) -> Array[String]:
	var components := get_components(profile, absolute_day)
	var lines: Array[String] = [
		"Доверие: %s" % _trust_label(int(components["trust"])),
		"Опасения: %s" % _fear_label(int(components["fear"])),
		"Взаимная выгода: %s" % _benefit_label(int(components["benefit"])),
	]
	var memories: Array[Dictionary] = []
	for memory_value in _normalized_profile(profile)["memories"]:
		var memory: Dictionary = memory_value
		if _remaining_ratio(memory, absolute_day) > 0.0:
			memories.append(memory)
	memories.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _memory_strength(left, absolute_day) > _memory_strength(right, absolute_day)
	)
	for index in mini(2, memories.size()):
		lines.append("Помнят: %s" % String(memories[index]["summary"]))
	return lines


static func to_save_data(profile: Dictionary) -> Dictionary:
	var normalized := _normalized_profile(profile)
	var memories: Array[Dictionary] = []
	for memory_value in normalized["memories"]:
		var memory: Dictionary = memory_value
		memories.append(memory.duplicate(true))
	return {
		"base_trust": int(normalized["base_trust"]),
		"base_fear": int(normalized["base_fear"]),
		"base_benefit": int(normalized["base_benefit"]),
		"memories": memories,
	}


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all(["base_trust", "base_fear", "base_benefit", "memories"]):
		return {"valid": false}
	for field in ["base_trust", "base_fear", "base_benefit"]:
		if not _is_integer(data[field]):
			return {"valid": false}
	if int(data["base_trust"]) < -100 or int(data["base_trust"]) > 100:
		return {"valid": false}
	if int(data["base_fear"]) < 0 or int(data["base_fear"]) > 100:
		return {"valid": false}
	if int(data["base_benefit"]) < -100 or int(data["base_benefit"]) > 100:
		return {"valid": false}
	if not data["memories"] is Array or data["memories"].size() > MAX_MEMORIES:
		return {"valid": false}
	var memories: Array[Dictionary] = []
	for memory_value in data["memories"]:
		var parsed := _parse_memory(memory_value)
		if not bool(parsed.get("valid", false)):
			return {"valid": false}
		memories.append(parsed["memory"])
	return {
		"valid": true,
		"profile": {
			"base_trust": int(data["base_trust"]),
			"base_fear": int(data["base_fear"]),
			"base_benefit": int(data["base_benefit"]),
			"memories": memories,
		},
	}


static func _normalized_profile(profile: Dictionary) -> Dictionary:
	var parsed := parse_save_data(profile)
	if bool(parsed.get("valid", false)):
		return parsed["profile"]
	return create_from_legacy(0)


static func _parse_memory(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all(["id", "day", "summary", "trust", "fear", "benefit", "duration_days"]):
		return {"valid": false}
	if not data["id"] is String or not data["summary"] is String:
		return {"valid": false}
	for field in ["day", "trust", "fear", "benefit", "duration_days"]:
		if not _is_integer(data[field]):
			return {"valid": false}
	if String(data["id"]).is_empty() or String(data["summary"]).is_empty():
		return {"valid": false}
	if int(data["day"]) < 1 or int(data["duration_days"]) < 1:
		return {"valid": false}
	for field in ["trust", "fear", "benefit"]:
		if int(data[field]) < -100 or int(data[field]) > 100:
			return {"valid": false}
	return {"valid": true, "memory": data.duplicate(true)}


static func _remaining_ratio(memory: Dictionary, absolute_day: int) -> float:
	var age := maxi(0, absolute_day - int(memory["day"]))
	return clampf(
		1.0 - float(age) / float(maxi(1, int(memory["duration_days"]))),
		0.0,
		1.0
	)


static func _memory_strength(memory: Dictionary, absolute_day: int) -> float:
	return float(
		absi(int(memory["trust"]))
		+ absi(int(memory["fear"]))
		+ absi(int(memory["benefit"]))
	) * _remaining_ratio(memory, absolute_day)


static func _trust_label(value: int) -> String:
	if value >= 50:
		return "высокое"
	if value >= 15:
		return "осторожное"
	if value > -15:
		return "не сложилось"
	if value > -50:
		return "низкое"
	return "почти отсутствует"


static func _fear_label(value: int) -> String:
	if value >= 60:
		return "сильные"
	if value >= 25:
		return "заметные"
	if value > 0:
		return "слабые"
	return "не испытывают"


static func _benefit_label(value: int) -> String:
	if value >= 50:
		return "очень важна"
	if value >= 15:
		return "заметна"
	if value > -15:
		return "неясна"
	if value > -50:
		return "сомнительна"
	return "отношения считают вредными"


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
