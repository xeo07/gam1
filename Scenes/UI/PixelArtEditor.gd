extends Control
class_name PixelArtEditor

signal pixels_changed
signal random_requested

const TRANSPARENT_INDEX := -1
const FLAG_CELL_SIZE := 20.0
const EMBLEM_CELL_SIZE := 20.0
const PALETTE: Array[Color] = [
	Color(0.03, 0.03, 0.035, 1.0),
	Color(0.94, 0.92, 0.84, 1.0),
	Color(0.48, 0.49, 0.50, 1.0),
	Color(0.20, 0.21, 0.22, 1.0),
	Color(0.76, 0.12, 0.10, 1.0),
	Color(0.36, 0.045, 0.04, 1.0),
	Color(0.12, 0.32, 0.75, 1.0),
	Color(0.035, 0.10, 0.31, 1.0),
	Color(0.16, 0.58, 0.22, 1.0),
	Color(0.035, 0.25, 0.09, 1.0),
	Color(0.92, 0.80, 0.16, 1.0),
	Color(0.72, 0.49, 0.10, 1.0),
	Color(0.92, 0.39, 0.08, 1.0),
	Color(0.35, 0.18, 0.07, 1.0),
	Color(0.48, 0.16, 0.62, 1.0),
	Color(0.08, 0.62, 0.61, 1.0),
]

@onready var editor_title_label: Label = $MainContainer/EditorHeader/EditorTitleLabel
@onready var size_label: Label = $MainContainer/EditorHeader/SizeLabel
@onready var tool_status_label: Label = $MainContainer/EditorHeader/ToolStatusLabel
@onready var random_button: Button = $MainContainer/EditorHeader/RandomButton
@onready var drawing_surface: Control = $MainContainer/WorkspaceContainer/CanvasPanel/CenterContainer/DrawingSurface
@onready var pencil_button: Button = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/ToolsGrid/PencilButton
@onready var eraser_button: Button = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/ToolsGrid/EraserButton
@onready var fill_button: Button = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/ToolsGrid/FillButton
@onready var clear_button: Button = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/ToolsGrid/ClearButton
@onready var grid_check_box: CheckBox = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/GridCheckBox
@onready var palette_grid: GridContainer = $MainContainer/WorkspaceContainer/ToolsPanel/VBoxContainer/PaletteGrid
@onready var preview_texture_rect: TextureRect = $MainContainer/PreviewPanel/HBoxContainer/PreviewTextureRect
@onready var clear_confirmation: ConfirmationDialog = $ClearConfirmation

var _grid_width := 16
var _grid_height := 10
var _cell_size := FLAG_CELL_SIZE
var _pixels: Array = []
var _palette_buttons: Array[Button] = []
var _transparent_button: Button
var _selected_color := 1
var _tool: StringName = &"pencil"
var _last_drag_cell := Vector2i(-1, -1)


func _ready() -> void:
	pencil_button.pressed.connect(func() -> void: _set_tool(&"pencil"))
	eraser_button.pressed.connect(func() -> void: _set_tool(&"eraser"))
	fill_button.pressed.connect(func() -> void: _set_tool(&"fill"))
	clear_button.pressed.connect(_request_clear)
	grid_check_box.toggled.connect(func(_enabled: bool) -> void: drawing_surface.queue_redraw())
	random_button.pressed.connect(func() -> void: random_requested.emit())
	clear_confirmation.confirmed.connect(clear_pixels)
	drawing_surface.draw.connect(_draw_drawing_surface)
	drawing_surface.gui_input.connect(_on_drawing_surface_gui_input)
	drawing_surface.mouse_exited.connect(func() -> void: _last_drag_cell = Vector2i(-1, -1))
	_build_palette()
	configure("Редактор", _grid_width, _grid_height, "Случайный рисунок")


func configure(title: String, width: int, height: int, random_text := "Случайный рисунок") -> void:
	_grid_width = maxi(width, 1)
	_grid_height = maxi(height, 1)
	_cell_size = EMBLEM_CELL_SIZE if width == height else FLAG_CELL_SIZE
	editor_title_label.text = title
	size_label.text = "%d×%d" % [_grid_width, _grid_height]
	random_button.text = random_text
	drawing_surface.custom_minimum_size = Vector2(_grid_width, _grid_height) * _cell_size
	preview_texture_rect.custom_minimum_size = (
		Vector2(96, 60) if width != height else Vector2(60, 60)
	)
	_pixels = create_blank_pixels(_grid_width, _grid_height)
	_last_drag_cell = Vector2i(-1, -1)
	_set_tool(_tool)
	_update_preview()
	drawing_surface.queue_redraw()


