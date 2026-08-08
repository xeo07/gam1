extends RefCounted
class_name DiplomaticActionResolver

const ACTIONS: Dictionary = {
	&"gift": {"label": "Отправить дар", "cost": 10, "trust": 14, "fear": -4, "benefit": 10, "duration": 45},
	&"threat": {"label": "Выдвинуть угрозу", "cost": 2, "trust": -12, "fear": 18, "benefit": -6, "duration": 40},
	&"agreement": {"label": "Обменяться посольствами", "cost": 5, "trust": 11, "fear": -2, "benefit": 13, "duration": 55},
	&"insult": {"label": "Публично оскорбить", "cost": 0, "trust": -18, "fear": 8, "benefit": -10, "duration": 60},
}


static func build(action_id: StringName, state: Dictionary, third_party: Dictionary = {}) -> Dictionary:
	if not ACTIONS.has(action_id):
		return {}
	var action: Dictionary = ACTIONS[action_id].duplicate(true)
	var personality := StringName(state.get("personality", &"traditionalist"))
	var interests: Array = state.get("interests", [])
	var trust := int(action["trust"])
	var fear := int(action["fear"])
	var benefit := int(action["benefit"])
	if action_id == &"gift":
		if personality == &"merchant" or &"wealth" in interests:
			benefit += 6
		if personality == &"diplomat":
			trust += 5
		if personality == &"warlike":
			trust -= 5
	elif action_id == &"threat":
		if personality == &"warlike" or &"army" in interests:
			trust -= 7
			fear -= 6
		if personality == &"guardian":
			fear -= 3
		if personality == &"opportunist":
			fear += 5
	elif action_id == &"agreement":
		if personality == &"merchant" or &"trade" in interests:
			benefit += 7
		if personality == &"diplomat" or &"alliances" in interests:
			trust += 6
		if personality == &"warlike":
			benefit -= 5
	elif action_id == &"insult" and personality == &"warlike":
		fear -= 5
		trust -= 4

	var name := String(state.get("name", "это государство"))
	var result := {
		"action_id": action_id,
		"label": String(action["label"]),
		"cost": int(action["cost"]),
		"trust": trust,
		"fear": fear,
		"benefit": benefit,
		"duration": int(action["duration"]),
		"memory_id": action_id,
		"summary": _memory_summary(action_id),
		"context": _context(action_id, name, personality),
		"forecast": _forecast(trust, fear, benefit),
		"message": _message(action_id),
	}
	if action_id == &"agreement" and not third_party.is_empty():
		result["third_party"] = {
			"state_id": third_party.get("id", &""),
			"state_name": third_party.get("name", "другой двор"),
			"trust": -6, "fear": 2, "benefit": -5, "duration": 35,
			"summary": "корона сблизилась с их соперником",
			"forecast": "Соперничающий двор, вероятно, насторожится.",
		}
	return result


static func _forecast(trust: int, fear: int, benefit: int) -> String:
	var warmth := trust + benefit - fear
	if warmth >= 18:
		return "Отношения, вероятно, заметно улучшатся."
	if warmth > 0:
		return "Двор, вероятно, станет немного благосклоннее."
	if fear >= 12:
		return "Двор испугается, но надолго запомнит давление."
	return "Отношения, вероятно, заметно ухудшатся."


static func _context(action_id: StringName, state_name: String, personality: StringName) -> String:
	var character := String(StatePersonality.get_profile(personality).get("display_name", "Правители"))
	match action_id:
		&"gift": return "%s ценят дары по-своему. Послы отправятся в %s." % [character, state_name]
		&"threat": return "%s оценят, насколько корона готова подкрепить слова силой." % character
		&"agreement": return "%s получат предложение о постоянном обмене посольствами." % state_name
		_: return "Оскорбление прозвучит публично, и %s не смогут его забыть." % state_name


static func _memory_summary(action_id: StringName) -> String:
	match action_id:
		&"gift": return "корона прислала щедрый подарок"
		&"threat": return "корона пыталась запугать их двор"
		&"agreement": return "корона предложила обмен посольствами"
		_: return "посол публично оскорбил их двор"


static func _message(action_id: StringName) -> String:
	match action_id:
		&"gift": return "Дар принят. Реакция двора зависит от его характера."
		&"threat": return "Ультиматум доставлен. Двор запомнит давление."
		&"agreement": return "Предложение принято. Сближение заметили и соседи."
		_: return "Оскорбление доставлено. Его запомнят надолго."
