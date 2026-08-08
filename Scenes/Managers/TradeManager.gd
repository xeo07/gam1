extends Node
class_name TradeManager

signal trade_completed(
	state_id: StringName,
	offer_id: StringName,
	transaction_type: StringName,
	resource_id: StringName,
	resource_amount: int,
	gold_amount: int
)
signal trade_failed(state_id: StringName, offer_id: StringName, reason: String)
signal trade_state_changed

const RESOURCE_DISPLAY_NAMES: Dictionary = {
	&"food": "Еда",
	&"wood": "Дерево",
	&"stone": "Камень",
}

@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var special_goods_manager: SpecialGoodsManager = $"../SpecialGoodsManager" as SpecialGoodsManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var diplomacy_manager: DiplomacyManager = $"../DiplomacyManager" as DiplomacyManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var _offers: Array[Dictionary] = [
	{
		"offer_id": &"northrealm_buy_wood",
		"state_id": &"northrealm",
		"transaction_type": &"buy",
		"goods_type": &"resource",
		"resource_id": &"wood",
		"amount": 10,
		"gold_price": 8,
		"minimum_relation": 0,
		"daily_limit": 2,
		"display_name": "Купить 10 дерева за 8 золота",
	},
	{
		"offer_id": &"northrealm_buy_stone",
		"state_id": &"northrealm",
		"transaction_type": &"buy",
		"goods_type": &"resource",
		"resource_id": &"stone",
		"amount": 5,
		"gold_price": 7,
		"minimum_relation": 15,
		"daily_limit": 1,
		"display_name": "Купить 5 камня за 7 золота",
	},
	{
		"offer_id": &"northrealm_sell_food",
		"state_id": &"northrealm",
		"transaction_type": &"sell",
		"goods_type": &"resource",
		"resource_id": &"food",
		"amount": 10,
		"gold_price": 5,
		"minimum_relation": -10,
		"daily_limit": 2,
		"display_name": "Продать 10 еды за 5 золота",
	},
	{
		"offer_id": &"suncoast_buy_food",
		"state_id": &"suncoast",
		"transaction_type": &"buy",
		"goods_type": &"resource",
		"resource_id": &"food",
		"amount": 15,
		"gold_price": 7,
		"minimum_relation": 0,
		"daily_limit": 2,
		"display_name": "Купить 15 еды за 7 золота",
	},
	{
		"offer_id": &"suncoast_buy_food_allied",
		"state_id": &"suncoast",
		"transaction_type": &"buy",
		"goods_type": &"resource",
		"resource_id": &"food",
		"amount": 25,
		"gold_price": 10,
		"minimum_relation": 35,
		"daily_limit": 1,
		"display_name": "Купить 25 еды за 10 золота",
	},
	{
		"offer_id": &"suncoast_sell_wood",
		"state_id": &"suncoast",
		"transaction_type": &"sell",
		"goods_type": &"resource",
		"resource_id": &"wood",
		"amount": 10,
		"gold_price": 6,
		"minimum_relation": 10,
		"daily_limit": 2,
		"display_name": "Продать 10 дерева за 6 золота",
	},
	{
		"offer_id": &"ironclan_buy_stone",
		"state_id": &"ironclan",
		"transaction_type": &"buy",
		"goods_type": &"resource",
		"resource_id": &"stone",
		"amount": 10,
		"gold_price": 9,
		"minimum_relation": -10,
		"daily_limit": 2,
		"display_name": "Купить 10 камня за 9 золота",
	},
	{
		"offer_id": &"ironclan_sell_food",
		"state_id": &"ironclan",
		"transaction_type": &"sell",
		"goods_type": &"resource",
		"resource_id": &"food",
		"amount": 15,
		"gold_price": 8,
		"minimum_relation": 0,
		"daily_limit": 2,
		"display_name": "Продать 15 еды за 8 золота",
	},
	{
		"offer_id": &"ironclan_sell_wood",
		"state_id": &"ironclan",
		"transaction_type": &"sell",
		"goods_type": &"resource",
		"resource_id": &"wood",
		"amount": 10,
		"gold_price": 7,
		"minimum_relation": 20,
		"daily_limit": 1,
		"display_name": "Продать 10 дерева за 7 золота",
	},
	{
		"offer_id": &"northrealm_buy_bows",
		"state_id": &"northrealm",
		"transaction_type": &"buy",
		"goods_type": &"special",
		"resource_id": &"northern_bows",
		"amount": 5,
		"gold_price": 18,
		"minimum_relation": 20,
		"daily_limit": 1,
		"display_name": "Купить 5 северных луков за 18 золота",
	},
	{
		"offer_id": &"suncoast_buy_cattle",
		"state_id": &"suncoast",
		"transaction_type": &"buy",
		"goods_type": &"special",
		"resource_id": &"suncoast_cattle",
		"amount": 2,
		"gold_price": 20,
		"minimum_relation": 25,
		"daily_limit": 1,
		"display_name": "Купить 2 головы породистого скота за 20 золота",
	},
	{
		"offer_id": &"ironclan_buy_weapons",
		"state_id": &"ironclan",
		"transaction_type": &"buy",
		"goods_type": &"special",
		"resource_id": &"iron_weapons",
		"amount": 5,
		"gold_price": 22,
		"minimum_relation": 15,
		"daily_limit": 1,
		"display_name": "Купить 5 комплектов железного оружия за 22 золота",
	},
]

