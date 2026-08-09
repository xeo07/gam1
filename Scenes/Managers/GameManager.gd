extends Node2D

const GAME_NAME := "Kingdoom"
const GAME_VERSION := "0.0.1"
const GRID_MARGIN := 10.0
const TOP_TOOLBAR_HEIGHT := 64.0
const MAIN_MENU_SCENE := "res://Scenes/Main/MainMenu.tscn"
const PENDING_NEW_GAME_PATH := "user://pending_new_game.json"
const PENDING_LOAD_PATH := "user://pending_load_game.flag"
const LAST_ERROR_PATH := "user://last_menu_error.txt"

@onready var game_session_manager: GameSessionManager = $GameSessionManager as GameSessionManager
@onready var time_manager: TimeManager = $TimeManager as TimeManager
@onready var resource_manager: ResourceManager = $ResourceManager as ResourceManager
@onready var population_manager: PopulationManager = $PopulationManager as PopulationManager
@onready var economy_manager: EconomyManager = $EconomyManager as EconomyManager
@onready var stability_manager: StabilityManager = $StabilityManager as StabilityManager
@onready var event_manager: EventManager = $EventManager as EventManager
@onready var story_chain_manager: StoryChainManager = $StoryChainManager as StoryChainManager
@onready var world_manager: WorldManager = $WorldManager as WorldManager
@onready var save_manager: SaveManager = $SaveManager as SaveManager
@onready var news_manager: NewsManager = $NewsManager as NewsManager
@onready var bottom_hud: BottomHUD = $BottomHUD as BottomHUD
@onready var situation_dashboard: SituationDashboard = $SituationDashboard as SituationDashboard
@onready var corner_menu_button: TopBar = $CornerMenuButton as TopBar
@onready var navigation_panel: NavigationPanel = $NavigationPanel as NavigationPanel
@onready var population_quick_menu: PopulationQuickMenu = $PopulationQuickMenu as PopulationQuickMenu
@onready var army_quick_menu: ArmyQuickMenu = $ArmyQuickMenu as ArmyQuickMenu
@onready var resource_quick_menu: ResourceQuickMenu = $ResourceQuickMenu as ResourceQuickMenu
@onready var side_menu: SideMenu = $SideMenu as SideMenu
@onready var kingdom_stats_panel: KingdomStatsPanel = $KingdomStatsPanel as KingdomStatsPanel
@onready var population_panel: PopulationPanel = $PopulationPanel as PopulationPanel
@onready var army_panel: ArmyPanel = $ArmyPanel as ArmyPanel
@onready var war_panel: WarPanel = $WarPanel as WarPanel
@onready var build_panel: BuildPanel = $BuildPanel as BuildPanel
@onready var hiring_panel: HiringPanel = $HiringPanel as HiringPanel
@onready var relations_panel: RelationsPanel = $RelationsPanel as RelationsPanel
@onready var trade_panel: TradePanel = $TradePanel as TradePanel
@onready var special_goods_panel: SpecialGoodsPanel = $SpecialGoodsPanel as SpecialGoodsPanel
@onready var save_load_panel: SaveLoadPanel = $SaveLoadPanel as SaveLoadPanel
@onready var kingdom_grid: KingdomGrid = $KingdomGrid as KingdomGrid
@onready var war_manager: WarManager = $WarManager as WarManager
@onready var foreign_news_panel: ForeignNewsPanel = $ForeignNewsPanel as ForeignNewsPanel
@onready var spy_report_panel: SpyReportPanel = $SpyReportPanel as SpyReportPanel
@onready var war_report_panel: WarReportPanel = $WarReportPanel as WarReportPanel
@onready var internal_event_panel: InternalEventPanel = $InternalEventPanel as InternalEventPanel
@onready var daily_report_panel: DailyReportPanel = $DailyReportPanel as DailyReportPanel
@onready var pause_menu: PauseMenu = $PauseMenu as PauseMenu
@onready var loading_overlay: CanvasLayer = $LoadingOverlay as CanvasLayer
@onready var tutorial_panel: TutorialPanel = $TutorialPanel as TutorialPanel

var _session_ready := false
var _startup_load_error := ""
var _regular_panels: Array[CanvasLayer] = []
var _quick_menus: Array[CanvasLayer] = []
var _report_panels: Array[CanvasLayer] = []


func _enter_tree() -> void:
	SettingsDialog.apply_saved_settings()


