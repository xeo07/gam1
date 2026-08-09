extends CanvasLayer
class_name TradePanel

const RESOURCE_RESULT_NAMES: Dictionary = {
	&"food": "еды",
	&"wood": "дерева",
	&"stone": "камня",
}
const SPECIAL_RESULT_NAMES: Dictionary = {
	&"northern_bows": "северных луков",
	&"suncoast_cattle": "головы породистого скота",
	&"iron_weapons": "комплектов железного оружия",
}

@onready var root_vbox: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/RootVBox
@onready var partner_vbox: VBoxContainer = root_vbox.get_node("PartnerCard/PartnerMargin/PartnerVBox") as VBoxContainer
@onready var state_option_button: OptionButton = partner_vbox.get_node("StateOptionButton") as OptionButton
@onready var relation_label: Label = partner_vbox.get_node("PartnerFacts/RelationLabel") as Label
@onready var state_wealth_label: Label = partner_vbox.get_node("PartnerFacts/StateWealthLabel") as Label
@onready var block_reason_label: Label = partner_vbox.get_node("BlockReasonLabel") as Label
@onready var offers_list: VBoxContainer = root_vbox.get_node("OffersScrollContainer/OffersList") as VBoxContainer
@onready var status_label: Label = root_vbox.get_node("StatusLabel") as Label
@onready var close_button: Button = root_vbox.get_node("CloseButton") as Button
@onready var trade_manager: TradeManager = $"../TradeManager" as TradeManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var diplomacy_manager: DiplomacyManager = $"../DiplomacyManager" as DiplomacyManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var _state_ids: Array[StringName] = []
var _selected_state_id: StringName = &""
var _is_executing_trade := false


func _ready() -> void:
	state_option_button.item_selected.connect(_on_state_selected)
	close_button.pressed.connect(close_panel)
	trade_manager.trade_completed.connect(_on_trade_completed)
	trade_manager.trade_failed.connect(_on_trade_failed)
	trade_manager.trade_state_changed.connect(_on_trade_state_changed)
	world_manager.states_changed.connect(_on_world_state_changed)
	resource_manager.resources_changed.connect(_on_resources_changed)
	time_manager.day_changed.connect(_on_time_changed)
	time_manager.time_loaded.connect(_on_time_changed)


func open_panel() -> void:
	visible = true
	status_label.text = ""
	_populate_states()


func close_panel() -> void:
	visible = false


func _populate_states() -> void:
	var states := world_manager.get_all_observed_states()
	state_option_button.clear()
	_state_ids.clear()

	for state in states:
		var state_id: StringName = state.get("id", &"")
		_state_ids.append(state_id)
		state_option_button.add_item(String(state.get("name", "")))

	if _state_ids.is_empty():
		state_option_button.add_item("Государств нет")
		state_option_button.set_item_disabled(0, true)
		_selected_state_id = &""
		_clear_state_details()
		return

	var selected_index := _state_ids.find(_selected_state_id)
	if selected_index == -1:
		selected_index = 0
		_selected_state_id = _state_ids[0]
	state_option_button.select(selected_index)
	_refresh_selected_state()


func _on_state_selected(index: int) -> void:
	if index < 0 or index >= _state_ids.size():
		return
	_selected_state_id = _state_ids[index]
	status_label.text = ""
	_refresh_selected_state()


func _refresh_selected_state() -> void:
	if _selected_state_id == &"":
		_clear_state_details()
		return

	var state := world_manager.get_observed_state_by_id(_selected_state_id)
	if state.is_empty():
		_populate_states()
		return

	relation_label.text = "Отношения: %s" % String(state.get("relation_text", "неизвестно"))
	state_wealth_label.text = "Богатство: %s · Сведения: %s, %s" % [
		String(state.get("wealth_text", "неизвестно")),
		String(state.get("source_text", "неизвестно")),
		String(state.get("freshness_text", "")),
	]
	var block_reason := trade_manager.get_trade_block_reason(_selected_state_id)
	block_reason_label.text = (
		"Торговля доступна" if block_reason.is_empty() else block_reason
	)
	_rebuild_offers()


func _rebuild_offers() -> void:
	_clear_offers()
	for offer in trade_manager.get_offers_for_state(_selected_state_id):
		_add_offer_control(offer)


