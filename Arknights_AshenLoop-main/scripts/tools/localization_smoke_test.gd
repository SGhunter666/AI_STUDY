extends SceneTree

# 本地化数据回归测试：验证 strings.json 加载、访问器输出与全分组 zh/en 完整性
# 用法：godot --headless --path . -s scripts/tools/localization_smoke_test.gd

var LocalizationManager: Node
var failures: Array[String] = []

func _initialize() -> void:
	LocalizationManager = root.get_node_or_null("LocalizationManager")
	call_deferred("_start")

func _fail(message: String) -> void:
	failures.append(message)
	print("LOCALIZATION_SMOKE_TEST_FAIL: ", message)

func _start() -> void:
	var code: int = await _run()
	if failures.is_empty():
		print("LOCALIZATION_SMOKE_TEST_OK")
	quit(code)

func _run() -> int:
	if LocalizationManager == null:
		_fail("无法访问 LocalizationManager 自动加载。")
		return 1
	_check_dict_sizes()
	_check_accessor_outputs()
	_check_language_parity()
	_check_reverse_indices()
	_check_en_language()
	return 0 if failures.is_empty() else 1

func _check_dict_sizes() -> void:
	# 期望值为下限；内容持续扩充时只增不减
	var expectations: Dictionary = {
		"ui_text": 300,
		"card_text": 220,
		"node_type_names": 7,
		"floor_names": 4,
		"node_descriptions": 7,
		"module_text": 20,
		"charm_text": 8,
		"enemy_text": 40,
		"intent_labels": 100,
		"event_text": 21,
		"exusiai_event_text": 26,
		"exusiai_event_option_text": 126,
		"event_result_text": 126,
		"exusiai_event_result_text": 126,
		"tune_text": 18,
		"character_profiles": 4,
	}
	for dict_name in expectations.keys():
		var value: Variant = LocalizationManager.get(dict_name)
		if typeof(value) != TYPE_DICTIONARY:
			_fail("字典缺失或类型错误: %s" % dict_name)
			continue
		var minimum: int = int(expectations[dict_name])
		if (value as Dictionary).size() < minimum:
			_fail("字典条目不足: %s 只有 %d 条（预期至少 %d）" % [dict_name, (value as Dictionary).size(), minimum])

func _check_accessor_outputs() -> void:
	if LocalizationManager.text("main.title") != "明日方舟：灰烬回路":
		_fail("text(main.title) 输出错误: %s" % LocalizationManager.text("main.title"))
	if LocalizationManager.floor_name(1) != "失序街区":
		_fail("floor_name(1) 输出错误: %s" % LocalizationManager.floor_name(1))
	if LocalizationManager.floor_name(4) != "灰烬真相":
		_fail("floor_name(4) 输出错误: %s" % LocalizationManager.floor_name(4))
	if LocalizationManager.node_type_name("boss") != "首领战":
		_fail("node_type_name(boss) 输出错误: %s" % LocalizationManager.node_type_name("boss"))
	if LocalizationManager.character_name("amiya") != "阿米娅":
		_fail("character_name(amiya) 输出错误: %s" % LocalizationManager.character_name("amiya"))
	if not LocalizationManager.text("main.save_slot", ["阿米娅", 2, 60, 72]).begins_with("存档1 | 阿米娅"):
		_fail("text 带格式化参数输出错误: %s" % LocalizationManager.text("main.save_slot", ["阿米娅", 2, 60, 72]))

func _check_language_parity() -> void:
	# 所有面向玩家的分组都必须同时提供 zh/en，防止以后加内容漏翻
	var group_fields: Dictionary = {
		"ui_text": ["zh", "en"],
		"card_text": ["zh_name", "en_name", "zh_desc", "en_desc"],
		"module_text": ["zh_name", "en_name", "zh_desc", "en_desc"],
		"charm_text": ["zh_name", "en_name", "zh_desc", "en_desc"],
		"enemy_text": ["zh_name", "en_name"],
		"event_text": ["zh_title", "en_title", "zh_body", "en_body"],
		"exusiai_event_text": ["zh_title", "en_title", "zh_body", "en_body"],
		"tune_text": ["zh_title", "en_title"],
	}
	for group_name in group_fields.keys():
		var group: Variant = LocalizationManager.get(group_name)
		if typeof(group) != TYPE_DICTIONARY:
			_fail("分组缺失: %s" % group_name)
			continue
		var fields: Array = group_fields[group_name]
		var missing: int = 0
		for key in (group as Dictionary).keys():
			var entry: Dictionary = (group as Dictionary)[key]
			for field in fields:
				if not entry.has(field) or String(entry.get(field, "")).strip_edges().is_empty():
					missing += 1
					if missing <= 3:
						_fail("%s[%s] 缺少字段 %s" % [group_name, key, field])
					break
		if missing > 3:
			_fail("%s 共 %d 条缺字段" % [group_name, missing])

func _check_reverse_indices() -> void:
	# 反查索引：intent_label / event_option_label / event_result 按中文原文命中英文
	var intent_labels: Dictionary = LocalizationManager.intent_labels
	var probe_intent: String = ""
	for key in intent_labels.keys():
		var entry: Dictionary = intent_labels[key]
		var zh_value: String = String(entry.get("zh", ""))
		if not zh_value.is_empty():
			probe_intent = zh_value
			break
	if probe_intent.is_empty():
		_fail("intent_labels 中找不到带 zh 的条目")
	else:
		LocalizationManager.current_language = "en"
		var resolved: String = LocalizationManager.intent_label(probe_intent)
		if resolved == probe_intent or resolved.is_empty():
			_fail("intent_label 反查失败: %s -> %s" % [probe_intent, resolved])
		LocalizationManager.current_language = "zh"
	var option_table: Dictionary = LocalizationManager.exusiai_event_option_text
	var probe_option: String = ""
	for key in option_table.keys():
		probe_option = String(option_table[key])
		break
	if probe_option.is_empty():
		_fail("exusiai_event_option_text 为空")
	else:
		LocalizationManager.current_language = "en"
		var resolved_option: String = LocalizationManager.event_option_label("", probe_option)
		if resolved_option == probe_option:
			_fail("event_option_label 反查失败: %s" % probe_option)
		LocalizationManager.current_language = "zh"
	# 调律访问器
	if LocalizationManager.tune_title("resonance_apply_plus_one", "") != "共振棱线":
		_fail("tune_title 输出错误: %s" % LocalizationManager.tune_title("resonance_apply_plus_one", ""))
	if LocalizationManager.tune_title("resonance_apply_plus_one", "").is_empty():
		_fail("tune_title 为空")

func _check_en_language() -> void:
	var original_language: String = LocalizationManager.current_language
	LocalizationManager.current_language = "en"
	var checks: Dictionary = {
		"main.title": "Arknights: Ashes Circuit",
		"node_type_name": "Boss",
	}
	if LocalizationManager.text("main.title") != checks["main.title"]:
		_fail("英文 text(main.title) 输出错误: %s" % LocalizationManager.text("main.title"))
	if LocalizationManager.node_type_name("boss") != checks["node_type_name"]:
		_fail("英文 node_type_name(boss) 输出错误: %s" % LocalizationManager.node_type_name("boss"))
	LocalizationManager.current_language = original_language
