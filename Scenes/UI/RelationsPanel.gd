extends CanvasLayer
class_name RelationsPanel

const STATUS_DISPLAY_NAMES: Dictionary = {
	&"neutral": "Нейтральный",
	&"ally": "Союзник",
	&"enemy": "Враг",
	&"war": "В состоянии войны",
}

@onready var states_list: ItemList = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatesList
@onready var state_name_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/StateNameLabel
@onready var ruler_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/RulerLabel
@onready var relation_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/RelationLabel
@onready var relation_reasons_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/RelationReasonsLabel
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/StatusLabel
@onready var population_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/PopulationLabel
@onready var military_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/MilitaryLabel
@onready var wealth_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/WealthLabel
@onready var stability_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/StabilityLabel
@onready var gift_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/GiftButton
@onready var threat_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/ThreatButton
@onready var agreement_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/AgreementButton
@onready var insult_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/InsultButton
@onready var contracts_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/ContractsLabel
@onready var trade_treaty_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/TradeTreatyButton
@onready var pact_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/PactButton
@onready var military_obligation_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/MilitaryObligationButton
@onready var break_contract_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/BreakContractButton
@onready var action_confirmation: ConfirmationDialog = $ActionConfirmation
@onready var cooldown_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/CooldownLabel
@onready var action_status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/ActionStatusLabel
@onready var send_spy_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/SendSpyButton
@onready var spy_status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/SpyStatusLabel
@onready var send_messenger_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/SendMessengerButton
@onready var messenger_status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailsPanel/VBoxContainer/MessengerStatusLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager
@onready var diplomacy_manager: DiplomacyManager = $"../DiplomacyManager" as DiplomacyManager
@onready var contract_manager: ContractManager = $"../ContractManager" as ContractManager
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var messenger_manager: MessengerManager = $"../MessengerManager" as MessengerManager
@onready var resource_manager: ResourceManager = $"../ResourceManager" as ResourceManager
@onready var time_manager: TimeManager = $"../TimeManager" as TimeManager

var _state_ids: Array[StringName] = []
var _selected_state_id: StringName = &""
var _pending_action_id: StringName = &""
var _pending_contract_id: StringName = &""
var _availability_label: Label
var _state_context_messages: Dictionary = {}


func _ready() -> void:
	_build_geopolitics_layout()
	states_list.item_selected.connect(_on_state_selected)
	gift_button.pressed.connect(_request_action.bind(&"gift"))
	threat_button.pressed.connect(_request_action.bind(&"threat"))
	agreement_button.pressed.connect(_request_action.bind(&"agreement"))
	insult_button.pressed.connect(_request_action.bind(&"insult"))
	action_confirmation.confirmed.connect(_on_action_confirmed)
	trade_treaty_button.pressed.connect(_request_contract.bind(&"trade_treaty"))
	pact_button.pressed.connect(_request_contract.bind(&"non_aggression"))
	military_obligation_button.pressed.connect(_request_contract.bind(&"military_obligation"))
	break_contract_button.pressed.connect(_request_break_contract)
	contract_manager.contract_signed.connect(_on_contract_changed)
	contract_manager.contract_ended.connect(_on_contract_changed)
	contract_manager.contract_failed.connect(_on_contract_failed)
	send_spy_button.pressed.connect(_on_send_spy_pressed)
	send_messenger_button.pressed.connect(_on_send_messenger_pressed)
	close_button.pressed.connect(close_panel)
	world_manager.states_changed.connect(_on_states_changed)
	diplomacy_manager.diplomatic_action_completed.connect(_on_diplomatic_action_completed)
	diplomacy_manager.diplomatic_action_failed.connect(_on_diplomatic_action_failed)
	spy_manager.spy_mission_started.connect(_on_spy_mission_started)
	spy_manager.spy_mission_failed.connect(_on_spy_mission_failed)
	spy_manager.spy_report_ready.connect(_on_spy_report_ready)
	messenger_manager.mission_started.connect(_on_messenger_started)
	messenger_manager.mission_failed.connect(_on_messenger_failed)
	messenger_manager.report_ready.connect(_on_messenger_report_ready)
	resource_manager.resources_changed.connect(_on_resources_changed)
	time_manager.day_changed.connect(_on_day_changed)
	time_manager.time_loaded.connect(_on_day_changed)
	_clear_details()


