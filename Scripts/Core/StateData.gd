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
	status: StringName = &"neutral",
	personality: StringName = &"traditionalist",
	interests: Array[StringName] = [],
	strategic_goal: StringName = &"continuity",
	relation_profile: Dictionary = {}
) -> Dictionary:
	if not StatePersonality.is_valid(personality):
		personality = &"traditionalist"
	if interests.is_empty():
		interests = StatePersonality.get_interests(personality)
	if strategic_goal == &"":
		strategic_goal = StatePersonality.get_strategic_goal(personality)
	var parsed_profile := RelationProfile.parse_save_data(relation_profile)
	var normalized_profile: Dictionary = (
		parsed_profile["profile"]
		if bool(parsed_profile.get("valid", false))
		else RelationProfile.create_from_legacy(relation)
	)
	return {
		"id": state_id,
		"name": display_name,
		"ruler_name": ruler_name,
		"population": maxi(10, population),
		"military_strength": clampi(military_strength, 0, 100),
		"wealth": clampi(wealth, 0, 100),
		"stability": clampi(stability, 0, 100),
		"relation": clampi(relation, -100, 100),
		"relation_profile": normalized_profile,
		"status": status if status in VALID_STATUSES else &"neutral",
		"personality": personality,
		"interests": interests.duplicate(),
		"strategic_goal": strategic_goal,
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
		"relation_profile": RelationProfile.to_save_data(
			state.get("relation_profile", RelationProfile.create_from_legacy(
				int(state.get("relation", 0))
			))
		),
		"status": String(state.get("status", &"neutral")),
		"personality": String(state.get("personality", &"traditionalist")),
		"interests": _string_names_to_strings(state.get("interests", [])),
		"strategic_goal": String(state.get("strategic_goal", &"continuity")),
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
	var personality := StringName(data.get("personality", "traditionalist"))
	var strategic_goal := StringName(data.get("strategic_goal", "continuity"))
	var interests: Array[StringName] = []
	var relation_profile := RelationProfile.create_from_legacy(relation)
	if data.has("relation_profile"):
		var parsed_profile := RelationProfile.parse_save_data(data["relation_profile"])
		if not bool(parsed_profile.get("valid", false)):
			return {"valid": false}
		relation_profile = parsed_profile["profile"]
	var saved_interests: Variant = data.get("interests", [])
	if not saved_interests is Array:
		return {"valid": false}
	for interest in saved_interests:
		if not interest is String:
			return {"valid": false}
		interests.append(StringName(interest))
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
	if not StatePersonality.is_valid(personality):
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
			status,
			personality,
			interests,
			strategic_goal,
			relation_profile
		),
	}


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))


static func _string_names_to_strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		result.append(String(value))
	return result
