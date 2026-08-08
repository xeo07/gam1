extends Node
class_name PopulationManager

signal population_changed(total_population: int)
signal citizen_updated(citizen_id: int)
signal population_capacity_changed(current_population: int, maximum_population: int)

const BASE_POPULATION_CAPACITY := 4
const HIRE_FOOD_COST := 10
const HIRE_GOLD_COST := 5

const AVAILABLE_JOBS: Array[StringName] = [
	&"unassigned",
	&"woodcutter",
	&"farmer",
	&"miner",
	&"builder",
	&"blacksmith",
	&"soldier",
]

const CITIZEN_NAMES: Array[String] = [
	"Алекс",
	"Борис",
	"Виктор",
	"Дано",
	"Дани",
	"Эгор",
	"Элья",
	"Кирилл",
	"Лев",
	"Максимус",
	"Олек",
	"Павел",
	"Роман",
	"Степан",
	"Фёдор",
]

@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager

var _citizens: Array[Dictionary] = []
var _next_citizen_id: int = 1
var _initialized := false


func _ready() -> void:
	print("PopulationManager initialized.")
	building_manager.building_placed.connect(_on_building_placed)


func initialize_new_game() -> void:
	if _initialized or not game_session_manager.is_initialized():
		return
	_citizens.clear()
	_next_citizen_id = 1
	var rng := game_session_manager.get_rng()
	var initial_population := rng.randi_range(2, 4)
	for _index in initial_population:
		add_random_citizen()
	_initialized = true
	print("Generated citizens: %d" % get_population_count())
	for citizen in _citizens:
		_print_citizen(citizen)
	emit_population_capacity()


func get_population_count() -> int:
	return _citizens.size()


func get_average_loyalty() -> float:
	if _citizens.is_empty():
		return 0.0
	var total_loyalty := 0
	for citizen in _citizens:
		total_loyalty += int(citizen.get("loyalty", 0))
	return float(total_loyalty) / float(_citizens.size())


func get_population_capacity() -> int:
	var maximum_population := BASE_POPULATION_CAPACITY
	for building in building_manager.get_all_buildings():
		var building_id: StringName = building.get("building_id", &"")
		var definition := building_manager.get_building_definition(building_id)
		if definition != null:
			maximum_population += maxi(definition.population_capacity, 0)
	return maximum_population


func can_add_citizen() -> bool:
	return get_population_count() < get_population_capacity()


func hire_random_citizen() -> bool:
	if not can_add_citizen():
		return false
	if not resource_manager.has_resource(&"food", HIRE_FOOD_COST):
		return false
	if not resource_manager.has_resource(&"gold", HIRE_GOLD_COST):
		return false

	resource_manager.remove_resource(&"food", HIRE_FOOD_COST)
	resource_manager.remove_resource(&"gold", HIRE_GOLD_COST)
	add_random_citizen()
	emit_population_capacity()
	return true


func emit_population_capacity() -> void:
	population_capacity_changed.emit(
		get_population_count(),
		get_population_capacity()
	)


func get_available_jobs() -> Array[StringName]:
	var jobs_copy: Array[StringName] = []
	for job in AVAILABLE_JOBS:
		jobs_copy.append(job)
	return jobs_copy


func get_all_citizens() -> Array[Dictionary]:
	var citizens_copy: Array[Dictionary] = []
	for citizen in _citizens:
		citizens_copy.append(citizen.duplicate(true))
	return citizens_copy


func get_citizen_by_id(citizen_id: int) -> Dictionary:
	var citizen_index := _find_citizen_index(citizen_id)
	if citizen_index == -1:
		return {}
	return _citizens[citizen_index].duplicate(true)


func add_random_citizen() -> Dictionary:
	if not game_session_manager.is_initialized():
		return {}
	var rng := game_session_manager.get_rng()
	var citizen: Dictionary = {
		"id": _next_citizen_id,
		"name": CITIZEN_NAMES[rng.randi_range(0, CITIZEN_NAMES.size() - 1)],
		"strength": rng.randi_range(1, 10),
		"intelligence": rng.randi_range(1, 10),
		"speed": rng.randi_range(1, 10),
		"loyalty": rng.randi_range(1, 10),
		"craftsmanship": rng.randi_range(1, 10),
		"job": &"unassigned",
	}

	_next_citizen_id += 1
	_citizens.append(citizen)
	emit_current_population()
	return citizen.duplicate(true)


