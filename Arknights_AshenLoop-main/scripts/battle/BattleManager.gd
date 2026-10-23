class_name BattleManager
extends Node

signal battle_started
signal turn_started(side: String)
signal hand_changed
signal cards_drawn(cards: Array[CardData], source: String)
signal cards_overflowed(cards: Array[CardData], source: String)
signal enemy_intents_updated
signal enemy_action_started(enemy: UnitState, intent: Dictionary)
signal enemy_action_resolved(enemy: UnitState, intent: Dictionary, result: Dictionary)
signal enemy_turn_sequence_finished
signal battle_ended(victory: bool)
signal log_message(text: String)
signal state_changed

const DEFAULT_HAND_SIZE := 5
const MAX_HAND_SIZE := 10
const KALTSIT_MON3TR_STARTING_INTEGRITY := 3
# 抽到即结算并消耗的诅咒卡（不可打，效果只在抽到时触发一次）
const CURSE_ON_DRAW_IDS := {
	"ex_s03_lost_focus": true,
	"ex_s03_lost_focus_plus": true,
	"ex_s07_static_chatter": true,
	"ex_s07_static_chatter_plus": true,
	"kaltsit_s03_medical_burden": true,
	"kaltsit_s05_command_interference": true,
	"kaltsit_s06_clinical_fatigue": true,
}

@export var player_character: CharacterData
@export var enemy_list: Array[EnemyData] = []

var player: UnitState
var mon3tr_guardian: UnitState
var enemies: Array[UnitState] = []
var enemy_datas: Array[EnemyData] = []
var deck: DeckController = DeckController.new()
var resolver: EffectResolver = EffectResolver.new(self)
var enemy_ai: EnemyAI = EnemyAI.new()
var turn_count: int = 0
var player_resource_max: int = 10
var card_db: Dictionary = {}
var module_db: Dictionary = {}
var hand_size: int = DEFAULT_HAND_SIZE
var first_card_tax_pending: bool = false
var active_side: String = "player"
var auto_end_queued: bool = false
var battle_finished: bool = false
var RunManager = null
var LocalizationManager = null
var SfxManager = null
var SceneRouter = null
var SettingsManager = null

func _ready() -> void:
	_bind_dependencies()
	if not resolver.effect_resolved.is_connected(_on_effect_resolved):
		resolver.effect_resolved.connect(_on_effect_resolved)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		dispose_runtime_state()

func configure(char_data: CharacterData, enemies_for_battle: Array[EnemyData]) -> void:
	player_character = char_data
	enemy_list = enemies_for_battle
	start_battle()

func start_battle() -> void:
	_bind_dependencies()
	_load_databases()
	_setup_player()
	_setup_enemies()
	var node_seed: int = 0
	var active_node: MapNodeModel = RunManager.current_node()
	if active_node != null:
		node_seed = active_node.id.hash()
	if RunManager.deck.is_empty() and player_character != null:
		for card_id in player_character.starter_deck:
			var normalized_card_id: String = String(card_id)
			if not normalized_card_id.is_empty():
				RunManager.deck.append(normalized_card_id)
		if not RunManager.deck.is_empty() and RunManager.has_method("save_run_snapshot"):
			RunManager.save_run_snapshot()
	deck.setup(RunManager.deck, card_db, RunManager.rng_seed + node_seed + RunManager.current_floor)
	turn_count = 0
	first_card_tax_pending = false
	battle_finished = false
	battle_started.emit()
	var actor_name: String = LocalizationManager.character_name(player_character.id, player_character.display_name)
	log_message.emit(LocalizationManager.text("battle.log.start", [actor_name]))
	start_player_turn()

func _bind_dependencies() -> void:
	var tree: SceneTree = null
	if is_inside_tree():
		tree = get_tree()
	if tree != null:
		if RunManager == null:
			RunManager = tree.root.get_node_or_null("RunManager")
		if LocalizationManager == null:
			LocalizationManager = tree.root.get_node_or_null("LocalizationManager")
		if SfxManager == null:
			SfxManager = tree.root.get_node_or_null("SfxManager")
		if SceneRouter == null:
			SceneRouter = tree.root.get_node_or_null("SceneRouter")
		if SettingsManager == null:
			SettingsManager = tree.root.get_node_or_null("SettingsManager")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root_node: Node = (main_loop as SceneTree).root
		if RunManager == null:
			RunManager = root_node.get_node_or_null("RunManager")
		if LocalizationManager == null:
			LocalizationManager = root_node.get_node_or_null("LocalizationManager")
		if SfxManager == null:
			SfxManager = root_node.get_node_or_null("SfxManager")
		if SceneRouter == null:
			SceneRouter = root_node.get_node_or_null("SceneRouter")
		if SettingsManager == null:
			SettingsManager = root_node.get_node_or_null("SettingsManager")

func _load_databases() -> void:
	card_db = Util.load_card_db()
	module_db = Util.load_module_db()

func dispose_runtime_state() -> void:
	if resolver != null:
		if resolver.effect_resolved.is_connected(_on_effect_resolved):
			resolver.effect_resolved.disconnect(_on_effect_resolved)
		resolver.clear_runtime_refs()
	if enemy_ai != null:
		enemy_ai.RunManager = null
	if deck != null:
		deck.draw_pile.clear()
		deck.hand.clear()
		deck.discard_pile.clear()
		deck.exhaust_pile.clear()
		deck.next_tag_cost_delta.clear()
	card_db.clear()
	module_db.clear()
	enemies.clear()
	mon3tr_guardian = null
	enemy_datas.clear()
	enemy_list.clear()
	player = null
	player_character = null
	RunManager = null
	LocalizationManager = null
	SfxManager = null
	SceneRouter = null
	SettingsManager = null

func _setup_player() -> void:
	player = UnitState.new()
	player.id = player_character.id
	player.display_name = player_character.display_name
	player.max_hp = RunManager.max_hp
	player.hp = RunManager.hp
	# 应用难度等级：起能量惩罚
	var energy_penalty: int = RunManager.ascension_starting_energy_penalty() if RunManager != null else 0
	player.energy = max(0, player_character.starting_energy - energy_penalty)
	player.will = 0
	player_resource_max = player_character.resource_max
	player.max_ammo = player_character.resource_max if player_character.id == "exusiai" else 0
	if player_character.id == "exusiai" and _has_relic("ex_m07_spare_pouch"):
		player.max_ammo += 1
	player.ammo = player.max_ammo
	if _has_relic("crown_of_responsibility"):
		player_resource_max += 3
	player.meta["signal_booster_used_battle"] = false
	player.meta["echo_pin_used_battle"] = false
	player.meta["kaltsits_log_used_battle"] = false
	player.meta["rhodes_pin_used_battle"] = false
	player.meta["silent_bell_used_battle"] = false
	player.meta["delivery_badge_used_battle"] = false
	player.meta["red_dot_pendant_used_battle"] = false
	player.meta["storm_permit_used_battle"] = false
	player.meta["ashen_halo_used_battle"] = false
	player.meta["ashen_halo_prevent_tick_once"] = false
	player.meta["tune_channel_quickcast_used_battle"] = false
	player.meta["tune_ex_first_refill_used_battle"] = false
	player.meta["rewire_ex_reload_draw_used_battle"] = false
	player.meta["next_turn_hand_size"] = _base_hand_size_for_character()
	player.meta["burst_prepared_next_turn"] = false
	player.meta["started_with_extra_ammo"] = false
	if player_character.id == "kaltsit":
		_setup_kaltsit_mon3tr()

func _setup_enemies() -> void:
	enemies.clear()
	enemy_datas = enemy_list.duplicate()
	var bonus_hp: int = _enemy_hp_bonus_for_active_node()
	if RunManager != null and RunManager.has_flag("next_battle_enemy_strength"):
		bonus_hp += 10
		RunManager.set_flag("next_battle_enemy_strength", false)
	# 应用难度等级：敌人血量加成
	if RunManager != null:
		bonus_hp += RunManager.ascension_enemy_hp_bonus()
	for enemy_index in range(enemy_datas.size()):
		var ed: EnemyData = enemy_datas[enemy_index]
		var e: UnitState = UnitState.new()
		e.id = ed.id
		e.meta["battle_instance_id"] = "%s_%d" % [ed.id, enemy_index]
		e.display_name = ed.display_name
		e.max_hp = ed.max_hp + bonus_hp
		e.hp = e.max_hp
		enemies.append(e)

func _enemy_hp_bonus_for_active_node() -> int:
	if RunManager == null:
		return 0
	var floor_index: int = int(RunManager.current_floor)
	if floor_index < 2 or floor_index > 3:
		return 0
	return 30 if floor_index == 2 else 50

func _ascension_scaled_gold(raw_gold: int) -> int:
	# 应用难度等级：金币惩罚（最低保留 1）
	if RunManager == null:
		return raw_gold
	var penalty: float = RunManager.ascension_gold_penalty()
	if penalty <= 0.0:
		return raw_gold
	var scaled: int = int(round(float(raw_gold) * (1.0 - penalty)))
	return max(1, scaled)

func _base_hand_size_for_character() -> int:
	if player_character != null and player_character.id == "kaltsit":
		return 4
	return DEFAULT_HAND_SIZE

func _is_kaltsit() -> bool:
	return player_character != null and player_character.id == "kaltsit" and player != null

func _setup_kaltsit_mon3tr() -> void:
	player.meta["mon3tr_integrity"] = KALTSIT_MON3TR_STARTING_INTEGRITY
	player.meta["mon3tr_base_max_integrity"] = 10
	player.meta["mon3tr_current_max_integrity"] = 10
	player.meta["mon3tr_meltdown_max_integrity"] = 15
	player.meta["mon3tr_in_meltdown"] = false
	player.meta["mon3tr_attack_bonus"] = 0
	player.meta["mon3tr_next_attack_bonus"] = 0
	player.meta["mon3tr_next_attack_bonus_charges"] = 0
	player.meta["mon3tr_next_attack_multiplier_percent"] = 100
	player.meta["mon3tr_next_attack_multiplier_charges"] = 0
	player.meta["mon3tr_low_integrity_no_penalty"] = false
	player.meta["mon3tr_meltdown_exit_threshold"] = 2
	player.meta["mon3tr_meltdown_max_override"] = 15
	player.meta["mon3tr_auto_repair_bonus"] = 0
	player.meta["mon3tr_repair_bonus"] = 0
	player.meta["kaltsit_protocol_repair_block"] = 0
	player.meta["kaltsit_protocol_repair_draw"] = 0
	player.meta["kaltsit_first_repair_used_turn"] = false
	_sync_mon3tr_guardian()

func _sync_mon3tr_guardian() -> void:
	if not _is_kaltsit():
		mon3tr_guardian = null
		return
	if mon3tr_guardian == null:
		mon3tr_guardian = UnitState.new()
		mon3tr_guardian.id = "mon3tr"
		mon3tr_guardian.display_name = "Mon3tr"
		mon3tr_guardian.meta["is_guardian"] = true
		mon3tr_guardian.meta["owner_id"] = "kaltsit"
	mon3tr_guardian.max_hp = mon3tr_max_integrity()
	mon3tr_guardian.hp = clamp(mon3tr_integrity(), 0, mon3tr_guardian.max_hp)
	mon3tr_guardian.block = 0
	mon3tr_guardian.statuses.clear()

func mon3tr_display_unit() -> UnitState:
	_sync_mon3tr_guardian()
	return mon3tr_guardian

func has_active_mon3tr_guardian() -> bool:
	return _is_kaltsit() and mon3tr_guardian != null and mon3tr_integrity() > 1

func _kaltsit_turn_start() -> void:
	if not _is_kaltsit():
		return
	player.meta["kaltsit_first_repair_used_turn"] = false
	player.meta["perpetual_maintenance_draw_used_turn"] = false
	player.meta["kaltsit_advanced_repair_used_turn"] = false
	player.meta["kaltsit_meltdown_stabilizer_plus_used_turn"] = false
	if turn_count == 1:
		_sync_mon3tr_guardian()
		return
	var auto_repair: int = 1 + max(0, int(player.meta.get("mon3tr_auto_repair_bonus", 0)))
	if bool(player.meta.get("mon3tr_perpetual_maintenance_active", false)) and bool(player.meta.get("mon3tr_in_meltdown", false)):
		auto_repair += 1
	repair_mon3tr(auto_repair, "turn_start")
	if bool(player.meta.get("mon3tr_perpetual_maintenance_draw", false)) and not bool(player.meta.get("perpetual_maintenance_draw_used_turn", false)):
		player.meta["perpetual_maintenance_draw_used_turn"] = true
		_draw_cards(1, "perpetual_maintenance")

func mon3tr_integrity() -> int:
	if player == null:
		return 0
	return int(player.meta.get("mon3tr_integrity", 0))

func mon3tr_max_integrity() -> int:
	if player == null:
		return 0
	return int(player.meta.get("mon3tr_current_max_integrity", 10))

func is_mon3tr_meltdown() -> bool:
	return player != null and bool(player.meta.get("mon3tr_in_meltdown", false))

func repair_mon3tr(amount: int, source_label: String = "") -> Dictionary:
	if not _is_kaltsit():
		return {}
	var repair_bonus: int = max(0, int(player.meta.get("mon3tr_repair_bonus", 0)))
	var repair_amount: int = max(0, amount + repair_bonus)
	if bool(player.meta.get("kaltsit_first_mon3tr_repair_each_turn_re", false)) and not bool(player.meta.get("kaltsit_repair_protocol_used_turn", false)):
		player.meta["kaltsit_repair_protocol_used_turn"] = true
		repair_amount += _power_plus("kaltsit_first_mon3tr_repair_each_turn_re", 1, 2)
	var before: int = mon3tr_integrity()
	var max_integrity: int = mon3tr_max_integrity()
	var after: int = min(max_integrity, before + repair_amount)
	player.meta["mon3tr_integrity"] = after
	player.meta["mon3tr_repaired_this_turn"] = int(player.meta.get("mon3tr_repaired_this_turn", 0)) + max(0, after - before)
	if bool(player.meta.get("kaltsit_advanced_repair_active", false)) and not bool(player.meta.get("kaltsit_advanced_repair_used_turn", false)) and before < max_integrity and after >= max_integrity:
		player.meta["kaltsit_advanced_repair_used_turn"] = true
		_draw_cards(_power_plus("kaltsit_advanced_repair_active", 2, 3), "advanced_repair_protocol")
		player.energy += 1
		log_message.emit("高级修复协议：修复至上限，抽牌并获得 1 能量。")
	if max(0, after - before) > 0 and bool(player.meta.get("kaltsit_healing_block_gain_and_mon3tr_re", false)) and not bool(player.meta.get("kaltsit_singularity_resolving", false)):
		# 医疗奇点：修复触发另外两项的百分比效果
		player.meta["kaltsit_singularity_resolving"] = true
		var singularity_percent: int = _power_plus("kaltsit_healing_block_gain_and_mon3tr_re", 25, 35)
		var singularity_amount: int = max(1, int(floor(float(after - before) * float(singularity_percent) / 100.0)))
		var singularity_before_hp: int = player.hp
		player.heal(singularity_amount)
		if player.hp > singularity_before_hp:
			player.meta["hp_healed_this_turn"] = int(player.meta.get("hp_healed_this_turn", 0)) + (player.hp - singularity_before_hp)
		player.add_block(singularity_amount)
		player.meta["kaltsit_singularity_resolving"] = false
	if not bool(player.meta.get("kaltsit_first_repair_used_turn", false)):
		player.meta["kaltsit_first_repair_used_turn"] = true
		var protocol_block: int = int(player.meta.get("kaltsit_protocol_repair_block", 0))
		if protocol_block > 0:
			player.add_block(protocol_block)
			if int(player.meta.get("kaltsit_protocol_repair_draw", 0)) > 0:
				_draw_cards(int(player.meta.get("kaltsit_protocol_repair_draw", 0)), "kaltsit_protocol_start")
	check_mon3tr_meltdown_trigger()
	_sync_mon3tr_guardian()
	state_changed.emit()
	return {
		"before": before,
		"after": mon3tr_integrity(),
		"amount": max(0, mon3tr_integrity() - before),
		"max": mon3tr_max_integrity(),
		"source": source_label,
		"meltdown": is_mon3tr_meltdown()
	}

