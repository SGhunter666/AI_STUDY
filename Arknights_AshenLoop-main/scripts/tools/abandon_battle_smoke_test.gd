extends SceneTree

const BATTLE_MANAGER_SCRIPT := preload("res://scripts/battle/BattleManager.gd")

var failures: Array[String] = []
var RunManager: Node
var SceneRouter: Node
var SaveManager: Node

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	SceneRouter = root.get_node_or_null("SceneRouter")
	SaveManager = root.get_node_or_null("SaveManager")
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	if SceneRouter == null:
		_fail("无法访问 SceneRouter 自动加载。")
		return 1
	if SaveManager == null:
		_fail("无法访问 SaveManager 自动加载。")
		return 1
	var original_profile: Dictionary = SaveManager.load_profile().duplicate(true)
	SaveManager.save_profile({})
	SceneRouter.suppress_navigation = true
	SceneRouter.last_requested_scene = ""

	var char_data: CharacterData = Util.load_character("amiya")
	var enemy_db: Dictionary = Util.load_enemy_db()
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
		return _finish(original_profile, 1)
	if not enemy_db.has("reunion_scout"):
		_fail("无法加载测试敌人 reunion_scout。")
		return _finish(original_profile, 1)

	RunManager.start_new_run(char_data, 9191)
	var node: MapNodeModel = MapNodeModel.new()
	node.id = "abandon_battle_smoke_node"
	node.node_type = "battle"
	node.floor_index = 1
	node.metadata = {"enemy_ids": ["reunion_scout"]}
	var test_nodes: Array[MapNodeModel] = [node]
	RunManager.map_nodes = test_nodes
	RunManager.current_node_id = node.id
	RunManager.save_run_snapshot()
	if not RunManager.has_saved_run():
		_fail("测试开始前应存在当前行动存档。")

	var manager: BattleManager = BATTLE_MANAGER_SCRIPT.new()
	root.add_child(manager)
	manager.configure(char_data, [enemy_db["reunion_scout"] as EnemyData])
	await process_frame
	manager.abandon_battle()
	await process_frame

	if RunManager.has_active_run():
		_fail("放弃战斗后运行态应结束。")
	if SceneRouter.last_requested_scene != SceneRouter.DEFEAT_SCENE:
		_fail("放弃战斗后应进入失败结算页。")

	await _queue_free_and_flush(manager)
	return _finish(original_profile, 0 if failures.is_empty() else 1)

func _finish(original_profile: Dictionary, exit_code: int) -> int:
	SceneRouter.suppress_navigation = false
	SaveManager.save_profile(original_profile)
	RunManager.abandon_run()
	SaveManager.save_profile(original_profile)
	if failures.is_empty():
		print("ABANDON_BATTLE_SMOKE_TEST_OK")
	else:
		push_error("ABANDON_BATTLE_SMOKE_TEST_FAILED")
		for failure in failures:
			push_error(failure)
	return exit_code

func _fail(message: String) -> void:
	failures.append(message)

func _queue_free_and_flush(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		await process_frame
		return
	node.queue_free()
	await node.tree_exited
	await process_frame
	await process_frame

func _flush_teardown() -> void:
	await process_frame
	await process_frame
