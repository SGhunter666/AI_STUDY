class_name EffectResolver
extends RefCounted

signal effect_resolved(effect_type: String, payload: Dictionary)

const CONDITION_EVALUATOR = preload("res://scripts/battle/ConditionEvaluator.gd")

var battle_manager
var RunManager = null

func _init(owner = null):
	battle_manager = owner

func clear_runtime_refs() -> void:
	battle_manager = null
	RunManager = null

func resolve_card(card: CardData, source: UnitState, target: UnitState = null) -> void:
	_bind_run_manager()
	for effect in card.effects:
		if not _passes_condition(effect, source, target, card):
			continue
		resolve_effect(effect, source, target, card)
	for effect in card.conditional_effects:
		if not _passes_condition(effect, source, target, card):
			continue
		resolve_effect(effect, source, target, card)

func resolve_effect(effect: EffectData, source: UnitState, target: UnitState, card: CardData = null) -> void:
	_bind_run_manager()
	match effect.effect_type:
		"damage":
			_resolve_damage(effect, source, target, card)
		"block":
			var resolved_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			var block_amount: int = effect.amount
			if source != null and source == battle_manager.player and battle_manager.has_method("nearl_shield_bonus"):
				block_amount += int(battle_manager.call("nearl_shield_bonus"))
			if _has_relic("nearl_crest"):
				block_amount += int(ceil(float(block_amount) * 0.2))
			if card != null and _has_relic("dobermann_manual") and card.rarity in ["Basic", "Starter"]:
				block_amount += 1
			for t in resolved_targets:
				if t == source and bool(source.meta.get("no_block_this_turn", false)):
					continue
				t.add_block(block_amount)
			effect_resolved.emit("block", {
				"amount": block_amount,
				"targets": resolved_targets,
				"source": source
			})
		"draw":
			battle_manager._draw_cards(effect.amount, "effect_draw")
			effect_resolved.emit("draw", {"amount": effect.amount})
		"heal":
			var heal_amount: int = effect.amount
			if source != null and source == battle_manager.player and battle_manager.has_method("nearl_heal_bonus"):
				heal_amount += int(battle_manager.call("nearl_heal_bonus"))
			if source != null and source == battle_manager.player and battle_manager.has_method("_hook_operating_room_heal_bonus"):
				heal_amount += int(battle_manager.call("_hook_operating_room_heal_bonus"))
			# 医疗负荷诅咒：本回合第一张医疗牌效果 -3（用后即消）
			if card != null and source != null and source == battle_manager.player and "Medical" in card.tags and int(source.meta.get("medical_burden_penalty", 0)) > 0:
				heal_amount = max(0, heal_amount - int(source.meta.get("medical_burden_penalty", 0)))
				source.meta["medical_burden_penalty"] = 0
			if source == battle_manager.player:
				heal_amount += int(source.meta.get("next_heal_bonus", 0))
				source.meta["next_heal_bonus"] = 0
			if _has_relic("sterile_strap"):
				heal_amount = int(ceil(float(heal_amount) * 1.3))
			var heal_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			for t in heal_targets:
				var before_hp: int = t.hp
				t.heal(heal_amount)
				if t == source and t.hp > before_hp:
					source.meta["hp_healed_this_turn"] = int(source.meta.get("hp_healed_this_turn", 0)) + (t.hp - before_hp)
				if t == battle_manager.player and battle_manager.has_method("_hook_player_heal_applied"):
					battle_manager.call("_hook_player_heal_applied", before_hp, t.hp, heal_amount)
			effect_resolved.emit("heal", {
				"amount": heal_amount,
				"targets": heal_targets,
				"source": source
			})
		"heal_or_block_if_full":
			var flexible_amount: int = effect.amount
			if source.hp >= source.max_hp:
				var flexible_block: int = effect.amount_2 if effect.amount_2 > 0 else flexible_amount
				if source == battle_manager.player and battle_manager.has_method("nearl_shield_bonus"):
					flexible_block += int(battle_manager.call("nearl_shield_bonus"))
				source.add_block(flexible_block)
				effect_resolved.emit("block", {
					"amount": flexible_block,
					"targets": [source],
					"source": source
				})
			else:
				var before_flexible_hp: int = source.hp
				var flexible_heal: int = flexible_amount
				if source == battle_manager.player and battle_manager.has_method("nearl_heal_bonus"):
					flexible_heal += int(battle_manager.call("nearl_heal_bonus"))
				source.heal(flexible_heal)
				source.meta["hp_healed_this_turn"] = int(source.meta.get("hp_healed_this_turn", 0)) + max(0, source.hp - before_flexible_hp)
				if source == battle_manager.player and battle_manager.has_method("_hook_player_heal_applied"):
					battle_manager.call("_hook_player_heal_applied", before_flexible_hp, source.hp, flexible_heal)
				effect_resolved.emit("heal", {
					"amount": flexible_heal,
					"targets": [source],
					"source": source
				})
		"repair_mon3tr":
			var repair_result: Dictionary = battle_manager.repair_mon3tr(effect.amount, card.id if card != null else effect.effect_type)
			effect_resolved.emit("repair_mon3tr", repair_result)
		"repair_mon3tr_draw_if_reaches_max":
			var repair_draw_before: int = battle_manager.mon3tr_integrity()
			var repair_draw_result: Dictionary = battle_manager.repair_mon3tr(effect.amount, card.id if card != null else effect.effect_type)
			var repair_draw_after: int = int(repair_draw_result.get("after", battle_manager.mon3tr_integrity()))
			var repair_draw_max: int = int(repair_draw_result.get("max", battle_manager.mon3tr_max_integrity()))
			if repair_draw_before < repair_draw_max and repair_draw_after >= repair_draw_max:
				battle_manager._draw_cards(max(1, effect.amount_2), "mon3tr_integrity_full")
			effect_resolved.emit("repair_mon3tr", repair_draw_result)
		"damage_mon3tr":
			var integrity_loss_result: Dictionary = battle_manager.damage_mon3tr(effect.amount, card.id if card != null else effect.effect_type)
			effect_resolved.emit("damage_mon3tr", integrity_loss_result)
		"mon3tr_damage":
			var mon3tr_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			var mon3tr_hits: int = max(1, effect.amount_2)
			for mon3tr_target in mon3tr_targets:
				for _hit in range(mon3tr_hits):
					if mon3tr_target == null or mon3tr_target.is_dead():
						break
					battle_manager.mon3tr_attack(mon3tr_target, effect.amount, card)
			effect_resolved.emit("mon3tr_damage", {
				"amount": effect.amount,
				"hits": mon3tr_hits,
				"targets": mon3tr_targets,
				"source": source
			})
		"mon3tr_damage_all":
			for mon3tr_enemy in battle_manager.enemies:
				if mon3tr_enemy != null and not mon3tr_enemy.is_dead():
					battle_manager.mon3tr_attack(mon3tr_enemy, effect.amount, card)
			effect_resolved.emit("mon3tr_damage_all", {"amount": effect.amount, "source": source})
		"set_protocol_start":
			source.meta["kaltsit_protocol_repair_block"] = effect.amount
			source.meta["kaltsit_protocol_repair_draw"] = effect.amount_2
			effect_resolved.emit("set_protocol_start", {
				"block": effect.amount,
				"draw": effect.amount_2,
				"source": source
			})
		"draw_discount_medical_command":
			var drawn_medical_command: Array[CardData] = battle_manager._draw_cards(effect.amount, "clinical_scheduling")
			var discounted_once: bool = false
			for drawn_card in drawn_medical_command:
				if discounted_once:
					break
				if drawn_card != null and ("Medical" in drawn_card.tags or "Command" in drawn_card.tags):
					var discounted_card: CardData = drawn_card.duplicate(true)
					discounted_card.cost = max(0, discounted_card.cost - max(1, effect.amount_2))
					var hand_index: int = battle_manager.deck.hand.find(drawn_card)
					if hand_index != -1:
						battle_manager.deck.hand[hand_index] = discounted_card
						discounted_once = true
			effect_resolved.emit("draw_discount_medical_command", {"amount": effect.amount, "source": source})
		"set_mon3tr_max_bonus":
			source.meta["mon3tr_base_max_integrity"] = int(source.meta.get("mon3tr_base_max_integrity", 10)) + effect.amount
			if not bool(source.meta.get("mon3tr_in_meltdown", false)):
				source.meta["mon3tr_current_max_integrity"] = int(source.meta.get("mon3tr_current_max_integrity", 10)) + effect.amount
			source.meta["mon3tr_integrity"] = min(int(source.meta.get("mon3tr_integrity", 3)) + effect.amount, int(source.meta.get("mon3tr_current_max_integrity", 10)))
			effect_resolved.emit("set_mon3tr_max_bonus", {"amount": effect.amount, "source": source})
		"set_mon3tr_auto_repair_bonus":
			source.meta["mon3tr_auto_repair_bonus"] = int(source.meta.get("mon3tr_auto_repair_bonus", 0)) + effect.amount
			effect_resolved.emit("set_mon3tr_auto_repair_bonus", {"amount": effect.amount, "source": source})
		"set_mon3tr_repair_bonus":
			source.meta["mon3tr_repair_bonus"] = int(source.meta.get("mon3tr_repair_bonus", 0)) + effect.amount
			effect_resolved.emit("set_mon3tr_repair_bonus", {"amount": effect.amount, "source": source})
		"set_mon3tr_attack_bonus":
			source.meta["mon3tr_attack_bonus"] = int(source.meta.get("mon3tr_attack_bonus", 0)) + effect.amount
			effect_resolved.emit("set_mon3tr_attack_bonus", {"amount": effect.amount, "source": source})
		"set_mon3tr_next_attack_bonus":
			source.meta["mon3tr_next_attack_bonus"] = int(source.meta.get("mon3tr_next_attack_bonus", 0)) + effect.amount
			source.meta["mon3tr_next_attack_bonus_charges"] = int(source.meta.get("mon3tr_next_attack_bonus_charges", 0)) + max(1, effect.amount_2)
			effect_resolved.emit("set_mon3tr_next_attack_bonus", {"amount": effect.amount, "source": source})
		"set_mon3tr_next_attack_multiplier":
			source.meta["mon3tr_next_attack_multiplier_percent"] = max(0, effect.amount)
			source.meta["mon3tr_next_attack_multiplier_charges"] = int(source.meta.get("mon3tr_next_attack_multiplier_charges", 0)) + max(1, effect.amount_2)
			effect_resolved.emit("set_mon3tr_next_attack_multiplier", {"amount": effect.amount, "source": source})
		"repair_mon3tr_to_max":
			var repair_to_max_amount: int = max(0, battle_manager.mon3tr_max_integrity() - battle_manager.mon3tr_integrity())
			var repair_to_max_result: Dictionary = battle_manager.repair_mon3tr(repair_to_max_amount, card.id if card != null else effect.effect_type)
			effect_resolved.emit("repair_mon3tr", repair_to_max_result)
		"repair_mon3tr_to_value":
			var repair_target_value: int = max(0, effect.amount)
			var repair_current_value: int = battle_manager.mon3tr_integrity()
			if repair_current_value < repair_target_value:
				var repair_to_value_result: Dictionary = battle_manager.repair_mon3tr(repair_target_value - repair_current_value, card.id if card != null else effect.effect_type)
				effect_resolved.emit("repair_mon3tr", repair_to_value_result)
		"mon3tr_damage_by_integrity":
			var integrity_damage_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			var integrity_damage_amount: int = max(0, battle_manager.mon3tr_integrity() + effect.amount)
			for integrity_target in integrity_damage_targets:
				if integrity_target != null and not integrity_target.is_dead():
					battle_manager.mon3tr_attack(integrity_target, integrity_damage_amount, card)
			effect_resolved.emit("mon3tr_damage_by_integrity", {"amount": integrity_damage_amount, "source": source})
		"set_mon3tr_low_integrity_no_penalty":
			source.meta["mon3tr_low_integrity_no_penalty"] = true
			effect_resolved.emit("set_mon3tr_low_integrity_no_penalty", {"source": source})
		"set_integrity_loss_reduction":
			source.meta["mon3tr_integrity_loss_reduction_turn"] = int(source.meta.get("mon3tr_integrity_loss_reduction_turn", 0)) + effect.amount
			effect_resolved.emit("set_integrity_loss_reduction", {"amount": effect.amount, "source": source})
		"set_mon3tr_reactive_repair":
			source.meta["mon3tr_reactive_repair_active"] = true
			source.meta["mon3tr_reactive_repair_amount"] = max(1, effect.amount)
			effect_resolved.emit("set_mon3tr_reactive_repair", {"amount": effect.amount, "source": source})
		"heal_if_low_else_block":
			var low_hp_threshold: int = effect.amount_2 if effect.amount_2 > 0 else 50
			if source.max_hp > 0 and float(source.hp) / float(source.max_hp) * 100.0 <= float(low_hp_threshold):
				var low_heal_amount: int = effect.amount
				if source == battle_manager.player and battle_manager.has_method("nearl_heal_bonus"):
					low_heal_amount += int(battle_manager.call("nearl_heal_bonus"))
				var before_low_heal: int = source.hp
				source.heal(low_heal_amount)
				source.meta["hp_healed_this_turn"] = int(source.meta.get("hp_healed_this_turn", 0)) + max(0, source.hp - before_low_heal)
				if source == battle_manager.player and battle_manager.has_method("_hook_player_heal_applied"):
					battle_manager.call("_hook_player_heal_applied", before_low_heal, source.hp, low_heal_amount)
				effect_resolved.emit("heal", {"amount": low_heal_amount, "targets": [source], "source": source})
			else:
				var low_block_amount: int = effect.amount
				if source == battle_manager.player and battle_manager.has_method("nearl_shield_bonus"):
					low_block_amount += int(battle_manager.call("nearl_shield_bonus"))
				source.add_block(low_block_amount)
				effect_resolved.emit("block", {"amount": low_block_amount, "targets": [source], "source": source})
		"enter_kaltsit_meltdown":
			battle_manager.enter_kaltsit_meltdown()
		"gain_radiance":
			if battle_manager.has_method("gain_nearl_radiance"):
				var radiance_result: Dictionary = battle_manager.call("gain_nearl_radiance", effect.amount)
				effect_resolved.emit("gain_radiance", radiance_result)
		"gain_counter":
			if battle_manager.has_method("gain_nearl_counter"):
				var counter_result: Dictionary = battle_manager.call("gain_nearl_counter", effect.amount, card)
				effect_resolved.emit("gain_counter", counter_result)
		"consume_counter_damage":
			var counter_total: int = int(source.meta.get("nearl_counter", 0))
			var consume_amount: int = counter_total if effect.amount <= 0 else min(counter_total, effect.amount)
			if consume_amount > 0:
				source.meta["nearl_counter"] = max(0, counter_total - consume_amount)
				var dmg_per_counter: int = max(1, effect.amount_2)
				var total_counter_dmg: int = consume_amount * dmg_per_counter
				var counter_dmg_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
				var counter_dmg_effect: EffectData = EffectData.new()
				counter_dmg_effect.effect_type = "damage"
				counter_dmg_effect.amount = total_counter_dmg
				counter_dmg_effect.target = effect.target
				for ct in counter_dmg_targets:
					if ct != null and not ct.is_dead():
						resolve_effect(counter_dmg_effect, source, ct, card)
				effect_resolved.emit("consume_counter_damage", {
					"consumed": consume_amount,
					"damage": total_counter_dmg,
					"targets": counter_dmg_targets,
					"source": source
				})
		"reduce_next_damage":
			source.meta["nearl_next_damage_reduction"] = int(source.meta.get("nearl_next_damage_reduction", 0)) + effect.amount
			effect_resolved.emit("reduce_next_damage", {"amount": effect.amount, "source": source})
		"gain_energy":
			source.energy += effect.amount
			effect_resolved.emit("gain_energy", {"amount": effect.amount, "source": source})
		"gain_will":
			source.gain_will(effect.amount, battle_manager.player_resource_max)
			effect_resolved.emit("gain_will", {"amount": effect.amount, "source": source})
		"gain_ammo":
			var ammo_before: int = source.ammo
			source.gain_ammo(effect.amount)
			effect_resolved.emit("gain_ammo", {
				"amount": source.ammo - ammo_before,
				"source": source
			})
		"fill_ammo":
			var restored_ammo: int = source.fill_ammo()
			effect_resolved.emit("gain_ammo", {
				"amount": restored_ammo,
				"source": source
			})
		"set_max_ammo_bonus":
			source.max_ammo = max(0, source.max_ammo + effect.amount)
			source.gain_ammo(max(0, effect.amount))
			effect_resolved.emit("set_max_ammo_bonus", {
				"amount": effect.amount,
				"max_ammo": source.max_ammo,
				"source": source
			})
		"consume_ammo":
			var spent_ammo: int = source.spend_ammo(effect.amount)
			effect_resolved.emit("consume_ammo", {"amount": spent_ammo, "source": source})
		"enter_burst":
			effect_resolved.emit("enter_burst", {"source": source})
		"exit_burst":
			source.burst_active = false
			effect_resolved.emit("exit_burst", {"source": source})
		"apply_mark":
			var mark_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			var mark_amount: int = effect.amount
			# 失焦诅咒：本回合玩家施加的下一道标记 -1（生效后消耗，与医疗负荷惩罚语义一致）
			if source != null and source == battle_manager.player and int(source.meta.get("mark_apply_penalty_this_turn", 0)) > 0:
				mark_amount = max(0, mark_amount - int(source.meta.get("mark_apply_penalty_this_turn", 0)))
				source.meta["mark_apply_penalty_this_turn"] = 0
			for t in mark_targets:
				t.add_mark(mark_amount)
			effect_resolved.emit("apply_mark", {
				"amount": mark_amount,
				"targets": mark_targets,
				"source": source
			})
		"consume_mark":
			if target == null:
				return
			var spent_mark: int = target.consume_mark(effect.amount if effect.amount > 0 else target.mark)
			effect_resolved.emit("consume_mark", {
				"amount": spent_mark,
				"target": target,
				"source": source
			})
		"queue_reload":
			var reload_entry: Dictionary = {
				"timing": effect.timing if not effect.timing.is_empty() else "turn_end",
				"amount": effect.amount,
				"fill": bool(effect.meta.get("fill", false))
			}
			source.reload_queue.append(reload_entry)
			effect_resolved.emit("queue_reload", {"entry": reload_entry, "source": source})
		"gain_overload":
			source.gain_overload(effect.amount)
			effect_resolved.emit("gain_overload", {"amount": effect.amount, "source": source})
		"reduce_overload":
			source.reduce_overload(effect.amount)
			effect_resolved.emit("reduce_overload", {"amount": effect.amount, "source": source})
		"consume_will":
			var spent_will: int = source.spend_will(effect.amount)
			_after_will_spent(source, spent_will)
			effect_resolved.emit("consume_will", {"amount": spent_will, "source": source})
		"lose_hp":
			var hp_loss: int = effect.amount
			if card != null and bool(source.meta.get("controlled_overload_active", false)) and "Overload" in card.tags:
				hp_loss = int(floor(float(hp_loss) * 0.5))
			source.lose_hp(hp_loss)
			effect_resolved.emit("lose_hp", {"amount": hp_loss})
		"apply_resonance":
			var resonance_targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			var resonance_amount: int = effect.amount
			if RunManager.has_tune("resonance_apply_plus_one") or RunManager.has_flag("tune_resonance_apply"):
				resonance_amount += 1
			if _has_relic("silent_bell") and not bool(source.meta.get("silent_bell_used_battle", false)):
				resonance_amount += 2
				source.meta["silent_bell_used_battle"] = true
			for t in resonance_targets:
				t.add_resonance(resonance_amount)
				if bool(source.meta.get("resonance_field_active", false)):
					var spread_target: UnitState = _find_other_enemy_with_id(t.id)
					if spread_target != null:
						spread_target.add_resonance(1)
			effect_resolved.emit("apply_resonance", {
				"amount": resonance_amount,
				"targets": resonance_targets,
				"source": source
			})
		"gain_echo":
			source.echo_percent = max(source.echo_percent, effect.amount)
			effect_resolved.emit("gain_echo", {"amount": effect.amount, "source": source})
		"set_echo_charges":
			source.echo_percent = max(source.echo_percent, effect.amount_2)
			source.meta["echo_charges"] = int(source.meta.get("echo_charges", 0)) + effect.amount
			effect_resolved.emit("set_echo_charges", {
				"charges": effect.amount,
				"percent": effect.amount_2,
				"source": source
			})
		"draw_per_resonant_enemy_reduce_drawn_arts":
			var resonant_enemy_count: int = 0
			for enemy in battle_manager.enemies:
				if enemy.resonance > 0 and not enemy.is_dead():
					resonant_enemy_count += 1
			if resonant_enemy_count > 0:
				var drawn_cards: Array[CardData] = battle_manager._draw_cards(resonant_enemy_count, "resonant_draw")
				for drawn_card in drawn_cards:
					if "Arts" in drawn_card.tags:
						var discounted_card: CardData = drawn_card.duplicate(true)
						discounted_card.cost = max(0, discounted_card.cost - 1)
						var hand_index: int = battle_manager.deck.hand.find(drawn_card)
						if hand_index != -1:
							battle_manager.deck.hand[hand_index] = discounted_card
			effect_resolved.emit("draw_per_resonant_enemy_reduce_drawn_arts", {"amount": resonant_enemy_count})
		"set_battleplan":
			source.meta["battleplan_support_cost_reduction"] = effect.amount
			source.meta["battleplan_support_draw_bonus"] = effect.amount_2
			source.meta["battleplan_first_support_pending"] = true
			effect_resolved.emit("set_battleplan", {"reduction": effect.amount, "draw": effect.amount_2})
		"set_next_tag_cost_delta":
			battle_manager.deck.next_tag_cost_delta[effect.tag] = int(battle_manager.deck.next_tag_cost_delta.get(effect.tag, 0)) + effect.amount
			effect_resolved.emit("set_next_tag_cost_delta", {"tag": effect.tag, "amount": effect.amount})
		"set_next_card_cost_delta":
			battle_manager.deck.next_card_cost_delta += effect.amount
			effect_resolved.emit("set_next_card_cost_delta", {"amount": effect.amount})
		"set_next_tag_damage_bonus":
			var next_bonus: Dictionary = source.meta.get("next_tag_damage_bonus", {})
			next_bonus[effect.tag] = int(next_bonus.get(effect.tag, 0)) + effect.amount
			source.meta["next_tag_damage_bonus"] = next_bonus
			effect_resolved.emit("set_next_tag_damage_bonus", {"tag": effect.tag, "amount": effect.amount})
		"set_no_block_this_turn":
			source.meta["no_block_this_turn"] = true
			effect_resolved.emit("set_no_block_this_turn", {})
		"channel_will_draw":
			var queue: Array = source.meta.get("channel_queue", [])
			queue.append({
				"type": "will_draw",
				"timing": "next_turn_start",
				"will": effect.amount,
				"draw": effect.amount_2
			})
			source.meta["channel_queue"] = queue
			effect_resolved.emit("channel", {"will": effect.amount, "draw": effect.amount_2, "source": source})
		"channel_support_draw_cost":
			var support_queue: Array = source.meta.get("channel_queue", [])
			support_queue.append({
				"type": "support_draw_cost",
				"timing": "next_turn_start",
				"draw": effect.amount,
				"cost_delta": -abs(effect.amount_2)
			})
			source.meta["channel_queue"] = support_queue
			effect_resolved.emit("channel", {"draw": effect.amount, "source": source})
		"channel_next_arts_bonus":
			var arts_queue: Array = source.meta.get("channel_queue", [])
			arts_queue.append({
				"type": "arts_bonus",
				"timing": "next_turn_start",
				"damage": effect.amount
			})
			source.meta["channel_queue"] = arts_queue
			effect_resolved.emit("channel", {"damage": effect.amount, "source": source})
		"cleanse_debuff":
			_cleanse_debuffs(source, effect.amount)
			effect_resolved.emit("cleanse_debuff", {"amount": effect.amount})
		"set_support_draw_trigger":
			source.meta["support_draw_trigger"] = max(int(source.meta.get("support_draw_trigger", 0)), effect.amount)
			effect_resolved.emit("set_support_draw_trigger", {"amount": effect.amount})
		"set_meta_flag":
			source.meta[effect.status_id] = true
			if card != null:
				# 记录来源卡 id，供钩子区分 base / plus 数值
				source.meta[effect.status_id + "__src_card"] = card.id
			if effect.status_id == "formation_hold_active" and effect.amount > 0:
				source.meta["formation_hold_block"] = effect.amount
			effect_resolved.emit("set_meta_flag", {"flag": effect.status_id})
		"set_meta_value":
			source.meta[effect.status_id] = effect.amount
			if card != null:
				source.meta[effect.status_id + "__src_card"] = card.id
			effect_resolved.emit("set_meta_value", {
				"key": effect.status_id,
				"value": effect.amount,
				"source": source
			})
		"add_meta_value":
			source.meta[effect.status_id] = int(source.meta.get(effect.status_id, 0)) + effect.amount
			if card != null:
				source.meta[effect.status_id + "__src_card"] = card.id
			effect_resolved.emit("add_meta_value", {
				"key": effect.status_id,
				"value": int(source.meta.get(effect.status_id, 0)),
				"source": source
			})
		"apply_status":
			var targets: Array[UnitState] = battle_manager.resolve_targets(effect.target, target)
			for t in targets:
				t.apply_status(effect.status_id, effect.amount)
			effect_resolved.emit("apply_status", {
				"status_id": effect.status_id,
				"amount": effect.amount,
				"targets": targets,
				"source": source
			})
		"weaken_enemy_team":
			var weakened_targets: Array[UnitState] = []
			for e in battle_manager.enemies:
				e.apply_status("weak", effect.amount)
				weakened_targets.append(e)
			effect_resolved.emit("team_debuff", {
				"amount": effect.amount,
				"targets": weakened_targets,
				"status_id": "weak",
				"source": source
			})
		"damage_all":
			for e in battle_manager.enemies:
				_deal_damage(source, e, effect.amount, true, card)
		"damage_resonant_all":
			for e in battle_manager.enemies:
				if e.resonance > 0:
					_deal_damage(source, e, effect.amount, true, card)
		"damage_random_hits":
			var hits: int = max(1, effect.amount_2)
			if card != null and "Shot" in card.tags and "MultiHit" in card.tags and hits > 1:
				hits += max(0, int(source.meta.get("multi_shot_extra_hits_turn", 0)))
			for _index in range(hits):
				var hit_target: UnitState = target if target != null and not target.is_dead() else _random_living_enemy()
				if hit_target == null:
					break
				_deal_damage(source, hit_target, effect.amount, true, card)
		"damage_ignore_block_percent":
			if target == null:
				return
			_deal_damage_ignore_block_percent(source, target, effect.amount, effect.amount_2, card, bool(effect.meta.get("skip_kaltsit_attack_meltdown_bonus", false)))
		"damage_resonant_all_consume":
			var consumed_total: int = 0
			var consumed_targets: Array[UnitState] = []
			for e in battle_manager.enemies:
				if e.resonance > 0:
					_deal_damage(source, e, effect.amount, true, card)
					var consumed_layers: int = e.consume_resonance(max(1, effect.amount_2))
					if consumed_layers > 0:
						consumed_total += consumed_layers
						consumed_targets.append(e)
			effect_resolved.emit("damage_resonant_all_consume", {
				"layers": consumed_total,
				"amount": effect.amount,
				"targets": consumed_targets,
				"source": source
			})
		"damage_per_support":
			if target == null:
				return
			var support_count: int = int(source.meta.get("played_support_this_turn", 0))
			var total_damage: int = effect.amount + support_count * effect.amount_2
			_deal_damage(source, target, total_damage, true, card)
		"damage_if_block_bonus":
			if target == null:
				return
			var block_bonus_damage: int = effect.amount_2 if source.block > 0 else 0
			_deal_damage(source, target, effect.amount + block_bonus_damage, true, card)
		"damage_plus_radiance":
			if target == null:
				return
			var radiance_bonus: int = 0
			if battle_manager.has_method("nearl_radiance"):
				radiance_bonus = int(battle_manager.call("nearl_radiance")) * max(1, effect.amount_2)
			_deal_damage(source, target, effect.amount + radiance_bonus, true, card)
		"damage_plus_overload":
			if target == null:
				return
			_deal_damage(source, target, effect.amount + source.overload, true, card)
		"damage_plus_mark":
			if target == null:
				return
			_deal_damage(source, target, effect.amount + target.mark * effect.amount_2, true, card)
		"damage_consume_all_mark":
			if target == null:
				return
			var total_mark: int = target.consume_mark(target.mark)
			var mark_damage: int = effect.amount + total_mark * effect.amount_2
			if mark_damage > 0:
				_deal_damage(source, target, mark_damage, true, card)
			effect_resolved.emit("damage_consume_all_mark", {
				"target": target,
				"amount": mark_damage,
				"marks": total_mark,
				"source": source
			})
		"damage_all_marked":
			for enemy in battle_manager.enemies:
				if enemy != null and not enemy.is_dead() and enemy.mark > 0:
					_deal_damage(source, enemy, effect.amount, true, card)
		"damage_per_lost_hp_ten":
			if target == null:
				return
			var lost_hp: int = int(source.meta.get("lost_hp_this_battle", 0))
			var bonus_steps: int = int(floor(float(lost_hp) / 10.0))
			_deal_damage(source, target, effect.amount + bonus_steps * effect.amount_2, true, card)
		"damage_all_plus_overload":
			for e in battle_manager.enemies:
				_deal_damage(source, e, effect.amount + source.overload, true, card)
		"spend_all_will_damage":
			var spent: int = source.spend_will(source.will)
			_after_will_spent(source, spent)
			if target:
				_deal_damage(source, target, spent * effect.amount, true, card)
		"spend_will_damage":
			var spent_partial: int = source.spend_will(min(source.will, effect.amount_2))
			_after_will_spent(source, spent_partial)
			if target:
				_deal_damage(source, target, spent_partial * effect.amount, true, card)
			effect_resolved.emit("consume_will", {"amount": spent_partial, "source": source})
		"fetch_support":
			battle_manager.fetch_support_from_draw_or_discard()
		"fetch_support_from_discard":
			battle_manager.fetch_support_from_discard()
		"peek_draw":
			battle_manager.peek_cards(effect.amount)
		"gain_gold":
			RunManager.add_gold(effect.amount)
			effect_resolved.emit("gain_gold", {"amount": effect.amount})
		"add_card_to_discard":
			if not effect.card_id.is_empty() and battle_manager.card_db.has(effect.card_id):
				battle_manager.deck.add_to_discard(battle_manager.card_db[effect.card_id])
				_trigger_added_card_relics(effect.card_id)
				effect_resolved.emit("add_card_to_discard", {"card_id": effect.card_id})
		"add_card_to_hand":
			if not effect.card_id.is_empty() and battle_manager.card_db.has(effect.card_id):
				_add_card_to_hand_or_discard(battle_manager.card_db[effect.card_id], "add_card_to_hand")
				_trigger_added_card_relics(effect.card_id)
				effect_resolved.emit("add_card_to_hand", {"card_id": effect.card_id})
		"add_random_supports_to_hand_free":
			var support_pool: Array[CardData] = []
			for res in battle_manager.card_db.values():
				var support_card: CardData = res as CardData
				if support_card != null and "Support" in support_card.tags and support_card.card_type != "Curse":
					support_pool.append(support_card)
			support_pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.id < b.id)
			var count_to_add: int = min(effect.amount, support_pool.size())
			for index in range(count_to_add):
				var generated_support: CardData = support_pool[index].duplicate(true)
				generated_support.cost = 0
				_add_card_to_hand_or_discard(generated_support, "add_random_supports_to_hand_free")
			effect_resolved.emit("add_random_supports_to_hand_free", {"amount": count_to_add})
		"add_random_cards_to_hand_free":
			var added_count: int = _add_random_cards_to_hand_free(effect, source)
			effect_resolved.emit("add_random_cards_to_hand_free", {"amount": added_count, "source": source})
		"fetch_low_cost_from_discard":
			var fetched: CardData = _fetch_low_cost_from_discard(effect, source)
			effect_resolved.emit("fetch_low_cost_from_discard", {
				"card_id": fetched.id if fetched != null else "",
				"source": source
			})
		"discard_cards":
			var discard_amount: int = max(1, effect.amount)
			var actually_discarded: int = 0
			for _discard_idx in range(discard_amount):
				if battle_manager.deck.hand.is_empty():
					break
				var discarded_entry: CardData = battle_manager.deck.hand.pop_at(0)
				battle_manager.deck.send_to_discard(discarded_entry)
				actually_discarded += 1
			effect_resolved.emit("discard_cards", {"amount": actually_discarded, "source": source})
		"discard_then_draw_if_support_energy":
			var discarded_support: bool = false
			if not battle_manager.deck.hand.is_empty():
				var discarded_card: CardData = battle_manager.deck.hand.pop_at(0)
				battle_manager.deck.send_to_discard(discarded_card)
				discarded_support = "Support" in discarded_card.tags
			if effect.amount > 0:
				battle_manager._draw_cards(effect.amount, "discard_then_draw")
			if discarded_support and effect.amount_2 > 0:
				source.energy += effect.amount_2
			effect_resolved.emit("discard_then_draw_if_support_energy", {"draw": effect.amount, "energy": effect.amount_2 if discarded_support else 0})
		"channel_damage_will":
			var queue: Array = source.meta.get("channel_queue", [])
			queue.append({
				"type": "damage_will",
				"timing": "next_turn_start",
				"damage": effect.amount,
				"will": effect.amount_2,
				"target": target
			})
			source.meta["channel_queue"] = queue
			effect_resolved.emit("channel_damage_will", {"damage": effect.amount, "will": effect.amount_2, "source": source})
		"channel_damage_turn_end":
			var end_queue: Array = source.meta.get("channel_queue", [])
			end_queue.append({
				"type": "damage",
				"timing": "turn_end",
				"damage": effect.amount,
				"target": target
			})
			source.meta["channel_queue"] = end_queue
			effect_resolved.emit("channel_damage_turn_end", {"damage": effect.amount, "source": source})
		"channel_echo_next_turn":
			var echo_queue: Array = source.meta.get("channel_queue", [])
			echo_queue.append({
				"type": "echo",
				"timing": "next_turn_start",
				"percent": effect.amount
			})
			source.meta["channel_queue"] = echo_queue
			effect_resolved.emit("channel_echo_next_turn", {"amount": effect.amount, "source": source})
		"damage_per_target_resonance_consume_all":
			if target == null:
				return
			var spent_resonance: int = target.consume_resonance(target.resonance)
			if spent_resonance > 0:
				_deal_damage(source, target, spent_resonance * effect.amount, true, card)
			effect_resolved.emit("damage_per_target_resonance_consume_all", {
				"layers": spent_resonance,
				"amount": effect.amount,
				"target": target,
				"source": source
			})
		"damage_from_will_and_target_resonance":
			if target == null:
				return
			var spent_all_will: int = source.spend_will(source.will)
			_after_will_spent(source, spent_all_will)
			var spent_target_resonance: int = target.consume_resonance(target.resonance)
			var total_damage: int = spent_all_will * effect.amount + spent_target_resonance * effect.amount_2
			if total_damage > 0:
				_deal_damage(source, target, total_damage, true, card)
			effect_resolved.emit("damage_from_will_and_target_resonance", {
				"will": spent_all_will,
				"resonance": spent_target_resonance,
				"amount": total_damage,
				"target": target,
				"source": source
			})
		"damage_from_lost_hp_battle_percent_all":
			var lost_hp_this_battle: int = int(source.meta.get("lost_hp_this_battle", 0))
			var total_aoe: int = int(floor(float(lost_hp_this_battle) * float(effect.amount) / 100.0))
			for enemy in battle_manager.enemies:
				_deal_damage(source, enemy, total_aoe, true, card)
			effect_resolved.emit("damage_from_lost_hp_battle_percent_all", {"amount": total_aoe})
		_:
			push_warning("Unknown effect type: %s" % effect.effect_type)

