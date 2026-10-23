extends SceneTree

const BATTLE_MANAGER_SCRIPT := preload("res://scripts/battle/BattleManager.gd")
const EFFECT_RESOLVER_SCRIPT := preload("res://scripts/battle/EffectResolver.gd")
const DECK_CONTROLLER_SCRIPT := preload("res://scripts/battle/DeckController.gd")
const UNIT_STATE_SCRIPT := preload("res://scripts/battle/UnitState.gd")

var failures: Array[String] = []
var test_run_manager: StubRunManager = StubRunManager.new()
var test_card_db: Dictionary = {}
var test_enemy_db: Dictionary = {}
var test_character: CharacterData = null
var test_character_exusiai: CharacterData = null
var test_character_kaltsit: CharacterData = null
var test_character_nearl: CharacterData = null
var test_managers: Array[BattleManager] = []

class StubRunManager:
	var character: CharacterData = null
	var current_floor: int = 1
	var current_node_id: String = ""
	var gold: int = 99
	var hp: int = 72
	var max_hp: int = 72
	var deck: Array[String] = []
	var modules: Array[String] = []
	var charms: Array[String] = []
	var owned_charms: Array[String] = []
	var tunes: Array[String] = []
	var story_flags: Dictionary = {}
	var pending_rewards: Dictionary = {}
	var rng_seed: int = 24680
	var last_run_summary: Dictionary = {}
	var run_won: bool = false
	var ascension_level: int = 0

	func ascension_enemy_hp_bonus() -> int:
		return 0

	func ascension_enemy_damage_bonus() -> int:
		return 0

	func ascension_gold_penalty() -> float:
		return 0.0

	func ascension_starting_energy_penalty() -> int:
		return 0

	func start_new_run(char_data: CharacterData, seed_value: int = 24680) -> void:
		character = char_data
		current_floor = 1
		current_node_id = ""
		gold = 99
		max_hp = char_data.max_hp
		hp = char_data.max_hp
		deck.clear()
		for card_id in char_data.starter_deck:
			deck.append(String(card_id))
		modules.clear()
		charms.clear()
		owned_charms.clear()
		tunes.clear()
		story_flags.clear()
		pending_rewards.clear()
		last_run_summary.clear()
		run_won = false
		rng_seed = seed_value

	func current_node():
		return null

	func add_module(module_id: String) -> void:
		if not modules.has(module_id):
			modules.append(module_id)

	func has_tune(tune_id: String) -> bool:
		return tunes.has(tune_id)

	func has_flag(flag_id: String) -> bool:
		return bool(story_flags.get(flag_id, false))

	func set_flag(flag_id: String, value = true) -> void:
		story_flags[flag_id] = value

	func add_gold(amount: int) -> void:
		gold += amount

	func has_relic(relic_id: String) -> bool:
		return modules.has(relic_id) or charms.has(relic_id)

	func get_reward_bias_weights() -> Dictionary:
		return {}

	func complete_current_node() -> void:
		pass

	func set_pending_rewards(reward_data: Dictionary) -> void:
		pending_rewards = reward_data.duplicate(true)

	func set_last_run_summary(summary: Dictionary) -> void:
		last_run_summary = summary.duplicate(true)

	func record_run_result(_victory: bool) -> void:
		pass

	func abandon_run() -> void:
		pass

class StubLocalizationManager:
	func text(_key: String, args := []):
		if args is Array and not args.is_empty():
			return " ".join(args)
		return ""

	func character_name(_id: String, fallback: String) -> String:
		return fallback

	func enemy_name(_id: String, fallback: String) -> String:
		return fallback

	func card_name(card) -> String:
		if card == null:
			return ""
		return String(card.id)

class TestBattleStub:
	var deck = DECK_CONTROLLER_SCRIPT.new()
	var player: UnitState
	var enemies: Array[UnitState] = []
	var player_resource_max: int = 10
	var card_db: Dictionary = {}
	var logs: Array[String] = []
	var last_peek_count: int = 0

	func resolve_targets(mode: String, main_target: UnitState) -> Array[UnitState]:
		match mode:
			"self":
				var result_self: Array[UnitState] = []
				if player != null:
					result_self.append(player)
				return result_self
			"enemy":
				var result_enemy: Array[UnitState] = []
				if main_target != null:
					result_enemy.append(main_target)
				return result_enemy
			"all_enemies":
				var result_all: Array[UnitState] = []
				for enemy in enemies:
					result_all.append(enemy)
				return result_all
			"random_enemy":
				var result_random: Array[UnitState] = []
				if not enemies.is_empty():
					result_random.append(enemies[0])
				return result_random
		var result_empty: Array[UnitState] = []
		return result_empty

	func fetch_support_from_draw_or_discard() -> void:
		for pile in [deck.draw_pile, deck.discard_pile]:
			for i in range(pile.size()):
				var card: CardData = pile[i]
				if "Support" in card.tags:
					deck.hand.append(card)
					pile.remove_at(i)
					return

	func fetch_support_from_discard() -> void:
		for i in range(deck.discard_pile.size()):
			var card: CardData = deck.discard_pile[i]
			if "Support" in card.tags:
				deck.hand.append(card)
				deck.discard_pile.remove_at(i)
				return

	func peek_cards(count: int) -> void:
		last_peek_count = count

	func _draw_cards(count: int, _source: String = "test") -> Array[CardData]:
		if count <= 0:
			var empty: Array[CardData] = []
			return empty
		return deck.draw_cards(count)

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var scene_router: Node = _scene_router()
	if scene_router != null:
		scene_router.suppress_navigation = true
	var exit_code: int = _run()
	if scene_router != null:
		scene_router.suppress_navigation = false
	await _flush_teardown()
	quit(exit_code)

func _scene_router() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("SceneRouter")
	return null

