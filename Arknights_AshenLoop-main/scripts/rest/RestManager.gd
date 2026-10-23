class_name RestManager
extends RefCounted

const TUNE_LIBRARY = preload("res://scripts/core/tune_library.gd")

func recover() -> void:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return
	run_manager.heal(int(ceil(float(run_manager.max_hp) * 0.3)))

func offered_tunes() -> Array[String]:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return []
	var active_node: MapNodeModel = run_manager.current_node()
	var node_hash: int = active_node.id.hash() if active_node != null else 0
	var seed_value: int = run_manager.rng_seed + run_manager.current_floor * 211 + run_manager.deck.size() * 13 + node_hash
	var character_id: String = run_manager.character.id if run_manager.character != null else ""
	return TUNE_LIBRARY.offer_tunes_for_character(character_id, seed_value, 3, run_manager.tunes)

func apply_tune(tune_id: String) -> bool:
	var run_manager: Node = _run_manager()
	return run_manager.add_tune(tune_id) if run_manager != null else false

func rewire(flag_id: String) -> void:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return
	run_manager.set_flag(flag_id, true)

func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunManager") if tree != null else null
