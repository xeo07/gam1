extends Node

const MENU_MUSIC := preload("res://Assets/Audio/Music/menu_cathedral.ogg")
const GAME_MUSIC := preload("res://Assets/Audio/Music/game_forest_whisper.ogg")
const UI_CLICK := preload("res://Assets/Audio/SFX/ui_click.ogg")
const MUSIC_FADE_SECONDS := 1.4
const SILENT_DB := -60.0
const MENU_TRACK_GAIN_DB := -8.0
const GAME_TRACK_GAIN_DB := 8.0

var _music_players: Array[AudioStreamPlayer] = []
var _click_player: AudioStreamPlayer
var _active_music_index := -1
var _current_track := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.bus = "Music"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "UiClickPlayer"
	_click_player.stream = UI_CLICK
	_click_player.bus = "SFX"
	_click_player.volume_db = -7.0
	_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click_player)
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons.call_deferred()


func _exit_tree() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
	if _click_player != null:
		_click_player.stop()
		_click_player.stream = null


func play_menu_music() -> void:
	_play_music(MENU_MUSIC, "menu")


func play_game_music() -> void:
	_play_music(GAME_MUSIC, "game")


func play_button_click() -> void:
	if _click_player == null:
		return
	_click_player.stop()
	_click_player.play()


func apply_volume_settings(settings: Dictionary) -> void:
	_set_bus_volume("Master", float(settings.get("master_volume", 0.85)))
	_set_bus_volume("Music", float(settings.get("music_volume", 0.65)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume", 0.8)))


func _play_music(stream: AudioStream, track_id: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _current_track == track_id and _active_music_index >= 0:
		if not _music_players[_active_music_index].playing:
			_music_players[_active_music_index].play()
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var next_index := 0 if _active_music_index != 0 else 1
	var next_player := _music_players[next_index]
	var target_volume_db := MENU_TRACK_GAIN_DB if track_id == "menu" else GAME_TRACK_GAIN_DB
	var previous_index := _active_music_index
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()
	_active_music_index = next_index
	_current_track = track_id
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(
		next_player,
		"volume_db",
		target_volume_db,
		MUSIC_FADE_SECONDS
	)
	if previous_index >= 0 and previous_index != next_index:
		var previous_player := _music_players[previous_index]
		_music_tween.tween_property(
			previous_player,
			"volume_db",
			SILENT_DB,
			MUSIC_FADE_SECONDS
		)
		_music_tween.chain().tween_callback(previous_player.stop)


func _connect_existing_buttons() -> void:
	_connect_buttons_in(get_tree().root)


func _connect_buttons_in(node: Node) -> void:
	_connect_button(node)
	for child in node.get_children():
		_connect_buttons_in(child)


func _on_node_added(node: Node) -> void:
	_connect_button(node)


func _connect_button(node: Node) -> void:
	if not node is BaseButton:
		return
	var button := node as BaseButton
	if button.has_meta("crowns_car_click_connected"):
		return
	button.set_meta("crowns_car_click_connected", true)
	button.pressed.connect(play_button_click)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized_volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized_volume <= 0.001)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(maxf(normalized_volume, 0.001))
	)
