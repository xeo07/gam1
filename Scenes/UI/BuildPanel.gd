extends CanvasLayer
class_name BuildPanel

signal house_selected
signal lumber_camp_selected
signal farm_selected
signal mine_selected
signal barracks_selected
signal cancel_pressed

const CONTENT_PATH := "Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer"

@onready var content: VBoxContainer = get_node(CONTENT_PATH) as VBoxContainer
@onready var body: VBoxContainer = content.get_node("BodyScroll/BodyContent") as VBoxContainer
@onready var house_button: Button = body.get_node("HouseButton") as Button
@onready var lumber_camp_button: Button = body.get_node("LumberCampButton") as Button
@onready var farm_button: Button = body.get_node("FarmButton") as Button
@onready var mine_button: Button = body.get_node("MineButton") as Button
@onready var barracks_button: Button = body.get_node("BarracksButton") as Button
@onready var cancel_button: Button = content.get_node("Footer/CancelButton") as Button


func _ready() -> void:
	house_button.pressed.connect(_on_house_pressed)
	lumber_camp_button.pressed.connect(_on_lumber_camp_pressed)
	farm_button.pressed.connect(_on_farm_pressed)
	mine_button.pressed.connect(_on_mine_pressed)
	barracks_button.pressed.connect(_on_barracks_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func open_panel() -> void:
	visible = true


func close_panel() -> void:
	visible = false


func _on_house_pressed() -> void:
	house_selected.emit()


func _on_lumber_camp_pressed() -> void:
	lumber_camp_selected.emit()


func _on_farm_pressed() -> void:
	farm_selected.emit()


func _on_mine_pressed() -> void:
	mine_selected.emit()


func _on_barracks_pressed() -> void:
	barracks_selected.emit()


func _on_cancel_pressed() -> void:
	cancel_pressed.emit()
