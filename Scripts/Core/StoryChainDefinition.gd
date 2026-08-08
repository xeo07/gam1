extends RefCounted
class_name StoryChainDefinition

const CHAIN_IDS: Array[StringName] = [
	&"border_refugees",
	&"grain_blight",
	&"disputed_succession",
]
const EVENT_IDS: Dictionary = {
	&"border_refugees": &"chain_border_refugees",
	&"grain_blight": &"chain_grain_blight",
	&"disputed_succession": &"chain_disputed_succession",
}


static func build_order(world_seed: int) -> Array[StringName]:
	var order := CHAIN_IDS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51A7C0DE
	for index in range(order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: StringName = order[index]
		order[index] = order[swap_index]
		order[swap_index] = temporary
	return order


static func chain_from_event(event_id: StringName) -> StringName:
	for chain_id in EVENT_IDS:
		if EVENT_IDS[chain_id] == event_id:
			return chain_id
	return &""


static func get_warning(chain_id: StringName) -> Dictionary:
	match chain_id:
		&"border_refugees":
			return {
				"title": "Люди у северной заставы",
				"body": "Дозорные заметили семьи, бегущие от беспорядков за границей. Через несколько дней они достигнут наших ворот. Совет просит решить, как их встретить.",
				"choices": [
					_choice(&"shelter_refugees", "Приготовить убежища", "Выделить 6 еды и принять людей под защиту.", {"food": 6}, {"food": -6, "stability": 1}, "Пограничникам приказано готовить кров и припасы."),
					_choice(&"close_border", "Закрыть границу", "Сберечь припасы, но выставить дополнительные караулы.", {}, {"stability": -1}, "Ворота закрыты, а заставы переведены на усиленный режим."),
					_choice(&"escort_refugees", "Нанять проводников", "Потратить 4 золота и отвести людей в безопасные земли.", {"gold": 4}, {"gold": -4}, "К границе отправлены проводники и небольшая охрана."),
				],
			}
		&"grain_blight":
			return {
				"title": "Чёрные пятна на колосьях",
				"body": "Сельские старосты сообщают о болезни зерна. Урожай ещё можно спасти, но промедление сделает последствия тяжелее.",
				"choices": [
					_choice(&"buy_seed", "Купить здоровое зерно", "Потратить 5 золота на семена из дальних земель.", {"gold": 5}, {"gold": -5}, "Купцы отправлены за здоровым зерном."),
					_choice(&"ration_grain", "Ввести ранние пайки", "Сразу ограничить выдачу еды и удержать запасы.", {}, {"stability": -1}, "Совет объявил нормы расхода зерна."),
					_choice(&"ignore_blight", "Не поднимать тревогу", "Не тратить ресурсы и надеяться на хороший исход.", {}, {}, "Двор решил не вмешиваться до появления точных сведений."),
				],
			}
		&"disputed_succession":
			return {
				"title": "Спор за соседний престол",
				"body": "В соседней державе два наследника объявили себя законными правителями. Оба тайно ищут нашей поддержки.",
				"choices": [
					_choice(&"support_claimant", "Поддержать смелого наследника", "Потратить 6 золота на его сторонников.", {"gold": 6}, {"gold": -6, "stability": -1}, "Наши люди и золото тайно отправлены одному из претендентов."),
					_choice(&"stay_neutral", "Сохранить нейтралитет", "Не вмешиваться в чужой спор.", {}, {}, "Послам приказано не давать обещаний ни одной стороне."),
					_choice(&"mediate_succession", "Предложить посредничество", "Потратить 3 золота на съезд послов.", {"gold": 3}, {"gold": -3, "stability": 1}, "Столица готовится принять представителей обоих наследников."),
				],
			}
	return {}


static func get_development(chain_id: StringName, choice_id: StringName) -> Dictionary:
	var data := _branch(chain_id, choice_id)
	return {
		"title": String(data.get("development_title", "История продолжается")),
		"summary": String(data.get("development", "События продолжают развиваться.")),
	}


static func get_consequence(chain_id: StringName, choice_id: StringName) -> Dictionary:
	var data := _branch(chain_id, choice_id)
	return {
		"title": String(data.get("consequence_title", "Последствия решения")),
		"summary": String(data.get("consequence", "Стали известны последствия принятого решения.")),
		"effects": data.get("effects", {}).duplicate(true),
	}


static func _branch(chain_id: StringName, choice_id: StringName) -> Dictionary:
	var branches: Dictionary = {
		&"border_refugees": {
			&"shelter_refugees": _outcome("Беженцы приближаются", "К воротам пришло больше семей, чем ожидалось. Жители несут им одежду, а старосты освобождают пустующие дома.", "Новые семьи нашли дом", "Принятые семьи поселились в королевстве и помогли собрать поздний урожай. Милосердие укрепило доверие к власти.", {"food": 4, "stability": 3}),
			&"close_border": _outcome("Толпа у закрытых ворот", "Люди разбили лагерь перед заставой. Среди жителей королевства спорят, правильно ли оставлять их снаружи.", "Граница осталась закрытой", "Беженцы ушли дальше, но рассказы о закрытых воротах вызвали недовольство внутри страны.", {"stability": -3}),
			&"escort_refugees": _outcome("Опасная дорога", "Проводники вывели семьи из приграничных лесов, однако отряд столкнулся с разбойниками.", "Проводники вернулись", "Большинство людей добралось до безопасных земель. Благодарные купцы возместили часть расходов короны.", {"gold": 6, "stability": 1}),
		},
		&"grain_blight": {
			&"buy_seed": _outcome("Караваны задерживаются", "Дожди размыли дорогу, но купцы всё же везут здоровое зерно к нашим полям.", "Поля удалось пересеять", "Здоровые семена остановили болезнь. Урожай оказался меньше обычного, но голода удалось избежать.", {"food": 12, "stability": 2}),
			&"ration_grain": _outcome("Недовольство пайками", "На рынках стали длиннее очереди, зато государственные амбары пока не пустеют.", "Запасов хватило", "Строгие пайки помогли пережить неурожай. Жители устали от ограничений, но худшего не случилось.", {"food": 6, "stability": 0}),
			&"ignore_blight": _outcome("Болезнь охватила поля", "Сообщения из деревень подтвердили худшие опасения: заражённые колосья уже нельзя спасти.", "Урожай погиб", "Запоздалые меры не помогли. Рост цен и пустые амбары подорвали спокойствие в королевстве.", {"stability": -5}),
		},
		&"disputed_succession": {
			&"support_claimant": _outcome("Наш ставленник собирает силы", "Поддержанный нами наследник нанял отряд и занял несколько крепостей. Его соперник обещает отомстить покровителям.", "Претендент захватил столицу", "Смелая ставка принесла короне богатые дары, но участие в перевороте встревожило подданных.", {"gold": 10, "stability": -2}),
			&"stay_neutral": _outcome("Послы требуют ответа", "Обе стороны считают молчание двора скрытой поддержкой соперника и усиливают давление на наших купцов.", "Соседний спор затянулся", "Корона сохранила золото и солдат, однако долгий конфликт нарушил приграничную торговлю.", {"stability": -1}),
			&"mediate_succession": _outcome("Наследники прибыли на съезд", "Переговоры идут тяжело, но впервые представители двух сторон сидят за одним столом.", "Заключено соглашение о наследовании", "Посредничество остановило борьбу до большой войны. Авторитет короны заметно вырос.", {"gold": 4, "stability": 4}),
		},
	}
	var chain: Dictionary = branches.get(chain_id, {})
	return chain.get(choice_id, {})


static func _choice(
	choice_id: StringName,
	text: String,
	description: String,
	requirements: Dictionary,
	effects: Dictionary,
	result_text: String
) -> Dictionary:
	return {
		"choice_id": choice_id,
		"text": text,
		"description": description,
		"requirements": requirements.duplicate(true),
		"effects": effects.duplicate(true),
		"result_text": result_text,
	}


static func _outcome(
	development_title: String,
	development: String,
	consequence_title: String,
	consequence: String,
	effects: Dictionary
) -> Dictionary:
	return {
		"development_title": development_title,
		"development": development,
		"consequence_title": consequence_title,
		"consequence": consequence,
		"effects": effects.duplicate(true),
	}
