class_name EventRunner
extends RefCounted

func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunManager") if tree != null else null

func _localization_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("LocalizationManager") if tree != null else null

func apply_event_option(option: Dictionary) -> Array[Dictionary]:
	var summary_entries: Array[Dictionary] = []
	var effects: Array = Array(_character_option_value(option, "effects", []))
	for effect in effects:
		_apply_effect(effect, summary_entries)
	return summary_entries

func _apply_effect(effect: Dictionary, summary_entries: Array[Dictionary]) -> void:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return
	match String(effect.get("type", "")):
		"gain_gold", "add_gold":
			var amount: int = int(effect.get("amount", 0))
			run_manager.add_gold(amount)
			_append_summary(summary_entries, _fmt_text("获得金币 +%d", "Gain %d Gold", [amount]), "", Color(0.98, 0.86, 0.54, 0.86))
		"lose_gold":
			var gold_loss: int = int(effect.get("amount", 0))
			# 钳制到当前持有量，避免金币扣成负数导致商店比较永久失效
			var current_gold: int = int(run_manager.gold)
			if gold_loss > current_gold:
				gold_loss = max(0, current_gold)
			run_manager.add_gold(-gold_loss)
			_append_summary(summary_entries, _fmt_text("失去金币 -%d", "Lose %d Gold", [gold_loss]), "", Color(0.90, 0.74, 0.54, 0.86))
		"lose_hp":
			var hp_loss: int = int(effect.get("amount", 0))
			run_manager.lose_hp(hp_loss)
			_append_summary(summary_entries, _fmt_text("失去生命 -%d", "Lose %d HP", [hp_loss]), "", Color(0.96, 0.66, 0.64, 0.84))
		"heal":
			var heal_amount: int = int(effect.get("amount", 0))
			run_manager.heal(heal_amount)
			_append_summary(summary_entries, _fmt_text("恢复生命 +%d", "Heal %d HP", [heal_amount]), "", Color(0.72, 0.96, 0.74, 0.84))
		"heal_percent":
			var heal_percent: int = int(effect.get("amount", 0))
			var heal_value: int = int(ceil(float(run_manager.max_hp) * float(heal_percent) / 100.0))
			run_manager.heal(heal_value)
			_append_summary(summary_entries, _fmt_text("恢复生命 %d%%（约 +%d）", "Heal %d%% (about +%d)", [heal_percent, heal_value]), "", Color(0.72, 0.96, 0.74, 0.84))
		"add_card":
			var add_card_id: String = String(_character_effect_value(effect, "card_id", ""))
			add_card_id = _character_safe_card_id(add_card_id)
			_add_card_if_known(add_card_id)
			var add_card: CardData = _card_data(add_card_id)
			_append_summary(
				summary_entries,
				_fmt_text("加入卡组：%s", "Added to Deck: %s", [_card_name(add_card_id)]),
				_card_description(add_card),
				Color(0.72, 0.92, 1.0, 0.84)
			)
		"add_card_reward":
			var reward_card_id: String = String(_character_effect_value(effect, "card_id", ""))
			reward_card_id = _character_safe_card_id(reward_card_id)
			_add_card_if_known(reward_card_id)
			var reward_card: CardData = _card_data(reward_card_id)
			_append_summary(
				summary_entries,
				_fmt_text("加入卡组：%s", "Added to Deck: %s", [_card_name(reward_card_id)]),
				_card_description(reward_card),
				Color(0.72, 0.92, 1.0, 0.84)
			)
		"remove_card", "remove_selected_card":
			var card_id: String = String(_character_effect_value(effect, "card_id", ""))
			if card_id.is_empty() and not run_manager.deck.is_empty():
				# 兜底移除时优先移除非基础牌，避免事件轻易删掉初始牌
				card_id = _removable_fallback_card_id(run_manager)
			run_manager.remove_card(card_id)
			var removed_card_name: String = _card_name(card_id)
			_append_summary(
				summary_entries,
				_fmt_text("移除卡牌：%s", "Removed Card: %s", [removed_card_name if not removed_card_name.is_empty() else _fmt_text("一张牌", "A Card")]),
				_fmt_text("牌组变得更薄，也更稳定。", "The deck becomes thinner and more consistent."),
				Color(0.90, 0.82, 0.66, 0.84)
			)
		"upgrade_random_card":
			var random_upgraded_name: String = _upgrade_random_available_card()
			if random_upgraded_name.is_empty():
				_append_summary(summary_entries, _fmt_text("升级落空", "Upgrade Missed"), _fmt_text("当前没有可升级的牌。", "There is no upgradable card right now."), Color(0.82, 0.78, 0.72, 0.84))
			else:
				_append_summary(summary_entries, _fmt_text("升级卡牌：%s", "Card Upgraded: %s", [random_upgraded_name]), _fmt_text("一张可升级的牌已经被强化。", "One upgradable card has been improved."), Color(0.98, 0.88, 0.64, 0.84))
		"upgrade_selected_card":
			var target_card_id: String = String(_character_effect_value(effect, "card_id", ""))
			var selected_upgraded_name: String = _upgrade_named_card(target_card_id)
			if selected_upgraded_name.is_empty():
				selected_upgraded_name = _upgrade_first_available_card()
			if selected_upgraded_name.is_empty():
				_append_summary(summary_entries, _fmt_text("升级落空", "Upgrade Missed"), _fmt_text("当前没有可升级的牌。", "There is no upgradable card right now."), Color(0.82, 0.78, 0.72, 0.84))
			else:
				_append_summary(summary_entries, _fmt_text("升级卡牌：%s", "Card Upgraded: %s", [selected_upgraded_name]), _fmt_text("一张可升级的牌已经被强化。", "One upgradable card has been improved."), Color(0.98, 0.88, 0.64, 0.84))
		"add_module":
			var module_id: String = String(_character_effect_value(effect, "module_id", ""))
			module_id = _character_safe_module_id(module_id)
			if module_id.is_empty():
				return
			run_manager.add_module(module_id)
			var module_data: ModuleData = _module_data(module_id)
			_append_summary(
				summary_entries,
				_fmt_text("获得模块：%s", "Module Acquired: %s", [_module_name(module_id)]),
				_module_description(module_data),
				Color(0.72, 0.92, 1.0, 0.84)
			)
		"add_charm":
			var charm_id: String = String(_character_effect_value(effect, "charm_id", ""))
			charm_id = _character_safe_charm_id(charm_id)
			if charm_id.is_empty():
				return
			run_manager.add_charm(charm_id)
			var charm_data: CharmData = _charm_data(charm_id)
			_append_summary(
				summary_entries,
				_fmt_text("获得护符：%s", "Charm Acquired: %s", [_charm_name(charm_id)]),
				_charm_description(charm_data),
				Color(0.88, 0.78, 1.0, 0.84)
			)
		"set_flag", "gain_story_flag":
			var flag_name: String = String(_character_effect_value(effect, "flag", ""))
			run_manager.set_flag(flag_name, true)
			_append_flag_summary(summary_entries, flag_name, true)
		"apply_run_modifier":
			var modifier_id: String = String(_character_effect_value(effect, "modifier_id", ""))
			run_manager.set_flag(modifier_id, true)
			_append_flag_summary(summary_entries, modifier_id, true)
		_:
			push_warning("Unknown event effect: %s" % String(effect.get("type", "")))

