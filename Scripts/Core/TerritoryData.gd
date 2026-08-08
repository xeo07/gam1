extends RefCounted
class_name TerritoryData


static func create(territory_id: StringName, display_name: String, source: StringName, origin_state_id: StringName, acquired_day: int) -> Dictionary:
	var profile := _profile(source)
	return {"id": territory_id, "name": display_name, "source": source, "origin_state_id": origin_state_id, "acquired_day": acquired_day, "gold_income": profile["gold_income"], "food_supply": profile["food_supply"], "unrest": profile["unrest"]}


static func is_valid(data: Dictionary) -> bool:
	return data.has_all(["id", "name", "source", "origin_state_id", "acquired_day", "gold_income", "food_supply", "unrest"]) and StringName(data.get("source", &"")) in [&"war", &"treaty", &"crisis"] and int(data.get("acquired_day", 0)) >= 1


static func _profile(source: StringName) -> Dictionary:
	match source:
		&"war": return {"gold_income": 3, "food_supply": 2, "unrest": 1}
		&"treaty": return {"gold_income": 2, "food_supply": 1, "unrest": 0}
		_: return {"gold_income": 1, "food_supply": 1, "unrest": 0}