func _resolve_damage(effect: EffectData, source: UnitState, target: UnitState, card: CardData = null) -> void:
	if target == null:
		return
	var damage_amount: int = effect.amount
	if effect.amount_2 > 0 and source.will > 0:
		damage_amount += source.will * effect.amount_2
	_deal_damage(source, target, damage_amount, true, card)

func preview_damage(source: UnitState, target: UnitState, amount: int, card: CardData = null, affected_by_block: bool = true) -> Dictionary:
	return _compute_damage_preview(source, target, amount, affected_by_block, card)

func _deal_damage(source: UnitState, target: UnitState, amount: int, affected_by_block: bool, card: CardData = null) -> void:
	var preview: Dictionary = _compute_damage_preview(source, target, amount, affected_by_block, card)
	var block_before: int = target.block
	var absorbed: int = int(preview.get("absorbed", 0))
	var damage_before_block: int = int(preview.get("damage_before_block", 0))
	var final_damage: int = int(preview.get("damage_after_block", 0))

	if affected_by_block and absorbed > 0:
		target.block = max(0, target.block - absorbed)
	var block_after: int = target.block
	var block_broken: bool = affected_by_block and block_before > 0 and block_after == 0 and absorbed > 0

	if final_damage > 0:
		target.lose_hp(final_damage)
		if card != null and "Support" in card.tags:
			target.meta["took_support_damage_this_turn"] = true

	effect_resolved.emit("damage", {
		"source": source,
		"target": target,
		"amount": final_damage,
		"absorbed": absorbed,
		"damage_before_block": damage_before_block,
		"block_before": block_before,
		"block_after": block_after,
		"block_broken": block_broken,
		"card_id": card.id if card != null else "",
		"card_tags": card.tags if card != null else [],
		"damage_type": "arts" if card != null and "Arts" in card.tags else "normal"
	})