func set_pixels(data: Array) -> bool:
	if not is_pixel_data_valid(data, _grid_width, _grid_height):
		return false
	_pixels = duplicate_pixels(data)
	_update_preview()
	drawing_surface.queue_redraw()
	pixels_changed.emit()
	return true


func get_pixels() -> Array:
	return duplicate_pixels(_pixels)


func get_grid_size() -> Vector2i:
	return Vector2i(_grid_width, _grid_height)


func clear_pixels() -> void:
	_pixels = create_blank_pixels(_grid_width, _grid_height)
	_finish_pixel_change()


static func create_blank_pixels(width: int, height: int) -> Array:
	var pixels: Array = []
	for _y in height:
		var row: Array = []
		for _x in width:
			row.append(TRANSPARENT_INDEX)
		pixels.append(row)
	return pixels


static func duplicate_pixels(data: Array) -> Array:
	var copy: Array = []
	for row_value in data:
		if row_value is Array:
			var row_copy: Array = []
			for pixel_value in row_value:
				row_copy.append(int(pixel_value))
			copy.append(row_copy)
	return copy


static func is_pixel_data_valid(data: Array, width: int, height: int) -> bool:
	if data.size() != height:
		return false
	for row_value in data:
		if not row_value is Array:
			return false
		var row: Array = row_value
		if row.size() != width:
			return false
		for pixel_value in row:
			if not _is_integer_value(pixel_value):
				return false
			var palette_index := int(pixel_value)
			if palette_index < TRANSPARENT_INDEX or palette_index >= PALETTE.size():
				return false
	return true


static func create_texture_from_pixels(data: Array) -> ImageTexture:
	if data.is_empty() or not data[0] is Array:
		return ImageTexture.new()
	var height := data.size()
	var width := (data[0] as Array).size()
	if not is_pixel_data_valid(data, width, height):
		return ImageTexture.new()
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var row: Array = data[y]
		for x in width:
			var palette_index := int(row[x])
			image.set_pixel(
				x,
				y,
				Color(0, 0, 0, 0)
				if palette_index == TRANSPARENT_INDEX
				else PALETTE[palette_index]
			)
	return ImageTexture.create_from_image(image)


func _draw_drawing_surface() -> void:
	for y in _grid_height:
		for x in _grid_width:
			var pixel_index := int(_pixels[y][x])
			var cell_rect := Rect2(Vector2(x, y) * _cell_size, Vector2.ONE * _cell_size)
			var color := (
				Color(0.075, 0.07, 0.065, 1.0)
				if pixel_index == TRANSPARENT_INDEX
				else PALETTE[pixel_index]
			)
			drawing_surface.draw_rect(cell_rect, color, true)
			if grid_check_box.button_pressed:
				drawing_surface.draw_rect(cell_rect, Color(0.34, 0.30, 0.23, 0.9), false, 1.0)


func _on_drawing_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		if not mouse_button.pressed:
			_last_drag_cell = Vector2i(-1, -1)
			return
		var cell := _position_to_cell(mouse_button.position)
		if not _is_inside(cell):
			return
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_paint_line(cell, cell, TRANSPARENT_INDEX)
		elif _tool == &"fill":
			_flood_fill(cell, _selected_color)
		else:
			_paint_line(cell, cell, TRANSPARENT_INDEX if _tool == &"eraser" else _selected_color)
		_last_drag_cell = cell
		_finish_pixel_change()
		drawing_surface.accept_event()
		return
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	var is_left_drag := bool(motion.button_mask & MOUSE_BUTTON_MASK_LEFT)
	var is_right_drag := bool(motion.button_mask & MOUSE_BUTTON_MASK_RIGHT)
	if not is_left_drag and not is_right_drag:
		_last_drag_cell = Vector2i(-1, -1)
		return
	if is_left_drag and _tool == &"fill":
		return
	var cell := _position_to_cell(motion.position)
	if not _is_inside(cell):
		_last_drag_cell = Vector2i(-1, -1)
		return
	var start := cell if not _is_inside(_last_drag_cell) else _last_drag_cell
	var color := TRANSPARENT_INDEX if is_right_drag or _tool == &"eraser" else _selected_color
	_paint_line(start, cell, color)
	_last_drag_cell = cell
	_finish_pixel_change()
	drawing_surface.accept_event()


