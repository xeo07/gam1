extends CanvasLayer
class_name BottomHUD

signal hud_height_changed(height: float)
signal population_section_pressed
signal army_section_pressed
signal stability_section_pressed
signal resources_section_pressed
signal next_day_pressed
signal relations_pressed
signal hiring_pressed
signal messenger_pressed

const SEGMENT_COUNT := 10
const DEFAULT_HUD_HEIGHT := 140.0

@onready var bottom_container: Control = $BottomContainer
@onready var hbox_container: HBoxContainer = $BottomContainer/PanelContainer/MarginContainer/HBoxContainer
@onready var left_stats: VBoxContainer = hbox_container.get_node("LeftStatsSection/VBoxContainer") as VBoxContainer
@onready var population_value_label: Label = left_stats.get_node("PopulationButtonArea/HBoxContainer/PopulationValueLabel") as Label
@onready var free_places_label: Label = left_stats.get_node("PopulationButtonArea/HBoxContainer/FreePlacesLabel") as Label
@onready var army_value_label: Label = left_stats.get_node("ArmyButtonArea/HBoxContainer/ArmyValueLabel") as Label
@onready var stability_value_label: Label = left_stats.get_node("StabilityButtonArea/VBoxContainer/StabilityHeader/StabilityValueLabel") as Label
@onready var stability_bar: HBoxContainer = left_stats.get_node("StabilityButtonArea/VBoxContainer/StabilityBar") as HBoxContainer
@onready var identity_hbox: HBoxContainer = hbox_container.get_node("IdentitySection/PanelContainer/MarginContainer/HBoxContainer") as HBoxContainer
@onready var emblem_texture_rect: TextureRect = identity_hbox.get_node("EmblemContainer/EmblemTextureRect") as TextureRect
@onready var main_identity: VBoxContainer = identity_hbox.get_node("MainIdentityContainer/VBoxContainer") as VBoxContainer
@onready var kingdom_name_label: Label = main_identity.get_node("KingdomNameLabel") as Label
@onready var flag_texture_rect: TextureRect = main_identity.get_node("IdentityContentRow/FlagAspectContainer/FlagTextureRect") as TextureRect
@onready var date_grid: GridContainer = hbox_container.get_node("DateSection/GridContainer") as GridContainer
@onready var day_value_label: Label = date_grid.get_node("DayValueLabel") as Label
@onready var month_value_label: Label = date_grid.get_node("MonthValueLabel") as Label
@onready var year_value_label: Label = date_grid.get_node("YearValueLabel") as Label
@onready var resources_section: PanelContainer = hbox_container.get_node("ResourcesSection") as PanelContainer
@onready var resources_grid: GridContainer = resources_section.get_node("GridContainer") as GridContainer
@onready var food_value_label: Label = resources_grid.get_node("FoodValueLabel") as Label
@onready var wood_value_label: Label = resources_grid.get_node("WoodValueLabel") as Label
@onready var stone_value_label: Label = resources_grid.get_node("StoneValueLabel") as Label
@onready var gold_value_label: Label = resources_grid.get_node("GoldValueLabel") as Label
@onready var population_button: Button = left_stats.get_node("PopulationButtonArea/PopulationSectionButton") as Button
@onready var army_button: Button = left_stats.get_node("ArmyButtonArea/ArmySectionButton") as Button
@onready var stability_button: Button = left_stats.get_node("StabilityButtonArea/StabilitySectionButton") as Button
@onready var resources_button: Button = resources_section.get_node("ResourcesSectionButton") as Button
@onready var next_day_button: Button = main_identity.get_node("IdentityContentRow/ActionButtonsContainer/NextDayButton") as Button
@onready var relations_button: Button = main_identity.get_node("IdentityContentRow/ActionButtonsContainer/RelationsButton") as Button

@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var event_manager: EventManager = $"../EventManager" as EventManager

var _segments: Array[Panel] = []
var _last_height := 0.0


