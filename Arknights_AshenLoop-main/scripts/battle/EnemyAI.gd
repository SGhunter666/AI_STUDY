class_name EnemyAI
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var RunManager = null

func _init(seed_value: int = 1):
	rng.seed = seed_value

func next_intent(enemy: UnitState, enemy_data: EnemyData, turn_index: int) -> Dictionary:
	match enemy_data.ai_profile:
		"basic":
			return _basic_intent(enemy_data, turn_index)
		"w_boss":
			if enemy_data.id == "ash_echo":
				return _ash_echo_intent(enemy, turn_index)
			return _w_intent(enemy, turn_index)
		"tank":
			return _tank_intent(enemy, enemy_data, turn_index)
		"debuffer":
			return _debuffer_intent(enemy, enemy_data, turn_index)
		"caster":
			return _caster_intent(enemy, enemy_data, turn_index)
	return {"type": "attack", "value": 6, "label": "攻击 6"}

func _basic_intent(enemy_data: EnemyData, turn_index: int) -> Dictionary:
	if enemy_data.moves.is_empty():
		return {"type": "attack", "value": 6, "label": "攻击 6"}
	return enemy_data.moves[turn_index % enemy_data.moves.size()].duplicate(true)

func _ash_echo_intent(enemy: UnitState, turn_index: int) -> Dictionary:
	var phase_two: bool = enemy != null and enemy.hp > 0 and enemy.hp <= int(ceil(float(enemy.max_hp) * 0.35))
	match turn_index % 4:
		0:
			return {"type": "attack", "value": 14 if not phase_two else 18, "label": "回响切断", "phase_two": phase_two}
		1:
			return {"type": "attack", "value": 12 if not phase_two else 16, "label": "灰烬脉冲", "phase_two": phase_two}
		2:
			if phase_two:
				return {"type": "apply_curse", "curse": "hesitation", "value": 2, "label": "残影噪声", "phase_two": true}
			return {"type": "shuffle_and_debuff", "value": 1, "label": "记忆扭曲", "phase_two": false}
		_:
			return {"type": "attack", "value": 16 if not phase_two else 20, "label": "裁决弧光", "phase_two": phase_two}

func _w_intent(enemy: UnitState, turn_index: int) -> Dictionary:
	var phase_level: int = 1
	if enemy != null and enemy.hp > 0:
		if enemy.hp <= int(ceil(float(enemy.max_hp) * 0.25)):
			phase_level = 3
		elif enemy.hp <= int(ceil(float(enemy.max_hp) * 0.5)):
			phase_level = 2
	var intent: Dictionary = {}
	if phase_level >= 3:
		intent = _w_phase_three_intent(turn_index)
	elif phase_level >= 2:
		intent = _w_phase_two_intent(turn_index)
	else:
		intent = _w_phase_one_intent(turn_index)
	intent["phase_two"] = phase_level >= 2
	intent["phase_three"] = phase_level >= 3
	return _apply_w_deception(intent, phase_level, turn_index)

func _w_phase_one_intent(turn_index: int) -> Dictionary:
	var mod: int = turn_index % 6
	match mod:
		0:
			return {"type": "apply_curse", "curse": "blast_countdown", "value": 1, "label": "埋设炸药"}
		1:
			return {"type": "attack", "value": 8, "label": "爆破齐射"}
		2:
			return {"type": "shuffle_and_debuff", "value": 1, "label": "嘲弄干扰"}
		3:
			return {"type": "apply_curse", "curse": "hesitation", "value": 1, "label": "战场阻塞"}
		4:
			return {"type": "rule_shift", "rule": "first_card_tax", "label": "灰烬规则：首牌 +1 费"}
		5:
			return {"type": "attack", "value": 10, "label": "定点爆破"}
	return {"type": "attack", "value": 8, "label": "攻击 8"}

func _w_phase_two_intent(turn_index: int) -> Dictionary:
	var mod: int = turn_index % 6
	match mod:
		0:
			return {"type": "apply_curse", "curse": "blast_countdown", "value": 1, "label": "预装炸药"}
		1:
			return {"type": "attack", "value": 12, "label": "破片扫射"}
		2:
			return {"type": "shuffle_and_debuff", "value": 1, "label": "舞台破坏"}
		3:
			return {"type": "attack", "value": 8, "label": "引爆线"}
		4:
			return {"type": "apply_curse", "curse": "hesitation", "value": 1, "label": "电台噪声"}
		5:
			return {"type": "attack", "value": 6, "label": "临时杀伤区"}
	return {"type": "attack", "value": 12, "label": "攻击 12"}

func _w_phase_three_intent(turn_index: int) -> Dictionary:
	var mod: int = turn_index % 6
	match mod:
		0:
			return {"type": "apply_curse", "curse": "blast_countdown", "value": 1, "label": "地雷合唱"}
		1:
			return {"type": "attack", "value": 9, "label": "破口爆发"}
		2:
			return {"type": "shuffle_and_debuff", "value": 1, "label": "信号崩塌"}
		3:
			return {"type": "attack", "value": 14, "label": "狂欢火力"}
		4:
			return {"type": "apply_curse", "curse": "hesitation", "value": 1, "label": "嘲弄加费"}
		5:
			return {"type": "attack", "value": 6, "label": "最后笑声"}
	return {"type": "attack", "value": 11, "label": "攻击 11"}

