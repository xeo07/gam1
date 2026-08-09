extends CanvasLayer
class_name SituationDashboard

signal decision_pressed
signal diplomacy_pressed
signal news_pressed

@onready var dashboard: PanelContainer = $Dashboard
@onready var date_label: Label = $Dashboard/MarginContainer/VBoxContainer/Header/DateLabel
@onready var resources_label: Label = $Dashboard/MarginContainer/VBoxContainer/ResourcesCard/MarginContainer/ResourcesLabel
@onready var situation_title: Label = $Dashboard/MarginContainer/VBoxContainer/SituationCard/MarginContainer/VBoxContainer/SituationTitle
@onready var situation_body: Label = $Dashboard/MarginContainer/VBoxContainer/SituationCard/MarginContainer/VBoxContainer/SituationBody
@onready var decision_button: Button = $Dashboard/MarginContainer/VBoxContainer/SituationCard/MarginContainer/VBoxContainer/DecisionButton
@onready var consequences_label: Label = $Dashboard/MarginContainer/VBoxContainer/ConsequencesCard/MarginContainer/VBoxContainer/ConsequencesLabel
@onready var news_title: Label = $Dashboard/MarginContainer/VBoxContainer/NewsCard/MarginContainer/VBoxContainer/NewsTitle
@onready var news_body: Label = $Dashboard/MarginContainer/VBoxContainer/NewsCard/MarginContainer/VBoxContainer/NewsBody
@onready var diplomacy_button: Button = $Dashboard/MarginContainer/VBoxContainer/Actions/DiplomacyButton
@onready var news_button: Button = $Dashboard/MarginContainer/VBoxContainer/Actions/NewsButton
@onready var situation_card: PanelContainer = $Dashboard/MarginContainer/VBoxContainer/SituationCard
@onready var consequences_card: PanelContainer = $Dashboard/MarginContainer/VBoxContainer/ConsequencesCard
@onready var news_card: PanelContainer = $Dashboard/MarginContainer/VBoxContainer/NewsCard
@onready var actions: HBoxContainer = $Dashboard/MarginContainer/VBoxContainer/Actions

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var event_manager: EventManager = $"../EventManager" as EventManager
@onready var journal_manager: EventJournalManager = $"../EventJournalManager" as EventJournalManager
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager
@onready var story_manager: StoryChainManager = $"../StoryChainManager" as StoryChainManager
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var contract_manager: ContractManager = $"../ContractManager" as ContractManager
@onready var territory_manager: TerritoryManager = $"../TerritoryManager" as TerritoryManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var messenger_manager: MessengerManager = $"../MessengerManager" as MessengerManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager


func _ready() -> void:
	decision_button.pressed.connect(func() -> void: decision_pressed.emit())
	diplomacy_button.pressed.connect(func() -> void: diplomacy_pressed.emit())
	news_button.pressed.connect(func() -> void: news_pressed.emit())
	time_manager.day_changed.connect(func(_d: int, _m: int, _y: int) -> void: refresh())
	time_manager.time_loaded.connect(func(_d: int, _m: int, _y: int) -> void: refresh())
	resource_manager.resources_changed.connect(func(_f: int, _w: int, _s: int, _g: int) -> void: refresh())
	event_manager.event_state_changed.connect(refresh)
	journal_manager.entry_added.connect(func(_entry: Dictionary) -> void: refresh())
	news_manager.weekly_edition_ready.connect(func(_edition: Dictionary) -> void: refresh())
	contract_manager.contracts_changed.connect(refresh)
	territory_manager.territories_changed.connect(refresh)
	messenger_manager.report_ready.connect(func(_report: Dictionary) -> void: refresh())
	population_manager.population_changed.connect(func(_value: int) -> void: refresh())
	population_manager.population_capacity_changed.connect(func(_current: int, _maximum: int) -> void: refresh())
	refresh()