func _ready() -> void:
	_register_windows()
	save_manager.load_failed.connect(_on_load_failed)
	save_manager.game_loaded.connect(_on_game_loaded)
	corner_menu_button.menu_button_pressed.connect(_on_menu_button_pressed)
	corner_menu_button.next_day_pressed.connect(_on_next_day_pressed)
	corner_menu_button.bar_height_changed.connect(_on_top_bar_height_changed)
	navigation_panel.section_selected.connect(_on_navigation_selected)
	bottom_hud.hud_height_changed.connect(_on_hud_height_changed)
	bottom_hud.population_section_pressed.connect(_on_population_section_pressed)
	bottom_hud.army_section_pressed.connect(_on_army_section_pressed)
	bottom_hud.stability_section_pressed.connect(_on_stats_pressed)
	bottom_hud.resources_section_pressed.connect(_on_resources_section_pressed)
	bottom_hud.next_day_pressed.connect(_on_next_day_pressed)
	bottom_hud.relations_pressed.connect(_on_relations_pressed)
	bottom_hud.hiring_pressed.connect(_on_hiring_pressed)
	bottom_hud.messenger_pressed.connect(_on_relations_pressed)
	situation_dashboard.decision_pressed.connect(_show_active_event)
	situation_dashboard.diplomacy_pressed.connect(_on_relations_pressed)
	situation_dashboard.news_pressed.connect(_on_dashboard_news_pressed)
	get_viewport().size_changed.connect(_update_game_area)
	side_menu.save_pressed.connect(_on_save_pressed)
	side_menu.load_pressed.connect(_on_load_pressed)
	side_menu.settings_pressed.connect(_on_settings_pressed)
	side_menu.main_menu_pressed.connect(_on_main_menu_pressed)
	side_menu.exit_pressed.connect(_on_exit_pressed)
	population_quick_menu.population_pressed.connect(_on_population_pressed)
	population_quick_menu.hiring_pressed.connect(_on_hiring_pressed)
	population_quick_menu.build_pressed.connect(_on_build_pressed)
	army_quick_menu.army_pressed.connect(_on_army_pressed)
	army_quick_menu.war_pressed.connect(_on_war_pressed)
	resource_quick_menu.trade_pressed.connect(_on_trade_pressed)
	resource_quick_menu.special_goods_pressed.connect(_on_special_goods_pressed)
	event_manager.internal_event_ready.connect(_on_internal_event_ready)
	event_manager.internal_event_resolved.connect(_on_internal_event_resolved)
	event_manager.event_state_changed.connect(_update_event_lock)
	internal_event_panel.panel_closed.connect(_update_event_lock)
	daily_report_panel.visibility_changed.connect(_on_report_visibility_changed.bind(daily_report_panel))
	foreign_news_panel.visibility_changed.connect(_on_report_visibility_changed.bind(foreign_news_panel))
	spy_report_panel.visibility_changed.connect(_on_report_visibility_changed.bind(spy_report_panel))
	war_report_panel.visibility_changed.connect(_on_report_visibility_changed.bind(war_report_panel))
	for window in _regular_panels + _quick_menus + [side_menu]:
		window.visibility_changed.connect(_on_window_visibility_changed.bind(window))
	war_manager.campaign_completed.connect(_on_campaign_completed)
	build_panel.house_selected.connect(_on_house_selected)
	build_panel.lumber_camp_selected.connect(_on_lumber_camp_selected)
	build_panel.farm_selected.connect(_on_farm_selected)
	build_panel.mine_selected.connect(_on_mine_selected)
	build_panel.barracks_selected.connect(_on_barracks_selected)
	build_panel.cancel_pressed.connect(_on_build_cancelled)
	_on_hud_height_changed(bottom_hud.get_hud_height())
	_prepare_responsive_windows()
	_update_event_lock()
	_update_game_area.call_deferred()
	print("--------------------------------")
	print(GAME_NAME)
	print("Version:", GAME_VERSION)
	print("--------------------------------")
	_initialize_session.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _session_ready or get_tree().paused:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if event_manager.has_active_event():
		_show_active_event()
		return
	if internal_event_panel.is_showing_result():
		internal_event_panel.close_result()
		return
	if _has_visible_report():
		return
	if side_menu.is_menu_open():
		close_system_menu()
		return
	if _has_visible_regular_panel():
		close_regular_panels()
		return
	if _has_visible_quick_menu():
		close_quick_menus()
		return
	pause_menu.open_menu()


