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


func _ready() -> void:
	spy_manager.spy_report_ready.connect(_on_spy_report_ready)
	close_button.pressed.connect(close_report)


func open_report(report: Dictionary) -> void:
	date_label.text = "Дата отчёта: День %d, Месяц %d, Год %d" % [
		int(report.get("report_day", 0)),
		int(report.get("report_month", 0)),
		int(report.get("report_year", 0)),
	]
	state_name_label.text = "Государство: %s" % String(report.get("state_name", ""))
	ruler_label.text = "Правитель: %s" % String(report.get("ruler_name", ""))
	population_label.text = "Население: %d" % int(report.get("population", 0))
	military_label.text = "Военная сила: %d" % int(report.get("military_strength", 0))
	wealth_label.text = "Богатство: %d" % int(report.get("wealth", 0))
	stability_label.text = "Стабильность: %d" % int(report.get("stability", 0))
	relation_label.text = "Отношения: %d" % int(report.get("relation", 0))
	var status: StringName = report.get("status", &"neutral")
	status_label.text = "Статус: %s" % String(
		STATUS_DISPLAY_NAMES.get(status, String(status))
	)
	visible = true


func close_report() -> void:
	visible = false


func _on_spy_report_ready(report: Dictionary) -> void:
	open_report(report)
