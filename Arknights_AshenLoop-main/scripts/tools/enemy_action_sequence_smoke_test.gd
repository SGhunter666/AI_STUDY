extends SceneTree

var failures: Array[String] = []
var RunManager: Node
var manager: BattleManager
var started_order: Array[String] = []
var resolved_order: Array[String] = []
var resolved_types: Array[String] = []

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		return _report()
	var char_data: CharacterData = Util.load_character("amiya")
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
		return _report()
	var enemy_db: Dictionary = Util.load_enemy_db()
	var scout: EnemyData = enemy_db.get("reunion_scout", null) as EnemyData
	var shield: EnemyData = enemy_db.get("riot_shieldbearer", null) as EnemyData
	var caster: EnemyData = enemy_db.get("reunion_caster", null) as EnemyData
	if scout == null or shield == null or caster == null:
		_fail("无法加载敌人资源用于队列测试。")
		return _report()

	RunManager.start_new_run(char_data, 20260422)
	manager = BattleManager.new()
	root.add_child(manager)
	manager.enemy_action_started.connect(_on_enemy_action_started)
	manager.enemy_action_resolved.connect(_on_enemy_action_resolved)
	manager.enemy_turn_sequence_finished.connect(_on_enemy_turn_sequence_finished)
	manager.configure(char_data, [scout, shield, caster])
	if manager.enemies.size() != 3:
		_fail("队列测试应生成 3 个敌人。")
		return await _finish()

	manager.enemies[0].intent = {"type": "attack", "value": 1, "label": "刺击"}
	manager.enemies[1].intent = {"type": "gain_block", "value": 3, "label": "防守"}
	manager.enemies[2].intent = {"type": "apply_debuff", "status": "weak", "value": 1, "label": "干扰"}
	manager.end_player_turn()
	await manager.enemy_turn_sequence_finished

	if started_order != ["reunion_scout", "riot_shieldbearer", "reunion_caster"]:
		_fail("敌人行动 started 顺序异常：%s" % str(started_order))
	if resolved_order != ["reunion_scout", "riot_shieldbearer", "reunion_caster"]:
		_fail("敌人行动 resolved 顺序异常：%s" % str(resolved_order))
	if resolved_types != ["attack", "gain_block", "apply_debuff"]:
		_fail("敌人行动类型回传异常：%s" % str(resolved_types))
	if manager.active_side != "player":
		_fail("敌人队列结束后应回到玩家回合。")
	if manager.player.hp >= manager.player.max_hp:
		_fail("攻击敌人的伤害没有正确结算到玩家。")
	if manager.enemies[1].block < 3:
		_fail("加盾敌人的护盾没有正确结算。")
	if int(manager.player.statuses.get("weak", 0)) < 1:
		_fail("上负面敌人的状态没有正确结算。")

	return await _finish()

func _finish() -> int:
	if manager != null:
		manager.queue_free()
		manager = null
	await process_frame
	if failures.is_empty():
		print("ENEMY_ACTION_SEQUENCE_SMOKE_TEST_OK")
		return 0
	return _report()

func _report() -> int:
	push_error("ENEMY_ACTION_SEQUENCE_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _on_enemy_action_started(enemy: UnitState, _intent: Dictionary) -> void:
	started_order.append(enemy.id)

func _on_enemy_action_resolved(enemy: UnitState, _intent: Dictionary, result: Dictionary) -> void:
	resolved_order.append(enemy.id)
	resolved_types.append(String(result.get("type", "")))

func _on_enemy_turn_sequence_finished() -> void:
	pass

func _fail(message: String) -> void:
	failures.append(message)
