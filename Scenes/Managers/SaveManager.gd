extends Node
class_name SaveManager

signal game_saved
signal game_loaded
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_PATH := "user://kingdoom_save.json"
const SAVE_VERSION := 1
const REQUIRED_SECTIONS: Array[String] = [
	"session",
	"time",
	"resources",
	"special_goods",
	"population",
	"army",
	"war",
	"buildings",
	"economy",
	"stability",
	"events",
	"world",
	"diplomacy",
	"trade",
	"spy",
	"news",
]

@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var special_goods_manager: SpecialGoodsManager = $"../SpecialGoodsManager" as SpecialGoodsManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var war_manager: WarManager = $"../WarManager" as WarManager
@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager
@onready var economy_manager: EconomyManager = $"../EconomyManager" as EconomyManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var event_manager: EventManager = $"../EventManager" as EventManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var diplomacy_manager: DiplomacyManager = $"../DiplomacyManager" as DiplomacyManager
@onready var trade_manager: TradeManager = $"../TradeManager" as TradeManager
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager
@onready var kingdom_grid: KingdomGrid = $"../KingdomGrid" as KingdomGrid


func save_game() -> bool:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		_fail_save("Не удалось открыть файл сохранения")
		return false

	var save_data := build_save_data()
	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.flush()
	if save_file.get_error() != OK:
		_fail_save("Не удалось записать файл сохранения")
		return false

	game_saved.emit()
	print("Game saved:")
	print("Path: %s" % SAVE_PATH)
	_print_saved_counts(save_data)
	return true


func load_game() -> bool:
	if not has_save_file():
		_fail_load("Файл сохранения не найден")
		return false

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		_fail_load("Не удалось открыть файл сохранения")
		return false

	var json_text := save_file.get_as_text()
	var json := JSON.new()
	var parse_error := json.parse(json_text)
	if parse_error != OK:
		_fail_load(
			"Ошибка JSON: строка %d — %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return false
	if not json.data is Dictionary:
		_fail_load("Некорректный формат сохранения")
		return false

	var save_data: Dictionary = json.data
	if not _is_integer_value(save_data.get("save_version", null)):
		_fail_load("Некорректная версия сохранения")
		return false
	if int(save_data.get("save_version", -1)) != SAVE_VERSION:
		_fail_load("Неподдерживаемая версия сохранения")
		return false
	if not save_data.has("session"):
		_fail_load("В сохранении отсутствует раздел session")
		return false
	if (
		save_data["session"] is Dictionary
		and (
			not save_data["session"].has("flag_pixels")
			or not save_data["session"].has("emblem_pixels")
		)
	):
		_fail_load("В сохранении отсутствуют данные флага или герба")
		return false
	if not save_data.has("special_goods"):
		_fail_load("В сохранении отсутствует раздел special_goods")
		return false
	if not save_data.has("army"):
		_fail_load("В сохранении отсутствует раздел army")
		return false
	if not save_data.has("war"):
		_fail_load("В сохранении отсутствует раздел war")
		return false
	if not save_data.has("trade"):
		_fail_load("В сохранении отсутствует раздел trade")
		return false
	if not save_data.has("economy"):
		_fail_load("В сохранении отсутствует раздел economy")
		return false
	if not save_data.has("stability"):
		_fail_load("В сохранении отсутствует раздел stability")
		return false
	if not save_data.has("events"):
		_fail_load("В сохранении отсутствует раздел events")
		return false
	if not _has_required_sections(save_data):
		_fail_load("В сохранении отсутствуют обязательные разделы")
		return false
	if not apply_save_data(save_data):
		_fail_load("Не удалось применить данные сохранения")
		return false

	game_loaded.emit()
	print("Game loaded:")
	print(
		"Day %d, Month %d, Year %d"
		% [time_manager.day, time_manager.month, time_manager.year]
	)
	print("Population: %d" % population_manager.get_population_count())
	print("Buildings: %d" % building_manager.get_all_buildings().size())
	return true


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not has_save_file():
		return false

	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	var error := DirAccess.remove_absolute(absolute_path)
	if error != OK:
		_fail_save("Не удалось удалить сохранение")
		return false

	print("Save deleted.")
	return true


func build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"session": game_session_manager.get_save_data(),
		"time": time_manager.get_save_data(),
		"resources": resource_manager.get_save_data(),
		"special_goods": special_goods_manager.get_save_data(),
		"population": population_manager.get_save_data(),
		"army": army_manager.get_save_data(),
		"war": war_manager.get_save_data(),
		"buildings": building_manager.get_save_data(),
		"economy": economy_manager.get_save_data(),
		"stability": stability_manager.get_save_data(),
		"events": event_manager.get_save_data(),
		"world": world_manager.get_save_data(),
		"diplomacy": diplomacy_manager.get_save_data(),
		"trade": trade_manager.get_save_data(),
		"spy": spy_manager.get_save_data(),
		"news": news_manager.get_save_data(),
	}


