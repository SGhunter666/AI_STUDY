extends SceneTree

const OUTPUT_DIR := "res://tmp/visual_qa"

var run_manager: Node
var scene_router: Node

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_frames(4)
	quit(exit_code)

func _run() -> int:
	run_manager = root.get_node_or_null("RunManager")
	scene_router = root.get_node_or_null("SceneRouter")
	if run_manager == null:
		push_error("VISUAL_QA_CAPTURE_FAILED: missing RunManager")
		return 1
	if scene_router != null:
		scene_router.suppress_navigation = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var sizes: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(1920, 1200),
		Vector2i(2560, 1600),
		Vector2i(2048, 1332)
	]
	var display_profiles: Array[Dictionary] = [
		{"name": "windows150", "content_scale": 1.50},
		{"name": "macbook", "content_scale": 1.75}
	]
	for profile in display_profiles:
		root.content_scale_factor = float(profile.get("content_scale", 1.0))
		await _flush_frames(4)
		for size in sizes:
			DisplayServer.window_set_size(size)
			await _flush_frames(8)
			var slug: String = "%s_%s" % [String(profile.get("name", "display")), _size_slug(size)]
			await _capture_single_player(slug)
			await _capture_map(slug, size)
			await _capture_battle(slug, size)
			await _capture_settings(slug)
			await _capture_event(slug, size)
			await _capture_rest(slug, size, false)
			await _capture_rest(slug, size, true)
	var settings_manager: Node = root.get_node_or_null("SettingsManager")
	if settings_manager != null and settings_manager.has_method("get_ui_display_scale"):
		root.content_scale_factor = float(settings_manager.call("get_ui_display_scale"))

	if scene_router != null:
		scene_router.suppress_navigation = false
	print("VISUAL_QA_CAPTURE_OK")
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	return 0

func _capture_single_player(slug: String) -> void:
	var scene: Node = await _instantiate_scene("res://scenes/SinglePlayerScene.tscn")
	if scene == null:
		return
	if scene.has_method("_select_character"):
		scene.call("_select_character", "exusiai")
	await _flush_frames(36)
	_capture("single_player_%s.png" % slug)
	await _queue_free_and_flush(scene)

func _capture_map(slug: String, size: Vector2i) -> void:
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data != null:
		run_manager.start_new_run(char_data, 91000 + size.x + size.y)
	var scene: Node = await _instantiate_scene("res://scenes/MapScene.tscn")
	if scene == null:
		return
	await _flush_frames(50)
	_capture("map_%s.png" % slug)
	await _queue_free_and_flush(scene)

func _capture_battle(slug: String, size: Vector2i) -> void:
	var char_data: CharacterData = Util.load_character("exusiai")
	if char_data != null:
		run_manager.start_new_run(char_data, 92000 + size.x + size.y)
	_prepare_battle_node()
	var scene: Node = await _instantiate_scene("res://scenes/BattleScene.tscn")
	if scene == null:
		return
	await _flush_frames(28)
	_force_player_status_layout(scene)
	await _flush_frames(12)
	_capture("battle_status_%s.png" % slug)
	await _queue_free_and_flush(scene)

func _capture_settings(slug: String) -> void:
	var scene: Node = await _instantiate_scene("res://scenes/SettingsScene.tscn")
	if scene == null:
		return
	await _flush_frames(30)
	_capture("settings_%s.png" % slug)
	await _queue_free_and_flush(scene)

func _capture_event(slug: String, size: Vector2i) -> void:
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data != null:
		run_manager.start_new_run(char_data, 93000 + size.x + size.y)
	_prepare_event_node()
	var scene: Node = await _instantiate_scene("res://scenes/EventScene.tscn")
	if scene == null:
		return
	await _flush_frames(36)
	_capture("event_%s.png" % slug)
	await _queue_free_and_flush(scene)

