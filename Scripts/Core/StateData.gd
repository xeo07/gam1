extends RefCounted
class_name StateData

const VALID_STATUSES: Array[StringName] = [
	&"neutral",
	&"ally",
	&"enemy",
	&"war",
]

const REQUIRED_FIELDS: Array[String] = [
	"id",
	"name",
	"ruler_name",
	"population",
	"military_strength",
	"wealth",
	"stability",
	"relation",
	"status",
]


static func create(
	state_id: StringName,
	display_name: String,
	ruler_name: String,
	population: int,
	military_strength: int,
	wealth: int,
	stability: int,
	relation: int = 0,
	status: StringName = &"neutral"
) -> Dictionary:
	return {
		"id": state_id,
		"name": display_name,
		"ruler_name": ruler_name,
		"population": maxi(10, population),
		"military_strength": clampi(military_strength, 0, 100),
		"wealth": clampi(wealth, 0, 100),
		"stability": clampi(stability, 0, 100),
		"relation": clampi(relation, -100, 100),
		"status": status if status in VALID_STATUSES else &"neutral",
	}


static func to_save_data(state: Dictionary) -> Dictionary:
	return {
		"id": String(state.get("id", &"")),
		"name": String(state.get("name", "")),
		"ruler_name": String(state.get("ruler_name", "")),
		"population": int(state.get("population", 10)),
		"military_strength": int(state.get("military_strength", 0)),
		"wealth": int(state.get("wealth", 0)),
		"stability": int(state.get("stability", 0)),
		"relation": int(state.get("relation", 0)),
		"status": String(state.get("status", &"neutral")),
	}


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all(REQUIRED_FIELDS):
		return {"valid": false}
	for field in ["id", "name", "ruler_name", "status"]:
		if not data[field] is String:
			return {"valid": false}
	for field in [
		"population",
		"military_strength",
		"wealth",
		"stability",
		"relation",
	]:
		if not _is_integer_value(data[field]):
			return {"valid": false}

	var state_id := StringName(data["id"])
	var population := int(data["population"])
	var military_strength := int(data["military_strength"])
	var wealth := int(data["wealth"])
	var stability := int(data["stability"])
	var relation := int(data["relation"])
	var status := StringName(data["status"])
	if state_id == &"":
		return {"valid": false}
	if population < 10:
		return {"valid": false}
	if military_strength < 0 or military_strength > 100:
		return {"valid": false}
	if wealth < 0 or wealth > 100:
		return {"valid": false}
	if stability < 0 or stability > 100:
		return {"valid": false}
	if relation < -100 or relation > 100:
		return {"valid": false}
	if status not in VALID_STATUSES:
		return {"valid": false}

	return {
		"valid": true,
		"state": create(
			state_id,
			String(data["name"]),
			String(data["ruler_name"]),
			population,
			military_strength,
			wealth,
			stability,
			relation,
			status
		),
	}


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))