func _run() -> int:
	var card_db: Dictionary = _load_test_card_db()
	var char_data: CharacterData = _load_test_character()
	var exusiai_data: CharacterData = _load_test_character_exusiai()
	var kaltsit_data: CharacterData = _load_test_character_kaltsit()
	var nearl_data: CharacterData = _load_test_character_nearl()
	if char_data == null:
		_fail("无法加载 Amiya 角色资源。")
	if exusiai_data == null:
		_fail("无法加载 Exusiai 角色资源。")
	if kaltsit_data == null:
		_fail("无法加载 Kal'tsit 角色资源。")
	if nearl_data == null:
		_fail("无法加载 Nearl 角色资源。")
	if card_db.size() < 109:
		_fail("卡牌资源数量异常，预期至少 109，实际 %d。" % card_db.size())
	_run_project_boot_check()
	_run_card_resource_checks(card_db)
	_run_card_effect_checks(card_db)
	_run_card_playability_checks(card_db, char_data, exusiai_data, kaltsit_data, nearl_data)
	_run_module_effect_checks(card_db, char_data)
	_run_status_interaction_checks(card_db)

	if failures.is_empty():
		print("CARD_SMOKE_TEST_OK")
		return 0

	push_error("CARD_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _run_manager():
	return test_run_manager

func _load_test_card_db() -> Dictionary:
	if test_card_db.is_empty():
		test_card_db = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	return test_card_db

func _load_test_enemy_db() -> Dictionary:
	if test_enemy_db.is_empty():
		test_enemy_db = Util.load_enemy_db(ResourceLoader.CACHE_MODE_IGNORE)
	return test_enemy_db

func _load_test_character() -> CharacterData:
	if test_character == null:
		test_character = Util.load_character("amiya", ResourceLoader.CACHE_MODE_IGNORE)
	return test_character

func _load_test_character_exusiai() -> CharacterData:
	if test_character_exusiai == null:
		test_character_exusiai = Util.load_character("exusiai", ResourceLoader.CACHE_MODE_IGNORE)
	return test_character_exusiai

func _load_test_character_kaltsit() -> CharacterData:
	if test_character_kaltsit == null:
		test_character_kaltsit = Util.load_character("kaltsit", ResourceLoader.CACHE_MODE_IGNORE)
	return test_character_kaltsit

func _load_test_character_nearl() -> CharacterData:
	if test_character_nearl == null:
		test_character_nearl = Util.load_character("nearl", ResourceLoader.CACHE_MODE_IGNORE)
	return test_character_nearl

func _run_project_boot_check() -> void:
	if not ResourceLoader.exists("res://scenes/Main.tscn"):
		_fail("无法加载主场景 Main.tscn。")

func _run_card_resource_checks(card_db: Dictionary) -> void:
	var supported_effects: Dictionary = {
		"damage": true,
		"block": true,
		"draw": true,
		"gain_energy": true,
		"gain_will": true,
		"lose_hp": true,
		"apply_status": true,
		"weaken_enemy_team": true,
		"damage_all": true,
		"spend_all_will_damage": true,
		"fetch_support": true,
		"peek_draw": true,
		"gain_gold": true,
		"consume_will": true,
		"apply_resonance": true,
		"heal": true,
		"gain_echo": true,
		"set_next_tag_cost_delta": true,
		"set_no_block_this_turn": true,
		"channel_will_draw": true,
		"cleanse_debuff": true,
		"set_support_draw_trigger": true,
		"set_meta_flag": true,
		"set_meta_value": true,
		"add_meta_value": true,
		"gain_overload": true,
		"set_next_tag_damage_bonus": true,
		"spend_will_damage": true,
		"damage_resonant_all": true,
		"damage_random_hits": true,
		"damage_ignore_block_percent": true,
		"damage_resonant_all_consume": true,
		"damage_per_support": true,
		"fetch_support_from_discard": true,
		"reduce_overload": true,
		"damage_plus_overload": true,
		"damage_per_lost_hp_ten": true,
		"damage_all_plus_overload": true,
		"set_next_card_cost_delta": true,
		"add_card_to_discard": true,
		"add_card_to_hand": true,
		"discard_then_draw_if_support_energy": true,
		"channel_damage_will": true,
		"channel_support_draw_cost": true,
		"channel_next_arts_bonus": true,
		"channel_damage_turn_end": true,
		"channel_echo_next_turn": true,
		"damage_per_target_resonance_consume_all": true,
		"damage_from_will_and_target_resonance": true,
		"set_echo_charges": true,
		"draw_per_resonant_enemy_reduce_drawn_arts": true,
		"set_battleplan": true,
		"add_random_supports_to_hand_free": true,
		"damage_from_lost_hp_battle_percent_all": true,
		"gain_ammo": true,
		"fill_ammo": true,
		"set_max_ammo_bonus": true,
		"consume_ammo": true,
		"enter_burst": true,
		"exit_burst": true,
		"apply_mark": true,
		"queue_reload": true,
		"damage_all_marked": true,
		"damage_plus_mark": true,
		"damage_consume_all_mark": true,
		"add_random_cards_to_hand_free": true,
		"fetch_low_cost_from_discard": true,
		"heal_or_block_if_full": true,
		"repair_mon3tr": true,
		"repair_mon3tr_draw_if_reaches_max": true,
		"repair_mon3tr_to_max": true,
		"repair_mon3tr_to_value": true,
		"damage_mon3tr": true,
		"mon3tr_damage": true,
		"mon3tr_damage_all": true,
		"mon3tr_damage_by_integrity": true,
		"set_protocol_start": true,
		"draw_discount_medical_command": true,
		"set_mon3tr_max_bonus": true,
		"set_mon3tr_auto_repair_bonus": true,
		"set_mon3tr_repair_bonus": true,
		"set_mon3tr_attack_bonus": true,
		"set_mon3tr_next_attack_bonus": true,
		"set_mon3tr_next_attack_multiplier": true,
		"set_mon3tr_low_integrity_no_penalty": true,
		"set_integrity_loss_reduction": true,
		"set_mon3tr_reactive_repair": true,
		"heal_if_low_else_block": true,
		"enter_kaltsit_meltdown": true,
		"gain_radiance": true,
		"gain_counter": true,
		"consume_counter_damage": true,
		"reduce_next_damage": true,
		"damage_if_block_bonus": true,
		"damage_plus_radiance": true,
		"discard_cards": true
	}
	for card_id in card_db.keys():
		var card: CardData = card_db[card_id]
		if card.card_type != "Curse" and card.effects.is_empty():
			_fail("%s 没有效果定义。" % card.id)
		for effect in card.effects:
			if not supported_effects.has(effect.effect_type):
				_fail("%s 使用了未支持的效果类型 %s。" % [card.id, effect.effect_type])
		if Util.card_art_path(card.id).is_empty():
			_fail("%s 缺少卡图资源。" % card.id)

func _run_card_playability_checks(card_db: Dictionary, char_data: CharacterData, exusiai_data: CharacterData, kaltsit_data: CharacterData, nearl_data: CharacterData) -> void:
	if char_data == null or exusiai_data == null or kaltsit_data == null or nearl_data == null:
		return
	for card_id in card_db.keys():
		var card: CardData = card_db[card_id]
		if card == null or card.card_type == "Curse":
			continue
		var active_character: CharacterData = char_data
		if card.id.begins_with("ex_"):
			active_character = exusiai_data
		elif card.id.begins_with("kaltsit_"):
			active_character = kaltsit_data
		elif card.id.begins_with("nearl_"):
			active_character = nearl_data
		var manager: BattleManager = BATTLE_MANAGER_SCRIPT.new()
		manager.RunManager = _run_manager()
		manager.LocalizationManager = StubLocalizationManager.new()
		manager.enemy_ai.RunManager = _run_manager()
		manager.player_character = active_character
		var enemy_db: Dictionary = _load_test_enemy_db()
		var scout_enemy: EnemyData = enemy_db.get("reunion_scout", null) as EnemyData
		if scout_enemy == null:
			_fail("无法加载基础敌人 reunion_scout，无法执行出牌性测试。")
			return
		manager.enemy_list = [scout_enemy]
		manager.start_battle()
		manager.resolver.RunManager = _run_manager()
		manager.player.energy = max(manager.player.energy, card.cost)
		manager.deck.hand.clear()
		manager.deck.hand.append(card)
		var played: bool = manager.play_card(0, 0)
		if not played:
			_fail("%s 无法在基础战斗测试中正常打出。" % card.id)
		manager.dispose_runtime_state()
		manager.free()

func _run_card_effect_checks(card_db: Dictionary) -> void:
	_check_direct_damage(card_db["arts_bolt"], 6)
	_check_block(card_db["guard_pulse"], 5)
	_check_block(card_db["barrier_formula"], 5)
	_check_draw_and_will(card_db["mind_alignment"], 2, 1)
	_check_draw_and_will(card_db["mental_tuning"], 2, 1)
	_check_conditional_will(card_db["tactical_reorder"])
	_check_damage(card_db["focus_pulse"], 7)
	_check_focus_pulse_bonus(card_db["focus_pulse"])
	_check_block(card_db["emergency_shield"], 9)
	_check_damage(card_db["resonance_burst"], 12)
	_check_resonance_burst_bonus(card_db["resonance_burst"])
	_check_support_draw_trigger(card_db["field_command"])
	_check_apply_resonance(card_db["resonance_mark"], 3)
	_check_damage(card_db["focused_ray"], 9)
	_check_focused_ray_bonus(card_db["focused_ray"])
	_check_next_support_discount(card_db["tactical_briefing"])
	_check_self_damage_and_energy(card_db["bloodline_casting"], 3, 2)
	_check_channel_queue(card_db["channel_pulse"], 3, 1)
	_check_stabilize_line(card_db["stabilize_line"])
	_check_energy(card_db["command_sync"], 1)
	_check_fetch_support(card_db["signal_relay"])
	_check_double_damage(card_db["guided_fire"], 10)
	_check_block_and_gold(card_db["rescue_corridor"], 6, 10)
	_check_draw_and_will(card_db["discipline_note"], 1, 1)
	_check_peek(card_db["pulse_scan"], 3)
	_check_self_damage_and_will(card_db["burn_will"], 4, 3)
	_check_self_damage_and_enemy_damage(card_db["overclock_arts"], 16, 3)
	_check_draw_and_team_weak(card_db["tactical_calm"], 2, 1)
	_check_echo_conduit(card_db["echo_conduit"])
	_check_arc_sliver(card_db["arc_sliver"])
	_check_no_block_this_turn(card_db["mind_pressure"])
	_check_harmonic_cut(card_db["harmonic_cut"])
	_check_damage(card_db["pressure_wave"], 4)
	_check_echo_lattice(card_db["echo_lattice"])
	_check_resonant_insight(card_db["resonant_insight"])
	_check_crowned_resolve(card_db["crowned_resolve"])
	_check_grand_equation(card_db["grand_equation"])
	_check_final_vector(card_db["final_vector"])
	_check_overclock_casting(card_db["overclock_casting"])
	_check_damage(card_db["measured_blast"], 14)
	_check_clear_intent(card_db["clear_intent"])
	_check_phase_tap(card_db["phase_tap"])
	_check_split_tone(card_db["split_tone"])
	_check_coordinated_strike(card_db["coordinated_strike"])
	_check_meta_flag(card_db["rhodes_formation"], "rhodes_formation_active")
	_check_draw_and_hp_loss(card_db["desperate_focus"], 3, 4)
	_check_crisis_surge(card_db["crisis_surge"])
	_check_arc_collapse(card_db["arc_collapse"])
	_check_controlled_detonation(card_db["controlled_detonation"])
	_check_thought_acceleration(card_db["thought_acceleration"])
	_check_widened_spectrum(card_db["widened_spectrum"])
	_check_meta_flag(card_db["tactical_network"], "tactical_network_active")
	_check_chain_reaction(card_db["chain_reaction"])
	_check_emergency_order(card_db["emergency_order"])
	_check_dobermann_drill_order(card_db["dobermann_drill_order"])
	_check_exusiai_cover_fire(card_db["exusiai_cover_fire"])
	_check_precise_break(card_db["precise_break"])
	_check_resonance_field(card_db["resonance_field"], card_db["resonance_mark"])
	_check_prism_shatter(card_db["prism_shatter"])
	_check_medical_evac_route(card_db["medical_evac_route"])
	_check_meta_flag(card_db["elite_coordination"], "elite_coordination_active")
	_check_tactical_encirclement(card_db["tactical_encirclement"])
	_check_harmonic_spike(card_db["harmonic_spike"])
	_check_reckless_invocation(card_db["reckless_invocation"])
	_check_ace_last_stand(card_db["ace_last_stand"])
	_check_black_ring_method(card_db["black_ring_method"])
	_check_survival_reflex(card_db["survival_reflex"])
	_check_will_transfusion(card_db["will_transfusion"])
	_check_mirrored_wave(card_db["mirrored_wave"])
	_check_last_argument(card_db["last_argument"])
	_check_terminal_appeal(card_db["terminal_appeal"])
	_check_ashes_to_ashes(card_db["ashes_to_ashes"])
	_check_frequency_lock(card_db["frequency_lock"])
	_check_strategic_rotation(card_db["strategic_rotation"])
	_check_forbidden_formula(card_db["forbidden_formula"])
	_check_unstable_channel(card_db["unstable_channel"])
	_check_collapse_frequency(card_db["collapse_frequency"])
	_check_feedback_loop(card_db["feedback_loop"])
	_check_blaze_forward_breach(card_db["blaze_forward_breach"])
	_check_greythroat_suppression(card_db["greythroat_suppression"])
	_check_frostleaf_delay_field(card_db["frostleaf_delay_field"])
	_check_pain_for_power(card_db["pain_for_power"])
	_check_nerve_burn(card_db["nerve_burn"])
	_check_curse_passthrough(card_db["overloaded_nerves"])
	_check_meta_flag(card_db["sealed_chimera"], "sealed_chimera_active")
	_check_zero_range_cast(card_db["zero_range_cast"])
	_check_singing_fracture(card_db["singing_fracture"])
	_check_meta_flag(card_db["voice_of_the_team"], "voice_of_the_team_active")
	_check_meta_flag(card_db["shared_burden"], "shared_burden_active")
	_check_meta_flag(card_db["forbidden_crown"], "forbidden_crown_active")
	_check_chimera_protocol(card_db["chimera_protocol"])
	_check_the_cost_of_mercy(card_db["the_cost_of_mercy"])
	_check_resonance_harvest(card_db["resonance_harvest"], card_db["arts_bolt"], card_db["guard_pulse"])
	_check_meta_flag(card_db["harmonic_dominion"], "harmonic_dominion_active")
	_check_sevenfold_echo(card_db["sevenfold_echo"])
	_check_unified_battleplan(card_db["unified_battleplan"])
	_check_controlled_overload(card_db["controlled_overload"], card_db["burn_will"])
	_check_meta_flag(card_db["voice_of_the_leader"], "voice_of_the_leader_active")
	_check_ashes_remember(card_db["ashes_remember"])
	_check_final_directive(card_db["final_directive"])
	_check_meta_flag(card_db["absolute_resonance"], "absolute_resonance_active")
	_check_landship_wide_order(card_db["landship_wide_order"])
	_check_ember_judgement(card_db["ember_judgement"])
	_check_unstable_resonance(card_db["unstable_resonance"])
	_check_curse_passthrough(card_db["mental_noise"])
	_check_curse_passthrough(card_db["command_delay"])
	_check_curse_passthrough(card_db["ashen_guilt"])
	_check_curse_passthrough(card_db["shattered_focus"])
	_check_curse_passthrough(card_db["hesitation"])
	_check_curse_passthrough(card_db["panic_static"])
	_check_curse_passthrough(card_db["blast_countdown"])
	_check_curse_passthrough(card_db["burn"])

func _run_module_effect_checks(card_db: Dictionary, char_data: CharacterData) -> void:
	_check_start_of_turn_module("reserve_battery", char_data, char_data.starting_energy + 1, 0)
	_check_start_of_turn_module("nearl_crest", char_data, char_data.starting_energy, 8)
	_check_field_medic_pack(char_data)
	_check_field_command_badge(card_db, char_data)
	_check_signal_booster(card_db, char_data)
	_check_ashen_thread(card_db, char_data)

func _run_status_interaction_checks(card_db: Dictionary) -> void:
	_check_strength_bonus(card_db["arts_bolt"], 2, 8)
	_check_weak_penalty(card_db["focused_ray"], 6)
	_check_slow_penalty(card_db["focused_ray"], 6)
	_check_vulnerable_bonus(card_db["focused_ray"], 14)
	_check_block_absorption(card_db["focused_ray"], 5, 4)

func _new_stub() -> Dictionary:
	var stub := TestBattleStub.new()
	stub.card_db = _load_test_card_db()
	var player: UnitState = UNIT_STATE_SCRIPT.new()
	player.id = "amiya"
	player.display_name = "Amiya"
	player.max_hp = 72
	player.hp = 72
	player.energy = 3
	stub.player = player
	var enemy: UnitState = UNIT_STATE_SCRIPT.new()
	enemy.id = "dummy"
	enemy.display_name = "Dummy"
	enemy.max_hp = 100
	enemy.hp = 100
	stub.enemies = [enemy]
	var resolver: EffectResolver = EFFECT_RESOLVER_SCRIPT.new(stub)
	resolver.RunManager = _run_manager()
	return {"stub": stub, "player": player, "enemy": enemy, "resolver": resolver}

func _new_battle_manager(char_data: CharacterData, module_ids: Array[String], deck_ids: Array[String]) -> BattleManager:
	var run_manager = _run_manager()
	if run_manager == null:
		_fail("测试环境缺少 RunManager 自动加载。")
		return null
	run_manager.start_new_run(char_data, 24680)
	run_manager.modules.clear()
	run_manager.charms.clear()
	run_manager.owned_charms.clear()
	run_manager.tunes.clear()
	for module_id in module_ids:
		run_manager.add_module(module_id)
	run_manager.deck = deck_ids.duplicate()
	var enemy_db: Dictionary = _load_test_enemy_db()
	var enemy_data: EnemyData = enemy_db.get("reunion_scout", null) as EnemyData
	var manager: BattleManager = BATTLE_MANAGER_SCRIPT.new()
	test_managers.append(manager)
	manager.RunManager = run_manager
	manager.LocalizationManager = StubLocalizationManager.new()
	manager.enemy_ai.RunManager = run_manager
	manager.player_character = char_data
	if enemy_data != null:
		manager.enemy_list = [enemy_data]
	manager.start_battle()
	manager.resolver.RunManager = run_manager
	return manager

func _check_direct_damage(card: CardData, expected: int) -> void:
	_check_damage(card, expected)

func _check_damage(card: CardData, expected: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected:
		_fail("%s 伤害异常，预期 %d，实际 %d。" % [card.id, expected, dealt])

func _check_double_damage(card: CardData, expected_total: int) -> void:
	_check_damage(card, expected_total)

func _check_block(card: CardData, expected: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.block != expected:
		_fail("%s 护盾异常，预期 %d，实际 %d。" % [card.id, expected, player.block])

func _check_draw_and_will(card: CardData, expected_draw: int, expected_will: int) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card, card, card, card])
	resolver.resolve_card(card, player, enemy)
	if player.will != expected_will:
		_fail("%s 意志异常，预期 %d，实际 %d。" % [card.id, expected_will, player.will])
	if stub.deck.hand.size() != expected_draw:
		_fail("%s 抽牌异常，预期 %d，实际 %d。" % [card.id, expected_draw, stub.deck.hand.size()])

func _check_conditional_will(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var stub1: TestBattleStub = ctx1["stub"]
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	_seed_draw_pile(stub1.deck, [card, card, card])
	resolver1.resolve_card(card, player1, enemy1)
	if player1.will != 0:
		_fail("%s 在未打出术式时不应获得意志。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var stub2: TestBattleStub = ctx2["stub"]
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	_seed_draw_pile(stub2.deck, [card, card, card])
	player2.meta["played_arts_this_turn"] = true
	resolver2.resolve_card(card, player2, enemy2)
	if player2.will != 1:
		_fail("%s 在打出术式后应获得 1 点意志。" % card.id)

func _check_energy(card: CardData, expected_gain: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var before: int = player.energy
	resolver.resolve_card(card, player, enemy)
	if player.energy != before + expected_gain:
		_fail("%s 能量异常，预期 %+d，实际 %+d。" % [card.id, expected_gain, player.energy - before])

func _check_fetch_support(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var card_db: Dictionary = _load_test_card_db()
	_seed_draw_pile(stub.deck, [card_db["focus_pulse"], card_db["arts_bolt"]])
	_seed_discard_pile(stub.deck, [card_db["command_sync"]])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.is_empty() or stub.deck.hand[0].id != "command_sync":
		_fail("%s 没有成功取回支援牌。" % card.id)

func _check_block_and_gold(card: CardData, expected_block: int, expected_gold_gain: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var run_manager = _run_manager()
	if run_manager == null:
		_fail("测试环境缺少 RunManager 自动加载。")
		return
	var before_gold: int = run_manager.gold
	resolver.resolve_card(card, player, enemy)
	if player.block != expected_block:
		_fail("%s 护盾异常，预期 %d，实际 %d。" % [card.id, expected_block, player.block])
	if run_manager.gold - before_gold != expected_gold_gain:
		_fail("%s 金币异常，预期 %+d，实际 %+d。" % [card.id, expected_gold_gain, run_manager.gold - before_gold])

func _check_peek(card: CardData, expected: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var stub: TestBattleStub = ctx["stub"]
	resolver.resolve_card(card, player, enemy)
	if int(stub.last_peek_count) != expected:
		_fail("%s 预览抽牌数异常，预期 %d，实际 %d。" % [card.id, expected, int(stub.last_peek_count)])

func _check_self_damage_and_will(card: CardData, hp_loss: int, will_gain: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.hp != 72 - hp_loss:
		_fail("%s 自伤异常，预期损失 %d，实际损失 %d。" % [card.id, hp_loss, 72 - player.hp])
	if player.will != will_gain:
		_fail("%s 意志异常，预期 %d，实际 %d。" % [card.id, will_gain, player.will])

func _check_self_damage_and_enemy_damage(card: CardData, expected_damage: int, hp_loss: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected_damage:
		_fail("%s 伤害异常，预期 %d，实际 %d。" % [card.id, expected_damage, dealt])
	if player.hp != 72 - hp_loss:
		_fail("%s 自伤异常，预期损失 %d，实际损失 %d。" % [card.id, hp_loss, 72 - player.hp])

func _check_draw_and_team_weak(card: CardData, expected_draw: int, expected_weak: int) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card, card, card, card])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != expected_draw:
		_fail("%s 抽牌异常，预期 %d，实际 %d。" % [card.id, expected_draw, stub.deck.hand.size()])
	if int(enemy.statuses.get("weak", 0)) != expected_weak:
		_fail("%s 虚弱异常，预期 %d，实际 %d。" % [card.id, expected_weak, int(enemy.statuses.get("weak", 0))])

func _check_echo_conduit(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 4
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 14:
		_fail("%s 在 4 点意志时应造成 14 伤害，实际 %d。" % [card.id, dealt])

func _check_focus_pulse_bonus(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["support_played_this_turn"] = true
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 10:
		_fail("%s 在本回合打出过支援后应造成 10 伤害，实际 %d。" % [card.id, dealt])

func _check_resonance_burst_bonus(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 4
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 16:
		_fail("%s 在 4 点意志时应造成 16 伤害，实际 %d。" % [card.id, dealt])

func _check_curse_passthrough(card: CardData) -> void:
	if card == null:
		_fail("存在无法加载的诅咒卡。")

func _check_start_of_turn_module(module_id: String, char_data: CharacterData, expected_energy: int, expected_block: int) -> void:
	var manager: BattleManager = _new_battle_manager(char_data, [module_id], char_data.starter_deck)
	if manager.player.energy != expected_energy:
		_fail("%s 能量异常，预期 %d，实际 %d。" % [module_id, expected_energy, manager.player.energy])
	if manager.player.block != expected_block:
		_fail("%s 护盾异常，预期 %d，实际 %d。" % [module_id, expected_block, manager.player.block])

func _check_field_medic_pack(char_data: CharacterData) -> void:
	var manager: BattleManager = _new_battle_manager(char_data, ["field_medic_pack"], char_data.starter_deck)
	manager.player.hp = 60
	manager.turn_count = 1
	manager._apply_start_of_turn_modules()
	if manager.player.hp != 64:
		_fail("field_medic_pack 生命异常，预期 64，实际 %d。" % manager.player.hp)

func _check_field_command_badge(card_db: Dictionary, char_data: CharacterData) -> void:
	var manager: BattleManager = _new_battle_manager(char_data, ["field_command_badge"], ["field_command", "tactical_briefing", "arts_bolt"])
	manager.deck.hand = [card_db["field_command"], card_db["tactical_briefing"], card_db["arts_bolt"]]
	manager.deck.draw_pile.clear()
	manager.player.energy = 3
	var played_ok: bool = manager.play_card(0, 0)
	if not played_ok:
		_fail("field_command_badge 测试中第一张支援牌未成功打出。")
		return
	if manager.player.energy != 3:
		_fail("field_command_badge 第一次支援后应返还能量到 3，实际 %d。" % manager.player.energy)
	var second_ok: bool = manager.play_card(0, 0)
	if not second_ok:
		_fail("field_command_badge 测试中第二张支援牌未成功打出。")
		return
	if manager.player.energy != 2:
		_fail("field_command_badge 不应对第二张支援再次返还能量，实际 %d。" % manager.player.energy)

func _check_signal_booster(card_db: Dictionary, char_data: CharacterData) -> void:
	var manager: BattleManager = _new_battle_manager(char_data, ["signal_booster"], ["field_command", "arts_bolt", "guard_pulse"])
	manager.deck.hand = [card_db["field_command"], card_db["arts_bolt"]]
	manager.deck.draw_pile.clear()
	manager.deck.draw_pile.append(card_db["guard_pulse"])
	var played_ok: bool = manager.play_card(0, 0)
	if not played_ok:
		_fail("signal_booster 测试中第一张支援牌未成功打出。")
		return
	var ids: Array[String] = []
	for hand_card in manager.deck.hand:
		ids.append(hand_card.id)
	if "guard_pulse" not in ids:
		_fail("signal_booster 未在第一张支援后额外抽 1 张牌。")

func _check_ashen_thread(card_db: Dictionary, char_data: CharacterData) -> void:
	var manager: BattleManager = _new_battle_manager(char_data, ["ashen_thread"], ["arts_bolt"])
	manager.deck.hand = [card_db["arts_bolt"]]
	manager.player.meta["after_self_damage"] = true
	var played_ok: bool = manager.play_card(0, 0)
	if not played_ok:
		_fail("ashen_thread 测试中术式牌未成功打出。")
		return
	var enemy: UnitState = manager.enemies[0]
	var dealt: int = enemy.max_hp - enemy.hp
	if dealt != 9:
		_fail("ashen_thread 应让下一张术式额外造成 3 点伤害，预期 9，实际 %d。" % dealt)
	if bool(manager.player.meta.get("after_self_damage", false)):
		_fail("ashen_thread 触发后应清除 after_self_damage 标记。")

func _check_strength_bonus(card: CardData, strength: int, expected_damage: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.apply_status("strength", strength)
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected_damage:
		_fail("力量加成异常，预期 %d，实际 %d。" % [expected_damage, dealt])

func _check_weak_penalty(card: CardData, expected_damage: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.apply_status("weak", 1)
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected_damage:
		_fail("虚弱减伤异常，预期 %d，实际 %d。" % [expected_damage, dealt])

func _check_slow_penalty(card: CardData, expected_damage: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.apply_status("slow", 1)
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected_damage:
		_fail("迟滞减伤异常，预期 %d，实际 %d。" % [expected_damage, dealt])

func _check_vulnerable_bonus(card: CardData, expected_damage: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.apply_status("vulnerable", 1)
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != expected_damage:
		_fail("易伤增伤异常，预期 %d，实际 %d。" % [expected_damage, dealt])

func _check_block_absorption(card: CardData, initial_block: int, expected_hp_loss: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.block = initial_block
	resolver.resolve_card(card, player, enemy)
	var hp_loss: int = enemy.max_hp - enemy.hp
	if hp_loss != expected_hp_loss:
		_fail("护盾吸收异常，预期实际掉血 %d，实际 %d。" % [expected_hp_loss, hp_loss])

func _check_support_draw_trigger(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if int(player.meta.get("support_draw_trigger", 0)) != 1:
		_fail("%s 没有正确设置支援抽牌触发。" % card.id)

func _check_apply_resonance(card: CardData, expected: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if enemy.resonance != expected:
		_fail("%s 共振异常，预期 %d，实际 %d。" % [card.id, expected, enemy.resonance])

func _check_focused_ray_bonus(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 3
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 13:
		_fail("%s 在 3 点意志时应造成 13 伤害，实际 %d。" % [card.id, dealt])

func _check_next_support_discount(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var card_db: Dictionary = _load_test_card_db()
	var support_card: CardData = card_db["signal_relay"]
	resolver.resolve_card(card, player, enemy)
	var cost: int = stub.deck.effective_cost(support_card)
	if cost != max(0, support_card.cost - 1):
		_fail("%s 未正确降低下一张支援牌费用，预期 %d，实际 %d。" % [card.id, max(0, support_card.cost - 1), cost])

func _check_self_damage_and_energy(card: CardData, hp_loss: int, energy_gain: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var before_energy: int = player.energy
	resolver.resolve_card(card, player, enemy)
	if player.hp != 72 - hp_loss:
		_fail("%s 自伤异常，预期损失 %d，实际损失 %d。" % [card.id, hp_loss, 72 - player.hp])
	if player.energy != before_energy + energy_gain:
		_fail("%s 能量异常，预期 %+d，实际 %+d。" % [card.id, energy_gain, player.energy - before_energy])

func _check_channel_queue(card: CardData, expected_will: int, expected_draw: int) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	var queue: Array = player.meta.get("channel_queue", [])
	if queue.size() != 1:
		_fail("%s 没有正确进入引导队列。" % card.id)
		return
	var entry: Dictionary = queue[0]
	if int(entry.get("will", 0)) != expected_will or int(entry.get("draw", 0)) != expected_draw:
		_fail("%s 引导效果异常，预期 will=%d draw=%d，实际 will=%d draw=%d。" % [card.id, expected_will, expected_draw, int(entry.get("will", 0)), int(entry.get("draw", 0))])

func _check_stabilize_line(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.apply_status("weak", 1)
	player.meta["played_support_this_turn"] = 1
	resolver.resolve_card(card, player, enemy)
	if player.block != 7:
		_fail("%s 护盾异常，预期 7，实际 %d。" % [card.id, player.block])
	if int(player.statuses.get("weak", 0)) != 0:
		_fail("%s 净化异常，虚弱应被移除。" % card.id)

func _check_arc_sliver(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 2
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 10:
		_fail("%s 在 2 点意志时应造成 10 伤害，实际 %d。" % [card.id, dealt])

func _check_no_block_this_turn(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.will != 2:
		_fail("%s 应获得 2 点意志，实际 %d。" % [card.id, player.will])
	if not bool(player.meta.get("no_block_this_turn", false)):
		_fail("%s 未正确施加本回合无法获得护盾。" % card.id)

func _check_harmonic_cut(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card])
	enemy.resonance = 2
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 6:
		_fail("%s 基础伤害异常。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 对有共振目标应抽 1 张牌。" % card.id)

func _check_harmonic_spike(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card])
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 5:
		_fail("%s 应造成 5 点伤害。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 对有共振目标应抽 1 张牌。" % card.id)

func _check_reckless_invocation(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.overload != 3:
		_fail("%s 应获得 3 层精神负荷。" % card.id)
	if 100 - enemy.hp != 18:
		_fail("%s 应对敌人造成 18 点伤害。" % card.id)

func _check_ace_last_stand(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.hp = 20
	resolver.resolve_card(card, player, enemy)
	if player.block != 15:
		_fail("%s 应获得 15 点护盾。" % card.id)
	if player.energy != 5:
		_fail("%s 在低血量时应额外获得 2 点能量。" % card.id)

func _check_black_ring_method(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.overload = 3
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 13:
		_fail("%s 在 3 层精神负荷时应造成 13 点伤害。" % card.id)

func _check_survival_reflex(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.hp = 20
	player.overload = 3
	resolver.resolve_card(card, player, enemy)
	if player.hp != 26:
		_fail("%s 低血量时应回复至 26 点生命。" % card.id)
	if player.overload != 1:
		_fail("%s 低血量时应移除 2 层精神负荷。" % card.id)

func _check_will_transfusion(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 3
	_seed_draw_pile(stub.deck, [card, card])
	resolver.resolve_card(card, player, enemy)
	if player.will != 1:
		_fail("%s 应消耗 2 点意志后剩余 1 点。" % card.id)
	if stub.deck.hand.size() != 2:
		_fail("%s 应抽 2 张牌。" % card.id)
	if player.energy != 4:
		_fail("%s 应额外获得 1 点能量。" % card.id)

func _check_mirrored_wave(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.echo_percent = 50
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 20:
		_fail("%s 在 Echo 激活时应造成 20 点伤害。" % card.id)

func _check_last_argument(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.hp = 20
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 30:
		_fail("%s 在低血量时应总共造成 30 点伤害。" % card.id)

func _check_terminal_appeal(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["lost_hp_this_battle"] = 23
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 20:
		_fail("%s 在本战已失去 23 点生命时应造成 20 点伤害。" % card.id)

func _check_ashes_to_ashes(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	stub.enemies.append(enemy2)
	player.overload = 3
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 87 or enemy2.hp != 87:
		_fail("%s 在 3 层精神负荷时应对全体造成 13 点伤害。" % card.id)

func _check_frequency_lock(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if enemy.resonance != 2:
		_fail("%s 应施加 2 层共振，实际 %d。" % [card.id, enemy.resonance])

func _check_strategic_rotation(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var card_db: Dictionary = _load_test_card_db()
	stub.deck.hand.clear()
	stub.deck.hand.append(card_db["field_command"])
	_seed_draw_pile(stub.deck, [card_db["arts_bolt"], card_db["guard_pulse"]])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != 2:
		_fail("%s 应弃 1 抽 2，当前手牌数 %d。" % [card.id, stub.deck.hand.size()])
	if player.energy != 4:
		_fail("%s 弃掉支援牌后应获得 1 点能量，实际 %d。" % [card.id, player.energy])
	if stub.deck.discard_pile.is_empty() or stub.deck.discard_pile[0].id != "field_command":
		_fail("%s 没有正确弃掉支援牌。" % card.id)

func _check_forbidden_formula(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 16:
		_fail("%s 应造成 16 点术式伤害。" % card.id)
	if stub.deck.discard_pile.is_empty() or stub.deck.discard_pile[0].id != "burn":
		_fail("%s 应向弃牌堆加入 1 张灼痕。" % card.id)

func _check_unstable_channel(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	var queue: Array = player.meta.get("channel_queue", [])
	if queue.size() != 1:
		_fail("%s 没有正确加入引导队列。" % card.id)
		return
	var entry: Dictionary = queue[0]
	if String(entry.get("type", "")) != "damage_will":
		_fail("%s 队列类型错误，实际 %s。" % [card.id, String(entry.get("type", ""))])
	if int(entry.get("damage", 0)) != 12 or int(entry.get("will", 0)) != 2:
		_fail("%s 引导内容错误，预期 damage=12 will=2。" % card.id)
	if player.overload != 1:
		_fail("%s 应获得 1 层精神负荷。" % card.id)

func _check_collapse_frequency(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 3
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 9:
		_fail("%s 消耗 3 层共振时应造成 9 点伤害。" % card.id)
	if enemy.resonance != 0:
		_fail("%s 应消耗目标全部共振。" % card.id)

func _check_feedback_loop(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if player.echo_percent != 50:
		_fail("%s 应赋予 50%% Echo。" % card.id)
	if enemy.resonance != 3:
		_fail("%s 应再施加 2 层共振，实际 %d。" % [card.id, enemy.resonance])

func _check_blaze_forward_breach(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	var stub: TestBattleStub = ctx["stub"]
	stub.enemies.append(enemy2)
	player.meta["lost_hp_this_turn"] = 2
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 87 or enemy2.hp != 87:
		_fail("%s 在本回合失去过生命时应对全体造成 13 点伤害。" % card.id)

func _check_greythroat_suppression(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["played_support_this_turn"] = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 15:
		_fail("%s 在打出过支援后应总共造成 15 点伤害。" % card.id)

func _check_frostleaf_delay_field(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 1
	_seed_draw_pile(stub.deck, [card])
	resolver.resolve_card(card, player, enemy)
	if int(enemy.statuses.get("slow", 0)) != 2:
		_fail("%s 应施加 2 层迟滞。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 对有共振目标时应抽 1 张牌。" % card.id)

func _check_pain_for_power(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var card_db: Dictionary = _load_test_card_db()
	resolver.resolve_card(card, player, enemy)
	if player.hp != 70:
		_fail("%s 应失去 2 点生命，实际生命 %d。" % [card.id, player.hp])
	if player.will != 1:
		_fail("%s 应获得 1 点意志。" % card.id)
	if stub.deck.effective_cost(card_db["arts_bolt"]) != 0:
		_fail("%s 应让下一张牌费用 -1。" % card.id)

func _check_echo_lattice(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.echo_percent != 50:
		_fail("%s 应赋予 50%% Echo，实际 %d%%。" % [card.id, player.echo_percent])

func _check_resonant_insight(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var stub1: TestBattleStub = ctx1["stub"]
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	_seed_draw_pile(stub1.deck, [card, card])
	enemy1.resonance = 1
	resolver1.resolve_card(card, player1, enemy1)
	if stub1.deck.hand.size() != 2:
		_fail("%s 在敌人已有共振时应抽 2 张牌。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	resolver2.resolve_card(card, player2, enemy2)
	if enemy2.resonance != 2:
		_fail("%s 在无人有共振时应施加 2 层共振。" % card.id)

func _check_crowned_resolve(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if not bool(player.meta.get("crowned_resolve_active", false)):
		_fail("%s 未正确启用冠冕意志效果。" % card.id)

func _check_grand_equation(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 3
	resolver.resolve_card(card, player, enemy)
	var dealt: int = 100 - enemy.hp
	if dealt != 14:
		_fail("%s 在 3 点意志时应造成 14 伤害，实际 %d。" % [card.id, dealt])
	if player.will != 1:
		_fail("%s 结算后应剩余 1 点意志，实际 %d。" % [card.id, player.will])

func _check_final_vector(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 6
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 28:
		_fail("%s 基础伤害异常。" % card.id)
	if int(enemy.statuses.get("vulnerable", 0)) != 2:
		_fail("%s 在 6 点意志时应施加 2 层易伤。" % card.id)

func _check_overclock_casting(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	var bonus_map: Dictionary = player.meta.get("next_tag_damage_bonus", {})
	if int(bonus_map.get("Arts", 0)) != 6:
		_fail("%s 未正确设置下一张术式增伤。" % card.id)
	if player.overload != 1:
		_fail("%s 应获得 1 层精神负荷。" % card.id)

func _check_clear_intent(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var stub1: TestBattleStub = ctx1["stub"]
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	_seed_draw_pile(stub1.deck, [card])
	resolver1.resolve_card(card, player1, enemy1)
	if stub1.deck.hand.size() != 1 or player1.will != 0:
		_fail("%s 在无满足条件时应只抽 1 张牌。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var stub2: TestBattleStub = ctx2["stub"]
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	var arts_bolt: CardData = _load_test_card_db()["arts_bolt"]
	stub2.deck.hand.clear()
	stub2.deck.hand.append(arts_bolt)
	stub2.deck.hand.append(arts_bolt)
	_seed_draw_pile(stub2.deck, [card, card])
	resolver2.resolve_card(card, player2, enemy2)
	if stub2.deck.hand.size() != 4:
		_fail("%s 满足条件时应总共抽 2 张牌。" % card.id)
	if player2.will != 2:
		_fail("%s 满足条件时应获得 2 点意志。" % card.id)

func _check_phase_tap(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card])
	resolver.resolve_card(card, player, enemy)
	if enemy.resonance != 1:
		_fail("%s 应施加 1 层共振。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 应抽 1 张牌。" % card.id)

func _check_split_tone(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 10:
		_fail("%s 对有共振目标应造成 10 点伤害。" % card.id)

func _check_coordinated_strike(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["played_support_this_turn"] = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 12:
		_fail("%s 在打出过支援时应造成 12 点伤害。" % card.id)

func _check_meta_flag(card: CardData, flag_name: String) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if not bool(player.meta.get(flag_name, false)):
		_fail("%s 未正确设置 %s。" % [card.id, flag_name])

func _check_draw_and_hp_loss(card: CardData, expected_draw: int, hp_loss: int) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card, card, card, card])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != expected_draw:
		_fail("%s 抽牌异常，预期 %d，实际 %d。" % [card.id, expected_draw, stub.deck.hand.size()])
	if player.hp != 72 - hp_loss:
		_fail("%s 自伤异常，预期损失 %d。" % [card.id, hp_loss])

func _check_crisis_surge(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	resolver1.resolve_card(card, player1, enemy1)
	if player1.will != 1:
		_fail("%s 在高血量时应获得 1 点意志。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var stub2: TestBattleStub = ctx2["stub"]
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	player2.hp = 30
	_seed_draw_pile(stub2.deck, [card, card, card])
	resolver2.resolve_card(card, player2, enemy2)
	if player2.will != 2 or player2.energy != 4 or stub2.deck.hand.size() != 2:
		_fail("%s 在低血量时应获得 2 意志、2 抽牌、1 能量。" % card.id)

func _check_arc_collapse(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 5
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 14:
		_fail("%s 基础伤害异常。" % card.id)
	if int(enemy.statuses.get("vulnerable", 0)) != 2:
		_fail("%s 在 5 点意志时应施加 2 层易伤。" % card.id)

func _check_controlled_detonation(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 3
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 15:
		_fail("%s 在 3 点意志时应造成 15 点伤害。" % card.id)
	if player.will != 0:
		_fail("%s 应消耗全部 3 点意志。" % card.id)

func _check_thought_acceleration(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var arts_bolt: CardData = _load_test_card_db()["arts_bolt"]
	resolver.resolve_card(card, player, enemy)
	if player.will != 2:
		_fail("%s 应获得 2 点意志。" % card.id)
	var cost: int = stub.deck.effective_cost(arts_bolt)
	if cost != 0:
		_fail("%s 应让下一张术式牌费用 -1。" % card.id)

func _check_widened_spectrum(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	var stub: TestBattleStub = ctx["stub"]
	stub.enemies.append(enemy2)
	player.will = 4
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 90 or enemy2.hp != 90:
		_fail("%s 在 4 点意志时应对全体造成 10 点伤害。" % card.id)

func _check_chain_reaction(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	var stub: TestBattleStub = ctx["stub"]
	stub.enemies.append(enemy2)
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 92 or enemy2.hp != 100:
		_fail("%s 应只对有共振的敌人造成 8 点术式伤害。" % card.id)

func _check_emergency_order(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var card_db: Dictionary = _load_test_card_db()
	_seed_discard_pile(stub.deck, [card_db["field_command"]])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.is_empty() or stub.deck.hand[0].id != "field_command":
		_fail("%s 没有从弃牌堆取回支援牌。" % card.id)
	var cost: int = stub.deck.effective_cost(card_db["field_command"])
	if cost != 0:
		_fail("%s 未正确降低下一张支援牌费用。" % card.id)

func _check_dobermann_drill_order(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["cards_played_this_turn"] = 2
	_seed_draw_pile(stub.deck, [card])
	resolver.resolve_card(card, player, enemy)
	if not bool(player.meta.get("dobermann_drill_ready", false)):
		_fail("%s 未正确准备下一张攻击/术式增伤。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 满足条件时应额外抽 1 张牌。" % card.id)

func _check_exusiai_cover_fire(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 9:
		_fail("%s 对有共振目标应总共造成 9 点伤害。" % card.id)

func _check_precise_break(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.block = 10
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 97 or enemy.block != 5:
		_fail("%s 应无视 50%% 护盾并造成 3 点掉血，剩余 5 点护盾。" % card.id)

func _check_resonance_field(card: CardData, marker: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	var stub: TestBattleStub = ctx["stub"]
	stub.enemies.append(enemy2)
	resolver.resolve_card(card, player, enemy)
	resolver.resolve_card(marker, player, enemy)
	if enemy.resonance != 3 or enemy2.resonance != 1:
		_fail("%s 未正确将共振扩散给另一名敌人。" % card.id)

func _check_prism_shatter(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	var stub: TestBattleStub = ctx["stub"]
	stub.enemies.append(enemy2)
	enemy.resonance = 2
	enemy2.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 94 or enemy2.hp != 94 or enemy.resonance != 1 or enemy2.resonance != 0:
		_fail("%s 应对所有有共振的敌人造成 6 点伤害并各消耗 1 层共振。" % card.id)

func _check_medical_evac_route(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.hp = 40
	player.apply_status("weak", 1)
	player.meta["played_support_this_turn"] = 2
	resolver.resolve_card(card, player, enemy)
	if player.hp != 48:
		_fail("%s 应回复 8 点生命。" % card.id)
	if int(player.statuses.get("weak", 0)) != 0:
		_fail("%s 满足条件时应净化全部负面状态。" % card.id)

func _check_tactical_encirclement(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.meta["played_support_this_turn"] = 2
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 20:
		_fail("%s 在本回合打出 2 张支援时应造成 20 点伤害。" % card.id)

func _check_nerve_burn(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 8:
		_fail("%s 应造成 8 点术式伤害。" % card.id)
	if stub.deck.hand.is_empty() or stub.deck.hand[0].id != "overloaded_nerves":
		_fail("%s 应向手牌加入 1 张过载神经。" % card.id)

func _check_zero_range_cast(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	resolver1.resolve_card(card, player1, enemy1)
	if 100 - enemy1.hp != 14:
		_fail("%s 基础伤害应为 14。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	enemy2.meta["took_support_damage_this_turn"] = true
	resolver2.resolve_card(card, player2, enemy2)
	if 100 - enemy2.hp != 20:
		_fail("%s 在目标受过支援伤害时应造成 20 点伤害。" % card.id)

func _check_singing_fracture(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	enemy.resonance = 1
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 21:
		_fail("%s 对有共振目标应总共造成 21 点伤害。" % card.id)

func _check_chimera_protocol(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.will = 3
	enemy.resonance = 2
	resolver.resolve_card(card, player, enemy)
	if 100 - enemy.hp != 23:
		_fail("%s 在 3 点意志和 2 层共振时应造成 23 点伤害。" % card.id)
	if player.will != 0 or enemy.resonance != 0:
		_fail("%s 应消耗全部意志与目标共振。" % card.id)

func _check_the_cost_of_mercy(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	player.hp = 40
	resolver.resolve_card(card, player, enemy)
	if player.hp != 52:
		_fail("%s 应回复至 52 点生命。" % card.id)
	if player.will != 2 or player.overload != 2:
		_fail("%s 应获得 2 点意志和 2 层精神负荷。" % card.id)

func _check_resonance_harvest(card: CardData, arts_card: CardData, support_card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	stub.enemies.append(enemy2)
	enemy.resonance = 1
	enemy2.resonance = 1
	_seed_draw_pile(stub.deck, [arts_card, support_card])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != 2:
		_fail("%s 有两名共振敌人时应抽 2 张牌。" % card.id)
	var discounted_arts_found: bool = false
	for drawn_card in stub.deck.hand:
		if drawn_card.id == arts_card.id and drawn_card.cost == 0:
			discounted_arts_found = true
			break
	if not discounted_arts_found:
		_fail("%s 抽到术式牌时应让其费用 -1。" % card.id)

func _check_sevenfold_echo(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if player.echo_percent != 50 or int(player.meta.get("echo_charges", 0)) != 2:
		_fail("%s 应给予 2 层 Echo 充能和 50%% Echo。" % card.id)

func _check_unified_battleplan(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if int(player.meta.get("battleplan_support_cost_reduction", 0)) != 1:
		_fail("%s 未正确设置本回合支援牌费用 -1。" % card.id)
	if not bool(player.meta.get("battleplan_first_support_pending", false)):
		_fail("%s 未正确准备第一次支援后的抽牌效果。" % card.id)
	if int(player.meta.get("battleplan_support_draw_bonus", 0)) != 2:
		_fail("%s 抽牌数应为 2。" % card.id)

func _check_controlled_overload(card: CardData, burn_will: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	resolver.resolve_card(burn_will, player, enemy)
	if player.hp != 70:
		_fail("%s 应将过载类牌的自伤 4 点减半为 2 点。" % card.id)

func _check_ashes_remember(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	var enemy2: UnitState = UNIT_STATE_SCRIPT.new()
	enemy2.id = "dummy2"
	enemy2.display_name = "Dummy2"
	enemy2.max_hp = 100
	enemy2.hp = 100
	stub.enemies.append(enemy2)
	player.meta["lost_hp_this_battle"] = 20
	resolver.resolve_card(card, player, enemy)
	if enemy.hp != 90 or enemy2.hp != 90:
		_fail("%s 应把已失去生命的 50%% 转化为对全体 10 点伤害。" % card.id)

func _check_final_directive(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card, card])
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != 2:
		_fail("%s 应抽 2 张牌。" % card.id)
	if not bool(player.meta.get("final_directive_active", false)):
		_fail("%s 未正确开启最终指令状态。" % card.id)

func _check_landship_wide_order(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	resolver.resolve_card(card, player, enemy)
	if stub.deck.hand.size() != 2:
		_fail("%s 应向手牌加入 2 张支援牌。" % card.id)
	for generated_card in stub.deck.hand:
		if "Support" not in generated_card.tags or generated_card.cost != 0:
			_fail("%s 生成的支援牌应为 0 费支援牌。" % card.id)

func _check_ember_judgement(card: CardData) -> void:
	var ctx1: Dictionary = _new_stub()
	var resolver1: EffectResolver = ctx1["resolver"]
	var player1: UnitState = ctx1["player"]
	var enemy1: UnitState = ctx1["enemy"]
	resolver1.resolve_card(card, player1, enemy1)
	if 100 - enemy1.hp != 18:
		_fail("%s 未满足条件时应造成 18 点伤害。" % card.id)
	var ctx2: Dictionary = _new_stub()
	var resolver2: EffectResolver = ctx2["resolver"]
	var player2: UnitState = ctx2["player"]
	var enemy2: UnitState = ctx2["enemy"]
	player2.will = 5
	resolver2.resolve_card(card, player2, enemy2)
	if 100 - enemy2.hp != 36:
		_fail("%s 在意志达到 5 时应造成 36 点伤害。" % card.id)

func _check_unstable_resonance(card: CardData) -> void:
	var ctx: Dictionary = _new_stub()
	var stub: TestBattleStub = ctx["stub"]
	var resolver: EffectResolver = ctx["resolver"]
	var player: UnitState = ctx["player"]
	var enemy: UnitState = ctx["enemy"]
	_seed_draw_pile(stub.deck, [card])
	resolver.resolve_card(card, player, enemy)
	if player.resonance != 2:
		_fail("%s 应给自己施加 2 层共振。" % card.id)
	if stub.deck.hand.size() != 1:
		_fail("%s 应抽 1 张牌。" % card.id)

func _fail(message: String) -> void:
	failures.append(message)

func _flush_teardown() -> void:
	failures.clear()
	test_run_manager = StubRunManager.new()
	test_card_db.clear()
	test_enemy_db.clear()
	test_character = null
	Util.clear_runtime_caches()
	for manager in test_managers:
		if manager != null and is_instance_valid(manager):
			manager.dispose_runtime_state()
			manager.free()
	test_managers.clear()
	await process_frame
	await process_frame

func _seed_draw_pile(deck: DeckController, cards: Array) -> void:
	deck.draw_pile.clear()
	for card in cards:
		deck.draw_pile.append(card)

func _seed_discard_pile(deck: DeckController, cards: Array) -> void:
	deck.discard_pile.clear()
	for card in cards:
		deck.discard_pile.append(card)
