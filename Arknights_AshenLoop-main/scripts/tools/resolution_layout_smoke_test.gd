extends SceneTree

var run_manager: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await process_frame
	await process_frame
	quit(exit_code)

func _run() -> int:
	run_manager = root.get_node_or_null("RunManager")
	if run_manager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
		return 1

	var sizes: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(1920, 1200),
		Vector2i(2560, 1440),
		Vector2i(2560, 1600),
		Vector2i(2048, 1332)
	]
	for size in sizes:
		DisplayServer.window_set_size(size)
		await _settle_frames(6)
		var single_player_scene: Node = await _instantiate_scene("res://scenes/SinglePlayerScene.tscn")
		if single_player_scene == null:
			return 1
		await _settle_frames(20)
		_verify_single_player_bounds(single_player_scene, size)
		await _queue_free_and_flush(single_player_scene)

		run_manager.start_new_run(char_data, 88000 + size.x + size.y)
		var map_scene: Node = await _instantiate_scene("res://scenes/MapScene.tscn")
		if map_scene == null:
			return 1
		await _settle_frames(60)
		if map_scene.has_method("_reset_layout_visuals"):
			map_scene.call("_reset_layout_visuals")
			await _settle_frames(4)
		_verify_map_bounds(map_scene, size)
		await _verify_map_hover_does_not_jump(map_scene, size)
		await _queue_free_and_flush(map_scene)

	if failures.is_empty():
		print("RESOLUTION_LAYOUT_SMOKE_TEST_OK")
		return 0
	push_error("RESOLUTION_LAYOUT_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _instantiate_scene(path: String) -> Node:
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

func _verify_map_bounds(scene_root: Node, requested_size: Vector2i) -> void:
	var root_control: Control = scene_root as Control
	if root_control == null:
		_fail("地图场景不是 Control 根节点。")
		return
	var paths: Array[String] = [
		"TopHUD",
		"PaperFrame",
		"PaperFrame/PaperMargin/PaperContent/InfoPanel",
		"PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll"
	]
	for path in paths:
		var control: Control = root_control.get_node_or_null(path) as Control
		if control == null:
			_fail("地图场景缺少布局节点：%s。" % path)
			continue
		var parent_control: Control = control.get_parent() as Control
		if parent_control == null:
			continue
		var rect: Rect2 = control.get_rect()
		var parent_rect := Rect2(Vector2.ZERO, parent_control.size)
		if rect.position.x < -2.0 or rect.position.y < -2.0 or rect.end.x > parent_rect.end.x + 2.0 or rect.end.y > parent_rect.end.y + 2.0:
			_fail("地图场景 %s 在 %s 下超出父容器：%s，父容器 %s。" % [path, str(requested_size), str(rect), str(parent_rect)])

func _verify_single_player_bounds(scene_root: Node, requested_size: Vector2i) -> void:
	var info_panel: Control = scene_root.get_node_or_null("InfoPanel") as Control
	var portrait_strip: Control = scene_root.get_node_or_null("PortraitStrip") as Control
	var back_button: Control = scene_root.get_node_or_null("Back") as Control
	var start_button: Control = scene_root.get_node_or_null("StartGame") as Control
	if info_panel == null or portrait_strip == null or back_button == null or start_button == null:
		_fail("角色选择场景缺少关键布局节点。")
		return
	var info_rect: Rect2 = info_panel.get_global_rect()
	var strip_rect: Rect2 = portrait_strip.get_global_rect()
	var start_rect: Rect2 = start_button.get_global_rect()
	var back_rect: Rect2 = back_button.get_global_rect()
	if info_rect.intersects(strip_rect) or info_rect.intersects(start_rect) or info_rect.intersects(back_rect):
		_fail("角色选择场景在 %s 下说明面板和底部按钮重叠：info=%s strip=%s start=%s back=%s。" % [
			str(requested_size),
			str(info_rect),
			str(strip_rect),
			str(start_rect),
			str(back_rect)
		])

func _verify_map_hover_does_not_jump(scene_root: Node, size: Vector2i) -> void:
	var scroll: ScrollContainer = scene_root.get_node_or_null("PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll") as ScrollContainer
	if scroll == null:
		_fail("地图场景缺少滚动容器，无法验证 hover 滚动稳定性。")
		return
	var max_scroll: int = max(int(round(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)), 0)
	if max_scroll <= 0:
		var rows: Control = scene_root.get_node_or_null("PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll/MapCanvas/Rows") as Control
		if rows != null and rows.get_combined_minimum_size().y > scroll.size.y + 8.0:
			_fail("地图场景在 %s 下内容高度 %.1f 超过视口 %.1f，但滚动范围为 0。" % [
				str(size),
				rows.get_combined_minimum_size().y,
				scroll.size.y
			])
		return
	scroll.scroll_vertical = max_scroll / 2
	await _settle_frames(2)
	var before: int = scroll.scroll_vertical
	var buttons: Dictionary = scene_root.get("node_buttons")
	for button_variant in buttons.values():
		var button: Button = button_variant as Button
		if button == null:
			continue
		button.emit_signal("mouse_entered")
		await _settle_frames(3)
		var after: int = scroll.scroll_vertical
		if abs(after - before) > 8:
			_fail("地图场景在 %s 下 hover 节点导致滚动跳动：%d -> %d。" % [str(size), before, after])
		return

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

func _fail(message: String) -> void:
	failures.append(message)
