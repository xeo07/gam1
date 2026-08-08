extends Node
class_name EventManager

signal internal_event_ready(event: Dictionary)
signal internal_event_resolved(result: Dictionary)
signal internal_event_failed(reason: String)
signal event_state_changed

const MIN_DAYS_BETWEEN_EVENTS := 2
const DEFAULT_EVENT_COOLDOWN_DAYS := 6
const RANDOM_EVENT_CHANCE := 0.35

const RESOURCE_NAMES: Array[StringName] = [
	&"food", &"wood", &"stone", &"gold",
]
const KNOWN_EVENT_IDS: Array[StringName] = [
	&"hunger_crisis",
	&"treasury_crisis",
	&"public_petition",
	&"abundant_harvest",
	&"merchant_caravan",
	&"military_petition",
	&"craftsmen_initiative",
	&"chain_border_refugees",
	&"chain_grain_blight",
	&"chain_disputed_succession",
]
const CRISIS_EVENT_IDS: Array[StringName] = [
	&"hunger_crisis",
	&"treasury_crisis",
	&"public_petition",
]
const EVENT_CHOICE_IDS: Dictionary = {
	&"hunger_crisis": [
		&"open_reserves", &"buy_provisions", &"refuse_hunger_aid",
	],
	&"treasury_crisis": [
		&"sell_timber", &"sell_stone", &"delay_payments",
	],
	&"public_petition": [
		&"financial_aid", &"food_aid", &"disperse_petitioners",
	],
	&"abundant_harvest": [
		&"fill_granaries", &"sell_harvest", &"hold_festival",
	],
	&"merchant_caravan": [
		&"merchant_food", &"merchant_stone", &"merchant_refuse",
	],
	&"military_petition": [
		&"army_food", &"army_reward", &"army_refuse",
	],
	&"craftsmen_initiative": [
		&"support_workshops", &"take_materials", &"reject_initiative",
	],
	&"chain_border_refugees": [
		&"shelter_refugees", &"close_border", &"escort_refugees",
	],
	&"chain_grain_blight": [
		&"buy_seed", &"ration_grain", &"ignore_blight",
	],
	&"chain_disputed_succession": [
		&"support_claimant", &"stay_neutral", &"mediate_succession",
	],
}

@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager
@onready var economy_manager: EconomyManager = $"../EconomyManager" as EconomyManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var war_manager: WarManager = $"../WarManager" as WarManager

var active_event: Dictionary = {}
var has_active_event_flag: bool = false
var latest_result: Dictionary = {}
var has_latest_result_flag: bool = false
var last_processed_absolute_day: int = 0
var last_event_day: int = -1000
var last_event_id: StringName = &""
var event_last_triggered_days: Dictionary = {}


func _ready() -> void:
	stability_manager.stability_day_completed.connect(
		_on_stability_day_completed,
		ConnectFlags.CONNECT_DEFERRED
	)


func initialize_new_game() -> void:
	active_event.clear()
	has_active_event_flag = false
	latest_result.clear()
	has_latest_result_flag = false
	last_processed_absolute_day = time_manager.get_absolute_day()
	last_event_day = -1000
	last_event_id = &""
	event_last_triggered_days.clear()
	event_state_changed.emit()


func try_generate_event(stability_data: Dictionary) -> bool:
	if stability_data.is_empty():
		return false
	var absolute_day := time_manager.get_absolute_day()
	if absolute_day <= last_processed_absolute_day:
		return false
	last_processed_absolute_day = absolute_day
	if has_active_event():
		return false
	var economy_report := economy_manager.get_last_economy_report()
	if economy_report.is_empty():
		return false
	if absolute_day - last_event_day < MIN_DAYS_BETWEEN_EVENTS:
		return false

	var eligible_ids := get_eligible_event_ids(economy_report)
	if eligible_ids.is_empty():
		return false
	var selected_event_id: StringName = &""
	for crisis_id in CRISIS_EVENT_IDS:
		if crisis_id in eligible_ids:
			selected_event_id = crisis_id
			break

	var rng := game_session_manager.get_rng()
	if selected_event_id == &"":
		if rng.randf() >= RANDOM_EVENT_CHANCE:
			return false
		var random_candidates: Array[StringName] = []
		for event_id in eligible_ids:
			if event_id not in CRISIS_EVENT_IDS:
				random_candidates.append(event_id)
		if random_candidates.is_empty():
			return false
		if random_candidates.size() > 1 and last_event_id in random_candidates:
			random_candidates.erase(last_event_id)
		selected_event_id = random_candidates[
			rng.randi_range(0, random_candidates.size() - 1)
		]

	var created_event := create_event(selected_event_id)
	if created_event.is_empty():
		return false
	return _activate_event(selected_event_id, created_event, absolute_day)


