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
	_test_spy_outcomes()
	_test_event_journal_entry()
	_test_weekly_newspaper()
	_test_story_chains()
	_test_relation_profiles()

	if _failures.is_empty():
		print("KINGDOOM tests passed: 15")
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


func _test_spy_outcomes() -> void:
	var exposed := SpyMissionOutcome.resolve(0.0)
	var failed := SpyMissionOutcome.resolve(0.20)
	var success := SpyMissionOutcome.resolve(0.80)
	_expect(exposed["id"] == &"exposed", "Low spy roll must expose the spy")
	_expect(
		int(exposed["relation_change"]) == SpyMissionOutcome.EXPOSURE_RELATION_CHANGE,
		"Exposure must have a diplomatic consequence"
	)
	_expect(failed["id"] == &"failed", "Middle-low spy roll must fail without exposure")
	_expect(int(failed["relation_change"]) == 0, "Undetected failure must not change relations")
	_expect(success["id"] == &"success", "High spy roll must succeed")
	_expect(bool(success["success"]), "Successful spy outcome must grant intelligence")
	_expect(
		is_equal_approx(
			SpyMissionOutcome.SUCCESS_CHANCE
				+ SpyMissionOutcome.UNDETECTED_FAILURE_CHANCE
				+ SpyMissionOutcome.EXPOSURE_CHANCE,
			1.0
		),
		"Spy outcome probabilities must add up to one"
	)


func _test_event_journal_entry() -> void:
	var entry := EventJournalEntry.create(
		"test:12:1", 12, &"foreign_affairs", "Пограничный кризис",
		"Соседнее государство укрепило границу.", [&"state_04"], &"reported",
		{"military_strength": 3, "wealth": -2}, 2
	)
	var parsed := EventJournalEntry.parse_save_data(EventJournalEntry.to_save_data(entry))
	_expect(bool(parsed.get("valid", false)), "Journal entry must survive save-data round-trip")
	_expect(parsed.get("entry", {}) == entry, "Journal round-trip must preserve all fields")
	var invalid := EventJournalEntry.to_save_data(entry)
	invalid["reliability"] = "absolute_truth"
	_expect(
		not bool(EventJournalEntry.parse_save_data(invalid).get("valid", false)),
		"Journal must reject unsupported reliability"
	)


func _test_weekly_newspaper() -> void:
	var minor := EventJournalEntry.create(
		"minor:3", 3, &"diplomacy", "Обычный визит",
		"Гонец доставил привычные приветствия.", [&"state_04"], &"confirmed", {}, 1
	)
	var important := EventJournalEntry.create(
		"war:6", 6, &"war", "Войска выступили к границе",
		"После долгих споров соседний двор начал собирать полки.",
		[&"state_05"], &"reported", {"military_strength": 4}, 3
	)
	var edition := NewspaperEdition.create(1, 7, [minor, important])
	var articles: Array = edition["articles"]
	_expect(edition["first_day"] == 1 and edition["last_day"] == 7, "First edition must cover seven days")
	_expect(articles.size() == 1, "Newspaper must omit routine low-importance entries")
	_expect(articles[0]["source_id"] == "war:6", "Most important story must lead the edition")
	_expect(not articles[0].has("consequences"), "Newspaper must not expose internal consequence data")
	var parsed := NewspaperEdition.parse_save_data(NewspaperEdition.to_save_data(edition))
	_expect(bool(parsed.get("valid", false)), "Newspaper edition must survive save-data round-trip")

	var quiet := NewspaperEdition.create(2, 14, [])
	var quiet_articles: Array = quiet["articles"]
	_expect(quiet_articles.size() == 1, "Quiet week must still create one readable article")
	_expect(
		String(quiet_articles[0]["body"]).contains("не принесли"),
		"Quiet-week article must contain narrative text"
	)

	var journal := EventJournalManager.new()
	var news := NewsManager.new()
	news.event_journal_manager = journal
	var emitted: Array[Dictionary] = []
	news.weekly_edition_ready.connect(func(value: Dictionary) -> void: emitted.append(value))
	news._on_world_day_processed(6, [])
	news._on_world_day_processed(7, [])
	news._on_world_day_processed(7, [])
	news._on_world_day_processed(14, [])
	_expect(emitted.size() == 2, "Newspaper must emit exactly once on each seventh day")
	_expect(emitted[0]["issue_number"] == 1, "Day seven must create the first issue")
	_expect(emitted[1]["issue_number"] == 2, "Day fourteen must create the second issue")
	var restored_news := NewsManager.new()
	_expect(restored_news.load_save_data(news.get_save_data()), "Newspaper state must load from save data")
	_expect(
		restored_news.get_latest_weekly_edition() == emitted[1],
		"Loaded save must preserve the latest newspaper issue"
	)
	restored_news.free()
	news.free()
	journal.free()


