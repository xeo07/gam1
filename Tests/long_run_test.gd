extends SceneTree

const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"
const RUN_DAYS := 60

var _failures: Array[String] = []
var _weekly_editions := 0
var _spy_resolutions := 0
var _messenger_reports := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _write_pending_session():
		_failures.append("Could not prepare long-run session")
		_finish()
		return
	var game := (load("res://Scenes/Main/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _frame in 8:
		await process_frame
	var time := game.get_node("TimeManager") as TimeManager
	var resources := game.get_node("ResourceManager") as ResourceManager
	var events := game.get_node("EventManager") as EventManager
	var world := game.get_node("WorldManager") as WorldManager
	var diplomacy := game.get_node("DiplomacyManager") as DiplomacyManager
	var contracts := game.get_node("ContractManager") as ContractManager
	var messenger := game.get_node("MessengerManager") as MessengerManager
	var spy := game.get_node("SpyManager") as SpyManager
	var news := game.get_node("NewsManager") as NewsManager
	var journal := game.get_node("EventJournalManager") as EventJournalManager
	var save_manager := game.get_node("SaveManager") as SaveManager
	var build_panel := game.get_node("BuildPanel") as BuildPanel
	var kingdom_grid := game.get_node("KingdomGrid") as KingdomGrid
	var tutorial_panel := game.get_node("TutorialPanel") as TutorialPanel
	_expect(
		kingdom_grid.position.y >= 80.0,
		"Kingdom grid still overlaps the top menu button"
	)
	tutorial_panel.open_offer()
	_expect(tutorial_panel.visible and paused, "Tutorial offer did not pause the new game")
	tutorial_panel.skip()
	_expect(not tutorial_panel.visible and not paused, "Tutorial could not be skipped")
	build_panel.open_panel()
	game.call("_on_lumber_camp_selected")
	_expect(not build_panel.visible, "Building selection did not uncover the kingdom grid")
	_expect(
		kingdom_grid.selected_building != null
		and kingdom_grid.selected_building.id == &"lumber_camp",
		"Lumber camp was not selected for placement"
	)
	kingdom_grid.clear_selection()
	news.weekly_edition_ready.connect(func(_edition: Dictionary) -> void: _weekly_editions += 1)
	spy.spy_mission_resolved.connect(func(_state: StringName, _outcome: Dictionary) -> void: _spy_resolutions += 1)
	messenger.report_ready.connect(func(_report: Dictionary) -> void: _messenger_reports += 1)
	resources.add_resource(&"gold", 150)
	var ids := WorldGenerator.AI_STATE_IDS
	messenger.start_mission(ids[0])
	spy.start_spy_mission(ids[1])
	diplomacy.perform_action(&"gift", ids[2])
	world.set_relation(ids[3], 60)
	contracts.propose(&"trade_treaty", ids[3])
	var restored_at_day := 0
	for elapsed in RUN_DAYS:
		if events.has_active_event():
			_resolve_available_event(events)
		if elapsed == 15:
			messenger.start_mission(ids[4])
		if elapsed == 20:
			spy.start_spy_mission(ids[5])
		if elapsed == 25:
			diplomacy.perform_action(&"agreement", ids[6])
		time.next_day()
		for _frame in 2:
			await process_frame
		if elapsed == 29:
			var snapshot := save_manager.build_save_data()
			if save_manager.apply_save_data(snapshot):
				restored_at_day = time.get_absolute_day()
			else:
				_failures.append("Combined save data failed to restore on day 30")
	if events.has_active_event():
		_resolve_available_event(events)
	_expect(time.get_absolute_day() >= RUN_DAYS + 1, "Simulation did not reach 60 completed days")
	_expect(_weekly_editions >= 8, "Weekly newspaper did not publish throughout 60 days")
	_expect(_spy_resolutions >= 2, "Espionage did not complete alongside the simulation")
	_expect(_messenger_reports >= 2, "Messengers did not return alongside the simulation")
	_expect(restored_at_day >= 30, "Mid-run save restoration did not preserve the date")
	_expect(world.get_all_states().size() == 7, "Long run lost generated states")
	_expect(journal.get_entries().size() >= 10, "Long run did not accumulate a meaningful event history")
	_expect(news.has_weekly_edition(), "Latest weekly edition was not retained")
	_finish()


func _resolve_available_event(events: EventManager) -> void:
	var event := events.get_active_event()
	for choice in event.get("choices", []):
		var choice_id := StringName(choice.get("choice_id", &""))
		if events.can_resolve_choice(choice_id):
			events.resolve_choice(choice_id)
			return
	_failures.append("No affordable response for active event %s" % String(event.get("event_id", &"")))


func _write_pending_session() -> bool:
	var file := FileAccess.open(PENDING_NEW_GAME_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"kingdom_name": "Королевство 60 дней", "world_seed": 606060, "flag_pixels": _pixels(16, 10, 6), "emblem_pixels": _pixels(12, 12, 10), "show_tutorial": false}))
	file.flush()
	return file.get_error() == OK


func _pixels(width: int, height: int, color: int) -> Array:
	var result: Array = []
	for _y in height:
		var row: Array = []
		for _x in width:
			row.append(color)
		result.append(row)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("KINGDOOM 60-day integrated run passed")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("KINGDOOM 60-day integrated run failed: %d" % _failures.size())
	quit(1)