func _deal_damage_ignore_block_percent(source: UnitState, target: UnitState, amount: int, ignored_block_percent: int, card: CardData = null, skip_kaltsit_attack_meltdown_bonus: bool = false) -> void:
	var preview: Dictionary = _compute_damage_preview(source, target, amount, false, card, skip_kaltsit_attack_meltdown_bonus)
	var block_before: int = target.block
	var available_block: int = max(0, int(round(float(target.block) * (100 - ignored_block_percent) / 100.0)))
	var absorbed: int = min(available_block, int(preview.get("damage_before_block", 0)))
	var final_damage: int = max(0, int(preview.get("damage_before_block", 0)) - absorbed)
	if absorbed > 0:
		target.block = max(0, target.block - absorbed)
	var block_after: int = target.block
	var block_broken: bool = block_before > 0 and block_after == 0 and absorbed > 0
	if final_damage > 0:
		target.lose_hp(final_damage)
	effect_resolved.emit("damage", {
		"source": source,
		"target": target,
		"amount": final_damage,
		"absorbed": absorbed,
		"damage_before_block": int(preview.get("damage_before_block", 0)),
		"block_before": block_before,
		"block_after": block_after,
		"block_broken": block_broken,
		"ignored_block_percent": ignored_block_percent,
		"card_id": card.id if card != null else "",
		"card_tags": card.tags if card != null else [],
		"damage_type": "arts" if card != null and "Arts" in card.tags else "normal"
	})