func _apply_w_deception(actual_intent: Dictionary, phase_level: int, turn_index: int) -> Dictionary:
	_bind_run_manager()
	var intent: Dictionary = actual_intent.duplicate(true)
	intent["display_type"] = intent.get("type", "attack")
	intent["display_value"] = intent.get("value", 0)
	intent["display_label"] = intent.get("label", "未知")
	if RunManager != null and RunManager.has_flag("w_intents_clear"):
		return intent
	var mod: int = turn_index % 6
	match String(intent.get("type", "attack")):
		"apply_curse":
			intent["display_type"] = "attack"
			intent["display_value"] = 7 if phase_level == 1 else (11 if phase_level == 2 else 14)
			intent["display_label"] = "压制火力"
		"shuffle_and_debuff":
			intent["display_type"] = "attack"
			intent["display_value"] = 8 if phase_level == 1 else (12 if phase_level == 2 else 15)
			intent["display_label"] = "佯攻弹幕"
		"rule_shift":
			if mod == 3:
				intent["display_type"] = "apply_curse"
				intent["display_value"] = 0
				intent["display_label"] = "静电干扰"
			else:
				intent["display_type"] = "attack"
				intent["display_value"] = 10 if phase_level == 1 else (14 if phase_level == 2 else 17)
				intent["display_label"] = "压迫射击"
		"attack":
			if mod == 5:
				var reduction: int = 1 if phase_level == 1 else (2 if phase_level == 2 else 3)
				intent["display_value"] = max(1, int(intent.get("value", 0)) - reduction)
				intent["display_label"] = "威胁嘲笑"
			elif phase_level >= 2:
				intent["display_value"] = max(1, int(intent.get("value", 0)) - 1)
	return intent

func _tank_intent(enemy: UnitState, enemy_data: EnemyData, turn_index: int) -> Dictionary:
	var base_damage: int = 6
	if not enemy_data.moves.is_empty():
		base_damage = int(enemy_data.moves[0].get("value", 6))
	var mod: int = turn_index % 4
	match mod:
		0:
			return {"type": "gain_block", "value": 10, "label": "加固防线"}
		1:
			var bonus: int = 3 if enemy.block > 0 else 0
			return {"type": "attack", "value": base_damage + bonus, "label": "盾击 %d" % (base_damage + bonus)}
		2:
			return {"type": "attack", "value": base_damage, "label": "重击 %d" % base_damage}
		_:
			return {"type": "gain_block", "value": 6, "label": "架盾"}

func _debuffer_intent(enemy: UnitState, enemy_data: EnemyData, turn_index: int) -> Dictionary:
	var base_damage: int = 4
	if not enemy_data.moves.is_empty():
		base_damage = int(enemy_data.moves[0].get("value", 4))
	var mod: int = turn_index % 5
	match mod:
		0:
			return {"type": "apply_debuff", "status": "weak", "value": 2, "label": "削弱"}
		1:
			return {"type": "apply_curse", "curse": "hesitation", "value": 1, "label": "注入迟疑"}
		2:
			return {"type": "attack", "value": base_damage, "label": "毒性飞镖 %d" % base_damage}
		3:
			return {"type": "apply_debuff", "status": "vulnerable", "value": 2, "label": "暴露弱点"}
		_:
			return {"type": "shuffle_and_debuff", "value": 1, "label": "迷乱瓦斯"}

func _caster_intent(enemy: UnitState, enemy_data: EnemyData, turn_index: int) -> Dictionary:
	var base_damage: int = _first_attack_value(enemy_data, 5)
	var charged: int = int(enemy.meta.get("charged_damage", 0))
	var mod: int = turn_index % 4
	match mod:
		0:
			return {"type": "charge", "value": base_damage * 2 + 4, "label": "蓄咒"}
		1:
			if charged > 0:
				return {"type": "release", "value": 0, "label": "释放术式 %d" % charged}
			return {"type": "attack", "value": base_damage, "label": "术式击 %d" % base_damage}
		2:
			return {"type": "attack", "value": base_damage + 2, "label": "奥术脉冲 %d" % (base_damage + 2)}
		_:
			return {"type": "charge", "value": base_damage + 6, "label": "引导蓄力"}

func _first_attack_value(enemy_data: EnemyData, fallback: int) -> int:
	if enemy_data == null:
		return fallback
	for move in enemy_data.moves:
		if typeof(move) != TYPE_DICTIONARY:
			continue
		if String(move.get("type", "")) == "attack":
			return int(move.get("value", fallback))
	return fallback

func _bind_run_manager() -> void:
	if RunManager != null:
		return
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		RunManager = (main_loop as SceneTree).root.get_node_or_null("RunManager")
