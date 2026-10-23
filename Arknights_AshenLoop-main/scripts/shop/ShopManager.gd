class_name ShopManager
extends RefCounted

func can_afford(price: int) -> bool:
	var run_manager: Node = _run_manager()
	return run_manager != null and run_manager.gold >= price

func buy_card(card_id: String, price: int) -> bool:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return false
	if not can_afford(price):
		return false
	run_manager.add_gold(-price)
	run_manager.add_card(card_id)
	return true

func buy_module(module_id: String, price: int) -> bool:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return false
	if not can_afford(price):
		return false
	run_manager.add_gold(-price)
	run_manager.add_module(module_id)
	return true

func buy_charm(charm_id: String, price: int) -> bool:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return false
	if not can_afford(price):
		return false
	run_manager.add_gold(-price)
	run_manager.add_charm(charm_id)
	return true

func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunManager") if tree != null else null
