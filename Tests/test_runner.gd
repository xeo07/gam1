extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_test_new_session_initialization()
	_test_seed_reproducibility()

	if _failures.is_empty():
		print("KINGDOOM tests passed: 2")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

