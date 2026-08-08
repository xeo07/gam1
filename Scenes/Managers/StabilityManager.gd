extends Node
class_name StabilityManager

signal stability_changed(
	stability: int,
	change: int,
	reasons: Array[String]
)
signal internal_state_changed(state_id: StringName)
signal stability_day_completed(data: Dictionary)

const STARTING_STABILITY := 70
const MINIMUM_STABILITY := 0
const MAXIMUM_STABILITY := 100
const MINIMUM_DAILY_CHANGE := -10
const MAXIMUM_DAILY_CHANGE := 3
const VALID_STATE_IDS: Array[StringName] = [
	&"prosperous",
	&"stable",
	&"tense",
	&"unstable",
	&"critical",
]

@onready var economy_manager: EconomyManager = $"../EconomyManager" as EconomyManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var stability: int = STARTING_STABILITY
var last_stability_change: int = 0
var last_change_reasons: Array[String] = []
var last_processed_absolute_day: int = 0


func _ready() -> void:
	economy_manager.daily_economy_completed.connect(_on_daily_economy_completed)
	time_manager.time_loaded.connect(_on_time_loaded)


func initialize_new_game() -> void:
	stability = STARTING_STABILITY
	last_stability_change = 0
	last_change_reasons.clear()
	last_processed_absolute_day = time_manager.get_absolute_day()
	_emit_current_state()


func get_stability() -> int:
	return stability


func get_last_stability_change() -> int:
	return last_stability_change


func get_last_change_reasons() -> Array[String]:
	var reasons_copy: Array[String] = []
	for reason in last_change_reasons:
		reasons_copy.append(reason)
	return reasons_copy


func get_average_loyalty() -> float:
	return population_manager.get_average_loyalty()


func get_internal_state_id() -> StringName:
	if stability >= 81:
		return &"prosperous"
	if stability >= 61:
		return &"stable"
	if stability >= 41:
		return &"tense"
	if stability >= 21:
		return &"unstable"
	return &"critical"


func get_internal_state_name() -> String:
	match get_internal_state_id():
		&"prosperous":
			return "Процветание"
		&"stable":
			return "Стабильно"
		&"tense":
			return "Напряжённость"
		&"unstable":
			return "Нестабильно"
		_:
			return "Критическое положение"


func apply_external_change(amount: int, reason: String) -> int:
	var previous_state_id := get_internal_state_id()
	var previous_stability := stability
	stability = clampi(
		stability + amount,
		MINIMUM_STABILITY,
		MAXIMUM_STABILITY
	)
	var actual_change := stability - previous_stability
	var signal_reasons: Array[String] = []
	if not reason.is_empty():
		signal_reasons.append(reason)
	stability_changed.emit(stability, actual_change, signal_reasons)
	var current_state_id := get_internal_state_id()
	if current_state_id != previous_state_id:
		internal_state_changed.emit(current_state_id)
	return actual_change


