extends SceneTree

# Power 卡钩子守护测试：验证"描述承诺但曾未实现"的角色 Power 卡现在真实生效
# 用法：godot --headless --path . -s scripts/tools/power_card_hook_smoke_test.gd

var BattleManager = preload("res://scripts/battle/BattleManager.gd")
var Util = load("res://scripts/core/util.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_start")

func _fail(message: String) -> void:
	failures.append(message)
	print("POWER_HOOK_SMOKE_TEST_FAIL: ", message)

func _start() -> void:
	var code: int = await _run()
	if failures.is_empty():
		print("POWER_HOOK_SMOKE_TEST_OK")
	quit(code)

func _new_manager(character_id: String, enemy_count: int = 1) -> BattleManager:
	var character: CharacterData = Util.load_character(character_id, ResourceLoader.CACHE_MODE_IGNORE)
	var enemies: Array[EnemyData] = []
	var enemy_db: Dictionary = Util.load_enemy_db(ResourceLoader.CACHE_MODE_IGNORE)
	for enemy_id in enemy_db.keys():
		var enemy: EnemyData = enemy_db[enemy_id] as EnemyData
		if enemy != null and enemy.id != "w_boss":
			enemies.append(enemy)
		if enemies.size() >= enemy_count:
			break
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	manager.configure(character, enemies)
	manager.start_battle()
	manager.deck.hand.clear()
	return manager

func _run() -> int:
	_test_exusiai_team_callout()
	_test_exusiai_fireline()
	_test_exusiai_combo_rhythm()
	_test_exusiai_angel_mark()
	_test_exusiai_seamless_reload()
	_test_kaltsit_medical_line()
	_test_kaltsit_medical_fortress()
	_test_kaltsit_auto_infusion()
	_test_kaltsit_overflow_shielding()
	_test_kaltsit_structural_compensation()
	_test_nearl_radiant_oath()
	_test_nearl_counter_trigger()
	_test_nearl_radiance_block_bonus()
	_test_nearl_radiant_strike_conditional_heal()
	_test_amiya_resonance_mark()
	_test_amiya_resonance_decay()
	_test_amiya_leader_passive()
	_test_amiya_will_and_focused_ray()
	_test_curse_lost_focus_on_draw()
	_test_curse_static_chatter_on_draw()
	_test_curse_medical_burden_on_draw()
	_test_curse_command_interference_on_draw()
	_test_kaltsit_s07_status_conditions()
	return 0 if failures.is_empty() else 1

func _play(manager, card_id: String) -> void:
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	manager.deck.hand.clear()
	manager.deck.hand.append(db[card_id])
	manager.player.energy = 99
	if not manager.play_card(0, 0):
		_fail("无法打出 %s。" % card_id)

func _test_exusiai_team_callout() -> void:
	var manager = _new_manager("exusiai")
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	_play(manager, "ex_c27_team_callout")
	var block_before: int = manager.player.block
	_play(manager, "ex_c05_fast_tempo")  # 非射击牌
	if manager.player.block != block_before:
		_fail("team_callout 不应被非射击牌触发。")
	manager.player.block = 0
	var shot: String = ""
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card != null and "Shot" in card.tags and card.card_type == "Attack" and not card.id.begins_with("ex_") == false and card.id.begins_with("ex_"):
			shot = card.id
			break
	if shot.is_empty():
		_fail("找不到能天使射击牌用于测试。")
		return
	_play(manager, shot)
	if manager.player.block < 2:
		_fail("team_callout：射击牌后应获得护盾，实际 %d。" % manager.player.block)
	manager.dispose_runtime_state()
	manager.free()

func _test_exusiai_fireline() -> void:
	var manager = _new_manager("exusiai")
	_play(manager, "ex_r05_fireline_control")
	var enemy: UnitState = manager.enemies[0]
	var hp_before: int = enemy.hp
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var first_card: CardData = db["ex_c01_double_tap_burst"]
	manager.deck.hand.clear()
	manager.deck.hand.append(first_card.duplicate(true))
	manager.deck.hand.append(first_card.duplicate(true))
	manager.player.energy = 99
	manager.play_card(0, 0)
	var first_damage: int = hp_before - enemy.hp
	manager.play_card(0, 0)
	var second_damage: int = hp_before - enemy.hp - first_damage
	if second_damage < first_damage + 2:
		_fail("fireline_control：第 2 张射击应至少 +2 伤害（%d → %d）。" % [first_damage, second_damage])
	manager.dispose_runtime_state()
	manager.free()