func _compute_damage_preview(source: UnitState, target: UnitState, amount: int, affected_by_block: bool, card: CardData = null, skip_kaltsit_attack_meltdown_bonus: bool = false) -> Dictionary:
	var final_damage: int = max(0, amount)
	if card:
		final_damage += _next_tag_bonus_damage(card, source)
	if card:
		final_damage += _card_bonus_damage(card, source)
	if not skip_kaltsit_attack_meltdown_bonus and source != null and source.id == "kaltsit" and card != null and card.card_type == "Attack" and bool(source.meta.get("mon3tr_in_meltdown", false)):
		final_damage = int(floor(float(final_damage) * 1.5))
	if card != null and "Shot" in card.tags:
		final_damage += int(source.meta.get("shot_damage_bonus_turn", 0))
		final_damage += int(source.meta.get("next_shot_damage_bonus", 0))
		if target != null and target.mark > 0:
			final_damage += int(source.meta.get("marked_target_bonus_damage", 0))
			if bool(source.meta.get("first_shot_vs_mark_bonus_pending", false)):
				final_damage += int(source.meta.get("first_shot_vs_mark_bonus", 0))
			if _has_relic("ex_m09_cluster_calibrator"):
				final_damage += 1
	if bool(source.meta.get("terminal_lock_active", false)) and "Shot" in card.tags and target != null and target.mark > 0 and int(source.meta.get("played_shot_this_turn", 0)) == 1:
		# 终端锁：带标记的敌人受到本回合第一张射击时额外伤害
		final_damage += int(source.meta.get("first_shot_vs_mark_bonus_static", 4))
	if int(source.statuses.get("strength", 0)) > 0:
		final_damage += int(source.statuses["strength"])
	if int(source.statuses.get("weak", 0)) > 0 or int(source.statuses.get("slow", 0)) > 0:
		final_damage = int(floor(final_damage * 0.75))
	if int(target.statuses.get("vulnerable", 0)) > 0:
		final_damage = int(ceil(final_damage * 1.5))

	var damage_before_block: int = final_damage
	var absorbed: int = 0
	var ignored_block_percent: int = _block_ignore_percent(source, target, card)
	if affected_by_block and target.block > 0:
		var available_block: int = target.block
		if ignored_block_percent > 0:
			available_block = max(0, int(round(float(target.block) * float(100 - ignored_block_percent) / 100.0)))
		absorbed = min(available_block, final_damage)
		final_damage -= absorbed

	return {
		"damage_before_block": damage_before_block,
		"absorbed": absorbed,
		"damage_after_block": final_damage,
		"ignored_block_percent": ignored_block_percent
	}

