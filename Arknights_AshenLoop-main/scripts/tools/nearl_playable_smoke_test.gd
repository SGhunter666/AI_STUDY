extends SceneTree

const BATTLE_MANAGER_SCRIPT := preload("res://scripts/battle/BattleManager.gd")
const EFFECT_DATA_SCRIPT := preload("res://scripts/data/EffectData.gd")

var failures: Array[String] = []
var managers: Array[BattleManager] = []

class StubLocalizationManager:
	func text(key: String, args: Array = []) -> String:
		return key

	func character_name(_id: String, fallback: String = "") -> String:
		return fallback

class StubRunManager:
	var character: CharacterData = null
	var current_floor: int = 1
	var current_node_id: String = ""
	var gold: int = 99
	var hp: int = 80
	var max_hp: int = 80
	var deck: Array[String] = []
	var modules: Array[String] = []
	var charms: Array[String] = []
	var owned_charms: Array[String] = []
	var tunes: Array[String] = []
	var story_flags: Dictionary = {}
	var pending_rewards: Dictionary = {}
	var rng_seed: int = 24680
	var ascension_level: int = 0

	# 与真实 RunManager 的难度接口保持一致，测试固定 0 难度
	func ascension_enemy_hp_bonus() -> int:
		return 0

	func ascension_enemy_damage_bonus() -> int:
		return 0

	func ascension_starting_energy_penalty() -> int:
		return 0

	func start_new_run(char_data: CharacterData, seed_value: int = 24680) -> void:
		character = char_data
		hp = char_data.max_hp
		max_hp = char_data.max_hp
		deck = []
		for card_id in char_data.starter_deck:
			deck.append(String(card_id))
		modules.clear()
		charms.clear()
		owned_charms.clear()
		tunes.clear()
		story_flags.clear()
		pending_rewards.clear()
		rng_seed = seed_value

	func has_relic(relic_id: String) -> bool:
		return modules.has(relic_id) or charms.has(relic_id)

	func has_tune(_tune_id: String) -> bool:
		return false

	func has_flag(flag_id: String) -> bool:
		return bool(story_flags.get(flag_id, false))

	func set_flag(flag_id: String, value = true) -> void:
		story_flags[flag_id] = value

	func add_gold(amount: int) -> void:
		gold += amount

	func current_node():
		return null

	func get_reward_bias_weights() -> Dictionary:
		return {}

	func save_run_snapshot() -> void:
		pass

func _initialize() -> void:
	print("NEARL_PLAYABLE_SMOKE_TEST_START")
	call_deferred("_start")

func _start() -> void:
	var code: int = await _run()
	for manager in managers:
		if is_instance_valid(manager):
			manager.dispose_runtime_state()
			manager.free()
	if failures.is_empty():
		print("NEARL_PLAYABLE_SMOKE_TEST_OK")
	quit(code)

func _run() -> int:
	var nearl: CharacterData = Util.load_character("nearl", ResourceLoader.CACHE_MODE_IGNORE)
	if nearl == null:
		_fail("无法加载临光角色。")
		return 1
	_check_card_counts()
	_check_starter_deck(nearl)
	_check_reward_filters()
	_check_luminous_guard(nearl)
	_check_counter(nearl)
	_check_radiance(nearl)
	return 0 if failures.is_empty() else 1

func _check_card_counts() -> void:
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var base_count: int = 0
	var plus_count: int = 0
	var rarity_counts: Dictionary = {}
	for card_id_variant in db.keys():
		var card_id: String = String(card_id_variant)
		if not card_id.begins_with("nearl_"):
			continue
		if card_id.ends_with("_plus"):
			plus_count += 1
			continue
		base_count += 1
		var card: CardData = db[card_id] as CardData
		rarity_counts[card.rarity] = int(rarity_counts.get(card.rarity, 0)) + 1
	if base_count != 93 or plus_count != 93:
		_fail("临光卡牌数量错误：base=%d plus=%d。" % [base_count, plus_count])
	var expected := {"Starter": 10, "Common": 30, "Uncommon": 25, "Rare": 20, "Legendary": 8}
	for rarity in expected.keys():
		if int(rarity_counts.get(rarity, 0)) != int(expected[rarity]):
			_fail("临光 %s 数量错误：%d。" % [rarity, int(rarity_counts.get(rarity, 0))])