func get_save_data() -> Dictionary:
	return {
		"stability": stability,
		"last_stability_change": last_stability_change,
		"last_change_reasons": get_last_change_reasons(),
		"last_processed_absolute_day": last_processed_absolute_day,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all([
		"stability",
		"last_stability_change",
		"last_change_reasons",
		"last_processed_absolute_day",
	]):
		return false
	for numeric_field in [
		"stability",
		"last_stability_change",
		"last_processed_absolute_day",
	]:
		if not _is_integer_value(data[numeric_field]):
			return false
	if not data["last_change_reasons"] is Array:
		return false

	var loaded_stability := int(data["stability"])
	var loaded_change := int(data["last_stability_change"])
	var loaded_day := int(data["last_processed_absolute_day"])
	if loaded_stability < MINIMUM_STABILITY or loaded_stability > MAXIMUM_STABILITY:
		return false
	if loaded_change < MINIMUM_DAILY_CHANGE or loaded_change > MAXIMUM_DAILY_CHANGE:
		return false
	if loaded_day < 0 or loaded_day != time_manager.get_absolute_day():
		return false

	var loaded_reasons: Array[String] = []
	for reason_value in data["last_change_reasons"]:
		if not reason_value is String:
			return false
		loaded_reasons.append(String(reason_value))

	stability = loaded_stability
	last_stability_change = loaded_change
	last_change_reasons = loaded_reasons
	last_processed_absolute_day = loaded_day
	_emit_current_state()
	return true


func _on_daily_economy_completed(report: Dictionary) -> void:
	var absolute_day := time_manager.get_absolute_day()
	if absolute_day <= last_processed_absolute_day:
		return
	last_processed_absolute_day = absolute_day

	var shortages: Dictionary = report.get("shortages", {})
	var net: Dictionary = report.get("net", {})
	var reasons: Array[String] = []
	var change := 0
	if bool(report.get("hunger_active", false)):
		change -= 5
		reasons.append("Голод снижает стабильность")
	if int(shortages.get("food", 0)) >= 5:
		change -= 2
		reasons.append("Тяжёлый дефицит еды")
	if bool(report.get("gold_deficit_active", false)):
		change -= 2
		reasons.append("Казна не покрывает содержание")
	if int(shortages.get("gold", 0)) >= 5:
		change -= 1
		reasons.append("Крупный дефицит золота")
	if int(shortages.get("food", 0)) == 0 and int(net.get("food", 0)) >= 3:
		change += 1
		reasons.append("Запасы еды растут")
	if int(shortages.get("gold", 0)) == 0 and int(net.get("gold", 0)) >= 2:
		change += 1
		reasons.append("Казна укрепляется")

	var average_loyalty := get_average_loyalty()
	if average_loyalty < 4.0:
		change -= 3
		reasons.append("Население крайне недовольно")
	elif average_loyalty < 6.0:
		change -= 1
		reasons.append("Верность населения снижена")
	elif average_loyalty >= 8.0:
		change += 1
		reasons.append("Население поддерживает правителя")

	var previous_state_id := get_internal_state_id()
	var previous_stability := stability
	change = clampi(change, MINIMUM_DAILY_CHANGE, MAXIMUM_DAILY_CHANGE)
	stability = clampi(
		stability + change,
		MINIMUM_STABILITY,
		MAXIMUM_STABILITY
	)
	last_stability_change = stability - previous_stability
	if last_stability_change == 0 and reasons.is_empty():
		reasons.append("Существенных изменений нет")
	last_change_reasons = reasons

	stability_changed.emit(
		stability,
		last_stability_change,
		get_last_change_reasons()
	)
	var current_state_id := get_internal_state_id()
	if current_state_id != previous_state_id:
		internal_state_changed.emit(current_state_id)

	var day_data := {
		"stability": stability,
		"change": last_stability_change,
		"state_id": current_state_id,
		"state_name": get_internal_state_name(),
		"average_loyalty": average_loyalty,
		"reasons": get_last_change_reasons(),
	}
	stability_day_completed.emit(day_data.duplicate(true))
	_print_stability_day(day_data)


func _on_time_loaded(_day: int, _month: int, _year: int) -> void:
	last_processed_absolute_day = time_manager.get_absolute_day()
	_emit_current_state()


func _emit_current_state() -> void:
	stability_changed.emit(
		stability,
		last_stability_change,
		get_last_change_reasons()
	)
	internal_state_changed.emit(get_internal_state_id())


func _print_stability_day(data: Dictionary) -> void:
	print("Stability day completed:")
	print("Day: %d" % time_manager.get_absolute_day())
	print("Stability: %d" % int(data["stability"]))
	print("Change: %d" % int(data["change"]))
	print("State: %s" % String(data["state_id"]))
	print("Average loyalty: %.1f" % float(data["average_loyalty"]))
	print("Reasons: %s" % "; ".join(PackedStringArray(data["reasons"])))


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
