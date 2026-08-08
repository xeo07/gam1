extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_test_new_session_initialization()
	_test_seed_reproducibility()
	_test_state_data_round_trip()
	_test_state_name_generation()
	_test_world_generation()
	_test_state_personalities()
	_test_world_events()
	_test_state_intelligence()
	_test_state_observation()
	_test_messenger_mission()

	if _failures.is_empty():
		print("KINGDOOM tests passed: 10")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("KINGDOOM tests failed: %d" % _failures.size())
	quit(1)


func _test_new_session_initialization() -> void:
	var session := GameSessionManager.new()
	session.initialize_new_game("  Тестовое королевство  ", 24680, [], [])

	_expect(session.is_initialized(), "New session must be initialized")
	_expect(session.is_new_game, "New session must be marked as new")
	_expect(
		session.get_kingdom_name() == "Тестовое королевство",
		"Kingdom name must be trimmed"
	)
	_expect(session.get_world_seed() == 24680, "World seed must be preserved")
	_expect(
		PixelArtEditor.is_pixel_data_valid(
			session.get_flag_pixels(),
			GameSessionManager.FLAG_SIZE.x,
			GameSessionManager.FLAG_SIZE.y
		),
		"Default flag must be valid"
	)
	_expect(
		PixelArtEditor.is_pixel_data_valid(
			session.get_emblem_pixels(),
			GameSessionManager.EMBLEM_SIZE.x,
			GameSessionManager.EMBLEM_SIZE.y
		),
		"Default emblem must be valid"
	)

	session.free()


func _test_seed_reproducibility() -> void:
	var first_session := GameSessionManager.new()
	var second_session := GameSessionManager.new()
	first_session.initialize_new_game("Первое", 13579, [], [])
	second_session.initialize_new_game("Второе", 13579, [], [])

	_expect(
		first_session.get_flag_pixels() == second_session.get_flag_pixels(),
		"The same seed must generate the same flag"
	)
	_expect(
		first_session.get_emblem_pixels() == second_session.get_emblem_pixels(),
		"The same seed must generate the same emblem"
	)

	var first_sequence: Array[int] = []
	var second_sequence: Array[int] = []
	for _index in 8:
		first_sequence.append(first_session.get_rng().randi())
		second_sequence.append(second_session.get_rng().randi())
	_expect(
		first_sequence == second_sequence,
		"The same seed must produce the same random sequence"
	)

	first_session.free()
	second_session.free()


func _test_state_data_round_trip() -> void:
	var original := StateData.create(
		&"test_state", "Тестовая марка", "Княгиня Ида", 88, 42, 73, 64, -12
	)
	var saved := StateData.to_save_data(original)
	var parsed := StateData.parse_save_data(saved)

	_expect(bool(parsed.get("valid", false)), "Valid state data must load")
	_expect(
		parsed.get("state", {}) == original,
		"Saved state data must round-trip without changes"
	)

	var invalid := saved.duplicate(true)
	invalid["military_strength"] = 101
	_expect(
		not bool(StateData.parse_save_data(invalid).get("valid", false)),
		"Out-of-range state data must be rejected"
	)


func _test_state_name_generation() -> void:
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 97531
	second_rng.seed = 97531
	var first_names := StateNameGenerator.generate_unique_names(first_rng, 7)
	var second_names := StateNameGenerator.generate_unique_names(second_rng, 7)

	_expect(
		StateNameGenerator.ADJECTIVES.size() >= 20,
		"State names need at least 20 adjectives"
	)
	_expect(
		StateNameGenerator.NOUNS.size() >= 20,
		"State names need at least 20 nouns"
	)
	_expect(first_names.size() == 7, "Generator must return seven names")
	_expect(first_names == second_names, "The same seed must generate the same names")

	var unique_names: Dictionary = {}
	for state_name in first_names:
		unique_names[state_name] = true
		_expect(
			state_name.split(" ", false).size() == 2,
			"Each state name must contain an adjective and a noun"
		)
	_expect(unique_names.size() == 7, "Generated state names must be unique")

	_expect(
		StateNameGenerator.compose_name(0, 0) == "Багровый Альянс",
		"Masculine adjective form must match its noun"
	)
	_expect(
		StateNameGenerator.compose_name(0, 9) == "Багровая Держава",
		"Feminine adjective form must match its noun"
	)
	_expect(
		StateNameGenerator.compose_name(0, 17) == "Багровое Владение",
		"Neuter adjective form must match its noun"
	)