func _check_starter_deck(nearl: CharacterData) -> void:
	var expected: Array[String] = [
		"nearl_b01_knight_strike",
		"nearl_b01_knight_strike",
		"nearl_b02_guard_pulse",
		"nearl_b02_guard_pulse",
		"nearl_b03_radiant_strike",
		"nearl_b04_radiant_oath",
		"nearl_b05_counter_guard",
		"nearl_b06_shield_advance",
		"nearl_b07_hold_the_line",
		"nearl_b08_luminous_command"
	]
	var actual: Array[String] = []
	for card_id in nearl.starter_deck:
		actual.append(String(card_id))
	if actual != expected:
		_fail("临光起始牌组不匹配：%s" % str(actual))
	for card_id in actual:
		if not card_id.begins_with("nearl_"):
			_fail("临光起始牌组混入非专属牌：%s" % card_id)
	var starter_charms: Array[String] = []
	for charm_id in nearl.starter_charms:
		starter_charms.append(String(charm_id))
	if starter_charms != ["nearl_h01_kazimierz_badge", "nearl_h02_oath_pin"]:
		_fail("临光起始护符不匹配：%s" % str(starter_charms))

func _check_reward_filters() -> void:
	var cards: Array[String] = Util.get_card_reward_pool("nearl")
	if cards.is_empty():
		_fail("临光奖励池没有卡牌。")
	for card_id in cards:
		if card_id.begins_with("ex_") or card_id.begins_with("kaltsit_"):
			_fail("临光卡牌奖励池混入其他角色牌：%s" % card_id)
		if not Util.is_card_available_to_character(card_id, "nearl"):
			_fail("临光奖励池出现不可用卡：%s" % card_id)
	var modules: Array[String] = Util.get_module_reward_pool("nearl")
	if modules.size() != 16:
		_fail("临光模块池数量错误：%d" % modules.size())
	for module_id in modules:
		if not module_id.begins_with("nearl_m") or not Util.is_module_available_to_character(module_id, "nearl"):
			_fail("临光模块池归属错误：%s" % module_id)
	if not Util.is_module_available_to_character("nearl_crest", "nearl"):
		_fail("nearl_crest 未被识别为临光模块。")
	var charms: Array[String] = Util.get_charm_reward_pool("nearl")
	if charms.size() != 8:
		_fail("临光护符池数量错误：%d" % charms.size())
	for charm_id in charms:
		if not charm_id.begins_with("nearl_h") or not Util.is_charm_available_to_character(charm_id, "nearl"):
			_fail("临光护符池归属错误：%s" % charm_id)

func _check_luminous_guard(nearl: CharacterData) -> void:
	var manager: BattleManager = _new_manager(nearl)
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	manager.deck.hand.clear()
	manager.deck.hand.append(db["nearl_b02_guard_pulse"])
	manager.player.energy = 10
	if not manager.play_card(0, 0):
		_fail("无法打出守护脉冲。")
	if manager.player.block != 9:
		_fail("临光第一张护盾牌应为 9 护盾，实际 %d。" % manager.player.block)
	manager.deck.hand.append(db["nearl_b02_guard_pulse"])
	if not manager.play_card(0, 0):
		_fail("无法打出第二张守护脉冲。")
	if manager.player.block != 14:
		_fail("临光第二张护盾牌不应再次触发被动，实际护盾 %d。" % manager.player.block)
	manager.start_player_turn()
	manager.deck.hand.clear()
	manager.deck.hand.append(db["nearl_b01_knight_strike"])
	manager.player.energy = 10
	var before_block: int = manager.player.block
	manager.play_card(0, 0)
	if manager.player.block != before_block:
		_fail("非护盾牌不应触发 luminous_guard。")