func _test_story_chains() -> void:
	var first_order := StoryChainDefinition.build_order(24680)
	var second_order := StoryChainDefinition.build_order(24680)
	_expect(first_order == second_order, "Fixed seed must reproduce story-chain order")
	_expect(first_order.size() == 3, "There must be three story chains")
	var unique: Dictionary = {}
	for chain_id in first_order:
		unique[chain_id] = true
		var warning := StoryChainDefinition.get_warning(chain_id)
		var choices: Array = warning.get("choices", [])
		_expect(choices.size() == 3, "Each story warning must offer three decisions")
		var first_choice: StringName = choices[0]["choice_id"]
		var second_choice: StringName = choices[1]["choice_id"]
		_expect(
			StoryChainDefinition.get_development(chain_id, first_choice)
				!= StoryChainDefinition.get_development(chain_id, second_choice),
			"Player choice must change story development"
		)
		_expect(
			StoryChainDefinition.get_consequence(chain_id, first_choice)
				!= StoryChainDefinition.get_consequence(chain_id, second_choice),
			"Player choice must change story consequence"
		)
	_expect(unique.size() == 3, "Initial story cycle must contain three distinct chains")

	var session := GameSessionManager.new()
	var time := TimeManager.new()
	var resources := ResourceManager.new()
	var population := PopulationManager.new()
	var stability := StabilityManager.new()
	var events := EventManager.new()
	var journal := EventJournalManager.new()
	var stories := StoryChainManager.new()
	session.initialize_new_game("Цепочки", 24680, [], [])
	resources.initialize_new_game()
	stability.time_manager = time
	stability.initialize_new_game()
	events.time_manager = time
	events.resource_manager = resources
	events.population_manager = population
	events.stability_manager = stability
	stories.game_session_manager = session
	stories.time_manager = time
	stories.event_manager = events
	stories.resource_manager = resources
	stories.stability_manager = stability
	stories.event_journal_manager = journal
	events.internal_event_resolved.connect(stories._on_internal_event_resolved)
	stories.initialize_new_game()
	time.day = StoryChainManager.FIRST_CHAIN_DAY
	stories._on_day_changed(time.day, time.month, time.year)
	_expect(events.has_active_event(), "Story warning must become a player decision")
	var active := events.get_active_event()
	var selected_choice: StringName = active["choices"][0]["choice_id"]
	_expect(events.resolve_choice(selected_choice), "Story decision must resolve through the event UI model")
	_expect(stories.get_selected_choice() == selected_choice, "Story chain must remember player choice")
	var saved_story := stories.get_save_data()
	var restored_story := StoryChainManager.new()
	restored_story.game_session_manager = session
	restored_story.time_manager = time
	_expect(restored_story.load_save_data(saved_story), "Active story chain must survive save data")
	_expect(restored_story.get_selected_choice() == selected_choice, "Save must preserve story branch")
	restored_story.free()

	time.day += StoryChainManager.DEVELOPMENT_DELAY_DAYS
	stories._on_day_changed(time.day, time.month, time.year)
	_expect(stories.get_phase() == &"waiting_consequence", "Story must reach development stage")
	time.day += StoryChainManager.CONSEQUENCE_DELAY_DAYS
	stories._on_day_changed(time.day, time.month, time.year)
	_expect(stories.get_phase() == &"idle", "Story must finish with a consequence")
	var story_entries := journal.get_entries()
	_expect(story_entries.size() == 4, "Warning, decision, development and consequence must reach journal")
	_expect(
		String(story_entries[-1]["consequences"].get("stage", "")) == "consequence",
		"Final story entry must be marked as a consequence for future news"
	)
	var followup_edition := NewspaperEdition.create(2, 14, story_entries)
	_expect(
		String(followup_edition["headline"]) == String(story_entries[-1]["title"]),
		"Story consequence must become a headline in a future newspaper"
	)
	stories.free()
	journal.free()
	events.free()
	stability.free()
	population.free()
	resources.free()
	time.free()
	session.free()