var _usage_day: int
var _offer_uses: Dictionary = {}


func _ready() -> void:
	_usage_day = time_manager.get_absolute_day()
	time_manager.day_changed.connect(_on_day_changed)
	time_manager.time_loaded.connect(_on_time_loaded)


func get_all_offers() -> Array[Dictionary]:
	return _duplicate_offers(_offers)


func get_offers_for_state(state_id: StringName) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for offer in _offers:
		if offer.get("state_id", &"") == state_id:
			offers.append(offer.duplicate(true))
	return offers


func get_offer_by_id(offer_id: StringName) -> Dictionary:
	for offer in _offers:
		if offer.get("offer_id", &"") == offer_id:
			return offer.duplicate(true)
	return {}


func can_execute_offer(offer_id: StringName) -> bool:
	return get_offer_failure_reason(offer_id).is_empty()


func execute_offer(offer_id: StringName) -> bool:
	var offer := get_offer_by_id(offer_id)
	var state_id: StringName = offer.get("state_id", &"")
	var failure_reason := get_offer_failure_reason(offer_id)
	if not failure_reason.is_empty():
		trade_failed.emit(state_id, offer_id, failure_reason)
		return false

	var transaction_type: StringName = offer["transaction_type"]
	var goods_type: StringName = offer["goods_type"]
	var resource_id: StringName = offer["resource_id"]
	var amount := int(offer["amount"])
	var gold_price := int(offer["gold_price"])

	if transaction_type == &"buy":
		resource_manager.remove_resource(&"gold", gold_price)
		if goods_type == &"special":
			special_goods_manager.add_goods(resource_id, amount)
		else:
			resource_manager.add_resource(resource_id, amount)
		world_manager.change_state_wealth(state_id, gold_price)
	else:
		resource_manager.remove_resource(resource_id, amount)
		resource_manager.add_resource(&"gold", gold_price)
		world_manager.change_state_wealth(state_id, -gold_price)

	_offer_uses[offer_id] = get_offer_uses_today(offer_id) + 1
	trade_completed.emit(
		state_id,
		offer_id,
		transaction_type,
		resource_id,
		amount,
		gold_price
	)
	trade_state_changed.emit()
	_print_completed_trade(offer)
	if goods_type == &"special":
		_print_completed_special_trade(offer)
	return true


func get_offer_failure_reason(offer_id: StringName) -> String:
	var offer := get_offer_by_id(offer_id)
	if offer.is_empty():
		return "Торговое предложение не найдено"
	if not _is_offer_goods_valid(offer):
		return "Неизвестный товар"

	var state_id: StringName = offer["state_id"]
	var state := world_manager.get_state_by_id(state_id)
	if state.is_empty():
		return "Государство не найдено"

	var status: StringName = state.get("status", &"neutral")
	if status == &"enemy":
		return "Враждебное государство отказывается торговать"
	if status == &"war":
		return "Торговля невозможна во время войны"

	var block_reason := get_trade_block_reason(state_id)
	if not block_reason.is_empty():
		return block_reason

	var minimum_relation := int(offer["minimum_relation"])
	if world_manager.get_relation(state_id) < minimum_relation:
		return "Для этой сделки требуются отношения не ниже %d" % minimum_relation
	if get_offer_uses_remaining(offer_id) <= 0:
		return "Дневной лимит сделки исчерпан"

	var transaction_type: StringName = offer["transaction_type"]
	var resource_id: StringName = offer["resource_id"]
	var amount := int(offer["amount"])
	var gold_price := int(offer["gold_price"])
	if transaction_type == &"buy":
		if not resource_manager.has_resource(&"gold", gold_price):
			return "Недостаточно золота"
	else:
		if not resource_manager.has_resource(resource_id, amount):
			return "Недостаточно ресурса: %s" % _get_resource_display_name(
				resource_id
			)
		if not world_manager.can_state_pay(state_id, gold_price):
			return "У государства недостаточно золота для сделки"

	return ""


func get_offer_uses_today(offer_id: StringName) -> int:
	return int(_offer_uses.get(offer_id, 0))


func get_offer_uses_remaining(offer_id: StringName) -> int:
	var offer := get_offer_by_id(offer_id)
	if offer.is_empty():
		return 0
	return maxi(
		0,
		int(offer["daily_limit"]) - get_offer_uses_today(offer_id)
	)


