class_name RelicManager
extends RefCounted

static func has_relic(relic_id: String) -> bool:
	var run_manager: Node = _run_manager()
	return run_manager.has_relic(relic_id) if run_manager != null else false

static func active_relics() -> Array[String]:
	var result: Array[String] = []
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return result
	for module_id in run_manager.modules:
		result.append(module_id)
	for charm_id in run_manager.charms:
		result.append(charm_id)
	return result

static func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunManager") if tree != null else null