func present_story_event(event_id: StringName) -> bool:
	if has_active_event() or StoryChainDefinition.chain_from_event(event_id) == &"":
		return false
	var created_event := create_event(event_id)
	if created_event.is_empty():
		return false
	return _activate_event(event_id, created_event, time_manager.get_absolute_day())


func get_eligible_event_ids(economy_report: Dictionary) -> Array[StringName]:
	var eligible: Array[StringName] = []
	if not economy_report.get("shortages", null) is Dictionary:
		return eligible
	var shortages: Dictionary = economy_report["shortages"]
	if not shortages.has_all(["food", "wood", "stone", "gold"]):
		return eligible
	var absolute_day := time_manager.get_absolute_day()
	if int(shortages.get("food", 0)) > 0 and _is_event_off_cooldown(
		&"hunger_crisis", absolute_day
	):
		eligible.append(&"hunger_crisis")
	if int(shortages.get("gold", 0)) > 0 and _is_event_off_cooldown(
		&"treasury_crisis", absolute_day
	):
		eligible.append(&"treasury_crisis")
	if (
		stability_manager.get_stability() < 50
		or population_manager.get_average_loyalty() < 6.0
	) and _is_event_off_cooldown(&"public_petition", absolute_day):
		eligible.append(&"public_petition")
	if (
		int(shortages.get("food", 0)) == 0
		and economy_manager.get_active_worker_count(&"farmer") > 0
		and stability_manager.get_stability() >= 60
		and _is_event_off_cooldown(&"abundant_harvest", absolute_day)
	):
		eligible.append(&"abundant_harvest")
	if _is_event_off_cooldown(&"merchant_caravan", absolute_day):
		eligible.append(&"merchant_caravan")
	if (
		army_manager.get_all_assignments().size() > 0
		and _is_event_off_cooldown(&"military_petition", absolute_day)
	):
		eligible.append(&"military_petition")
	if _has_craftsman() and _is_event_off_cooldown(
		&"craftsmen_initiative", absolute_day
	):
		eligible.append(&"craftsmen_initiative")
	return eligible


