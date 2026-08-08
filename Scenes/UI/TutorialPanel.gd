extends CanvasLayer
class_name TutorialPanel

signal tutorial_closed(skipped: bool)

const STEPS: Array[Dictionary] = [
	{
		"title": "1. Ваше королевство",
		"body": "Слева находится земля королевства. Каждая клетка доступна для строительства. Кнопка ☰ теперь расположена над полем и не занимает клетку."
	},
	{
		"title": "2. Как построить здание",
		"body": "Нажмите «Жители» внизу, затем «Строительство». Выберите здание — окно закроется. После этого нажмите на свободную клетку поля."
	},
	{
		"title": "3. Ресурсы и жители",
		"body": "Справа внизу показаны еда, дерево, камень и золото. Строения тратят ресурсы, а жители нужны для работы и армии."
	},
	{
		"title": "4. Время и события",
		"body": "Кнопка «Новый день» двигает время вперёд. Следите за событиями и принимайте решения: они меняют ресурсы, стабильность и отношения."
	},
	{
		"title": "5. Мир вокруг",
		"body": "Откройте «Геополитика», чтобы изучать соседей, отправлять гонцов и шпионов. Сохранение и настройки находятся в меню ☰."
	},
]

@onready var title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var progress_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressLabel
@onready var body_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyLabel
@onready var primary_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/PrimaryButton
@onready var skip_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/SkipButton

var _step := -1


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	visible = false


func open_offer() -> void:
	_step = -1
	title_label.text = "Добро пожаловать в KINGDOOM"
	progress_label.text = "Короткое обучение займёт меньше минуты"
	body_label.text = "Хотите узнать основные действия или сразу начать править королевством?"
	primary_button.text = "Пройти обучение"
	skip_button.text = "Пропустить обучение"
	visible = true
	get_tree().paused = true
	primary_button.grab_focus()


func skip() -> void:
	_close(true)


func _on_primary_pressed() -> void:
	if _step < 0:
		_step = 0
	else:
		_step += 1
	if _step >= STEPS.size():
		_close(false)
		return
	_show_step()


func _on_skip_pressed() -> void:
	skip()


func _show_step() -> void:
	var data := STEPS[_step]
	title_label.text = String(data["title"])
	progress_label.text = "Шаг %d из %d" % [_step + 1, STEPS.size()]
	body_label.text = String(data["body"])
	primary_button.text = "Начать игру" if _step == STEPS.size() - 1 else "Далее"
	skip_button.text = "Пропустить"
	primary_button.grab_focus()


func _close(skipped: bool) -> void:
	visible = false
	get_tree().paused = false
	tutorial_closed.emit(skipped)
