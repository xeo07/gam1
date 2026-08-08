extends RefCounted
class_name StateObservation

const SOURCE_NAMES: Dictionary = {
	&"world_start": "слухи при дворе",
	&"legacy_rumor": "старые слухи",
	&"messenger": "донесение гонца",
	&"spy": "отчёт шпиона",
	&"unknown": "неизвестный источник",
}

const STATUS_NAMES: Dictionary = {
	&"neutral": "нейтральный",
	&"ally": "союзник",
	&"enemy": "враждебный",
	&"war": "война",
}


static func create_view(
	state: Dictionary,
	intelligence: Dictionary,
	current_day: int
) -> Dictionary:
	var level := StateIntelligence.get_effective_level(intelligence, current_day)
	var age := StateIntelligence.get_age(intelligence, current_day)
	var source := StringName(intelligence.get("source", &"unknown"))
	var view := {
		"id": state.get("id", &""),
		"name": String(state.get("name", "Неизвестное государство")),
		"knowledge_level": level,
		"age_days": age,
		"source": source,
		"source_text": String(SOURCE_NAMES.get(source, SOURCE_NAMES[&"unknown"])),
		"freshness_text": _format_freshness(age),
		"ruler_text": "неизвестно",
		"status_text": "неизвестно",
		"population_text": "неизвестно",
		"military_text": "неизвестно",
		"wealth_text": "неизвестно",
		"stability_text": "неизвестно",
		"relation_text": "неизвестно",
	}

	if level <= StateIntelligence.LEVEL_UNKNOWN:
		return view

	view["status_text"] = String(
		STATUS_NAMES.get(state.get("status", &"neutral"), "неизвестно")
	)
	view["population_text"] = _qualitative_population(int(state.get("population", 0)))
	view["military_text"] = _qualitative_value(int(state.get("military_strength", 0)))
	view["wealth_text"] = _qualitative_value(int(state.get("wealth", 0)))
	view["stability_text"] = _qualitative_value(int(state.get("stability", 0)))
	view["relation_text"] = _qualitative_relation(int(state.get("relation", 0)))

	if level >= StateIntelligence.LEVEL_DIPLOMATIC:
		view["ruler_text"] = String(state.get("ruler_name", "неизвестно"))
		view["population_text"] = _range_text(int(state.get("population", 0)), 0.20, 10)
		view["military_text"] = _range_text(int(state.get("military_strength", 0)), 0.15, 8, 0, 100)
		view["wealth_text"] = _range_text(int(state.get("wealth", 0)), 0.15, 8, 0, 100)
		view["stability_text"] = _range_text(int(state.get("stability", 0)), 0.15, 8, 0, 100)
		view["relation_text"] = _range_text(int(state.get("relation", 0)), 0.15, 10, -100, 100)

	if level >= StateIntelligence.LEVEL_ESPIONAGE:
		view["population_text"] = _range_text(int(state.get("population", 0)), 0.05, 4)
		view["military_text"] = _range_text(int(state.get("military_strength", 0)), 0.05, 3, 0, 100)
		view["wealth_text"] = _range_text(int(state.get("wealth", 0)), 0.05, 3, 0, 100)
		view["stability_text"] = _range_text(int(state.get("stability", 0)), 0.05, 3, 0, 100)
		view["relation_text"] = _range_text(int(state.get("relation", 0)), 0.05, 4, -100, 100)

	return view


static func _range_text(
	value: int,
	ratio: float,
	minimum_width: int,
	minimum_value: int = 0,
	maximum_value: int = 1000000
) -> String:
	var width := maxi(minimum_width, ceili(absf(value) * ratio))
	var lower := maxi(minimum_value, value - width)
	var upper := mini(maximum_value, value + width)
	return "примерно %d–%d" % [lower, upper]


static func _qualitative_population(value: int) -> String:
	if value < 80:
		return "малое"
	if value < 115:
		return "среднее"
	return "большое"


static func _qualitative_value(value: int) -> String:
	if value < 35:
		return "слабое"
	if value < 65:
		return "среднее"
	return "сильное"


static func _qualitative_relation(value: int) -> String:
	if value < -30:
		return "враждебные"
	if value < 0:
		return "холодные"
	if value < 30:
		return "нейтральные"
	if value < 60:
		return "благоприятные"
	return "тёплые"


static func _format_freshness(age: int) -> String:
	if age == 0:
		return "получены сегодня"
	if age == 1:
		return "получены вчера"
	return "получены %d дн. назад" % age