func _add_card_if_known(card_id: String) -> void:
	if card_id.is_empty():
		return
	if not Util.load_card_db().has(card_id):
		push_warning("Event tried to add unknown card: %s" % card_id)
		return
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return
	run_manager.add_card(card_id)

func _character_safe_card_id(card_id: String) -> String:
	if card_id.is_empty():
		return ""
	var run_manager: Node = _run_manager()
	if run_manager == null or run_manager.character == null:
		return card_id
	var character_id: String = String(run_manager.character.id)
	if Util.is_card_available_to_character(card_id, character_id):
		return card_id
	var replacements: Array[String] = Util.normalize_character_card_choices(
		[card_id],
		character_id,
		1,
		int(run_manager.rng_seed) + int(run_manager.current_floor) * 131 + card_id.hash(),
		run_manager.get_reward_bias_weights()
	)
	if replacements.is_empty():
		push_warning("Event could not find a character-safe replacement for card: %s" % card_id)
		return ""
	return replacements[0]

func _character_safe_module_id(module_id: String) -> String:
	if module_id.is_empty():
		return ""
	var run_manager: Node = _run_manager()
	if run_manager == null or run_manager.character == null:
		return module_id
	var character_id: String = String(run_manager.character.id)
	if Util.is_module_available_to_character(module_id, character_id):
		return module_id
	var replacements: Array[String] = Util.normalize_character_module_choices(
		[module_id],
		character_id,
		1,
		int(run_manager.rng_seed) + int(run_manager.current_floor) * 163 + module_id.hash()
	)
	if replacements.is_empty():
		push_warning("Event could not find a character-safe replacement for module: %s" % module_id)
		return ""
	return replacements[0]

