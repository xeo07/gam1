extends RefCounted
class_name StatePersonality

const PROFILE_IDS: Array[StringName] = [
	&"merchant",
	&"warlike",
	&"guardian",
	&"settler",
	&"diplomat",
	&"traditionalist",
	&"opportunist",
]

const PROFILES: Dictionary = {
	&"merchant": {
		"display_name": "Торговцы",
		"interests": [&"trade", &"wealth"],
		"strategic_goal": &"prosperity",
		"bias": {"population": 0, "military": -1, "wealth": 2, "stability": 0, "relation": 1},
	},
	&"warlike": {
		"display_name": "Завоеватели",
		"interests": [&"army", &"conquest"],
		"strategic_goal": &"dominance",
		"bias": {"population": 0, "military": 2, "wealth": -1, "stability": 0, "relation": -1},
	},
	&"guardian": {
		"display_name": "Хранители",
		"interests": [&"defense", &"stability"],
		"strategic_goal": &"security",
		"bias": {"population": 0, "military": 1, "wealth": 0, "stability": 2, "relation": 0},
	},
	&"settler": {
		"display_name": "Поселенцы",
		"interests": [&"population", &"territory"],
		"strategic_goal": &"expansion",
		"bias": {"population": 2, "military": 0, "wealth": 0, "stability": -1, "relation": 0},
	},
	&"diplomat": {
		"display_name": "Дипломаты",
		"interests": [&"alliances", &"trade"],
		"strategic_goal": &"harmony",
		"bias": {"population": 0, "military": 0, "wealth": 1, "stability": 0, "relation": 2},
	},
	&"traditionalist": {
		"display_name": "Традиционалисты",
		"interests": [&"stability", &"population"],
		"strategic_goal": &"continuity",
		"bias": {"population": 1, "military": 0, "wealth": 0, "stability": 1, "relation": 0},
	},
	&"opportunist": {
		"display_name": "Искатели выгоды",
		"interests": [&"wealth", &"army"],
		"strategic_goal": &"advantage",
		"bias": {"population": 0, "military": 1, "wealth": 1, "stability": 0, "relation": -1},
	},
}


static func is_valid(profile_id: StringName) -> bool:
	return PROFILES.has(profile_id)


static func get_profile(profile_id: StringName) -> Dictionary:
	if not is_valid(profile_id):
		profile_id = &"traditionalist"
	return PROFILES[profile_id].duplicate(true)


static func get_interests(profile_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for interest in get_profile(profile_id).get("interests", []):
		result.append(StringName(interest))
	return result


static func get_strategic_goal(profile_id: StringName) -> StringName:
	return StringName(get_profile(profile_id).get("strategic_goal", &"continuity"))


static func get_daily_bias(profile_id: StringName) -> Dictionary:
	return get_profile(profile_id).get("bias", {}).duplicate(true)