func _test_exusiai_combo_rhythm() -> void:
	var manager = _new_manager("exusiai")
	_play(manager, "ex_u17_combo_rhythm")
	var hand_before: int = manager.deck.hand.size()
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var shot_card: CardData = db["ex_c01_double_tap_burst"]
	manager.deck.hand.clear()
	manager.deck.hand.append(shot_card.duplicate(true))
	manager.deck.hand.append(shot_card.duplicate(true))
	manager.deck.hand.append(shot_card.duplicate(true))
	manager.player.energy = 99
	manager.play_card(0, 0)
	manager.play_card(0, 0)
	manager.play_card(0, 0)
	if manager.deck.hand.size() < hand_before:
		_fail("combo_rhythm：第 3 张牌应触发抽 1（手牌 %d -> %d）。" % [hand_before, manager.deck.hand.size()])
	manager.dispose_runtime_state()
	manager.free()

func _test_exusiai_angel_mark() -> void:
	var manager = _new_manager("exusiai")
	_play(manager, "ex_r06_angel_mark")
	var mark_card_id: String = ""
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card == null or not card.id.begins_with("ex_"):
			continue
		for effect in card.effects:
			if effect != null and effect.effect_type == "apply_mark":
				mark_card_id = card.id
				break
		if not mark_card_id.is_empty():
			break
	if mark_card_id.is_empty():
		_fail("找不到能天使标记牌用于测试。")
		manager.dispose_runtime_state()
		manager.free()
		return
	var mark_card: CardData = db[mark_card_id]
	var base_mark: int = 0
	for effect in mark_card.effects:
		if effect.effect_type == "apply_mark":
			base_mark = effect.amount
	manager.deck.hand.clear()
	manager.deck.hand.append(mark_card)
	manager.player.energy = 99
	manager.play_card(0, 0)
	var enemy: UnitState = manager.enemies[0]
	if enemy.mark < base_mark + 1:
		_fail("angel_mark：施加标记应追加 1 层（%d + 1，实际 %d）。" % [base_mark, enemy.mark])
	manager.dispose_runtime_state()
	manager.free()

func _test_exusiai_seamless_reload() -> void:
	var manager = _new_manager("exusiai")
	_play(manager, "ex_r03_seamless_reload")
	manager.player.ammo = 1
	# 打出一张带 consume_ammo 的射击牌，弹药耗尽时应自动恢复 2
	_play(manager, "ex_c01_double_tap_burst")
	if manager.player.ammo < 2:
		_fail("seamless_reload：弹药耗尽应立即恢复 2，实际 %d。" % manager.player.ammo)
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_medical_line() -> void:
	var manager = _new_manager("kaltsit")
	_play(manager, "kaltsit_c21_medical_line")
	manager.player.block = 0
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var heal_card_id: String = ""
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card == null or not card.id.begins_with("kaltsit_"):
			continue
		for effect in card.effects:
			if effect != null and effect.effect_type == "heal":
				heal_card_id = card.id
				break
		if not heal_card_id.is_empty():
			break
	if heal_card_id.is_empty():
		_fail("找不到凯尔希医疗牌用于测试。")
		manager.dispose_runtime_state()
		manager.free()
		return
	manager.player.hp = max(1, manager.player.max_hp - 10)
	_play(manager, heal_card_id)
	if manager.player.block < 3:
		_fail("medical_line：第一张医疗牌应给予 3 护盾，实际 %d。" % manager.player.block)
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_medical_fortress() -> void:
	var manager = _new_manager("kaltsit")
	_play(manager, "kaltsit_u03_medical_fortress")
	manager.player.block = 0
	manager.start_player_turn()
	manager.player.block = 0
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var heal_card_id: String = ""
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card == null or not card.id.begins_with("kaltsit_"):
			continue
		for effect in card.effects:
			if effect != null and effect.effect_type == "heal":
				heal_card_id = card.id
				break
		if not heal_card_id.is_empty():
			break
	manager.player.hp = max(1, manager.player.max_hp - 10)
	_play(manager, heal_card_id)
	if manager.player.block < 2:
		_fail("medical_fortress：医疗牌应给予 +2 护盾，实际 %d。" % manager.player.block)
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_auto_infusion() -> void:
	var manager = _new_manager("kaltsit")
	_play(manager, "kaltsit_c22_auto_infusion")
	manager.player.hp = max(1, int(manager.player.max_hp * 0.3))
	var hp_before: int = manager.player.hp
	manager.start_player_turn()
	if manager.player.hp <= hp_before:
		_fail("auto_infusion：低血量回合开始应治疗 2（%d -> %d）。" % [hp_before, manager.player.hp])
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_overflow_shielding() -> void:
	var manager = _new_manager("kaltsit")
	_play(manager, "kaltsit_u11_overflow_shielding")
	manager.player.hp = manager.player.max_hp
	manager.player.block = 0
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var heal_card_id: String = ""
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card == null or not card.id.begins_with("kaltsit_"):
			continue
		for effect in card.effects:
			if effect != null and effect.effect_type == "heal" and effect.amount >= 2:
				heal_card_id = card.id
				break
		if not heal_card_id.is_empty():
			break
	if heal_card_id.is_empty():
		_fail("找不到凯尔希治疗牌用于溢出测试。")
		manager.dispose_runtime_state()
		manager.free()
		return
	manager.player.hp = manager.player.max_hp
	_play(manager, heal_card_id)
	if manager.player.block < 2:
		_fail("overflow_shielding：满血治疗溢出应转化为护盾，实际 %d。" % manager.player.block)
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_structural_compensation() -> void:
	var manager = _new_manager("kaltsit")
	_play(manager, "kaltsit_u16_structural_compensation")
	var bonus_before: int = int(manager.player.meta.get("mon3tr_next_attack_bonus", 0))
	manager.damage_mon3tr(3, "test")
	var bonus_after: int = int(manager.player.meta.get("mon3tr_next_attack_bonus", 0))
	if bonus_after <= bonus_before:
		_fail("structural_compensation：损失完整性应提升下次 Mon3tr 攻击（%d -> %d）。" % [bonus_before, bonus_after])
	manager.dispose_runtime_state()
	manager.free()