func _character_safe_charm_id(charm_id: String) -> String:
	if charm_id.is_empty():
		return ""
	var run_manager: Node = _run_manager()
	if run_manager == null or run_manager.character == null:
		return charm_id
	var character_id: String = String(run_manager.character.id)
	if Util.is_charm_available_to_character(charm_id, character_id):
		return charm_id
	var replacements: Array[String] = Util.normalize_character_charm_choices(
		[charm_id],
		character_id,
		1,
		int(run_manager.rng_seed) + int(run_manager.current_floor) * 181 + charm_id.hash()
	)
	if replacements.is_empty():
		push_warning("Event could not find a character-safe replacement for charm: %s" % charm_id)
		return ""
	return replacements[0]

func _removable_fallback_card_id(run_manager: Node) -> String:
	# 兜底移除：优先选择非基础/非状态/非诅咒牌，保护初始牌组
	var card_db: Dictionary = Util.load_card_db()
	for index in range(run_manager.deck.size()):
		var candidate: CardData = card_db.get(String(run_manager.deck[index]), null) as CardData
		if candidate != null and candidate.rarity not in ["Basic", "Starter"] and candidate.card_type not in ["Status", "Curse"]:
			return String(run_manager.deck[index])
	return String(run_manager.deck[0])

func _upgrade_first_available_card() -> String:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return ""
	var indexes: Array[int] = _upgradeable_card_indexes(run_manager)
	if indexes.is_empty():
		return ""
	return _upgrade_card_at_index(run_manager, indexes[0])

func _upgrade_random_available_card() -> String:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return ""
	var indexes: Array[int] = _upgradeable_card_indexes(run_manager)
	if indexes.is_empty():
		return ""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# 使用 run 种子而非系统时钟，保证同一存档状态下升级结果可复现
	rng.seed = int(run_manager.rng_seed) + int(run_manager.current_floor) * 101 + run_manager.deck.size() * 37 + 7919
	return _upgrade_card_at_index(run_manager, indexes[rng.randi_range(0, indexes.size() - 1)])

func _upgrade_named_card(card_id: String) -> String:
	if card_id.is_empty():
		return ""
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return ""
	for index in range(run_manager.deck.size()):
		if String(run_manager.deck[index]) == card_id:
			return _upgrade_card_at_index(run_manager, index)
	return ""

func _upgradeable_card_indexes(run_manager: Node) -> Array[int]:
	var card_db: Dictionary = Util.load_card_db()
	var indexes: Array[int] = []
	for index in range(run_manager.deck.size()):
		var card_id: String = run_manager.deck[index]
		var card: CardData = card_db.get(card_id, null) as CardData
		if card != null and not card.upgraded_id.is_empty() and card_db.has(card.upgraded_id):
			indexes.append(index)
	return indexes

func _upgrade_card_at_index(run_manager: Node, index: int) -> String:
	var card_db: Dictionary = Util.load_card_db()
	if index < 0 or index >= run_manager.deck.size():
		return ""
	var card_id: String = String(run_manager.deck[index])
	var card: CardData = card_db.get(card_id, null) as CardData
	if card == null or card.upgraded_id.is_empty() or not card_db.has(card.upgraded_id):
		return ""
	run_manager.deck[index] = card.upgraded_id
	run_manager.deck_changed.emit()
	run_manager.run_updated.emit()
	run_manager.save_run_snapshot()
	return _card_name(card_id)

func _append_summary(summary_entries: Array[Dictionary], title: String, body: String = "", accent: Color = Color(0.90, 0.86, 0.74, 0.84)) -> void:
	if title.is_empty():
		return
	summary_entries.append({
		"title": title,
		"body": body,
		"accent": accent
	})

func _append_flag_summary(summary_entries: Array[Dictionary], flag_name: String, value: Variant = true) -> void:
	var summary: Dictionary = _flag_summary(flag_name, value)
	if summary.is_empty():
		return
	summary_entries.append(summary)

