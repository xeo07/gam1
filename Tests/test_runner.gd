extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_test_new_session_initialization()
	_test_seed_reproducibility()
	_test_state_data_round_trip()
	_test_state_name_generation()

	if _failures.is_empty():
		print("KINGDOOM tests passed: 4")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
