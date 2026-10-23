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
		return _report()
	var enemy_db: Dictionary = Util.load_enemy_db()
	var w_data: EnemyData = enemy_db.get("w_boss", null) as EnemyData
	if w_data == null:
		_fail("无法加载 W 的敌人资源。")
		return _report()
	var ai: EnemyAI = EnemyAI.new(9001)
	var w_state := UnitState.new()
	w_state.id = w_data.id
	w_state.max_hp = w_data.max_hp
	w_state.hp = w_data.max_hp
	RunManager.story_flags.clear()
	var disguised_intent: Dictionary = ai.next_intent(w_state, w_data, 0)
	if String(disguised_intent.get("type", "")) != "apply_curse":
		_fail("W 第一阶段第一回合应是真实炸弹意图。")
	if String(disguised_intent.get("display_type", "")) != "attack":
		_fail("W 未解明时应显示伪装攻击意图。")
	w_state.hp = int(ceil(float(w_state.max_hp) * 0.5))
	var phase_two_intent: Dictionary = ai.next_intent(w_state, w_data, 1)
	if not bool(phase_two_intent.get("phase_two", false)):
		_fail("W 半血后应进入第二阶段。")
	if int(phase_two_intent.get("value", 0)) < 12:
		_fail("W 第二阶段攻击数值应明显提升。")
	w_state.hp = int(ceil(float(w_state.max_hp) * 0.25))
	var phase_three_intent: Dictionary = ai.next_intent(w_state, w_data, 3)
	if not bool(phase_three_intent.get("phase_three", false)):
		_fail("W 残血后应进入第三阶段。")
	if String(phase_three_intent.get("type", "")) == "attack" and int(phase_three_intent.get("value", 0)) < 14:
		_fail("W 第三阶段攻击数值应进一步提高。")
	RunManager.story_flags.clear()
	RunManager.set_flag("w_intents_clear", true)
	var revealed_intent: Dictionary = ai.next_intent(w_state, w_data, 0)
	if String(revealed_intent.get("display_type", "")) != String(revealed_intent.get("type", "")):
		_fail("获得 W 情报后，不应继续伪装意图。")
	if failures.is_empty():
		print("W_BOSS_SMOKE_TEST_OK")
		return 0
	return _report()

func _report() -> int:
	push_error("W_BOSS_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _fail(message: String) -> void:
	failures.append(message)
