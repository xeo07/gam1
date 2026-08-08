extends CanvasLayer
class_name SpyReportPanel

const STATUS_DISPLAY_NAMES: Dictionary = {
	&"neutral": "Нейтральный",
	&"ally": "Союзник",
	&"enemy": "Враг",
	&"war": "В состоянии войны",
}

@onready var date_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DateLabel
@onready var state_name_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StateNameLabel
@onready var ruler_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RulerLabel
@onready var population_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PopulationLabel
@onready var military_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MilitaryLabel
@onready var wealth_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WealthLabel
@onready var stability_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StabilityLabel
@onready var relation_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RelationLabel
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var spy_manager: SpyManager = $"../SpyManager" as SpyManager
@onready var world_manager: WorldManager = $"../WorldManager" as WorldManager


func _ready() -> void:
	spy_manager.spy_report_ready.connect(_on_spy_report_ready)
	close_button.pressed.connect(close_report)


func open_report(report: Dictionary) -> void:
	var observed := world_manager.get_observed_state_by_id(report.get("state_id", &""))
	date_label.text = "Дата отчёта: День %d, Месяц %d, Год %d\n%s, %s" % [
		int(report.get("report_day", 0)),
		int(report.get("report_month", 0)),
		int(report.get("report_year", 0)),
		String(observed.get("source_text", "отчёт шпиона")),
		String(observed.get("freshness_text", "")),
	]
	state_name_label.text = "Государство: %s" % String(observed.get("name", ""))
	ruler_label.text = "Правитель: %s" % String(observed.get("ruler_text", "неизвестно"))
	population_label.text = "Население: %s" % String(observed.get("population_text", "неизвестно"))
	military_label.text = "Военная сила: %s" % String(observed.get("military_text", "неизвестно"))
	wealth_label.text = "Богатство: %s" % String(observed.get("wealth_text", "неизвестно"))
	stability_label.text = "Стабильность: %s" % String(observed.get("stability_text", "неизвестно"))
	relation_label.text = "Отношения: %s" % String(observed.get("relation_text", "неизвестно"))
	status_label.text = "Статус: %s" % String(observed.get("status_text", "неизвестно"))
	visible = true


func close_report() -> void:
	visible = false


func _on_spy_report_ready(report: Dictionary) -> void:
	open_report(report)