func _flag_summary(flag_name: String, value: Variant = true) -> Dictionary:
	var character_id: String = _active_character_id()
	match flag_name:
		"next_floor_fewer_events":
			return _summary(_fmt_text("后续变化：下一层事件更少", "Next Floor: Fewer events"), _fmt_text("信息会更集中，但剧情机会也会减少。", "Information becomes tighter, but there will be fewer narrative opportunities."), Color(0.90, 0.82, 0.66, 0.84))
		"soft_start_next_battle":
			return _summary(_fmt_text("后续变化：下场战斗更稳", "Next Battle: Softer opening"), _fmt_text("下一场战斗会以更平稳的节奏开始。", "The next battle will start from a steadier pace."), Color(0.74, 0.94, 0.98, 0.84))
		"doctor_ideal":
			if character_id == "exusiai":
				return _summary(_fmt_text("路线倾向：救援 / 支援", "Route Bias: Rescue / Support"), _fmt_text("后续奖励会更偏向支援调度、补给与空域掩护。", "Future rewards lean more toward support routing, resupply, and aerial cover."), Color(0.76, 0.96, 0.80, 0.84))
			return _summary(_fmt_text("路线倾向：治疗 / 支援", "Route Bias: Heal / Support"), _fmt_text("后续奖励会更偏向治疗与支援。", "Future rewards lean more toward healing and support."), Color(0.76, 0.96, 0.80, 0.84))
		"doctor_efficiency":
			if character_id == "exusiai":
				return _summary(_fmt_text("路线倾向：点杀 / 爆发", "Route Bias: Pickoff / Burst"), _fmt_text("后续奖励会更偏向锁头处决与爆发连射。", "Future rewards lean more toward mark execution and burst chains."), Color(0.98, 0.88, 0.64, 0.84))
			return _summary(_fmt_text("路线倾向：高稀有 / 爆发", "Route Bias: Rare / Burst"), _fmt_text("后续奖励会更偏向高稀有与爆发。", "Future rewards lean more toward rare burst options."), Color(0.98, 0.88, 0.64, 0.84))
		"doctor_burden":
			if character_id == "exusiai":
				return _summary(_fmt_text("路线倾向：高压 / 连射", "Route Bias: High-risk / Chains"), _fmt_text("后续奖励会更偏向高压爆发、装填与连射续航。", "Future rewards lean more toward high-risk burst, reload, and chain-fire sustain."), Color(0.96, 0.76, 0.76, 0.84))
			return _summary(_fmt_text("路线倾向：透支 / 意志", "Route Bias: Overload / Will"), _fmt_text("后续奖励会更偏向透支与意志混合。", "Future rewards lean more toward overload and will hybrids."), Color(0.96, 0.76, 0.76, 0.84))
		"accept_burden_1", "accept_burden_2", "accept_burden_3":
			if character_id == "exusiai":
				return _summary(_fmt_text("隐藏路线进度：承担", "Hidden Route: Burden progress"), _fmt_text("能天使承担路线的进度被推进了。", "Exusiai's burden route has advanced."), Color(0.92, 0.78, 0.98, 0.84))
			return _summary(_fmt_text("隐藏路线进度：承担", "Hidden Route: Burden progress"), _fmt_text("阿米娅承担路线的进度被推进了。", "Amiya's burden route has advanced."), Color(0.92, 0.78, 0.98, 0.84))
		"floor_first_support_double":
			return _summary(_fmt_text("本层增益：首张支援触发两次", "Floor Bonus: First Support doubles"), _fmt_text("本层每场战斗的第一张支援牌会触发两次基础效果。", "This floor, the first Support card each battle triggers its base effect twice."), Color(0.74, 0.94, 0.98, 0.84))
		"double_next_reward":
			return _summary(_fmt_text("后续变化：下一份奖励更丰厚", "Next Reward: Increased payout"), _fmt_text("下一次奖励会比平时更肥。", "The next reward will be richer than usual."), Color(0.98, 0.88, 0.64, 0.84))
		"next_battle_enemy_strength":
			return _summary(_fmt_text("风险提升：下一场敌人强化", "Risk Up: Next battle stronger enemies"), _fmt_text("你会换到更高回报，但下一场战斗也会更硬。", "You trade into higher returns, but the next battle will be tougher."), Color(0.96, 0.72, 0.60, 0.84))
		"preview_two_nodes":
			return _summary(_fmt_text("战术情报：额外预览节点", "Tactical Intel: Extra node preview"), _fmt_text("地图上会额外显示两个可预览节点。", "Two more map nodes will be previewed."), Color(0.72, 0.92, 1.0, 0.84))
		"next_battle_start_will_3":
			return _summary(_fmt_text("后续变化：开局 +3 意志", "Next Battle: Start with +3 Will"), _fmt_text("下一场战斗开始时会直接获得 3 点意志。", "The next battle starts with 3 extra Will."), Color(0.72, 0.90, 1.0, 0.84))
		"next_battle_start_ammo_2":
			return _summary(_fmt_text("后续变化：开局 +2 弹药", "Next Battle: Start with +2 Ammo"), _fmt_text("下一场战斗开始时会带着更完整的弹匣上场。", "The next battle starts with a fuller magazine."), Color(0.72, 0.90, 1.0, 0.84))
		"next_battle_start_energy_1":
			return _summary(_fmt_text("后续变化：开局 +1 能量", "Next Battle: Start with +1 Energy"), _fmt_text("下一场战斗开始时会多出一格节奏空间。", "The next battle starts with one extra beat of tempo."), Color(0.86, 0.92, 1.0, 0.84))
		"channel_upgrade_credit":
			return _summary(_fmt_text("后续变化：引导牌强化机会", "Future Bonus: Channel upgrade credit"), _fmt_text("之后会更容易把引导牌变成核心组件。", "It becomes easier to turn Channel cards into core pieces later."), Color(0.76, 0.90, 1.0, 0.84))
		"legendary_offer_next_reward":
			return _summary(_fmt_text("后续变化：传奇牌机会提升", "Next Reward: Better legendary odds"), _fmt_text("下一份奖励更容易出现传奇级选项。", "The next reward is more likely to offer a legendary option."), Color(1.0, 0.84, 0.62, 0.84))
		"double_elite_reward":
			return _summary(_fmt_text("后续变化：精英奖励翻倍", "Elite Rewards: Doubled"), _fmt_text("本层精英战的收益会更夸张。", "Elite encounters on this floor will pay out more heavily."), Color(0.98, 0.86, 0.58, 0.84))
		"support_upgrade_credit":
			return _summary(_fmt_text("后续变化：支援牌强化机会", "Future Bonus: Support upgrade credit"), _fmt_text("之后会更容易把支援链路拉满。", "It becomes easier to fully tune support chains later."), Color(0.74, 0.94, 0.98, 0.84))
		"tune_resonance_apply":
			return _summary(_fmt_text("调律倾向：共振", "Tune Bias: Resonance"), _fmt_text("下一次调律更偏向共振方向。", "The next tune offer leans toward resonance."), Color(0.72, 0.96, 1.0, 0.84))
		"tune_cost_pending":
			return _summary(_fmt_text("后续变化：下场首牌减费", "Next Battle: First card costs less"), _fmt_text("下一场战斗打出的第一张牌费用 -1。", "The first card you play next battle costs 1 less."), Color(0.84, 0.92, 1.0, 0.84))
		"avoided_fissure":
			return _summary(_fmt_text("剧情记录：避开裂缝", "Story Record: Fissure avoided"), _fmt_text("你保住了节奏，也避开了这段污染。", "You kept the tempo and avoided this patch of contamination."), Color(0.86, 0.88, 0.94, 0.84))
		"energy_potion_2":
			return _summary(_fmt_text("资源储备：2 次能量药剂", "Resource Stock: 2 energy potions"), _fmt_text("之后你可以在关键回合多榨出一点节奏。", "Later, you can squeeze more tempo out of key turns."), Color(0.98, 0.88, 0.64, 0.84))
		"rest_upgrade_credit":
			return _summary(_fmt_text("后续变化：休整升级机会", "Future Bonus: Rest upgrade credit"), _fmt_text("下一次休整会更容易把牌组往核心方向推进。", "The next rest site will make it easier to sharpen the deck."), Color(0.82, 0.96, 0.78, 0.84))
		"evacuation_kind":
			return _summary(_fmt_text("路线记录：保护 / 撤离", "Route Record: Kind evacuation"), _fmt_text("之后的事件会更倾向保护与撤离。", "Future choices lean more toward protection and evacuation."), Color(0.82, 0.96, 0.78, 0.84))
		"evacuation_efficient":
			return _summary(_fmt_text("路线记录：效率推进", "Route Record: Efficient advance"), _fmt_text("之后的事件会更倾向效率与推进。", "Future choices lean more toward efficiency and advance."), Color(0.98, 0.88, 0.64, 0.84))
		"evacuation_split":
			return _summary(_fmt_text("路线记录：折中策略", "Route Record: Split compromise"), _fmt_text("之后的事件会更倾向两边都留余地。", "Future choices lean toward compromise and flexibility."), Color(0.90, 0.82, 0.66, 0.84))
		"w_intents_clear":
			return _summary(_fmt_text("首领情报：W 意图已看穿", "Boss Intel: W intentions revealed"), _fmt_text("W 战时，敌方意图会完整显示。", "W's intentions will be fully shown in her boss fight."), Color(0.98, 0.76, 0.64, 0.84))
		"lost_hidden_progress":
			return _summary(_fmt_text("隐藏路线：进度受损", "Hidden Route: Progress lost"), _fmt_text("你离隐藏路线更远了一步。", "You moved one step farther from the hidden route."), Color(0.92, 0.70, 0.70, 0.84))
		_:
			return {}

