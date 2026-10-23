class_name ChannelManager
extends RefCounted

static func enqueue(unit: UnitState, entry: Dictionary) -> void:
	var queue: Array = unit.meta.get("channel_queue", [])
	queue.append(entry.duplicate(true))
	unit.meta["channel_queue"] = queue

static func clear(unit: UnitState) -> void:
	unit.meta["channel_queue"] = []