func create_event(event_id: StringName) -> Dictionary:
	var choices: Array[Dictionary] = []
	var title := ""
	var body := ""
	match event_id:
		&"hunger_crisis":
			title = "Голодные семьи"
			body = "К дворцу пришли жители, которым не хватает продовольствия. Они требуют немедленной помощи."
			choices = [
				_choice(&"open_reserves", "Открыть резервные склады", "Выдать населению 5 единиц еды.", {"food": 5}, {"food": -5, "stability": 3, "loyalty_all": 1}, "Запасы распределены среди нуждающихся. Жители благодарны правителю."),
				_choice(&"buy_provisions", "Закупить провиант", "Потратить 8 золота и получить 10 еды.", {"gold": 8}, {"gold": -8, "food": 10, "stability": 2}, "Купцы доставили продовольствие. Самый острый кризис удалось смягчить."),
				_choice(&"refuse_hunger_aid", "Отказать в помощи", "Сохранить ресурсы, но вызвать недовольство.", {}, {"stability": -4, "loyalty_all": -1}, "Просители ушли ни с чем. Недовольство правителем усилилось."),
			]
		&"treasury_crisis":
			title = "Пустая казна"
			body = "Казна не смогла полностью покрыть содержание государства. Совет требует срочного решения."
			choices = [
				_choice(&"sell_timber", "Продать часть древесины", "Обменять 10 дерева на 7 золота.", {"wood": 10}, {"wood": -10, "gold": 7, "stability": -1}, "Часть строительных запасов продана. Казна получила временную передышку."),
				_choice(&"sell_stone", "Продать часть камня", "Обменять 5 камня на 6 золота.", {"stone": 5}, {"stone": -5, "gold": 6, "stability": -1}, "Каменные запасы сократились, но государственные выплаты удалось продолжить."),
				_choice(&"delay_payments", "Отложить выплаты", "Не тратить ресурсы.", {}, {"stability": -3, "loyalty_all": -1}, "Выплаты отложены. Жители и служащие недовольны решением."),
			]
		&"public_petition":
			title = "Прошение жителей"
			body = "Представители населения просят правителя принять меры для улучшения жизни в государстве."
			choices = [
				_choice(&"financial_aid", "Выделить денежную помощь", "Потратить 5 золота.", {"gold": 5}, {"gold": -5, "stability": 2, "loyalty_all": 2}, "Помощь распределена. Доверие жителей к правителю выросло."),
				_choice(&"food_aid", "Раздать продовольствие", "Потратить 8 еды.", {"food": 8}, {"food": -8, "stability": 1, "loyalty_all": 2}, "Продовольствие передано населению. Просители покинули дворец удовлетворёнными."),
				_choice(&"disperse_petitioners", "Разогнать просителей", "Не тратить ресурсы.", {}, {"stability": -4, "loyalty_all": -2}, "Стража разогнала собравшихся. Напряжение в государстве усилилось."),
			]
		&"abundant_harvest":
			title = "Богатый урожай"
			body = "Фермеры сообщают о хорошем урожае. Совет предлагает решить, как распорядиться излишками."
			choices = [
				_choice(&"fill_granaries", "Пополнить амбары", "Сохранить урожай для будущих дней.", {}, {"food": 12}, "Излишки отправлены в государственные амбары."),
				_choice(&"sell_harvest", "Продать излишки", "Получить золото вместо продовольствия.", {}, {"gold": 8}, "Урожай продан приезжим купцам. Казна пополнилась."),
				_choice(&"hold_festival", "Устроить праздник", "Использовать урожай для поддержки населения.", {}, {"stability": 3, "loyalty_all": 1}, "В государстве прошёл праздник. Настроение населения улучшилось."),
			]
		&"merchant_caravan":
			title = "Караван купцов"
			body = "Через государство проходит торговый караван. Купцы предлагают несколько разовых сделок."
			choices = [
				_choice(&"merchant_food", "Купить продовольствие", "Потратить 6 золота и получить 10 еды.", {"gold": 6}, {"gold": -6, "food": 10}, "Купцы передали продовольствие и продолжили путь."),
				_choice(&"merchant_stone", "Обменять древесину на камень", "Отдать 8 дерева и получить 5 камня.", {"wood": 8}, {"wood": -8, "stone": 5}, "Обмен завершён. Государство получило новую партию камня."),
				_choice(&"merchant_refuse", "Отказаться от торговли", "Не менять ресурсы.", {}, {}, "Правитель отказался от предложений. Караван покинул государство."),
			]
		&"military_petition":
			title = "Просьба воинов"
			body = "Представители армии просят выделить дополнительные средства и продовольствие."
			choices = [
				_choice(&"army_food", "Выдать дополнительное довольствие", "Потратить 5 еды.", {"food": 5}, {"food": -5, "stability": 1}, "Воины получили дополнительное довольствие."),
				_choice(&"army_reward", "Выдать награду", "Потратить 5 золота.", {"gold": 5}, {"gold": -5, "stability": 2}, "Военные получили награду. Авторитет правителя укрепился."),
				_choice(&"army_refuse", "Отказать", "Не тратить ресурсы.", {}, {"stability": -2}, "Армейская делегация покинула дворец недовольной."),
			]
		&"craftsmen_initiative":
			title = "Предложение ремесленников"
			body = "Мастера предлагают расширить производство при поддержке государства."
			choices = [
				_choice(&"support_workshops", "Поддержать мастерские", "Потратить 6 золота.", {"gold": 6}, {"gold": -6, "wood": 6, "stone": 3, "stability": 1}, "Мастерские получили поддержку и передали государству часть произведённых материалов."),
				_choice(&"take_materials", "Потребовать материалы для казны", "Получить материалы, но вызвать недовольство.", {}, {"wood": 4, "stone": 2, "stability": -1}, "Часть материалов изъята для государственных нужд."),
				_choice(&"reject_initiative", "Отклонить предложение", "Не менять состояние государства.", {}, {}, "Предложение ремесленников осталось без поддержки."),
			]
		&"chain_border_refugees", &"chain_grain_blight", &"chain_disputed_succession":
			var chain_id := StoryChainDefinition.chain_from_event(event_id)
			var warning := StoryChainDefinition.get_warning(chain_id)
			title = String(warning.get("title", ""))
			body = String(warning.get("body", ""))
			for choice_value in warning.get("choices", []):
				var choice: Dictionary = choice_value
				choices.append(_choice(
					StringName(choice.get("choice_id", &"")),
					String(choice.get("text", "")),
					String(choice.get("description", "")),
					choice.get("requirements", {}),
					choice.get("effects", {}),
					String(choice.get("result_text", ""))
				))
		_:
			return {}
	return {
		"event_id": event_id,
		"title": title,
		"body": body,
		"created_day": time_manager.day,
		"created_month": time_manager.month,
		"created_year": time_manager.year,
		"created_absolute_day": time_manager.get_absolute_day(),
		"choices": choices,
	}