func _capture_rest(slug: String, size: Vector2i, interfloor: bool) -> void:
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data != null:
		run_manager.start_new_run(char_data, 94000 + size.x + size.y)
	_prepare_rest_node(interfloor)
	var scene: Node = await _instantiate_scene("res://scenes/RestScene.tscn")
	if scene == null:
		return
	await _flush_frames(36)
	var prefix := "rest_interfloor" if interfloor else "rest"
	_capture("%s_%s.png" % [prefix, slug])
	await _queue_free_and_flush(scene)

func _prepare_battle_node() -> void:
	var battle_node := MapNodeModel.new()
	battle_node.id = "visual_qa_battle"
	battle_node.node_type = "battle"
	battle_node.floor_index = int(run_manager.current_floor)
	battle_node.row = 0
	battle_node.lane = 0
	battle_node.index = 0
	battle_node.metadata = {
		"enemy_ids": ["acid_originium_slug", "originium_slug_alpha", "originium_slug"]
	}
	run_manager.current_node_id = battle_node.id
	var test_nodes: Array[MapNodeModel] = [battle_node]
	run_manager.map_nodes = test_nodes

func _prepare_event_node() -> void:
	var event_node := MapNodeModel.new()
	event_node.id = "visual_qa_event"
	event_node.node_type = "event"
	event_node.floor_index = int(run_manager.current_floor)
	event_node.row = 0
	event_node.lane = 0
	event_node.index = 0
	event_node.metadata = {
		"event_id": "temporary_ward"
	}
	run_manager.current_node_id = event_node.id
	var test_nodes: Array[MapNodeModel] = [event_node]
	run_manager.map_nodes = test_nodes

func _prepare_rest_node(interfloor: bool) -> void:
	var rest_node := MapNodeModel.new()
	rest_node.id = "visual_qa_rest"
	rest_node.node_type = "rest"
	rest_node.floor_index = int(run_manager.current_floor)
	rest_node.row = 0
	rest_node.lane = 0
	rest_node.index = 0
	rest_node.metadata = {}
	run_manager.current_node_id = rest_node.id
	run_manager.pending_interfloor_rest = interfloor
	var test_nodes: Array[MapNodeModel] = [rest_node]
	run_manager.map_nodes = test_nodes

func _force_player_status_layout(scene: Node) -> void:
	var manager: BattleManager = scene.get_node_or_null("BattleManager") as BattleManager
	if manager != null and manager.player != null:
		manager.player.block = 8
	var actor_stage: Control = scene.get_node_or_null("Arena/PlayerActorStage") as Control
	if actor_stage == null or actor_stage.get_child_count() <= 0:
		return
	var actor_view: CombatActorView = actor_stage.get_child(0) as CombatActorView
	if actor_view == null:
		return
	actor_view.update_stats(70, 70, 8)
	actor_view.update_statuses([
		{
			"kind": "buff",
			"icon": "6",
			"amount": "8",
			"tooltip": "视觉检查：状态条不应遮挡护盾。",
			"bg": Color(0.96, 0.98, 1.0, 0.92),
			"fg": Color(0.12, 0.16, 0.22, 1.0)
		},
		{
			"kind": "buff",
			"icon": "增",
			"amount": "",
			"tooltip": "视觉检查：多个状态仍需避开护盾。",
			"bg": Color(0.46, 0.92, 0.48, 0.92)
		}
	])

func _instantiate_scene(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("VISUAL_QA_CAPTURE_FAILED: cannot load %s" % path)
		return null
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _flush_frames(4)
	return scene

func _capture(file_name: String) -> void:
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		push_error("VISUAL_QA_CAPTURE_FAILED: root texture unavailable")
		return
	var image: Image = texture.get_image()
	if image == null:
		push_error("VISUAL_QA_CAPTURE_FAILED: root image unavailable")
		return
	image.save_png(OUTPUT_DIR.path_join(file_name))

func _queue_free_and_flush(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		await _flush_frames(2)
		return
	node.queue_free()
	await node.tree_exited
	await _flush_frames(4)

func _flush_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _size_slug(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]
