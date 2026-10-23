extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	_check_card_pool()
	_check_character_pools()
	_check_branching_map()
	_check_w_three_phase()
	if failures.is_empty():
		print("FEATURE_PROGRESS_SMOKE_TEST_OK")
		return 0
	push_error("FEATURE_PROGRESS_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _check_card_pool() -> void:
	var card_db: Dictionary = Util.load_card_db()
	if card_db.size() < 40:
		_fail("卡牌资源不足 40 张，当前只有 %d 张。" % card_db.size())

func _check_character_pools() -> void:
	var character_db: Dictionary = Util.load_character_db()
	var required_ids: Array[String] = ["amiya", "nearl", "exusiai", "kaltsit"]
	for character_id in required_ids:
		var character_data: CharacterData = character_db.get(character_id, null) as CharacterData
		if character_data == null:
			_fail("缺少角色资源：%s" % character_id)
			continue
		if character_data.starter_deck.size() < 10:
			_fail("%s 的起始牌组少于 10 张。" % character_id)
		if character_data.passive_id.is_empty():
			_fail("%s 缺少被动标识。" % character_id)

func _check_branching_map() -> void:
	var floor_nodes: Array[MapNodeModel] = MapGenerator.new(424242).generate_floor(2)
	var multi_branch_count: int = 0
	var rows: Dictionary = {}
	for node_variant in floor_nodes:
		var node: MapNodeModel = node_variant
		if node.next_ids.size() > 1:
			multi_branch_count += 1
		rows[node.row] = int(rows.get(node.row, 0)) + 1
	if multi_branch_count == 0:
		_fail("地图没有生成任何分叉路线。")
	var multi_node_rows: int = 0
	for row_count in rows.values():
		if int(row_count) >= 2:
			multi_node_rows += 1
	if multi_node_rows < 3:
		_fail("地图多节点行数过少，看起来仍然不像真正分叉图。")

func _check_w_three_phase() -> void:
	var enemy_ai_source: String = ""
	var file := FileAccess.open("res://scripts/battle/EnemyAI.gd", FileAccess.READ)
	if file == null:
		_fail("无法读取 EnemyAI.gd。")
		return
	enemy_ai_source = file.get_as_text()
	if not enemy_ai_source.contains("_w_phase_one_intent"):
		_fail("EnemyAI 中缺少 W 第一阶段逻辑。")
	if not enemy_ai_source.contains("_w_phase_two_intent"):
		_fail("EnemyAI 中缺少 W 第二阶段逻辑。")
	if not enemy_ai_source.contains("_w_phase_three_intent"):
		_fail("EnemyAI 中缺少 W 第三阶段逻辑。")
	if not enemy_ai_source.contains("phase_three"):
		_fail("EnemyAI 中没有第三阶段标记。")

func _fail(message: String) -> void:
	failures.append(message)