func _add_offer_control(offer: Dictionary) -> void:
	var offer_id: StringName = offer.get("offer_id", &"")
	var offer_panel := PanelContainer.new()
	var margin := MarginContainer.new()
	var content := HBoxContainer.new()
	var details := VBoxContainer.new()
	var offer_name_label := Label.new()
	var requirement_label := Label.new()
	var limit_label := Label.new()
	var execute_button := Button.new()

	offer_panel.custom_minimum_size = Vector2(0, 82)
	offer_panel.theme_type_variation = &"HUDIdentityPanel"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	content.add_theme_constant_override("separation", 12)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	offer_name_label.add_theme_color_override(
		"font_color", Color(0.94, 0.76, 0.36)
	)
	offer_name_label.add_theme_font_size_override("font_size", 16)
	requirement_label.add_theme_font_size_override("font_size", 13)
	limit_label.add_theme_font_size_override("font_size", 13)
	execute_button.custom_minimum_size = Vector2(120, 44)
	execute_button.add_theme_font_size_override("font_size", 15)

	offer_name_label.text = String(offer.get("display_name", ""))
	var minimum_relation := int(offer.get("minimum_relation", -100))
	requirement_label.text = (
		"Доступно при любых отношениях"
		if minimum_relation <= -100
		else "Требуются отношения: %d" % minimum_relation
	)
	limit_label.text = "Осталось сделок сегодня: %d/%d" % [
		trade_manager.get_offer_uses_remaining(offer_id),
		int(offer.get("daily_limit", 0)),
	]
	var transaction_type: StringName = offer.get("transaction_type", &"")
	execute_button.text = "Купить" if transaction_type == &"buy" else "Продать"
	execute_button.disabled = not trade_manager.can_execute_offer(offer_id)
	if execute_button.disabled:
		execute_button.tooltip_text = trade_manager.get_offer_failure_reason(offer_id)
	execute_button.pressed.connect(_on_execute_offer.bind(offer_id))

	offers_list.add_child(offer_panel)
	offer_panel.add_child(margin)
	margin.add_child(content)
	content.add_child(details)
	details.add_child(offer_name_label)
	details.add_child(requirement_label)
	details.add_child(limit_label)
	content.add_child(execute_button)


func _on_execute_offer(offer_id: StringName) -> void:
	_is_executing_trade = true
	trade_manager.execute_offer(offer_id)
	_is_executing_trade = false
	if visible:
		_refresh_selected_state()


func _on_trade_completed(
	state_id: StringName,
	_offer_id: StringName,
	transaction_type: StringName,
	resource_id: StringName,
	resource_amount: int,
	gold_amount: int
) -> void:
	if not visible or state_id != _selected_state_id:
		return
	var offer := trade_manager.get_offer_by_id(_offer_id)
	var goods_type: StringName = offer.get("goods_type", &"resource")
	var resource_name := String(RESOURCE_RESULT_NAMES.get(resource_id, String(resource_id)))
	if goods_type == &"special":
		resource_name = String(SPECIAL_RESULT_NAMES.get(resource_id, String(resource_id)))
	if transaction_type == &"buy":
		status_label.text = (
			"Сделка завершена: получено %d %s за %d золота"
			% [resource_amount, resource_name, gold_amount]
		)
	else:
		status_label.text = (
			"Сделка завершена: продано %d %s за %d золота"
			% [resource_amount, resource_name, gold_amount]
		)
	if not _is_executing_trade:
		_refresh_selected_state()


func _on_trade_failed(
	state_id: StringName,
	_offer_id: StringName,
	reason: String
) -> void:
	if visible and (state_id == &"" or state_id == _selected_state_id):
		status_label.text = reason
		if not _is_executing_trade:
			_refresh_selected_state()


func _on_trade_state_changed() -> void:
	if visible and not _is_executing_trade:
		_refresh_selected_state()


func _on_world_state_changed() -> void:
	if visible and not _is_executing_trade:
		_refresh_selected_state()


func _on_resources_changed(
	_food: int,
	_wood: int,
	_stone: int,
	_gold: int
) -> void:
	if visible and not _is_executing_trade:
		_rebuild_offers()


func _on_time_changed(_day: int, _month: int, _year: int) -> void:
	if visible:
		_refresh_selected_state()


func _clear_offers() -> void:
	for child in offers_list.get_children():
		offers_list.remove_child(child)
		child.queue_free()


func _clear_state_details() -> void:
	relation_label.text = ""
	state_wealth_label.text = ""
	block_reason_label.text = ""
	_clear_offers()
