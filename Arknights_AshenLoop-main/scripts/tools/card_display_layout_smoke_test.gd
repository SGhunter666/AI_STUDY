extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	var card_db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var card_display_factory: GDScript = load("res://scripts/ui/card_display_factory.gd") as GDScript
	if card_display_factory == null:
		_fail("无法加载卡牌显示工厂。")
		return 1
	var root_control := Control.new()
	root_control.size = Vector2(1920, 1080)
	root.add_child(root_control)
	var checked: int = 0
	for card_id in card_db.keys():
		var card: CardData = card_db[card_id] as CardData
		if card == null:
			continue
		var description: String = String(card.description)
		if description.strip_edges().length() < 28:
			continue
		var button: Button = card_display_factory.create_card_button(
			card,
			String(card.display_name),
			description,
			card.cost,
			Util.load_card_art(card.id),
			card_display_factory.reward_card_size(),
			true,
			card_display_factory.has_upgrade_visual(card)
		)
		button.position = Vector2(96 + (checked % 6) * 252, 96 + int(checked / 6) * 400)
		root_control.add_child(button)
		checked += 1
		if checked % 18 == 0:
			await process_frame
			_check_visible_descriptions(root_control)
			_clear_children(root_control)
	await process_frame
	_check_visible_descriptions(root_control)
	_clear_children(root_control)
	_check_tooltip_terms(card_db, card_display_factory)
	root_control.free()
	if failures.is_empty():
		print("CARD_DISPLAY_LAYOUT_SMOKE_TEST_OK checked=%d" % checked)
		return 0
	push_error("CARD_DISPLAY_LAYOUT_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _check_visible_descriptions(parent: Node) -> void:
	for child in parent.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var desc_label: Label = _find_label(button, "CardDescription")
		if desc_label == null:
			_fail("卡牌 %s 缺少描述 Label。" % button.tooltip_text.get_slice("\n", 0))
			continue
		var line_count: int = desc_label.get_line_count()
		var visible_line_count: int = desc_label.get_visible_line_count()
		if visible_line_count <= 0:
			_fail("卡牌 %s 的描述区域没有可见行。" % button.tooltip_text.get_slice("\n", 0))
			continue
		if line_count > visible_line_count:
			_fail("卡牌 %s 描述被裁切：需要 %d 行，可见 %d 行。" % [button.tooltip_text.get_slice("\n", 0), line_count, visible_line_count])

func _find_label(node: Node, target_name: String) -> Label:
	if node.name == target_name and node is Label:
		return node as Label
	for child in node.get_children():
		var found: Label = _find_label(child, target_name)
		if found != null:
			return found
	return null

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()

func _check_tooltip_terms(card_db: Dictionary, card_display_factory: GDScript) -> void:
	_check_one_tooltip(card_db, card_display_factory, "ex_b01_burst_shot", ["所属：能天使", "核心术语：射击", "射击：", "弹药："])
	_check_one_tooltip(card_db, card_display_factory, "resonance_mark", ["所属：阿米娅", "核心术语：意志", "共振："])

func _check_one_tooltip(card_db: Dictionary, card_display_factory: GDScript, card_id: String, expected_fragments: Array[String]) -> void:
	if not card_db.has(card_id):
		_fail("缺少用于 tooltip 回归的卡牌：%s" % card_id)
		return
	var card: CardData = card_db[card_id] as CardData
	var button: Button = card_display_factory.create_card_button(
		card,
		String(card.display_name),
		String(card.description),
		card.cost,
		Util.load_card_art(card.id),
		card_display_factory.reward_card_size(),
		true,
		card_display_factory.has_upgrade_visual(card)
	)
	for fragment in expected_fragments:
		if not button.tooltip_text.contains(fragment):
			_fail("卡牌 %s 的 tooltip 缺少：%s" % [card_id, fragment])
	button.free()

func _flush_teardown() -> void:
	for _i in range(4):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