func has_active_event() -> bool:
	return has_active_event_flag and not active_event.is_empty()


func get_active_event() -> Dictionary:
	return active_event.duplicate(true) if has_active_event() else {}


func get_latest_result() -> Dictionary:
	return latest_result.duplicate(true) if has_latest_result() else {}


func has_latest_result() -> bool:
	return has_latest_result_flag and not latest_result.is_empty()


func can_resolve_choice(choice_id: StringName) -> bool:
	return get_choice_failure_reason(choice_id).is_empty()


func get_choice_failure_reason(choice_id: StringName) -> String:
	if not has_active_event():
		return "Активное событие отсутствует"
	var choice := _find_choice(choice_id)
	if choice.is_empty():
		return "Вариант решения не найден"
	var requirements: Dictionary = choice["requirements"]["resources"]
	var effects: Dictionary = choice["effects"]["resources"]
	for resource_name in RESOURCE_NAMES:
		var required := maxi(
			int(requirements.get(String(resource_name), 0)),
			maxi(-int(effects.get(String(resource_name), 0)), 0)
		)
		if not resource_manager.has_resource(resource_name, required):
			return _insufficient_resource_reason(resource_name)
	return ""


func resolve_choice(choice_id: StringName) -> bool:
	var failure_reason := get_choice_failure_reason(choice_id)
	if not failure_reason.is_empty():
		internal_event_failed.emit(failure_reason)
		return false
	var choice := _find_choice(choice_id)
	var effects: Dictionary = choice["effects"]
	var resource_effects: Dictionary = effects["resources"].duplicate(true)
	if not resource_manager.apply_resource_transaction(resource_effects):
		failure_reason = _get_transaction_failure_reason(resource_effects)
		internal_event_failed.emit(failure_reason)
		return false

	var stability_change := stability_manager.apply_external_change(
		int(effects["stability"]),
		"Решение внутреннего события: %s" % String(active_event["title"])
	)
	var requested_loyalty_change := int(effects["loyalty_all"])
	var changed_citizens := population_manager.apply_loyalty_change_to_all(
		requested_loyalty_change
	)
	var actual_loyalty_change := (
		requested_loyalty_change if changed_citizens > 0 else 0
	)
	var resolved_event_id: StringName = active_event["event_id"]
	latest_result = {
		"event_id": resolved_event_id,
		"event_title": String(active_event["title"]),
		"choice_id": choice_id,
		"choice_text": String(choice["text"]),
		"result_text": String(choice["result_text"]),
		"applied_effects": {
			"resources": resource_effects.duplicate(true),
			"stability": stability_change,
			"loyalty_all": actual_loyalty_change,
			"loyalty_citizens_changed": changed_citizens,
		},
		"resolved_day": time_manager.day,
		"resolved_month": time_manager.month,
		"resolved_year": time_manager.year,
	}
	has_latest_result_flag = true
	active_event.clear()
	has_active_event_flag = false
	internal_event_resolved.emit(get_latest_result())
	event_state_changed.emit()
	print("Internal event resolved:")
	print("Event: %s" % String(resolved_event_id))
	print("Choice: %s" % String(choice_id))
	print("Stability change: %d" % stability_change)
	print("Loyalty change: %d" % actual_loyalty_change)
	return true