func _test_nearl_radiant_oath() -> void:
	var manager = _new_manager("nearl")
	_play(manager, "nearl_b04_radiant_oath")
	if manager.nearl_radiance() < 1:
		_fail("radiant_oath：应获得 1 层光耀，实际 %d。" % manager.nearl_radiance())
	_play(manager, "nearl_b04_radiant_oath")
	if manager.nearl_radiance() != 2:
		_fail("radiant_oath：第二次打出后光耀应为 2，实际 %d。" % manager.nearl_radiance())
	manager.dispose_runtime_state()
	manager.free()

func _test_nearl_counter_trigger() -> void:
	var manager = _new_manager("nearl")
	_play(manager, "nearl_b05_counter_guard")
	var counter_total: int = int(manager.player.meta.get("nearl_counter", 0))
	if counter_total != 3:
		_fail("counter_guard：反击应为 3，实际 %d。" % counter_total)
		manager.dispose_runtime_state()
		manager.free()
		return
	var enemy: UnitState = manager.enemies[0]
	enemy.block = 0
	var enemy_hp_before: int = enemy.hp
	manager.player.block = 5
	manager._route_enemy_damage(enemy, 3, {}, "test")
	var counter_dealt: int = enemy_hp_before - enemy.hp
	if counter_dealt != 3:
		_fail("counter_guard：受击应反击 3 点（counter 3 + 光耀 0），实际 %d。" % counter_dealt)
	manager.dispose_runtime_state()
	manager.free()

func _test_nearl_radiance_block_bonus() -> void:
	var manager = _new_manager("nearl")
	for i in range(4):
		_play(manager, "nearl_b04_radiant_oath")
	if manager.nearl_radiance() != 4:
		_fail("radiance：打出 4 次光耀誓言后光耀应为 4，实际 %d。" % manager.nearl_radiance())
	if manager.nearl_shield_bonus() != 2:
		_fail("radiance：4 层光耀应提供护盾加成 +2，实际 %d。" % manager.nearl_shield_bonus())
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var guard_pulse: CardData = db["nearl_b02_guard_pulse"]
	var base_block: int = 0
	for effect in guard_pulse.effects:
		if effect != null and effect.effect_type == "block":
			base_block = effect.amount
	manager.player.block = 0
	_play(manager, "nearl_b02_guard_pulse")
	# 基础 + 光耀加成 2 + 被动"光辉守卫"（每回合首张含护盾效果牌 +4）
	var expected_block: int = base_block + 2 + 4
	if manager.player.block != expected_block:
		_fail("radiance_block：护盾牌应得 %d（基础 %d + 光耀 2 + 被动 4），实际 %d。" % [expected_block, base_block, manager.player.block])
	_play(manager, "nearl_b04_radiant_oath")  # 重置能量并保持光耀
	manager.player.block = 0
	_play(manager, "nearl_b02_guard_pulse")
	var second_expected: int = base_block + 2
	if manager.player.block != second_expected:
		_fail("radiance_block：第二张护盾牌应得 %d（被动已消耗，基础 %d + 光耀 2），实际 %d。" % [second_expected, base_block, manager.player.block])
	manager.dispose_runtime_state()
	manager.free()