func _register_windows() -> void:
	_regular_panels.append(kingdom_stats_panel)
	_regular_panels.append(population_panel)
	_regular_panels.append(army_panel)
	_regular_panels.append(war_panel)
	_regular_panels.append(build_panel)
	_regular_panels.append(hiring_panel)
	_regular_panels.append(relations_panel)
	_regular_panels.append(trade_panel)
	_regular_panels.append(special_goods_panel)
	_regular_panels.append(save_load_panel)
	_quick_menus.append(population_quick_menu)
	_quick_menus.append(army_quick_menu)
	_quick_menus.append(resource_quick_menu)
	_report_panels.append(daily_report_panel)
	_report_panels.append(foreign_news_panel)
	_report_panels.append(spy_report_panel)
	_report_panels.append(war_report_panel)


func _initialize_session() -> void:
	if FileAccess.file_exists(PENDING_LOAD_PATH):
		_remove_file(PENDING_LOAD_PATH)
		_startup_load_error = ""
		if not save_manager.load_game():
			_return_to_menu_with_error(
				_startup_load_error
				if not _startup_load_error.is_empty()
				else "Не удалось загрузить сохранение"
			)
			return
		_finish_initialization(false)
		return

	if FileAccess.file_exists(PENDING_NEW_GAME_PATH):
		var pending_data := _read_pending_new_game()
		if not bool(pending_data.get("valid", false)):
			_return_to_menu_with_error("Некорректные параметры новой игры")
			return
		_remove_file(PENDING_NEW_GAME_PATH)
		game_session_manager.initialize_new_game(
			String(pending_data["kingdom_name"]),
			int(pending_data["world_seed"]),
			pending_data["flag_pixels"],
			pending_data["emblem_pixels"]
		)
		resource_manager.initialize_new_game()
		population_manager.initialize_new_game()
		economy_manager.initialize_new_game()
		stability_manager.initialize_new_game()
		event_manager.initialize_new_game()
		world_manager.initialize_new_game()
		story_chain_manager.initialize_new_game()
		_finish_initialization(bool(pending_data["show_tutorial"]))
		return

	_return_to_menu_with_error("Не указан режим запуска игры")


func _finish_initialization(show_tutorial: bool = false) -> void:
	_session_ready = true
	loading_overlay.visible = false
	get_tree().paused = false
	_update_event_lock()
	if show_tutorial:
		tutorial_panel.open_offer()


func _read_pending_new_game() -> Dictionary:
	var pending_file := FileAccess.open(PENDING_NEW_GAME_PATH, FileAccess.READ)
	if pending_file == null:
		return {"valid": false}
	var json := JSON.new()
	if json.parse(pending_file.get_as_text()) != OK or not json.data is Dictionary:
		return {"valid": false}
	var data: Dictionary = json.data
	if not data.get("kingdom_name", null) is String:
		return {"valid": false}
	if not _is_integer_value(data.get("world_seed", null)):
		return {"valid": false}
	if not data.get("flag_pixels", null) is Array:
		return {"valid": false}
	if not data.get("emblem_pixels", null) is Array:
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(data["flag_pixels"], 16, 10):
		return {"valid": false}
	if not PixelArtEditor.is_pixel_data_valid(data["emblem_pixels"], 12, 12):
		return {"valid": false}
	var loaded_name := String(data["kingdom_name"]).strip_edges()
	if loaded_name.length() < 2 or loaded_name.length() > 24:
		return {"valid": false}
	return {
		"valid": true,
		"kingdom_name": loaded_name,
		"world_seed": int(data["world_seed"]),
		"flag_pixels": PixelArtEditor.duplicate_pixels(data["flag_pixels"]),
		"emblem_pixels": PixelArtEditor.duplicate_pixels(data["emblem_pixels"]),
		"show_tutorial": bool(data.get("show_tutorial", true)),
	}


func _on_load_failed(reason: String) -> void:
	_startup_load_error = reason


func _on_game_loaded() -> void:
	close_system_menu()
	close_quick_menus()
	close_regular_panels()
	foreign_news_panel.close_report()
	spy_report_panel.close_report()
	war_report_panel.close_report()
	daily_report_panel.close_report()
	internal_event_panel.hide_panel()
	if event_manager.has_active_event():
		_show_active_event()
	_update_event_lock()


func _return_to_menu_with_error(reason: String) -> void:
	var error_file := FileAccess.open(LAST_ERROR_PATH, FileAccess.WRITE)
	if error_file != null:
		error_file.store_string(reason)
		error_file.flush()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _is_integer_value(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))


func _on_menu_button_pressed() -> void:
	if event_manager.has_active_event():
		_show_active_event()
		return
	prepare_for_system_menu()
	side_menu.toggle_menu()


func _on_next_day_pressed() -> void:
	if event_manager.has_active_event():
		var event := event_manager.get_active_event()
		print("Next day blocked:")
		print("Unresolved internal event: %s" % String(event.get("event_id", &"")))
		_show_active_event()
		return
	close_quick_menus()
	close_system_menu()
	time_manager.next_day()