func damage_mon3tr(amount: int, source_label: String = "") -> Dictionary:
	if not _is_kaltsit():
		return {}
	var before: int = mon3tr_integrity()
	var loss: int = max(0, amount)
	if int(player.meta.get("mon3tr_integrity_loss_reduction_turn", 0)) > 0:
		var reduced_by: int = min(loss, int(player.meta.get("mon3tr_integrity_loss_reduction_turn", 0)))
		loss -= reduced_by
		player.meta["mon3tr_integrity_loss_reduction_turn"] = max(0, int(player.meta.get("mon3tr_integrity_loss_reduction_turn", 0)) - reduced_by)
	var after: int = max(1, before - loss)
	if after < 2 and bool(player.meta.get("kaltsit_first_time_each_combat_mon3tr_wo", false)) and not bool(player.meta.get("cold_start_protocol_used_battle", false)):
		# 冷启动协议：每场战斗第一次 Mon3tr 将降至 1 完整性时，改为设为较高值
		player.meta["cold_start_protocol_used_battle"] = true
		after = _power_plus("kaltsit_first_time_each_combat_mon3tr_wo", 4, 6)
		loss = max(0, before - after)
		log_message.emit("冷启动协议：Mon3tr 完整性保持在 %d。" % after)
	player.meta["mon3tr_integrity"] = after
	# 实际损失以 before-after 为准（完整性下限 1 与冷启动协议会改变实际扣减）
	var actual_loss: int = max(0, before - after)
	if actual_loss > 0:
		player.meta["mon3tr_lost_integrity_this_turn"] = int(player.meta.get("mon3tr_lost_integrity_this_turn", 0)) + actual_loss
		if bool(player.meta.get("kaltsit_each_integrity_lost_gives_next_m", false)):
			# 结构补偿：每失去 1 点完整性，下一次 Mon3tr 攻击伤害提升
			var structural_bonus: int = _power_plus("kaltsit_each_integrity_lost_gives_next_m", 1, 2)
			player.meta["mon3tr_next_attack_bonus"] = int(player.meta.get("mon3tr_next_attack_bonus", 0)) + actual_loss * structural_bonus
			player.meta["mon3tr_next_attack_bonus_charges"] = int(player.meta.get("mon3tr_next_attack_bonus_charges", 0)) + 1
		if bool(player.meta.get("mon3tr_reactive_repair_active", false)) and not bool(player.meta.get("mon3tr_reactive_repair_used_turn", false)):
			player.meta["mon3tr_reactive_repair_used_turn"] = true
			repair_mon3tr(int(player.meta.get("mon3tr_reactive_repair_amount", 1)), "reactive_repair")
	check_mon3tr_meltdown_exit()
	_sync_mon3tr_guardian()
	state_changed.emit()
	return {
		"before": before,
		"after": mon3tr_integrity(),
		"amount": max(0, before - mon3tr_integrity()),
		"max": mon3tr_max_integrity(),
		"source": source_label,
		"meltdown": is_mon3tr_meltdown()
	}

func check_mon3tr_meltdown_trigger() -> void:
	if not _is_kaltsit():
		return
	if is_mon3tr_meltdown():
		return
	if mon3tr_integrity() <= 2:
		return
	if mon3tr_integrity() >= mon3tr_max_integrity():
		enter_kaltsit_meltdown()

func enter_kaltsit_meltdown() -> void:
	if not _is_kaltsit():
		return
	player.meta["mon3tr_in_meltdown"] = true
	var meltdown_max: int = int(player.meta.get("mon3tr_meltdown_max_override", player.meta.get("mon3tr_meltdown_max_integrity", 15)))
	player.meta["mon3tr_current_max_integrity"] = max(15, meltdown_max)
	player.meta["mon3tr_integrity"] = min(mon3tr_integrity(), mon3tr_max_integrity())
	log_message.emit("指令：融毁启动。Mon3tr最大完整性提升至 %d，凯尔希与Mon3tr伤害 +50%%。" % mon3tr_max_integrity())
	_sync_mon3tr_guardian()
	resolver.effect_resolved.emit("kaltsit_meltdown", {"source": player, "active": true})

func check_mon3tr_meltdown_exit() -> void:
	if not _is_kaltsit() or not is_mon3tr_meltdown():
		return
	var threshold: int = int(player.meta.get("mon3tr_meltdown_exit_threshold", 2))
	if mon3tr_integrity() < threshold:
		# 熔毁稳定器+：每回合第一次低于阈值时，先修复 2 点再检查退出
		if String(player.meta.get("mon3tr_meltdown_exit_threshold__src_card", "")).ends_with("_plus") and not bool(player.meta.get("kaltsit_meltdown_stabilizer_plus_used_turn", false)):
			player.meta["kaltsit_meltdown_stabilizer_plus_used_turn"] = true
			repair_mon3tr(2, "meltdown_stabilizer_plus")
		if mon3tr_integrity() < threshold:
			exit_kaltsit_meltdown()

func exit_kaltsit_meltdown() -> void:
	if not _is_kaltsit():
		return
	player.meta["mon3tr_in_meltdown"] = false
	player.meta["mon3tr_current_max_integrity"] = int(player.meta.get("mon3tr_base_max_integrity", 10))
	player.meta["mon3tr_integrity"] = min(mon3tr_integrity(), mon3tr_max_integrity())
	log_message.emit("指令：融毁结束。Mon3tr完整性回到 %d/%d。" % [mon3tr_integrity(), mon3tr_max_integrity()])
	_sync_mon3tr_guardian()
	resolver.effect_resolved.emit("kaltsit_meltdown", {"source": player, "active": false})

func get_mon3tr_damage(base_damage: int) -> int:
	if not _is_kaltsit():
		return max(0, base_damage)
	var damage: int = max(0, base_damage)
	var permanent_bonus: int = int(player.meta.get("mon3tr_attack_bonus", 0))
	var next_bonus: int = int(player.meta.get("mon3tr_next_attack_bonus", 0))
	if is_mon3tr_meltdown() and permanent_bonus < 0:
		permanent_bonus = 0
	if is_mon3tr_meltdown() and next_bonus < 0:
		next_bonus = 0
	damage += permanent_bonus
	damage += next_bonus
	if mon3tr_integrity() <= 2 and not bool(player.meta.get("mon3tr_low_integrity_no_penalty", false)) and not is_mon3tr_meltdown():
		damage = int(floor(float(damage) * 0.75))
	if is_mon3tr_meltdown():
		damage = int(floor(float(damage) * 1.5))
	var multiplier: int = int(player.meta.get("mon3tr_next_attack_multiplier_percent", 100))
	if is_mon3tr_meltdown() and multiplier < 100:
		multiplier = 100
	if multiplier != 100:
		damage = int(floor(float(damage) * float(multiplier) / 100.0))
	return max(0, damage)

func consume_mon3tr_attack_modifiers() -> void:
	if not _is_kaltsit():
		return
	var bonus_charges: int = int(player.meta.get("mon3tr_next_attack_bonus_charges", 0))
	if bonus_charges > 0:
		bonus_charges -= 1
		player.meta["mon3tr_next_attack_bonus_charges"] = bonus_charges
		if bonus_charges <= 0:
			player.meta["mon3tr_next_attack_bonus"] = 0
	var multiplier_charges: int = int(player.meta.get("mon3tr_next_attack_multiplier_charges", 0))
	if multiplier_charges > 0:
		multiplier_charges -= 1
		player.meta["mon3tr_next_attack_multiplier_charges"] = multiplier_charges
		if multiplier_charges <= 0:
			player.meta["mon3tr_next_attack_multiplier_percent"] = 100

func mon3tr_attack(target: UnitState, base_damage: int, card: CardData = null) -> int:
	if target == null:
		return 0
	var damage: int = get_mon3tr_damage(base_damage)
	var temp_effect: EffectData = EffectData.new()
	temp_effect.effect_type = "damage"
	temp_effect.amount = damage
	if is_mon3tr_meltdown():
		resolver.resolve_effect(_ignore_block_effect(damage), player, target, card)
	else:
		resolver.resolve_effect(temp_effect, player, target, card)
	consume_mon3tr_attack_modifiers()
	if damage > 0 and bool(player.meta.get("kaltsit_this_turn_each_hp_heal_makes_mon", false)) and not bool(player.meta.get("kaltsit_twin_resolving", false)):
		# 双线作战：Mon3tr 造成伤害时凯尔希治疗
		player.meta["kaltsit_twin_resolving"] = true
		var twin_heal: int = _power_plus("kaltsit_this_turn_each_hp_heal_makes_mon", 2, 3)
		var twin_before_hp: int = player.hp
		player.heal(twin_heal)
		if player.hp > twin_before_hp:
			player.meta["hp_healed_this_turn"] = int(player.meta.get("hp_healed_this_turn", 0)) + (player.hp - twin_before_hp)
		player.meta["kaltsit_twin_resolving"] = false
	return damage

func _ignore_block_effect(amount: int) -> EffectData:
	var effect: EffectData = EffectData.new()
	effect.effect_type = "damage_ignore_block_percent"
	effect.amount = amount
	effect.amount_2 = 100
	effect.meta["skip_kaltsit_attack_meltdown_bonus"] = true
	return effect

func start_player_turn() -> void:
	if battle_finished:
		return
	active_side = "player"
	turn_count += 1
	# 回合开始时重置玩家护盾（杀戮尖塔标准机制）；临光拥有护盾继承，跨回合保留
	if not (player_character != null and player_character.id == "nearl"):
		player.block = 0
	var exusiai_burst_ready_turn: bool = player_character != null and player_character.id == "exusiai" and bool(player.meta.get("burst_prepared_next_turn", false))
	# 应用难度等级起能量惩罚
	var energy_penalty: int = RunManager.ascension_starting_energy_penalty() if RunManager != null else 0
	player.energy = max(0, player_character.starting_energy - energy_penalty)
	player.burst_active = false
	player.meta["burst_prepared_next_turn"] = false
	var base_hand_size: int = _base_hand_size_for_character()
	hand_size = int(player.meta.get("next_turn_hand_size", base_hand_size))
	player.meta["next_turn_hand_size"] = base_hand_size
	if RunManager.modules.has("reserve_battery") and turn_count == 1:
		player.energy += 1
	if turn_count == 1 and RunManager != null:
		if RunManager.has_flag("next_battle_start_will_3") and player_character.id != "exusiai":
			player.gain_will(3, player_resource_max)
			RunManager.set_flag("next_battle_start_will_3", false)
		if RunManager.has_flag("next_battle_start_energy_1"):
			player.energy += 1
			RunManager.set_flag("next_battle_start_energy_1", false)
		if RunManager.has_flag("energy_potion_2"):
			player.energy += 2
			RunManager.set_flag("energy_potion_2", false)
			log_message.emit(LocalizationManager.text("battle.log.energy_potion"))
		if RunManager.has_flag("soft_start_next_battle"):
			player.add_block(5)
			RunManager.set_flag("soft_start_next_battle", false)
			log_message.emit(LocalizationManager.text("battle.log.soft_start"))
		if RunManager.has_flag("next_battle_start_ammo_2"):
			RunManager.set_flag("next_battle_start_ammo_2", false)
			if player.max_ammo > 0:
				player.gain_ammo(2)
				log_message.emit(LocalizationManager.text("battle.log.ammo_start"))
		if RunManager.has_flag("tune_cost_pending"):
			# 调律减费：本场战斗打出的第一张牌费用 -1
			RunManager.set_flag("tune_cost_pending", false)
			deck.next_card_cost_delta = -1
			log_message.emit(LocalizationManager.text("battle.log.tune_cost_discount"))
	player.meta["support_played_this_turn"] = false
	player.meta["played_support_this_turn"] = 0
	player.meta["support_trigger_ready"] = false
	player.meta["field_command_badge_used_turn"] = false
	player.meta["originium_fragment_used_turn"] = false
	player.meta["support_grid_used_turn"] = false
	player.meta["command_overflow_active"] = false
	player.meta["mark_apply_penalty_this_turn"] = 0
	player.meta["clinical_fatigue_draw_penalty"] = 0
	player.meta["medical_burden_penalty"] = 0
	player.meta["operators_thread_used_turn"] = false
	player.meta["duplicate_support_after_resolve"] = false
	player.meta["rewire_arts_bonus_used_turn"] = false
	player.meta["tune_will_arts_discount_used_turn"] = false
	player.meta["tune_overload_guard_used_turn"] = false
	player.meta["tune_ex_marked_shot_discount_used_turn"] = false
	player.meta["tune_ex_mark_trace_draw_used_turn"] = false
	player.meta["rewire_ex_first_shot_bonus_used_turn"] = false
	player.meta["rewire_ex_burst_ammo_used_turn"] = false
	player.meta["next_tag_damage_bonus"] = {}
	player.meta["cards_played_this_turn"] = 0
	player.meta["w_third_triggered_this_turn"] = false
	player.meta["played_arts_this_turn"] = false
	player.meta["gained_will_this_turn"] = false
	player.meta["lost_hp_this_turn"] = 0
	player.meta["no_block_this_turn"] = false
	player.meta["shared_burden_used"] = false
	player.meta["battleplan_support_cost_reduction"] = 0
	player.meta["battleplan_support_draw_bonus"] = 0
	player.meta["battleplan_first_support_pending"] = false
	player.meta["final_directive_active"] = false
	player.meta["luminous_guard_used_turn"] = false
	player.meta["nearl_counter"] = 0
	player.meta["nearl_countered_enemy_ids_turn"] = {}
	player.meta["nearl_next_damage_reduction"] = 0
	player.meta["nearl_m13_used_turn"] = false
	player.meta["nearl_m10_used_turn"] = false
	player.meta["gained_block_this_turn"] = 0
	player.meta["cover_fire_lead_used_turn"] = false
	player.meta["cold_analysis_used_turn"] = false
	player.meta["first_ammo_spent_used_turn"] = false
	player.meta["played_shot_this_turn"] = 0
	player.meta["burst_shots_played_turn"] = 0
	player.meta["burst_entry_resolved_turn"] = false
	player.meta["burst_cycle_draw_used_turn"] = false
	player.meta["burst_cycle_ammo_used_turn"] = false
	player.meta["burst_cycle_followup_used_turn"] = false
	player.meta["spent_ammo_this_turn"] = 0
	player.meta["restored_ammo_this_turn"] = 0
	player.meta["applied_mark_this_turn"] = 0
	player.meta["multi_shot_extra_hits_turn"] = 0
	player.meta["shot_damage_bonus_turn"] = 0
	player.meta["next_shot_damage_bonus"] = int(player.meta.get("next_shot_damage_bonus_persistent", 0))
	player.meta["next_shot_damage_bonus_charges"] = int(player.meta.get("next_shot_damage_bonus_charges_persistent", 0))
	player.meta["burst_shot_damage_bonus"] = 0
	player.meta["turn_shot_cost_reduction"] = int(player.meta.get("turn_shot_cost_reduction_persistent", 0))
	player.meta["next_shot_cost_reduction"] = int(player.meta.get("next_shot_cost_reduction_persistent", 0))
	player.meta["next_shot_cost_reduction_charges"] = int(player.meta.get("next_shot_cost_reduction_charges_persistent", 0))
	player.meta["marked_target_bonus_damage"] = int(player.meta.get("marked_target_bonus_damage_static", 0))
	player.meta["first_shot_vs_mark_bonus_pending"] = false
	player.meta["first_shot_vs_mark_bonus"] = int(player.meta.get("first_shot_vs_mark_bonus_static", 0))
	player.meta["headline_rhythm_triggers_turn"] = 0
	player.meta["fast_tempo_triggered_turn"] = false
	player.meta["ammo_refill_draw_first_used_turn"] = false
	player.meta["ammo_three_energy_used_turn"] = false
	player.meta["target_scope_used_turn"] = false
	player.meta["gunfire_cross_used_turn"] = false
	player.meta["hunter_clearance_used_turn"] = false
	player.meta["hunter_clearance_active_card"] = false
	player.meta["command_delay_active"] = false
	player.meta["overheated_bolt_active"] = false
	player.meta["fire_frenzy_active"] = false
	player.meta["fire_frenzy_bonus"] = 0
	player.meta["played_medical_this_turn"] = 0
	player.meta["played_command_this_turn"] = 0
	player.meta["hp_healed_this_turn"] = 0
	player.meta["mon3tr_repaired_this_turn"] = 0
	player.meta["mon3tr_lost_integrity_this_turn"] = 0
	player.meta["mon3tr_integrity_loss_reduction_turn"] = 0
	player.meta["mon3tr_reactive_repair_used_turn"] = false
	player.meta["kaltsit_first_repair_used_turn"] = false
	# Power 卡钩子的每回合重置
	player.meta["heated_barrel_used_turn"] = false
	player.meta["angelic_storm_first_shot_pending"] = false
	player.meta["angel_mark_used_turn"] = false
	player.meta["seamless_reload_used_turn"] = false
	player.meta["kaltsit_medical_loop_used_turn"] = 0
	player.meta["kaltsit_long_term_care_used_turn"] = false
	player.meta["kaltsit_protocol_sync_used_turn"] = false
	player.meta["kaltsit_repair_protocol_used_turn"] = false
	player.meta["next_heal_bonus"] = 0
	for enemy in enemies:
		enemy.meta["took_support_damage_this_turn"] = false
	if _is_kaltsit():
		_kaltsit_turn_start()
		_hook_kaltsit_turn_start_powers()
	if exusiai_burst_ready_turn:
		_activate_exusiai_burst("准备完成")
		player.energy += 2
		hand_size += 2
		log_message.emit("爆发回合：能量 +2，抽牌 +2。")
	_apply_start_of_turn_modules()
	_resolve_reload_queue("next_turn_start")
	_resolve_pending_channels()
	if bool(player.meta.get("harmonic_dominion_active", false)):
		var random_enemy: UnitState = _first_living_enemy()
		if random_enemy != null:
			random_enemy.add_resonance(1)
	var bonus_draw_next_turn: int = int(player.meta.get("bonus_draw_next_turn", 0))
	var draw_count: int = max(0, hand_size + bonus_draw_next_turn)
	_draw_cards(draw_count, "turn_start")
	player.meta["bonus_draw_next_turn"] = 0
	_apply_draw_curse_penalties()
	turn_started.emit("player")
	_refresh_enemy_intents_if_needed()
	hand_changed.emit()
	state_changed.emit()
	_queue_auto_end_turn_check()

