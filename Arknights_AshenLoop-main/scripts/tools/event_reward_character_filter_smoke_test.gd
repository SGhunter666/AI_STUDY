extends SceneTree

func _initialize() -> void:
	print("EVENT_REWARD_CHARACTER_FILTER_SMOKE_TEST_START")
	var checked_count: int = 0
	var reward_sets: Array[Dictionary] = _read_event_reward_card_sets()
	for character_id in ["amiya", "exusiai", "nearl", "kaltsit"]:
		for reward_set in reward_sets:
			if _record_for_other_character(reward_set, character_id):
				continue
			var raw_cards: Array = reward_set.get("cards", [])
			if raw_cards.is_empty():
				continue
			var filtered_cards: Array[String] = Util.normalize_character_card_choices(
				raw_cards,
				character_id,
				raw_cards.size(),
				1701 + checked_count,
				{}
			)
			checked_count += 1
			for card_id in filtered_cards:
				if not Util.is_card_available_to_character(card_id, character_id):
					_fail("%s 事件奖励混入了非本角色牌：%s -> %s" % [character_id, String(reward_set.get("event", "")), card_id])
				var card: CardData = Util.load_card_db().get(card_id, null) as CardData
				if card == null:
					_fail("%s 事件奖励混入未知牌：%s -> %s" % [character_id, String(reward_set.get("event", "")), card_id])
				elif card.rarity in ["Basic", "Starter", "Curse", "Status"]:
					_fail("%s 事件奖励混入不可奖励牌：%s -> %s（%s）" % [character_id, String(reward_set.get("event", "")), card_id, card.rarity])
	print("EVENT_REWARD_CHARACTER_FILTER_SMOKE_TEST_OK checked=%d" % checked_count)
	quit(0)

func _read_event_reward_card_sets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open("res://data/events")
	if dir == null:
		_fail("无法打开事件目录。")
		return result
	var regex := RegEx.new()
	regex.compile("\"reward_cards\": PackedStringArray\\(([^)]*)\\)")
	var character_tag_regex := RegEx.new()
	character_tag_regex.compile("\"(character:[^\"]+)\"")
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = "res://data/events/%s" % file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text: String = file.get_as_text()
				var tags: Array[String] = _all_matches(character_tag_regex, text)
				for match_result in regex.search_all(text):
					var cards: Array = []
					var raw: String = match_result.get_string(1)
					for part in raw.split(",", false):
						var card_id: String = String(part).strip_edges().trim_prefix("\"").trim_suffix("\"")
						if not card_id.is_empty():
							cards.append(card_id)
					result.append({"event": file_name.trim_suffix(".tres"), "cards": cards, "tags": tags})
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _all_matches(regex: RegEx, text: String) -> Array[String]:
	var values: Array[String] = []
	for match_result in regex.search_all(text):
		values.append(match_result.get_string(1))
	return values

func _record_for_other_character(record: Dictionary, character_id: String) -> bool:
	for tag_variant in Array(record.get("tags", [])):
		var tag_text: String = String(tag_variant)
		if tag_text.begins_with("character:"):
			return tag_text != "character:%s" % character_id
	return false

func _fail(message: String) -> void:
	push_error(message)
	print("EVENT_REWARD_CHARACTER_FILTER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