func _test_nearl_radiant_strike_conditional_heal() -> void:
	var manager = _new_manager("nearl")
	manager.player.hp = max(1, manager.player.max_hp - 5)
	var hp_no_block: int = manager.player.hp
	manager.player.block = 0
	_play(manager, "nearl_b03_radiant_strike")
	if manager.player.hp != hp_no_block:
		_fail("radiant_strike：无护盾时不应治疗（%d -> %d）。" % [hp_no_block, manager.player.hp])
	manager.player.hp = max(1, manager.player.max_hp - 5)
	var hp_with_block: int = manager.player.hp
	manager.player.block = 3
	_play(manager, "nearl_b03_radiant_strike")
	if manager.player.hp != hp_with_block + 1:
		_fail("radiant_strike：有护盾时应治疗 1（%d -> %d）。" % [hp_with_block, manager.player.hp])
	manager.dispose_runtime_state()
	manager.free()

func _test_amiya_resonance_mark() -> void:
	var manager = _new_manager("amiya")
	var enemy: UnitState = manager.enemies[0]
	_play(manager, "resonance_mark")
	if enemy.resonance != 3:
		_fail("resonance_mark：应施加 3 层共振，实际 %d。" % enemy.resonance)
	manager.dispose_runtime_state()
	manager.free()

func _test_amiya_resonance_decay() -> void:
	var manager = _new_manager("amiya")
	var enemy: UnitState = manager.enemies[0]
	_play(manager, "resonance_mark")
	manager._decay_enemy_resonance()
	if enemy.resonance != 2:
		_fail("resonance_decay：回合末共振应衰减至 2，实际 %d。" % enemy.resonance)
	manager.dispose_runtime_state()
	manager.free()

func _test_amiya_leader_passive() -> void:
	var manager = _new_manager("amiya")
	var enemy: UnitState = manager.enemies[0]
	enemy.block = 0
	_play(manager, "field_command")
	var arts_bonus: Dictionary = manager.player.meta.get("next_tag_damage_bonus", {})
	if int(arts_bonus.get("Arts", 0)) != 2:
		_fail("leader_passive：首张支援牌后下一张术式应 +2 伤害，实际加成 %d。" % int(arts_bonus.get("Arts", 0)))
		manager.dispose_runtime_state()
		manager.free()
		return
	var enemy_hp_before: int = enemy.hp
	_play(manager, "arts_bolt")
	var dealt: int = enemy_hp_before - enemy.hp
	if dealt != 8:
		_fail("leader_passive：术击应造成 6+2=8 伤害，实际 %d。" % dealt)
	manager.dispose_runtime_state()
	manager.free()

func _test_amiya_will_and_focused_ray() -> void:
	var manager = _new_manager("amiya")
	_play(manager, "mental_tuning")
	if manager.player.will != 1:
		_fail("mental_tuning：应获得 1 意志，实际 %d。" % manager.player.will)
	var enemy: UnitState = manager.enemies[0]
	enemy.block = 0
	manager.player.will = 3
	var enemy_hp_before: int = enemy.hp
	_play(manager, "focused_ray")
	var dealt: int = enemy_hp_before - enemy.hp
	if dealt != 13:
		_fail("focused_ray：意志>=3 时应造成 9+4=13 伤害，实际 %d。" % dealt)
	manager.dispose_runtime_state()
	manager.free()

func _draw_curse(manager, curse_id: String) -> CardData:
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var curse: CardData = db[curse_id]
	manager.deck.draw_pile.append(curse)
	manager._draw_cards(1, "curse_test")
	return curse

func _test_curse_lost_focus_on_draw() -> void:
	var manager = _new_manager("exusiai")
	var curse: CardData = _draw_curse(manager, "ex_s03_lost_focus")
	if not manager.deck.exhaust_pile.has(curse):
		_fail("lost_focus：抽到后应进入消耗堆。")
	if int(manager.player.meta.get("mark_apply_penalty_this_turn", 0)) != 1:
		_fail("lost_focus：抽到后应设置标记惩罚 1，实际 %d。" % int(manager.player.meta.get("mark_apply_penalty_this_turn", 0)))
		manager.dispose_runtime_state()
		manager.free()
		return
	var enemy: UnitState = manager.enemies[0]
	_play(manager, "ex_c09_red_dot_lock")  # 施加 3 标记
	if enemy.mark != 2:
		_fail("lost_focus：3 标记应被惩罚减为 2，实际 %d。" % enemy.mark)
	manager.dispose_runtime_state()
	manager.free()

