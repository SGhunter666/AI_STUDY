class_name CardData
extends Resource

@export var id: String
@export var display_name: String
@export var cost: int = 1
@export var card_type: String = "Attack"
@export var tags: PackedStringArray = []
@export_multiline var description: String
@export var rarity: String = "Common"
@export var exhausts: bool = false
@export var innate: bool = false
@export var ethereal: bool = false
@export var upgraded_id: String = ""
@export var effects: Array[EffectData] = []
@export var conditional_effects: Array[EffectData] = []
