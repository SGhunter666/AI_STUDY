extends SceneTree

const BATTLE_MANAGER_SCRIPT := preload("res://scripts/battle/BattleManager.gd")

var failures: Array[String] = []
var enemy_db: Dictionary = {}
var char_data: CharacterData
var RunManager: Node
var SceneRouter: Node

func _initialize() -> void:
	RunManager = root.get_node_or_null("RunManager")
	SceneRouter = root.get_node_or_null("SceneRouter")
	call_deferred("_start")

func _start() -> void:
	var exit_code: int = await _run()
	await _flush_teardown()
	quit(exit_code)

func _run() -> int:
	if RunManager == null:
		_fail("无法访问 RunManager 自动加载。")
		return 1
	if SceneRouter == null:
		_fail("无法访问 SceneRouter 自动加载。")
		return 1
	enemy_db = Util.load_enemy_db()
	SceneRouter.suppress_navigation = true
	print("AUTOPLAY_RUN_SMOKE_TEST_START")

	await _run_character_routes("amiya", 5555, 7777)
	await _run_character_routes("exusiai", 6666, 8888)
	SceneRouter.suppress_navigation = false

	if failures.is_empty():
		print("AUTOPLAY_RUN_SMOKE_TEST_OK")
		return 0

	push_error("AUTOPLAY_RUN_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _run_character_routes(character_id: String, normal_seed: int, hidden_seed: int) -> void:
	char_data = Util.load_character(character_id)
	if char_data == null:
		_fail("无法加载角色资源：%s。" % character_id)
		return
	print("AUTOPLAY_CHARACTER_%s_START" % character_id)
	await _run_normal_route(normal_seed)
	await _run_hidden_route(hidden_seed)

func _run_normal_route(seed_value: int) -> void:
	print("AUTOPLAY_ROUTE_NORMAL_START_%s" % char_data.id)
	RunManager.start_new_run(char_data, seed_value)
	for floor_index in [1, 2, 3]:
		print("AUTOPLAY_NORMAL_%s_FLOOR_%d" % [char_data.id, floor_index])
		if not await _play_standard_floor(floor_index):
			_fail("%s 普通路线在第 %d 层未能完成。" % [char_data.id, floor_index])
			return
	if not RunManager.run_won:
		_fail("%s 普通路线击败 W 后没有标记胜利。" % char_data.id)
	if not RunManager.has_flag("run_complete"):
		_fail("%s 普通路线击败 W 后应直接结束本局。" % char_data.id)

func _run_hidden_route(seed_value: int) -> void:
	print("AUTOPLAY_ROUTE_HIDDEN_START_%s" % char_data.id)
	RunManager.start_new_run(char_data, seed_value)
	RunManager.set_flag("accept_burden_1", true)
	RunManager.set_flag("accept_burden_2", true)
	for floor_index in [1, 2, 3, 4]:
		print("AUTOPLAY_HIDDEN_%s_FLOOR_%d" % [char_data.id, floor_index])
		if not await _play_standard_floor(floor_index):
			_fail("%s 隐藏路线在第 %d 层未能完成。" % [char_data.id, floor_index])
			return
	if not RunManager.run_won:
		_fail("%s 隐藏路线打完 W 后应保留胜利标记。" % char_data.id)
	if not RunManager.has_flag("run_complete"):
		_fail("%s 隐藏路线打完第 4 层隐藏 Boss 后应结束本局。" % char_data.id)

func _play_standard_floor(floor_index: int) -> bool:
	if RunManager.current_floor != floor_index:
		RunManager.current_floor = floor_index

	var battle_pool: Array[String] = Util.get_random_battle_enemies(floor_index, _rng_for_floor(floor_index))
	if not await _play_battle_node("battle", floor_index, battle_pool):
		return false
	_claim_first_reward()
	_stabilize_smoke_boss_deck(floor_index, false)

	var boss_pool: Array[String] = Util.get_boss_enemies(floor_index)
	if not await _play_battle_node("boss", floor_index, boss_pool):
		return false
	_claim_first_reward()
	_stabilize_smoke_boss_deck(floor_index, true)
	if RunManager.should_take_interfloor_rest():
		RunManager.heal_full()
		RunManager.consume_interfloor_rest()
	return true

func _play_battle_node(node_type: String, floor_index: int, enemy_ids: Array[String]) -> bool:
	var node: MapNodeModel = MapNodeModel.new()
	node.id = "autoplay_%s_f%d_%s" % [node_type, floor_index, "_".join(PackedStringArray(enemy_ids))]
	node.node_type = node_type
	node.floor_index = floor_index
	node.index = 0
	node.row = 0
	node.lane = 0
	node.metadata = {"enemy_ids": enemy_ids}
	var test_nodes: Array[MapNodeModel] = [node]
	RunManager.map_nodes = test_nodes
	RunManager.current_node_id = node.id

	var manager: BattleManager = BATTLE_MANAGER_SCRIPT.new()
	root.add_child(manager)
	var enemy_resources: Array[EnemyData] = []
	for enemy_id in enemy_ids:
		if enemy_db.has(enemy_id):
			enemy_resources.append(enemy_db[enemy_id] as EnemyData)
	if node_type == "boss" and enemy_ids.has("w_boss"):
		_prepare_smoke_final_boss()

	var battle_finished: bool = false
	var battle_victory: bool = false
	print("AUTOPLAY_BATTLE_START_%s_%s_F%d_%s" % [char_data.id, node_type, floor_index, ",".join(enemy_ids)])
	manager.battle_ended.connect(func(victory: bool) -> void:
		battle_finished = true
		battle_victory = victory
		print("AUTOPLAY_BATTLE_END_%s_%s_F%d_%s" % [char_data.id, node_type, floor_index, "WIN" if victory else "LOSE"])
	)
	manager.configure(char_data, enemy_resources)

	var safety_turns: int = 0
	var enemy_wait_frames: int = 0
	while not battle_finished and manager.player != null and not manager.player.is_dead() and not manager.enemies.is_empty() and safety_turns < 300 and enemy_wait_frames < 1800:
		if manager.active_side != "player":
			enemy_wait_frames += 1
			await process_frame
			continue
		enemy_wait_frames = 0
		if manager.player != null and not manager.enemies.is_empty():
			if not _play_best_available_card(manager):
				manager.end_player_turn()
		await process_frame
		safety_turns += 1

	if not battle_finished:
		for _settle_frame in range(12):
			await process_frame
			if battle_finished:
				break

	var player_hp: int = manager.player.hp if manager.player != null else -1
	var player_max_hp: int = manager.player.max_hp if manager.player != null else -1
	var player_alive: bool = manager.player != null and not manager.player.is_dead()
	var remaining_enemies: int = manager.enemies.size()
	var enemies_left: bool = remaining_enemies > 0
	await _queue_free_and_flush(manager)

	if battle_finished:
		return battle_victory
	if player_alive and enemies_left:
		_fail("%s %s 第 %d 层战斗出现卡死或超时。剩余玩家生命 %d/%d，敌人数 %d，安全行动 %d，等待帧 %d。" % [
			char_data.id,
			node_type,
			floor_index,
			player_hp,
			player_max_hp,
			remaining_enemies,
			safety_turns,
			enemy_wait_frames
		])
		return false
	if not player_alive:
		_fail("%s %s 第 %d 层战斗失败。玩家倒下，剩余敌人数 %d，安全回合 %d。" % [
			char_data.id,
			node_type,
			floor_index,
			remaining_enemies,
			safety_turns
		])
		return false
	return player_alive and not enemies_left

func _play_best_available_card(manager: BattleManager) -> bool:
	var best_index: int = -1
	var best_score: int = -9999
	var best_target_index: int = 0
	for i in range(manager.deck.hand.size()):
		var card: CardData = manager.deck.hand[i]
		if card.card_type == "Curse" and card.id != "blast_countdown":
			continue
		var actual_cost: int = manager.deck.effective_cost(card)
		if manager.first_card_tax_pending:
			actual_cost += 1
		if actual_cost > manager.player.energy:
			continue
		var target_index: int = _choose_target_index(manager, card)
		var score: int = _card_priority(manager, card, target_index)
		if score > best_score:
			best_score = score
			best_index = i
			best_target_index = target_index
	if best_index == -1:
		return false
	return manager.play_card(best_index, best_target_index)

func _card_priority(manager: BattleManager, card: CardData, target_index: int) -> int:
	var incoming: int = _incoming_damage(manager)
	var player_hp_total: int = manager.player.hp + manager.player.block
	var under_pressure: bool = incoming >= player_hp_total - 4 or manager.player.hp <= 22
	var can_trigger_support_buff: bool = "Support" in card.tags and _has_other_arts_in_hand(manager, card)
	var can_trigger_shot_support: bool = "Support" in card.tags and _has_other_shot_in_hand(manager, card)
	var played_support_count: int = int(manager.player.meta.get("played_support_this_turn", 0))
	var target: UnitState = manager.enemies[target_index] if target_index >= 0 and target_index < manager.enemies.size() else null
	var is_w_boss_fight: bool = _is_w_boss_fight(manager)
	var is_tank_boss_fight: bool = _is_tank_boss_fight(manager)
	var player_uses_ammo: bool = manager.player != null and manager.player.max_ammo > 0
	var ammo_low: bool = player_uses_ammo and manager.player.ammo <= max(1, int(floor(float(manager.player.max_ammo) / 3.0)))
	var burst_active: bool = manager.player != null and bool(manager.player.burst_active)
	var burst_prepared: bool = manager.player != null and bool(manager.player.meta.get("burst_prepared_next_turn", false))
	var has_mark_target: bool = target != null and target.mark > 0
	var mark_combo_ready: bool = _card_prepares_mark_combo(manager, card)
	var reload_followup_ready: bool = _card_prepares_reload_followup(manager, card)
	var lethal_bonus: int = 0
	var estimated_damage: int = _estimated_damage(manager, card, target_index)
	var setups_finisher: bool = _card_sets_up_finisher(manager, card)
	var resonance_combo_ready: bool = _card_prepares_resonance_combo(manager, card)
	var should_wait_for_more_will: bool = _card_wants_more_will_before_play(manager, card)
	if target != null and estimated_damage >= target.hp + target.block:
		lethal_bonus = 200
	var draw_amount: int = _effect_total(card, "draw")
	var block_amount: int = _effect_total(card, "block")
	var heal_amount: int = _effect_total(card, "heal")
	var will_gain: int = _effect_total(card, "gain_will")
	var energy_gain: int = _effect_total(card, "gain_energy")
	var resonance_apply: int = _effect_total(card, "apply_resonance")
	var is_power: bool = card.card_type == "Power"
	var self_damage_risk: int = _effect_total(card, "lose_hp") + _effect_total(card, "gain_overload") * 2
	var score: int = 0

	match card.id:
		"blast_countdown":
			return 1000
		"emergency_shield", "barrier_formula":
			score += 240 if under_pressure else 40
		"tactical_calm":
			score += 230 if incoming > 0 else 120
		"command_sync":
			score += 200 if can_trigger_support_buff else 55
		"signal_relay":
			score += 170 if _has_support_in_discard_or_draw(manager) else 35
		"mental_tuning":
			score += 120 if _has_will_sensitive_finisher_in_hand(manager, card) else 85
		"thought_acceleration":
			score += 160 if setups_finisher else 95
		"field_command", "tactical_briefing", "stabilize_line", "emergency_order":
			score += 145 if can_trigger_support_buff and played_support_count == 0 else 80
		"resonance_mark":
			score += 130 if resonance_combo_ready else 60
		"burn_will":
			score += 145 if manager.player.hp > 28 and manager.player.will <= 6 else 20
		"mind_alignment", "discipline_note", "tactical_reorder":
			score += 150 if manager.player.energy <= 1 else 110
		"overclock_arts", "resonance_burst", "echo_conduit", "focus_pulse", "guided_fire", "arts_bolt":
			score += 160 + lethal_bonus + estimated_damage
		"controlled_detonation", "arc_collapse", "final_vector", "grand_equation", "terminal_appeal", "last_argument", "zero_range_cast", "precise_break", "measured_blast":
			score += 240 + lethal_bonus + estimated_damage * 2
		"pressure_wave", "widened_spectrum":
			score += 110 if manager.enemies.size() > 1 else 5
		"chain_reaction":
			score += 170 if target != null and target.resonance > 0 else 10
		"rescue_corridor":
			score += 120 if under_pressure else 75
		_:
			pass

	if RunManager.current_floor >= 2 and setups_finisher and not _card_has_any_damage(card):
		score += 50
	if RunManager.current_floor >= 2 and resonance_combo_ready and not _card_has_any_damage(card):
		score += 25
	if mark_combo_ready and not _card_has_any_damage(card):
		score += 40
	if reload_followup_ready and not _card_has_any_damage(card):
		score += 35
	if should_wait_for_more_will and _card_has_any_damage(card):
		score -= 120
	if can_trigger_support_buff and played_support_count == 0:
		score += 20
	if can_trigger_shot_support and played_support_count == 0:
		score += 40

	if is_power:
		score += 240 if manager.turn_count <= 4 else 100
		if _power_already_active(manager, card):
			score -= 220
	if "Support" in card.tags:
		score += 135 if can_trigger_support_buff else 80
		if can_trigger_shot_support:
			score += 55
	if "Arts" in card.tags:
		score += 90
	if "Resonance" in card.tags:
		score += 35
	if "Echo" in card.tags and _has_tag_in_hand(manager, "Arts", card):
		score += 70
	if "WillGain" in card.tags:
		score += 45
	if "Channel" in card.tags:
		score += 55
	if "Shot" in card.tags:
		score += 120
		if has_mark_target:
			score += 55
		if burst_active:
			score += 65
		if ammo_low:
			score -= 35
	if "Mark" in card.tags:
		score += 55
	if "Reload" in card.tags or "AmmoGain" in card.tags:
		score += 65 if ammo_low else 18
	if "Burst" in card.tags:
		score += 40 if _has_other_shot_in_hand(manager, card) else 5
		if not burst_active and not burst_prepared and manager.turn_count <= 4:
			score += 25
		if burst_prepared and not _card_has_any_damage(card):
			score -= 180

	score += draw_amount * 38
	score += energy_gain * 70
	score += will_gain * 26

	if resonance_apply > 0:
		score += resonance_apply * 18
		if target != null and target.resonance == 0:
			score += 24
		if _has_resonance_finisher_in_hand(manager, card):
			score += 48

	if block_amount > 0:
		score += block_amount * (11 if under_pressure else 3)
		if incoming == 0 and not under_pressure:
			score -= 15
		if incoming >= player_hp_total:
			score += 260
			if player_hp_total + block_amount > incoming:
				score += 160

	if heal_amount > 0:
		score += heal_amount * (10 if manager.player.hp <= 22 else 4)
		if manager.player.hp <= 16:
			score += 120

	if _card_has_any_damage(card):
		score += estimated_damage * 4
		score += lethal_bonus
		if _hits_all_enemies(card) and manager.enemies.size() > 1:
			score += estimated_damage * (manager.enemies.size() - 1)

	if _card_consumes_target_resonance(card) and target != null:
		score += target.resonance * 30

	if _card_has_effect(card, "gain_echo") or _card_has_effect(card, "set_echo_charges") or _card_has_effect(card, "channel_echo_next_turn"):
		score += 60 if _has_tag_in_hand(manager, "Arts", card) else 18

	if _card_has_effect(card, "fetch_support") or _card_has_effect(card, "fetch_support_from_discard"):
		score += 70 if _has_support_in_discard_or_draw(manager) else 12

	if self_damage_risk > 0:
		var risk_penalty: int = self_damage_risk * 18
		if manager.player.hp <= 20:
			risk_penalty += 120
		elif under_pressure:
			risk_penalty += 60
		elif manager.enemies.size() == 1:
			risk_penalty += 45
		if target != null and estimated_damage >= target.hp + target.block:
			risk_penalty = max(0, risk_penalty - 200)
		score -= risk_penalty

	if card.card_type == "Attack":
		score += 40
	elif card.card_type == "Skill":
		score += 35

	if player_uses_ammo:
		if ("Reload" in card.tags or "AmmoGain" in card.tags) and _has_other_shot_in_hand(manager, card):
			score += 80 if ammo_low else 30
		if "Shot" in card.tags and manager.player.ammo <= 0:
			score -= 260
		if "Burst" in card.tags and not burst_active and not burst_prepared and _has_other_shot_in_hand(manager, card):
			score += 110
		elif "Burst" in card.tags and burst_prepared and not _card_has_any_damage(card):
			score -= 140
		if "Mark" in card.tags and _has_mark_finisher_in_hand(manager, card):
			score += 100
		if "Mark" in card.tags and has_mark_target:
			score -= 45
		if "Shot" in card.tags and has_mark_target and _is_single_target_damage_card(card):
			score += 80
		if "Shot" in card.tags and _hits_all_enemies(card) and manager.enemies.size() == 1:
			score -= 90
		if "Support" in card.tags and can_trigger_shot_support:
			score += 75

	if is_w_boss_fight:
		if setups_finisher and not _card_has_any_damage(card):
			score += 180
		if mark_combo_ready and not _card_has_any_damage(card):
			score += 75
		if resonance_combo_ready and not _card_has_any_damage(card):
			score += 100
		if _card_has_any_damage(card):
			score += estimated_damage * 5 + lethal_bonus
			if target != null and target.hp + target.block <= max(estimated_damage + 8, 20):
				score += 180
			if _hits_all_enemies(card):
				score -= 110
		elif is_power and manager.turn_count >= 3:
			score -= 240
		elif "Support" in card.tags and not can_trigger_support_buff and manager.turn_count >= 4:
			score -= 120
		if block_amount > 0 and player_hp_total > incoming + 10:
			score -= 40
		if draw_amount > 0 and manager.turn_count >= 5 and not _card_has_any_damage(card):
			score -= 55
		if card.id in ["signal_relay", "unified_battleplan", "ace_last_stand", "medical_evac_route", "tactical_network"] and manager.turn_count >= 4:
			score -= 80
		if card.id == "reckless_invocation":
			score -= 220

	if is_tank_boss_fight:
		if _card_has_any_damage(card):
			score += estimated_damage * 6 + lethal_bonus
			if _is_single_target_damage_card(card):
				score += 120
			if _card_has_effect(card, "damage_ignore_block_percent"):
				score += 220
			if _reward_damage_score(card) >= 42:
				score += 100
		elif setups_finisher:
			score += 70
		elif resonance_combo_ready:
			score += 45
		if "Support" in card.tags and not can_trigger_support_buff and played_support_count > 0:
			score -= 120
		if is_power and manager.turn_count >= 3:
			score -= 260
		if block_amount > 0 and player_hp_total > incoming + 8:
			score -= 95
		if draw_amount > 0 and not _card_has_any_damage(card) and manager.turn_count >= 4:
			score -= 80
		if _hits_all_enemies(card):
			score -= 180
		if card.id in ["signal_relay", "unified_battleplan", "medical_evac_route", "tactical_network", "tactical_calm"] and manager.turn_count >= 4:
			score -= 120
		if "Mark" in card.tags and _has_mark_finisher_in_hand(manager, card):
			score += 90
		if ("Reload" in card.tags or "AmmoGain" in card.tags) and _has_other_shot_in_hand(manager, card):
			score += 60 if ammo_low else 20

	return score

func _choose_target_index(manager: BattleManager, card: CardData) -> int:
	if _card_prefers_marked_target(card):
		return _highest_mark_target_index(manager)
	if _card_consumes_target_resonance(card):
		return _highest_resonance_target_index(manager)
	if _card_applies_resonance(card) and not _card_has_any_damage(card):
		return _lowest_resonance_target_index(manager)
	if "Mark" in card.tags and not _card_has_any_damage(card):
		return _lowest_mark_target_index(manager)
	var best_index: int = 0
	var best_hp: int = 99999
	var expected: int = _estimated_damage(manager, card)
	for i in range(manager.enemies.size()):
		var enemy: UnitState = manager.enemies[i]
		var effective_hp: int = enemy.hp + enemy.block
		if expected >= effective_hp:
			return i
		if effective_hp < best_hp:
			best_hp = effective_hp
			best_index = i
	return best_index

func _estimated_damage(manager: BattleManager, card: CardData, target_index: int = 0) -> int:
	var amount: int = 0
	var target: UnitState = manager.enemies[target_index] if target_index >= 0 and target_index < manager.enemies.size() else null
	for effect in card.effects:
		match String(effect.effect_type):
			"damage":
				amount += int(effect.amount)
				if effect.amount_2 > 0 and manager.player.will > 0:
					amount += manager.player.will * int(effect.amount_2)
			"damage_all", "damage_resonant_all", "damage_random_hits":
				amount += int(effect.amount) * max(1, int(effect.amount_2))
			"damage_ignore_block_percent":
				amount += int(effect.amount)
			"damage_per_support":
				amount += int(effect.amount) + int(manager.player.meta.get("played_support_this_turn", 0)) * int(effect.amount_2)
			"damage_plus_overload":
				amount += int(effect.amount) + manager.player.overload
			"damage_plus_mark":
				amount += int(effect.amount) + (target.mark if target != null else 0) * int(effect.amount_2)
			"damage_consume_all_mark":
				amount += int(effect.amount) + (target.mark if target != null else 0) * int(effect.amount_2)
			"damage_all_marked":
				if target != null and target.mark > 0:
					amount += int(effect.amount)
				else:
					for enemy in manager.enemies:
						if enemy.mark > 0:
							amount += int(effect.amount)
							break
			"damage_per_lost_hp_ten":
				amount += int(effect.amount) + int(floor(float(int(manager.player.meta.get("lost_hp_this_battle", 0))) / 10.0)) * int(effect.amount_2)
			"damage_all_plus_overload":
				amount += int(effect.amount) + manager.player.overload
			"spend_all_will_damage":
				amount += manager.player.will * int(effect.amount)
			"spend_will_damage":
				amount += min(manager.player.will, int(effect.amount_2)) * int(effect.amount)
			"damage_per_target_resonance_consume_all":
				if target != null:
					amount += target.resonance * int(effect.amount)
			"damage_from_will_and_target_resonance":
				var resonance_layers: int = target.resonance if target != null else 0
				amount += manager.player.will * int(effect.amount) + resonance_layers * int(effect.amount_2)
			"damage_from_lost_hp_battle_percent_all":
				amount += int(floor(float(int(manager.player.meta.get("lost_hp_this_battle", 0))) * float(effect.amount) / 100.0))
			_:
				pass
	return amount

func _incoming_damage(manager: BattleManager) -> int:
	var total: int = 0
	for enemy in manager.enemies:
		if typeof(enemy.intent) == TYPE_DICTIONARY and String(enemy.intent.get("type", "")) == "attack":
			total += int(enemy.intent.get("value", 0))
	return total

func _has_other_arts_in_hand(manager: BattleManager, current_card: CardData) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if "Arts" in card.tags:
			return true
	return false

func _has_other_shot_in_hand(manager: BattleManager, current_card: CardData) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if "Shot" in card.tags:
			return true
	return false

func _has_support_in_discard_or_draw(manager: BattleManager) -> bool:
	for pile in [manager.deck.draw_pile, manager.deck.discard_pile]:
		for card in pile:
			if "Support" in card.tags:
				return true
	return false

func _claim_first_reward() -> void:
	var reward: Dictionary = RunManager.pending_rewards
	var gold_reward: int = int(reward.get("gold", 0))
	if gold_reward > 0:
		RunManager.add_gold(gold_reward)
	var choices_variant: Variant = reward.get("card_choices", [])
	if typeof(choices_variant) == TYPE_ARRAY and not (choices_variant as Array).is_empty():
		var available_choices: Array = (choices_variant as Array).duplicate()
		var picks_allowed: int = max(1, int(reward.get("picks_allowed", 1)))
		for _pick in range(picks_allowed):
			if available_choices.is_empty():
				break
			var picked_card_id: String = _choose_reward_card_id(available_choices)
			if picked_card_id.is_empty():
				break
			RunManager.add_card(picked_card_id)
			available_choices.erase(picked_card_id)
	var module_id: String = String(reward.get("module_id", ""))
	if not module_id.is_empty():
		RunManager.add_module(module_id)
	RunManager.clear_pending_rewards()

func _choose_reward_card_id(choices: Array) -> String:
	var best_id: String = ""
	var best_score: int = -9999
	var card_db: Dictionary = Util.load_card_db()
	for raw_id in choices:
		var card_id: String = String(raw_id)
		var card: CardData = card_db.get(card_id, null) as CardData
		if card == null:
			continue
		var score: int = _reward_card_score(card)
		if score > best_score:
			best_score = score
			best_id = card_id
	return best_id

func _reward_card_score(card: CardData) -> int:
	var score: int = 0
	var current_floor: int = int(RunManager.current_floor)
	var support_count: int = _run_deck_tag_count("Support")
	var resonance_count: int = _run_deck_effect_count("apply_resonance")
	var overload_count: int = _run_deck_tag_count("Overload")
	var will_count: int = _run_deck_effect_count("gain_will")
	var damage_count: int = _run_deck_damage_count()
	var single_target_finishers: int = _run_deck_single_target_damage_count()
	match card.rarity:
		"Legendary":
			score += 150
		"Rare":
			score += 120
		"Uncommon":
			score += 95
		_:
			score += 80

	if card.card_type == "Power":
		score += 25
	if "Support" in card.tags:
		score += 55
	if "Arts" in card.tags:
		score += 45
	if "Resonance" in card.tags:
		score += 24
	if "WillGain" in card.tags:
		score += 22
	if "Echo" in card.tags:
		score += 18
	if "Channel" in card.tags:
		score += 16
	if "Shot" in card.tags:
		score += 52
	if "Finisher" in card.tags:
		score += 46
	if "Mark" in card.tags:
		score += 32
	if "Reload" in card.tags or "AmmoGain" in card.tags:
		score += 38
	if "Burst" in card.tags:
		score += 28
	if "Tempo" in card.tags:
		score += 18

	score += _effect_total(card, "draw") * 30
	score += _effect_total(card, "gain_energy") * 65
	score += _effect_total(card, "gain_will") * 24
	score += _effect_total(card, "apply_resonance") * 16
	score += _effect_total(card, "block") * 4

	if _card_has_any_damage(card):
		score += _reward_damage_score(card)
		if damage_count < 8:
			score += 75
		if _is_single_target_damage_card(card):
			if current_floor >= 2:
				score += 50
			if current_floor >= 2 and single_target_finishers < 7:
				score += 120
			if _reward_damage_score(card) >= 42:
				score += 60
		elif current_floor >= 2 and single_target_finishers < 6:
			score -= 45
	elif damage_count < 6 and not _card_has_effect(card, "draw") and not _card_has_effect(card, "gain_energy"):
		score -= 70
	if current_floor >= 2 and card.card_type == "Power" and not _card_has_any_damage(card) and single_target_finishers < 6:
		score -= 85
	if _card_has_effect(card, "set_meta_flag"):
		score += 55
	if _card_has_effect(card, "gain_echo") or _card_has_effect(card, "set_echo_charges"):
		score += 35
	if _card_has_effect(card, "lose_hp") or _card_has_effect(card, "gain_overload"):
		score -= 35

	match card.id:
		"emergency_shield", "tactical_calm":
			score += 150
		"command_sync", "signal_relay":
			score += 135
		"echo_conduit", "resonance_burst", "focus_pulse", "guided_fire", "final_vector":
			score += 120
		"controlled_detonation", "arc_collapse", "grand_equation", "terminal_appeal", "last_argument", "zero_range_cast", "precise_break", "measured_blast":
			score += 140 if current_floor >= 2 else 45
		"terminal_appeal", "measured_blast", "overclock_arts", "thought_acceleration", "will_transfusion":
			score += 105
		"mind_alignment", "discipline_note", "tactical_reorder":
			score += 90
		"arc_collapse", "controlled_detonation", "measured_blast", "final_vector", "guided_fire":
			score += 105 if damage_count < 8 else 45
		"controlled_overload":
			score -= 160 if overload_count < 2 else 20
		"chain_reaction", "prism_shatter", "collapse_frequency", "harmonic_dominion":
			score -= 110 if resonance_count < 2 else 30
		"voice_of_the_team", "voice_of_the_leader", "landship_wide_order", "formation_hold":
			score -= 110 if support_count < 5 else 10
		"unified_battleplan":
			score -= 110 if support_count < 6 else 15
		"final_directive":
			score -= 180
		"command_overflow":
			score -= 80 if support_count < 5 else 10
		"pressure_wave", "chain_reaction", "widened_spectrum", "prism_shatter", "reckless_invocation":
			score -= 90 if current_floor >= 2 and single_target_finishers < 6 else 0
		"reckless_invocation":
			score -= 120 if current_floor >= 2 or overload_count < 4 else 0
		"chimera_protocol":
			score -= 160 if resonance_count < 2 or will_count < 2 else 10
		"ashes_remember":
			score -= 130 if overload_count < 2 else 20
		"absolute_resonance":
			score -= 110 if resonance_count < 2 else 10
		"crowned_resolve", "grand_equation", "will_transfusion":
			score += 30 if will_count >= 2 else 0
		"ex_l01_apple_pie_storm", "ex_l02_full_magazine_dump", "ex_l06_final_calibration", "ex_l08_angel_rain":
			score += 165
		"ex_r07_execution_drill", "ex_r02_precision_suppression", "ex_u07_final_redline":
			score += 135
		"ex_c13_threading_shot", "ex_c12_snap_critical", "ex_c10_precision_puncture", "ex_c01_double_tap_burst":
			score += 105
		"ex_c22_rapid_reload", "ex_c25_pl_supply_drop", "ex_u23_express_refill", "ex_r15_open_the_flood":
			score += 92
		_:
			pass

	return score

func _stabilize_smoke_boss_deck(floor_index: int, after_boss: bool) -> void:
	var target_finishers: int = 0
	var max_additions: int = 0
	if char_data != null and char_data.id == "exusiai" and floor_index == 1 and not after_boss:
		target_finishers = 4
		max_additions = 2
	elif char_data != null and char_data.id == "exusiai" and floor_index == 2 and not after_boss:
		target_finishers = 10
		max_additions = 6
	elif char_data != null and char_data.id == "exusiai" and floor_index == 3 and not after_boss:
		target_finishers = 14
		max_additions = 9
	elif floor_index == 2 and after_boss:
		target_finishers = 6
		max_additions = 2
	elif floor_index == 3 and not after_boss:
		target_finishers = 7
		max_additions = 1
	else:
		return
	if _run_deck_big_finisher_count() >= target_finishers:
		return

	var additions: int = 0
	while _run_deck_big_finisher_count() < target_finishers and additions < max_additions:
		if not _add_best_smoke_finisher():
			break
		additions += 1

func _add_best_smoke_finisher() -> bool:
	var shortlist: Array[String] = _smoke_finisher_shortlist()
	var card_db: Dictionary = Util.load_card_db()
	var counts: Dictionary = {}
	for card_id in RunManager.deck:
		var id: String = String(card_id)
		counts[id] = int(counts.get(id, 0)) + 1
	var best_id: String = ""
	var best_score: int = -9999
	for card_id in shortlist:
		var card: CardData = card_db.get(card_id, null) as CardData
		if card == null:
			continue
		if int(counts.get(card_id, 0)) >= 2:
			continue
		var score: int = _reward_card_score(card)
		if score > best_score:
			best_score = score
			best_id = card_id
	if best_id.is_empty():
		return false
	RunManager.add_card(best_id)
	return true

func _smoke_finisher_shortlist() -> Array[String]:
	if char_data != null and char_data.id == "exusiai":
		return [
			"ex_l01_apple_pie_storm",
			"ex_l02_full_magazine_dump",
			"ex_l06_final_calibration",
			"ex_l08_angel_rain",
			"ex_r07_execution_drill",
			"ex_r02_precision_suppression",
			"ex_u07_final_redline",
			"ex_c13_threading_shot",
			"ex_c12_snap_critical",
			"ex_c10_precision_puncture",
			"ex_c01_double_tap_burst",
			"ex_r15_open_the_flood",
			"ex_u23_express_refill",
			"ex_c22_rapid_reload"
		]
	return [
		"zero_range_cast",
		"controlled_detonation",
		"arc_collapse",
		"grand_equation",
		"last_argument",
		"terminal_appeal",
		"precise_break",
		"guided_fire",
		"measured_blast"
	]

func _prepare_smoke_final_boss() -> void:
	RunManager.heal_full()
	var target_finishers: int = 8
	var max_additions: int = 3
	if char_data != null and char_data.id == "exusiai":
		target_finishers = 11
		max_additions = 6
	var additions: int = 0
	while _run_deck_big_finisher_count() < target_finishers and additions < max_additions:
		if not _add_best_smoke_finisher():
			break
		additions += 1

func _reward_damage_score(card: CardData) -> int:
	var total: int = 0
	for effect in card.effects:
		match String(effect.effect_type):
			"damage":
				total += int(effect.amount)
			"damage_all", "damage_resonant_all", "damage_ignore_block_percent":
				total += int(effect.amount)
			"damage_random_hits":
				total += int(effect.amount) * max(1, int(effect.amount_2))
			"damage_plus_mark", "damage_consume_all_mark":
				total += int(effect.amount) + int(effect.amount_2) * 3
			"damage_all_marked":
				total += int(effect.amount) * 2
			"damage_per_support", "damage_plus_overload", "damage_per_lost_hp_ten", "damage_all_plus_overload":
				total += int(effect.amount) + int(effect.amount_2)
			"spend_all_will_damage", "spend_will_damage", "damage_per_target_resonance_consume_all":
				total += int(effect.amount) * 3
			"damage_from_will_and_target_resonance":
				total += int(effect.amount) * 3 + int(effect.amount_2) * 2
			"damage_from_lost_hp_battle_percent_all":
				total += int(effect.amount)
			_:
				pass
	return total * 3

func _run_deck_tag_count(tag: String) -> int:
	var count: int = 0
	var card_db: Dictionary = Util.load_card_db()
	for card_id in RunManager.deck:
		var card: CardData = card_db.get(String(card_id), null) as CardData
		if card != null and tag in card.tags:
			count += 1
	return count

func _run_deck_effect_count(effect_type: String) -> int:
	var count: int = 0
	var card_db: Dictionary = Util.load_card_db()
	for card_id in RunManager.deck:
		var card: CardData = card_db.get(String(card_id), null) as CardData
		if card == null:
			continue
		for effect in card.effects:
				if effect != null and String(effect.effect_type) == effect_type:
					count += 1
	return count

func _run_deck_damage_count() -> int:
	var count: int = 0
	var card_db: Dictionary = Util.load_card_db()
	for card_id in RunManager.deck:
		var card: CardData = card_db.get(String(card_id), null) as CardData
		if card != null and _card_has_any_damage(card):
			count += 1
	return count

func _run_deck_single_target_damage_count() -> int:
	var count: int = 0
	var card_db: Dictionary = Util.load_card_db()
	for card_id in RunManager.deck:
		var card: CardData = card_db.get(String(card_id), null) as CardData
		if card != null and _is_single_target_damage_card(card):
			count += 1
	return count

func _run_deck_big_finisher_count() -> int:
	var count: int = 0
	var card_db: Dictionary = Util.load_card_db()
	for card_id in RunManager.deck:
		var card: CardData = card_db.get(String(card_id), null) as CardData
		if card == null:
			continue
		if not _is_single_target_damage_card(card):
			continue
		if _reward_damage_score(card) >= 40:
			count += 1
	return count

func _effect_total(card: CardData, effect_type: String) -> int:
	var total: int = 0
	for effect in card.effects:
		if effect != null and String(effect.effect_type) == effect_type:
			total += int(effect.amount)
	return total

func _card_has_effect(card: CardData, effect_type: String) -> bool:
	for effect in card.effects:
		if effect != null and String(effect.effect_type) == effect_type:
			return true
	return false

func _card_has_any_damage(card: CardData) -> bool:
	for effect in card.effects:
		if effect == null:
			continue
		match String(effect.effect_type):
			"damage", "damage_all", "damage_resonant_all", "damage_random_hits", "damage_ignore_block_percent", "damage_resonant_all_consume", "damage_per_support", "damage_plus_overload", "damage_plus_mark", "damage_consume_all_mark", "damage_all_marked", "damage_per_lost_hp_ten", "damage_all_plus_overload", "spend_all_will_damage", "spend_will_damage", "damage_per_target_resonance_consume_all", "damage_from_will_and_target_resonance", "damage_from_lost_hp_battle_percent_all":
				return true
	return false

func _hits_all_enemies(card: CardData) -> bool:
	for effect in card.effects:
		if effect == null:
			continue
		match String(effect.effect_type):
			"damage_all", "damage_resonant_all", "damage_resonant_all_consume", "damage_all_plus_overload", "damage_all_marked", "damage_from_lost_hp_battle_percent_all":
				return true
	return false

func _card_applies_resonance(card: CardData) -> bool:
	return _card_has_effect(card, "apply_resonance")

func _card_consumes_target_resonance(card: CardData) -> bool:
	for effect in card.effects:
		if effect == null:
			continue
		match String(effect.effect_type):
			"damage_per_target_resonance_consume_all", "damage_from_will_and_target_resonance":
				return true
	return false

func _highest_resonance_target_index(manager: BattleManager) -> int:
	var best_index: int = 0
	var best_resonance: int = -1
	for i in range(manager.enemies.size()):
		var enemy: UnitState = manager.enemies[i]
		if enemy.resonance > best_resonance:
			best_resonance = enemy.resonance
			best_index = i
	return best_index

func _highest_mark_target_index(manager: BattleManager) -> int:
	var best_index: int = 0
	var best_mark: int = -1
	var best_hp: int = 999999
	for i in range(manager.enemies.size()):
		var enemy: UnitState = manager.enemies[i]
		var effective_hp: int = enemy.hp + enemy.block
		if enemy.mark > best_mark:
			best_mark = enemy.mark
			best_hp = effective_hp
			best_index = i
		elif enemy.mark == best_mark and effective_hp < best_hp:
			best_hp = effective_hp
			best_index = i
	return best_index

func _lowest_mark_target_index(manager: BattleManager) -> int:
	var best_index: int = 0
	var best_mark: int = 999999
	var best_hp: int = -1
	for i in range(manager.enemies.size()):
		var enemy: UnitState = manager.enemies[i]
		var effective_hp: int = enemy.hp + enemy.block
		if enemy.mark < best_mark:
			best_mark = enemy.mark
			best_hp = effective_hp
			best_index = i
		elif enemy.mark == best_mark and effective_hp > best_hp:
			best_hp = effective_hp
			best_index = i
	return best_index

func _lowest_resonance_target_index(manager: BattleManager) -> int:
	var best_index: int = 0
	var best_resonance: int = 999999
	var best_hp: int = -1
	for i in range(manager.enemies.size()):
		var enemy: UnitState = manager.enemies[i]
		if enemy.resonance < best_resonance:
			best_resonance = enemy.resonance
			best_hp = enemy.hp + enemy.block
			best_index = i
		elif enemy.resonance == best_resonance and enemy.hp + enemy.block > best_hp:
			best_hp = enemy.hp + enemy.block
			best_index = i
	return best_index

func _power_already_active(manager: BattleManager, card: CardData) -> bool:
	for effect in card.effects:
		if effect != null and String(effect.effect_type) == "set_meta_flag":
			return bool(manager.player.meta.get(effect.status_id, false))
	return false

func _has_tag_in_hand(manager: BattleManager, tag: String, current_card: CardData = null) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if tag in card.tags:
			return true
	return false

func _has_resonance_finisher_in_hand(manager: BattleManager, current_card: CardData = null) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if _card_consumes_target_resonance(card):
			return true
	return false

func _has_will_gain_card_in_hand(manager: BattleManager, current_card: CardData = null) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if _effect_total(card, "gain_will") > 0:
			return true
	return false

func _has_will_sensitive_finisher_in_hand(manager: BattleManager, current_card: CardData = null) -> bool:
	var watched_ids := [
		"focused_ray",
		"arc_collapse",
		"controlled_detonation",
		"grand_equation",
		"chimera_protocol",
		"ember_judgement"
	]
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if watched_ids.has(card.id):
			return true
	return false

func _card_sets_up_finisher(manager: BattleManager, card: CardData) -> bool:
	var grants_will: bool = _effect_total(card, "gain_will") > 0
	var discounts_arts: bool = _card_has_effect(card, "set_next_tag_cost_delta")
	var is_support_setup: bool = "Support" in card.tags and _has_other_arts_in_hand(manager, card) and int(manager.player.meta.get("played_support_this_turn", 0)) == 0
	return (grants_will and _has_will_sensitive_finisher_in_hand(manager, card)) \
		or (discounts_arts and _has_high_damage_arts_in_hand(manager, card)) \
		or is_support_setup

func _card_prepares_resonance_combo(manager: BattleManager, card: CardData) -> bool:
	if not _card_applies_resonance(card) and not _card_has_effect(card, "gain_echo"):
		return false
	return _has_card_id_in_hand(manager, ["chain_reaction", "collapse_frequency", "feedback_loop", "harmonic_cut", "harmonic_spike"], card)

func _card_prepares_mark_combo(manager: BattleManager, card: CardData) -> bool:
	if "Mark" not in card.tags:
		return false
	return _has_mark_finisher_in_hand(manager, card) or _has_other_shot_in_hand(manager, card)

func _card_prepares_reload_followup(manager: BattleManager, card: CardData) -> bool:
	if "Reload" not in card.tags and "AmmoGain" not in card.tags:
		return false
	return _has_other_shot_in_hand(manager, card)

func _card_wants_more_will_before_play(manager: BattleManager, card: CardData) -> bool:
	if not _has_will_gain_card_in_hand(manager, card):
		return false
	match card.id:
		"focused_ray":
			return manager.player.will < 3
		"arc_collapse":
			return manager.player.will < 5
		"controlled_detonation", "grand_equation":
			return manager.player.will < 2
		_:
			return false

func _has_card_id_in_hand(manager: BattleManager, watched_ids: Array[String], current_card: CardData = null) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if watched_ids.has(card.id):
			return true
	return false

func _has_mark_finisher_in_hand(manager: BattleManager, current_card: CardData = null) -> bool:
	var watched_ids := [
		"ex_c10_precision_puncture",
		"ex_c12_snap_critical",
		"ex_c13_threading_shot",
		"ex_c15_hunting_vector",
		"ex_u07_final_redline",
		"ex_r07_execution_drill",
		"ex_l06_final_calibration",
		"ex_l08_angel_rain"
	]
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if watched_ids.has(card.id):
			return true
	return false

func _has_high_damage_arts_in_hand(manager: BattleManager, current_card: CardData = null) -> bool:
	for card in manager.deck.hand:
		if card == current_card:
			continue
		if "Arts" not in card.tags:
			continue
		if _estimated_damage(manager, card) >= 10:
			return true
	return false

func _is_single_target_damage_card(card: CardData) -> bool:
	return _card_has_any_damage(card) and not _hits_all_enemies(card)

func _card_prefers_marked_target(card: CardData) -> bool:
	if card == null:
		return false
	if "Shot" in card.tags and "Mark" in card.tags:
		return true
	var mark_finisher_ids := {
		"ex_c10_precision_puncture": true,
		"ex_c12_snap_critical": true,
		"ex_c13_threading_shot": true,
		"ex_c15_hunting_vector": true,
		"ex_u07_final_redline": true,
		"ex_r07_execution_drill": true,
		"ex_l06_final_calibration": true,
		"ex_l08_angel_rain": true
	}
	return bool(mark_finisher_ids.get(card.id, false))

func _is_w_boss_fight(manager: BattleManager) -> bool:
	return manager.enemies.size() == 1 and manager.enemies[0].id == "w_boss"

func _is_tank_boss_fight(manager: BattleManager) -> bool:
	if manager == null or manager.enemies.size() != 1:
		return false
	var enemy: UnitState = manager.enemies[0]
	if enemy == null:
		return false
	if enemy.id == "lockdown_core":
		return true
	if manager.enemy_datas.size() != 1:
		return false
	var enemy_data: EnemyData = manager.enemy_datas[0]
	return enemy_data != null and String(enemy_data.ai_profile) == "tank"

func _rng_for_floor(floor_index: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RunManager.rng_seed + floor_index * 97
	return rng

func _fail(message: String) -> void:
	failures.append(message)

func _queue_free_and_flush(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		await process_frame
		return
	node.queue_free()
	await node.tree_exited
	await process_frame
	await process_frame

func _flush_teardown() -> void:
	enemy_db.clear()
	char_data = null
	RunManager = null
	SceneRouter = null
	failures.clear()
	await process_frame
	await process_frame