func apply_save_data(data: Dictionary) -> bool:
	if not _is_integer_value(data.get("save_version", null)):
		return false
	if int(data.get("save_version", -1)) != SAVE_VERSION:
		return false
	if not _has_required_sections(data):
		return false
	if not game_session_manager.is_save_data_valid(data["session"]):
		return false
	if not army_manager.is_save_data_equipment_consistent(data["army"]):
		return false
	if not war_manager.is_save_data_consistent_with_sections(
		data["war"],
		data["world"],
		data["army"]
	):
		return false

	var had_initialized_session := game_session_manager.is_initialized()
	var previous_data := build_save_data() if had_initialized_session else {}
	army_manager.begin_save_load()
	war_manager.begin_save_load()
	var apply_succeeded := _apply_sections(data)
	if not apply_succeeded:
		var rollback_succeeded := (
			_apply_sections(previous_data) if had_initialized_session else true
		)
		war_manager.end_save_load()
		army_manager.end_save_load()
		_refresh_ui()
		if not rollback_succeeded:
			push_error("Save rollback failed.")
		return false

	war_manager.end_save_load()
	army_manager.end_save_load()
	game_session_manager.initialize_loaded_game()
	_refresh_ui()
	return true


func _apply_sections(data: Dictionary) -> bool:
	var session_data: Dictionary = data["session"]
	var time_data: Dictionary = data["time"]
	var resources_data: Dictionary = data["resources"]
	var special_goods_data: Dictionary = data["special_goods"]
	var buildings_data: Dictionary = data["buildings"]
	var economy_data: Dictionary = data["economy"]
	var stability_data: Dictionary = data["stability"]
	var events_data: Dictionary = data["events"]
	var population_data: Dictionary = data["population"]
	var army_data: Dictionary = data["army"]
	var war_data: Dictionary = data["war"]
	var world_data: Dictionary = data["world"]
	var diplomacy_data: Dictionary = data["diplomacy"]
	var trade_data: Dictionary = data["trade"]
	var spy_data: Dictionary = data["spy"]
	var news_data: Dictionary = data["news"]

	if not game_session_manager.load_save_data(session_data):
		return false
	if not time_manager.load_save_data(time_data):
		return false
	if not resource_manager.load_save_data(resources_data):
		return false
	if not special_goods_manager.load_save_data(special_goods_data):
		return false
	if not population_manager.load_save_data(population_data):
		return false
	if not army_manager.load_save_data(army_data):
		return false
	if not war_manager.load_save_data(war_data):
		return false
	if not building_manager.load_save_data(buildings_data):
		return false
	if not economy_manager.load_save_data(economy_data):
		return false
	if not stability_manager.load_save_data(stability_data):
		return false
	if not event_manager.load_save_data(events_data):
		return false
	if not world_manager.load_save_data(world_data):
		return false
	if not diplomacy_manager.load_save_data(diplomacy_data):
		return false
	if not trade_manager.load_save_data(trade_data):
		return false
	if not spy_manager.load_save_data(spy_data):
		return false
	if not news_manager.load_save_data(news_data):
		return false
	kingdom_grid.rebuild_building_visuals()
	return true