func get_save_data() -> Dictionary:
	var triggered_days := {}
	for event_id_value in event_last_triggered_days:
		triggered_days[String(event_id_value)] = int(
			event_last_triggered_days[event_id_value]
		)
	return {
		"last_processed_absolute_day": last_processed_absolute_day,
		"last_event_day": last_event_day,
		"last_event_id": String(last_event_id),
		"event_last_triggered_days": triggered_days,
		"active_event": _event_to_save_data(active_event),
		"has_active_event": has_active_event(),
		"latest_result": _result_to_save_data(latest_result),
		"has_latest_result": has_latest_result(),
	}


func load_save_data(data: Dictionary) -> bool:
	var parsed := _parse_save_data(data)
	if not bool(parsed.get("valid", false)):
		return false
	last_processed_absolute_day = int(parsed["last_processed_absolute_day"])
	last_event_day = int(parsed["last_event_day"])
	last_event_id = parsed["last_event_id"]
	event_last_triggered_days = parsed["event_last_triggered_days"].duplicate(true)
	active_event = parsed["active_event"].duplicate(true)
	has_active_event_flag = bool(parsed["has_active_event"])
	latest_result = parsed["latest_result"].duplicate(true)
	has_latest_result_flag = bool(parsed["has_latest_result"])
	event_state_changed.emit()
	return true


func emit_event_state() -> void:
	event_state_changed.emit()


func _on_stability_day_completed(stability_data: Dictionary) -> void:
	try_generate_event(stability_data.duplicate(true))


func _activate_event(event_id: StringName, event: Dictionary, absolute_day: int) -> bool:
	active_event = event.duplicate(true)
	has_active_event_flag = true
	last_event_day = absolute_day
	last_event_id = event_id
	event_last_triggered_days[event_id] = absolute_day
	internal_event_ready.emit(get_active_event())
	event_state_changed.emit()
	print("Internal event created:")
	print("Event: %s" % String(event_id))
	print("Day: %d" % absolute_day)
	print("Choices: %d" % (active_event["choices"] as Array).size())
	return true


func _is_event_off_cooldown(event_id: StringName, absolute_day: int) -> bool:
	if not event_last_triggered_days.has(event_id):
		return true
	return (
		absolute_day - int(event_last_triggered_days[event_id])
		>= DEFAULT_EVENT_COOLDOWN_DAYS
	)


func _has_craftsman() -> bool:
	for citizen in population_manager.get_all_citizens():
		var job: StringName = citizen.get("job", &"unassigned")
		if job == &"builder" or job == &"blacksmith":
			return true
	return false


func _choice(
	choice_id: StringName,
	text: String,
	description: String,
	requirements: Dictionary,
	effects: Dictionary,
	result_text: String
) -> Dictionary:
	return {
		"choice_id": choice_id,
		"text": text,
		"description": description,
		"requirements": {
			"resources": _normalized_resources(requirements),
		},
		"effects": {
			"resources": _normalized_resources(effects),
			"stability": int(effects.get("stability", 0)),
			"loyalty_all": int(effects.get("loyalty_all", 0)),
		},
		"result_text": result_text,
	}


func _normalized_resources(source: Dictionary) -> Dictionary:
	return {
		"food": int(source.get("food", 0)),
		"wood": int(source.get("wood", 0)),
		"stone": int(source.get("stone", 0)),
		"gold": int(source.get("gold", 0)),
	}


func _find_choice(choice_id: StringName) -> Dictionary:
	if not has_active_event():
		return {}
	for choice_value in active_event["choices"]:
		var choice: Dictionary = choice_value
		if choice.get("choice_id", &"") == choice_id:
			return choice.duplicate(true)
	return {}


func _insufficient_resource_reason(resource_name: StringName) -> String:
	match resource_name:
		&"food":
			return "Недостаточно еды"
		&"wood":
			return "Недостаточно дерева"
		&"stone":
			return "Недостаточно камня"
		_:
			return "Недостаточно золота"


func _get_transaction_failure_reason(deltas: Dictionary) -> String:
	for resource_name in RESOURCE_NAMES:
		var delta := int(deltas.get(String(resource_name), 0))
		if delta < 0 and not resource_manager.has_resource(resource_name, -delta):
			return _insufficient_resource_reason(resource_name)
	return "Некорректная транзакция ресурсов"


