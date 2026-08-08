extends Node
class_name BuildingManager

signal building_placed(building: Dictionary)
signal placement_failed(reason: String)
signal buildings_loaded

const DEFINITION_PATHS: Array[String] = [
	"res://Resources/Buildings/House.tres",
	"res://Resources/Buildings/LumberCamp.tres",
	"res://Resources/Buildings/Farm.tres",
	"res://Resources/Buildings/Mine.tres",
	"res://Resources/Buildings/Barracks.tres",
]

@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager

var _buildings: Array[Dictionary] = []
var _occupied_cells: Dictionary = {}
var _definitions_by_id: Dictionary = {}
var _next_instance_id: int = 1


func _ready() -> void:
	for definition_path in DEFINITION_PATHS:
		var definition := load(definition_path) as BuildingDefinition
		if definition != null:
			_definitions_by_id[definition.id] = definition


func can_place_building(
	definition: BuildingDefinition,
	grid_position: Vector2i
) -> bool:
	if definition == null or definition.size.x <= 0 or definition.size.y <= 0:
		return false
	if _is_area_occupied(grid_position, definition.size):
		return false
	return _has_building_resources(definition)


func place_building(
	definition: BuildingDefinition,
	grid_position: Vector2i
) -> bool:
	if definition == null or definition.size.x <= 0 or definition.size.y <= 0:
		placement_failed.emit("Некорректное здание")
		return false

	if _is_area_occupied(grid_position, definition.size):
		placement_failed.emit("Клетка занята")
		return false

	if not _has_building_resources(definition):
		placement_failed.emit("Недостаточно ресурсов")
		return false

	_remove_building_resources(definition)

	var building: Dictionary = {
		"instance_id": _next_instance_id,
		"building_id": definition.id,
		"grid_position": grid_position,
	}
	_next_instance_id += 1
	_buildings.append(building)
	_definitions_by_id[definition.id] = definition

	for cell in _get_occupied_area(grid_position, definition.size):
		_occupied_cells[cell] = building["instance_id"]

	building_placed.emit(building.duplicate(true))
	return true


func is_cell_occupied(grid_position: Vector2i) -> bool:
	return _occupied_cells.has(grid_position)


func get_building_at(grid_position: Vector2i) -> Dictionary:
	if not _occupied_cells.has(grid_position):
		return {}

	var instance_id: int = _occupied_cells[grid_position]
	for building in _buildings:
		if building["instance_id"] == instance_id:
			return building.duplicate(true)
	return {}


func get_all_buildings() -> Array[Dictionary]:
	var buildings_copy: Array[Dictionary] = []
	for building in _buildings:
		buildings_copy.append(building.duplicate(true))
	return buildings_copy


func get_building_definition(building_id: StringName) -> BuildingDefinition:
	return _definitions_by_id.get(building_id) as BuildingDefinition


func get_building_count(building_id: StringName) -> int:
	var count := 0
	for building in _buildings:
		if building.get("building_id", &"") == building_id:
			count += 1
	return count


func get_total_worker_capacity(job: StringName) -> int:
	var total_capacity := 0
	for building in _buildings:
		var building_id: StringName = building.get("building_id", &"")
		var definition := get_building_definition(building_id)
		if definition != null and definition.worker_job == job:
			total_capacity += maxi(definition.worker_capacity, 0)
	return total_capacity


func get_total_daily_upkeep() -> Dictionary:
	var upkeep := {"food": 0, "gold": 0}
	for building in _buildings:
		var building_id: StringName = building.get("building_id", &"")
		var definition := get_building_definition(building_id)
		if definition == null:
			continue
		upkeep["food"] += maxi(definition.daily_food_upkeep, 0)
		upkeep["gold"] += maxi(definition.daily_gold_upkeep, 0)
	return upkeep


func get_save_data() -> Dictionary:
	var buildings: Array[Dictionary] = []
	for building in _buildings:
		var grid_position: Vector2i = building["grid_position"]
		buildings.append({
			"instance_id": int(building["instance_id"]),
			"building_id": String(building["building_id"]),
			"grid_x": grid_position.x,
			"grid_y": grid_position.y,
		})

	return {
		"next_instance_id": _next_instance_id,
		"buildings": buildings,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["next_instance_id", "buildings"]):
		return false
	if not data["buildings"] is Array:
		return false
	if not _is_integer_value(data["next_instance_id"]):
		return false

	var loaded_buildings: Array[Dictionary] = []
	var loaded_occupied_cells: Dictionary = {}
	var instance_ids: Dictionary = {}
	var maximum_instance_id := 0
	for building_value in data["buildings"]:
		if not building_value is Dictionary:
			return false
		var building: Dictionary = building_value
		if not building.has_all([
			"instance_id",
			"building_id",
			"grid_x",
			"grid_y",
		]):
			return false
		if not building["building_id"] is String:
			return false
		for numeric_field in ["instance_id", "grid_x", "grid_y"]:
			if not _is_integer_value(building[numeric_field]):
				return false

		var instance_id := int(building["instance_id"])
		var building_id := StringName(building["building_id"])
		var definition := get_building_definition(building_id)
		var grid_position := Vector2i(
			int(building["grid_x"]),
			int(building["grid_y"])
		)
		if instance_id < 1 or instance_ids.has(instance_id):
			return false
		if definition == null:
			return false
		for cell in _get_occupied_area(grid_position, definition.size):
			if loaded_occupied_cells.has(cell):
				return false
			loaded_occupied_cells[cell] = instance_id

		instance_ids[instance_id] = true
		maximum_instance_id = maxi(maximum_instance_id, instance_id)
		loaded_buildings.append({
			"instance_id": instance_id,
			"building_id": building_id,
			"grid_position": grid_position,
		})

	var loaded_next_id := int(data["next_instance_id"])
	if loaded_next_id <= maximum_instance_id:
		return false

	_buildings = loaded_buildings
	_occupied_cells = loaded_occupied_cells
	_next_instance_id = loaded_next_id
	buildings_loaded.emit()
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func _has_building_resources(definition: BuildingDefinition) -> bool:
	return (
		resource_manager.has_resource(&"wood", definition.wood_cost)
		and resource_manager.has_resource(&"stone", definition.stone_cost)
		and resource_manager.has_resource(&"gold", definition.gold_cost)
	)


func _remove_building_resources(definition: BuildingDefinition) -> void:
	if definition.wood_cost > 0:
		resource_manager.remove_resource(&"wood", definition.wood_cost)
	if definition.stone_cost > 0:
		resource_manager.remove_resource(&"stone", definition.stone_cost)
	if definition.gold_cost > 0:
		resource_manager.remove_resource(&"gold", definition.gold_cost)


func _is_area_occupied(grid_position: Vector2i, building_size: Vector2i) -> bool:
	for cell in _get_occupied_area(grid_position, building_size):
		if is_cell_occupied(cell):
			return true
	return false


func _get_occupied_area(
	grid_position: Vector2i,
	building_size: Vector2i
) -> Array[Vector2i]:
	var occupied_area: Array[Vector2i] = []
	for y_offset in building_size.y:
		for x_offset in building_size.x:
			occupied_area.append(grid_position + Vector2i(x_offset, y_offset))
	return occupied_area