func _has_required_sections(data: Dictionary) -> bool:
	for section in REQUIRED_SECTIONS:
		if not data.has(section) or not data[section] is Dictionary:
			return false
	return true


func _refresh_ui() -> void:
	resource_manager.emit_current_resources()
	special_goods_manager.emit_current_goods()
	population_manager.emit_current_population()
	population_manager.emit_population_capacity()
	war_manager.emit_war_state_changed()
	event_manager.emit_event_state()
	world_manager.emit_states_changed()


func _fail_save(reason: String) -> void:
	save_failed.emit(reason)


func _fail_load(reason: String) -> void:
	load_failed.emit(reason)


func _print_saved_counts(data: Dictionary) -> void:
	var session: Dictionary = data["session"]
	var population: Dictionary = data["population"]
	var buildings: Dictionary = data["buildings"]
	var economy: Dictionary = data["economy"]
	var stability_data: Dictionary = data["stability"]
	var events: Dictionary = data["events"]
	var army: Dictionary = data["army"]
	var war: Dictionary = data["war"]
	var special_goods: Dictionary = data["special_goods"]
	var world: Dictionary = data["world"]
	var trade: Dictionary = data["trade"]
	var spy: Dictionary = data["spy"]
	var citizens: Array = population["citizens"]
	var building_entries: Array = buildings["buildings"]
	var states: Array = world["states"]
	var trade_offer_uses: Dictionary = trade["offer_uses"]
	var missions: Array = spy["active_missions"]
	var goods: Dictionary = special_goods["goods"]
	var assignments: Array = army["assignments"]
	var equipped_goods: Dictionary = army["equipped_goods"]
	print("Saved session:")
	print("Kingdom: %s" % String(session["kingdom_name"]))
	print("Seed: %d" % int(session["world_seed"]))
	print("Saved citizens: %d" % citizens.size())
	print("Saved buildings: %d" % building_entries.size())
	print("Saved economy:")
	print(
		"Last processed day: %d"
		% int(economy["last_processed_absolute_day"])
	)
	print("Has report: %s" % str(bool(economy["has_economy_report"])))
	print("Saved stability:")
	print("Value: %d" % int(stability_data["stability"]))
	print("Last change: %d" % int(stability_data["last_stability_change"]))
	print(
		"Last processed day: %d"
		% int(stability_data["last_processed_absolute_day"])
	)
	print("Saved events:")
	print("Active event: %s" % str(bool(events["has_active_event"])))
	print("Latest result: %s" % str(bool(events["has_latest_result"])))
	print("Last event day: %d" % int(events["last_event_day"]))
	print("Saved states: %d" % states.size())
	print("Saved spy missions: %d" % missions.size())
	print("Saved trade offers used: %d" % trade_offer_uses.size())
	print("Saved special goods:")
	print("Northern bows: %d" % int(goods["northern_bows"]))
	print("Suncoast cattle: %d" % int(goods["suncoast_cattle"]))
	print("Iron weapons: %d" % int(goods["iron_weapons"]))
	print("Saved army:")
	print("Assignments: %d" % assignments.size())
	print("Equipped bows: %d" % int(equipped_goods["northern_bows"]))
	print("Equipped weapons: %d" % int(equipped_goods["iron_weapons"]))
	var war_state_id := String(war["current_war_state_id"])
	print("Saved war:")
	print("State: %s" % (war_state_id if not war_state_id.is_empty() else "none"))
	print("Active campaign: %s" % str(not war["active_campaign"].is_empty()))
	print("Latest report: %s" % str(bool(war["has_latest_report"])))


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)