func _build_geopolitics_layout() -> void:
	var main_vbox := states_list.get_parent() as VBoxContainer
	var details_panel := state_name_label.get_parent().get_parent() as PanelContainer
	var split := SplitContainer.new()
	split.vertical = false
	split.name = "MainSplit"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split)
	main_vbox.move_child(split, 1)
	states_list.reparent(split, false)
	states_list.custom_minimum_size = Vector2(260, 180)
	states_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details_scroll := ScrollContainer.new()
	details_scroll.name = "DetailsScroll"
	details_scroll.custom_minimum_size = Vector2(500, 180)
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(details_scroll)
	details_panel.reparent(details_scroll, false)
	details_panel.custom_minimum_size = Vector2(500, 0)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_availability_label = Label.new()
	_availability_label.name = "AvailabilityLabel"
	_availability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var details_vbox := state_name_label.get_parent() as VBoxContainer
	details_vbox.add_child(_availability_label)
	details_vbox.move_child(_availability_label, cooldown_label.get_index())


func open_panel() -> void:
	visible = true
	action_status_label.text = ""
	spy_status_label.text = ""
	refresh_states()


func close_panel() -> void:
	visible = false


func refresh_states() -> void:
	var states := world_manager.get_all_observed_states()
	states_list.clear()
	_state_ids.clear()

	if states.is_empty():
		states_list.add_item("Государств нет")
		states_list.set_item_disabled(0, true)
		_selected_state_id = &""
		_clear_details()
		return

	for state in states:
		var state_id: StringName = state.get("id", &"")
		_state_ids.append(state_id)
		states_list.add_item(_format_state_list_item(state))

	var selected_index := _state_ids.find(_selected_state_id)
	if selected_index == -1:
		selected_index = 0
		_selected_state_id = _state_ids[0]

	states_list.select(selected_index)
	_show_state(_selected_state_id)


func _on_state_selected(index: int) -> void:
	if index < 0 or index >= _state_ids.size():
		return

	_selected_state_id = _state_ids[index]
	action_status_label.text = String(_state_context_messages.get(_selected_state_id, ""))
	spy_status_label.text = ""
	_show_state(_selected_state_id)


func _on_states_changed() -> void:
	if visible:
		refresh_states()


func _request_action(action_id: StringName) -> void:
	if _selected_state_id == &"":
		return
	var preview := diplomacy_manager.get_action_preview(action_id, _selected_state_id)
	if preview.is_empty():
		return
	_pending_action_id = action_id
	var lines: Array[String] = [String(preview["context"]), "", "Цена: %d золота" % int(preview["cost"]), "Вероятный итог: %s" % String(preview["forecast"])]
	var third: Dictionary = preview.get("third_party", {})
	if not third.is_empty():
		lines.append("Третья сторона: %s — %s" % [String(third["state_name"]), String(third["forecast"])])
	action_confirmation.title = String(preview["label"])
	action_confirmation.dialog_text = "\n".join(PackedStringArray(lines))
	action_confirmation.popup_centered(Vector2i(500, 260))


func _on_action_confirmed() -> void:
	if _pending_contract_id != &"" and _selected_state_id != &"":
		contract_manager.propose(_pending_contract_id, _selected_state_id)
	elif _pending_action_id != &"" and _selected_state_id != &"":
		diplomacy_manager.perform_action(_pending_action_id, _selected_state_id)
	_pending_action_id = &""
	_pending_contract_id = &""


