extends RefCounted
class_name WorldGenerator

const AI_STATE_IDS: Array[StringName] = [
	&"northrealm",
	&"suncoast",
	&"ironclan",
	&"state_04",
	&"state_05",
	&"state_06",
	&"state_07",
]

const RULER_TITLES: Array[String] = [
	"Князь",
	"Княгиня",
	"Король",
	"Королева",
	"Канцлер",
	"Воевода",
	"Наместник",
	"Правительница",
]

const RULER_NAMES: Array[String] = [
	"Адель",
	"Бран",
	"Велимир",
	"Грета",
	"Дарен",
	"Ида",
	"Кай",
	"Леона",
	"Мирра",
	"Оскар",
	"Рада",
	"Северин",
	"Теодор",
	"Элина",
]


static func generate_states(world_seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var names := StateNameGenerator.generate_unique_names(rng, AI_STATE_IDS.size())
	var states: Array[Dictionary] = []

	for index in AI_STATE_IDS.size():
		states.append(StateData.create(
			AI_STATE_IDS[index],
			names[index],
			_generate_ruler_name(rng),
			rng.randi_range(65, 135),
			rng.randi_range(25, 90),
			rng.randi_range(25, 90),
			rng.randi_range(45, 90),
			rng.randi_range(-25, 25)
		))

	return states


static func _generate_ruler_name(rng: RandomNumberGenerator) -> String:
	var title := RULER_TITLES[rng.randi_range(0, RULER_TITLES.size() - 1)]
	var ruler_name := RULER_NAMES[rng.randi_range(0, RULER_NAMES.size() - 1)]
	return "%s %s" % [title, ruler_name]

