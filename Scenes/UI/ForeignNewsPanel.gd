extends CanvasLayer
class_name ForeignNewsPanel

@onready var date_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DateLabel
@onready var news_list: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/NewsList
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var news_manager: NewsManager = $"../NewsManager" as NewsManager


func _ready() -> void:
	news_manager.weekly_edition_ready.connect(_on_weekly_edition_ready)
	close_button.pressed.connect(close_report)


func open_report(report: Dictionary) -> void:
	if report.is_empty():
		return

	_clear_news_list()
	date_label.text = "Выпуск №%d • события дней %d–%d" % [
		int(report.get("issue_number", 0)),
		int(report.get("first_day", 0)),
		int(report.get("last_day", 0)),
	]

	var articles: Array = report.get("articles", [])
	for article_value in articles:
		if article_value is Dictionary:
			_add_article(article_value)
	if articles.is_empty():
		_add_article({
			"title": "Неделя прошла спокойно",
			"body": "Значимых известий за эту неделю не поступило.",
			"day": int(report.get("last_day", 0)),
			"reliability": &"reported",
		})

	visible = true


func close_report() -> void:
	visible = false


func _on_weekly_edition_ready(report: Dictionary) -> void:
	open_report(report)


func _clear_news_list() -> void:
	for child in news_list.get_children():
		child.queue_free()


func _add_article(article: Dictionary) -> void:
	var article_panel := PanelContainer.new()
	var content := VBoxContainer.new()
	var title_label := Label.new()
	var source_label := Label.new()
	var details_label := Label.new()

	title_label.text = String(article.get("title", "Без заголовка"))
	title_label.theme_type_variation = &"TitleLabel"
	source_label.text = "День %d • %s" % [
		int(article.get("day", 0)),
		_reliability_text(StringName(article.get("reliability", &"reported"))),
	]
	details_label.text = String(article.get("body", "Подробности пока неизвестны."))
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	news_list.add_child(article_panel)
	article_panel.add_child(content)
	content.add_child(title_label)
	content.add_child(source_label)
	content.add_child(details_label)


func _reliability_text(reliability: StringName) -> String:
	match reliability:
		&"confirmed":
			return "подтверждено двором"
		&"rumor":
			return "непроверенный слух"
		_:
			return "сообщают гонцы"
