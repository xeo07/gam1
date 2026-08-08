extends CanvasLayer
class_name PopulationPanel

const JOB_DISPLAY_NAMES: Dictionary = {
	&"unassigned": "Без профессии",
	&"woodcutter": "Лесоруб",
	&"farmer": "Фермер",
	&"miner": "Шахтёр",
	&"builder": "Строитель",
	&"blacksmith": "Кузнец",
	&"soldier": "Солдат",
}

const CONTENT_PATH := "Overlay/GameAreaMargin/CenterContainer/PanelContainer/MarginContainer/VBoxContainer"
const DETAILS_PATH := "MainContent/MainSplit/DetailsScroll/DetailsPanel/VBoxContainer"

@onready var content: VBoxContainer = get_node(CONTENT_PATH) as VBoxContainer
@onready var citizens_list: ItemList = content.get_node(
	"MainContent/MainSplit/CitizensColumn/CitizensList"
) as ItemList
@onready var details: VBoxContainer = content.get_node(DETAILS_PATH) as VBoxContainer
@onready var name_label: Label = details.get_node("NameLabel") as Label
@onready var job_label: Label = details.get_node("JobLabel") as Label
@onready var job_option_button: OptionButton = details.get_node("JobOptionButton") as OptionButton
@onready var assign_job_button: Button = details.get_node("AssignJobButton") as Button
@onready var strength_label: Label = details.get_node("StrengthLabel") as Label
@onready var intelligence_label: Label = details.get_node("IntelligenceLabel") as Label
@onready var speed_label: Label = details.get_node("SpeedLabel") as Label
@onready var loyalty_label: Label = details.get_node("LoyaltyLabel") as Label
@onready var craftsmanship_label: Label = details.get_node("CraftsmanshipLabel") as Label
@onready var close_button: Button = content.get_node("Footer/CloseButton") as Button
@onready var population_manager: PopulationManager = $"../PopulationManager" as PopulationManager

var _citizen_ids: Array[int] = []
var _selected_citizen_id: int = -1


func _ready() -> void:
	citizens_list.item_selected.connect(_on_citizen_selected)
	assign_job_button.pressed.connect(_on_assign_job_pressed)
	close_button.pressed.connect(close_panel)
	population_manager.population_changed.connect(_on_population_changed)
	population_manager.citizen_updated.connect(_on_citizen_updated)
	_clear_details()


func open_panel() -> void:
	visible = true
	_populate_job_options()
	refresh_citizens()


func close_panel() -> void:
	visible = false


func refresh_citizens() -> void:
	var citizens := population_manager.get_all_citizens()
	citizens_list.clear()
	_citizen_ids.clear()

	if citizens.is_empty():
		citizens_list.add_item("Жителей нет")
		citizens_list.set_item_disabled(0, true)
		_selected_citizen_id = -1
		_clear_details()
		return

	for citizen in citizens:
		var citizen_id := int(citizen["id"])
		_citizen_ids.append(citizen_id)
		citizens_list.add_item(_format_citizen_list_item(citizen))

	var selected_index := _citizen_ids.find(_selected_citizen_id)
	if selected_index == -1:
		_selected_citizen_id = -1
		_clear_details()
		return

	citizens_list.select(selected_index)
	_show_citizen(_selected_citizen_id)


func _on_citizen_selected(index: int) -> void:
	if index < 0 or index >= _citizen_ids.size():
		return

	_selected_citizen_id = _citizen_ids[index]
	_show_citizen(_selected_citizen_id)


func _on_population_changed(_total_population: int) -> void:
	if visible:
		refresh_citizens()


func _on_citizen_updated(citizen_id: int) -> void:
	if not visible:
		return

	_update_citizen_list_item(citizen_id)
	if citizen_id == _selected_citizen_id:
		_show_citizen(citizen_id)


func _on_assign_job_pressed() -> void:
	if _selected_citizen_id == -1 or job_option_button.selected == -1:
		return

	var selected_job: StringName = job_option_button.get_item_metadata(job_option_button.selected)
	population_manager.assign_job(_selected_citizen_id, selected_job)


func _show_citizen(citizen_id: int) -> void:
	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty():
		_selected_citizen_id = -1
		_clear_details()
		return

	var job: StringName = citizen.get("job", &"unassigned")

	name_label.text = "Имя: %s" % String(citizen["name"])
	job_label.text = "Профессия: %s" % _get_job_display_name(job)
	strength_label.text = "Сила: %d/10" % int(citizen["strength"])
	intelligence_label.text = "Интеллект: %d/10" % int(citizen["intelligence"])
	speed_label.text = "Скорость: %d/10" % int(citizen["speed"])
	loyalty_label.text = "Верность: %d/10" % int(citizen["loyalty"])
	craftsmanship_label.text = "Ремесло: %d/10" % int(citizen["craftsmanship"])
	_select_job(job)
	assign_job_button.disabled = false


func _populate_job_options() -> void:
	job_option_button.clear()
	for job in population_manager.get_available_jobs():
		var item_index := job_option_button.item_count
		job_option_button.add_item(_get_job_display_name(job))
		job_option_button.set_item_metadata(item_index, job)


func _select_job(job: StringName) -> void:
	for item_index in job_option_button.item_count:
		if job_option_button.get_item_metadata(item_index) == job:
			job_option_button.select(item_index)
			return


func _update_citizen_list_item(citizen_id: int) -> void:
	var item_index := _citizen_ids.find(citizen_id)
	if item_index == -1:
		return

	var citizen := population_manager.get_citizen_by_id(citizen_id)
	if citizen.is_empty():
		return

	citizens_list.set_item_text(item_index, _format_citizen_list_item(citizen))


func _format_citizen_list_item(citizen: Dictionary) -> String:
	var job: StringName = citizen.get("job", &"unassigned")
	return "#%d %s — %s" % [
		int(citizen["id"]),
		String(citizen["name"]),
		_get_job_display_name(job),
	]


func _get_job_display_name(job: StringName) -> String:
	return String(JOB_DISPLAY_NAMES.get(job, String(job)))


func _clear_details() -> void:
	name_label.text = ""
	job_label.text = ""
	strength_label.text = ""
	intelligence_label.text = ""
	speed_label.text = ""
	loyalty_label.text = ""
	craftsmanship_label.text = ""
	assign_job_button.disabled = true
