extends CanvasLayer
class_name WarReportPanel

@onready var date_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DateLabel
@onready var state_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StateLabel
@onready var result_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResultLabel
@onready var strength_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StrengthLabel
@onready var sent_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SentLabel
@onready var casualties_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CasualtiesLabel
@onready var survivors_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SurvivorsLabel
@onready var gold_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GoldLabel
@onready var enemy_changes_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/EnemyChangesLabel
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var war_manager: WarManager = $"../WarManager" as WarManager


func _ready() -> void:
	war_manager.campaign_completed.connect(_on_campaign_completed)
	close_button.pressed.connect(close_report)


func open_report(report: Dictionary) -> void:
	date_label.text = "Дата: День %d, Месяц %d, Год %d" % [
		int(report.get("report_day", 0)),
		int(report.get("report_month", 0)),
		int(report.get("report_year", 0)),
	]
	state_label.text = "Противник: %s" % String(report.get("state_name", ""))
	result_label.text = "Результат: %s" % String(report.get("result_name", ""))
	strength_label.text = "Сила: %d против %d" % [
		int(report.get("player_strength", 0)),
		int(report.get("enemy_strength", 0)),
	]
	var sent_ids: Array = report.get("sent_citizen_ids", [])
	var casualty_ids: Array = report.get("casualty_ids", [])
	var survivor_ids: Array = report.get("survivor_ids", [])
	sent_label.text = "Отправлено бойцов: %d" % sent_ids.size()
	casualties_label.text = "Потери: %d" % casualty_ids.size()
	survivors_label.text = "Вернулось: %d" % survivor_ids.size()
	gold_label.text = "Золото: %s" % _format_signed(int(report.get("gold_change", 0)))
	enemy_changes_label.text = (
		"Изменения противника: армия %s, богатство %s, "
		+ "стабильность %s, население %s"
	) % [
		_format_signed(int(report.get("enemy_military_change", 0))),
		_format_signed(int(report.get("enemy_wealth_change", 0))),
		_format_signed(int(report.get("enemy_stability_change", 0))),
		_format_signed(int(report.get("enemy_population_change", 0))),
	]
	visible = true


func close_report() -> void:
	visible = false


func _on_campaign_completed(report: Dictionary) -> void:
	open_report(report)


func _format_signed(value: int) -> String:
	return "+%d" % value if value >= 0 else "%d" % value