func _test_world_generation() -> void:
	var first_world := WorldGenerator.generate_states(424242)
	var second_world := WorldGenerator.generate_states(424242)
	var different_world := WorldGenerator.generate_states(424243)

	_expect(first_world.size() == 7, "A new world must contain seven AI states")
	_expect(first_world == second_world, "The same seed must reproduce the whole world")
	_expect(first_world != different_world, "A different seed should create a different world")

	var ids: Dictionary = {}
	var names: Dictionary = {}
	for state in first_world:
		ids[state["id"]] = true
		names[state["name"]] = true
		var parsed := StateData.parse_save_data(StateData.to_save_data(state))
		_expect(
			bool(parsed.get("valid", false)) and parsed.get("state", {}) == state,
			"Generated state must survive save-data round-trip"
		)
	_expect(ids.size() == 7, "Generated state identifiers must be unique")
	_expect(names.size() == 7, "Generated state names must be unique")
	for expected_id in WorldGenerator.AI_STATE_IDS:
		_expect(ids.has(expected_id), "Generated world must contain %s" % expected_id)


func _test_state_personalities() -> void:
	var world := WorldGenerator.generate_states(8888)
	var personalities: Dictionary = {}
	for state in world:
		var personality: StringName = state["personality"]
		personalities[personality] = true
		_expect(StatePersonality.is_valid(personality), "State personality must be valid")
		_expect(not state["interests"].is_empty(), "State interests must not be empty")
		_expect(state["strategic_goal"] != &"", "State strategic goal must not be empty")
	_expect(personalities.size() == 7, "The initial states must have distinct personalities")

	var merchant_bias := StatePersonality.get_daily_bias(&"merchant")
	var warlike_bias := StatePersonality.get_daily_bias(&"warlike")
	_expect(
		int(merchant_bias["wealth"]) > int(warlike_bias["wealth"]),
		"Merchant states must prioritize wealth more than warlike states"
	)
	_expect(
		int(warlike_bias["military"]) > int(merchant_bias["military"]),
		"Warlike states must prioritize the army more than merchant states"
	)
	_expect(
		int(merchant_bias["relation"]) > int(warlike_bias["relation"]),
		"Personalities must influence diplomatic posture"
	)


func _test_world_events() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123456
	var state := StateData.create(
		&"event_state", "Торговая республика", "Канцлер Ида",
		80, 40, 60, 70, 0, &"neutral", &"merchant"
	)
	var event := WorldEventGenerator.generate_for_state(state, 12, rng)
	var before := state.duplicate(true)
	WorldEventGenerator.apply_event(state, event)

	_expect(not event.is_empty(), "World event must be generated for a valid state")
	_expect(not String(event["cause"]).is_empty(), "World event must explain its cause")
	_expect(not String(event["summary"]).is_empty(), "World event must describe consequences")
	_expect(
		int(state["wealth"]) > int(before["wealth"]),
		"Merchant event must change the state's wealth"
	)
	_expect(
		int(state["relation"]) > int(before["relation"]),
		"Merchant event must also change diplomatic relations"
	)
	var parsed := WorldEventGenerator.parse_save_data(
		WorldEventGenerator.to_save_data(event)
	)
	_expect(bool(parsed.get("valid", false)), "World event must survive save-data round-trip")


func _test_state_intelligence() -> void:
	var rumor := StateIntelligence.create(
		&"known_state", StateIntelligence.LEVEL_RUMORS, 10, &"world_start"
	)
	_expect(
		StateIntelligence.get_effective_level(rumor, 10) == StateIntelligence.LEVEL_RUMORS,
		"Fresh rumors must preserve their knowledge level"
	)
	_expect(
		StateIntelligence.get_effective_level(rumor, 24) == StateIntelligence.LEVEL_UNKNOWN,
		"Old rumors must degrade into unknown information"
	)
	var spy_report := StateIntelligence.improve(
		rumor, StateIntelligence.LEVEL_ESPIONAGE, 24, &"spy"
	)
	_expect(
		StateIntelligence.get_effective_level(spy_report, 24)
			== StateIntelligence.LEVEL_ESPIONAGE,
		"A new spy report must restore high intelligence"
	)
	_expect(
		StateIntelligence.get_effective_level(spy_report, 52)
			== StateIntelligence.LEVEL_RUMORS,
		"Even precise intelligence must become less reliable with age"
	)
	var parsed := StateIntelligence.parse_save_data(
		StateIntelligence.to_save_data(spy_report)
	)
	_expect(bool(parsed.get("valid", false)), "Intelligence must survive save-data round-trip")


