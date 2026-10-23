extends SceneTree

var failures: Array[String] = []
var RunManager: Node

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
		return 1

	_test_floor_boss_mapping()
	_test_maps_have_rest_nodes(char_data)
	_test_interfloor_rest_and_victory_flow(char_data)
	_test_hidden_floor_flow(char_data)
	_test_charm_inventory_flow(char_data)

	if failures.is_empty():
		print("RUN_FLOW_SMOKE_TEST_OK")
		return 0

	push_error("RUN_FLOW_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _test_floor_boss_mapping() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value in range(20):
		rng.seed = seed_value
		var floor_one_bosses: Array[String] = Util.get_boss_enemies(1, rng)
		if floor_one_bosses.size() != 1 or not ["scout_chief", "reunion_assault_commander"].has(floor_one_bosses[0]):
			_fail("第 1 层 Boss 映射异常：%s" % str(floor_one_bosses))
		rng.seed = seed_value + 100
		var floor_two_bosses: Array[String] = Util.get_boss_enemies(2, rng)
		if floor_two_bosses.size() != 1 or not ["lockdown_core", "chernobog_suppression_convoy", "originium_aberration_cluster"].has(floor_two_bosses[0]):
			_fail("第 2 层 Boss 映射异常：%s" % str(floor_two_bosses))
	if Util.get_boss_enemies(3) != ["w_boss"]:
		_fail("第 3 层 Boss 应为 W。")
	if Util.get_boss_enemies(4) != ["ash_echo"]:
		_fail("第 4 层 Boss 应为灰烬回响。")

func _test_maps_have_rest_nodes(char_data: CharacterData) -> void:
	RunManager.start_new_run(char_data, 2222)
	var found_rest: bool = false
	for floor_index in [1, 2, 3]:
		RunManager.current_floor = floor_index
		RunManager._generate_floor_map(floor_index)
		for node in RunManager.map_nodes:
			if node.node_type == "rest":
				found_rest = true
				break
		if found_rest:
			break
	if not found_rest:
		_fail("前 3 层地图中应至少生成 1 个休整节点。")

func _test_interfloor_rest_and_victory_flow(char_data: CharacterData) -> void:
	RunManager.start_new_run(char_data, 3333)
	RunManager.current_floor = 1
	RunManager.pending_interfloor_rest = false
	RunManager.run_won = false
	RunManager.story_flags.erase("run_complete")
	RunManager._finish_floor()
	if RunManager.current_floor != 2:
		_fail("第 1 层结算后应进入第 2 层。")
	if not RunManager.should_take_interfloor_rest():
		_fail("第 1 层结算后应强制进入层间休整。")
	RunManager.hp = 12
	RunManager.heal_full()
	if RunManager.hp != RunManager.max_hp:
		_fail("层间休整应回满生命值。")
	RunManager.consume_interfloor_rest()
	if RunManager.should_take_interfloor_rest():
		_fail("层间休整消耗后不应继续保留。")

	RunManager.current_floor = 3
	RunManager.story_flags.clear()
	RunManager.pending_interfloor_rest = false
	RunManager.run_won = false
	RunManager._finish_floor()
	if not RunManager.has_flag("run_complete"):
		_fail("击败 W 且未进隐藏层时应直接标记通关。")
	if not RunManager.run_won:
		_fail("击败 W 后应标记为正式胜利。")

func _test_hidden_floor_flow(char_data: CharacterData) -> void:
	RunManager.start_new_run(char_data, 4444)
	RunManager.current_floor = 3
	RunManager.story_flags.clear()
	RunManager.story_flags["accept_burden_1"] = true
	RunManager.story_flags["accept_burden_2"] = true
	RunManager.pending_interfloor_rest = false
	RunManager.run_won = false
	RunManager._finish_floor()
	if RunManager.current_floor != 4:
		_fail("满足隐藏条件后，第 3 层结算应进入第 4 层。")
	if not RunManager.should_take_interfloor_rest():
		_fail("进入隐藏层前应先强制层间休整。")
	if not RunManager.run_won:
		_fail("进入隐藏层前也应保留已经击败 W 的正式胜利状态。")

func _test_charm_inventory_flow(char_data: CharacterData) -> void:
	RunManager.start_new_run(char_data, 5555)
	if RunManager.deck.count("mental_tuning") != 2:
		_fail("兔徽开局应只额外加入 1 张 Mental Tuning。")
	if RunManager.owned_charms.size() != char_data.starter_charms.size():
		_fail("起始 Charm 应同时进入拥有列表。")
	if RunManager.charms.size() != min(char_data.starter_charms.size(), RunManager.max_charm_slots()):
		_fail("起始 Charm 装备栏数量异常。")
	RunManager.add_charm("operators_thread", false)
	if not RunManager.is_charm_owned("operators_thread"):
		_fail("新获得的 Charm 应进入拥有列表。")
	if RunManager.is_charm_equipped("operators_thread"):
		_fail("未显式装备的 Charm 不应直接挤占装备栏。")
	if not RunManager.equip_charm("operators_thread"):
		_fail("已拥有的 Charm 应能被装备。")
	if not RunManager.is_charm_equipped("operators_thread"):
		_fail("装备后的 Charm 应进入生效列表。")

func _fail(message: String) -> void:
	failures.append(message)