func _test_relation_profiles() -> void:
	var legacy := RelationProfile.create_from_legacy(32)
	_expect(RelationProfile.get_score(legacy, 1) == 32, "Legacy relation must keep its old score")
	var remembered := RelationProfile.add_memory(
		legacy, "gift:10", 10, "корона прислала щедрый подарок", 18, 0, 12, 20
	)
	var fresh_score := RelationProfile.get_score(remembered, 10)
	var fading_score := RelationProfile.get_score(remembered, 25)
	_expect(fresh_score > fading_score, "Remembered action must gradually lose weight")
	_expect(RelationProfile.get_score(remembered, 30) == 32, "Expired memory must stop affecting relation")
	_expect(
		"Помнят: корона прислала щедрый подарок" in RelationProfile.get_reason_lines(remembered, 10),
		"Visible reasons must explain remembered actions without exposing a formula"
	)
	var parsed_profile := RelationProfile.parse_save_data(RelationProfile.to_save_data(remembered))
	_expect(bool(parsed_profile.get("valid", false)), "Relation memory must survive save-data round-trip")

	var legacy_state := StateData.to_save_data(StateData.create(
		&"legacy_relation", "Старая держава", "Князь", 80, 50, 50, 50, -20
	))
	legacy_state.erase("relation_profile")
	var migrated_state := StateData.parse_save_data(legacy_state)
	_expect(bool(migrated_state.get("valid", false)), "Old state save without relation profile must migrate")
	_expect(
		RelationProfile.get_score(migrated_state["state"]["relation_profile"], 1) == -20,
		"Migrated relation profile must preserve old relation"
	)

	var session := GameSessionManager.new()
	var time := TimeManager.new()
	var resources := ResourceManager.new()
	var world := WorldManager.new()
	var diplomacy := DiplomacyManager.new()
	session.initialize_new_game("Дипломатия", 97531, [], [])
	resources.initialize_new_game()
	world.game_session_manager = session
	world.time_manager = time
	world.initialize_new_game()
	diplomacy.world_manager = world
	diplomacy.resource_manager = resources
	diplomacy.time_manager = time
	var state_id := WorldGenerator.AI_STATE_IDS[0]
	var initial_gold := resources.gold
	_expect(diplomacy.send_gift(state_id), "Gift must create a diplomatic memory")
	_expect(resources.gold == initial_gold - DiplomacyManager.GIFT_GOLD_COST, "Gift must keep its visible cost")
	var reasons := world.get_relation_reasons(state_id)
	_expect(
		"Помнят: корона прислала щедрый подарок" in reasons,
		"Diplomatic panel reasons must include the gift"
	)
	var components := world.get_relation_components(state_id)
	_expect(components.has_all(["trust", "fear", "benefit"]), "Relation must expose three named components")
	var saved_state := StateData.to_save_data(world.get_state_by_id(state_id))
	var restored_state := StateData.parse_save_data(saved_state)
	_expect(bool(restored_state.get("valid", false)), "State save must preserve diplomatic history")
	_expect(
		restored_state["state"]["relation_profile"] == world.get_state_by_id(state_id)["relation_profile"],
		"Loaded state must restore every remembered action"
	)
	diplomacy.free()
	world.free()
	resources.free()
	time.free()
	session.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
