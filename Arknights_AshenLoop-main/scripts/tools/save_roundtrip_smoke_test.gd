extends SceneTree

var failures: Array[String] = []
var RunManager: Node
var SaveManager: Node

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	SaveManager = root.get_node_or_null("SaveManager")
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	if SaveManager == null:
		_fail("无法访问 SaveManager 自动加载。")
		return 1
	var original_profile: Dictionary = SaveManager.load_profile().duplicate(true)
	SaveManager.save_profile({})
	_test_profile_backup_fallback()

	var char_data: CharacterData = Util.load_character("nearl")
	if char_data == null:
		_fail("无法加载 Nearl 角色资源。")
		SaveManager.save_profile(original_profile)
		return 1

	RunManager.start_new_run(char_data, 6262)
	var original_deck_size: int = RunManager.deck.size()
	var first_reachable: String = RunManager.reachable_node_ids[0] if not RunManager.reachable_node_ids.is_empty() else ""
	if first_reachable.is_empty() or not RunManager.select_node(first_reachable):
		_fail("新行动应能选择第一个可达节点。")
	RunManager.set_pending_rewards({
		"type": "battle_reward",
		"gold": 31,
		"card_choices": ["nearl_c01_steady_cut", "nearl_c02_small_guard"],
		"picks_allowed": 1
	})
	var saved_before_load: Dictionary = RunManager.saved_run_summary()
	if saved_before_load.is_empty():
		_fail("创建行动后应写入 run_save。")

	RunManager.exit_flush_done = true
	RunManager.save_batch_depth = 3
	RunManager.save_snapshot_queued = true
	RunManager.character = null
	RunManager.current_floor = 0
	RunManager.current_node_id = ""
	RunManager.gold = -1
	RunManager.hp = -1
	RunManager.deck.clear()
	RunManager.pending_rewards.clear()

	if not RunManager.load_saved_run():
		_fail("应能从 run_save 读回行动。")
	else:
		if RunManager.character == null or RunManager.character.id != "nearl":
			_fail("读档后角色应恢复为 Nearl。")
		if RunManager.current_floor != 1:
			_fail("读档后楼层应恢复。")
		if RunManager.current_node_id != first_reachable:
			_fail("读档后当前节点选择应恢复。")
		if RunManager.deck.size() != original_deck_size:
			_fail("读档后牌组数量应恢复。")
		if RunManager.pending_rewards.is_empty():
			_fail("读档后未领取奖励应恢复。")
		if RunManager.exit_flush_done:
			_fail("读档应重置退出保存标记。")
		if RunManager.save_batch_depth != 0:
			_fail("读档应重置保存批处理深度。")
		if RunManager.save_snapshot_queued:
			_fail("读档应重置延迟保存标记。")

	RunManager.add_gold(7)
	var saved_after_gold: Dictionary = RunManager.saved_run_summary()
	if int(saved_after_gold.get("gold", 0)) != RunManager.gold:
		_fail("读档后的后续改动应继续写回存档。")

	_test_empty_deck_saved_run_repair(char_data)

	SaveManager.save_profile(original_profile)
	RunManager.abandon_run()
	SaveManager.save_profile(original_profile)

	if failures.is_empty():
		print("SAVE_ROUNDTRIP_SMOKE_TEST_OK")
		return 0
	push_error("SAVE_ROUNDTRIP_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _fail(message: String) -> void:
	failures.append(message)

func _test_profile_backup_fallback() -> void:
	SaveManager.save_profile({"backup_base": 1})
	SaveManager.save_profile({"backup_next": 2})
	var file: FileAccess = FileAccess.open("user://save_profile.json", FileAccess.WRITE)
	if file == null:
		_fail("无法写入损坏存档测试文件。")
		return
	file.store_string("{broken")
	file.close()
	var recovered: Dictionary = SaveManager.load_profile()
	if int(recovered.get("backup_base", 0)) != 1:
		_fail("主存档损坏时应回退到上一份备份。")
	SaveManager.save_profile({})
	var cleared: Dictionary = SaveManager.load_profile()
	if not cleared.is_empty():
		_fail("保存空 Profile 时不应错误读回旧备份。")

func _test_empty_deck_saved_run_repair(char_data: CharacterData) -> void:
	if char_data == null:
		return
	RunManager.start_new_run(char_data, 7373)
	var save_data: Dictionary = RunManager.saved_run_summary().duplicate(true)
	save_data["deck"] = []
	SaveManager.update_profile({"run_save": save_data})
	RunManager.exit_flush_done = true
	RunManager.character = null
	RunManager.deck.clear()
	if not RunManager.load_saved_run():
		_fail("空牌组旧存档应仍能读取。")
		return
	if RunManager.deck.size() != char_data.starter_deck.size():
		_fail("空牌组旧存档读档后应恢复角色初始牌组，实际 %d，期望 %d。" % [RunManager.deck.size(), char_data.starter_deck.size()])
