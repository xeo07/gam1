extends CanvasLayer
class_name ForeignNewsPanel

@onready var date_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DateLabel
@onready var news_list: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/NewsList
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager


func _ready() -> void:
	news_manager.foreign_news_ready.connect(_on_foreign_news_ready)
	close_button.pressed.connect(close_report)


func open_report(report: Dictionary) -> void:
	if report.is_empty():
		return

	_clear_news_list()
	date_label.text = "Дата: День %d, Месяц %d, Год %d" % [
		int(report.get("day", 0)),
		int(report.get("month", 0)),
		int(report.get("year", 0)),
	]

	var states: Array = report.get("states", [])
	for state_value in states:
		var state: Dictionary = state_value
		_add_state_news(state)

	visible = true


func close_report() -> void:
	visible = false


func _on_foreign_news_ready(report: Dictionary) -> void:
	open_report(report)


func _clear_news_list() -> void:
	for child in news_list.get_children():
		child.queue_free()


func _add_state_news(state: Dictionary) -> void:
	var state_panel := PanelContainer.new()
	var content := VBoxContainer.new()
	var name_label := Label.new()
	var details_label := Label.new()

	name_label.text = String(state.get("state_name", ""))
	details_label.text = (
		"Население: %d\n"
		+ "Военная сила: %d\n"
		+ "Богатство: %d\n"
		+ "Стабильность: %d\n\n"
		+ "%s"
	) % [
		int(state.get("population", 0)),
		int(state.get("military_strength", 0)),
		int(state.get("wealth", 0)),
		int(state.get("stability", 0)),
		String(state.get("summary", "")),
	]
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	news_list.add_child(state_panel)
	state_panel.add_child(content)
	content.add_child(name_label)
	content.add_child(details_label)