func end_player_turn() -> void:
	if battle_finished or active_side != "player":
		return
	player.meta["command_overflow_active"] = false
	for i in range(deck.hand.size() - 1, -1, -1):
		var card: CardData = deck.hand[i]
		if card.id == "hesitation":
			player.will = max(0, player.will - 1)
		elif card.id == "blast_countdown":
			if SfxManager != null:
				SfxManager.play_explosion()
			player.lose_hp(8)
			log_message.emit(LocalizationManager.text("battle.log.countdown"))
		elif card.id == "burn":
			player.lose_hp(2)
			log_message.emit(LocalizationManager.text("battle.log.burn"))
		elif card.id == "overloaded_nerves":
			var overload_effect: EffectData = EffectData.new()
			overload_effect.effect_type = "gain_overload"
			overload_effect.amount = 1
			resolver.resolve_effect(overload_effect, player, player)
			player.meta["bonus_draw_next_turn"] = int(player.meta.get("bonus_draw_next_turn", 0)) + 1
			log_message.emit(LocalizationManager.text("battle.log.overloaded_nerves"))
			deck.send_to_exhaust(deck.hand.pop_at(i))
		elif card.id == "mental_noise":
			if not bool(player.meta.get("gained_will_this_turn", false)):
				player.meta["bonus_draw_next_turn"] = int(player.meta.get("bonus_draw_next_turn", 0)) - 1
			deck.send_to_exhaust(deck.hand.pop_at(i))
		elif card.id == "ashen_guilt":
			if int(player.meta.get("lost_hp_this_turn", 0)) > 0:
				player.lose_hp(1)
			deck.send_to_exhaust(deck.hand.pop_at(i))
	if bool(player.meta.get("forbidden_crown_active", false)):
		var crown_effect: EffectData = EffectData.new()
		crown_effect.effect_type = "gain_overload"
		crown_effect.amount = 1
		resolver.resolve_effect(crown_effect, player, player)
		log_message.emit(LocalizationManager.text("battle.log.forbidden_crown"))
	_resolve_turn_end_channels()
	if _has_relic("ex_m08_highspeed_loader") and player.ammo <= 1:
		var loader_before: int = player.ammo
		player.gain_ammo(2)
		var loader_restored: int = max(0, player.ammo - loader_before)
		if loader_restored > 0:
			_on_effect_resolved("gain_ammo", {"amount": loader_restored, "source": player})
			log_message.emit("高速装填器启动，恢复 %d 点弹药。" % loader_restored)
	_resolve_reload_queue("turn_end")
	if bool(player.meta.get("overload_magazine_discard_pending", false)):
		player.meta["overload_magazine_discard_pending"] = false
		if not deck.hand.is_empty():
			var discarded_card: CardData = deck.hand.pop_at(0)
			deck.send_to_discard(discarded_card)
			log_message.emit("过量上膛：弃掉 %s。" % discarded_card.display_name)
	if bool(player.meta.get("kaltsit_if_hp_was_healed_this_turn_lose_hp", false)):
		player.meta["kaltsit_if_hp_was_healed_this_turn_lose_hp"] = false
		if int(player.meta.get("hp_healed_this_turn", 0)) > 0:
			player.lose_hp(1)
			log_message.emit("伦理残响：失去 1 点生命。")
	player.burst_active = false
	# 回响只在打出当回合内有效（“下一张牌”语义），回合结束时清除，不跨回合残留
	player.clear_echo()
	player.meta["echo_charges"] = 0
	if _has_relic("field_stabilizer") and player.energy > 0:
		player.add_block(player.energy)
	if _has_relic("crown_of_responsibility"):
		player.lose_hp(1)
	_on_overload_tick()
	if player.is_dead():
		_end_battle(false)
		return
	deck.discard_hand_with_ethereal()
	_tick_status_decay(player)
	_resolve_enemy_turn()

func play_card(hand_index: int, target_index: int = 0) -> bool:
	if battle_finished or active_side != "player":
		return false
	var card: CardData = deck.play_from_hand(hand_index)
	if card == null:
		return false
	var counts_as_support: bool = _card_has_effective_tag(card, "Support")
	var counts_as_arts: bool = _card_has_effective_tag(card, "Arts")
	var counts_as_channel: bool = _card_has_effective_tag(card, "Channel")
	var counts_as_shot: bool = _card_has_effective_tag(card, "Shot")
	var counts_as_medical: bool = _card_has_effective_tag(card, "Medical")
	var counts_as_command: bool = _card_has_effective_tag(card, "Command")
	var actual_cost: int = current_card_cost(card)
	if player.energy < actual_cost:
		deck.hand.insert(hand_index, card)
		return false

	player.energy -= actual_cost
	first_card_tax_pending = false
	if counts_as_arts and RunManager.has_tune("will_arts_discount") and player.will >= 4:
		player.meta["tune_will_arts_discount_used_turn"] = true
	if counts_as_shot and RunManager.has_tune("ex_marked_shot_discount") and _any_living_enemy_has_mark():
		player.meta["tune_ex_marked_shot_discount_used_turn"] = true
	player.meta["cards_played_this_turn"] = int(player.meta.get("cards_played_this_turn", 0)) + 1
	var target: UnitState = null
	if target_index >= 0 and target_index < enemies.size() and not enemies[target_index].is_dead():
		target = enemies[target_index]
	elif not enemies.is_empty():
		# 回退目标必须是存活敌人（本回合先死亡的敌人要等出牌结束后才从数组移除）
		target = _first_living_enemy()
	player.meta["hunter_clearance_active_card"] = counts_as_shot and target != null and target.mark > 0 and _has_relic("ex_m14_hunter_clearance") and not bool(player.meta.get("hunter_clearance_used_turn", false))

	if counts_as_arts:
		player.meta["played_arts_this_turn"] = true
	if counts_as_shot:
		player.meta["played_shot_this_turn"] = int(player.meta.get("played_shot_this_turn", 0)) + 1
	if counts_as_medical and card.card_type != "Power":
		player.meta["played_medical_this_turn"] = int(player.meta.get("played_medical_this_turn", 0)) + 1
	if counts_as_command and card.card_type != "Power":
		player.meta["played_command_this_turn"] = int(player.meta.get("played_command_this_turn", 0)) + 1
	_apply_passives_before_card(card)
	resolver.resolve_card(card, player, target)
	if counts_as_command and bool(player.meta.get("kaltsit_next_command_triggers_twice", false)):
		# 精准指令：下一张指令牌触发两次
		player.meta["kaltsit_next_command_triggers_twice"] = false
		resolver.resolve_card(card, player, target)
		log_message.emit("精准指令：指令牌触发两次。")
	if counts_as_support and RunManager.has_flag("floor_first_support_double") and not bool(player.meta.get("floor_first_support_double_used_battle", false)):
		# 本层增益：每场战斗的第一张支援牌触发两次基础效果
		player.meta["floor_first_support_double_used_battle"] = true
		resolver.resolve_card(card, player, target)
		log_message.emit(LocalizationManager.text("battle.log.floor_support_double"))
	if bool(player.meta.get("duplicate_support_after_resolve", false)):
		player.meta["duplicate_support_after_resolve"] = false
		resolver.resolve_card(card, player, target)
	if _has_relic("ex_m10_tempo_pedal") and int(player.meta.get("cards_played_this_turn", 0)) == 3:
		_draw_cards(1, "tempo_pedal")
	if counts_as_channel and _has_relic("kaltsits_log") and not bool(player.meta.get("kaltsits_log_used_battle", false)):
		_draw_cards(2, "kaltsits_log")
		player.meta["kaltsits_log_used_battle"] = true
	if counts_as_channel and RunManager.has_tune("channel_quickcast") and not bool(player.meta.get("tune_channel_quickcast_used_battle", false)):
		_draw_cards(1, "tune_channel_quickcast")
		player.gain_will(1, player_resource_max)
		player.meta["tune_channel_quickcast_used_battle"] = true
		log_message.emit(LocalizationManager.text("battle.log.tune_channel_quickcast"))
	if card.exhausts or card.ethereal:
		deck.send_to_exhaust(card)
	else:
		deck.send_to_discard(card)
	_consume_post_play_bonuses(card, target)
	_apply_rule_shift_after_card()
	_cleanup_dead_enemies()
	hand_changed.emit()
	state_changed.emit()

	if enemies.is_empty():
		_end_battle(true)
	else:
		_queue_auto_end_turn_check()
	return true

func current_card_cost(card: CardData) -> int:
	if card == null:
		return 0
	var counts_as_support: bool = _card_has_effective_tag(card, "Support")
	var counts_as_arts: bool = _card_has_effective_tag(card, "Arts")
	var counts_as_shot: bool = _card_has_effective_tag(card, "Shot")
	var counts_as_medical: bool = _card_has_effective_tag(card, "Medical")
	var counts_as_command: bool = _card_has_effective_tag(card, "Command")
	var counts_as_reload: bool = "Reload" in card.tags
	var actual_cost: int = deck.effective_cost(card)
	if first_card_tax_pending:
		actual_cost += 1
	if counts_as_support:
		actual_cost = max(0, actual_cost - int(player.meta.get("battleplan_support_cost_reduction", 0)))
	if counts_as_arts and RunManager.has_tune("will_arts_discount") and player.will >= 4 and not bool(player.meta.get("tune_will_arts_discount_used_turn", false)):
		actual_cost = max(0, actual_cost - 1)
	if counts_as_reload and _has_relic("ex_h05_spare_mag") and player.ammo <= 0:
		actual_cost = max(0, actual_cost - 1)
	if counts_as_shot:
		actual_cost = max(0, actual_cost - int(player.meta.get("turn_shot_cost_reduction", 0)))
		actual_cost = max(0, actual_cost - int(player.meta.get("next_shot_cost_reduction", 0)))
		if RunManager.has_tune("ex_marked_shot_discount") and not bool(player.meta.get("tune_ex_marked_shot_discount_used_turn", false)) and _any_living_enemy_has_mark():
			actual_cost = max(0, actual_cost - 1)
	if counts_as_medical:
		actual_cost = max(0, actual_cost - int(player.meta.get("turn_medical_cost_reduction", 0)))
		actual_cost = max(0, actual_cost - int(player.meta.get("next_medical_cost_reduction", 0)))
	if counts_as_command:
		actual_cost = max(0, actual_cost - int(player.meta.get("turn_command_cost_reduction", 0)))
		actual_cost = max(0, actual_cost - int(player.meta.get("next_command_cost_reduction", 0)))
	return actual_cost

func can_play_card(card: CardData) -> bool:
	if player == null or card == null or active_side != "player":
		return false
	return player.energy >= current_card_cost(card)

func _resolve_enemy_turn() -> void:
	if battle_finished:
		return
	active_side = "enemy"
	turn_started.emit("enemy")
	state_changed.emit()
	# 敌人回合开始时重置所有敌人护盾
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			enemy.block = 0
	for i in range(enemies.size()):
		var e: UnitState = enemies[i]
		if e.is_dead():
			continue
		var ed: EnemyData = enemy_datas[i]
		var intent: Dictionary = e.intent if not e.intent.is_empty() else enemy_ai.next_intent(e, ed, turn_count)
		e.intent = intent
		enemy_action_started.emit(e, intent.duplicate(true))
		await _wait_between_enemy_actions()
		if battle_finished or e.is_dead():
			continue
		var action_result: Dictionary = _execute_enemy_intent(e, intent)
		enemy_action_resolved.emit(e, intent.duplicate(true), action_result)
		_tick_status_decay(e)
		if player.is_dead():
			_end_battle(false)
			return
		await _wait_between_enemy_actions()

	_cleanup_dead_enemies()
	if enemies.is_empty():
		_end_battle(true)
		return
	# await 期间玩家可能弃战，需再次检查 battle_finished
	if battle_finished:
		return

	_decay_enemy_resonance()
	_decay_enemy_marks()
	start_player_turn()
	enemy_turn_sequence_finished.emit()

func _wait_between_enemy_actions() -> void:
	if not is_inside_tree():
		await Engine.get_main_loop().process_frame
		return
	var wait_seconds: float = 0.35 / _battle_speed_scale()
	await get_tree().create_timer(wait_seconds).timeout

func _battle_speed_scale() -> float:
	if SettingsManager != null and SettingsManager.has_method("get_battle_speed"):
		return SettingsManager.get_battle_speed()
	return 1.0

func _execute_enemy_intent(enemy: UnitState, intent: Dictionary) -> Dictionary:
	var enemy_name: String = LocalizationManager.enemy_name(enemy.id, enemy.display_name)
	var result: Dictionary = {
		"type": String(intent.get("type", "attack")),
		"source": enemy,
		"target": player,
		"amount": 0,
		"absorbed": 0,
		"status_id": "",
		"status_amount": 0,
		"text": ""
	}
	match String(intent.get("type", "attack")):
		"attack":
			var dmg: int = int(intent.get("value", 6))
			# 应用难度等级：敌人伤害加成
			if RunManager != null:
				dmg += RunManager.ascension_enemy_damage_bonus()
			_route_enemy_damage(enemy, dmg, result, enemy_name)
		"apply_curse":
			var curse_count: int = max(1, int(intent.get("value", 1)))
			for _index in range(curse_count):
				_insert_curse_into_discard(String(intent.get("curse", "hesitation")))
			result["amount"] = curse_count
			result["status_id"] = String(intent.get("curse", "hesitation"))
			result["status_amount"] = curse_count
			result["text"] = "%s 加入干扰牌 ×%d" % [enemy_name, curse_count]
			log_message.emit(LocalizationManager.text("battle.log.curse", [enemy_name]))
		"shuffle_and_debuff":
			deck.shuffle_draw()
			if enemy == null or enemy.id != "w_boss":
				player.apply_status("weak", 1)
			if enemy == null or enemy.id != "w_boss":
				first_card_tax_pending = true
			result["status_id"] = "weak"
			result["status_amount"] = 1
			result["text"] = "%s 打乱牌堆" % enemy_name
			log_message.emit(LocalizationManager.text("battle.log.disrupt", [enemy_name]))
		"rule_shift":
			_apply_w_rule(String(intent.get("rule", "")))
			result["text"] = "%s 改写战场规则" % enemy_name
		"gain_block":
			var block_amount: int = int(intent.get("value", 8))
			enemy.add_block(block_amount)
			result["target"] = enemy
			result["amount"] = block_amount
			result["text"] = "%s 获得 %d 护盾" % [enemy_name, block_amount]
			log_message.emit(LocalizationManager.text("battle.log.enemy_block", [enemy_name, block_amount]))
		"apply_debuff":
			var debuff_id: String = String(intent.get("status", "weak"))
			var debuff_amount: int = max(1, int(intent.get("value", 1)))
			player.apply_status(debuff_id, debuff_amount)
			result["status_id"] = debuff_id
			result["status_amount"] = debuff_amount
			result["text"] = "%s 施加 %s +%d" % [enemy_name, debuff_id, debuff_amount]
			log_message.emit(LocalizationManager.text("battle.log.enemy_debuff", [enemy_name]))
		"charge":
			enemy.meta["charged_damage"] = int(enemy.meta.get("charged_damage", 0)) + int(intent.get("value", 12))
			result["target"] = enemy
			result["amount"] = int(intent.get("value", 12))
			result["text"] = "%s 蓄力 +%d" % [enemy_name, int(result["amount"])]
			log_message.emit(LocalizationManager.text("battle.log.enemy_charge", [enemy_name]))
		"release":
			var charged: int = int(enemy.meta.get("charged_damage", 0))
			if charged > 0:
				_route_enemy_damage(enemy, charged, result, enemy_name, "释放蓄力")
				enemy.meta["charged_damage"] = 0
			if String(result.get("text", "")).is_empty():
				result["text"] = "%s 释放蓄力：%d" % [enemy_name, int(result["amount"])]
			log_message.emit(LocalizationManager.text("battle.log.enemy_release", [enemy_name, charged]))
		_:
			result["text"] = LocalizationManager.text("battle.log.enemy_idle")
			log_message.emit(LocalizationManager.text("battle.log.enemy_idle"))
	state_changed.emit()
	return result

