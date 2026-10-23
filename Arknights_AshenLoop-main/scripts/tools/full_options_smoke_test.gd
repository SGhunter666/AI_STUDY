extends SceneTree

var failures: Array[String] = []
var missing_portraits: Array[String] = []
var char_data: CharacterData
var RunManager: Node
var LocalizationManager: Node

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	LocalizationManager = root.get_node_or_null("LocalizationManager")
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		_report()
		return 1
	if LocalizationManager == null:
		_fail("无法访问 LocalizationManager 自动加载。")
		_report()
		return 1
	char_data = Util.load_character("amiya")
	if char_data == null:
		_fail("无法加载 Amiya。")
		_report()
		return 1

	_check_data_counts()
	_check_event_options()
	await _check_shop_buttons()
	await _check_rest_buttons()
	await _check_reward_buttons()
	_check_enemy_portraits()

	if failures.is_empty():
		print("FULL_OPTIONS_SMOKE_TEST_OK")
		if missing_portraits.is_empty():
			print("MISSING_ENEMY_PORTRAITS: none")
		else:
			print("MISSING_ENEMY_PORTRAITS: %s" % ", ".join(missing_portraits))
		return 0

	_report()
	return 1

func _check_data_counts() -> void:
	if Util.load_card_db().size() < 109:
		_fail("卡牌数量低于预期。")
	if Util.load_module_db().size() < 16:
		_fail("模块数量低于 16。")
	if Util.load_charm_db().size() < 8:
		_fail("Charm 数量低于 8。")
	if Util.load_event_db().size() < 25:
		_fail("事件数量低于 20。")

func _check_event_options() -> void:
	var event_db: Dictionary = Util.load_event_db()
	var valid_effects := {
		"gain_gold": true,
		"add_gold": true,
		"lose_gold": true,
		"lose_hp": true,
		"heal": true,
		"heal_percent": true,
		"add_card": true,
		"add_card_reward": true,
		"remove_card": true,
		"remove_selected_card": true,
		"upgrade_random_card": true,
		"upgrade_selected_card": true,
		"add_module": true,
		"add_charm": true,
		"set_flag": true,
		"gain_story_flag": true,
		"apply_run_modifier": true
	}
	var runner: EventRunner = EventRunner.new()
	for event_id in event_db.keys():
		var event: EventData = event_db[event_id] as EventData
		if event == null:
			_fail("事件资源为空：%s" % event_id)
			continue
		if event.options.is_empty():
			_fail("事件没有选项：%s" % event.id)
		for option_index in range(event.options.size()):
			var option: Dictionary = event.options[option_index]
			if String(option.get("label", "")).is_empty():
				_fail("事件 %s 的第 %d 个选项没有文本。" % [event.id, option_index + 1])
			for effect in option.get("effects", []):
				var effect_type: String = String(effect.get("type", ""))
				if not valid_effects.has(effect_type):
					_fail("事件 %s 使用未知效果：%s" % [event.id, effect_type])
			_prepare_run()
			var summary_entries: Array[Dictionary] = runner.apply_event_option(option)
			for card_id in option.get("reward_cards", []):
				if not Util.load_card_db().has(String(card_id)):
					_fail("事件 %s 奖励了未知卡牌：%s" % [event.id, String(card_id)])
			if Array(option.get("reward_cards", [])).is_empty() and summary_entries.is_empty():
				_fail("事件 %s 的第 %d 个选项没有任何可见奖励摘要。" % [event.id, option_index + 1])

func _check_shop_buttons() -> void:
	var labels: Array[String] = await _collect_button_labels("res://scenes/ShopScene.tscn", true)
	if labels.is_empty():
		_fail("商店没有可测试按钮。")
		return
	for label in labels:
		if label == "Continue" or label == "继续" or label == "返回":
			continue
		await _press_scene_button("res://scenes/ShopScene.tscn", label)

func _check_rest_buttons() -> void:
	var labels: Array[String] = await _collect_rest_button_labels()
	if labels.is_empty():
		_fail("休整点没有服务按钮。")
		return
	for label in labels:
		await _press_scene_button("res://scenes/RestScene.tscn", label, "rest")

func _check_reward_buttons() -> void:
	_prepare_run()
	RunManager.pending_rewards = {
		"type": "battle_reward",
		"text": "Full option smoke reward",
		"card_choices": ["arts_bolt", "guard_pulse", "mental_tuning"],
		"picks_allowed": 2,
		"module_id": "recorder_of_resolve"
	}
	var packed: PackedScene = load("res://scenes/RewardScene.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var pressed_cards: int = 0
	while pressed_cards < 2:
		var buttons: Array[Button] = []
		_collect_buttons(node, buttons)
		var pressed_this_loop := false
		for button in buttons:
			if is_instance_valid(button) and not button.disabled and button.text != LocalizationManager.text("reward.skip") and button.text != LocalizationManager.text("reward.continue"):
				button.emit_signal("pressed")
				pressed_cards += 1
				pressed_this_loop = true
				await process_frame
				break
		if not pressed_this_loop:
			break
	if pressed_cards == 0:
		_fail("奖励页没有成功点击任何卡牌奖励。")
	await _queue_free_and_flush(node)

func _check_enemy_portraits() -> void:
	var enemy_db: Dictionary = Util.load_enemy_db()
	for enemy_id in enemy_db.keys():
		var enemy: EnemyData = enemy_db[enemy_id] as EnemyData
		if enemy == null:
			continue
		var portrait_path: String = _enemy_portrait_path(enemy.id)
		if portrait_path.is_empty():
			missing_portraits.append("%s（%s）" % [LocalizationManager.enemy_name(enemy.id, enemy.display_name), enemy.id])
			continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(portrait_path))
		if image == null or image.is_empty():
			missing_portraits.append("%s（%s）" % [LocalizationManager.enemy_name(enemy.id, enemy.display_name), enemy.id])