func _check_counter(nearl: CharacterData) -> void:
	var manager: BattleManager = _new_manager(nearl)
	var enemy: UnitState = manager.enemies[0]
	var start_hp: int = enemy.hp
	var result: Dictionary = {}
	manager.player.block = 5
	manager._route_enemy_damage(enemy, 1, result, "测试敌人")
	if enemy.hp != start_hp:
		_fail("没有反击状态时不应反击。")
	manager.player.block = 0
	manager.gain_nearl_counter(3)
	manager._route_enemy_damage(enemy, 1, result, "测试敌人")
	if enemy.hp != start_hp:
		_fail("没有护盾时不应反击。")
	manager.player.block = 5
	manager.gain_nearl_radiance(2)
	manager._route_enemy_damage(enemy, 1, result, "测试敌人")
	if enemy.hp != start_hp - 5:
		_fail("反击伤害应为基础 3 + 光耀 2，实际敌人生命 %d。" % enemy.hp)
	manager._route_enemy_damage(enemy, 1, result, "测试敌人")
	if enemy.hp != start_hp - 5:
		_fail("同一敌人每回合不应触发第二次反击。")
	var twin_manager: BattleManager = _new_manager(nearl, 2)
	twin_manager.player.block = 8
	twin_manager.gain_nearl_counter(3)
	var first_enemy: UnitState = twin_manager.enemies[0]
	var second_enemy: UnitState = twin_manager.enemies[1]
	var first_start_hp: int = first_enemy.hp
	var second_start_hp: int = second_enemy.hp
	twin_manager._route_enemy_damage(first_enemy, 1, {}, "测试敌人A")
	twin_manager._route_enemy_damage(second_enemy, 1, {}, "测试敌人B")
	if first_enemy.hp != first_start_hp - 3 or second_enemy.hp != second_start_hp - 3:
		_fail("同 ID 的不同敌人各自攻击时都应该能触发反击。")

func _check_radiance(nearl: CharacterData) -> void:
	var manager: BattleManager = _new_manager(nearl)
	manager.gain_nearl_radiance(10)
	if manager.nearl_radiance() != 5:
		_fail("光耀应被限制在 5 层，实际 %d。" % manager.nearl_radiance())
	var block_effect: EffectData = EFFECT_DATA_SCRIPT.new()
	block_effect.effect_type = "block"
	block_effect.amount = 4
	block_effect.target = "self"
	manager.resolver.resolve_effect(block_effect, manager.player, manager.player)
	if manager.player.block != 6:
		_fail("5 层光耀时护盾应 +2，实际 %d。" % manager.player.block)
	manager.player.hp = 70
	var heal_effect: EffectData = EFFECT_DATA_SCRIPT.new()
	heal_effect.effect_type = "heal"
	heal_effect.amount = 1
	heal_effect.target = "self"
	manager.resolver.resolve_effect(heal_effect, manager.player, manager.player)
	if manager.player.hp != 73:
		_fail("5 层光耀时治疗应 +2，实际生命 %d。" % manager.player.hp)

func _new_manager(nearl: CharacterData, enemy_count: int = 1) -> BattleManager:
	var run_manager := StubRunManager.new()
	run_manager.start_new_run(nearl)
	var enemy_db: Dictionary = Util.load_enemy_db(ResourceLoader.CACHE_MODE_IGNORE)
	var enemy_data: EnemyData = enemy_db.get("reunion_scout", null) as EnemyData
	var manager: BattleManager = BATTLE_MANAGER_SCRIPT.new()
	managers.append(manager)
	manager.RunManager = run_manager
	manager.LocalizationManager = StubLocalizationManager.new()
	manager.enemy_ai.RunManager = run_manager
	manager.player_character = nearl
	if enemy_data != null:
		for _index in range(enemy_count):
			manager.enemy_list.append(enemy_data)
	manager.start_battle()
	manager.resolver.RunManager = run_manager
	return manager

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)
	print("NEARL_PLAYABLE_SMOKE_TEST_FAIL: %s" % message)
