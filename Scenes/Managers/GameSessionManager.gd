extends Node
class_name GameSessionManager

signal session_initialized
signal kingdom_name_changed(name: String)
signal identity_visuals_changed

const FLAG_SIZE := Vector2i(16, 10)
const EMBLEM_SIZE := Vector2i(12, 12)

var kingdom_name: String = ""
var world_seed: int = 0
var is_new_game: bool = false
var flag_pixels: Array = []
var emblem_pixels: Array = []

var _rng := RandomNumberGenerator.new()
var _initialized := false
var _flag_texture: ImageTexture
var _emblem_texture: ImageTexture


func initialize_new_game(
	new_kingdom_name: String,
	new_world_seed: int,
	new_flag_pixels: Array,
	new_emblem_pixels: Array
) -> void:
	if _initialized:
		return
	kingdom_name = new_kingdom_name.strip_edges()
	world_seed = new_world_seed
	is_new_game = true
	_rng.seed = world_seed
	if not set_flag_pixels(new_flag_pixels):
		flag_pixels = generate_default_flag(_create_identity_rng(world_seed))
	if not set_emblem_pixels(new_emblem_pixels):
		emblem_pixels = generate_default_emblem(_create_identity_rng(world_seed + 1))
	_rebuild_identity_textures()
	_initialized = true
	kingdom_name_changed.emit(kingdom_name)
	identity_visuals_changed.emit()
	session_initialized.emit()
	print("Game session initialized:")
	print("Kingdom: %s" % kingdom_name)
	print("Seed: %d" % world_seed)


func initialize_loaded_game() -> void:
	if not _initialized:
		return
	is_new_game = false
	kingdom_name_changed.emit(kingdom_name)
	identity_visuals_changed.emit()
	session_initialized.emit()


func get_kingdom_name() -> String:
	return kingdom_name


func get_world_seed() -> int:
	return world_seed


func get_rng() -> RandomNumberGenerator:
	return _rng


func set_flag_pixels(data: Array) -> bool:
	if not PixelArtEditor.is_pixel_data_valid(data, FLAG_SIZE.x, FLAG_SIZE.y):
		return false
	flag_pixels = PixelArtEditor.duplicate_pixels(data)
	_flag_texture = PixelArtEditor.create_texture_from_pixels(flag_pixels)
	if _initialized:
		identity_visuals_changed.emit()
	return true


func set_emblem_pixels(data: Array) -> bool:
	if not PixelArtEditor.is_pixel_data_valid(data, EMBLEM_SIZE.x, EMBLEM_SIZE.y):
		return false
	emblem_pixels = PixelArtEditor.duplicate_pixels(data)
	_emblem_texture = PixelArtEditor.create_texture_from_pixels(emblem_pixels)
	if _initialized:
		identity_visuals_changed.emit()
	return true


func get_flag_pixels() -> Array:
	return PixelArtEditor.duplicate_pixels(flag_pixels)


func get_emblem_pixels() -> Array:
	return PixelArtEditor.duplicate_pixels(emblem_pixels)


func get_flag_texture() -> ImageTexture:
	return _flag_texture


func get_emblem_texture() -> ImageTexture:
	return _emblem_texture


static func generate_default_flag(rng: RandomNumberGenerator) -> Array:
	var primary := rng.randi_range(4, PixelArtEditor.PALETTE.size() - 1)
	var secondary := rng.randi_range(4, PixelArtEditor.PALETTE.size() - 1)
	if secondary == primary:
		secondary = 4 + ((secondary - 3) % (PixelArtEditor.PALETTE.size() - 4))
	var accent := rng.randi_range(1, PixelArtEditor.PALETTE.size() - 1)
	while accent == primary or accent == secondary:
		accent = 1 + (accent % (PixelArtEditor.PALETTE.size() - 1))
	var pattern := rng.randi_range(0, 7)
	var pixels: Array = []
	for y in FLAG_SIZE.y:
		var row: Array = []
		for x in FLAG_SIZE.x:
			var color := primary
			match pattern:
				0: color = primary if y < FLAG_SIZE.y / 2 else secondary
				1: color = primary if x < FLAG_SIZE.x / 2 else secondary
				2: color = accent if absi(x - FLAG_SIZE.x / 2) <= 1 or absi(y - FLAG_SIZE.y / 2) <= 1 else (primary if x < FLAG_SIZE.x / 2 else secondary)
				3: color = accent if absi(x - y * FLAG_SIZE.x / FLAG_SIZE.y) <= 1 else (primary if x < y * FLAG_SIZE.x / FLAG_SIZE.y else secondary)
				4: color = accent if x < FLAG_SIZE.x / 3 and y < FLAG_SIZE.y / 2 else (primary if y < FLAG_SIZE.y / 2 else secondary)
				5: color = primary if x < FLAG_SIZE.x / 3 else (secondary if x < FLAG_SIZE.x * 2 / 3 else accent)
				6: color = accent if x <= 1 or x >= FLAG_SIZE.x - 2 or y <= 1 or y >= FLAG_SIZE.y - 2 else (primary if y < FLAG_SIZE.y / 2 else secondary)
				7: color = accent if absi(x - FLAG_SIZE.x / 2) <= y / 2 else (primary if x < FLAG_SIZE.x / 2 else secondary)
			row.append(color)
		pixels.append(row)
	return pixels


