extends Node
class_name TimeManager

signal day_changed(day: int, month: int, year: int)
signal time_loaded(day: int, month: int, year: int)

const DAYS_IN_MONTH := 30
const MONTHS_IN_YEAR := 12

var day: int = 1
var month: int = 1
var year: int = 1

func _ready() -> void:
	print("TimeManager initialized.")
	add_to_group("time_manager")
	print(get_date())

func emit_current_date() -> void:
	day_changed.emit(day, month, year)

func next_day() -> void:
	day += 1

	if day > DAYS_IN_MONTH:
		day = 1
		month += 1

	if month > MONTHS_IN_YEAR:
		month = 1
		year += 1

	print(get_date())

	emit_current_date()

func get_date() -> String:
	return "Day %d | Month %d | Year %d" % [day, month, year]


func get_absolute_day() -> int:
	return (year - 1) * 360 + (month - 1) * 30 + day


func get_save_data() -> Dictionary:
	return {
		"day": day,
		"month": month,
		"year": year,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["day", "month", "year"]):
		return false
	if not _is_integer_value(data["day"]):
		return false
	if not _is_integer_value(data["month"]):
		return false
	if not _is_integer_value(data["year"]):
		return false

	var loaded_day := int(data["day"])
	var loaded_month := int(data["month"])
	var loaded_year := int(data["year"])
	if loaded_day < 1 or loaded_day > DAYS_IN_MONTH:
		return false
	if loaded_month < 1 or loaded_month > MONTHS_IN_YEAR:
		return false
	if loaded_year < 1:
		return false

	day = loaded_day
	month = loaded_month
	year = loaded_year
	time_loaded.emit(day, month, year)
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)