func _request_contract(contract_id: StringName) -> void:
	var preview := contract_manager.get_preview(contract_id, _selected_state_id)
	if preview.is_empty():
		return
	_pending_action_id = &""
	_pending_contract_id = contract_id
	action_confirmation.title = String(preview["name"])
	action_confirmation.dialog_text = "%s\n\nСрок: %d дней\nЦена: %d золота\nУсловие: %s\nВыгода: %s\nНарушение: %s\n\nВероятная реакция: %s" % [String(preview["name"]), int(preview["duration"]), int(preview["cost"]), String(preview["condition"]), String(preview["benefit"]), String(preview["breach"]), String(preview["reaction"])]
	action_confirmation.popup_centered(Vector2i(560, 340))


func _request_break_contract() -> void:
	contract_manager.break_contract(_selected_state_id)


func _on_contract_changed(contract: Dictionary, message: String) -> void:
	if contract.get("state_id", &"") == _selected_state_id:
		action_status_label.text = message
		_state_context_messages[_selected_state_id] = message
		_update_contract_controls()


func _on_contract_failed(state_id: StringName, reason: String) -> void:
	if state_id == _selected_state_id:
		action_status_label.text = reason
		_state_context_messages[state_id] = reason


func _on_send_spy_pressed() -> void:
	if _selected_state_id == &"":
		return
	spy_manager.start_spy_mission(_selected_state_id)


func _on_send_messenger_pressed() -> void:
	if _selected_state_id != &"":
		messenger_manager.start_mission(_selected_state_id)


func _on_messenger_started(state_id: StringName, _completion_day: int) -> void:
	if visible and state_id == _selected_state_id:
		_update_messenger_controls()


func _on_messenger_failed(state_id: StringName, reason: String) -> void:
	if visible and state_id == _selected_state_id:
		messenger_status_label.text = reason
		_update_messenger_button()


func _on_messenger_report_ready(report: Dictionary) -> void:
	if visible and report.get("state_id", &"") == _selected_state_id:
		messenger_status_label.text = String(report.get("summary", "Гонец вернулся"))
		_show_state(_selected_state_id)


func _on_diplomatic_action_completed(
	state_id: StringName,
	_action_id: StringName,
	_relation_change: int,
	message: String
) -> void:
	if not visible:
		return

	refresh_states()
	if state_id == _selected_state_id:
		action_status_label.text = message
		_state_context_messages[state_id] = message
		_show_state(state_id)


func _on_diplomatic_action_failed(
	state_id: StringName,
	_action_id: StringName,
	reason: String
) -> void:
	if visible and state_id == _selected_state_id:
		action_status_label.text = reason
		_state_context_messages[state_id] = reason
		_update_action_controls()


func _on_resources_changed(
	_food: int,
	_wood: int,
	_stone: int,
	_gold: int
) -> void:
	if visible:
		_update_action_controls()
		_update_spy_controls()
		_update_messenger_controls()


func _on_day_changed(_day: int, _month: int, _year: int) -> void:
	if visible:
		_update_action_controls()
		_update_spy_controls()
		_update_messenger_controls()


func _show_state(state_id: StringName) -> void:
	var state := world_manager.get_observed_state_by_id(state_id)
	if state.is_empty():
		_selected_state_id = &""
		_clear_details()
		return

	state_name_label.text = "Государство: %s" % String(state.get("name", ""))
	ruler_label.text = "Правитель: %s" % String(state.get("ruler_text", "неизвестно"))
	var relation_summary := diplomacy_manager.get_relation_summary(state_id)
	relation_label.text = "Отношения: %s" % String(
		relation_summary.get("label", state.get("relation_text", "неизвестно"))
	)
	var reasons: Array = relation_summary.get("reasons", [])
	var reason_lines: Array[String] = []
	for reason in reasons:
		reason_lines.append("• %s" % String(reason))
	relation_reasons_label.text = (
		"Почему так:\n%s" % "\n".join(PackedStringArray(reason_lines))
		if not reason_lines.is_empty()
		else "Почему так: сведений недостаточно"
	)
	status_label.text = "Статус: %s" % String(state.get("status_text", "неизвестно"))
	population_label.text = "Население: %s" % String(state.get("population_text", "неизвестно"))
	military_label.text = "Военная сила: %s" % String(state.get("military_text", "неизвестно"))
	wealth_label.text = "Богатство: %s" % String(state.get("wealth_text", "неизвестно"))
	stability_label.text = "Стабильность: %s\nИсточник: %s, %s" % [
		String(state.get("stability_text", "неизвестно")),
		String(state.get("source_text", "неизвестно")),
		String(state.get("freshness_text", "")),
	]
	_update_action_controls()
	_update_contract_controls()
	_update_spy_controls()
	_update_messenger_controls()