func _event_to_save_data(event: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}
	var saved := event.duplicate(true)
	saved["event_id"] = String(event["event_id"])
	var saved_choices: Array[Dictionary] = []
	for choice_value in event["choices"]:
		var choice: Dictionary = choice_value
		var saved_choice := choice.duplicate(true)
		saved_choice["choice_id"] = String(choice["choice_id"])
		saved_choices.append(saved_choice)
	saved["choices"] = saved_choices
	return saved


func _result_to_save_data(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	var saved := result.duplicate(true)
	saved["event_id"] = String(result["event_id"])
	saved["choice_id"] = String(result["choice_id"])
	return saved


func _parse_save_data(data: Dictionary) -> Dictionary:
	if data.size() != 8:
		return {"valid": false}
	if not data.has_all([
		"last_processed_absolute_day",
		"last_event_day",
		"last_event_id",
		"event_last_triggered_days",
		"active_event",
		"has_active_event",
		"latest_result",
		"has_latest_result",
	]):
		return {"valid": false}
	if not _is_integer_value(data["last_processed_absolute_day"]):
		return {"valid": false}
	if not _is_integer_value(data["last_event_day"]):
		return {"valid": false}
	if not data["last_event_id"] is String:
		return {"valid": false}
	if not data["event_last_triggered_days"] is Dictionary:
		return {"valid": false}
	if not data["active_event"] is Dictionary or not data["latest_result"] is Dictionary:
		return {"valid": false}
	if not data["has_active_event"] is bool or not data["has_latest_result"] is bool:
		return {"valid": false}

	var current_day := time_manager.get_absolute_day()
	var loaded_processed_day := int(data["last_processed_absolute_day"])
	var loaded_event_day := int(data["last_event_day"])
	var loaded_event_id := StringName(data["last_event_id"])
	if loaded_processed_day < 0 or loaded_processed_day > current_day:
		return {"valid": false}
	if loaded_event_day != -1000 and (loaded_event_day < 1 or loaded_event_day > current_day):
		return {"valid": false}
	if loaded_event_id != &"" and loaded_event_id not in KNOWN_EVENT_IDS:
		return {"valid": false}
	if loaded_event_id == &"" and loaded_event_day != -1000:
		return {"valid": false}

	var loaded_triggered_days := {}
	for event_id_value in data["event_last_triggered_days"]:
		if not event_id_value is String:
			return {"valid": false}
		var event_id := StringName(event_id_value)
		var day_value: Variant = data["event_last_triggered_days"][event_id_value]
		if event_id not in KNOWN_EVENT_IDS or not _is_integer_value(day_value):
			return {"valid": false}
		var triggered_day := int(day_value)
		if triggered_day < 1 or triggered_day > current_day:
			return {"valid": false}
		loaded_triggered_days[event_id] = triggered_day
	if loaded_event_id != &"" and (
		not loaded_triggered_days.has(loaded_event_id)
		or int(loaded_triggered_days[loaded_event_id]) != loaded_event_day
	):
		return {"valid": false}

	var has_loaded_active := bool(data["has_active_event"])
	var has_loaded_result := bool(data["has_latest_result"])
	var active_data: Dictionary = data["active_event"]
	var result_data: Dictionary = data["latest_result"]
	if has_loaded_active != (not active_data.is_empty()):
		return {"valid": false}
	if has_loaded_result != (not result_data.is_empty()):
		return {"valid": false}
	var parsed_event := {"valid": true, "event": {}}
	if has_loaded_active:
		parsed_event = _parse_event(active_data, current_day)
		if not bool(parsed_event.get("valid", false)):
			return {"valid": false}
		var normalized_event: Dictionary = parsed_event["event"]
		if (
			normalized_event["event_id"] != loaded_event_id
			or int(normalized_event["created_absolute_day"]) != loaded_event_day
		):
			return {"valid": false}
	var parsed_result := {"valid": true, "result": {}}
	if has_loaded_result:
		parsed_result = _parse_result(result_data, current_day)
		if not bool(parsed_result.get("valid", false)):
			return {"valid": false}
	return {
		"valid": true,
		"last_processed_absolute_day": loaded_processed_day,
		"last_event_day": loaded_event_day,
		"last_event_id": loaded_event_id,
		"event_last_triggered_days": loaded_triggered_days,
		"active_event": parsed_event.get("event", {}),
		"has_active_event": has_loaded_active,
		"latest_result": parsed_result.get("result", {}),
		"has_latest_result": has_loaded_result,
	}


func _parse_event(data: Dictionary, current_day: int) -> Dictionary:
	if data.size() != 8:
		return {"valid": false}
	if not data.has_all([
		"event_id", "title", "body", "created_day", "created_month",
		"created_year", "created_absolute_day", "choices",
	]):
		return {"valid": false}
	for text_field in ["event_id", "title", "body"]:
		if not data[text_field] is String:
			return {"valid": false}
	for date_field in ["created_day", "created_month", "created_year", "created_absolute_day"]:
		if not _is_integer_value(data[date_field]):
			return {"valid": false}
	if not data["choices"] is Array:
		return {"valid": false}
	var event_id := StringName(data["event_id"])
	var created_day := int(data["created_day"])
	var created_month := int(data["created_month"])
	var created_year := int(data["created_year"])
	var created_absolute := int(data["created_absolute_day"])
	if event_id not in KNOWN_EVENT_IDS:
		return {"valid": false}
	if created_day < 1 or created_day > TimeManager.DAYS_IN_MONTH:
		return {"valid": false}
	if created_month < 1 or created_month > TimeManager.MONTHS_IN_YEAR or created_year < 1:
		return {"valid": false}
	if created_absolute != _absolute_day(created_day, created_month, created_year):
		return {"valid": false}
	if created_absolute > current_day:
		return {"valid": false}
	var choices_data: Array = data["choices"]
	if choices_data.size() < 2 or choices_data.size() > 3:
		return {"valid": false}
	var loaded_choices: Array[Dictionary] = []
	var choice_ids := {}
	for choice_value in choices_data:
		if not choice_value is Dictionary:
			return {"valid": false}
		var parsed_choice := _parse_choice(choice_value, event_id)
		if not bool(parsed_choice.get("valid", false)):
			return {"valid": false}
		var choice: Dictionary = parsed_choice["choice"]
		var choice_id: StringName = choice["choice_id"]
		if choice_ids.has(choice_id):
			return {"valid": false}
		choice_ids[choice_id] = true
		loaded_choices.append(choice)
	return {
		"valid": true,
		"event": {
			"event_id": event_id,
			"title": String(data["title"]),
			"body": String(data["body"]),
			"created_day": created_day,
			"created_month": created_month,
			"created_year": created_year,
			"created_absolute_day": created_absolute,
			"choices": loaded_choices,
		},
	}


func _parse_choice(data: Dictionary, event_id: StringName) -> Dictionary:
	if data.size() != 6:
		return {"valid": false}
	if not data.has_all([
		"choice_id", "text", "description", "requirements", "effects", "result_text",
	]):
		return {"valid": false}
	for text_field in ["choice_id", "text", "description", "result_text"]:
		if not data[text_field] is String:
			return {"valid": false}
	if not data["requirements"] is Dictionary or not data["effects"] is Dictionary:
		return {"valid": false}
	var choice_id := StringName(data["choice_id"])
	var known_choices: Array = EVENT_CHOICE_IDS[event_id]
	if choice_id not in known_choices:
		return {"valid": false}
	var requirements: Dictionary = data["requirements"]
	var effects: Dictionary = data["effects"]
	if requirements.size() != 1 or effects.size() != 3:
		return {"valid": false}
	if not requirements.has("resources") or not requirements["resources"] is Dictionary:
		return {"valid": false}
	if not effects.has_all(["resources", "stability", "loyalty_all"]):
		return {"valid": false}
	if not effects["resources"] is Dictionary:
		return {"valid": false}
	if not _is_integer_value(effects["stability"]) or not _is_integer_value(effects["loyalty_all"]):
		return {"valid": false}
	var parsed_requirements := _parse_resource_map(requirements["resources"], false)
	var parsed_effects := _parse_resource_map(effects["resources"], true)
	if not bool(parsed_requirements.get("valid", false)) or not bool(parsed_effects.get("valid", false)):
		return {"valid": false}
	var requirement_values: Dictionary = parsed_requirements["resources"]
	var effect_values: Dictionary = parsed_effects["resources"]
	for resource_name in RESOURCE_NAMES:
		if int(requirement_values[String(resource_name)]) < maxi(
			-int(effect_values[String(resource_name)]), 0
		):
			return {"valid": false}
	return {
		"valid": true,
		"choice": {
			"choice_id": choice_id,
			"text": String(data["text"]),
			"description": String(data["description"]),
			"requirements": {"resources": requirement_values},
			"effects": {
				"resources": effect_values,
				"stability": int(effects["stability"]),
				"loyalty_all": int(effects["loyalty_all"]),
			},
			"result_text": String(data["result_text"]),
		},
	}


func _parse_result(data: Dictionary, current_day: int) -> Dictionary:
	if data.size() != 9:
		return {"valid": false}
	if not data.has_all([
		"event_id", "event_title", "choice_id", "choice_text", "result_text",
		"applied_effects", "resolved_day", "resolved_month", "resolved_year",
	]):
		return {"valid": false}
	for text_field in ["event_id", "event_title", "choice_id", "choice_text", "result_text"]:
		if not data[text_field] is String:
			return {"valid": false}
	for date_field in ["resolved_day", "resolved_month", "resolved_year"]:
		if not _is_integer_value(data[date_field]):
			return {"valid": false}
	if not data["applied_effects"] is Dictionary:
		return {"valid": false}
	var event_id := StringName(data["event_id"])
	var choice_id := StringName(data["choice_id"])
	if event_id not in KNOWN_EVENT_IDS or choice_id not in EVENT_CHOICE_IDS[event_id]:
		return {"valid": false}
	var resolved_day := int(data["resolved_day"])
	var resolved_month := int(data["resolved_month"])
	var resolved_year := int(data["resolved_year"])
	if resolved_day < 1 or resolved_day > TimeManager.DAYS_IN_MONTH:
		return {"valid": false}
	if resolved_month < 1 or resolved_month > TimeManager.MONTHS_IN_YEAR or resolved_year < 1:
		return {"valid": false}
	if _absolute_day(resolved_day, resolved_month, resolved_year) > current_day:
		return {"valid": false}
	var applied: Dictionary = data["applied_effects"]
	if applied.size() != 4:
		return {"valid": false}
	if not applied.has_all([
		"resources", "stability", "loyalty_all", "loyalty_citizens_changed",
	]):
		return {"valid": false}
	if not applied["resources"] is Dictionary:
		return {"valid": false}
	if not _is_integer_value(applied["stability"]):
		return {"valid": false}
	if not _is_integer_value(applied["loyalty_all"]):
		return {"valid": false}
	if not _is_integer_value(applied["loyalty_citizens_changed"]):
		return {"valid": false}
	if int(applied["loyalty_citizens_changed"]) < 0:
		return {"valid": false}
	var parsed_resources := _parse_resource_map(applied["resources"], true)
	if not bool(parsed_resources.get("valid", false)):
		return {"valid": false}
	return {
		"valid": true,
		"result": {
			"event_id": event_id,
			"event_title": String(data["event_title"]),
			"choice_id": choice_id,
			"choice_text": String(data["choice_text"]),
			"result_text": String(data["result_text"]),
			"applied_effects": {
				"resources": parsed_resources["resources"],
				"stability": int(applied["stability"]),
				"loyalty_all": int(applied["loyalty_all"]),
				"loyalty_citizens_changed": int(applied["loyalty_citizens_changed"]),
			},
			"resolved_day": resolved_day,
			"resolved_month": resolved_month,
			"resolved_year": resolved_year,
		},
	}


func _parse_resource_map(data: Dictionary, allow_negative: bool) -> Dictionary:
	if data.size() != RESOURCE_NAMES.size():
		return {"valid": false}
	var normalized := {}
	for resource_value in data:
		var resource_name := StringName(resource_value)
		if resource_name not in RESOURCE_NAMES:
			return {"valid": false}
		if not _is_integer_value(data[resource_value]):
			return {"valid": false}
		var amount := int(data[resource_value])
		if not allow_negative and amount < 0:
			return {"valid": false}
		normalized[String(resource_name)] = amount
	for resource_name in RESOURCE_NAMES:
		if not normalized.has(String(resource_name)):
			return {"valid": false}
	return {"valid": true, "resources": normalized}


func _absolute_day(day: int, month: int, year: int) -> int:
	return (year - 1) * 360 + (month - 1) * 30 + day


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