func _route_enemy_damage(enemy: UnitState, raw_damage: int, result: Dictionary, enemy_name: String, _action_label: String = "攻击") -> void:
	var player_name: String = LocalizationManager.character_name(player_character.id, player_character.display_name)
	var routed_damage: int = max(0, raw_damage)
	var player_block_before_attack: int = player.block
	var next_damage_reduction: int = int(player.meta.get("nearl_next_damage_reduction", 0))
	if next_damage_reduction > 0:
		var reduced_by: int = min(routed_damage, next_damage_reduction)
		routed_damage -= reduced_by
		player.meta["nearl_next_damage_reduction"] = max(0, next_damage_reduction - reduced_by)
		result["reduced"] = int(result.get("reduced", 0)) + reduced_by
	# 统一计算一次伤害预览：weak/slow/vulnerable 等修饰只应生效一次，
	# 护盾层与扣血层共用同一份修饰后伤害，避免状态效果被计算两次
	var damage_preview: Dictionary = resolver.preview_damage(enemy, player, routed_damage, null, true)
	var modified_damage: int = int(damage_preview.get("damage_before_block", 0))
	var block_absorbed: int = int(damage_preview.get("absorbed", 0))
	# 第1层：玩家护盾（block）优先吸收伤害
	if block_absorbed > 0:
		player.block = max(0, player.block - block_absorbed)
		result["absorbed"] = block_absorbed
		if player_block_before_attack > 0 and player.block == 0:
			result["block_broken"] = true
	var remaining_damage: int = max(0, modified_damage - block_absorbed)
	# 第2层：Mon3tr guardian 拦截溢出伤害
	var guard_capacity_used: int = 0
	var guard_integrity_lost: int = 0
	var guard_before: int = mon3tr_integrity()
	if has_active_mon3tr_guardian() and remaining_damage > 0:
		guard_capacity_used = min(remaining_damage, max(0, guard_before - 1))
		if guard_capacity_used > 0:
			var guard_result: Dictionary = damage_mon3tr(guard_capacity_used, "enemy_attack")
			guard_integrity_lost = int(guard_result.get("amount", 0))
			result["target"] = mon3tr_display_unit()
			result["mon3tr_damage"] = guard_integrity_lost
			result["mon3tr_absorbed"] = guard_capacity_used
			result["mon3tr_before"] = guard_before
			result["mon3tr_after"] = mon3tr_integrity()
			result["mon3tr_max"] = mon3tr_max_integrity()
			remaining_damage = max(0, remaining_damage - guard_capacity_used)
	# 第3层：剩余伤害直接扣 hp（修饰已在预览中统一计算，不再重复施加）
	if remaining_damage > 0:
		player.lose_hp(remaining_damage)
		result["amount"] = remaining_damage
		# 记录死因：如果玩家 hp 归零，捕获敌人信息
		if player.hp <= 0 and RunManager != null:
			RunManager.last_death_cause = {
				"enemy_id": enemy.id,
				"enemy_name": enemy_name,
				"damage": remaining_damage,
				"floor": RunManager.current_floor,
				"turn": turn_count
			}
		result["target"] = player
	_try_nearl_counter(enemy, player_block_before_attack, result)
	# 碎盾回击（nearl_m10）：护盾被敌人攻击打破时获得反击（敌方伤害不走 effect_resolved，需在此触发）
	if _is_nearl() and bool(result.get("block_broken", false)) and _has_relic("nearl_m10_broken_shield_counter") and not bool(player.meta.get("nearl_m10_used_turn", false)):
		player.meta["nearl_m10_used_turn"] = true
		gain_nearl_counter(3, null)
		log_message.emit(LocalizationManager.text("battle.log.broken_shield_counter"))
	# 日志文案
	if block_absorbed > 0 and guard_capacity_used > 0 and result.get("amount", 0) > 0:
		result["text"] = "%s → 护盾：%d，Mon3tr：%d，命中%s：%d" % [enemy_name, block_absorbed, guard_integrity_lost, player_name, int(result.get("amount", 0))]
	elif block_absorbed > 0 and guard_capacity_used > 0:
		result["text"] = "%s → 护盾：%d，Mon3tr：%d" % [enemy_name, block_absorbed, guard_integrity_lost]
	elif block_absorbed > 0 and result.get("amount", 0) > 0:
		result["text"] = "%s → 护盾：%d，命中%s：%d" % [enemy_name, block_absorbed, player_name, int(result.get("amount", 0))]
	elif guard_capacity_used > 0 and result.get("amount", 0) > 0:
		result["text"] = "%s → Mon3tr：%d，命中%s：%d" % [enemy_name, guard_integrity_lost, player_name, int(result.get("amount", 0))]
	elif block_absorbed > 0:
		result["text"] = "%s → 护盾：%d" % [enemy_name, block_absorbed]
	elif guard_capacity_used > 0:
		result["text"] = "%s → Mon3tr：%d" % [enemy_name, guard_integrity_lost]
	else:
		result["text"] = "%s → %s：%d" % [enemy_name, player_name, int(result.get("amount", 0))]

func _is_nearl() -> bool:
	return player_character != null and player_character.id == "nearl"

func nearl_radiance() -> int:
	if player == null:
		return 0
	return clamp(int(player.meta.get("nearl_radiance", 0)), 0, 5)

func nearl_shield_bonus() -> int:
	if not _is_nearl():
		return 0
	var bonus: int = min(2, int(floor(float(nearl_radiance()) / 2.0)))
	if _has_relic("nearl_m14_high_radiance_guard") and nearl_radiance() >= 4:
		bonus += 1
	return bonus

func nearl_heal_bonus() -> int:
	if not _is_nearl():
		return 0
	return min(2, int(floor(float(nearl_radiance()) / 2.0)))

func gain_nearl_radiance(amount: int) -> Dictionary:
	if not _is_nearl():
		return {"before": 0, "after": 0, "amount": 0}
	var before: int = nearl_radiance()
	var after: int = clamp(before + max(0, amount), 0, 5)
	player.meta["nearl_radiance"] = after
	var gained: int = max(0, after - before)
	if gained > 0 and _has_relic("nearl_h02_oath_pin") and not bool(player.meta.get("nearl_h02_used_battle", false)):
		player.meta["nearl_h02_used_battle"] = true
		player.add_block(2)
	if gained > 0 and _has_relic("nearl_m09_first_radiance_draw") and not bool(player.meta.get("nearl_m09_used_battle", false)):
		player.meta["nearl_m09_used_battle"] = true
		_draw_cards(1, "nearl_first_radiance")
	if gained > 0:
		var radiance_log: String = LocalizationManager.text("battle.log.radiance_gain", [gained, after]) if LocalizationManager != null else "光耀 +%d（%d/5）。" % [gained, after]
		log_message.emit(radiance_log)
	return {"before": before, "after": after, "amount": gained, "source": player}

func gain_nearl_counter(amount: int, card: CardData = null) -> Dictionary:
	if not _is_nearl():
		return {"amount": 0, "source": player}
	var counter_amount: int = max(0, amount)
	if _has_relic("nearl_m12_upgraded_counter") and card != null and card.id.ends_with("_plus"):
		counter_amount += 1
	player.meta["nearl_counter"] = int(player.meta.get("nearl_counter", 0)) + counter_amount
	if _has_relic("nearl_m16_first_counter_guard") and not bool(player.meta.get("nearl_m16_used_battle", false)):
		player.meta["nearl_m16_used_battle"] = true
		player.add_block(4)
	if counter_amount > 0:
		var counter_log: String = LocalizationManager.text("battle.log.counter_gain", [counter_amount, int(player.meta.get("nearl_counter", 0))]) if LocalizationManager != null else "反击 +%d（当前 %d）。" % [counter_amount, int(player.meta.get("nearl_counter", 0))]
		log_message.emit(counter_log)
	return {"amount": counter_amount, "total": int(player.meta.get("nearl_counter", 0)), "source": player}

func nearl_counter_damage() -> int:
	return _nearl_counter_damage()

func _nearl_counter_damage() -> int:
	if not _is_nearl():
		return 0
	var damage: int = int(player.meta.get("nearl_counter", 0)) + nearl_radiance()
	if _has_relic("nearl_m02_counter_edge"):
		damage += 1
	if _has_relic("nearl_m06_low_hp_counter") and player.max_hp > 0 and float(player.hp) / float(player.max_hp) <= 0.4:
		damage += 2
	if _has_relic("nearl_m15_full_radiance_counter") and nearl_radiance() >= 5:
		damage += 2
	return max(0, damage)

func _try_nearl_counter(enemy: UnitState, player_block_before_attack: int, result: Dictionary) -> void:
	if not _is_nearl() or enemy == null or enemy.is_dead():
		return
	if player_block_before_attack <= 0:
		return
	var counter_damage: int = _nearl_counter_damage()
	if counter_damage <= 0:
		return
	var countered: Dictionary = player.meta.get("nearl_countered_enemy_ids_turn", {})
	var counter_key: String = String(enemy.meta.get("battle_instance_id", enemy.id))
	if bool(countered.get(counter_key, false)):
		return
	countered[counter_key] = true
	player.meta["nearl_countered_enemy_ids_turn"] = countered
	var counter_effect: EffectData = EffectData.new()
	counter_effect.effect_type = "damage"
	counter_effect.amount = counter_damage
	resolver.resolve_effect(counter_effect, player, enemy)
	result["counter_damage"] = counter_damage
	if _has_relic("nearl_m05_first_counter_block") and not bool(player.meta.get("nearl_m05_used_battle", false)):
		player.meta["nearl_m05_used_battle"] = true
		player.add_block(4)
	if _has_relic("nearl_m13_counter_heal") and not bool(player.meta.get("nearl_m13_used_turn", false)):
		player.meta["nearl_m13_used_turn"] = true
		player.heal(1)
	log_message.emit("临光反击：造成 %d 点伤害。" % counter_damage)

func _apply_passives_before_card(card: CardData) -> void:
	var counts_as_support: bool = _card_has_effective_tag(card, "Support")
	var counts_as_arts: bool = _card_has_effective_tag(card, "Arts")
	var counts_as_shot: bool = _card_has_effective_tag(card, "Shot")
	var has_amiya_passive: bool = player_character != null and player_character.passive_id == "leader_of_rhodes"
	var has_nearl_passive: bool = player_character != null and player_character.passive_id == "luminous_guard"
	var has_kaltsit_passive: bool = player_character != null and player_character.passive_id == "cold_analysis"
	var is_attack_card: bool = card != null and card.card_type == "Attack"
	var has_block_effect: bool = false
	if card != null:
		for effect in card.effects:
			if effect != null and effect.effect_type == "block":
				has_block_effect = true
				break
		for effect in card.conditional_effects:
			if effect != null and effect.effect_type == "block":
				has_block_effect = true
				break
	if counts_as_arts and _has_relic("originium_fragment") and not bool(player.meta.get("originium_fragment_used_turn", false)):
		var arts_bonus: Dictionary = player.meta.get("next_tag_damage_bonus", {})
		arts_bonus["Arts"] = int(arts_bonus.get("Arts", 0)) + 2
		player.meta["next_tag_damage_bonus"] = arts_bonus
		player.meta["originium_fragment_used_turn"] = true
	if counts_as_arts and RunManager.has_flag("rewire_arts_bonus") and not bool(player.meta.get("rewire_arts_bonus_used_turn", false)):
		var rewire_bonus: Dictionary = player.meta.get("next_tag_damage_bonus", {})
		rewire_bonus["Arts"] = int(rewire_bonus.get("Arts", 0)) + 2
		player.meta["next_tag_damage_bonus"] = rewire_bonus
		player.meta["rewire_arts_bonus_used_turn"] = true
	if counts_as_arts and _has_relic("pain_converter") and int(player.meta.get("pain_converter_bonus", 0)) > 0:
		var pain_bonus: Dictionary = player.meta.get("next_tag_damage_bonus", {})
		pain_bonus["Arts"] = int(pain_bonus.get("Arts", 0)) + int(player.meta.get("pain_converter_bonus", 0))
		player.meta["next_tag_damage_bonus"] = pain_bonus
		player.meta["pain_converter_bonus"] = 0
	if has_nearl_passive and has_block_effect and not bool(player.meta.get("luminous_guard_used_turn", false)):
		var passive_block: int = 4
		if _has_relic("nearl_m01_first_guard"):
			passive_block += 2
		player.add_block(passive_block)
		player.meta["luminous_guard_used_turn"] = true
		log_message.emit(LocalizationManager.text("battle.log.luminous_guard"))
	if has_kaltsit_passive and (counts_as_support or _card_has_effective_tag(card, "Channel")) and not bool(player.meta.get("cold_analysis_used_turn", false)):
		_draw_cards(1, "cold_analysis")
		player.meta["cold_analysis_used_turn"] = true
		log_message.emit(LocalizationManager.text("battle.log.cold_analysis"))
	if counts_as_shot and bool(player.meta.get("first_shot_vs_mark_bonus_pending", false)):
		player.meta["first_shot_vs_mark_bonus_pending"] = false
	if counts_as_support:
		var support_count_before: int = int(player.meta.get("played_support_this_turn", 0))
		var support_count: int = support_count_before + 1
		var support_counted: bool = true
		if bool(player.meta.get("command_delay_active", false)) and support_count_before == 0:
			player.meta["command_delay_active"] = false
			support_count = support_count_before
			support_counted = false
		else:
			player.meta["played_support_this_turn"] = support_count
			player.meta["played_support_this_battle"] = int(player.meta.get("played_support_this_battle", 0)) + 1
		if bool(player.meta.get("elite_coordination_active", false)):
			var elite_bonus: Dictionary = player.meta.get("next_tag_damage_bonus", {})
			elite_bonus["Arts"] = int(elite_bonus.get("Arts", 0)) + 2
			player.meta["next_tag_damage_bonus"] = elite_bonus
		if bool(player.meta.get("rhodes_formation_active", false)):
			player.add_block(3)
			log_message.emit(LocalizationManager.text("battle.log.rhodes_formation"))
		if bool(player.meta.get("battleplan_first_support_pending", false)) and support_count_before == 0:
			_draw_cards(int(player.meta.get("battleplan_support_draw_bonus", 2)), "battleplan_support")
			player.meta["battleplan_first_support_pending"] = false
		if support_count == 1 and support_counted and has_amiya_passive:
			player.meta["support_trigger_ready"] = true
			var next_bonus: Dictionary = player.meta.get("next_tag_damage_bonus", {})
			next_bonus["Arts"] = int(next_bonus.get("Arts", 0)) + 2
			player.meta["next_tag_damage_bonus"] = next_bonus
			log_message.emit(LocalizationManager.text("battle.log.leader_ready"))
			if RunManager.modules.has("signal_booster") and not bool(player.meta.get("signal_booster_used_battle", false)):
				_draw_cards(1, "signal_booster")
				player.meta["signal_booster_used_battle"] = true
				log_message.emit(LocalizationManager.text("battle.log.signal_booster"))
			if bool(player.meta.get("tactical_network_active", false)):
				player.energy += 1
				log_message.emit(LocalizationManager.text("battle.log.tactical_network"))
			if RunManager.modules.has("field_command_badge") and not bool(player.meta.get("field_command_badge_used_turn", false)):
				player.energy += 1
				player.meta["field_command_badge_used_turn"] = true
				RunManager.set_flag("used_field_command_badge", true)
				log_message.emit(LocalizationManager.text("battle.log.field_command_badge"))
			if _has_relic("rhodes_pin") and not bool(player.meta.get("rhodes_pin_used_battle", false)):
				player.energy += 1
				player.meta["rhodes_pin_used_battle"] = true
			if _has_relic("ex_h04_delivery_badge") and not bool(player.meta.get("delivery_badge_used_battle", false)):
				player.meta["delivery_badge_used_battle"] = true
				_draw_cards(1, "delivery_badge")
			if RunManager.has_tune("support_echo_seed"):
				player.echo_percent = max(player.echo_percent, 50)
				log_message.emit(LocalizationManager.text("battle.log.tune_support_echo_seed"))
			if _has_relic("support_grid") and not bool(player.meta.get("support_grid_used_turn", false)):
				player.meta["duplicate_support_after_resolve"] = true
				player.meta["support_grid_used_turn"] = true
			if bool(player.meta.get("command_overflow_active", false)):
				player.meta["duplicate_support_after_resolve"] = true
			if _has_relic("ex_m05_penguin_invoice"):
				player.add_block(1)
				player.gain_ammo(1)
			if bool(player.meta.get("formation_hold_active", false)):
				var queue: Array = player.meta.get("channel_queue", [])
				queue.append({
					"type": "block",
					"timing": "next_turn_start",
					"block": int(player.meta.get("formation_hold_block", 3))
				})
				player.meta["channel_queue"] = queue
			var support_draw_trigger: int = int(player.meta.get("support_draw_trigger", 0))
			if support_draw_trigger > 0:
				_draw_cards(support_draw_trigger, "support_trigger")
				player.meta["support_draw_trigger"] = 0
		if support_counted and support_count == 2 and _has_relic("operators_thread") and not bool(player.meta.get("operators_thread_used_turn", false)):
			deck.next_card_cost_delta -= 1
			player.meta["operators_thread_used_turn"] = true
		if bool(player.meta.get("voice_of_the_team_active", false)) and support_counted and support_count % 2 == 0:
			_add_temporary_arts_to_hand(0, false)
		var support_count_battle: int = int(player.meta.get("played_support_this_battle", 0))
		if bool(player.meta.get("voice_of_the_leader_active", false)) and support_counted and support_count_battle > 0 and support_count_battle % 2 == 0:
			_add_temporary_arts_to_hand(0, true)
		player.meta["support_played_this_turn"] = true
		if player_character != null and player_character.id == "exusiai" and support_counted and support_count == 1 and RunManager.has_tune("ex_support_shot_link"):
			player.meta["next_shot_damage_bonus"] = int(player.meta.get("next_shot_damage_bonus", 0)) + 2
			player.meta["next_shot_damage_bonus_charges"] = int(player.meta.get("next_shot_damage_bonus_charges", 0)) + 1
			log_message.emit(LocalizationManager.text("battle.log.tune_ex_support_shot_link"))
	elif counts_as_arts and bool(player.meta.get("support_trigger_ready", false)):
		pass
	if counts_as_shot and player_character != null and player_character.id == "exusiai" and RunManager.has_flag("ex_rewire_first_shot_bonus") and int(player.meta.get("played_shot_this_turn", 0)) == 1 and not bool(player.meta.get("rewire_ex_first_shot_bonus_used_turn", false)):
		player.meta["rewire_ex_first_shot_bonus_used_turn"] = true
		player.meta["next_shot_damage_bonus"] = int(player.meta.get("next_shot_damage_bonus", 0)) + 2
		player.meta["next_shot_damage_bonus_charges"] = int(player.meta.get("next_shot_damage_bonus_charges", 0)) + 1
		log_message.emit("重构【首轮点射】启动：本回合第一张射击牌 +2。")
	if RunManager.modules.has("ashen_thread") and counts_as_arts and bool(player.meta.get("after_self_damage", false)):
		var bonus: EffectData = EffectData.new()
		bonus.effect_type = "damage"
		bonus.amount = 3
		var target: UnitState = enemies[0] if not enemies.is_empty() else null
		resolver.resolve_effect(bonus, player, target, card)
		player.meta["after_self_damage"] = false
	_hook_power_cards_on_play(card, counts_as_shot, counts_as_support)

