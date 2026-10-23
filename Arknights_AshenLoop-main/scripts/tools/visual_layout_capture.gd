extends SceneTree

const OUTPUT_DIR := "res://tmp/visual_checks"

var run_manager: Node
var scene_router: Node

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush()
	quit(exit_code)

func _run() -> int:
	run_manager = root.get_node_or_null("RunManager")
	scene_router = root.get_node_or_null("SceneRouter")
	if run_manager == null:
		push_error("VISUAL_LAYOUT_CAPTURE_FAILED: missing RunManager")
		return 1
	if scene_router != null:
		scene_router.suppress_navigation = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame

	var single_player: Node = await _instantiate_scene("res://scenes/SinglePlayerScene.tscn")
	if single_player == null:
		return 1
	if single_player.has_method("_select_character"):
		single_player.call("_select_character", "kaltsit")
	await _settle_frames(40)
	await _capture("single_player_kaltsit.png")
	await _queue_free_and_flush(single_player)

	var kaltsit: CharacterData = Util.load_character("kaltsit", ResourceLoader.CACHE_MODE_IGNORE)
	if kaltsit == null:
		push_error("VISUAL_LAYOUT_CAPTURE_FAILED: missing kaltsit character")
		return 1
	run_manager.start_new_run(kaltsit, 9090)
	_prepare_battle_state()
	var battle_scene: Node = await _instantiate_scene("res://scenes/BattleScene.tscn")
	if battle_scene == null:
		return 1
	await _settle_frames(72)
	await _capture("battle_kaltsit_mon3tr.png")
	await _queue_free_and_flush(battle_scene)

	if scene_router != null:
		scene_router.suppress_navigation = false
	print("VISUAL_LAYOUT_CAPTURE_OK")
	print(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("single_player_kaltsit.png")))
	print(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("battle_kaltsit_mon3tr.png")))
	return 0

func _instantiate_scene(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("VISUAL_LAYOUT_CAPTURE_FAILED: cannot load %s" % path)
		return null
	var node: Node = packed.instantiate()
	if node == null:
		push_error("VISUAL_LAYOUT_CAPTURE_FAILED: cannot instantiate %s" % path)
		return null
	root.add_child(node)
	await process_frame
	await process_frame
	return node

func _prepare_battle_state() -> void:
	var battle_node: MapNodeModel = MapNodeModel.new()
	battle_node.id = "visual_battle"
	battle_node.node_type = "battle"
	battle_node.floor_index = run_manager.current_floor
	battle_node.row = 0
	battle_node.lane = 0
	battle_node.index = 0
	battle_node.metadata = {
		"enemy_ids": ["acid_originium_slug", "originium_slug_alpha", "originium_slug"]
	}
	run_manager.current_node_id = battle_node.id
	var test_nodes: Array[MapNodeModel] = [battle_node]
	run_manager.map_nodes = test_nodes

func _capture(file_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_DIR.path_join(file_name))

func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _queue_free_and_flush(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		await process_frame
		return
	node.queue_free()
	await node.tree_exited
	await process_frame
	await process_frame

func _flush() -> void:
	await process_frame
	await process_frame
