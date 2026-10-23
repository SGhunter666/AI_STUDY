class_name CharmData
extends Resource

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var slot_type: String = "charm"
@export var run_start_effects: Array[Dictionary] = []
