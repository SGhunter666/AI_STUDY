class_name EnemyData
extends Resource

@export var id: String
@export var display_name: String
@export var max_hp: int = 40
@export var gold_reward: int = 15
@export var tags: PackedStringArray = []
@export var ai_profile: String = "basic"
@export var moves: Array[Dictionary] = []
