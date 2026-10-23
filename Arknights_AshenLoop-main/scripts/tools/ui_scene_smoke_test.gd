extends SceneTree

var failures: Array[String] = []
var run_manager: Node
var scene_router: Node
var baseline_root_children: Dictionary = {}

func _initialize() -> void:
	run_manager = root.get_node_or_null("RunManager")
	scene_router = root.get_node_or_null("SceneRouter")
	for child in root.get_children():
		baseline_root_children[child.get_instance_id()] = true
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	if run_manager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	if scene_router == null:
		_fail("无法访问 SceneRouter 自动加载。")
		return 1
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
		return 1

	run_manager.start_new_run(char_data, 67890)

	await _instantiate_scene("res://scenes/MainMenu.tscn")
	await _instantiate_scene("res://scenes/SinglePlayerScene.tscn")
	await _instantiate_scene("res://scenes/SettingsScene.tscn")
	var encyclopedia_scene: Node = await _instantiate_scene_interactive("res://scenes/EncyclopediaScene.tscn")
	await _verify_encyclopedia_buttons(encyclopedia_scene)
	await _cleanup_scene(encyclopedia_scene)
	await _instantiate_scene("res://scenes/QuitScene.tscn")
	await _instantiate_scene("res://scenes/DefeatScene.tscn")

	await _prepare_victory_state()
	await _instantiate_scene("res://scenes/VictoryScene.tscn")

	await _prepare_map_state()
	var map_scene: Node = await _instantiate_scene_interactive("res://scenes/MapScene.tscn")
	await _verify_tune_overlay(map_scene, "地图场景")
	await _cleanup_scene(map_scene)

	await _prepare_battle_state()
	var battle_scene: Node = await _instantiate_scene_interactive("res://scenes/BattleScene.tscn")
	await create_timer(0.5).timeout
	await _verify_tune_overlay(battle_scene, "战斗场景")
	await _verify_battle_settings_overlay(battle_scene)
	await _verify_battle_enemy_layout(battle_scene)
	await _verify_actor_status_layout(battle_scene)
	await _verify_battle_top_hud_layout(battle_scene)
	await _cleanup_scene(battle_scene)

	await _prepare_event_state()
	await _instantiate_scene("res://scenes/EventScene.tscn")

	await _prepare_reward_state()
	await _instantiate_scene("res://scenes/RewardScene.tscn")

	await _prepare_shop_state()
	var shop_scene: Node = await _instantiate_scene_interactive("res://scenes/ShopScene.tscn")
	await _verify_shop_layout(shop_scene)
	await _cleanup_scene(shop_scene)

	await _prepare_rest_state()
	await _instantiate_scene("res://scenes/RestScene.tscn")

	if failures.is_empty():
		print("UI_SCENE_SMOKE_TEST_OK")
		return 0

	push_error("UI_SCENE_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _instantiate_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("无法加载场景：%s" % path)
		return
	var node: Node = packed.instantiate()
	if node == null:
		_fail("无法实例化场景：%s" % path)
		return
	root.add_child(node)
	await process_frame
	await process_frame
	await _queue_free_and_flush(node)

func _instantiate_scene_interactive(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("无法加载场景：%s" % path)
		return null
	var node: Node = packed.instantiate()
	if node == null:
		_fail("无法实例化场景：%s" % path)
		return null
	root.add_child(node)
	await process_frame
	await process_frame
	return node

func _cleanup_scene(node: Node) -> void:
	await _queue_free_and_flush(node)

func _verify_tune_overlay(scene_root: Node, scene_label: String) -> void:
	if scene_root == null:
		return
	var button: Button = scene_root.get_node_or_null("TopHUD/HudMargin/HudRow/TuneButton") as Button
	if button == null:
		_fail("%s缺少调律入口按钮。" % scene_label)
		return
	button.pressed.emit()
	await process_frame
	await process_frame
	var overlay: Node = scene_root.get_node_or_null("TuneSummaryOverlay")
	if overlay == null:
		_fail("%s点开调律入口后没有生成总览面板。" % scene_label)
		return
	await _queue_free_and_flush(overlay)

func _verify_battle_settings_overlay(scene_root: Node) -> void:
	if scene_root == null:
		return
	var battle_scene := scene_root as Control
	var settings_button: Button = battle_scene.get_node_or_null("SettingsButton") as Button
	if settings_button == null:
		_fail("战斗场景缺少设置按钮。")
		return
	var manager: BattleManager = battle_scene.get_node_or_null("BattleManager") as BattleManager
	var original_request: String = String(scene_router.get("last_requested_scene"))
	settings_button.emit_signal("pressed")
	await process_frame
	await process_frame
	await create_timer(0.24).timeout
	await process_frame
	var overlay: Control = battle_scene.get("settings_overlay") as Control
	if overlay == null:
		overlay = battle_scene.find_child("SettingsScene", true, false) as Control
	if overlay == null:
		_fail("战斗场景点击设置后没有打开覆盖层。")
		return
	if String(scene_router.get("last_requested_scene")) != original_request:
		_fail("战斗场景点击设置不应触发场景跳转。")
	if manager == null or manager.player == null or manager.enemies.is_empty():
		_fail("战斗设置覆盖层打开后，战斗状态被意外重置。")
	var back_button: Button = overlay.get_node_or_null("Margin/LeftPanel/LeftMargin/LeftBox/Footer/Back") as Button
	if back_button != null:
		back_button.pressed.emit()
		await process_frame
		await process_frame

func _verify_battle_enemy_layout(scene_root: Node) -> void:
	if scene_root == null:
		return
	var battle_manager: BattleManager = scene_root.get_node_or_null("BattleManager") as BattleManager
	var expected_count: int = battle_manager.enemies.size() if battle_manager != null else 0
	var actor_stage: Control = scene_root.get_node_or_null("Arena/EnemyActorStage") as Control
	if actor_stage == null:
		_fail("战斗场景缺少敌方立绘舞台。")
		return
	if expected_count < 3:
		_fail("战斗场景烟测没有拿到多敌人战，无法验证第三个敌人的布局。")
		return
	if actor_stage.get_child_count() != expected_count:
		_fail("战斗场景敌方立绘数量不正确，预期 %d，实际 %d。" % [expected_count, actor_stage.get_child_count()])
		return
	var stage_width: float = actor_stage.size.x
	for child in actor_stage.get_children():
		var actor_view: Control = child as Control
		if actor_view == null:
			continue
		var left: float = actor_view.position.x
		var right: float = actor_view.position.x + actor_view.size.x
		if left < -4.0 or right > stage_width + 4.0:
			_fail("战斗场景存在敌方立绘超出舞台范围，三敌布局异常。")
			return

func _verify_actor_status_layout(scene_root: Node) -> void:
	if scene_root == null:
		return
	var actor_stage: Control = scene_root.get_node_or_null("Arena/PlayerActorStage") as Control
	if actor_stage == null or actor_stage.get_child_count() <= 0:
		_fail("战斗场景缺少玩家立绘状态布局。")
		return
	var actor_view: Control = actor_stage.get_child(0) as Control
	if actor_view == null:
		_fail("战斗场景玩家立绘不是 Control。")
		return
	var status_strip: Control = actor_view.find_child("StatusStrip", true, false) as Control
	var hp_bar: Control = actor_view.find_child("HPBarBack", true, false) as Control
	var block_bar: Control = actor_view.find_child("BlockBarBack", true, false) as Control
	if status_strip == null or hp_bar == null or block_bar == null:
		_fail("战斗场景玩家立绘缺少状态条或血盾条。")
		return
	var status_rect: Rect2 = status_strip.get_global_rect()
	var hp_rect: Rect2 = hp_bar.get_global_rect()
	var block_rect: Rect2 = block_bar.get_global_rect()
	if status_rect.intersects(hp_rect) or status_rect.intersects(block_rect):
		_fail("战斗场景玩家 buff/debuff 状态条遮挡了生命或护盾条。")
		return

func _verify_battle_top_hud_layout(scene_root: Node) -> void:
	if scene_root == null:
		return
	var top_hud: Control = scene_root.get_node_or_null("TopHUD") as Control
	var settings_button: Control = scene_root.get_node_or_null("SettingsButton") as Control
	if top_hud == null or settings_button == null:
		_fail("战斗场景缺少顶部 HUD 或设置按钮。")
		return
	# 放弃战斗按钮已迁移至设置菜单的 game 分类，战斗场景不再直接持有 AbandonRunButton
	var battle_speed_button: Control = scene_root.get_node_or_null("BattleSpeedButton") as Control
	if battle_speed_button != null:
		# 确保倍速按钮不与设置按钮重叠
		if battle_speed_button.get_global_rect().intersects(settings_button.get_global_rect()):
			_fail("战斗场景倍速按钮遮挡了设置按钮。")
			return

func _verify_shop_layout(scene_root: Node) -> void:
	if scene_root == null:
		return
	var gold_label: Label = scene_root.get_node_or_null("Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/TopRow/GoldChip/GoldMargin/GoldLabel") as Label
	if gold_label == null:
		_fail("商店场景缺少固定金币显示。")
		return
	if gold_label.text.is_empty():
		_fail("商店场景金币显示为空。")
	var content_scroll: ScrollContainer = scene_root.get_node_or_null("Panel/Margin/VBox/ContentScroll") as ScrollContainer
	if content_scroll == null:
		_fail("商店场景缺少滚动商品区。")
		return
	var shop_list: VBoxContainer = scene_root.get_node_or_null("Panel/Margin/VBox/ContentScroll/ShopList") as VBoxContainer
	if shop_list == null or shop_list.get_child_count() <= 0:
		_fail("商店场景没有成功生成商品内容。")

func _verify_encyclopedia_buttons(scene_root: Node) -> void:
	if scene_root == null:
		return
	var button_paths: Array[String] = [
		"Margin/Scroll/Root/TopRow/CardsEntry",
		"Margin/Scroll/Root/TopRow/ModulesEntry",
		"Margin/Scroll/Root/TopRow/MonsterEntry"
	]
	for button_path in button_paths:
		var button: Button = scene_root.get_node_or_null(button_path) as Button
		if button == null:
			_fail("百科场景缺少入口按钮：%s" % button_path)
			return
		button.pressed.emit()
		await process_frame
		await process_frame
		var overlay: Node = _find_overlay_by_script(scene_root, "res://scripts/ui/card_gallery_overlay.gd")
		if overlay == null:
			overlay = _find_overlay_by_script(scene_root, "res://scripts/ui/compendium_overlay.gd")
		if overlay == null:
			_fail("百科入口按钮未能打开对应弹层：%s" % button_path)
			return
		if button_path.ends_with("CardsEntry"):
			_verify_card_gallery_grid(overlay)
		await _queue_free_and_flush(overlay)

func _find_overlay_by_script(scene_root: Node, script_path: String) -> Node:
	for child in scene_root.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path == script_path:
			return child
	return null

func _verify_card_gallery_grid(overlay: Node) -> void:
	var first_row: Node = _find_named_descendant(overlay, "CardsRow")
	if first_row == null:
		_fail("卡牌总览没有生成卡牌行。")
		return
	var card_count: int = 0
	for child in first_row.get_children():
		if child is Button:
			card_count += 1
	if card_count != 4:
		_fail("卡牌总览第一行应为 4 张卡，实际为 %d 张。" % card_count)

func _find_named_descendant(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named_descendant(child, target_name)
		if found != null:
			return found
	return null

func _queue_free_and_flush(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		await process_frame
		return
	node.queue_free()
	await node.tree_exited
	await process_frame
	await process_frame

func _flush_teardown() -> void:
	for child_variant in root.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		if baseline_root_children.has(child.get_instance_id()):
			continue
		await _queue_free_and_flush(child)
	await process_frame
	await process_frame

func _prepare_map_state() -> void:
	run_manager.current_node_id = ""
	run_manager.pending_rewards = {}
	run_manager.pending_interfloor_rest = false

func _prepare_battle_state() -> void:
	var battle_node: MapNodeModel = _find_or_build_node("battle")
	battle_node.metadata["enemy_ids"] = ["acid_originium_slug", "originium_slug_alpha", "originium_slug"]
	run_manager.current_node_id = battle_node.id
	var test_nodes: Array[MapNodeModel] = [battle_node]
	run_manager.map_nodes = test_nodes

func _prepare_event_state() -> void:
	var event_node: MapNodeModel = _find_or_build_node("event")
	run_manager.current_node_id = event_node.id
	var test_nodes: Array[MapNodeModel] = [event_node]
	run_manager.map_nodes = test_nodes

func _prepare_reward_state() -> void:
	run_manager.pending_rewards = {
		"type": "battle_reward",
		"text": "Smoke Test Reward",
		"module_id": "resonance_prism",
		"card_choices": ["focus_pulse", "emergency_shield", "signal_relay"],
		"summary_entries": [
			{
				"title": "加入卡组：心压",
				"body": "获得 2 点意志。\n本回合不能获得护盾。",
				"accent": Color(0.95, 0.84, 0.62, 0.9)
			}
		]
	}

func _prepare_shop_state() -> void:
	run_manager.current_node_id = _find_or_build_node("shop").id

func _prepare_rest_state() -> void:
	run_manager.current_node_id = _find_or_build_node("rest").id
	run_manager.pending_interfloor_rest = true

func _prepare_victory_state() -> void:
	run_manager.last_run_summary = {
		"floor": 3,
		"gold": 233,
		"deck_size": run_manager.deck.size(),
		"modules": run_manager.modules.size()
	}
	run_manager.set_flag("run_complete", true)

func _find_or_build_node(node_type: String) -> MapNodeModel:
	for node in run_manager.map_nodes:
		if node.node_type == node_type:
			return node
	var node: MapNodeModel = MapNodeModel.new()
	node.id = "smoke_%s" % node_type
	node.node_type = node_type
	node.floor_index = run_manager.current_floor
	node.row = 0
	node.lane = 0
	node.index = 0
	node.metadata = Util.generate_node_metadata(run_manager.current_floor, node_type, 0, RandomNumberGenerator.new())
	if node_type == "event":
		node.metadata["event_id"] = "temporary_ward"
	if node_type == "battle":
		node.metadata["enemy_ids"] = ["originium_slug", "originium_slug", "blazing_originium_slug"]
	return node

func _fail(message: String) -> void:
	failures.append(message)
