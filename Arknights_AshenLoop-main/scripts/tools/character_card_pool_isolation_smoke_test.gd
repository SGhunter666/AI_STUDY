extends SceneTree

func _initialize() -> void:
	print("CHARACTER_CARD_POOL_ISOLATION_SMOKE_TEST_START")
	var checked: int = 0
	for character_id in ["amiya", "exusiai", "nearl", "kaltsit"]:
		checked += _check_reward_pools(character_id)
		checked += _check_tag_pools(character_id)
		checked += _check_event_direct_card_effects(character_id)
	if not Util.get_card_reward_pool("exusiai").has("exusiai_cover_fire"):
		_fail("exusiai_cover_fire 属于能天使，但没有进入能天使奖励池。")
	print("CHARACTER_CARD_POOL_ISOLATION_SMOKE_TEST_OK checked=%d" % checked)
	quit(0)

func _check_reward_pools(character_id: String) -> int:
	var checked: int = 0
	var pools: Array[Array] = [
		Util.get_card_reward_pool(character_id),
		Util.get_normal_battle_reward_pool(character_id),
		Util.get_common_card_reward_pool(character_id),
		Util.get_uncommon_card_reward_pool(character_id),
		Util.get_rare_card_reward_pool(character_id)
	]
	for pool in pools:
		for card_id in pool:
			checked += 1
			if Util.default_starter_deck_for_character(character_id).has(String(card_id)):
				_fail("%s 奖励池混入初始牌：%s" % [character_id, String(card_id)])
			if not Util.is_card_available_to_character(String(card_id), character_id):
				_fail("%s 奖励池混入非本角色牌：%s" % [character_id, String(card_id)])
			var card: CardData = Util.load_card_db().get(String(card_id), null) as CardData
			if card == null:
				_fail("%s 奖励池混入未知牌：%s" % [character_id, String(card_id)])
			elif not Util.is_card_reward_eligible(card, character_id):
				_fail("%s 奖励池混入不可奖励牌：%s（%s）" % [character_id, String(card_id), card.rarity])
	if not _has_strict_module_charm_pool(character_id):
		return checked
	for module_id in Util.get_module_reward_pool(character_id):
		checked += 1
		if not Util.is_module_available_to_character(module_id, character_id):
			_fail("%s 模块池混入非本角色模块：%s" % [character_id, module_id])
	for charm_id in Util.get_charm_reward_pool(character_id):
		checked += 1
		if not Util.is_charm_available_to_character(charm_id, character_id):
			_fail("%s 护符池混入非本角色护符：%s" % [character_id, charm_id])
	return checked

func _check_tag_pools(character_id: String) -> int:
	var checked: int = 0
	var tag_sets: Array[Array] = [
		["Support"],
		["Shot"],
		["Mark"],
		["Arts"],
		["Resonance"],
		["AmmoGain", "Reload"]
	]
	for tags_any in tag_sets:
		var pool: Array[String] = Util.get_character_card_pool_by_tags(character_id, tags_any, false, false)
		for card_id in pool:
			checked += 1
			if not Util.is_card_available_to_character(card_id, character_id):
				_fail("%s 标签牌池 %s 混入非本角色牌：%s" % [character_id, str(tags_any), card_id])
			var card: CardData = Util.load_card_db().get(card_id, null) as CardData
			if card == null:
				_fail("%s 标签牌池 %s 混入未知牌：%s" % [character_id, str(tags_any), card_id])
			elif card.rarity in ["Basic", "Starter", "Curse", "Status"]:
				_fail("%s 标签牌池 %s 混入不可奖励牌：%s（%s）" % [character_id, str(tags_any), card_id, card.rarity])
	return checked

func _check_event_direct_card_effects(character_id: String) -> int:
	var checked: int = 0
	for entry in _read_event_direct_card_ids():
		var raw_card_id: String = String(entry.get("card_id", ""))
		if raw_card_id.is_empty():
			continue
		var normalized: Array[String] = Util.normalize_character_card_choices(
			[raw_card_id],
			character_id,
			1,
			2901 + checked,
			{}
		)
		checked += 1
		if normalized.is_empty():
			_fail("%s 事件 %s 的直接加牌无法找到安全替换：%s" % [character_id, String(entry.get("event", "")), raw_card_id])
		for card_id in normalized:
			if not Util.is_card_available_to_character(card_id, character_id):
				_fail("%s 事件 %s 直接加牌替换后仍不安全：%s -> %s" % [character_id, String(entry.get("event", "")), raw_card_id, card_id])
			var card: CardData = Util.load_card_db().get(card_id, null) as CardData
			if card == null:
				_fail("%s 事件 %s 直接加牌替换到未知牌：%s -> %s" % [character_id, String(entry.get("event", "")), raw_card_id, card_id])
			elif card.rarity in ["Basic", "Starter", "Curse", "Status"]:
				_fail("%s 事件 %s 直接加牌替换到不可奖励牌：%s -> %s（%s）" % [character_id, String(entry.get("event", "")), raw_card_id, card_id, card.rarity])
	return checked

func _has_strict_module_charm_pool(character_id: String) -> bool:
	return character_id in ["amiya", "exusiai", "nearl"]

func _read_event_direct_card_ids() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open("res://data/events")
	if dir == null:
		_fail("无法打开事件目录。")
		return result
	var regex := RegEx.new()
	regex.compile("\"type\"\\s*:\\s*\"add_card(?:_reward)?\"\\s*,\\s*\"card_id\"\\s*:\\s*\"([^\"]+)\"")
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = "res://data/events/%s" % file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text: String = file.get_as_text()
				for match_result in regex.search_all(text):
					result.append({
						"event": file_name.trim_suffix(".tres"),
						"card_id": match_result.get_string(1)
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _fail(message: String) -> void:
	push_error(message)
	print("CHARACTER_CARD_POOL_ISOLATION_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
