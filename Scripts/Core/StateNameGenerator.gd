extends RefCounted
class_name StateNameGenerator

const ADJECTIVES: Array[Dictionary] = [
	{"masculine": "Багровый", "feminine": "Багровая", "neuter": "Багровое"},
	{"masculine": "Белый", "feminine": "Белая", "neuter": "Белое"},
	{"masculine": "Бронзовый", "feminine": "Бронзовая", "neuter": "Бронзовое"},
	{"masculine": "Великий", "feminine": "Великая", "neuter": "Великое"},
	{"masculine": "Вольный", "feminine": "Вольная", "neuter": "Вольное"},
	{"masculine": "Восточный", "feminine": "Восточная", "neuter": "Восточное"},
	{"masculine": "Горный", "feminine": "Горная", "neuter": "Горное"},
	{"masculine": "Грозовой", "feminine": "Грозовая", "neuter": "Грозовое"},
	{"masculine": "Звёздный", "feminine": "Звёздная", "neuter": "Звёздное"},
	{"masculine": "Зелёный", "feminine": "Зелёная", "neuter": "Зелёное"},
	{"masculine": "Золотой", "feminine": "Золотая", "neuter": "Золотое"},
	{"masculine": "Каменный", "feminine": "Каменная", "neuter": "Каменное"},
	{"masculine": "Лазурный", "feminine": "Лазурная", "neuter": "Лазурное"},
	{"masculine": "Лесной", "feminine": "Лесная", "neuter": "Лесное"},
	{"masculine": "Лунный", "feminine": "Лунная", "neuter": "Лунное"},
	{"masculine": "Морской", "feminine": "Морская", "neuter": "Морское"},
	{"masculine": "Новый", "feminine": "Новая", "neuter": "Новое"},
	{"masculine": "Пепельный", "feminine": "Пепельная", "neuter": "Пепельное"},
	{"masculine": "Пограничный", "feminine": "Пограничная", "neuter": "Пограничное"},
	{"masculine": "Северный", "feminine": "Северная", "neuter": "Северное"},
	{"masculine": "Серебряный", "feminine": "Серебряная", "neuter": "Серебряное"},
	{"masculine": "Солнечный", "feminine": "Солнечная", "neuter": "Солнечное"},
	{"masculine": "Туманный", "feminine": "Туманная", "neuter": "Туманное"},
	{"masculine": "Чёрный", "feminine": "Чёрная", "neuter": "Чёрное"},
	{"masculine": "Янтарный", "feminine": "Янтарная", "neuter": "Янтарное"},
]

const NOUNS: Array[Dictionary] = [
	{"word": "Альянс", "gender": "masculine"},
	{"word": "Дом", "gender": "masculine"},
	{"word": "Клан", "gender": "masculine"},
	{"word": "Край", "gender": "masculine"},
	{"word": "Легион", "gender": "masculine"},
	{"word": "Орден", "gender": "masculine"},
	{"word": "Престол", "gender": "masculine"},
	{"word": "Союз", "gender": "masculine"},
	{"word": "Удел", "gender": "masculine"},
	{"word": "Держава", "gender": "feminine"},
	{"word": "Земля", "gender": "feminine"},
	{"word": "Империя", "gender": "feminine"},
	{"word": "Корона", "gender": "feminine"},
	{"word": "Лига", "gender": "feminine"},
	{"word": "Марка", "gender": "feminine"},
	{"word": "Община", "gender": "feminine"},
	{"word": "Республика", "gender": "feminine"},
	{"word": "Владение", "gender": "neuter"},
	{"word": "Герцогство", "gender": "neuter"},
	{"word": "Королевство", "gender": "neuter"},
	{"word": "Княжество", "gender": "neuter"},
	{"word": "Содружество", "gender": "neuter"},
	{"word": "Царство", "gender": "neuter"},
	{"word": "Наместничество", "gender": "neuter"},
	{"word": "Государство", "gender": "neuter"},
]


static func generate_unique_names(
	rng: RandomNumberGenerator,
	count: int
) -> Array[String]:
	var requested_count := clampi(count, 0, combination_count())
	var names: Array[String] = []
	var used: Dictionary = {}
	var attempts := 0
	var maximum_attempts := maxi(64, requested_count * 16)

	while names.size() < requested_count and attempts < maximum_attempts:
		var adjective_index := rng.randi_range(0, ADJECTIVES.size() - 1)
		var noun_index := rng.randi_range(0, NOUNS.size() - 1)
		var name := compose_name(adjective_index, noun_index)
		attempts += 1
		if used.has(name):
			continue
		used[name] = true
		names.append(name)

	if names.size() < requested_count:
		for adjective_index in ADJECTIVES.size():
			for noun_index in NOUNS.size():
				var name := compose_name(adjective_index, noun_index)
				if used.has(name):
					continue
				used[name] = true
				names.append(name)
				if names.size() == requested_count:
					return names

	return names


static func compose_name(adjective_index: int, noun_index: int) -> String:
	if adjective_index < 0 or adjective_index >= ADJECTIVES.size():
		return ""
	if noun_index < 0 or noun_index >= NOUNS.size():
		return ""
	var adjective: Dictionary = ADJECTIVES[adjective_index]
	var noun: Dictionary = NOUNS[noun_index]
	var gender := String(noun["gender"])
	return "%s %s" % [String(adjective[gender]), String(noun["word"])]


static func combination_count() -> int:
	return ADJECTIVES.size() * NOUNS.size()

