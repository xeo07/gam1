extends Node
class_name ResourceManager

signal resources_changed(food: int, wood: int, stone: int, gold: int)

const STARTING_FOOD := 40
const STARTING_WOOD := 30
const STARTING_STONE := 10
const STARTING_GOLD := 20
const RESOURCE_NAMES: Array[StringName] = [
	&"food",
	&"wood",
	&"stone",
	&"gold",
]

var food: int = 0:
	set(value):
		food = maxi(value, 0)

var wood: int = 0:
	set(value):
		wood = maxi(value, 0)

var stone: int = 0:
	set(value):
		stone = maxi(value, 0)

var gold: int = 0:
	set(value):
		gold = maxi(value, 0)

var _initialized := false


func initialize_new_game() -> void:
	if _initialized:
		return
	food = STARTING_FOOD
	wood = STARTING_WOOD
	stone = STARTING_STONE
	gold = STARTING_GOLD
	_initialized = true
	emit_current_resources()


func add_resource(resource_name: StringName, amount: int) -> void:
	if amount <= 0:
		return

	match resource_name:
		&"food":
			food += amount
		&"wood":
			wood += amount
		&"stone":
			stone += amount
		&"gold":
			gold += amount
		_:
			return

	emit_current_resources()


func remove_resource(resource_name: StringName, amount: int) -> bool:
	if amount < 0 or not has_resource(resource_name, amount):
		return false
	if amount == 0:
		return true

	match resource_name:
		&"food":
			food -= amount
		&"wood":
			wood -= amount
		&"stone":
			stone -= amount
		&"gold":
			gold -= amount
		_:
			return false

	emit_current_resources()
	return true


func has_resource(resource_name: StringName, amount: int) -> bool:
	if amount < 0:
		return false

	match resource_name:
		&"food":
			return food >= amount
		&"wood":
			return wood >= amount
		&"stone":
			return stone >= amount
		&"gold":
			return gold >= amount
		_:
			return false


func can_apply_resource_transaction(deltas: Dictionary) -> bool:
	var next_values := {
		&"food": food,
		&"wood": wood,
		&"stone": stone,
		&"gold": gold,
	}
	for resource_value in deltas:
		var resource_name := StringName(resource_value)
		if resource_name not in RESOURCE_NAMES:
			return false
		var delta_value: Variant = deltas[resource_value]
		if not _is_integer_value(delta_value):
			return false
		next_values[resource_name] = int(next_values[resource_name]) + int(delta_value)
		if int(next_values[resource_name]) < 0:
			return false
	return true


func apply_resource_transaction(deltas: Dictionary) -> bool:
	if not can_apply_resource_transaction(deltas):
		return false
	var normalized := {
		&"food": 0,
		&"wood": 0,
		&"stone": 0,
		&"gold": 0,
	}
	for resource_value in deltas:
		var resource_name := StringName(resource_value)
		normalized[resource_name] = int(deltas[resource_value])
	food += int(normalized[&"food"])
	wood += int(normalized[&"wood"])
	stone += int(normalized[&"stone"])
	gold += int(normalized[&"gold"])
	emit_current_resources()
	return true


func emit_current_resources() -> void:
	resources_changed.emit(food, wood, stone, gold)


func get_save_data() -> Dictionary:
	return {
		"food": food,
		"wood": wood,
		"stone": stone,
		"gold": gold,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["food", "wood", "stone", "gold"]):
		return false
	for resource_name in ["food", "wood", "stone", "gold"]:
		if not _is_integer_value(data[resource_name]):
			return false

	var loaded_food := int(data["food"])
	var loaded_wood := int(data["wood"])
	var loaded_stone := int(data["stone"])
	var loaded_gold := int(data["gold"])
	if (
		loaded_food < 0
		or loaded_wood < 0
		or loaded_stone < 0
		or loaded_gold < 0
	):
		return false

	food = loaded_food
	wood = loaded_wood
	stone = loaded_stone
	gold = loaded_gold
	_initialized = true
	emit_current_resources()
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)