func _card_bonus_damage(card: CardData, source: UnitState) -> int:
	var bonus: int = 0
	if bool(source.meta.get("forbidden_crown_active", false)) and "Arts" in card.tags:
		bonus += 4
	if bool(source.burst_active) and "Shot" in card.tags:
		bonus += int(source.meta.get("burst_shot_damage_bonus", 0))
	if bool(source.burst_active) and "Shot" in card.tags and _has_relic("ex_m15_gunfire_halo"):
		bonus += 2
	if card.rarity in ["Basic", "Starter"] and _has_relic("dobermann_manual"):
		bonus += 1
	if "Shot" in card.tags and _has_relic("ex_m02_light_stock") and int(source.meta.get("played_shot_this_turn", 0)) == 1:
		bonus += 2
	if "Shot" in card.tags and _has_relic("ex_m12_chainfire_recorder") and int(source.meta.get("played_shot_this_turn", 0)) == 2:
		bonus += 3
	if "MultiHit" in card.tags and _has_relic("ex_m06_muzzle_suppressor"):
		bonus += 1
	if "MultiHit" in card.tags and _has_relic("ex_h06_gunfire_cross") and not bool(source.meta.get("gunfire_cross_used_turn", false)):
		bonus += 1
	if bool(source.meta.get("dobermann_drill_ready", false)) and (card.card_type == "Attack" or "Arts" in card.tags):
		bonus += 5
	if "Command" in card.tags:
		bonus += int(source.meta.get("next_command_damage_bonus", 0))
	if "Mon3tr" in card.tags or "Command" in card.tags:
		bonus += int(source.meta.get("mon3tr_card_damage_bonus_turn", 0))
	match card.id:
		"echo_conduit":
			bonus += min(source.will, 6)
		"resonance_burst":
			bonus += 4 if source.will >= 4 else 0
		"focus_pulse":
			bonus += 3 if bool(source.meta.get("support_played_this_turn", false)) else 0
		"ex_c18_storm_tap":
			bonus += 1 if source.burst_active else 0
		"ex_u15_blowout_burst":
			bonus += 5 if source.burst_active else 0
		"ex_r12_fire_frenzy":
			bonus += int(source.meta.get("fire_frenzy_bonus", 0)) if "Shot" in card.tags and card.cost <= 1 else 0
		_:
			pass
	return bonus

