extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	var card_db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var battle_scene_packed: PackedScene = load("res://scenes/BattleScene.tscn")
	if battle_scene_packed == null:
		_fail("无法加载战斗场景，不能测试卡牌拖拽目标判定。")
		return _finish()
	var battle_scene: Control = battle_scene_packed.instantiate() as Control
	if battle_scene == null:
		_fail("无法实例化战斗场景，不能测试卡牌拖拽目标判定。")
		return _finish()

	var scanned_count: int = 0
	var enemy_target_count: int = 0
	var false_negatives: Array[String] = []
	var false_positives: Array[String] = []
	for card_id in card_db.keys():
		var card: CardData = card_db[card_id] as CardData
		if card == null:
			continue
		scanned_count += 1
		var expected_enemy_target: bool = _expected_card_targets_enemy(card)
		var actual_enemy_target: bool = bool(battle_scene.call("_card_targets_enemy", card))
		if expected_enemy_target:
			enemy_target_count += 1
		if expected_enemy_target and not actual_enemy_target:
			false_negatives.append("%s（%s）" % [card.id, card.display_name])
		elif not expected_enemy_target and actual_enemy_target:
			false_positives.append("%s（%s）" % [card.id, card.display_name])

	battle_scene.free()
	if not false_negatives.is_empty():
		_fail("这些牌应该允许拖到敌人身上，但 UI 没判定为敌方目标：%s" % ", ".join(false_negatives))
	if not false_positives.is_empty():
		_fail("这些牌不应该要求拖到敌人身上，但 UI 误判为敌方目标：%s" % ", ".join(false_positives))
	if failures.is_empty():
		print("CARD_TARGETING_UI_SMOKE_TEST_OK scanned=%d enemy_target_cards=%d" % [scanned_count, enemy_target_count])
	return _finish()

func _expected_card_targets_enemy(card: CardData) -> bool:
	if card == null or String(card.card_type) == "Curse":
		return false
	for effect in card.effects:
		if _expected_effect_targets_enemy(effect):
			return true
	for effect in card.conditional_effects:
		if _expected_effect_targets_enemy(effect):
			return true
	return false

func _expected_effect_targets_enemy(effect: EffectData) -> bool:
	if effect == null:
		return false
	var target: String = String(effect.target)
	if target in ["enemy", "all_enemies", "random_enemy"]:
		return true
	if target == "" and String(effect.effect_type) in _legacy_enemy_effect_types():
		return true
	return false

func _legacy_enemy_effect_types() -> Array[String]:
	return [
		"damage",
		"damage_all",
		"damage_random_hits",
		"damage_ignore_block_percent",
		"damage_resonant_all",
		"damage_resonant_all_consume",
		"damage_per_support",
		"damage_plus_overload",
		"damage_per_lost_hp_ten",
		"damage_all_plus_overload",
		"spend_all_will_damage",
		"spend_will_damage",
		"damage_per_target_resonance_consume_all",
		"damage_from_will_and_target_resonance",
		"damage_from_lost_hp_battle_percent_all",
		"apply_status",
		"apply_resonance",
		"apply_mark",
		"consume_mark",
	]

func _finish() -> int:
	if failures.is_empty():
		return 0
	push_error("CARD_TARGETING_UI_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _flush_teardown() -> void:
	for _i in range(4):
		await process_frame

func _fail(message: String) -> void:
	failures.append(message)