func _on_spy_mission_started(
	state_id: StringName,
	_completion_day: int
) -> void:
	if visible and state_id == _selected_state_id:
		spy_status_label.text = (
			"Шпион отправлен. Отчёт будет через %d дня."
			% SpyManager.SPY_MISSION_DURATION_DAYS
		)
		_update_spy_button()


func _on_spy_mission_failed(state_id: StringName, reason: String) -> void:
	if visible and state_id == _selected_state_id:
		spy_status_label.text = reason
		_update_spy_button()


func _on_spy_report_ready(report: Dictionary) -> void:
	if not visible:
		return
	var state_id: StringName = report.get("state_id", &"")
	if state_id == _selected_state_id:
		_update_spy_controls()


func _format_state_list_item(state: Dictionary) -> String:
	return "%s — %s" % [String(state.get("name", "")), String(state.get("relation_text", "неизвестно"))]


func _get_status_display_name(status: StringName) -> String:
	return String(STATUS_DISPLAY_NAMES.get(status, String(status)))


func _update_action_controls() -> void:
	if _selected_state_id == &"":
		gift_button.disabled = true
		threat_button.disabled = true
		agreement_button.disabled = true
		insult_button.disabled = true
		cooldown_label.text = ""
		_availability_label.text = ""
		return

	var cooldown_remaining := diplomacy_manager.get_action_cooldown_remaining(
		_selected_state_id
	)
	if cooldown_remaining > 0:
		cooldown_label.text = "Посланник вернётся через %d дн." % cooldown_remaining
		_availability_label.text = "Почему действия недоступны: посланник ещё в пути."
	else:
		cooldown_label.text = "Посланник доступен"
		_availability_label.text = ""

	for action_data in [[gift_button, &"gift"], [threat_button, &"threat"], [agreement_button, &"agreement"], [insult_button, &"insult"]]:
		var button: Button = action_data[0]
		var preview := diplomacy_manager.get_action_preview(action_data[1], _selected_state_id)
		button.disabled = cooldown_remaining > 0 or not resource_manager.has_resource(&"gold", int(preview.get("cost", 0)))
		var cost := int(preview.get("cost", 0))
		button.tooltip_text = (
			"Недоступно: нужно %d золота." % cost
			if not resource_manager.has_resource(&"gold", cost)
			else ("Недоступно: посланник ещё в пути." if cooldown_remaining > 0 else "%s Цена: %d золота." % [String(preview.get("forecast", "")), cost])
		)


func _update_contract_controls() -> void:
	var buttons: Array[Button] = [trade_treaty_button, pact_button, military_obligation_button]
	if _selected_state_id == &"":
		contracts_label.text = ""
		for button in buttons:
			button.disabled = true
		break_contract_button.disabled = true
		return
	var active := contract_manager.get_active_contract(_selected_state_id)
	if not active.is_empty():
		contracts_label.text = "Действует: %s · до дня %d\nУсловие: %s" % [String(active["name"]), int(active["end_day"]), String(active["condition"])]
		for button in buttons:
			button.disabled = true
			button.tooltip_text = "Недоступно: с государством уже действует договор."
		break_contract_button.disabled = false
		return
	contracts_label.text = "Действующих договоров нет"
	break_contract_button.disabled = true
	for pair in [[trade_treaty_button, &"trade_treaty"], [pact_button, &"non_aggression"], [military_obligation_button, &"military_obligation"]]:
		var preview := contract_manager.get_preview(pair[1], _selected_state_id)
		var button: Button = pair[0]
		button.disabled = not resource_manager.has_resource(&"gold", int(preview.get("cost", 0)))
		button.tooltip_text = (
			"Недоступно: нужно %d золота." % int(preview.get("cost", 0))
			if button.disabled
			else String(preview.get("reaction", ""))
		)