func _power_plus(flag_key: String, base_value: int, plus_value: int) -> int:
	# 依据来源卡 id 判断 Power 卡是否为升级版，返回对应数值
	if String(player.meta.get(flag_key + "__src_card", "")).ends_with("_plus"):
		return plus_value
	return base_value

func _card_has_effective_tag(card: CardData, tag: String) -> bool:
	if card == null:
		return false
	if tag in card.tags:
		return true
	if bool(player.meta.get("final_directive_active", false)):
		var shares_directive_type: bool = "Support" in card.tags or "Arts" in card.tags or "Tactic" in card.tags
		if shares_directive_type and tag in ["Support", "Arts", "Tactic"]:
			return true
	return false

func _apply_start_of_turn_modules() -> void:
	if _has_relic("recorder_of_resolve") and turn_count == 1:
		player.gain_will(1, player_resource_max)
	if player_character != null and player_character.id == "nearl":
		if turn_count == 1 and _has_relic("nearl_h01_kazimierz_badge"):
			player.add_block(3)
		if turn_count == 1 and _has_relic("nearl_m03_opening_barrier"):
			player.add_block(4)
		if turn_count == 1 and _has_relic("nearl_m04_dawn_oath"):
			gain_nearl_radiance(1)
		if turn_count == 1 and _has_relic("nearl_m11_boss_bulwark"):
			var has_boss: bool = false
			for enemy in enemies:
				if enemy != null and ("boss" in enemy.id.to_lower() or "Boss" in enemy.display_name):
					has_boss = true
					break
			if has_boss:
				player.add_block(8)
	if player_character != null and player_character.id == "exusiai":
		if turn_count == 1 and _has_relic("ex_h02_fast_sling"):
			player.add_block(8)
			log_message.emit("高速挂带启动：获得 8 护盾。")
		if turn_count == 1 and _has_relic("ex_m01_racing_magazine"):
			player.gain_ammo(1)
	if RunManager.modules.has("nearl_crest") and turn_count == 1:
		player.add_block(8)
	if RunManager.modules.has("field_medic_pack") and turn_count == 1:
		player.heal(4)
	if RunManager.has_flag("rewire_support_draw") and turn_count == 1:
		_draw_cards(2, "rewire_support_draw")

func _resolve_pending_channels() -> void:
	var queue: Array = player.meta.get("channel_queue", [])
	if queue.is_empty():
		return
	player.meta["channel_queue"] = []
	for entry in queue:
		if String(entry.get("timing", "next_turn_start")) != "next_turn_start":
			var remaining: Array = player.meta.get("channel_queue", [])
			remaining.append(entry)
			player.meta["channel_queue"] = remaining
			continue
		if String(entry.get("type", "")) == "will_draw":
			var gained_will: int = int(entry.get("will", 0))
			var gained_draw: int = int(entry.get("draw", 0))
			player.gain_will(gained_will, player_resource_max)
			if gained_draw > 0:
				_draw_cards(gained_draw, "channel_will_draw")
			log_message.emit(LocalizationManager.text("battle.log.channel_resolve", [gained_will, gained_draw]))
		elif String(entry.get("type", "")) == "support_draw_cost":
			var support_draw: int = int(entry.get("draw", 0))
			if support_draw > 0:
				_draw_cards(support_draw, "channel_support_draw")
			deck.next_tag_cost_delta["Support"] = int(deck.next_tag_cost_delta.get("Support", 0)) + int(entry.get("cost_delta", 0))
		elif String(entry.get("type", "")) == "arts_bonus":
			var bonus_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
			bonus_map["Arts"] = int(bonus_map.get("Arts", 0)) + int(entry.get("damage", 0))
			player.meta["next_tag_damage_bonus"] = bonus_map
		elif String(entry.get("type", "")) == "echo":
			player.echo_percent = max(player.echo_percent, int(entry.get("percent", 0)))
		elif String(entry.get("type", "")) == "block":
			player.add_block(int(entry.get("block", 0)))
		elif String(entry.get("type", "")) == "damage_will":
			var target: UnitState = entry.get("target", null) as UnitState
			if target == null or target.is_dead():
				target = enemies[0] if not enemies.is_empty() else null
			var damage_amount: int = int(entry.get("damage", 0))
			var will_amount: int = int(entry.get("will", 0))
			player.gain_will(will_amount, player_resource_max)
			if target != null and damage_amount > 0:
				var temp_effect: EffectData = EffectData.new()
				temp_effect.effect_type = "damage"
				temp_effect.amount = damage_amount
				resolver.resolve_effect(temp_effect, player, target)
			log_message.emit(LocalizationManager.text("battle.log.channel_damage_will", [damage_amount, will_amount]))

func _resolve_turn_end_channels() -> void:
	var queue: Array = player.meta.get("channel_queue", [])
	if queue.is_empty():
		return
	var remaining_queue: Array = []
	for entry in queue:
		if String(entry.get("timing", "next_turn_start")) != "turn_end":
			remaining_queue.append(entry)
			continue
		var target: UnitState = entry.get("target", null) as UnitState
		if target == null or target.is_dead():
			target = enemies[0] if not enemies.is_empty() else null
		var damage_amount: int = int(entry.get("damage", 0))
		if target != null and damage_amount > 0:
			var temp_effect: EffectData = EffectData.new()
			temp_effect.effect_type = "damage"
			temp_effect.amount = damage_amount
			resolver.resolve_effect(temp_effect, player, target)
	player.meta["channel_queue"] = remaining_queue

func _resolve_reload_queue(timing: String) -> void:
	if player.reload_queue.is_empty():
		return
	var remaining_queue: Array[Dictionary] = []
	for entry in player.reload_queue:
		if String(entry.get("timing", "turn_end")) != timing:
			remaining_queue.append(entry)
			continue
		var before_ammo: int = player.ammo
		if bool(entry.get("fill", false)):
			player.fill_ammo()
		else:
			player.gain_ammo(int(entry.get("amount", 0)))
		var restored: int = max(0, player.ammo - before_ammo)
		if restored > 0:
			_on_effect_resolved("gain_ammo", {"amount": restored, "source": player})
			log_message.emit("装填完成，恢复 %d 点弹药。" % restored)
	player.reload_queue = remaining_queue

func _on_overload_tick() -> void:
	if player.overload <= 0:
		return
	var tick_damage: int = player.overload
	if bool(player.meta.get("ashen_halo_prevent_tick_once", false)):
		tick_damage = 0
		player.meta["ashen_halo_prevent_tick_once"] = false
	if bool(player.meta.get("controlled_overload_active", false)):
		tick_damage = int(floor(float(tick_damage) * 0.5))
	if RunManager.has_flag("rewire_overload_minus_one"):
		tick_damage = max(0, tick_damage - 1)
	if tick_damage > 0:
		player.lose_hp(tick_damage)
		player.meta["lost_hp_this_turn"] = int(player.meta.get("lost_hp_this_turn", 0)) + tick_damage
		player.meta["lost_hp_this_battle"] = int(player.meta.get("lost_hp_this_battle", 0)) + tick_damage
	if _has_relic("broken_horn_token"):
		player.add_block(4)
	player.reduce_overload(2)

func _decay_enemy_resonance() -> void:
	if _has_relic("resonance_anchor") or bool(player.meta.get("harmonic_dominion_active", false)):
		return
	for enemy in enemies:
		enemy.resonance = max(0, enemy.resonance - 1)

func _decay_enemy_marks() -> void:
	if bool(player.meta.get("mark_decay_locked", false)):
		return
	if bool(player.meta.get("mark_decay_locked_once", false)) and not bool(player.meta.get("mark_decay_locked_once_used_battle", false)):
		# 锁定延伸：标记不会在回合结束时衰减 1 次（每场战斗一次）
		player.meta["mark_decay_locked_once_used_battle"] = true
		log_message.emit("锁定延伸：本次回合结束标记不衰减。")
		return
	for enemy in enemies:
		if enemy == null or enemy.is_dead():
			continue
		enemy.mark = max(0, enemy.mark - 1)

func _apply_draw_curse_penalties() -> void:
	for i in range(deck.hand.size() - 1, -1, -1):
		var card: CardData = deck.hand[i]
		if card.id == "panic_static":
			first_card_tax_pending = true
			log_message.emit(LocalizationManager.text("battle.log.panic"))
		elif card.id == "command_delay":
			player.meta["command_delay_active"] = true
			deck.send_to_exhaust(deck.hand.pop_at(i))
		elif card.id == "shattered_focus":
			player.will = max(0, player.will - 1)
			deck.send_to_exhaust(deck.hand.pop_at(i))

func _refresh_enemy_intents_if_needed() -> void:
	for i in range(enemies.size()):
		var e: UnitState = enemies[i]
		e.intent = enemy_ai.next_intent(e, enemy_datas[i], turn_count)
	enemy_intents_updated.emit()

func _cleanup_dead_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].is_dead():
			if player_character != null and player_character.id == "exusiai" and player.burst_active:
				if bool(player.meta.get("chain_trigger_active", false)):
					player.gain_ammo(1)
				if bool(player.meta.get("endless_chain_active", false)):
					deck.next_card_cost_delta -= 1
				if bool(player.meta.get("burst_kill_draw_active", false)):
					_draw_cards(1, "burst_kill_draw")
			RunManager.add_gold(_ascension_scaled_gold(enemy_datas[i].gold_reward))
			enemies.remove_at(i)
			enemy_datas.remove_at(i)

func _end_battle(victory: bool) -> void:
	if battle_finished:
		return
	battle_finished = true
	RunManager.hp = player.hp
	battle_ended.emit(victory)
	if victory:
		var reward_gen: RewardGenerator = RewardGenerator.new(RunManager.rng_seed + turn_count)
		var reward_bias: Dictionary = RunManager.get_reward_bias_weights()
		var active_node: MapNodeModel = RunManager.current_node()
		var is_elite_battle: bool = active_node != null and active_node.node_type == "elite"
		var is_boss_battle: bool = active_node != null and active_node.node_type == "boss"
		var next_reward_boost: bool = RunManager.has_flag("double_next_reward")
		var legendary_offer: bool = RunManager.has_flag("legendary_offer_next_reward")
		var elite_reward_boost: bool = RunManager.has_flag("double_elite_reward") and is_elite_battle
		var card_choices: Array[String] = []
		var gold_reward: int = 20
		var reward_text: String = LocalizationManager.text("reward.body_default")
		var picks_allowed: int = 1
		var module_reward_id: String = ""
		var reward_choice_count: int = 3
		if is_elite_battle:
			reward_choice_count = 4
			var elite_uncommon_pool: Array[String] = Util.get_uncommon_card_reward_pool(player_character.id)
			if legendary_offer:
				for card_id in Util.get_rare_card_reward_pool(player_character.id):
					if not elite_uncommon_pool.has(card_id):
						elite_uncommon_pool.append(card_id)
			card_choices = reward_gen.elite_card_choices(
				Util.get_normal_battle_reward_pool(player_character.id),
				elite_uncommon_pool,
				reward_choice_count,
				reward_bias
			)
			picks_allowed = reward_gen.elite_picks_allowed()
			gold_reward = 42
			reward_text = LocalizationManager.text(
				"reward.body_elite_double" if picks_allowed > 1 else "reward.body_elite"
			)
			if elite_reward_boost:
				picks_allowed = max(picks_allowed, 2)
				gold_reward += 20
				reward_text = LocalizationManager.text("reward.body_elite_double")
				module_reward_id = reward_gen.module_choice(Util.get_module_reward_pool(player_character.id), RunManager.modules)
				RunManager.set_flag("double_elite_reward", false)
			elif reward_gen.rng.randf() < 0.75:
				module_reward_id = reward_gen.module_choice(Util.get_module_reward_pool(player_character.id), RunManager.modules)
		elif is_boss_battle:
			reward_choice_count = 4
			var boss_uncommon_pool: Array[String] = Util.get_uncommon_card_reward_pool(player_character.id)
			if legendary_offer:
				for card_id in Util.get_rare_card_reward_pool(player_character.id):
					if not boss_uncommon_pool.has(card_id):
						boss_uncommon_pool.append(card_id)
			card_choices = reward_gen.elite_card_choices(
				Util.get_normal_battle_reward_pool(player_character.id),
				boss_uncommon_pool,
				reward_choice_count,
				reward_bias
			)
			picks_allowed = 3
			gold_reward = 60
			reward_text = LocalizationManager.text("reward.body_elite_double")
			module_reward_id = reward_gen.module_choice(Util.get_module_reward_pool(player_character.id), RunManager.modules)
		else:
			if legendary_offer:
				reward_choice_count = 4
				var mixed_pool: Array[String] = Util.get_normal_battle_reward_pool(player_character.id)
				for card_id in Util.get_elite_card_reward_pool(player_character.id):
					if not mixed_pool.has(card_id):
						mixed_pool.append(card_id)
				for card_id in Util.get_rare_card_reward_pool(player_character.id):
					if not mixed_pool.has(card_id):
						mixed_pool.append(card_id)
				card_choices = reward_gen.card_choices(mixed_pool, reward_choice_count, reward_bias)
			else:
				card_choices = reward_gen.normal_battle_card_choices(
					Util.get_normal_battle_reward_pool(player_character.id),
					Util.get_elite_card_reward_pool(player_character.id),
					Util.get_rare_card_reward_pool(player_character.id),
					reward_choice_count,
					reward_bias
				)
		if next_reward_boost:
			picks_allowed += 1
			gold_reward += 12
			reward_choice_count = max(reward_choice_count, 4)
			if card_choices.size() < reward_choice_count:
				var extra_pool: Array[String] = Util.get_uncommon_card_reward_pool(player_character.id)
				for existing in card_choices:
					extra_pool.erase(existing)
				for bonus_card in reward_gen.card_choices(extra_pool, reward_choice_count - card_choices.size(), reward_bias):
					card_choices.append(bonus_card)
			RunManager.set_flag("double_next_reward", false)
		if legendary_offer:
			RunManager.set_flag("legendary_offer_next_reward", false)
		RunManager.complete_current_node()
		# 应用难度等级：金币奖励惩罚
		var final_gold_reward: int = _ascension_scaled_gold(gold_reward)
		RunManager.set_pending_rewards({
			"type": "battle_reward",
			"gold": final_gold_reward,
			"text": reward_text,
			"card_choices": card_choices,
			"picks_allowed": picks_allowed,
			"picked_ids": [],
			"module_id": module_reward_id
		})
		if SceneRouter != null:
			SceneRouter.go_reward()
	else:
		_finish_failed_run(false)

func abandon_battle() -> void:
	if battle_finished:
		return
	battle_finished = true
	if player != null:
		RunManager.hp = player.hp
	battle_ended.emit(false)
	_finish_failed_run(false)

func _finish_failed_run(victory_for_stats: bool) -> void:
	# 扩展 summary：记录完整的死亡回顾数据
	var char_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	var char_name: String = LocalizationManager.character_name(char_id, RunManager.character.display_name if RunManager.character != null else "")
	var death_cause: Dictionary = RunManager.last_death_cause.duplicate(true)
	var summary_data: Dictionary = {
		"floor": RunManager.current_floor,
		"gold": RunManager.gold,
		"deck_size": RunManager.deck.size(),
		"character_id": char_id,
		"character_name": char_name,
		"ascension_level": RunManager.ascension_level,
		"final_hp": player.hp if player != null else 0,
		"max_hp": RunManager.max_hp,
		"deck_list": RunManager.deck.duplicate(),
		"charms_list": RunManager.charms.duplicate(),
		"owned_charms_list": RunManager.owned_charms.duplicate(),
		"modules_list": RunManager.modules.duplicate(),
		"tunes_list": RunManager.tunes.duplicate(),
		"death_cause": death_cause,
		"battle_turn": turn_count,
		"abandoned": player != null and player.hp > 0
	}
	RunManager.set_last_run_summary(summary_data)
	var summary: Dictionary = RunManager.last_run_summary.duplicate(true)
	RunManager.record_run_result(victory_for_stats)
	RunManager.abandon_run()
	RunManager.set_last_run_summary(summary)
	if SceneRouter != null:
		SceneRouter.go_defeat()

func _insert_curse_into_discard(curse_id: String) -> void:
	if not card_db.has(curse_id):
		return
	deck.discard_pile.append(card_db[curse_id])

func _handle_enter_burst() -> void:
	if player_character == null or player_character.id != "exusiai":
		player.burst_active = true
		resolver.effect_resolved.emit("burst_activated", {"source": player})
		return
	_prepare_exusiai_burst_next_turn()

func _prepare_exusiai_burst_next_turn() -> void:
	if player == null:
		return
	player.burst_active = false
	player.meta["burst_prepared_next_turn"] = true
	log_message.emit("爆发准备：下回合进入爆发，能量 +2，抽牌 +2。")

