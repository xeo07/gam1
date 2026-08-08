extends CanvasLayer
class_name SpecialGoodsPanel

@onready var bows_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BowsLabel
@onready var cattle_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CattleLabel
@onready var weapons_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WeaponsLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var special_goods_manager: SpecialGoodsManager = $"../SpecialGoodsManager" as SpecialGoodsManager


func _ready() -> void:
	close_button.pressed.connect(close_panel)
	special_goods_manager.special_goods_changed.connect(_on_special_goods_changed)


func open_panel() -> void:
	visible = true
	_update_goods(special_goods_manager.get_all_goods())


func close_panel() -> void:
	visible = false


func _on_special_goods_changed(goods: Dictionary) -> void:
	_update_goods(goods)


func _update_goods(goods: Dictionary) -> void:
	bows_label.text = "Северные луки: %d" % int(goods.get(&"northern_bows", 0))
	cattle_label.text = "Породистый скот: %d" % int(goods.get(&"suncoast_cattle", 0))
	weapons_label.text = "Железное оружие: %d" % int(goods.get(&"iron_weapons", 0))
