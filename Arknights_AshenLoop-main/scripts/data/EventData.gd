class_name EventData
extends Resource

@export var id: String
@export var title: String
@export_multiline var body: String
@export var tags: PackedStringArray = []
@export var options: Array[Dictionary] = []
@export var conditions: Array[String] = []