func _activate_exusiai_burst(reason: String) -> void:
	if player == null:
		return
	player.burst_active = true
	if player_character != null and player_character.passive_id == "angel_of_bullets":
		player.meta["burst_shot_damage_bonus"] = max(1, int(player.meta.get("burst_shot_damage_bonus", 0)))
	if bool(player.meta.get("burst_entry_resolved_turn", false)):
		log_message.emit("爆发启动：%s。" % reason)
		return
	player.meta["burst_entry_resolved_turn"] = true
	log_message.emit("爆发启动：%s。射击牌 +1 伤害，爆发节拍本回合各触发一次。" % reason)
	resolver.effect_resolved.emit("burst_activated", {"source": player})
	if RunManager.has_tune("ex_burst_entry_mag"):
		player.gain_ammo(1)
		log_message.emit(LocalizationManager.text("battle.log.tune_ex_burst_entry_mag"))
	if _has_relic("ex_m11_storm_permit") and not bool(player.meta.get("storm_permit_used_battle", false)):
		player.meta["storm_permit_used_battle"] = true
		player.gain_ammo(2)
	if _has_relic("ex_h08_angel_shard"):
		_add_temporary_shot_to_hand(0, false)
	if bool(player.meta.get("burst_entry_draw", false)):
		_draw_cards(int(player.meta.get("burst_entry_draw", 0)), "burst_entry_draw")
	if bool(player.meta.get("burst_entry_ammo_once", false)) and not bool(player.meta.get("burst_entry_ammo_once_used_battle", false)):
		player.meta["burst_entry_ammo_once_used_battle"] = true
		player.gain_ammo(int(player.meta.get("burst_entry_ammo_once", 0)))
	if bool(player.meta.get("burst_entry_shot_bonus", false)):
		player.meta["burst_shot_damage_bonus"] = int(player.meta.get("burst_shot_damage_bonus", 0)) + int(player.meta.get("burst_entry_shot_bonus", 0))

func _on_effect_resolved(effect_type: String, payload: Dictionary) -> void:
	match effect_type:
		"block":
			var block_gained: int = int(payload.get("amount", 0))
			if _is_nearl() and block_gained > 0:
				player.meta["gained_block_this_turn"] = int(player.meta.get("gained_block_this_turn", 0)) + block_gained
			if block_gained > 0:
				_hook_block_gained_singularity(block_gained)
		"gain_will":
			player.meta["gained_will_this_turn"] = true
			log_message.emit(LocalizationManager.text("battle.log.will", [int(payload.get("amount", 0))]))
			if bool(player.meta.get("crowned_resolve_active", false)):
				player.add_block(1)
				log_message.emit(LocalizationManager.text("battle.log.crowned_resolve"))
		"gain_ammo":
			var restored_ammo: int = int(payload.get("amount", 0))
			if restored_ammo > 0:
				player.meta["restored_ammo_this_turn"] = int(player.meta.get("restored_ammo_this_turn", 0)) + restored_ammo
				if bool(player.meta.get("fast_tempo_active", false)) and not bool(player.meta.get("fast_tempo_triggered_turn", false)):
					player.meta["fast_tempo_triggered_turn"] = true
					_draw_cards(1, "fast_tempo")
					if bool(player.meta.get("fast_tempo_guard", false)):
						player.add_block(1)
						log_message.emit("快节奏：恢复弹药时获得 1 护盾。")
				if (_has_relic("ex_m03_fast_feeder") or bool(player.meta.get("ammo_refill_draw_first", false))) and not bool(player.meta.get("ammo_refill_draw_first_used_turn", false)):
					player.meta["ammo_refill_draw_first_used_turn"] = true
					_draw_cards(1, "ammo_refill_draw_first")
				if RunManager.has_tune("ex_reload_guard_screen"):
					player.add_block(4)
					log_message.emit(LocalizationManager.text("battle.log.tune_ex_reload_guard_screen"))
				if RunManager.has_tune("ex_first_refill_draw") and not bool(player.meta.get("tune_ex_first_refill_used_battle", false)):
					player.meta["tune_ex_first_refill_used_battle"] = true
					_draw_cards(1, "ex_first_refill_draw")
					player.gain_ammo(1)
					log_message.emit(LocalizationManager.text("battle.log.tune_ex_first_refill_draw"))
				if RunManager.has_flag("ex_rewire_reload_draw") and not bool(player.meta.get("rewire_ex_reload_draw_used_battle", false)):
					player.meta["rewire_ex_reload_draw_used_battle"] = true
					_draw_cards(2, "ex_rewire_reload_draw")
					log_message.emit("重构【装填节拍】启动：首次补弹额外抽 2。")
		"consume_ammo":
			var spent_ammo: int = int(payload.get("amount", 0))
			if spent_ammo > 0:
				player.meta["spent_ammo_this_turn"] = int(player.meta.get("spent_ammo_this_turn", 0)) + spent_ammo
				if _has_relic("ex_m16_heaven_circuit"):
					var spent_total: int = int(player.meta.get("spent_ammo_this_turn", 0))
					var thresholds_before: int = int(floor(float(spent_total - spent_ammo) / 3.0))
					var thresholds_after: int = int(floor(float(spent_total) / 3.0))
					var energy_gain: int = max(0, thresholds_after - thresholds_before)
					if energy_gain > 0:
						player.energy += energy_gain
				if player_character != null and player_character.passive_id == "angel_of_bullets" and not bool(player.meta.get("first_ammo_spent_used_turn", false)):
					player.meta["first_ammo_spent_used_turn"] = true
					player.meta["shot_damage_bonus_turn"] = int(player.meta.get("shot_damage_bonus_turn", 0)) + 1
					if player.burst_active:
						_draw_cards(1, "angel_of_bullets")
				if bool(player.meta.get("ammo_three_energy_active", false)) and int(player.meta.get("spent_ammo_this_turn", 0)) >= 3 and not bool(player.meta.get("ammo_three_energy_used_turn", false)):
					player.meta["ammo_three_energy_used_turn"] = true
					player.energy += 1
				if bool(player.meta.get("overheated_bolt_active", false)):
					player.lose_hp(1)
				if bool(player.meta.get("seamless_reload_active", false)) and player.ammo <= 0 and not bool(player.meta.get("seamless_reload_used_turn", false)):
					player.meta["seamless_reload_used_turn"] = true
					player.gain_ammo(max(1, int(player.meta.get("seamless_reload_amount", 2))))
					log_message.emit("无缝装填：弹药耗尽时立即恢复。")
		"enter_burst":
			_handle_enter_burst()
		"apply_mark":
			player.meta["applied_mark_this_turn"] = int(player.meta.get("applied_mark_this_turn", 0)) + int(payload.get("amount", 0))
			if bool(player.meta.get("angel_mark_active", false)) and not bool(player.meta.get("angel_mark_used_turn", false)):
				player.meta["angel_mark_used_turn"] = true
				var angel_extra_marks: int = _power_plus("angel_mark_bonus", 1, 2)
				for angel_mark_variant in payload.get("targets", []):
					var angel_mark_target: UnitState = angel_mark_variant as UnitState
					if angel_mark_target != null:
						angel_mark_target.add_mark(angel_extra_marks)
						player.meta["applied_mark_this_turn"] = int(player.meta.get("applied_mark_this_turn", 0)) + angel_extra_marks
				log_message.emit("天使标记：追加 %d 层标记。" % angel_extra_marks)
			if _has_relic("ex_m04_target_scope") and not bool(player.meta.get("target_scope_used_turn", false)):
				player.meta["target_scope_used_turn"] = true
				for target_variant in payload.get("targets", []):
					var marked_target: UnitState = target_variant as UnitState
					if marked_target != null:
						marked_target.add_mark(1)
						player.meta["applied_mark_this_turn"] = int(player.meta.get("applied_mark_this_turn", 0)) + 1
			if _has_relic("ex_h03_red_dot_pendant") and not bool(player.meta.get("red_dot_pendant_used_battle", false)):
				player.meta["red_dot_pendant_used_battle"] = true
				for target_variant in payload.get("targets", []):
					var first_mark_target: UnitState = target_variant as UnitState
					if first_mark_target != null:
						first_mark_target.add_mark(2)
						player.meta["applied_mark_this_turn"] = int(player.meta.get("applied_mark_this_turn", 0)) + 2
			if RunManager.has_tune("ex_mark_trace_draw") and not bool(player.meta.get("tune_ex_mark_trace_draw_used_turn", false)):
				player.meta["tune_ex_mark_trace_draw_used_turn"] = true
				_draw_cards(1, "ex_mark_trace_draw")
				log_message.emit(LocalizationManager.text("battle.log.tune_ex_mark_trace_draw"))
		"gain_overload":
			if _has_relic("ashen_halo") and not bool(player.meta.get("ashen_halo_used_battle", false)):
				player.meta["ashen_halo_used_battle"] = true
				player.meta["ashen_halo_prevent_tick_once"] = true
				_draw_cards(2, "ashen_halo")
			if RunManager.has_tune("overload_guard_matrix") and not bool(player.meta.get("tune_overload_guard_used_turn", false)):
				player.add_block(6)
				player.meta["tune_overload_guard_used_turn"] = true
				log_message.emit(LocalizationManager.text("battle.log.tune_overload_guard_matrix"))
			if bool(player.meta.get("sealed_chimera_active", false)):
				player.gain_will(1, player_resource_max)
				log_message.emit(LocalizationManager.text("battle.log.sealed_chimera"))
		"lose_hp":
			player.meta["after_self_damage"] = true
			player.meta["lost_hp_this_turn"] = int(player.meta.get("lost_hp_this_turn", 0)) + int(payload.get("amount", 0))
			player.meta["lost_hp_this_battle"] = int(player.meta.get("lost_hp_this_battle", 0)) + int(payload.get("amount", 0))
			if bool(player.meta.get("shared_burden_active", false)) and not bool(player.meta.get("shared_burden_used", false)):
				player.meta["shared_burden_used"] = true
				_draw_cards(1, "shared_burden")
				player.gain_will(1, player_resource_max)
				log_message.emit(LocalizationManager.text("battle.log.shared_burden"))
			if _has_relic("pain_converter") and int(payload.get("amount", 0)) > 0:
				player.meta["pain_converter_bonus"] = int(player.meta.get("pain_converter_bonus", 0)) + 1
		"gain_echo", "set_echo_charges":
			if _has_relic("echo_pin") and not bool(player.meta.get("echo_pin_used_battle", false)):
				player.meta["echo_pin_used_battle"] = true
				_draw_cards(1, "echo_pin")
			if RunManager.has_tune("echo_guard_lattice"):
				player.add_block(5)
				log_message.emit(LocalizationManager.text("battle.log.tune_echo_guard_lattice"))
		"set_meta_flag":
			var flag_id: String = String(payload.get("flag", ""))
			if not flag_id.is_empty():
				player.meta[flag_id] = true
		"set_meta_value":
			var meta_key: String = String(payload.get("key", ""))
			if not meta_key.is_empty():
				player.meta[meta_key] = int(payload.get("value", 0))
		"damage_per_target_resonance_consume_all", "damage_from_will_and_target_resonance", "damage_resonant_all_consume":
			if bool(player.meta.get("absolute_resonance_active", false)) and int(payload.get("layers", 0)) > 0:
				player.echo_percent = max(player.echo_percent, 50)
			if _has_relic("resonance_prism") and int(payload.get("layers", 0)) > 0:
				_discount_first_hand_card()
		"damage":
			var damage_target: UnitState = payload.get("target", null) as UnitState
			var damage_source: UnitState = payload.get("source", null) as UnitState
			if _is_kaltsit() and damage_target != null and not damage_target.is_dead() and damage_target != player and bool(player.meta.get("kaltsit_when_an_enemy_hp_25_mon3tr_autom", false)):
				var fired_ids: Dictionary = player.meta.get("dead_line_fired_enemy_ids", {})
				if not fired_ids.has(damage_target.id) and damage_target.max_hp > 0 and float(damage_target.hp) / float(damage_target.max_hp) <= 0.25:
					fired_ids[damage_target.id] = true
					player.meta["dead_line_fired_enemy_ids"] = fired_ids
					var dead_line_key: String = "kaltsit_when_an_enemy_hp_25_mon3tr_autom"
					var dead_line_damage: int = 22 if String(player.meta.get(dead_line_key + "__src_card", "")).ends_with("_plus") else 16
					mon3tr_attack(damage_target, dead_line_damage, null)
					log_message.emit("死亡线协议：Mon3tr 自动处决低生命敌人。")
			if _is_nearl() and damage_target == player and bool(payload.get("block_broken", false)) and _has_relic("nearl_m10_broken_shield_counter") and not bool(player.meta.get("nearl_m10_used_turn", false)):
				player.meta["nearl_m10_used_turn"] = true
				gain_nearl_counter(3, null)
			if player_character != null and player_character.id == "exusiai" and damage_source == player and damage_target != null and damage_target.mark > 0:
				if bool(player.meta.get("headline_rhythm_active", false)) and int(player.meta.get("headline_rhythm_triggers_turn", 0)) < int(player.meta.get("headline_rhythm_limit", 1)):
					player.meta["headline_rhythm_triggers_turn"] = int(player.meta.get("headline_rhythm_triggers_turn", 0)) + 1
					_draw_cards(1, "headline_rhythm")
			_check_w_phase_transition(payload.get("target", null) as UnitState)
	state_changed.emit()

func _consume_post_play_bonuses(card: CardData, target: UnitState = null) -> void:
	if card == null:
		return
	if bool(player.meta.get("dobermann_drill_ready", false)) and (card.card_type == "Attack" or _card_has_effective_tag(card, "Arts")):
		player.meta["dobermann_drill_ready"] = false
	if _card_has_effective_tag(card, "Arts"):
		player.meta["support_trigger_ready"] = false
		var bonus_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
		bonus_map.erase("Arts")
		player.meta["next_tag_damage_bonus"] = bonus_map
	if _card_has_effective_tag(card, "Shot"):
		if player_character != null and player_character.passive_id == "angel_of_bullets" and player.burst_active:
			var burst_shots: int = int(player.meta.get("burst_shots_played_turn", 0)) + 1
			player.meta["burst_shots_played_turn"] = burst_shots
			if burst_shots >= 2 and not bool(player.meta.get("burst_cycle_draw_used_turn", false)):
				player.meta["burst_cycle_draw_used_turn"] = true
				_draw_cards(1, "angel_burst_cycle")
				log_message.emit("爆发节拍：第 %d 张射击牌抽 1。" % burst_shots)
			if burst_shots >= 3 and not bool(player.meta.get("burst_cycle_ammo_used_turn", false)):
				player.meta["burst_cycle_ammo_used_turn"] = true
				var ammo_before: int = player.ammo
				player.gain_ammo(1)
				var restored_ammo: int = max(0, player.ammo - ammo_before)
				if restored_ammo > 0:
					_on_effect_resolved("gain_ammo", {"amount": restored_ammo, "source": player})
				log_message.emit("爆发补仓：第 %d 张射击牌返还 1 发弹药。" % burst_shots)
			if burst_shots >= 3 and target != null and not target.is_dead() and not bool(player.meta.get("burst_cycle_followup_used_turn", false)):
				player.meta["burst_cycle_followup_used_turn"] = true
				var burst_followup: EffectData = EffectData.new()
				burst_followup.effect_type = "damage"
				burst_followup.amount = 3
				resolver.resolve_effect(burst_followup, player, target, card)
				log_message.emit("爆发连射：第 %d 张射击牌追加 3 点伤害。" % burst_shots)
		if bool(player.meta.get("hunter_clearance_active_card", false)):
			player.meta["hunter_clearance_active_card"] = false
			player.meta["hunter_clearance_used_turn"] = true
		if int(player.meta.get("next_shot_damage_bonus_charges", 0)) > 0:
			player.meta["next_shot_damage_bonus_charges"] = max(0, int(player.meta.get("next_shot_damage_bonus_charges", 0)) - 1)
			if int(player.meta.get("next_shot_damage_bonus_charges", 0)) <= 0:
				player.meta["next_shot_damage_bonus"] = 0
		if int(player.meta.get("next_shot_cost_reduction_charges", 0)) > 0:
			player.meta["next_shot_cost_reduction_charges"] = max(0, int(player.meta.get("next_shot_cost_reduction_charges", 0)) - 1)
			if int(player.meta.get("next_shot_cost_reduction_charges", 0)) <= 0:
				player.meta["next_shot_cost_reduction"] = 0
		if RunManager.has_flag("ex_rewire_burst_ammo") and player.burst_active and not bool(player.meta.get("rewire_ex_burst_ammo_used_turn", false)):
			player.meta["rewire_ex_burst_ammo_used_turn"] = true
			var ammo_before: int = player.ammo
			player.gain_ammo(1)
			var restored_ammo: int = max(0, player.ammo - ammo_before)
			if restored_ammo > 0:
				_on_effect_resolved("gain_ammo", {"amount": restored_ammo, "source": player})
			log_message.emit("重构【爆发补仓】启动：爆发中首张射击牌返还 1 发弹药。")
	if "MultiHit" in card.tags and _has_relic("ex_h06_gunfire_cross") and not bool(player.meta.get("gunfire_cross_used_turn", false)):
		player.meta["gunfire_cross_used_turn"] = true
	if player.echo_percent > 0:
		var echo_charges: int = int(player.meta.get("echo_charges", 0))
		if echo_charges > 0:
			echo_charges -= 1
			player.meta["echo_charges"] = echo_charges
			if echo_charges <= 0:
				player.clear_echo()
		else:
			player.clear_echo()
	deck.consume_tag_cost_delta(card)

