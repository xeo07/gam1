extends RefCounted
class_name EventJournalEntry

const VALID_RELIABILITY: Array[StringName] = [
	&"confirmed",
	&"reported",
	&"rumor",
]


static func create(
	entry_id: String,
	absolute_day: int,
	category: StringName,
	title: String,
	summary: String,
	participants: Array[StringName],
	reliability: StringName,
	consequences: Dictionary,
	importance: int
) -> Dictionary:
	return {
		"id": entry_id,
		"day": maxi(1, absolute_day),
		"category": category,
		"title": title,
		"summary": summary,
		"participants": participants.duplicate(),
		"reliability": (
			reliability if reliability in VALID_RELIABILITY else &"reported"
		),
		"consequences": consequences.duplicate(true),
		"importance": clampi(importance, 1, 3),
	}


static func to_save_data(entry: Dictionary) -> Dictionary:
	var participants: Array[String] = []
	for participant in entry.get("participants", []):
		participants.append(String(participant))
	return {
		"id": String(entry.get("id", "")),
		"day": int(entry.get("day", 1)),
		"category": String(entry.get("category", &"world")),
		"title": String(entry.get("title", "")),
		"summary": String(entry.get("summary", "")),
		"participants": participants,
		"reliability": String(entry.get("reliability", &"reported")),
		"consequences": entry.get("consequences", {}).duplicate(true),
		"importance": int(entry.get("importance", 1)),
	}


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all([
		"id", "day", "category", "title", "summary", "participants",
		"reliability", "consequences", "importance",
	]):
		return {"valid": false}
	for field in ["id", "category", "title", "summary", "reliability"]:
		if not data[field] is String:
			return {"valid": false}
	if not data["participants"] is Array or not data["consequences"] is Dictionary:
		return {"valid": false}
	if not _is_integer(data["day"]) or not _is_integer(data["importance"]):
		return {"valid": false}
	var reliability := StringName(data["reliability"])
	if String(data["id"]).is_empty() or int(data["day"]) < 1:
		return {"valid": false}
	if reliability not in VALID_RELIABILITY:
		return {"valid": false}
	if int(data["importance"]) < 1 or int(data["importance"]) > 3:
		return {"valid": false}
	var participants: Array[StringName] = []
	for participant in data["participants"]:
		if not participant is String or String(participant).is_empty():
			return {"valid": false}
		participants.append(StringName(participant))
	return {
		"valid": true,
		"entry": create(
			String(data["id"]),
			int(data["day"]),
			StringName(data["category"]),
			String(data["title"]),
			String(data["summary"]),
			participants,
			reliability,
			data["consequences"],
			int(data["importance"])
		),
	}


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))