func _test_state_observation() -> void:
	var state := StateData.create(
		&"observed", "Северная лига", "Королева Ида", 120, 73, 61, 82, 17
	)
	var rumor := StateIntelligence.create(
		&"observed", StateIntelligence.LEVEL_RUMORS, 5, &"world_start"
	)
	var rumor_view := StateObservation.create_view(state, rumor, 5)
	_expect(rumor_view["population_text"] == "большое", "Rumors must use qualitative population")
	_expect(not String(rumor_view["military_text"]).contains("73"), "Rumors must hide exact military strength")
	_expect(rumor_view["ruler_text"] == "неизвестно", "Rumors must hide the ruler")

	var diplomatic := StateIntelligence.create(
		&"observed", StateIntelligence.LEVEL_DIPLOMATIC, 6, &"messenger"
	)
	var diplomatic_view := StateObservation.create_view(state, diplomatic, 6)
	_expect(String(diplomatic_view["population_text"]).contains("–"), "Diplomatic data must use a range")
	_expect(diplomatic_view["ruler_text"] == "Королева Ида", "Diplomatic data may reveal the ruler")

	var espionage := StateIntelligence.create(
		&"observed", StateIntelligence.LEVEL_ESPIONAGE, 7, &"spy"
	)
	var espionage_view := StateObservation.create_view(state, espionage, 7)
	_expect(
		String(espionage_view["military_text"]) != String(diplomatic_view["military_text"]),
		"Spy range must be narrower than diplomatic range"
	)
	_expect(
		not String(espionage_view["military_text"]).ends_with("73"),
		"Even spy data must not expose a bare exact value"
	)


func _test_messenger_mission() -> void:
	var test_root := Node.new()
	test_root.name = "MessengerTest"
	var session := GameSessionManager.new()
	session.name = "GameSessionManager"
	var time := TimeManager.new()
	time.name = "TimeManager"
	var resources := ResourceManager.new()
	resources.name = "ResourceManager"
	var world := WorldManager.new()
	world.name = "WorldManager"
	var messenger := MessengerManager.new()
	messenger.name = "MessengerManager"
	test_root.add_child(session)
	test_root.add_child(time)
	test_root.add_child(resources)
	test_root.add_child(world)
	test_root.add_child(messenger)
	root.add_child(test_root)
	world.time_manager = time
	world.game_session_manager = session
	messenger.time_manager = time
	messenger.world_manager = world
	messenger.resource_manager = resources
	time.day_changed.connect(messenger._on_day_changed)
	session.initialize_new_game("Тест", 777, [], [])
	resources.initialize_new_game()
	world.initialize_new_game()
	var state_id := WorldGenerator.AI_STATE_IDS[0]
	var initial_gold := resources.gold

	_expect(messenger.start_mission(state_id), "Messenger mission must start")
	_expect(
		resources.gold == initial_gold - MessengerManager.GOLD_COST,
		"Messenger mission must charge its visible gold cost"
	)
	_expect(messenger.has_active_mission(state_id), "Messenger must remain active during travel")
	time.next_day()
	_expect(messenger.has_active_mission(state_id), "Messenger must not return too early")
	time.next_day()
	_expect(not messenger.has_active_mission(state_id), "Messenger must return after two days")
	var knowledge := world.get_intelligence(state_id)
	_expect(
		int(knowledge.get("effective_level", 0)) == StateIntelligence.LEVEL_DIPLOMATIC,
		"Messenger report must grant diplomatic intelligence"
	)
	_expect(
		not messenger.get_latest_report(state_id).is_empty(),
		"Completed messenger mission must create a report"
	)
	test_root.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
