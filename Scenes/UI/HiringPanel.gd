extends CanvasLayer
class_name HiringPanel

const CONTENT_PATH := "Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer"

@onready var content: VBoxContainer = get_node(CONTENT_PATH) as VBoxContainer
@onready var body: VBoxContainer = content.get_node("BodyScroll/BodyContent") as VBoxContainer
@onready var population_label: Label = body.get_node("PopulationLabel") as Label
@onready var status_label: Label = body.get_node("StatusLabel") as Label
@onready var hire_button: Button = body.get_node("HireButton") as Button
@onready var close_button: Button = content.get_node("Footer/CloseButton") as Button
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager


func _ready() -> void:
	hire_button.pressed.connect(_on_hire_pressed)
	close_button.pressed.connect(close_panel)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.population_capacity_changed.connect(_on_population_capacity_changed)
	resource_manager.resources_changed.connect(_on_resources_changed)


func open_panel() -> void:
	visible = true
	status_label.text = ""
	_refresh_display()


func close_panel() -> void:
	visible = false


func _on_hire_pressed() -> void:
	if population_manager.hire_random_citizen():
		status_label.text = "Новый житель нанят"
	elif not population_manager.can_add_citizen():
		status_label.text = "Нет свободного жилья"
	else:
		status_label.text = "Недостаточно ресурсов"
	_refresh_display()


func _on_population_changed(_total_population: int) -> void:
	if visible:
		_refresh_display()


func _on_population_capacity_changed(
	_current_population: int,
	_maximum_population: int
) -> void:
	if visible:
		_refresh_display()


func _on_resources_changed(
	_food: int,
	_wood: int,
	_stone: int,
	_gold: int
) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	var current_population := population_manager.get_population_count()
	var maximum_population := population_manager.get_population_capacity()
	population_label.text = "Население: %d/%d" % [
		current_population,
		maximum_population,
	]
	hire_button.disabled = (
		not population_manager.can_add_citizen()
		or not resource_manager.has_resource(
			&"food",
			PopulationManager.HIRE_FOOD_COST
		)
		or not resource_manager.has_resource(
			&"gold",
			PopulationManager.HIRE_GOLD_COST
		)
	)
