extends CanvasLayer
class_name SituationDashboard

signal decision_pressed
signal diplomacy_pressed
signal news_pressed

@onready var dashboard: PanelContainer = $Dashboard
@onready var date_label: Label = $Dashboard/MarginContainer/VBoxContainer/Header/DateLabel
@onready var resources_label: Label = $Dashboard/MarginContainer/VBoxContainer/ResourcesCard/MarginContainer/ResourcesLabel
@onready var situation_title: Label = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/SituationCard/MarginContainer/VBoxContainer/SituationTitle
@onready var situation_body: Label = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/SituationCard/MarginContainer/VBoxContainer/SituationBody
@onready var decision_button: Button = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/SituationCard/MarginContainer/VBoxContainer/DecisionButton
@onready var consequences_label: Label = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/ConsequencesCard/MarginContainer/VBoxContainer/ConsequencesLabel
@onready var news_title: Label = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/NewsCard/MarginContainer/VBoxContainer/NewsTitle
@onready var news_body: Label = $Dashboard/MarginContainer/VBoxContainer/CardScroll/CardsVBox/NewsCard/MarginContainer/VBoxContainer/NewsBody
@onready var diplomacy_button: Button = $Dashboard/MarginContainer/VBoxContainer/Actions/DiplomacyButton
@onready var news_button: Button = $Dashboard/MarginContainer/VBoxContainer/Actions/NewsButton

@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var event_manager: EventManager = $"../EventManager" as EventManager
@onready var journal_manager: EventJournalManager = $"../EventJournalManager" as EventJournalManager
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager
@onready var story_manager: StoryChainManager = $"../StoryChainManager" as StoryChainManager
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var contract_manager: ContractManager = $"../ContractManager" as ContractManager
@onready var territory_manager: TerritoryManager = $"../TerritoryManager" as TerritoryManager


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
	refresh()


func layout_for_viewport(hud_height: float) -> float:
	var viewport := get_viewport().get_visible_rect().size
	var layout := UILayoutMetrics.calculate(viewport, hud_height)
	var rect: Rect2 = layout["dashboard_rect"]
	dashboard.position = rect.position
	dashboard.size = rect.size
	return float(layout["dashboard_width"])


func refresh() -> void:
	if not is_node_ready():
		return
	date_label.text = "День %d · Месяц %d · Год %d" % [time_manager.day, time_manager.month, time_manager.year]
	resources_label.text = "ЕДА  %d     ДЕРЕВО  %d\nКАМЕНЬ  %d     ЗОЛОТО  %d" % [resource_manager.food, resource_manager.wood, resource_manager.stone, resource_manager.gold]
	_refresh_situation()
	_refresh_consequences()
	_refresh_news()


func _refresh_situation() -> void:
	if event_manager.has_active_event():
		var event := event_manager.get_active_event()
		situation_title.text = "ТРЕБУЕТ РЕШЕНИЯ · %s" % String(event.get("title", "Событие"))
		situation_body.text = String(event.get("body", "Совет ждёт решения короны."))
		var deadline := story_manager.get_choice_deadline_day()
		decision_button.text = "Принять решение%s" % (" · до дня %d" % deadline if deadline > 0 else "")
		decision_button.visible = true
		return
	var entries := journal_manager.get_entries()
	if entries.is_empty():
		situation_title.text = "КОРОЛЕВСТВО ЖДЁТ ВАШЕГО РЕШЕНИЯ"
		situation_body.text = "Развивайте владения, собирайте сведения и следите за соседями."
	else:
		var latest: Dictionary = entries[-1]
		situation_title.text = String(latest.get("title", "Последнее событие")).to_upper()
		situation_body.text = String(latest.get("summary", ""))
	decision_button.visible = false


func _refresh_consequences() -> void:
	var lines: Array[String] = []
	for mission in spy_manager.get_active_missions():
		lines.append("• Разведка вернётся через %d дн." % spy_manager.get_mission_days_remaining(StringName(mission.get("state_id", &""))))
	for contract in contract_manager.get_active_contracts():
		lines.append("• Договор действует ещё %d дн." % maxi(0, int(contract.get("end_day", 0)) - time_manager.get_absolute_day()))
	if not territory_manager.get_territories().is_empty():
		lines.append("• Снабжение земель через %d дн." % (5 - time_manager.get_absolute_day() % 5))
	if lines.is_empty():
		lines.append("• Срочных последствий не ожидается")
	consequences_label.text = "\n".join(PackedStringArray(lines.slice(0, 4)))


func _refresh_news() -> void:
	var edition := news_manager.get_latest_weekly_edition()
	if edition.is_empty():
		news_title.text = "ВЕСТНИК · первый выпуск через %d дн." % maxi(0, 7 - time_manager.get_absolute_day())
		news_body.text = "Гонцы пока собирают первые известия."
		news_button.disabled = true
		return
	news_title.text = "ВЕСТНИК №%d" % int(edition.get("issue_number", 0))
	news_body.text = String(edition.get("headline", "Неделя прошла спокойно"))
	news_button.disabled = false
