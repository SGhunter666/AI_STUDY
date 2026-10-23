class_name EventManager
extends RefCounted

var runner: EventRunner = EventRunner.new()

func load_event(event_id: String) -> EventData:
	return Util.load_event_db().get(event_id, null) as EventData

func apply_choice(option: Dictionary) -> void:
	runner.apply_event_option(option)