func _test_curse_static_chatter_on_draw() -> void:
	var manager = _new_manager("exusiai")
	_draw_curse(manager, "ex_s07_static_chatter")
	if not bool(manager.player.meta.get("command_delay_active", false)):
		_fail("static_chatter：抽到后应激活支援延迟。")
		manager.dispose_runtime_state()
		manager.free()
		return
	manager.enemies[0].block = 0
	_play(manager, "ex_c29_delivery_burst")  # Support 牌
	if int(manager.player.meta.get("played_support_this_turn", 0)) != 0:
		_fail("static_chatter：第一张支援牌不应计入支援数，实际 %d。" % int(manager.player.meta.get("played_support_this_turn", 0)))
	manager.dispose_runtime_state()
	manager.free()

func _test_curse_medical_burden_on_draw() -> void:
	var manager = _new_manager("kaltsit")
	_draw_curse(manager, "kaltsit_s03_medical_burden")
	if int(manager.player.meta.get("medical_burden_penalty", 0)) != 3:
		_fail("medical_burden：抽到后应设置医疗惩罚 3，实际 %d。" % int(manager.player.meta.get("medical_burden_penalty", 0)))
		manager.dispose_runtime_state()
		manager.free()
		return
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var heal_card_id: String = ""
	var base_heal: int = 0
	for card_id in db.keys():
		var card: CardData = db[card_id] as CardData
		if card == null or not card.id.begins_with("kaltsit_") or not "Medical" in card.tags:
			continue
		for effect in card.effects:
			if effect != null and effect.effect_type == "heal" and effect.amount >= 4:
				heal_card_id = card.id
				base_heal = effect.amount
				break
		if not heal_card_id.is_empty():
			break
	if heal_card_id.is_empty():
		_fail("找不到凯尔希带 Medical 标签的治疗牌用于测试。")
		manager.dispose_runtime_state()
		manager.free()
		return
	manager.player.hp = max(1, manager.player.max_hp - 20)
	var hp_before: int = manager.player.hp
	_play(manager, heal_card_id)
	var healed: int = manager.player.hp - hp_before
	if healed != max(0, base_heal - 3):
		_fail("medical_burden：治疗 %d 应被减 3 至 %d，实际治疗 %d。" % [base_heal, max(0, base_heal - 3), healed])
	manager.dispose_runtime_state()
	manager.free()

func _test_curse_command_interference_on_draw() -> void:
	var manager = _new_manager("kaltsit")
	_draw_curse(manager, "kaltsit_s05_command_interference")
	if int(manager.player.meta.get("mon3tr_next_attack_bonus", 0)) != -4:
		_fail("command_interference：抽到后应设置下次 Mon3tr 攻击 -4，实际 %d。" % int(manager.player.meta.get("mon3tr_next_attack_bonus", 0)))
		manager.dispose_runtime_state()
		manager.free()
		return
	var enemy: UnitState = manager.enemies[0]
	enemy.block = 0
	var enemy_hp_before: int = enemy.hp
	manager.mon3tr_attack(enemy, 10, null)
	var dealt: int = enemy_hp_before - enemy.hp
	if dealt != 6:
		_fail("command_interference：10 点 Mon3tr 攻击应减为 6，实际 %d。" % dealt)
	if int(manager.player.meta.get("mon3tr_next_attack_bonus", 0)) != 0:
		_fail("command_interference：惩罚应在一次攻击后消耗。")
	manager.dispose_runtime_state()
	manager.free()

func _test_kaltsit_s07_status_conditions() -> void:
	var manager = _new_manager("kaltsit")
	var integrity_before: int = manager.mon3tr_integrity()
	_play(manager, "kaltsit_s07_unstable_meltdown")  # 非融毁：应 +1
	if manager.mon3tr_integrity() != integrity_before + 1:
		_fail("s07：非融毁时应修复 1 点完整性（%d -> %d）。" % [integrity_before, manager.mon3tr_integrity()])
	manager.enter_kaltsit_meltdown()
	integrity_before = manager.mon3tr_integrity()
	_play(manager, "kaltsit_s07_unstable_meltdown")  # 融毁：应 -2
	if manager.mon3tr_integrity() >= integrity_before:
		_fail("s07：融毁时应失去 2 点完整性（%d -> %d）。" % [integrity_before, manager.mon3tr_integrity()])
	manager.dispose_runtime_state()
	manager.free()
