class_name UIWindowLayout
extends RefCounted

const OUTER_MARGIN := 20.0
const MIN_SCROLL_HEIGHT := 72.0


static func make_body_scrollable(
	window: CanvasLayer,
	fixed_top: Array[StringName],
	fixed_bottom: Array[StringName]
) -> void:
	var panel := _get_panel_container(window)
	if panel == null:
		return
	var margin := panel.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return

	var main_vbox := _get_direct_vbox(margin)
	if main_vbox == null:
		_promote_existing_scroll(margin)
		return
	if main_vbox.has_node("BodyScroll"):
		return

	var original_children := main_vbox.get_children()
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.custom_minimum_size.y = MIN_SCROLL_HEIGHT
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(body_scroll)

	var body_content := VBoxContainer.new()
	body_content.name = "BodyContent"
	body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_content.add_theme_constant_override(
		"separation",
		main_vbox.get_theme_constant("separation")
	)
	body_scroll.add_child(body_content)

	var insertion_index := 0
	for child in original_children:
		if StringName(child.name) in fixed_top:
			insertion_index += 1
	main_vbox.move_child(body_scroll, insertion_index)

	for child in original_children:
		var child_name := StringName(child.name)
		if child_name in fixed_top or child_name in fixed_bottom:
			continue
		child.reparent(body_content, false)


static func fit_window(
	window: CanvasLayer,
	bottom_hud_height: float,
	preferred_size: Vector2,
	cover_bottom_hud: bool = false
) -> void:
	if not window.is_inside_tree():
		return
	var overlay := window.get_node_or_null("Overlay") as Control
	var panel := _get_panel_container(window)
	if overlay == null or panel == null:
		return

	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport_size := window.get_viewport().get_visible_rect().size
	var reserved_height := 0.0 if cover_bottom_hud else maxf(bottom_hud_height, 0.0)
	var game_area_size := Vector2(
		maxf(viewport_size.x, 1.0),
		maxf(viewport_size.y - reserved_height, 1.0)
	)

	var game_area_margin := window.get_node_or_null("Overlay/GameAreaMargin") as Control
	var center: CenterContainer
	if game_area_margin != null:
		game_area_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		game_area_margin.offset_bottom = -reserved_height
		center = game_area_margin.get_node_or_null("CenterContainer") as CenterContainer
	else:
		center = window.get_node_or_null("Overlay/CenterContainer") as CenterContainer
		if center != null:
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			center.offset_left = OUTER_MARGIN
			center.offset_top = OUTER_MARGIN
			center.offset_right = -OUTER_MARGIN
			center.offset_bottom = -(reserved_height + OUTER_MARGIN)
	if center == null:
		return

	var maximum_size := Vector2(
		maxf(game_area_size.x - OUTER_MARGIN * 2.0, 1.0),
		maxf(game_area_size.y - OUTER_MARGIN * 2.0, 1.0)
	)
	var target_width := minf(preferred_size.x, maximum_size.x)
	var target_height := minf(preferred_size.y, maximum_size.y)
	panel.custom_minimum_size = Vector2(target_width, target_height)

	var main_split := window.find_child("MainSplit", true, false) as SplitContainer
	if main_split != null:
		var compact_split := game_area_size.y < 420.0 or game_area_size.x < 700.0
		main_split.vertical = compact_split
		var main_content := window.find_child("MainContent", true, false) as Control
		var citizens_column := window.find_child("CitizensColumn", true, false) as Control
		var citizens_list := window.find_child("CitizensList", true, false) as Control
		var details_scroll := window.find_child("DetailsScroll", true, false) as Control
		if main_content != null:
			main_content.custom_minimum_size.y = 100.0 if compact_split else 180.0
		if citizens_column != null:
			citizens_column.custom_minimum_size.y = 0.0 if compact_split else 80.0
		if citizens_list != null:
			citizens_list.custom_minimum_size.y = 36.0 if compact_split else 70.0
		if details_scroll != null:
			details_scroll.custom_minimum_size.y = 36.0 if compact_split else 80.0


static func release_focus(window: CanvasLayer) -> void:
	if window.is_inside_tree():
		window.get_viewport().gui_release_focus()


static func _promote_existing_scroll(margin: MarginContainer) -> void:
	var body_scroll := _get_direct_scroll(margin)
	if body_scroll == null or body_scroll.name == "BodyScroll":
		return
	var body_content := _get_direct_vbox(body_scroll)
	if body_content == null:
		return
	var title := body_content.get_node_or_null("TitleLabel") as Control
	var close_button := body_content.get_node_or_null("CloseButton") as Control
	if title == null or close_button == null:
		return

	var outer := VBoxContainer.new()
	outer.name = "WindowVBox"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	body_scroll.reparent(outer, false)
	body_scroll.name = "BodyScroll"
	body_scroll.custom_minimum_size.y = MIN_SCROLL_HEIGHT
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	title.reparent(outer, false)
	outer.move_child(title, 0)
	close_button.reparent(outer, false)


static func _get_panel_container(window: CanvasLayer) -> PanelContainer:
	var panel := window.get_node_or_null(
		"Overlay/GameAreaMargin/CenterContainer/PanelContainer"
	) as PanelContainer
	if panel != null:
		return panel
	return window.get_node_or_null("Overlay/CenterContainer/PanelContainer") as PanelContainer


static func _get_direct_vbox(parent: Node) -> VBoxContainer:
	for child in parent.get_children():
		if child is VBoxContainer:
			return child as VBoxContainer
	return null


static func _get_direct_scroll(parent: Node) -> ScrollContainer:
	for child in parent.get_children():
		if child is ScrollContainer:
			return child as ScrollContainer
	return null
