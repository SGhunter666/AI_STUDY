extends SceneTree

const TUNE_LIBRARY = preload("res://scripts/core/tune_library.gd")

func _initialize() -> void:
	print("CHARACTER_TUNE_REWIRE_SMOKE_TEST_START")
	_check_character(
		"amiya",
		load("res://data/characters/amiya.tres") as CharacterData,
		[
			"resonance_apply_plus_one",
			"support_echo_seed",
			"will_arts_discount",
			"overload_guard_matrix",
			"channel_quickcast",
			"echo_guard_lattice",
		],
		[
			"ex_burst_entry_mag",
			"ex_support_shot_link",
			"ex_mark_trace_draw",
			"ex_reload_guard_screen",
			"ex_marked_shot_discount",
			"ex_first_refill_draw",
		],
		[
			"rewire_arts_bonus",
			"rewire_support_draw",
			"rewire_overload_minus_one",
		]
	)
	_check_character(
		"exusiai",
		load("res://data/characters/exusiai.tres") as CharacterData,
		[
			"ex_burst_entry_mag",
			"ex_support_shot_link",
			"ex_mark_trace_draw",
			"ex_reload_guard_screen",
			"ex_marked_shot_discount",
			"ex_first_refill_draw",
		],
		[
			"resonance_apply_plus_one",
			"support_echo_seed",
			"will_arts_discount",
			"overload_guard_matrix",
			"channel_quickcast",
			"echo_guard_lattice",
		],
		[
			"ex_rewire_first_shot_bonus",
			"ex_rewire_reload_draw",
			"ex_rewire_burst_ammo",
		]
	)
	print("CHARACTER_TUNE_REWIRE_SMOKE_TEST_OK")
	quit(0)

func _check_character(character_id: String, character_data: CharacterData, expected_tunes: Array[String], forbidden_tunes: Array[String], expected_rewires: Array[String]) -> void:
	if character_data == null:
		_fail("%s 角色资源加载失败。" % character_id)
	var available_tunes: Array[String] = TUNE_LIBRARY.available_tune_ids_for_character(character_id, [])
	if available_tunes.size() != expected_tunes.size():
		_fail("%s 调律数量异常：%d" % [character_id, available_tunes.size()])
	for tune_id in expected_tunes:
		if not available_tunes.has(tune_id):
			_fail("%s 缺少应有调律：%s" % [character_id, tune_id])
		_check_character_text(character_id, TUNE_LIBRARY.title(tune_id), "调律标题 %s" % tune_id)
		_check_character_text(character_id, TUNE_LIBRARY.short_text(tune_id), "调律短说明 %s" % tune_id)
		_check_character_text(character_id, TUNE_LIBRARY.description(tune_id), "调律描述 %s" % tune_id)
	for tune_id in forbidden_tunes:
		if available_tunes.has(tune_id):
			_fail("%s 混入了不该出现的调律：%s" % [character_id, tune_id])

	var offered_tunes: Array[String] = TUNE_LIBRARY.offer_tunes_for_character(character_id, 1337, 3, [])
	if offered_tunes.is_empty():
		_fail("%s 没有生成任何调律。" % character_id)
	for tune_id in offered_tunes:
		if not expected_tunes.has(tune_id):
			_fail("%s 生成了错误调律：%s" % [character_id, tune_id])

	var rewires: Array[Dictionary] = TUNE_LIBRARY.rewire_entries(character_id)
	if rewires.size() != expected_rewires.size():
		_fail("%s 重构数量异常：%d" % [character_id, rewires.size()])
	for rewire_entry in rewires:
		var rewire_id: String = String(rewire_entry.get("id", ""))
		if not expected_rewires.has(rewire_id):
			_fail("%s 生成了错误重构：%s" % [character_id, rewire_id])
		for field in ["title", "description", "done", "shop_title", "shop_desc", "shop_done"]:
			_check_character_text(character_id, String(rewire_entry.get(field, "")), "重构 %s.%s" % [rewire_id, field])

func _check_character_text(character_id: String, text: String, context: String) -> void:
	if character_id != "exusiai":
		return
	for forbidden in ["阿米娅", "Amiya", "意志", "术式", "共振", "Will", "Arts", "Resonance"]:
		if text.contains(forbidden):
			_fail("能天使%s混入阿米娅术语：%s" % [context, forbidden])

func _fail(message: String) -> void:
	push_error(message)
	print("CHARACTER_TUNE_REWIRE_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