func layout_for_viewport(hud_height: float) -> float:
	var viewport := get_viewport().get_visible_rect().size
	var layout := UILayoutMetrics.calculate(viewport, hud_height)
	var rect: Rect2 = layout["dashboard_rect"]
	dashboard.position = rect.position
	dashboard.size = rect.size
	var compact := rect.size.y < 390.0
	situation_card.custom_minimum_size.y = 105.0 if compact else 145.0
	consequences_card.custom_minimum_size.y = 74.0 if compact else 100.0
	news_card.custom_minimum_size.y = 64.0 if compact else 95.0
	actions.visible = false
	return float(layout["dashboard_width"])


func refresh() -> void:
	if not is_node_ready():
		return
	date_label.text = "День %d · Месяц %d · Год %d" % [time_manager.day, time_manager.month, time_manager.year]
	resources_label.text = "ЕДА  %d     ДЕРЕВО  %d\nКАМЕНЬ  %d     ЗОЛОТО  %d" % [resource_manager.food, resource_manager.wood, resource_manager.stone, resource_manager.gold]
	_refresh_world_news()
	_refresh_kingdom_affairs()
	_refresh_intelligence()


func _refresh_world_news() -> void:
	if event_manager.has_active_event():
		var event := event_manager.get_active_event()
		situation_title.text = "ТРЕБУЕТ РЕШЕНИЯ"
		situation_body.text = String(event.get("body", "Совет ждёт решения короны."))
		var deadline := story_manager.get_choice_deadline_day()
		decision_button.text = "Принять решение%s" % (" · до дня %d" % deadline if deadline > 0 else "")
		decision_button.visible = true
		return
	situation_title.text = "НОВОСТИ МИРА"
	var edition := news_manager.get_latest_weekly_edition()
	var lines: Array[String] = []
	for article_value in edition.get("articles", []):
		if article_value is Dictionary:
			lines.append("— %s" % String(article_value.get("title", "Без заголовка")))
		if lines.size() == 4:
			break
	if lines.is_empty():
		lines.append("Гонцы собирают первые известия.")
	var remaining := 7 - time_manager.get_absolute_day() % 7
	lines.append("\nДо следующего выпуска: %d дн." % remaining)
	situation_body.text = "\n".join(PackedStringArray(lines))
	decision_button.visible = false


func _refresh_kingdom_affairs() -> void:
	var lines: Array[String] = []
	var food_days := resource_manager.food / maxi(1, population_manager.get_population_count())
	lines.append("• Запасов еды примерно на %d дн." % food_days)
	var free_places := population_manager.get_population_capacity() - population_manager.get_population_count()
	if free_places <= 0:
		lines.append("• Свободных мест для жителей нет.")
	elif free_places <= 2:
		lines.append("• Свободных мест: %d." % free_places)
	if stability_manager.get_stability() < 50:
		lines.append("• Стабильность требует внимания.")
	for mission in spy_manager.get_active_missions():
		lines.append("• Разведка вернётся через %d дн." % spy_manager.get_mission_days_remaining(StringName(mission.get("state_id", &""))))
	for contract in contract_manager.get_active_contracts():
		lines.append("• Договор действует ещё %d дн." % maxi(0, int(contract.get("end_day", 0)) - time_manager.get_absolute_day()))
	if not territory_manager.get_territories().is_empty():
		lines.append("• Снабжение земель через %d дн." % (5 - time_manager.get_absolute_day() % 5))
	if lines.is_empty():
		lines.append("• Срочных последствий не ожидается")
	consequences_label.text = "\n".join(PackedStringArray(lines.slice(0, 4)))


func _refresh_intelligence() -> void:
	news_title.text = "ПОСЛЕДНИЕ СВЕДЕНИЯ"
	var latest: Dictionary = {}
	for state in world_manager.get_all_states():
		var report := messenger_manager.get_latest_report(StringName(state.get("id", &"")))
		if not report.is_empty() and int(report.get("report_day", 0)) > int(latest.get("report_day", -1)):
			latest = report
	if latest.is_empty():
		news_body.text = "Нет свежих сведений.\nОтправьте гонца через раздел дипломатии."
	else:
		var age := maxi(0, time_manager.get_absolute_day() - int(latest.get("report_day", 0)))
		news_body.text = "%s\nСведения получены %d дн. назад." % [String(latest.get("summary", "")), age]
	news_button.disabled = news_manager.get_latest_weekly_edition().is_empty()
