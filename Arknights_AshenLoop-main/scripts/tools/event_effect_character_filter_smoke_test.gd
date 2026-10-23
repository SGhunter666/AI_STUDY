extends SceneTree

func _initialize() -> void:
	print("EVENT_EFFECT_CHARACTER_FILTER_SMOKE_TEST_START")
	var checked_effects: int = 0
	var event_db: Dictionary = Util.load_event_db()
	for character_id in ["amiya", "exusiai", "nearl", "kaltsit"]:
		for raw_event in event_db.values():
			var event_data: EventData = raw_event as EventData
			if event_data == null:
				continue
			if not _event_available_to_character(event_data, character_id):
				continue
			for option_index in range(event_data.options.size()):
				var option: Dictionary = event_data.options[option_index]
				var effects: Array = Array(_character_option_value(option, "effects", [], character_id))
				for effect_variant in effects:
					var effect: Dictionary = effect_variant as Dictionary
					checked_effects += 1
					_validate_effect(effect, character_id, event_data.id, option_index, checked_effects)
				var reward_cards: Array = Array(_character_option_value(option, "reward_cards", [], character_id))
				if reward_cards.is_empty():
					continue
				var filtered_cards: Array[String] = Util.normalize_character_card_choices(
					reward_cards,
					character_id,
					reward_cards.size(),
					2500 + checked_effects + option_index,
					{}
				)
				for card_id in filtered_cards:
					if not Util.is_card_available_to_character(card_id, character_id):
						_fail("%s 事件奖励混入了非本角色牌：%s[%d] -> %s" % [character_id, event_data.id, option_index, card_id])
					var card: CardData = Util.load_card_db().get(card_id, null) as CardData
					if card == null:
						_fail("%s 事件奖励混入未知牌：%s[%d] -> %s" % [character_id, event_data.id, option_index, card_id])
					elif card.rarity in ["Basic", "Starter", "Curse", "Status"]:
						_fail("%s 事件奖励混入不可奖励牌：%s[%d] -> %s（%s）" % [character_id, event_data.id, option_index, card_id, card.rarity])
	print("EVENT_EFFECT_CHARACTER_FILTER_SMOKE_TEST_OK checked=%d" % checked_effects)
	quit(0)

func _validate_effect(effect: Dictionary, character_id: String, event_id: String, option_index: int, seed_offset: int) -> void:
	var effect_type: String = String(effect.get("type", ""))
	match effect_type:
		"add_card", "add_card_reward", "remove_card":
			var card_id: String = String(effect.get("card_id", ""))
			if card_id.is_empty():
				return
			var safe_cards: Array[String] = Util.normalize_character_card_choices([card_id], character_id, 1, 3100 + seed_offset, {})
			if safe_cards.is_empty() or not Util.is_card_available_to_character(safe_cards[0], character_id):
				_fail("%s 事件效果混入了非本角色牌：%s[%d] -> %s" % [character_id, event_id, option_index, card_id])
		"add_module":
			var module_id: String = String(effect.get("module_id", ""))
			if module_id.is_empty():
				return
			var safe_modules: Array[String] = Util.normalize_character_module_choices([module_id], character_id, 1, 4100 + seed_offset)
			if safe_modules.is_empty() or not Util.is_module_available_to_character(safe_modules[0], character_id):
				_fail("%s 事件效果混入了非本角色模块：%s[%d] -> %s" % [character_id, event_id, option_index, module_id])
		"add_charm":
			var charm_id: String = String(effect.get("charm_id", ""))
			if charm_id.is_empty():
				return
			var safe_charms: Array[String] = Util.normalize_character_charm_choices([charm_id], character_id, 1, 5100 + seed_offset)
			if safe_charms.is_empty() or not Util.is_charm_available_to_character(safe_charms[0], character_id):
				_fail("%s 事件效果混入了非本角色护符：%s[%d] -> %s" % [character_id, event_id, option_index, charm_id])
		_:
			return

func _character_option_value(option: Dictionary, key: String, default_value: Variant, character_id: String) -> Variant:
	var direct_key: String = "%s_%s" % [key, character_id]
	if option.has(direct_key):
		return option.get(direct_key, default_value)
	var mapping_key: String = "%s_by_character" % key
	if option.has(mapping_key):
		var mapping: Dictionary = option.get(mapping_key, {})
		if mapping.has(character_id):
			return mapping[character_id]
	return option.get(key, default_value)

func _event_available_to_character(event_data: EventData, character_id: String) -> bool:
	for tag in event_data.tags:
		var tag_text: String = String(tag)
		if tag_text.begins_with("character:"):
			return tag_text == "character:%s" % character_id
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("EVENT_EFFECT_CHARACTER_FILTER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