func _paint_line(from: Vector2i, to: Vector2i, palette_index: int) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		_set_pixel(Vector2i(x0, y0), palette_index)
		if x0 == x1 and y0 == y1:
			break
		var doubled_error := 2 * error
		if doubled_error >= dy:
			error += dy
			x0 += sx
		if doubled_error <= dx:
			error += dx
			y0 += sy


func _set_pixel(position: Vector2i, palette_index: int) -> void:
	if _is_inside(position):
		_pixels[position.y][position.x] = palette_index


func _flood_fill(start: Vector2i, replacement: int) -> void:
	var target := int(_pixels[start.y][start.x])
	if target == replacement:
		return
	var queue: Array[Vector2i] = [start]
	var next_index := 0
	var visited: Dictionary = {}
	while next_index < queue.size():
		var position := queue[next_index]
		next_index += 1
		if visited.has(position):
			continue
		visited[position] = true
		if int(_pixels[position.y][position.x]) != target:
			continue
		_pixels[position.y][position.x] = replacement
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_position: Vector2i = position + direction
			if _is_inside(next_position):
				queue.append(next_position)


func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _cell_size), floori(position.y / _cell_size))


func _is_inside(position: Vector2i) -> bool:
	return (
		position.x >= 0
		and position.x < _grid_width
		and position.y >= 0
		and position.y < _grid_height
	)


func _build_palette() -> void:
	for child in palette_grid.get_children():
		palette_grid.remove_child(child)
		child.queue_free()
	_palette_buttons.clear()
	for index in PALETTE.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(26, 26)
		button.tooltip_text = "Цвет %d" % (index + 1)
		button.pressed.connect(_select_color.bind(index))
		palette_grid.add_child(button)
		_palette_buttons.append(button)
	_transparent_button = Button.new()
	_transparent_button.custom_minimum_size = Vector2(26, 26)
	_transparent_button.text = "×"
	_transparent_button.tooltip_text = "Прозрачный пиксель"
	_transparent_button.pressed.connect(_select_color.bind(TRANSPARENT_INDEX))
	palette_grid.add_child(_transparent_button)
	_refresh_palette_buttons()


func _select_color(index: int) -> void:
	_selected_color = index
	_set_tool(&"pencil")
	_refresh_palette_buttons()


func _refresh_palette_buttons() -> void:
	for index in _palette_buttons.size():
		_apply_palette_button_style(_palette_buttons[index], PALETTE[index], index == _selected_color)
	if is_instance_valid(_transparent_button):
		_apply_palette_button_style(
			_transparent_button,
			Color(0.075, 0.07, 0.065, 1.0),
			_selected_color == TRANSPARENT_INDEX
		)


func _apply_palette_button_style(button: Button, color: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var border_width := 4 if selected else 1
	style.set_border_width_all(border_width)
	style.border_color = Color(1.0, 0.78, 0.28, 1.0) if selected else Color(0.30, 0.26, 0.20, 1.0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


func _set_tool(tool: StringName) -> void:
	_tool = tool
	pencil_button.button_pressed = tool == &"pencil"
	eraser_button.button_pressed = tool == &"eraser"
	fill_button.button_pressed = tool == &"fill"
	match tool:
		&"eraser":
			tool_status_label.text = "Инструмент: Ластик"
		&"fill":
			tool_status_label.text = "Инструмент: Заливка"
		_:
			tool_status_label.text = "Инструмент: Кисть"


func _request_clear() -> void:
	clear_confirmation.dialog_text = "Полностью очистить текущий рисунок?"
	clear_confirmation.popup_centered()


func _finish_pixel_change() -> void:
	_update_preview()
	drawing_surface.queue_redraw()
	pixels_changed.emit()


func _update_preview() -> void:
	preview_texture_rect.texture = create_texture_from_pixels(_pixels)


static func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
