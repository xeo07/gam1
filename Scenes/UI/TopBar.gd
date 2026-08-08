extends CanvasLayer
class_name TopBar

signal menu_button_pressed
signal bar_height_changed(height: float)

const MINIMUM_BAR_HEIGHT := 56.0
const VERTICAL_MARGINS := 16.0

@onready var margin_container: MarginContainer = $MarginContainer
@onready var hbox_container: HBoxContainer = $MarginContainer/HBoxContainer
@onready var menu_button: Button = $MarginContainer/HBoxContainer/MenuButton
@onready var kingdom_name_label: Label = $MarginContainer/HBoxContainer/KingdomNameLabel
@onready var day_label: Label = $MarginContainer/HBoxContainer/DayLabel
@onready var food_label: Label = $MarginContainer/HBoxContainer/ResourcesContainer/FoodLabel
@onready var wood_label: Label = $MarginContainer/HBoxContainer/ResourcesContainer/WoodLabel
@onready var stone_label: Label = $MarginContainer/HBoxContainer/ResourcesContainer/StoneLabel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/ResourcesContainer/GoldLabel
@onready var population_label: Label = $MarginContainer/HBoxContainer/StatusContainer/PopulationLabel
@onready var military_strength_label: Label = $MarginContainer/HBoxContainer/StatusContainer/MilitaryStrengthLabel
@onready var stability_label: Label = $MarginContainer/HBoxContainer/StatusContainer/StabilityLabel
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var army_manager: ArmyManager = $"../ArmyManager" as ArmyManager
@onready var stability_manager: StabilityManager = $"../StabilityManager" as StabilityManager
@onready var game_session_manager: GameSessionManager = $"../GameSessionManager" as GameSessionManager

var _bar_height := MINIMUM_BAR_HEIGHT
var _layout_update_queued := false


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_button_pressed)
	game_session_manager.kingdom_name_changed.connect(_on_kingdom_name_changed)
	game_session_manager.session_initialized.connect(_on_session_initialized)
	time_manager.day_changed.connect(_on_day_changed)
	time_manager.time_loaded.connect(_on_day_changed)
	resource_manager.resources_changed.connect(_on_resources_changed)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.population_capacity_changed.connect(_on_population_capacity_changed)
	army_manager.army_changed.connect(_on_army_changed)
	stability_manager.stability_changed.connect(_on_stability_changed)
	stability_manager.internal_state_changed.connect(_on_internal_state_changed)
	hbox_container.minimum_size_changed.connect(_queue_layout_update)
	get_viewport().size_changed.connect(_queue_layout_update)
	time_manager.emit_current_date()
	resource_manager.emit_current_resources()
	population_manager.emit_current_population()
	population_manager.emit_population_capacity()
	_on_army_changed()
	_on_stability_changed(
		stability_manager.get_stability(),
		stability_manager.get_last_stability_change(),
		stability_manager.get_last_change_reasons()
	)
	_queue_layout_update()


func _on_kingdom_name_changed(kingdom_name: String) -> void:
	kingdom_name_label.text = "Государство: %s" % kingdom_name
	_queue_layout_update()


func _on_session_initialized() -> void:
	_on_kingdom_name_changed(game_session_manager.get_kingdom_name())


func get_bar_height() -> float:
	return _bar_height


func _on_menu_button_pressed() -> void:
	menu_button_pressed.emit()


func _on_day_changed(day: int, month: int, year: int) -> void:
	day_label.text = "День %d   Месяц %d   Год %d" % [day, month, year]
	_queue_layout_update()


func _on_resources_changed(food: int, wood: int, stone: int, gold: int) -> void:
	food_label.text = "Еда: %d" % food
	wood_label.text = "Дерево: %d" % wood
	stone_label.text = "Камень: %d" % stone
	gold_label.text = "Золото: %d" % gold
	_queue_layout_update()


func _on_population_changed(total_population: int) -> void:
	population_label.text = "Жители: %d/%d" % [
		total_population,
		population_manager.get_population_capacity(),
	]
	_queue_layout_update()


func _on_population_capacity_changed(
	current_population: int,
	maximum_population: int
) -> void:
	population_label.text = "Жители: %d/%d" % [
		current_population,
		maximum_population,
	]
	_queue_layout_update()


func _on_army_changed() -> void:
	military_strength_label.text = "Армия: %d" % army_manager.calculate_total_military_strength()
	_queue_layout_update()


func _on_stability_changed(
	value: int,
	_change: int,
	_reasons: Array[String]
) -> void:
	stability_label.text = "Стабильность: %d" % value
	_queue_layout_update()


func _on_internal_state_changed(_state_id: StringName) -> void:
	_queue_layout_update()


func _queue_layout_update() -> void:
	if _layout_update_queued:
		return
	_layout_update_queued = true
	_update_bar_height.call_deferred()


func _update_bar_height() -> void:
	_layout_update_queued = false
	var content_height := hbox_container.get_combined_minimum_size().y
	var new_height := maxf(MINIMUM_BAR_HEIGHT, content_height + VERTICAL_MARGINS)
	margin_container.offset_bottom = new_height
	if is_equal_approx(_bar_height, new_height):
		return
	_bar_height = new_height
	bar_height_changed.emit(_bar_height)