static func generate_default_emblem(rng: RandomNumberGenerator) -> Array:
	var background := rng.randi_range(4, PixelArtEditor.PALETTE.size() - 1)
	var symbol := rng.randi_range(1, PixelArtEditor.PALETTE.size() - 1)
	if symbol == background:
		symbol = 1 if background != 1 else 10
	var detail := rng.randi_range(1, PixelArtEditor.PALETTE.size() - 1)
	while detail == background or detail == symbol:
		detail = 1 + (detail % (PixelArtEditor.PALETTE.size() - 1))
	var pattern := rng.randi_range(0, 7)
	var pixels: Array = []
	for y in EMBLEM_SIZE.y:
		var row: Array = []
		for x in EMBLEM_SIZE.x:
			var mx := mini(x, EMBLEM_SIZE.x - 1 - x)
			var color := background
			match pattern:
				0:
					if mx in [4, 5] or y in [5, 6]: color = symbol
				1:
					if absi(x - 5) + absi(y - 5) <= 4: color = symbol
					if absi(x - 5) + absi(y - 5) <= 1: color = detail
				2:
					if y >= 2 and y <= 9 and mx >= maxi(1, y / 3) and mx <= 5: color = symbol
					if y in [3, 4] and mx in [4, 5]: color = detail
				3:
					if y in [3, 4] and mx in [1, 3, 5] or y in [5, 6] and mx >= 1 or y >= 7 and y <= 9 and mx in [2, 5]: color = symbol
				4:
					if y >= 6 and mx in [4, 5] or y in [3, 4, 5] and mx >= 2 or y == 2 and mx in [3, 5]: color = symbol
				5:
					if y >= 3 and y <= 9 and (mx in [2, 5] or y in [3, 6, 9]): color = symbol
					if y in [4, 5] and mx in [3, 4]: color = detail
				6:
					var distance := absi(x - 5) + absi(y - 5)
					if distance <= 2: color = detail
					elif distance in [4, 5] and (x == 5 or y == 5 or x + y in [6, 16] or x - y in [-6, 6]): color = symbol
				7:
					if y in [4, 5] and mx >= 2 or y in [3, 6] and mx in [1, 2, 4, 5] or y >= 7 and mx in [4, 5]: color = symbol
			row.append(color)
		pixels.append(row)
	return pixels


func is_initialized() -> bool:
	return _initialized


func get_save_data() -> Dictionary:
	var current_rng_state := _rng.state
	return {
		"kingdom_name": kingdom_name,
		"world_seed": world_seed,
		"rng_state": current_rng_state,
		"rng_state_exact": str(current_rng_state),
		"flag_pixels": get_flag_pixels(),
		"emblem_pixels": get_emblem_pixels(),
	}


func is_save_data_valid(data: Dictionary) -> bool:
	return bool(_parse_save_data(data).get("valid", false))


func load_save_data(data: Dictionary) -> bool:
	var parsed := _parse_save_data(data)
	if not bool(parsed.get("valid", false)):
		return false
	kingdom_name = parsed["kingdom_name"]
	world_seed = parsed["world_seed"]
	_rng.seed = world_seed
	_rng.state = int(parsed["rng_state"])
	flag_pixels = parsed["flag_pixels"]
	emblem_pixels = parsed["emblem_pixels"]
	_rebuild_identity_textures()
	is_new_game = false
	_initialized = true
	return true


func _parse_save_data(data: Dictionary) -> Dictionary:
	if not data.has_all([
		"kingdom_name",
		"world_seed",
		"rng_state",
		"flag_pixels",
		"emblem_pixels",
	]):
		return {"valid": false}
	if not data["kingdom_name"] is String:
		return {"valid": false}
	if not _is_integer_value(data["world_seed"]):
		return {"valid": false}
	if not _is_integer_value(data["rng_state"]):
		return {"valid": false}
	if not data["flag_pixels"] is Array or not data["emblem_pixels"] is Array:
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(
		data["flag_pixels"], FLAG_SIZE.x, FLAG_SIZE.y
	):
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(
		data["emblem_pixels"], EMBLEM_SIZE.x, EMBLEM_SIZE.y
	):
		return {"valid": false}
	var loaded_rng_state := int(data["rng_state"])
	if data.has("rng_state_exact"):
		if not data["rng_state_exact"] is String:
			return {"valid": false}
		var exact_state := String(data["rng_state_exact"])
		if not exact_state.is_valid_int():
			return {"valid": false}
		loaded_rng_state = int(exact_state)
	var loaded_name := String(data["kingdom_name"]).strip_edges()
	if loaded_name.length() < 2 or loaded_name.length() > 24:
		return {"valid": false}
	return {
		"valid": true,
		"kingdom_name": loaded_name,
		"world_seed": int(data["world_seed"]),
		"rng_state": loaded_rng_state,
		"flag_pixels": PixelArtEditor.duplicate_pixels(data["flag_pixels"]),
		"emblem_pixels": PixelArtEditor.duplicate_pixels(data["emblem_pixels"]),
	}


func _rebuild_identity_textures() -> void:
	_flag_texture = PixelArtEditor.create_texture_from_pixels(flag_pixels)
	_emblem_texture = PixelArtEditor.create_texture_from_pixels(emblem_pixels)


static func _create_identity_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