func _summary(title: String, body: String, accent: Color) -> Dictionary:
	return {
		"title": title,
		"body": body,
		"accent": accent
	}

func _card_data(card_id: String) -> CardData:
	return Util.load_card_db().get(card_id, null) as CardData

func _module_data(module_id: String) -> ModuleData:
	return Util.load_module_db().get(module_id, null) as ModuleData

func _charm_data(charm_id: String) -> CharmData:
	return Util.load_charm_db().get(charm_id, null) as CharmData

func _card_name(card_id: String) -> String:
	var card: CardData = _card_data(card_id)
	var localization_manager: Node = _localization_manager()
	return localization_manager.card_name(card) if card != null and localization_manager != null else card_id

func _card_description(card: CardData) -> String:
	var localization_manager: Node = _localization_manager()
	return localization_manager.card_description(card) if card != null and localization_manager != null else ""

func _module_name(module_id: String) -> String:
	var module_data: ModuleData = _module_data(module_id)
	var localization_manager: Node = _localization_manager()
	return localization_manager.module_name(module_data) if module_data != null and localization_manager != null else module_id

func _module_description(module_data: ModuleData) -> String:
	var localization_manager: Node = _localization_manager()
	return localization_manager.module_description(module_data) if module_data != null and localization_manager != null else ""

