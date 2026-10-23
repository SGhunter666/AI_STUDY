extends SceneTree

const REWARD_GENERATOR_SCRIPT := preload("res://scripts/rewards/RewardGenerator.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	_check_normal_reward_odds()
	_check_reward_pools_by_tier()
	if failures.is_empty():
		print("REWARD_RARITY_SMOKE_TEST_OK")
		return 0
	push_error("REWARD_RARITY_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _check_normal_reward_odds() -> void:
	var generator: RewardGenerator = REWARD_GENERATOR_SCRIPT.new(20260512)
	var common_pool: Array[String] = []
	var elite_pool: Array[String] = []
	var rare_pool: Array[String] = []
	for index in range(80):
		common_pool.append("common_%d" % index)
		elite_pool.append("elite_%d" % index)
		rare_pool.append("rare_%d" % index)
	var common_count: int = 0
	var elite_count: int = 0
	var rare_count: int = 0
	var total: int = 0
	for _run_index in range(8000):
		var choices: Array[String] = generator.normal_battle_card_choices(common_pool, elite_pool, rare_pool, 3, {})
		for card_id in choices:
			total += 1
			if card_id.begins_with("rare_"):
				rare_count += 1
			elif card_id.begins_with("elite_"):
				elite_count += 1
			elif card_id.begins_with("common_"):
				common_count += 1
	var elite_rate: float = float(elite_count) / float(total)
	var rare_rate: float = float(rare_count) / float(total)
	if elite_rate < 0.035 or elite_rate > 0.065:
		_fail("普通战精英卡概率应约为 5%%，实际 %.2f%%。" % (elite_rate * 100.0))
	if rare_rate < 0.012 or rare_rate > 0.032:
		_fail("普通战稀有卡概率应约为 2%%，实际 %.2f%%。" % (rare_rate * 100.0))
	if common_count <= elite_count + rare_count:
		_fail("普通战奖励仍应以普通卡为主。")

func _check_reward_pools_by_tier() -> void:
	for character_id in ["amiya", "exusiai", "kaltsit", "nearl"]:
		_check_pool_tier(character_id, Util.get_normal_battle_reward_pool(character_id), "common")
		_check_pool_tier(character_id, Util.get_elite_card_reward_pool(character_id), "elite")
		_check_pool_tier(character_id, Util.get_rare_card_reward_pool(character_id), "rare")

func _check_pool_tier(character_id: String, pool: Array[String], expected_tier: String) -> void:
	if pool.is_empty():
		_fail("%s 的 %s 奖励池为空。" % [character_id, expected_tier])
	for card_id in pool:
		var card: CardData = Util.load_card_by_id(card_id, ResourceLoader.CACHE_MODE_IGNORE)
		if card == null:
			_fail("%s 奖励池出现未知牌：%s。" % [character_id, card_id])
			continue
		if Util.card_rarity_tier(card) != expected_tier:
			_fail("%s 的 %s 奖励池混入 %s：%s。" % [character_id, expected_tier, Util.card_rarity_tier(card), card_id])
		if not Util.is_card_reward_eligible(card, character_id):
			_fail("%s 的 %s 奖励池混入不可奖励牌：%s。" % [character_id, expected_tier, card_id])

func _fail(message: String) -> void:
	failures.append(message)
