extends RefCounted
class_name DiplomaticContract

const DEFINITIONS: Dictionary = {
	&"trade_treaty": {"name": "Торговый договор", "duration": 30, "cost": 6, "minimum_relation": 0, "interests": [&"trade", &"wealth"], "condition": "Открытые рынки в течение 30 дней", "benefit": "+1 золото каждые 3 дня", "breach": "Сильная потеря доверия и выгоды"},
	&"non_aggression": {"name": "Пакт о ненападении", "duration": 45, "cost": 3, "minimum_relation": 8, "interests": [&"defense", &"stability", &"alliances"], "condition": "Не объявлять войну партнёру 45 дней", "benefit": "Постепенный рост доверия", "breach": "Объявление войны считается нарушением"},
	&"military_obligation": {"name": "Военное обязательство", "duration": 30, "cost": 4, "minimum_relation": 18, "interests": [&"army", &"alliances", &"defense"], "condition": "Каждые 7 дней выделять 2 золота на совместную оборону", "benefit": "Доверие и военное влияние", "breach": "Невыплата разрушает доверие"},
}


static func get_preview(contract_id: StringName, state: Dictionary, relation: int) -> Dictionary:
	if not DEFINITIONS.has(contract_id):
		return {}
	var definition: Dictionary = DEFINITIONS[contract_id].duplicate(true)
	var score := relation
	for interest in state.get("interests", []):
		if interest in definition["interests"]:
			score += 12
	if state.get("personality", &"") == &"diplomat":
		score += 8
	if contract_id == &"non_aggression" and state.get("personality", &"") == &"warlike":
		score -= 12
	definition["contract_id"] = contract_id
	definition["accepted"] = score >= int(definition["minimum_relation"])
	definition["reaction"] = (
		"Двор склонен принять предложение."
		if definition["accepted"]
		else "Двор, вероятно, откажется: интересы или отношения недостаточны."
	)
	return definition


static func create_active(contract_id: StringName, state_id: StringName, start_day: int) -> Dictionary:
	var definition: Dictionary = DEFINITIONS[contract_id]
	return {"contract_id": contract_id, "state_id": state_id, "start_day": start_day, "end_day": start_day + int(definition["duration"]), "last_payment_day": start_day, "status": &"active"}