func _on_population_section_pressed() -> void:
	open_quick_menu(population_quick_menu)


func _on_army_section_pressed() -> void:
	open_quick_menu(army_quick_menu)


func _on_resources_section_pressed() -> void:
	open_quick_menu(resource_quick_menu)


func _on_stats_pressed() -> void:
	open_regular_panel(kingdom_stats_panel)


func _on_population_pressed() -> void:
	open_regular_panel(population_panel)


func _on_army_pressed() -> void:
	open_regular_panel(army_panel)


func _on_war_pressed() -> void:
	open_regular_panel(war_panel)


func _on_build_pressed() -> void:
	open_regular_panel(build_panel)


func _on_hiring_pressed() -> void:
	open_regular_panel(hiring_panel)


func _on_relations_pressed() -> void:
	open_regular_panel(relations_panel)


func _on_trade_pressed() -> void:
	open_regular_panel(trade_panel)


func _on_special_goods_pressed() -> void:
	open_regular_panel(special_goods_panel)


func _on_save_pressed() -> void:
	open_regular_panel(save_load_panel)


func _on_load_pressed() -> void:
	open_regular_panel(save_load_panel)


func _on_settings_pressed() -> void:
	close_quick_menus()
	close_regular_panels()
	close_system_menu()
	pause_menu.open_settings()


func _on_main_menu_pressed() -> void:
	close_quick_menus()
	close_regular_panels()
	close_system_menu()
	pause_menu.request_main_menu()


func _on_exit_pressed() -> void:
	close_quick_menus()
	close_regular_panels()
	close_system_menu()
	pause_menu.request_exit()


func _on_campaign_completed(_report: Dictionary) -> void:
	close_system_menu()
	close_quick_menus()


func _on_internal_event_ready(event: Dictionary) -> void:
	close_quick_menus()
	close_regular_panels()
	close_system_menu()
	if not internal_event_panel.visible:
		internal_event_panel.open_event(event)
	_update_event_lock()


func _on_internal_event_resolved(_result: Dictionary) -> void:
	_update_event_lock()


func _show_active_event() -> void:
	if not event_manager.has_active_event():
		return
	close_quick_menus()
	close_regular_panels()
	close_system_menu()
	internal_event_panel.open_event(event_manager.get_active_event())
	_update_event_lock()


func _update_event_lock() -> void:
	corner_menu_button.menu_button.disabled = event_manager.has_active_event() or internal_event_panel.visible


func _on_report_visibility_changed(panel: CanvasLayer) -> void:
	if panel.visible:
		close_quick_menus()
		close_regular_panels()
		close_system_menu()
	else:
		UIWindowLayout.release_focus(panel)


func _on_window_visibility_changed(window: CanvasLayer) -> void:
	if not window.visible:
		UIWindowLayout.release_focus(window)


func _on_hud_height_changed(_height: float) -> void:
	side_menu.set_bottom_hud_height(_height)
	_update_game_area()


func _on_top_bar_height_changed(_height: float) -> void:
	_update_game_area()


func _update_game_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var hud_height := bottom_hud.get_hud_height()
	var layout := UILayoutMetrics.calculate(viewport_size, hud_height)
	var grid_rect: Rect2 = layout["grid_rect"]
	var nav_rect: Rect2 = layout["nav_rect"]
	situation_dashboard.layout_for_viewport(hud_height)
	navigation_panel.layout(nav_rect)
	kingdom_grid.position = grid_rect.position
	kingdom_grid.size = grid_rect.size
	_update_window_layouts(hud_height)


func _on_navigation_selected(section: StringName) -> void:
	match section:
		&"overview":
			close_regular_panels()
		&"build":
			_on_build_pressed()
		&"population":
			_on_population_pressed()
		&"army":
			_on_army_pressed()
		&"diplomacy", &"espionage", &"world":
			_on_relations_pressed()
		&"trade":
			_on_trade_pressed()
		&"events":
			if event_manager.has_active_event():
				_show_active_event()
			else:
				_on_dashboard_news_pressed()


func _on_dashboard_news_pressed() -> void:
	var edition: Dictionary = news_manager.get_latest_weekly_edition()
	if not edition.is_empty():
		foreign_news_panel.open_report(edition)


func open_regular_panel(panel: CanvasLayer) -> void:
	if panel not in _regular_panels:
		push_error("Attempted to open an unregistered regular panel: %s" % panel.name)
		return
	if event_manager.has_active_event():
		_show_active_event()
		return
	close_quick_menus()
	close_system_menu()
	close_regular_panels()
	panel.call("open_panel")