func _ready() -> void:
	_build_stability_segments()
	population_button.pressed.connect(
		func() -> void: population_section_pressed.emit()
	)
	army_button.pressed.connect(
		func() -> void: army_section_pressed.emit()
	)
	stability_button.pressed.connect(
		func() -> void: stability_section_pressed.emit()
	)
	resources_button.pressed.connect(
		func() -> void: resources_section_pressed.emit()
	)
	next_day_button.pressed.connect(
		func() -> void: hiring_pressed.emit()
	)
	relations_button.pressed.connect(
		func() -> void: messenger_pressed.emit()
	)
	game_session_manager.kingdom_name_changed.connect(_on_kingdom_name_changed)
	game_session_manager.session_initialized.connect(_refresh_identity)
	game_session_manager.identity_visuals_changed.connect(_refresh_identity)
	time_manager.day_changed.connect(_on_date_changed)
	time_manager.time_loaded.connect(_on_date_changed)
	resource_manager.resources_changed.connect(_on_resources_changed)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.population_capacity_changed.connect(_on_population_capacity_changed)
	army_manager.army_changed.connect(_on_army_changed)
	stability_manager.stability_changed.connect(_on_stability_changed)
	event_manager.event_state_changed.connect(_update_event_lock)
	bottom_container.minimum_size_changed.connect(_queue_height_update)
	get_viewport().size_changed.connect(_queue_height_update)
	_on_kingdom_name_changed(game_session_manager.get_kingdom_name())
	_on_date_changed(time_manager.day, time_manager.month, time_manager.year)
	resource_manager.emit_current_resources()
	population_manager.emit_population_capacity()
	_on_army_changed()
	_on_stability_changed(
		stability_manager.get_stability(),
		stability_manager.get_last_stability_change(),
		stability_manager.get_last_change_reasons()
	)
	_refresh_identity()
	_update_event_lock()
	_queue_height_update()


func get_hud_height() -> float:
	return DEFAULT_HUD_HEIGHT


func _on_kingdom_name_changed(name: String) -> void:
	var _unused := name
	kingdom_name_label.text = "ВЕРНОСТЬ  %d" % roundi(population_manager.get_average_loyalty())


func _refresh_identity() -> void:
	flag_texture_rect.texture = game_session_manager.get_flag_texture()
	emblem_texture_rect.texture = game_session_manager.get_emblem_texture()


func _on_date_changed(day: int, month: int, year: int) -> void:
	day_value_label.text = str(day)
	month_value_label.text = str(month)
	year_value_label.text = str(year)


func _on_resources_changed(food: int, wood: int, stone: int, gold: int) -> void:
	food_value_label.text = str(food)
	wood_value_label.text = str(wood)
	stone_value_label.text = str(stone)
	gold_value_label.text = str(gold)


func _on_population_changed(total_population: int) -> void:
	population_value_label.text = "%d/%d" % [total_population, population_manager.get_population_capacity()]
	free_places_label.text = "свободно: %d" % maxi(0, population_manager.get_population_capacity() - total_population)
	kingdom_name_label.text = "ВЕРНОСТЬ  %d" % roundi(population_manager.get_average_loyalty())


func _on_population_capacity_changed(current: int, maximum: int) -> void:
	population_value_label.text = "%d/%d" % [current, maximum]
	free_places_label.text = "свободно: %d" % maxi(0, maximum - current)


func _on_army_changed() -> void:
	army_value_label.text = str(army_manager.calculate_total_military_strength())


func _on_stability_changed(value: int, _change: int, _reasons: Array[String]) -> void:
	stability_value_label.text = str(value)
	var filled_segments := clampi(ceili(float(value) / 10.0), 0, SEGMENT_COUNT)
	var filled_variation: StringName
	if value >= 70:
		filled_variation = &"StabilityHighSegment"
	elif value >= 40:
		filled_variation = &"StabilityMediumSegment"
	else:
		filled_variation = &"StabilityLowSegment"
	for index in _segments.size():
		_segments[index].theme_type_variation = filled_variation if index < filled_segments else &"StabilityEmptySegment"


func _update_event_lock() -> void:
	var locked := event_manager.has_active_event()
	for button in [
		population_button,
		army_button,
		stability_button,
		resources_button,
		next_day_button,
		relations_button,
	]:
		button.disabled = locked
	next_day_button.tooltip_text = (
		"Сначала примите решение по текущему событию" if locked else ""
	)


func _build_stability_segments() -> void:
	for child in stability_bar.get_children():
		stability_bar.remove_child(child)
		child.queue_free()
	_segments.clear()
	for _index in SEGMENT_COUNT:
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(7, 13)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stability_bar.add_child(segment)
		_segments.append(segment)


func _queue_height_update() -> void:
	_update_height.call_deferred()


func _update_height() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	bottom_container.position = Vector2(0.0, maxf(viewport_size.y - DEFAULT_HUD_HEIGHT, 0.0))
	bottom_container.size = Vector2(viewport_size.x, minf(DEFAULT_HUD_HEIGHT, viewport_size.y))
	if is_equal_approx(DEFAULT_HUD_HEIGHT, _last_height):
		return
	_last_height = DEFAULT_HUD_HEIGHT
	hud_height_changed.emit(DEFAULT_HUD_HEIGHT)