func _update_spy_controls() -> void:
	if _selected_state_id == &"":
		spy_status_label.text = ""
		send_spy_button.disabled = true
		return

	if spy_manager.has_active_mission(_selected_state_id):
		spy_status_label.text = "Шпион вернётся через %d дн." % (
			spy_manager.get_mission_days_remaining(_selected_state_id)
		)
	else:
		var latest_report := spy_manager.get_latest_report(_selected_state_id)
		if latest_report.is_empty():
			spy_status_label.text = "3 дня · %s" % SpyMissionOutcome.risk_text()
		else:
			spy_status_label.text = (
				"Последний отчёт получен: День %d, Месяц %d, Год %d"
				% [
					latest_report.get("report_day", 0),
					latest_report.get("report_month", 0),
					latest_report.get("report_year", 0),
				]
			)

	_update_spy_button()


func _update_spy_button() -> void:
	send_spy_button.disabled = (
		_selected_state_id == &""
		or spy_manager.has_active_mission(_selected_state_id)
		or not resource_manager.has_resource(
			&"gold",
			SpyManager.SPY_GOLD_COST
		)
	)
	send_spy_button.tooltip_text = (
		"Недоступно: шпион уже выполняет миссию."
		if _selected_state_id != &"" and spy_manager.has_active_mission(_selected_state_id)
		else ("Недоступно: нужно %d золота." % SpyManager.SPY_GOLD_COST if not resource_manager.has_resource(&"gold", SpyManager.SPY_GOLD_COST) else "3 дня. Успех 65%, провал 20%, разоблачение 15%.")
	)


func _update_messenger_controls() -> void:
	if _selected_state_id == &"":
		messenger_status_label.text = ""
		send_messenger_button.disabled = true
		return
	if messenger_manager.has_active_mission(_selected_state_id):
		messenger_status_label.text = "Гонец вернётся через %d дн. · низкий риск" % (
			messenger_manager.get_days_remaining(_selected_state_id)
		)
	else:
		var latest := messenger_manager.get_latest_report(_selected_state_id)
		messenger_status_label.text = (
			MessengerManager.BENEFIT_TEXT
			if latest.is_empty()
			else String(latest.get("summary", MessengerManager.BENEFIT_TEXT))
		)
	_update_messenger_button()


func _update_messenger_button() -> void:
	send_messenger_button.disabled = (
		_selected_state_id == &""
		or messenger_manager.has_active_mission(_selected_state_id)
		or not resource_manager.has_resource(&"gold", MessengerManager.GOLD_COST)
	)
	send_messenger_button.tooltip_text = (
		"Недоступно: гонец уже в пути."
		if _selected_state_id != &"" and messenger_manager.has_active_mission(_selected_state_id)
		else ("Недоступно: нужно %d золота." % MessengerManager.GOLD_COST if not resource_manager.has_resource(&"gold", MessengerManager.GOLD_COST) else MessengerManager.BENEFIT_TEXT)
	)


func _clear_details() -> void:
	state_name_label.text = ""
	ruler_label.text = ""
	relation_label.text = ""
	relation_reasons_label.text = ""
	status_label.text = ""
	population_label.text = ""
	military_label.text = ""
	wealth_label.text = ""
	stability_label.text = ""
	cooldown_label.text = ""
	action_status_label.text = ""
	if _availability_label != null:
		_availability_label.text = ""
	spy_status_label.text = ""
	messenger_status_label.text = ""
	contracts_label.text = ""
	gift_button.disabled = true
	threat_button.disabled = true
	agreement_button.disabled = true
	insult_button.disabled = true
	trade_treaty_button.disabled = true
	pact_button.disabled = true
	military_obligation_button.disabled = true
	break_contract_button.disabled = true
	send_spy_button.disabled = true
	send_messenger_button.disabled = true