func open_quick_menu(menu: CanvasLayer) -> void:
	if menu not in _quick_menus:
		push_error("Attempted to open an unregistered quick menu: %s" % menu.name)
		return
	if event_manager.has_active_event():
		_show_active_event()
		return
	close_regular_panels()
	close_system_menu()
	close_quick_menus()
	menu.call("open_menu")


func close_regular_panels() -> void:
	for panel in _regular_panels:
		panel.call("close_panel")
	kingdom_grid.clear_selection()


func close_quick_menus() -> void:
	for menu in _quick_menus:
		menu.call("close_menu")


func close_system_menu() -> void:
	side_menu.close_menu()


func prepare_for_system_menu() -> void:
	close_quick_menus()
	close_regular_panels()


func _has_visible_regular_panel() -> bool:
	for panel in _regular_panels:
		if panel.visible:
			return true
	return false


func _has_visible_quick_menu() -> bool:
	for menu in _quick_menus:
		if menu.visible:
			return true
	return false


func _has_visible_report() -> bool:
	for report in _report_panels:
		if report.visible:
			return true
	return false


func _prepare_responsive_windows() -> void:
	UIWindowLayout.make_body_scrollable(
		army_panel, [&"TitleLabel", &"SummaryLabel"], [&"StatusLabel", &"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		war_panel, [&"TitleLabel"], [&"StatusLabel", &"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		kingdom_stats_panel, [&"TitleLabel"], [&"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		trade_panel, [&"TitleLabel"], [&"StatusLabel", &"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		special_goods_panel, [&"TitleLabel"], [&"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		save_load_panel, [&"TitleLabel"], [&"StatusLabel", &"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		spy_report_panel, [&"TitleLabel"], [&"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(
		war_report_panel, [&"TitleLabel"], [&"CloseButton"]
	)
	UIWindowLayout.make_body_scrollable(daily_report_panel, [], [])
	var foreign_news_scroll := foreign_news_panel.get_node(
		"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer"
	) as ScrollContainer
	foreign_news_scroll.custom_minimum_size.y = UIWindowLayout.MIN_SCROLL_HEIGHT
	_update_window_layouts(bottom_hud.get_hud_height())


func _update_window_layouts(hud_height: float) -> void:
	UIWindowLayout.fit_window(kingdom_stats_panel, hud_height, Vector2(720, 680))
	UIWindowLayout.fit_window(population_panel, hud_height, Vector2(860, 640))
	UIWindowLayout.fit_window(army_panel, hud_height, Vector2(760, 680))
	UIWindowLayout.fit_window(war_panel, hud_height, Vector2(760, 680))
	UIWindowLayout.fit_window(build_panel, hud_height, Vector2(420, 360))
	UIWindowLayout.fit_window(hiring_panel, hud_height, Vector2(420, 300))
	UIWindowLayout.fit_window(relations_panel, hud_height, Vector2(1040, 680))
	UIWindowLayout.fit_window(trade_panel, hud_height, Vector2(720, 620))
	UIWindowLayout.fit_window(special_goods_panel, hud_height, Vector2(560, 360))
	UIWindowLayout.fit_window(save_load_panel, hud_height, Vector2(480, 360))
	UIWindowLayout.fit_window(daily_report_panel, hud_height, Vector2(640, 680), true)
	UIWindowLayout.fit_window(foreign_news_panel, hud_height, Vector2(680, 620), true)
	UIWindowLayout.fit_window(spy_report_panel, hud_height, Vector2(520, 560), true)
	UIWindowLayout.fit_window(war_report_panel, hud_height, Vector2(680, 560), true)
	UIWindowLayout.fit_window(internal_event_panel, hud_height, Vector2(720, 640), true)


func _on_house_selected() -> void:
	kingdom_grid.select_house()
	_finish_building_selection()


func _on_lumber_camp_selected() -> void:
	kingdom_grid.select_lumber_camp()
	_finish_building_selection()


func _on_farm_selected() -> void:
	kingdom_grid.select_farm()
	_finish_building_selection()


func _on_mine_selected() -> void:
	kingdom_grid.select_mine()
	_finish_building_selection()


func _on_barracks_selected() -> void:
	kingdom_grid.select_barracks()
	_finish_building_selection()


func _finish_building_selection() -> void:
	# Keep the selected building, but uncover the grid so the player can place it.
	build_panel.close_panel()
	UIWindowLayout.release_focus(build_panel)


func _on_build_cancelled() -> void:
	kingdom_grid.clear_selection()
	build_panel.close_panel()
