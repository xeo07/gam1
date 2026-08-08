extends Node
class_name SpecialGoodsManager

signal special_goods_changed(goods: Dictionary)

const GOODS_DISPLAY_NAMES: Dictionary = {
	&"northern_bows": "Северные луки",
	&"suncoast_cattle": "Породистый скот",
	&"iron_weapons": "Железное оружие",
}

var _goods: Dictionary = {
	&"northern_bows": 0,
	&"suncoast_cattle": 0,
	&"iron_weapons": 0,
}


func get_amount(goods_id: StringName) -> int:
	if not is_valid_goods(goods_id):
		return 0
	return int(_goods[goods_id])


func has_goods(goods_id: StringName, amount: int) -> bool:
	return amount >= 0 and is_valid_goods(goods_id) and get_amount(goods_id) >= amount


func add_goods(goods_id: StringName, amount: int) -> bool:
	if amount < 0 or not is_valid_goods(goods_id):
		return false
	if amount == 0:
		return true
	_goods[goods_id] = get_amount(goods_id) + amount
	_emit_goods_changed()
	return true


func remove_goods(goods_id: StringName, amount: int) -> bool:
	if amount < 0 or not has_goods(goods_id, amount):
		return false
	if amount == 0:
		return true
	_goods[goods_id] = get_amount(goods_id) - amount
	_emit_goods_changed()
	return true


func get_all_goods() -> Dictionary:
	return _goods.duplicate(true)


func get_display_name(goods_id: StringName) -> String:
	return String(GOODS_DISPLAY_NAMES.get(goods_id, "Неизвестный товар"))


func is_valid_goods(goods_id: StringName) -> bool:
	return _goods.has(goods_id)


func emit_current_goods() -> void:
	special_goods_changed.emit(get_all_goods())


func _emit_goods_changed() -> void:
	emit_current_goods()
	print("Special goods changed:")
	print("Northern bows: %d" % get_amount(&"northern_bows"))
	print("Suncoast cattle: %d" % get_amount(&"suncoast_cattle"))
	print("Iron weapons: %d" % get_amount(&"iron_weapons"))


func get_save_data() -> Dictionary:
	return {
		"goods": {
			"northern_bows": get_amount(&"northern_bows"),
			"suncoast_cattle": get_amount(&"suncoast_cattle"),
			"iron_weapons": get_amount(&"iron_weapons"),
		},
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has("goods") or not data["goods"] is Dictionary:
		return false
	var saved_goods: Dictionary = data["goods"]
	if saved_goods.size() != GOODS_DISPLAY_NAMES.size():
		return false

	var loaded_goods: Dictionary = {}
	for goods_id in GOODS_DISPLAY_NAMES.keys():
		var saved_id := String(goods_id)
		if not saved_goods.has(saved_id):
			return false
		var value: Variant = saved_goods[saved_id]
		if not _is_integer_value(value) or int(value) < 0:
			return false
		loaded_goods[goods_id] = int(value)

	for saved_id in saved_goods.keys():
		if not saved_id is String or not is_valid_goods(StringName(saved_id)):
			return false

	_goods = loaded_goods
	_emit_goods_changed()
	return true


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