func _block_ignore_percent(source: UnitState, target: UnitState, card: CardData = null) -> int:
	if source == null or target == null or card == null:
		return 0
	if "Shot" in card.tags and target.mark > 0 and _has_relic("ex_m14_hunter_clearance") and bool(source.meta.get("hunter_clearance_active_card", false)):
		return 50
	return 0

func _next_tag_bonus_damage(card: CardData, source: UnitState) -> int:
	var total: int = 0
	var bonus_map: Dictionary = source.meta.get("next_tag_damage_bonus", {})
	for tag in card.tags:
		total += int(bonus_map.get(String(tag), 0))
	return total

func _cleanse_debuffs(unit: UnitState, amount: int) -> void:
	var remaining: int = amount
	for debuff_id in ["weak", "vulnerable"]:
		if remaining <= 0:
			break
		if int(unit.statuses.get(debuff_id, 0)) > 0:
			unit.clear_status(debuff_id)
			remaining -= 1

func _random_living_enemy() -> UnitState:
	var candidates: Array[UnitState] = []
	for enemy in battle_manager.enemies:
		if not enemy.is_dead():
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _find_other_enemy_with_id(excluded_id: String) -> UnitState:
	# 随机选取一名与 excluded_id 不同的存活敌人（共振场等效果的“另一名敌人”）
	var candidates: Array[UnitState] = []
	for enemy in battle_manager.enemies:
		if enemy != null and enemy.id != excluded_id and not enemy.is_dead():
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _passes_condition(effect: EffectData, source: UnitState, target: UnitState = null, card: CardData = null) -> bool:
	return CONDITION_EVALUATOR.evaluate(effect.condition, battle_manager, source, target, card)

