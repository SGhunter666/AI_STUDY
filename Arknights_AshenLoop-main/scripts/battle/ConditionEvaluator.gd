class_name ConditionEvaluator
extends RefCounted

static func evaluate(condition: String, battle_manager, source: UnitState, target: UnitState, card: CardData = null) -> bool:
	if condition.is_empty():
		return true

	if condition.contains("&"):
		for segment in condition.split("&", false):
			if not evaluate(String(segment).strip_edges(), battle_manager, source, target, card):
				return false
		return true

	var invert: bool = false
	if condition.begins_with("not_"):
		invert = true
		condition = condition.trim_prefix("not_")

	var key: String = condition
	var args: Array[String] = []
	if condition.contains(":"):
		var parts: PackedStringArray = condition.split(":")
		key = String(parts[0]).strip_edges()
		for i in range(1, parts.size()):
			args.append(String(parts[i]).strip_edges())

	var result: bool = true
	match key:
		"played_arts":
			result = bool(source.meta.get("played_arts_this_turn", false))
		"player_will_gte":
			result = source.will >= _int_arg(args, 0)
		"player_will_lte":
			result = source.will <= _int_arg(args, 0)
		"player_ammo_gte":
			result = source.ammo >= _int_arg(args, 0)
		"player_ammo_lte":
			result = source.ammo <= _int_arg(args, 0)
		"player_ammo_eq":
			result = source.ammo == _int_arg(args, 0)
		"player_has_burst":
			result = source.burst_active
		"ammo_restored_this_turn":
			result = int(source.meta.get("restored_ammo_this_turn", 0)) > 0
		"spent_ammo_this_turn_gte":
			result = int(source.meta.get("spent_ammo_this_turn", 0)) >= _int_arg(args, 0)
		"player_has_overload":
			result = source.overload > 0
		"player_overload_gte":
			result = source.overload >= _int_arg(args, 0)
		"player_will_gte_or_overload_gte":
			result = source.will >= _int_arg(args, 0) or source.overload >= _int_arg(args, 1)
		"player_hp_lte_percent":
			if source.max_hp <= 0:
				result = false
			else:
				result = float(source.hp) / float(source.max_hp) <= float(_int_arg(args, 0)) / 100.0
		"target_has_resonance":
			result = target != null and target.resonance > 0
		"target_has_mark":
			result = target != null and target.mark > 0
		"target_mark_gte":
			result = target != null and target.mark >= _int_arg(args, 0)
		"any_enemy_has_resonance":
			if battle_manager == null:
				result = false
			else:
				result = false
				for enemy in battle_manager.enemies:
					if enemy.resonance > 0:
						result = true
						break
		"any_enemy_has_mark":
			if battle_manager == null:
				result = false
			else:
				result = false
				for enemy in battle_manager.enemies:
					if enemy.mark > 0:
						result = true
						break
		"played_support_this_turn_gte":
			result = int(source.meta.get("played_support_this_turn", 0)) >= _int_arg(args, 0)
		"played_shot_this_turn_gte":
			result = int(source.meta.get("played_shot_this_turn", 0)) >= _int_arg(args, 0)
		"played_medical_this_turn_gte":
			result = int(source.meta.get("played_medical_this_turn", 0)) >= _int_arg(args, 0)
		"played_command_this_turn_gte":
			result = int(source.meta.get("played_command_this_turn", 0)) >= _int_arg(args, 0)
		"player_has_block":
			result = source.block > 0
		"player_has_radiance":
			result = int(source.meta.get("nearl_radiance", 0)) > 0
		"player_radiance_gte":
			result = int(source.meta.get("nearl_radiance", 0)) >= _int_arg(args, 0)
		"gained_block_this_turn":
			result = int(source.meta.get("gained_block_this_turn", 0)) > 0
		"hp_healed_this_turn":
			result = int(source.meta.get("hp_healed_this_turn", 0)) > 0
		"mon3tr_repaired_this_turn":
			result = int(source.meta.get("mon3tr_repaired_this_turn", 0)) > 0
		"mon3tr_integrity_lte":
			result = battle_manager != null and battle_manager.has_method("mon3tr_integrity") and int(battle_manager.call("mon3tr_integrity")) <= _int_arg(args, 0)
		"mon3tr_integrity_gte":
			result = battle_manager != null and battle_manager.has_method("mon3tr_integrity") and int(battle_manager.call("mon3tr_integrity")) >= _int_arg(args, 0)
		"mon3tr_meltdown":
			result = battle_manager != null and battle_manager.has_method("is_mon3tr_meltdown") and bool(battle_manager.call("is_mon3tr_meltdown"))
		"hand_size_lte":
			result = battle_manager != null and battle_manager.deck != null and battle_manager.deck.hand.size() <= _int_arg(args, 0)
		"cards_played_this_turn_gte":
			result = int(source.meta.get("cards_played_this_turn", 0)) >= _int_arg(args, 0)
		"hand_contains_tag_gte":
			if battle_manager == null or battle_manager.deck == null:
				result = false
			else:
				var wanted_tag: String = _str_arg(args, 0)
				var needed: int = _int_arg(args, 1)
				var found: int = 0
				for hand_card in battle_manager.deck.hand:
					if hand_card != null and wanted_tag in hand_card.tags:
						found += 1
				result = found >= needed
		"lost_hp_this_turn":
			result = int(source.meta.get("lost_hp_this_turn", 0)) > 0
		"lost_hp_this_battle_gte":
			result = int(source.meta.get("lost_hp_this_battle", 0)) >= _int_arg(args, 0)
		"target_has_block":
			result = target != null and target.block > 0
		"target_supported_this_turn":
			result = target != null and bool(target.meta.get("took_support_damage_this_turn", false))
		"echo_active":
			result = source.echo_percent > 0
		"current_energy_gte":
			result = source.energy >= _int_arg(args, 0)
		_:
			result = true
	return not result if invert else result

static func _int_arg(args: Array[String], index: int) -> int:
	if index < 0 or index >= args.size():
		return 0
	return int(args[index])

static func _str_arg(args: Array[String], index: int) -> String:
	if index < 0 or index >= args.size():
		return ""
	return String(args[index])
