extends RefCounted
class_name WorldEventGenerator

const MAX_EVENT_HISTORY := 50
const EFFECT_FIELDS: Array[String] = [
	"population",
	"military_strength",
	"wealth",
	"stability",
	"relation",
]


static func try_generate_event(
	states: Array[Dictionary],
	absolute_day: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	if states.is_empty() or absolute_day < 1:
		return {}
	if absolute_day % 4 != 0 and rng.randf() > 0.25:
		return {}
	var state := states[rng.randi_range(0, states.size() - 1)]
	return generate_for_state(state, absolute_day, rng)


static func generate_for_state(
	state: Dictionary,
	absolute_day: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var state_id := StringName(state.get("id", &""))
	if state_id == &"" or absolute_day < 1:
		return {}

	var template := _choose_template(state, rng)
	var event_type := StringName(template["type"])
	return {
		"id": "%d:%s:%s" % [absolute_day, state_id, event_type],
		"type": event_type,
		"state_id": state_id,
		"state_name": String(state.get("name", "")),
		"day": absolute_day,
		"title": String(template["title"]),
		"cause": String(template["cause"]),
		"summary": String(template["summary"]),
		"effects": template["effects"].duplicate(true),
	}


static func apply_event(state: Dictionary, event: Dictionary) -> void:
	var effects: Dictionary = event.get("effects", {})
	state["population"] = maxi(
		10, int(state.get("population", 10)) + int(effects.get("population", 0))
	)
	for field in ["military_strength", "wealth", "stability"]:
		state[field] = clampi(
			int(state.get(field, 0)) + int(effects.get(field, 0)), 0, 100
		)
	state["relation"] = clampi(
		int(state.get("relation", 0)) + int(effects.get("relation", 0)), -100, 100
	)


static func to_save_data(event: Dictionary) -> Dictionary:
	var saved := event.duplicate(true)
	saved["type"] = String(event.get("type", &""))
	saved["state_id"] = String(event.get("state_id", &""))
	return saved


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all([
		"id", "type", "state_id", "state_name", "day",
		"title", "cause", "summary", "effects",
	]):
		return {"valid": false}
	for field in ["id", "type", "state_id", "state_name", "title", "cause", "summary"]:
		if not data[field] is String:
			return {"valid": false}
	if not data["effects"] is Dictionary or not _is_integer_value(data["day"]):
		return {"valid": false}
	if String(data["id"]).is_empty() or String(data["state_id"]).is_empty() or int(data["day"]) < 1:
		return {"valid": false}
	var effects: Dictionary = data["effects"]
	for field in EFFECT_FIELDS:
		if effects.has(field) and not _is_integer_value(effects[field]):
			return {"valid": false}
	var event := data.duplicate(true)
	event["type"] = StringName(data["type"])
	event["state_id"] = StringName(data["state_id"])
	return {"valid": true, "event": event}


static func _choose_template(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if int(state.get("stability", 100)) <= 50:
		return {
			"type": &"unrest",
			"title": "Волнения в провинциях",
			"cause": "Низкая стабильность усилила недовольство жителей.",
			"summary": "Беспорядки ослабили хозяйство и заставили правителя тратить силы на порядок.",
			"effects": {"population": -2, "military_strength": -1, "wealth": -3, "stability": -3, "relation": 0},
		}
	if int(state.get("wealth", 100)) <= 30:
		return {
			"type": &"debt_crisis",
			"title": "Долговой кризис",
			"cause": "Истощённая казна вынудила двор поднять сборы.",
			"summary": "Чрезвычайные налоги немного пополнили казну, но усилили напряжение.",
			"effects": {"population": -1, "military_strength": 0, "wealth": 4, "stability": -4, "relation": -1},
		}

	match StringName(state.get("personality", &"traditionalist")):
		&"merchant":
			return _template(&"trade_fair", "Большая ярмарка", "Торговые интересы двора привлекли чужеземных купцов.", "Ярмарка наполнила казну и сделала соседей благосклоннее.", 1, 0, 5, 1, 1)
		&"warlike":
			return _template(&"military_muster", "Военный сбор", "Завоевательные планы потребовали новых полков.", "Казна оплатила ускоренную подготовку армии.", 0, 5, -3, -1, -1)
		&"guardian":
			return _template(&"fortification", "Укрепление границ", "Двор опасается угрозы соседей.", "Новые укрепления усилили оборону и уверенность жителей.", 0, 2, -2, 3, 0)
		&"settler":
			return _template(&"migration", "Великий переселенческий обоз", "Свободные земли привлекли новые семьи.", "Население выросло, но устройство переселенцев потребовало расходов.", 5, 0, -2, -1, 0)
		&"diplomat":
			return _template(&"summit", "Съезд послов", "Двор стремится расширить круг союзников.", "Переговоры улучшили отношение к соседям ценой расходов на приём.", 0, 0, -1, 1, 4)
		&"opportunist":
			var profit := 6 if rng.randf() >= 0.4 else -5
			return _template(&"risky_venture", "Рискованное предприятие", "Двор решил воспользоваться внезапной возможностью.", "Смелая ставка изменила состояние казны.", 0, 1, profit, -1, -1)
		_:
			return _template(&"festival", "Праздник традиций", "Двор укрепляет старые обычаи и единство жителей.", "Торжества повысили спокойствие, но потребовали денег.", 1, 0, -2, 4, 0)


static func _template(
	event_type: StringName,
	title: String,
	cause: String,
	summary: String,
	population: int,
	military: int,
	wealth: int,
	stability: int,
	relation: int
) -> Dictionary:
	return {
		"type": event_type,
		"title": title,
		"cause": cause,
		"summary": summary,
		"effects": {
			"population": population,
			"military_strength": military,
			"wealth": wealth,
			"stability": stability,
			"relation": relation,
		},
	}


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))