func _charm_name(charm_id: String) -> String:
	var charm_data: CharmData = _charm_data(charm_id)
	var localization_manager: Node = _localization_manager()
	if charm_data != null and localization_manager != null:
		return localization_manager.charm_name(charm_data)
	return charm_id

func _charm_description(charm_data: CharmData) -> String:
	var localization_manager: Node = _localization_manager()
	if charm_data != null and localization_manager != null:
		return localization_manager.charm_description(charm_data)
	return ""

func _fmt_text(zh_text: String, en_text: String, format_args: Array = []) -> String:
	var localization_manager: Node = _localization_manager()
	var raw: String = zh_text
	if localization_manager != null and localization_manager.current_language != localization_manager.LANG_ZH:
		raw = en_text
	return raw % format_args if not format_args.is_empty() else raw

func _active_character_id() -> String:
	var run_manager: Node = _run_manager()
	if run_manager != null and run_manager.character != null:
		return String(run_manager.character.id)
	return "amiya"

func _character_option_value(option: Dictionary, key: String, default_value: Variant = null) -> Variant:
	var character_id: String = _active_character_id()
	var direct_key: String = "%s_%s" % [key, character_id]
	if option.has(direct_key):
		return option.get(direct_key, default_value)
	var mapping_key: String = "%s_by_character" % key
	if option.has(mapping_key):
		var mapping: Dictionary = option.get(mapping_key, {})
		if mapping.has(character_id):
			return mapping[character_id]
	return option.get(key, default_value)

func _character_effect_value(effect: Dictionary, key: String, default_value: Variant = null) -> Variant:
	var character_id: String = _active_character_id()
	var direct_key: String = "%s_%s" % [key, character_id]
	if effect.has(direct_key):
		return effect.get(direct_key, default_value)
	var mapping_key: String = "%s_by_character" % key
	if effect.has(mapping_key):
		var mapping: Dictionary = effect.get(mapping_key, {})
		if mapping.has(character_id):
			return mapping[character_id]
	return effect.get(key, default_value)