func _has_relic(relic_id: String) -> bool:
	_bind_run_manager()
	if battle_manager == null or RunManager == null:
		return false
	return RunManager.has_relic(relic_id)

func _bind_run_manager() -> void:
	if RunManager != null:
		return
	if battle_manager != null and battle_manager.get_tree() != null:
		RunManager = battle_manager.get_tree().root.get_node_or_null("RunManager")
		return
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		RunManager = (main_loop as SceneTree).root.get_node_or_null("RunManager")

func _after_will_spent(source: UnitState, spent: int) -> void:
	if spent >= 3 and _has_relic("embershard"):
		source.echo_percent = max(source.echo_percent, 50)

func _trigger_added_card_relics(card_id: String) -> void:
	if card_id == "burn" and _has_relic("burnt_paper_charm"):
		battle_manager._draw_cards(1, "burnt_paper_charm")

func _character_id_for_source(source: UnitState) -> String:
	if source == null:
		return "amiya"
	match source.id:
		"exusiai":
			return "exusiai"
		"amiya":
			return "amiya"
		_:
			if RunManager != null and RunManager.character != null:
				return String(RunManager.character.id)
			return "amiya"

func _add_random_cards_to_hand_free(effect: EffectData, source: UnitState) -> int:
	if battle_manager == null:
		return 0
	var character_id: String = _character_id_for_source(source)
	var tag_filter: Array = effect.meta.get("tags_any", [])
	var pool_limit: int = int(effect.meta.get("pool_size", 0))
	var candidates: Array[CardData] = []
	var candidate_ids: Array[String] = Util.get_character_card_pool_by_tags(character_id, tag_filter, false, false)
	for candidate_id in candidate_ids:
		var candidate: CardData = battle_manager.card_db.get(candidate_id, null) as CardData
		if candidate == null or candidate.card_type == "Curse":
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: CardData, b: CardData) -> bool: return a.id < b.id)
	if pool_limit > 0 and candidates.size() > pool_limit:
		candidates = candidates.slice(0, pool_limit)
	var add_count: int = min(effect.amount, candidates.size())
	var actual_added: int = 0
	for index in range(add_count):
		var generated_card: CardData = candidates[index].duplicate(true)
		generated_card.cost = 0
		if _add_card_to_hand_or_discard(generated_card, "add_random_cards_to_hand_free"):
			actual_added += 1
	return actual_added

func _add_card_to_hand_or_discard(card: CardData, source: String) -> bool:
	if card == null or battle_manager == null or battle_manager.deck == null:
		return false
	if battle_manager.has_method("add_card_to_hand_or_discard"):
		return bool(battle_manager.call("add_card_to_hand_or_discard", card, source))
	battle_manager.deck.add_to_hand(card)
	return true

func _fetch_low_cost_from_discard(effect: EffectData, source: UnitState) -> CardData:
	if battle_manager == null or battle_manager.deck == null:
		return null
	var max_cost: int = max(0, int(effect.meta.get("max_cost", effect.amount)))
	var character_id: String = _character_id_for_source(source)
	for index in range(battle_manager.deck.discard_pile.size()):
		var card: CardData = battle_manager.deck.discard_pile[index]
		if card == null:
			continue
		if not Util.is_card_available_to_character(card.id, character_id):
			continue
		if card.card_type == "Curse" or card.cost > max_cost:
			continue
		battle_manager.deck.hand.append(card)
		battle_manager.deck.discard_pile.remove_at(index)
		return card
	return null