func _draw_cards(count: int, source: String = "generic") -> Array[CardData]:
	var empty_result: Array[CardData] = []
	if count <= 0:
		return empty_result
	# 临床疲劳诅咒：本回合少抽 1 张（抽到时若本次抽牌仍有剩余则立即扣除，否则记为下笔抽牌惩罚）
	var pending_fatigue_penalty: int = int(player.meta.get("clinical_fatigue_draw_penalty", 0))
	if pending_fatigue_penalty > 0:
		count = max(0, count - pending_fatigue_penalty)
		player.meta["clinical_fatigue_draw_penalty"] = 0
		if count <= 0:
			return empty_result
	var hand_before: int = deck.hand.size()
	var capacity: int = max(0, MAX_HAND_SIZE - hand_before)
	var drawn: Array[CardData] = deck.draw_cards(count)
	if drawn.is_empty():
		return empty_result
	# 诅咒卡：抽到即结算惩罚并直接消耗，不进入手牌
	var resolved_curses: Array[CardData] = []
	var fatigue_draw_penalty: int = 0
	for drawn_card in drawn:
		if drawn_card != null and drawn_card.card_type == "Curse" and bool(CURSE_ON_DRAW_IDS.get(drawn_card.id, false)):
			resolver.resolve_card(drawn_card, player, null)
			if drawn_card.id == "kaltsit_s06_clinical_fatigue":
				fatigue_draw_penalty += 1
			deck.hand.erase(drawn_card)
			deck.send_to_exhaust(drawn_card)
			resolved_curses.append(drawn_card)
			log_message.emit("%s：诅咒生效并消耗。" % LocalizationManager.card_name(drawn_card))
	for resolved_curse in resolved_curses:
		drawn.erase(resolved_curse)
	# 临床疲劳：立即从本次抽牌结果中扣除，不足部分留到本回合下一笔抽牌
	if fatigue_draw_penalty > 0 and not drawn.is_empty():
		var immediate_penalty: int = min(fatigue_draw_penalty, drawn.size())
		for _i in range(immediate_penalty):
			var penalized_card: CardData = drawn.pop_back()
			deck.send_to_discard(penalized_card)
		fatigue_draw_penalty -= immediate_penalty
		log_message.emit(LocalizationManager.text("battle.log.clinical_fatigue", [immediate_penalty]))
	if fatigue_draw_penalty > 0:
		player.meta["clinical_fatigue_draw_penalty"] = int(player.meta.get("clinical_fatigue_draw_penalty", 0)) + fatigue_draw_penalty
	if drawn.is_empty():
		return empty_result
	var kept_count: int = min(drawn.size(), capacity)
	var kept_cards: Array[CardData] = []
	var overflow_cards: Array[CardData] = []
	for index in range(drawn.size()):
		if index < kept_count:
			kept_cards.append(drawn[index])
		else:
			overflow_cards.append(drawn[index])
	for _i in range(overflow_cards.size()):
		if not deck.hand.is_empty():
			deck.hand.pop_back()
	for overflow_card in overflow_cards:
		deck.send_to_discard(overflow_card)
	if not kept_cards.is_empty():
		cards_drawn.emit(kept_cards, source)
	if not overflow_cards.is_empty():
		cards_overflowed.emit(overflow_cards, source)
	return kept_cards

func add_card_to_hand_or_discard(card: CardData, source: String = "generated") -> bool:
	if card == null:
		return false
	if deck.hand.size() >= MAX_HAND_SIZE:
		deck.send_to_discard(card)
		var overflow_cards: Array[CardData] = [card]
		cards_overflowed.emit(overflow_cards, source)
		return false
	deck.add_to_hand(card)
	return true

func _add_temporary_arts_to_hand(cost_value: int, upgraded: bool) -> void:
	var pool: Array[String] = [
		"arts_bolt",
		"focused_ray",
		"arc_sliver",
		"measured_blast",
		"echo_conduit",
		"resonance_burst"
	]
	var available: Array[String] = []
	for card_id in pool:
		if card_db.has(card_id):
			available.append(card_id)
	if available.is_empty():
		return
	var seed_source: int = turn_count + int(player.meta.get("played_support_this_turn", 0)) + deck.hand.size()
	var chosen_id: String = available[seed_source % available.size()]
	var generated_card: CardData = (card_db[chosen_id] as CardData).duplicate(true)
	if upgraded and not generated_card.upgraded_id.is_empty() and card_db.has(generated_card.upgraded_id):
		generated_card = (card_db[generated_card.upgraded_id] as CardData).duplicate(true)
	if upgraded:
		generated_card.set_meta("upgraded_visual", true)
	generated_card.cost = cost_value
	generated_card.exhausts = true
	if add_card_to_hand_or_discard(generated_card, "temporary_arts"):
		log_message.emit(LocalizationManager.text("battle.log.voice_of_the_team", [LocalizationManager.card_name(generated_card)]))
		hand_changed.emit()

func _add_temporary_shot_to_hand(cost_value: int, upgraded: bool) -> void:
	var pool: Array[String] = [
		"ex_b01_burst_shot",
		"ex_b05_crossfire_ping",
		"ex_c01_double_tap_burst",
		"ex_c14_hail_entry",
		"ex_r02_precision_suppression"
	]
	var available: Array[String] = []
	for card_id in pool:
		if card_db.has(card_id):
			available.append(card_id)
	if available.is_empty():
		return
	var seed_source: int = turn_count + int(player.meta.get("played_shot_this_turn", 0)) + deck.hand.size() + player.ammo
	var chosen_id: String = available[seed_source % available.size()]
	var generated_card: CardData = (card_db[chosen_id] as CardData).duplicate(true)
	if upgraded and not generated_card.upgraded_id.is_empty() and card_db.has(generated_card.upgraded_id):
		generated_card = (card_db[generated_card.upgraded_id] as CardData).duplicate(true)
	if upgraded:
		generated_card.set_meta("upgraded_visual", true)
	generated_card.cost = cost_value
	generated_card.exhausts = true
	if add_card_to_hand_or_discard(generated_card, "temporary_shot"):
		log_message.emit("天使碎片送来一张临时火力牌：%s。" % LocalizationManager.card_name(generated_card))
		hand_changed.emit()

func _first_living_enemy() -> UnitState:
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			return enemy
	return null

func _any_living_enemy_has_mark() -> bool:
	for enemy in enemies:
		if enemy != null and not enemy.is_dead() and enemy.mark > 0:
			return true
	return false

func _discount_first_hand_card() -> void:
	if deck.hand.is_empty():
		return
	var discounted_card: CardData = deck.hand[0].duplicate(true)
	discounted_card.cost = max(0, discounted_card.cost - 1)
	deck.hand[0] = discounted_card
	hand_changed.emit()

func _has_relic(relic_id: String) -> bool:
	return RunManager.has_relic(relic_id)

func resolve_targets(mode: String, main_target: UnitState) -> Array[UnitState]:
	var result: Array[UnitState] = []
	match mode:
		"self":
			if player != null:
				result.append(player)
			return result
		"enemy":
			if main_target != null:
				result.append(main_target)
			return result
		"all_enemies":
			for enemy in enemies:
				if enemy != null and not enemy.is_dead():
					result.append(enemy)
			return result
		"random_enemy":
			var living_enemies: Array[UnitState] = []
			for enemy in enemies:
				if enemy != null and not enemy.is_dead():
					living_enemies.append(enemy)
			if living_enemies.is_empty():
				return result
			result.append(living_enemies[randi() % living_enemies.size()])
			return result
	return result

func fetch_support_from_draw_or_discard() -> void:
	for pile in [deck.draw_pile, deck.discard_pile]:
		for i in range(pile.size()):
			var card: CardData = pile[i]
			if "Support" in card.tags:
				pile.remove_at(i)
				if not add_card_to_hand_or_discard(card, "fetch_support"):
					log_message.emit(LocalizationManager.text("battle.log.hand_full_overflow", [LocalizationManager.card_name(card)]))
				hand_changed.emit()
				return

func fetch_support_from_discard() -> void:
	for i in range(deck.discard_pile.size()):
		var card: CardData = deck.discard_pile[i]
		if "Support" in card.tags:
			deck.discard_pile.remove_at(i)
			if not add_card_to_hand_or_discard(card, "fetch_support_discard"):
				log_message.emit(LocalizationManager.text("battle.log.hand_full_overflow", [LocalizationManager.card_name(card)]))
			hand_changed.emit()
			return

func peek_cards(count: int) -> void:
	var preview: Array[String] = []
	for i in range(min(count, deck.draw_pile.size())):
		preview.append(LocalizationManager.card_name(deck.draw_pile[deck.draw_pile.size() - 1 - i]))
	log_message.emit(LocalizationManager.text("battle.log.scan", [", ".join(preview)]))

func _apply_w_rule(rule_id: String) -> void:
	match rule_id:
		"hand_limit_down":
			player.meta["next_turn_hand_size"] = 4
			log_message.emit(LocalizationManager.text("battle.log.w_hand"))
		"first_card_tax":
			first_card_tax_pending = true
			log_message.emit(LocalizationManager.text("battle.log.w_tax"))
		_:
			log_message.emit(LocalizationManager.text("battle.log.w_shift"))

func _apply_rule_shift_after_card() -> void:
	if enemies.is_empty():
		return
	if int(player.meta.get("cards_played_this_turn", 0)) != 3:
		return
	if bool(player.meta.get("w_third_triggered_this_turn", false)):
		return
	for i in range(min(enemies.size(), enemy_datas.size())):
		var enemy: UnitState = enemies[i]
		var ed: EnemyData = enemy_datas[i]
		if enemy == null or enemy.is_dead():
			continue
		if ed.ai_profile == "w_boss":
			var phase_three_threshold: int = int(ceil(float(enemy.max_hp) * 0.25))
			var phase_three_active: bool = enemy.hp <= phase_three_threshold or bool(enemy.intent.get("phase_three", false))
			if not phase_three_active:
				continue
			var backlash: int = 1
			player.lose_hp(backlash)
			player.meta["w_third_triggered_this_turn"] = true
			log_message.emit(LocalizationManager.text("battle.log.w_third", [backlash]))
			break

func _check_w_phase_transition(target_unit: UnitState) -> void:
	if target_unit == null or target_unit.is_dead():
		return
	var enemy_index: int = enemies.find(target_unit)
	if enemy_index == -1 or enemy_index >= enemy_datas.size():
		return
	if enemy_datas[enemy_index].id != "w_boss":
		return
	var phase_two_threshold: int = int(ceil(float(target_unit.max_hp) * 0.5))
	var phase_three_threshold: int = int(ceil(float(target_unit.max_hp) * 0.25))
	var intents_stale: bool = false
	# 一回合内从 >50% 直接打到 <=25% 时，二阶段台词不应被跳过：先二阶段再三阶段
	if target_unit.hp <= phase_two_threshold and not bool(target_unit.meta.get("w_phase_two_announced", false)):
		target_unit.meta["w_phase_two_announced"] = true
		log_message.emit("W 开始认真起来了。她的节奏更快，假动作也更多。")
		intents_stale = true
	if target_unit.hp <= phase_three_threshold and not bool(target_unit.meta.get("w_phase_three_announced", false)):
		target_unit.meta["w_phase_three_announced"] = true
		log_message.emit("W 彻底摊牌了。她开始同时压速度、炸药和假动作。")
		intents_stale = true
	if intents_stale:
		_refresh_enemy_intents_if_needed()

func _tick_status_decay(unit: UnitState) -> void:
	for status_id in ["weak", "vulnerable", "slow"]:
		if int(unit.statuses.get(status_id, 0)) > 0:
			unit.statuses[status_id] = int(unit.statuses[status_id]) - 1
			if int(unit.statuses[status_id]) <= 0:
				unit.clear_status(status_id)

func _queue_auto_end_turn_check() -> void:
	if auto_end_queued:
		return
	auto_end_queued = true
	call_deferred("_auto_end_turn_if_needed")

func _auto_end_turn_if_needed() -> void:
	auto_end_queued = false
	if SettingsManager == null or not bool(SettingsManager.get_settings().get("auto_end_turn", false)):
		return
	if active_side != "player":
		return
	if player == null or player.is_dead() or enemies.is_empty():
		return
	if _has_playable_card():
		return
	log_message.emit(LocalizationManager.text("battle.log.auto_end"))
	if SfxManager != null:
		SfxManager.play_end_turn()
	end_player_turn()

func _has_playable_card() -> bool:
	for card in deck.hand:
		if card == null or card.card_type == "Curse":
			continue
		var actual_cost: int = current_card_cost(card)
		if player.energy >= actual_cost:
			return true
	return false

# ===== 角色 Power 卡钩子 =====
# 修复"卡牌描述承诺了效果但从未实现"的卡：所有钩子集中在这一区域，
# 由 play_card / 回合流程 / _on_effect_resolved / EffectResolver 调用。

func _random_enemy() -> UnitState:
	var candidates: Array[UnitState] = []
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _deal_power_damage(target: UnitState, amount: int, label: String) -> void:
	if target == null or target.is_dead() or amount <= 0:
		return
	var effect: EffectData = EffectData.new()
	effect.effect_type = "damage"
	effect.amount = amount
	resolver.resolve_effect(effect, player, target, null)
	log_message.emit("%s：对 %s 造成 %d 点伤害。" % [label, _unit_battle_name(target), amount])

func _unit_battle_name(unit: UnitState) -> String:
	if unit == null:
		return ""
	for ed in enemy_datas:
		if ed != null and ed.id == unit.id:
			return LocalizationManager.enemy_name(ed.id, ed.display_name)
	if not unit.display_name.is_empty():
		return unit.display_name
	return unit.id

func _add_next_shot_damage(bonus: int) -> void:
	if bonus <= 0:
		return
	player.meta["next_shot_damage_bonus"] = int(player.meta.get("next_shot_damage_bonus", 0)) + bonus
	player.meta["next_shot_damage_bonus_charges"] = int(player.meta.get("next_shot_damage_bonus_charges", 0)) + 1

