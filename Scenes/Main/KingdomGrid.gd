extends Control
class_name KingdomGrid

const GRID_COLUMNS := 10
const GRID_ROWS := 6
const MAXIMUM_CELL_SIZE := 96.0
const MINIMUM_CELL_SIZE := 12.0
const GRID_SIZE := Vector2i(GRID_COLUMNS, GRID_ROWS)

@export var house_definition: BuildingDefinition
@export var lumber_camp_definition: BuildingDefinition
@export var farm_definition: BuildingDefinition
@export var mine_definition: BuildingDefinition
@export var barracks_definition: BuildingDefinition

@onready var building_manager: BuildingManager = $"../BuildingManager" as BuildingManager

var selected_building: BuildingDefinition
var _building_visuals: Array[Control] = []
var _cell_size := MAXIMUM_CELL_SIZE


func _ready() -> void:
	building_manager.building_placed.connect(_on_building_placed)
	building_manager.buildings_loaded.connect(rebuild_building_visuals)
	resized.connect(_on_grid_resized)
	_update_cell_size()
	rebuild_building_visuals()
	queue_redraw()


func select_house() -> void:
	selected_building = house_definition


func select_lumber_camp() -> void:
	selected_building = lumber_camp_definition


func select_farm() -> void:
	selected_building = farm_definition


func select_mine() -> void:
	selected_building = mine_definition


func select_barracks() -> void:
	selected_building = barracks_definition


func clear_selection() -> void:
	selected_building = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.24, 0.14), true)
	_draw_terrain()
	for row in GRID_ROWS:
		for column in GRID_COLUMNS:
			var cell_rect := Rect2(
				Vector2(column * _cell_size, row * _cell_size),
				Vector2(_cell_size, _cell_size)
			)
			draw_rect(cell_rect, Color(0.12, 0.17, 0.09, 0.22), true)
			draw_rect(cell_rect, Color(0.72, 0.70, 0.56, 0.52), false, 1.0)


func _draw_terrain() -> void:
	var map_size := Vector2(_cell_size * GRID_COLUMNS, _cell_size * GRID_ROWS)
	var river := PackedVector2Array([
		Vector2(0.0, map_size.y * 0.43),
		Vector2(map_size.x * 0.12, map_size.y * 0.48),
		Vector2(map_size.x * 0.2, map_size.y * 0.67),
		Vector2(map_size.x * 0.31, map_size.y),
	])
	draw_polyline(river, Color(0.12, 0.28, 0.32, 0.95), _cell_size * 0.42, true)
	draw_polyline(river, Color(0.28, 0.43, 0.42, 0.75), _cell_size * 0.27, true)
	var road := PackedVector2Array([
		Vector2(map_size.x * 0.08, map_size.y * 0.7),
		Vector2(map_size.x * 0.33, map_size.y * 0.48),
		Vector2(map_size.x * 0.56, map_size.y * 0.52),
		Vector2(map_size.x * 0.83, map_size.y * 0.24),
		Vector2(map_size.x, map_size.y * 0.2),
	])
	draw_polyline(road, Color(0.38, 0.31, 0.19, 0.72), _cell_size * 0.2, true)
	for tree_position in [
		Vector2(0.08, 0.12), Vector2(0.14, 0.18), Vector2(0.88, 0.12),
		Vector2(0.92, 0.55), Vector2(0.78, 0.7), Vector2(0.56, 0.18),
	]:
		_draw_tree(Vector2(tree_position) * map_size)


func _draw_tree(tree_position: Vector2) -> void:
	var radius := _cell_size * 0.09
	draw_circle(tree_position + Vector2(0.0, radius * 0.9), radius * 0.35, Color(0.22, 0.14, 0.07, 1))
	draw_circle(tree_position, radius, Color(0.08, 0.19, 0.1, 0.95))
	draw_circle(tree_position + Vector2(-radius * 0.55, radius * 0.35), radius * 0.72, Color(0.12, 0.27, 0.12, 0.95))


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if selected_building == null:
		return

	var grid_position := Vector2i(
		floori(mouse_event.position.x / _cell_size),
		floori(mouse_event.position.y / _cell_size)
	)
	if not _is_inside_grid(grid_position, selected_building.size):
		return

	building_manager.place_building(selected_building, grid_position)
	accept_event()


func _on_building_placed(building: Dictionary) -> void:
	_create_building_visual(building)


func rebuild_building_visuals() -> void:
	for visual in _building_visuals:
		if is_instance_valid(visual):
			if visual.get_parent() == self:
				remove_child(visual)
			visual.queue_free()
	_building_visuals.clear()

	for building in building_manager.get_all_buildings():
		_create_building_visual(building)


func _create_building_visual(building: Dictionary) -> void:
	var definition := _get_definition_by_id(StringName(building["building_id"]))
	if definition == null:
		return

	var grid_position: Vector2i = building["grid_position"]
	var visual_position := Vector2(grid_position) * _cell_size
	var visual_size := Vector2(definition.size) * _cell_size
	var visual: Control

	if definition.texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = definition.texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual = texture_rect
	else:
		var emoji_label := Label.new()
		emoji_label.text = definition.emoji
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_label.add_theme_font_size_override("font_size", 36)
		visual = emoji_label

	visual.position = visual_position
	visual.size = visual_size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	_building_visuals.append(visual)


func _on_grid_resized() -> void:
	_update_cell_size()
	rebuild_building_visuals()
	queue_redraw()


func _update_cell_size() -> void:
	_cell_size = clampf(
		minf(size.x / float(GRID_COLUMNS), size.y / float(GRID_ROWS)),
		MINIMUM_CELL_SIZE,
		MAXIMUM_CELL_SIZE
	)


func _get_definition_by_id(building_id: StringName) -> BuildingDefinition:
	if house_definition != null and house_definition.id == building_id:
		return house_definition
	if lumber_camp_definition != null and lumber_camp_definition.id == building_id:
		return lumber_camp_definition
	if farm_definition != null and farm_definition.id == building_id:
		return farm_definition
	if mine_definition != null and mine_definition.id == building_id:
		return mine_definition
	if barracks_definition != null and barracks_definition.id == building_id:
		return barracks_definition
	return null


func _is_inside_grid(grid_position: Vector2i, building_size: Vector2i) -> bool:
	return (
		grid_position.x >= 0
		and grid_position.y >= 0
		and grid_position.x + building_size.x <= GRID_SIZE.x
		and grid_position.y + building_size.y <= GRID_SIZE.y
	)