func get_trade_block_reason(state_id: StringName) -> String:
	if state_id == &"ironclan" and world_manager.get_relation(&"northrealm") >= 51:
		return "Железный клан отказывается торговать с союзником Северного королевства."
	if state_id == &"northrealm" and world_manager.get_relation(&"ironclan") >= 51:
		return "Северное королевство отказывается торговать с союзником Железного клана."
	return ""


func get_save_data() -> Dictionary:
	var offer_uses: Dictionary = {}
	for offer_id_value in _offer_uses.keys():
		offer_uses[String(offer_id_value)] = int(_offer_uses[offer_id_value])
	return {
		"usage_day": _usage_day,
		"offer_uses": offer_uses,
	}


func load_save_data(data: Dictionary) -> bool:
	if not data.has_all(["usage_day", "offer_uses"]):
		return false
	if not _is_integer_value(data["usage_day"]):
		return false
	if not data["offer_uses"] is Dictionary:
		return false

	var loaded_usage_day := int(data["usage_day"])
	if loaded_usage_day < 1:
		return false
	if loaded_usage_day != time_manager.get_absolute_day():
		return false

	var loaded_offer_uses: Dictionary = {}
	var saved_offer_uses: Dictionary = data["offer_uses"]
	for offer_id_value in saved_offer_uses.keys():
		if not offer_id_value is String:
			return false
		if not _is_integer_value(saved_offer_uses[offer_id_value]):
			return false
		var offer_id := StringName(offer_id_value)
		var offer := get_offer_by_id(offer_id)
		var uses := int(saved_offer_uses[offer_id_value])
		if offer.is_empty():
			return false
		if uses < 0 or uses > int(offer["daily_limit"]):
			return false
		if uses > 0:
			loaded_offer_uses[offer_id] = uses

	_usage_day = loaded_usage_day
	_offer_uses = loaded_offer_uses
	trade_state_changed.emit()
	return true


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	var absolute_day := time_manager.get_absolute_day()
	if absolute_day == _usage_day:
		return
	_usage_day = absolute_day
	_offer_uses.clear()
	trade_state_changed.emit()
	print("Trade limits reset:")
	print("Absolute day: %d" % absolute_day)


func _on_time_loaded(_day: int, _month: int, _year: int) -> void:
	_usage_day = time_manager.get_absolute_day()


func _duplicate_offers(offers: Array[Dictionary]) -> Array[Dictionary]:
	var offers_copy: Array[Dictionary] = []
	for offer in offers:
		offers_copy.append(offer.duplicate(true))
	return offers_copy


func _get_resource_display_name(resource_id: StringName) -> String:
	return String(RESOURCE_DISPLAY_NAMES.get(resource_id, String(resource_id)))


func _is_offer_goods_valid(offer: Dictionary) -> bool:
	if not offer.has_all([
		"goods_type",
		"transaction_type",
		"resource_id",
		"amount",
		"gold_price",
	]):
		return false
	if (
		not _is_integer_value(offer["amount"])
		or not _is_integer_value(offer["gold_price"])
		or int(offer["amount"]) <= 0
		or int(offer["gold_price"]) < 0
	):
		return false
	var goods_type: StringName = offer.get("goods_type", &"")
	var transaction_type: StringName = offer.get("transaction_type", &"")
	var resource_id: StringName = offer.get("resource_id", &"")
	if goods_type == &"resource":
		return (
			transaction_type in [&"buy", &"sell"]
			and RESOURCE_DISPLAY_NAMES.has(resource_id)
		)
	if goods_type == &"special":
		return (
			transaction_type == &"buy"
			and special_goods_manager.is_valid_goods(resource_id)
		)
	return false


func _print_completed_trade(offer: Dictionary) -> void:
	var offer_id: StringName = offer["offer_id"]
	print("Trade completed:")
	print("State: %s" % offer["state_id"])
	print("Offer: %s" % offer_id)
	print("Type: %s" % offer["transaction_type"])
	print("Resource: %s" % offer["resource_id"])
	print("Amount: %d" % int(offer["amount"]))
	print("Gold: %d" % int(offer["gold_price"]))
	print(
		"Uses today: %d/%d"
		% [get_offer_uses_today(offer_id), int(offer["daily_limit"])]
	)


func _print_completed_special_trade(offer: Dictionary) -> void:
	print("Special trade completed:")
	print("State: %s" % offer["state_id"])
	print("Offer: %s" % offer["offer_id"])
	print("Goods: %s" % offer["resource_id"])
	print("Amount: %d" % int(offer["amount"]))
	print("Gold: %d" % int(offer["gold_price"]))


func _is_integer_value(value: Variant) -> bool:
	return (
		value is int
		or (value is float and value == floor(value))
	)