# 打出卡牌时按 tag 触发的 Power 卡效果（在效果结算前调用，便于"第 N 张 +伤"作用于当前卡）
func _hook_power_cards_on_play(card: CardData, counts_as_shot: bool, counts_as_support: bool) -> void:
	if card == null or player == null:
		return
	var shot_count: int = int(player.meta.get("played_shot_this_turn", 0))
	var cards_played: int = int(player.meta.get("cards_played_this_turn", 0))
	var medical_count: int = int(player.meta.get("played_medical_this_turn", 0))
	var command_count: int = int(player.meta.get("played_command_this_turn", 0))
	var counts_as_medical: bool = _card_has_effective_tag(card, "Medical") and card.card_type != "Power"
	var counts_as_command: bool = _card_has_effective_tag(card, "Command") and card.card_type != "Power"
	var counts_as_protocol: bool = _card_has_effective_tag(card, "Protocol") and card.card_type != "Power"

	# --- 能天使 ---
	if counts_as_shot:
		if bool(player.meta.get("team_callout_active", false)):
			player.add_block(_power_plus("team_callout_block", 2, 3))
			log_message.emit("战术呼叫：射击牌提供护盾。")
		if bool(player.meta.get("fireline_control_active", false)) and (shot_count == 2 or shot_count == 4):
			var fireline_bonus: int = _power_plus("fireline_control_bonus", 2, 3)
			var fireline_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
			fireline_map["Shot"] = int(fireline_map.get("Shot", 0)) + fireline_bonus
			player.meta["next_tag_damage_bonus"] = fireline_map
			log_message.emit("火线控制：第 %d 张射击 +%d 伤害。" % [shot_count, fireline_bonus])
		if bool(player.meta.get("stabilized_track_active", false)) and shot_count % 2 == 0:
			var track_bonus: int = _power_plus("stabilized_track_bonus", 1, 2)
			var track_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
			track_map["Shot"] = int(track_map.get("Shot", 0)) + track_bonus
			player.meta["next_tag_damage_bonus"] = track_map
		if bool(player.meta.get("angel_combo_active", false)) and player.burst_active and shot_count % 2 == 0:
			_draw_cards(1, "angel_combo")
			player.gain_ammo(1)
			_add_next_shot_damage(_power_plus("angel_combo_active", 0, 1))
			log_message.emit("天使连击：爆发中第 %d 张射击，抽 1 并恢复 1 弹药。" % shot_count)
		if bool(player.meta.get("angelic_storm_first_shot_pending", false)):
			player.meta["angelic_storm_first_shot_pending"] = false
			player.gain_ammo(1)
			log_message.emit("天使风暴：本回合第一张射击返还 1 弹药。")
	if counts_as_support:
		if bool(player.meta.get("urban_mobility_active", false)) and int(player.meta.get("played_support_this_turn", 0)) == 1:
			deck.next_tag_cost_delta["Shot"] = int(deck.next_tag_cost_delta.get("Shot", 0)) - 1
			_add_next_shot_damage(_power_plus("urban_mobility_active", 0, 2))
			log_message.emit("城市机动：下一张射击费用 -1。")
		if bool(player.meta.get("pl_standard_kit_active", false)) and int(player.meta.get("played_support_this_turn", 0)) == 1:
			player.gain_ammo(1)
			player.add_block(_power_plus("pl_standard_kit_block", 3, 5))
			log_message.emit("P.L. 标准装备：恢复 1 弹药并获得护盾。")
		if bool(player.meta.get("air_cover_active", false)) and int(player.meta.get("played_support_this_turn", 0)) == 1:
			var air_damage: int = _power_plus("air_cover_damage", 3, 4)
			for _hit in range(2):
				_deal_power_damage(_random_enemy(), air_damage, "空中掩护")
		if bool(player.meta.get("cover_network_active", false)):
			_add_next_shot_damage(_power_plus("support_shot_bonus", 1, 2))
	if bool(player.meta.get("combo_rhythm_active", false)) and cards_played % 3 == 0:
		_draw_cards(1, "combo_rhythm")
		_add_next_shot_damage(_power_plus("combo_rhythm_active", 0, 1))
		log_message.emit("连点节奏：第 %d 张牌，抽 1。" % cards_played)

	# --- 凯尔希 ---
	if _is_kaltsit():
		if counts_as_medical:
			if bool(player.meta.get("kaltsit_first_medical_each_turn_gives_3_", false)) and medical_count == 1:
				player.add_block(_power_plus("kaltsit_first_medical_each_turn_gives_3_", 3, 4))
				log_message.emit("医疗防线：本回合第一张医疗牌给予护盾。")
			if bool(player.meta.get("kaltsit_medical_cards_give_2_block", false)):
				player.add_block(_power_plus("kaltsit_medical_cards_give_2_block", 2, 3))
			if bool(player.meta.get("kaltsit_this_turn_each_medical_draws_1_m", false)):
				var loop_limit: int = _power_plus("kaltsit_this_turn_each_medical_draws_1_m", 2, 3)
				var loop_used: int = int(player.meta.get("kaltsit_medical_loop_used_turn", 0))
				if loop_used < loop_limit:
					player.meta["kaltsit_medical_loop_used_turn"] = loop_used + 1
					_draw_cards(1, "medical_loop")
			if bool(player.meta.get("kaltsit_medical_makes_next_mon3tr_attack", false)):
				var concord_bonus: int = _power_plus("kaltsit_medical_makes_next_mon3tr_attack", 2, 3)
				player.meta["mon3tr_next_attack_bonus"] = int(player.meta.get("mon3tr_next_attack_bonus", 0)) + concord_bonus
				player.meta["mon3tr_next_attack_bonus_charges"] = int(player.meta.get("mon3tr_next_attack_bonus_charges", 0)) + 1
			if bool(player.meta.get("kaltsit_first_medical_each_turn_discount", false)) and medical_count == 1:
				deck.next_tag_cost_delta["Command"] = int(deck.next_tag_cost_delta.get("Command", 0)) - 1
				if String(player.meta.get("kaltsit_first_medical_each_turn_discount__src_card", "")).ends_with("_plus"):
					_draw_cards(1, "tactical_ecosystem")
		if counts_as_command:
			if bool(player.meta.get("kaltsit_medical_makes_next_mon3tr_attack", false)):
				player.meta["next_heal_bonus"] = _power_plus("kaltsit_medical_makes_next_mon3tr_attack", 2, 3)
			if bool(player.meta.get("kaltsit_every_second_command_each_turn_m", false)) and command_count == 2:
				var matrix_damage: int = _power_plus("kaltsit_every_second_command_each_turn_m", 8, 11)
				var matrix_target: UnitState = _random_enemy()
				if matrix_target != null:
					mon3tr_attack(matrix_target, matrix_damage, null)
					log_message.emit("指令矩阵：第二张指令牌使 Mon3tr 攻击。")
			if bool(player.meta.get("kaltsit_first_command_each_turn_repairs_", false)) and command_count == 1:
				repair_mon3tr(_power_plus("kaltsit_first_command_each_turn_repairs_", 1, 2), "command_link")
			if bool(player.meta.get("kaltsit_first_medical_each_turn_discount", false)) and command_count == 1 and not String(player.meta.get("kaltsit_first_medical_each_turn_discount__src_card", "")).is_empty():
				deck.next_tag_cost_delta["Medical"] = int(deck.next_tag_cost_delta.get("Medical", 0)) - 1
				if String(player.meta.get("kaltsit_first_medical_each_turn_discount__src_card", "")).ends_with("_plus"):
					_draw_cards(1, "tactical_ecosystem")
			if bool(player.meta.get("kaltsit_if_medical_was_played_this_turn_", false)) and card.id == "kaltsit_u09_rapid_procedure":
				if int(player.meta.get("played_medical_this_turn", 0)) > 0:
					deck.next_tag_cost_delta["Command"] = int(deck.next_tag_cost_delta.get("Command", 0)) - 1
					var rapid_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
					rapid_map["Command"] = int(rapid_map.get("Command", 0)) + _power_plus("kaltsit_if_medical_was_played_this_turn_", 3, 5)
					player.meta["next_tag_damage_bonus"] = rapid_map
		if counts_as_protocol and bool(player.meta.get("kaltsit_first_protocol_each_turn_draws_1", false)) and not bool(player.meta.get("kaltsit_protocol_sync_used_turn", false)):
			player.meta["kaltsit_protocol_sync_used_turn"] = true
			_draw_cards(_power_plus("kaltsit_first_protocol_each_turn_draws_1", 1, 2), "protocol_synchronization")
			deck.next_tag_cost_delta["Medical"] = int(deck.next_tag_cost_delta.get("Medical", 0)) - 1
			deck.next_tag_cost_delta["Command"] = int(deck.next_tag_cost_delta.get("Command", 0)) - 1
			log_message.emit("协议同步：第一张协议牌抽牌并使下一张医疗/指令费用 -1。")
		# 打出即触发的一次性效果
		match card.id:
			"ex_r01_extended_mag", "ex_r01_extended_mag_plus":
				if int(player.meta.get("battle_start_bonus_ammo", 0)) > 0:
					player.gain_ammo(1)
			"kaltsit_c16_command_recall", "kaltsit_c16_command_recall_plus":
				_fetch_command_from_discard_discounted()
				if card.id.ends_with("_plus"):
					_draw_cards(1, "command_recall_plus")
			"kaltsit_c19_overflow_care_plus":
				_draw_cards(1, "overflow_care_plus")
			"kaltsit_r17_optimal_solution", "kaltsit_r17_optimal_solution_plus":
				_discount_command_or_medical_in_hand()
			"kaltsit_c28_field_supply", "kaltsit_c28_field_supply_plus":
				_discover_tag_cards_to_hand(["Medical"], 3 if not card.id.ends_with("_plus") else 4, 1, false)
			"kaltsit_c29_command_preparation", "kaltsit_c29_command_preparation_plus":
				_discover_tag_cards_to_hand(["Command"], 3 if not card.id.ends_with("_plus") else 4, 1, false)
			"kaltsit_l04_rhodes_island_highest_authority", "kaltsit_l04_rhodes_island_highest_authority_plus":
				var pick_count: int = 2 if not card.id.ends_with("_plus") else 3
				var discover_count: int = 5 if not card.id.ends_with("_plus") else 6
				_discover_tag_cards_to_hand(["Medical", "Command", "Protocol"], discover_count, pick_count, true)
			"kaltsit_u19_black_box_scheduling", "kaltsit_u19_black_box_scheduling_plus":
				_fetch_medical_or_command_from_draw_pile(5, 1 if not card.id.ends_with("_plus") else 2)

# 突发进入时的 Power 卡效果（_activate_exusiai_burst 调用）
func _hook_burst_entry_powers() -> void:
	if player == null:
		return
	if bool(player.meta.get("heated_barrel_active", false)) and not bool(player.meta.get("heated_barrel_used_turn", false)):
		player.meta["heated_barrel_used_turn"] = true
		var barrel_damage: int = _power_plus("heated_barrel_damage", 3, 4)
		var barrel_hits: int = max(1, int(player.meta.get("heated_barrel_hits", 2)))
		for _hit in range(barrel_hits):
			_deal_power_damage(_random_enemy(), barrel_damage, "炽热枪口")
	if bool(player.meta.get("angelic_storm_active", false)):
		player.meta["angelic_storm_first_shot_pending"] = true

# 凯尔希回合开始的 Power 卡效果
func _hook_kaltsit_turn_start_powers() -> void:
	if player == null or not _is_kaltsit():
		return
	if bool(player.meta.get("kaltsit_at_turn_start_if_hp_50_heal_2", false)):
		if player.max_hp > 0 and float(player.hp) / float(player.max_hp) <= 0.5:
			var auto_heal: int = _power_plus("kaltsit_at_turn_start_if_hp_50_heal_2", 2, 3)
			player.heal(auto_heal)
			player.meta["hp_healed_this_turn"] = int(player.meta.get("hp_healed_this_turn", 0)) + auto_heal
			log_message.emit("自动输注：回合开始治疗 %d 点生命。" % auto_heal)

# 玩家治疗结算后的 Power 卡钩子（EffectResolver 调用）
func _hook_player_heal_applied(before_hp: int, after_hp: int, requested_amount: int) -> void:
	if player == null:
		return
	var healed: int = max(0, after_hp - before_hp)
	var overflow: int = max(0, requested_amount - healed)
	if healed <= 0 and overflow <= 0:
		return
	if _is_kaltsit():
		if healed > 0 and not bool(player.meta.get("kaltsit_heal_hook_resolving", false)):
			player.meta["kaltsit_heal_hook_resolving"] = true
			if bool(player.meta.get("kaltsit_first_hp_heal_each_turn_draws_1", false)) and not bool(player.meta.get("kaltsit_long_term_care_used_turn", false)):
				player.meta["kaltsit_long_term_care_used_turn"] = true
				_draw_cards(1, "long_term_care")
				if String(player.meta.get("kaltsit_first_hp_heal_each_turn_draws_1__src_card", "")).ends_with("_plus"):
					repair_mon3tr(1, "long_term_care_plus")
			if bool(player.meta.get("kaltsit_operating_room_active", false)):
				repair_mon3tr(1, "operating_room")
			if bool(player.meta.get("kaltsit_this_turn_each_hp_heal_makes_mon", false)):
				var twin_target: UnitState = _random_enemy()
				if twin_target != null:
					mon3tr_attack(twin_target, healed, null)
					log_message.emit("双线作战：Mon3tr 造成等量伤害。")
			if bool(player.meta.get("kaltsit_healing_block_gain_and_mon3tr_re", false)):
				var percent: int = _power_plus("kaltsit_healing_block_gain_and_mon3tr_re", 25, 35)
				player.add_block(max(1, int(floor(float(healed) * float(percent) / 100.0))))
				repair_mon3tr(max(1, int(floor(float(healed) * float(percent) / 100.0))), "medical_singularity")
			player.meta["kaltsit_heal_hook_resolving"] = false
		if overflow > 0 and not bool(player.meta.get("kaltsit_overflow_hook_resolving", false)):
			player.meta["kaltsit_overflow_hook_resolving"] = true
			var overflow_source: String = ""
			if bool(player.meta.get("kaltsit_healing_overflow_becomes_block", false)):
				player.add_block(overflow)
				overflow_source = "溢出护盾"
				if String(player.meta.get("kaltsit_healing_overflow_becomes_block__src_card", "")).ends_with("_plus"):
					repair_mon3tr(max(1, int(floor(float(overflow) / 2.0))), "overflow_shielding_plus")
			if bool(player.meta.get("kaltsit_healing_overflow_repairs_mon3tr", false)):
				repair_mon3tr(overflow, "overflow_repair")
				overflow_source = "溢出修复"
				if String(player.meta.get("kaltsit_healing_overflow_repairs_mon3tr__src_card", "")).ends_with("_plus"):
					player.add_block(max(1, int(floor(float(overflow) / 2.0))))
			if bool(player.meta.get("kaltsit_this_turn_healing_overflow_repai", false)):
				repair_mon3tr(overflow, "overflow_care")
				overflow_source = "溢出救护"
			if not overflow_source.is_empty():
				log_message.emit("%s：治疗溢出 %d 点生效。" % [overflow_source, overflow])
			player.meta["kaltsit_overflow_hook_resolving"] = false

# 玩家获得护盾后的奇点钩子（_on_effect_resolved "block" 分支调用）
func _hook_block_gained_singularity(amount: int) -> void:
	if player == null or not _is_kaltsit():
		return
	if not bool(player.meta.get("kaltsit_healing_block_gain_and_mon3tr_re", false)):
		return
	if bool(player.meta.get("kaltsit_singularity_resolving", false)):
		return
	player.meta["kaltsit_singularity_resolving"] = true
	var percent: int = _power_plus("kaltsit_healing_block_gain_and_mon3tr_re", 25, 35)
	var derived: int = max(1, int(floor(float(amount) * float(percent) / 100.0)))
	var before_hp: int = player.hp
	player.heal(derived)
	if player.hp > before_hp:
		player.meta["hp_healed_this_turn"] = int(player.meta.get("hp_healed_this_turn", 0)) + (player.hp - before_hp)
	repair_mon3tr(derived, "medical_singularity")
	player.meta["kaltsit_singularity_resolving"] = false

# 战场手术室：治疗量加成（EffectResolver heal 分支调用）
func _hook_operating_room_heal_bonus() -> int:
	if player == null or not _is_kaltsit():
		return 0
	if bool(player.meta.get("kaltsit_operating_room_active", false)):
		return _power_plus("kaltsit_operating_room_active", 2, 3)
	return 0

# 最优解简化实现：手牌中费用最高的一张指令/医疗牌本回合费用变为 0
func _discount_command_or_medical_in_hand() -> void:
	var best_index: int = -1
	var best_cost: int = -1
	for index in range(deck.hand.size()):
		var hand_card: CardData = deck.hand[index]
		if hand_card == null or not (_card_has_effective_tag(hand_card, "Command") or _card_has_effective_tag(hand_card, "Medical")):
			continue
		if hand_card.cost > best_cost:
			best_cost = hand_card.cost
			best_index = index
	if best_index < 0 or best_cost <= 0:
		return
	var discounted: CardData = deck.hand[best_index].duplicate(true)
	discounted.cost = 0
	deck.hand[best_index] = discounted
	log_message.emit("最优解：%s 本回合费用变为 0。" % LocalizationManager.card_name(discounted))
	hand_changed.emit()

# 从弃牌堆取一张指令牌入手并本回合费用 -1（指令回溯）
func _fetch_command_from_discard_discounted() -> void:
	for index in range(deck.discard_pile.size()):
		var discard_card: CardData = deck.discard_pile[index]
		if discard_card == null or not _card_has_effective_tag(discard_card, "Command"):
			continue
		var fetched: CardData = discard_card.duplicate(true)
		fetched.cost = max(0, fetched.cost - 1)
		deck.discard_pile.remove_at(index)
		if add_card_to_hand_or_discard(fetched, "command_recall"):
			log_message.emit("指令回溯：%s 返回手牌且费用 -1。" % LocalizationManager.card_name(fetched))
		else:
			log_message.emit(LocalizationManager.text("battle.log.command_recall_overflow", [LocalizationManager.card_name(fetched)]))
		hand_changed.emit()
		return

# 发现类简化实现：从角色卡池随机取 count 张对应 tag 的卡，自动选用 picks 张入手（费用 -1 或归零）
func _discover_tag_cards_to_hand(pool_tags: Array, discover_count: int, picks: int, cost_zero: bool) -> void:
	var character_id: String = String(player_character.id) if player_character != null else "kaltsit"
	var pool: Array[CardData] = []
	for candidate_id in Util.get_character_card_pool_by_tags(character_id, pool_tags, false, false):
		var candidate: CardData = card_db.get(candidate_id, null) as CardData
		if candidate == null or candidate.card_type == "Curse" or candidate.card_type == "Power":
			continue
		pool.append(candidate)
	if pool.is_empty():
		return
	pool.shuffle()
	var added: int = 0
	for index in range(min(discover_count, pool.size())):
		if added >= picks:
			break
		if deck.hand.size() >= MAX_HAND_SIZE:
			log_message.emit(LocalizationManager.text("battle.log.discover_hand_full"))
			break
		var discovered: CardData = pool[index].duplicate(true)
		discovered.cost = 0 if cost_zero else max(0, discovered.cost - 1)
		deck.hand.append(discovered)
		added += 1
		log_message.emit("发现：%s 加入手牌。" % LocalizationManager.card_name(discovered))
	hand_changed.emit()

# 黑箱调度简化实现：从抽牌堆顶部找医疗/指令牌入手
func _fetch_medical_or_command_from_draw_pile(look_count: int, picks: int) -> void:
	var found: int = 0
	var scanned: int = 0
	var index: int = 0
	while scanned < look_count and index < deck.draw_pile.size() and found < picks:
		scanned += 1
		var pile_card: CardData = deck.draw_pile[index]
		if pile_card == null or not (_card_has_effective_tag(pile_card, "Medical") or _card_has_effective_tag(pile_card, "Command")):
			index += 1
			continue
		if deck.hand.size() >= MAX_HAND_SIZE:
			log_message.emit(LocalizationManager.text("battle.log.dispatch_hand_full", [LocalizationManager.card_name(pile_card)]))
			break
		deck.hand.append(pile_card)
		deck.draw_pile.remove_at(index)
		found += 1
		log_message.emit("黑箱调度：%s 从牌堆顶加入手牌。" % LocalizationManager.card_name(pile_card))
	if found > 0:
		hand_changed.emit()
