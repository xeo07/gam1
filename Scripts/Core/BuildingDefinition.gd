class_name BuildingDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var texture: Texture2D
@export var size: Vector2i = Vector2i.ONE
@export var wood_cost: int
@export var stone_cost: int
@export var gold_cost: int
@export var population_capacity: int = 0
@export var worker_job: StringName = &""
@export var worker_capacity: int = 0
@export var daily_food_upkeep: int = 0
@export var daily_gold_upkeep: int = 0
