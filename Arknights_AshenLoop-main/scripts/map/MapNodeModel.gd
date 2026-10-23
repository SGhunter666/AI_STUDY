class_name MapNodeModel
extends RefCounted

var id: String = ""
var node_type: String = "battle"
var floor_index: int = 1
var index: int = 0
var row: int = 0
var lane: int = 0
var next_ids: Array[String] = []
var completed: bool = false
var metadata: Dictionary = {}
