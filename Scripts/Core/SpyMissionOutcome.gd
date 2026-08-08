extends RefCounted
class_name SpyMissionOutcome

const SUCCESS_CHANCE := 0.65
const UNDETECTED_FAILURE_CHANCE := 0.20
const EXPOSURE_CHANCE := 0.15
const EXPOSURE_RELATION_CHANGE := -20


static func resolve(roll: float) -> Dictionary:
	roll = clampf(roll, 0.0, 0.999999)
	if roll < EXPOSURE_CHANCE:
		return {
			"id": &"exposed",
			"success": false,
			"exposed": true,
			"relation_change": EXPOSURE_RELATION_CHANGE,
			"message": "Шпион разоблачён. Отношения ухудшились на %d." % abs(EXPOSURE_RELATION_CHANGE),
		}
	if roll < EXPOSURE_CHANCE + UNDETECTED_FAILURE_CHANCE:
		return {
			"id": &"failed",
			"success": false,
			"exposed": false,
			"relation_change": 0,
			"message": "Шпион вернулся без надёжных сведений.",
		}
	return {
		"id": &"success",
		"success": true,
		"exposed": false,
		"relation_change": 0,
		"message": "Шпион добыл подробные, но приблизительные сведения.",
	}


static func risk_text() -> String:
	return "Успех 65% · безрезультатный провал 20% · разоблачение 15%"