func remove_citizen(citizen_id: int) -> bool:
	var citizen_index := _find_citizen_index(citizen_id)
	if citizen_index == -1:
		return false

	_citizens.remove_at(citizen_index)
	emit_current_population()
	emit_population_capacity()
	return true


func assign_job(citizen_id: int, job: StringName) -> bool:
	if job not in AVAILABLE_JOBS:
		return false

	var citizen_index := _find_citizen_index(citizen_id)
	if citizen_index == -1:
		return false

	_citizens[citizen_index]["job"] = job
	citizen_updated.emit(citizen_id)
	return true


func emit_current_population() -> void:
	population_changed.emit(get_population_count())


func apply_loyalty_change_to_all(amount: int) -> int:
	var changed_count := 0
	for index in _citizens.size():
		var citizen_id := int(_citizens[index]["id"])
		var old_loyalty := int(_citizens[index]["loyalty"])
		var new_loyalty := clampi(old_loyalty + amount, 1, 10)
		if new_loyalty == old_loyalty:
			continue
		_citizens[index]["loyalty"] = new_loyalty
		changed_count += 1
		citizen_updated.emit(citizen_id)
	return changed_count


func get_save_data() -> Dictionary:
	var citizens: Array[Dictionary] = []
	for citizen in _citizens:
		var saved_citizen := citizen.duplicate(true)
		saved_citizen["job"] = String(citizen.get("job", &"unassigned"))
		citizens.append(saved_citizen)

	return {
		"next_citizen_id": _next_citizen_id,
		"citizens": citizens,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["next_citizen_id", "citizens"]):
		return false
	if not data["citizens"] is Array:
		return false
	if not _is_integer_value(data["next_citizen_id"]):
		return false

	var loaded_citizens: Array[Dictionary] = []
	var citizen_ids: Dictionary = {}
	var maximum_id := 0
	for citizen_value in data["citizens"]:
		if not citizen_value is Dictionary:
			return false
		var citizen: Dictionary = citizen_value
		if not citizen.has_all([
			"id",
			"name",
			"strength",
			"intelligence",
			"speed",
			"loyalty",
			"craftsmanship",
			"job",
		]):
			return false
		if not citizen["name"] is String:
			return false
		if not citizen["job"] is String:
			return false
		for numeric_field in [
			"id",
			"strength",
			"intelligence",
			"speed",
			"loyalty",
			"craftsmanship",
		]:
			if not _is_integer_value(citizen[numeric_field]):
				return false

		var citizen_id := int(citizen["id"])
		var job := StringName(citizen["job"])
		if citizen_id < 1 or citizen_ids.has(citizen_id):
			return false
		if job not in AVAILABLE_JOBS:
			return false

		for attribute in [
			"strength",
			"intelligence",
			"speed",
			"loyalty",
			"craftsmanship",
		]:
			var value := int(citizen[attribute])
			if value < 1 or value > 10:
				return false

		citizen_ids[citizen_id] = true
		maximum_id = maxi(maximum_id, citizen_id)
		loaded_citizens.append({
			"id": citizen_id,
			"name": String(citizen["name"]),
			"strength": int(citizen["strength"]),
			"intelligence": int(citizen["intelligence"]),
			"speed": int(citizen["speed"]),
			"loyalty": int(citizen["loyalty"]),
			"craftsmanship": int(citizen["craftsmanship"]),
			"job": job,
		})

	var loaded_next_id := int(data["next_citizen_id"])
	if loaded_next_id <= maximum_id:
		return false

	_citizens = loaded_citizens
	_next_citizen_id = loaded_next_id
	_initialized = true
	emit_current_population()
	emit_population_capacity()
	return true


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)


func _on_building_placed(_building: Dictionary) -> void:
	emit_population_capacity()


func _find_citizen_index(citizen_id: int) -> int:
	for index in _citizens.size():
		if _citizens[index]["id"] == citizen_id:
			return index
	return -1


func _print_citizen(citizen: Dictionary) -> void:
	var citizen_text := (
		"Citizen #%d: %s | strength=%d, intelligence=%d, speed=%d, "
		+ "loyalty=%d, craftsmanship=%d, job=%s"
	) % [
		citizen["id"],
		citizen["name"],
		citizen["strength"],
		citizen["intelligence"],
		citizen["speed"],
		citizen["loyalty"],
		citizen["craftsmanship"],
		citizen["job"],
	]
	print(citizen_text)