func _collect_button_labels(scene_path: String, prepare_shop: bool = false) -> Array[String]:
	_prepare_run()
	if prepare_shop:
		RunManager.gold = 999
		_set_current_node("shop")
	var packed: PackedScene = load(scene_path)
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var buttons: Array[Button] = []
	_collect_buttons(node, buttons)
	var labels: Array[String] = []
	for button in buttons:
		if not button.text.is_empty() and button.visible:
			labels.append(button.text)
	await _queue_free_and_flush(node)
	return labels

func _collect_rest_button_labels() -> Array[String]:
	_prepare_run()
	RunManager.pending_interfloor_rest = false
	_set_current_node("rest")
	var packed: PackedScene = load("res://scenes/RestScene.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var buttons: Array[Button] = []
	_collect_buttons(node, buttons)
	var labels: Array[String] = []
	for button in buttons:
		if button.text.is_empty():
			continue
		if button.text == LocalizationManager.text("reward.continue"):
			continue
		if button.text.begins_with("Recover") or button.text.begins_with("Upgrade") or button.text.begins_with("Tune") or button.text.begins_with("Rewire") or button.text.begins_with("Equip") or button.text.begins_with("恢复") or button.text.begins_with("升级") or button.text.begins_with("调律") or button.text.begins_with("重构") or button.text.begins_with("补入护符"):
			labels.append(button.text)
	await _queue_free_and_flush(node)
	return labels

func _press_scene_button(scene_path: String, label: String, node_type: String = "shop") -> void:
	_prepare_run()
	RunManager.gold = 999
	RunManager.pending_interfloor_rest = false
	_set_current_node(node_type)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_fail("无法加载场景：%s" % scene_path)
		return
	var node: Node = packed.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var buttons: Array[Button] = []
	_collect_buttons(node, buttons)
	var found := false
	for button in buttons:
		if button.text == label:
			found = true
			if button.disabled:
				_fail("按钮被禁用：%s" % label)
			else:
				button.emit_signal("pressed")
				await process_frame
			break
	if not found:
		_fail("找不到按钮：%s" % label)
	await _queue_free_and_flush(node)

func _collect_buttons(node: Node, result: Array[Button]) -> void:
	var button := node as Button
	if button != null:
		result.append(button)
	for child in node.get_children():
		_collect_buttons(child, result)

func _prepare_run() -> void:
	RunManager.start_new_run(char_data, 13579)
	RunManager.gold = 999
	RunManager.pending_rewards = {}
	RunManager.pending_interfloor_rest = false
	RunManager.clear_stale_node_selection()

func _set_current_node(node_type: String) -> void:
	var node := MapNodeModel.new()
	node.id = "full_options_%s" % node_type
	node.node_type = node_type
	node.floor_index = RunManager.current_floor
	node.row = 0
	node.lane = 0
	node.index = 0
	node.metadata = Util.generate_node_metadata(RunManager.current_floor, node_type, 0, RandomNumberGenerator.new())
	var test_nodes: Array[MapNodeModel] = [node]
	RunManager.map_nodes = test_nodes
	RunManager.current_node_id = node.id

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

func _enemy_portrait_path(enemy_id: String) -> String:
	var direct_path: String = "res://assets/enemy_portraits/%s.png" % enemy_id
	if FileAccess.file_exists(ProjectSettings.globalize_path(direct_path)):
		return direct_path
	match enemy_id:
		"reunion_scout":
			return "res://assets/enemy_portraits/reunion_scout.png"
		"reunion_caster":
			return "res://assets/enemy_portraits/reunion_caster.png"
		"riot_shieldbearer":
			return "res://assets/enemy_portraits/riot_shieldbearer.png"
		"crossbow_sniper":
			return "res://assets/enemy_portraits/crossbow_sniper.png"
		"field_captain":
			return "res://assets/enemy_portraits/field_captain.png"
		"originium_channeler":
			return "res://assets/enemy_portraits/originium_channeler.png"
		"scout_chief":
			return "res://assets/enemy_portraits/scout_chief.png"
		"lockdown_core":
			return "res://assets/enemy_portraits/lockdown_core.png"
		"w_boss":
			return "res://assets/enemy_portraits/w_boss.png"
		"ash_echo":
			return "res://assets/enemy_portraits/ash_echo.png"
	return ""

func _report() -> void:
	push_error("FULL_OPTIONS_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	if not missing_portraits.is_empty():
		print("MISSING_ENEMY_PORTRAITS: %s" % ", ".join(missing_portraits))

func _fail(message: String) -> void:
	failures.append(message)
