class_name Util
extends Object

static var _card_art_cache: Dictionary = {}
static var _resource_db_cache: Dictionary = {}
static var _common_status_card_ids: Dictionary = {}
static var _common_status_card_ids_loaded: bool = false

static func clear_runtime_caches() -> void:
	_card_art_cache.clear()
	_resource_db_cache.clear()
	_common_status_card_ids.clear()
	_common_status_card_ids_loaded = false

static func _run_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("RunManager") if tree != null else null

static func _load_resource_dir(path: String, cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	var db: Dictionary = {}
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return db
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")):
			var resource_file_name: String = file_name.trim_suffix(".remap")
			var full_path: String = path.path_join(resource_file_name)
			var res: Resource = ResourceLoader.load(full_path, "", cache_mode)
			if res:
				var res_id: String = String(res.get("id"))
				if not res_id.is_empty():
					db[res_id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	return db

static func _cached_load_resource_dir(path: String, cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	if cache_mode != ResourceLoader.CACHE_MODE_REUSE:
		return _load_resource_dir(path, cache_mode)
	if not _resource_db_cache.has(path):
		_resource_db_cache[path] = _load_resource_dir(path, cache_mode)
	var cached: Dictionary = _resource_db_cache.get(path, {})
	return cached.duplicate()

static func load_card_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/cards", cache_mode)

static func load_card_by_id(card_id: String, cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> CardData:
	var normalized_id: String = String(card_id)
	if normalized_id.is_empty():
		return null
	var path: String = "res://data/cards/%s.tres" % normalized_id
	var card: Resource = ResourceLoader.load(path, "", cache_mode)
	return card as CardData

static func load_module_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/modules", cache_mode)

static func load_charm_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/charms", cache_mode)

static func load_event_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/events", cache_mode)

static func load_enemy_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/enemies", cache_mode)

static func load_character_db(cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> Dictionary:
	return _cached_load_resource_dir("res://data/characters", cache_mode)

static func load_character(character_id: String = "amiya", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> CharacterData:
	var db: Dictionary = load_character_db(cache_mode)
	var character: CharacterData = db.get(character_id, null) as CharacterData
	if character != null:
		return character
	var path: String = "res://data/characters/%s.tres" % String(character_id)
	return ResourceLoader.load(path, "", cache_mode) as CharacterData

static func default_starter_deck_for_character(character_id: String) -> Array[String]:
	match String(character_id):
		"amiya":
			return [
				"arts_bolt",
				"arts_bolt",
				"guard_pulse",
				"guard_pulse",
				"mental_tuning",
				"field_command",
				"resonance_mark",
				"focused_ray",
				"tactical_briefing",
				"stabilize_line"
			]
		"exusiai":
			return [
				"ex_b01_burst_shot",
				"ex_b01_burst_shot",
				"ex_b02_cover_step",
				"ex_b02_cover_step",
				"ex_b03_quick_reload",
				"ex_b04_target_ping",
				"ex_b05_crossfire_ping",
				"ex_b06_burst_entry",
				"ex_b07_mag_swap",
				"ex_b08_angled_volley"
			]
		"kaltsit":
			return [
				"kaltsit_b01_surgical_strike",
				"kaltsit_b01_surgical_strike",
				"kaltsit_b02_tactical_guard",
				"kaltsit_b02_tactical_guard",
				"kaltsit_b03_field_treatment",
				"kaltsit_b04_structure_repair",
				"kaltsit_b04_structure_repair",
				"kaltsit_b05_mon3tr_command",
				"kaltsit_b05_mon3tr_command",
				"kaltsit_b07_clinical_scheduling"
			]
		"nearl":
			return [
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
	return []

static func module_icon_path(module_id: String) -> String:
	var direct_path: String = "res://assets/module_icons/%s.svg" % module_id
	if ResourceLoader.exists(direct_path):
		return direct_path
	return ""

static func _load_first_texture(paths: Array[String]) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

static func load_character_portrait(character_id: String) -> Texture2D:
	var portrait: Texture2D = _load_first_texture([
		"res://assets/character_portraits/%s.png" % character_id,
		"res://assets/character_portraits/%s.jpg" % character_id,
		"res://assets/character_portraits/%s.jpeg" % character_id
	])
	var fallback_path: String = "res://人物选择页面的角色壁纸.png"
	if portrait != null:
		return portrait
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return null

static func load_character_selection_image(character_id: String) -> Texture2D:
	var selection_texture: Texture2D = _load_first_texture([
		"res://assets/character_select/%s.png" % character_id,
		"res://assets/character_select/%s.jpg" % character_id,
		"res://assets/character_select/%s.jpeg" % character_id,
		"res://assets/backgrounds/%s_character_select_wallpaper.png" % character_id,
		"res://assets/backgrounds/%s_character_select_wallpaper.jpg" % character_id,
		"res://assets/backgrounds/%s_character_select_wallpaper.jpeg" % character_id
	])
	if selection_texture != null:
		return selection_texture
	return load_character_portrait(character_id)

static func card_art_path(card_id: String) -> String:
	var direct_path: String = "res://assets/card_art/%s.png" % card_id
	var fallback_path: String = "res://assets/card_art/default_card.png"
	if ResourceLoader.exists(direct_path):
		return direct_path
	if card_id.ends_with("_plus"):
		var base_card_id: String = card_id.trim_suffix("_plus")
		var base_path: String = "res://assets/card_art/%s.png" % base_card_id
		if ResourceLoader.exists(base_path):
			return base_path
	if ResourceLoader.exists(fallback_path):
		return fallback_path
	return ""

static func load_card_art(card_id: String) -> Texture2D:
	if _card_art_cache.has(card_id):
		return _card_art_cache[card_id] as Texture2D

	var resolved_path: String = card_art_path(card_id)
	var texture: Texture2D = null

	if not resolved_path.is_empty():
		texture = load(resolved_path) as Texture2D

	if texture != null:
		_card_art_cache[card_id] = texture

	return texture

static func card_owner(card_id: String) -> String:
	if _is_common_status_card(card_id):
		return "common"
	if card_id.begins_with("ex_") or card_id == "exusiai_cover_fire":
		return "exusiai"
	if card_id.begins_with("nearl_"):
		return "nearl"
	if card_id.begins_with("kaltsit_"):
		return "kaltsit"
	return "amiya"

static func _is_common_status_card(card_id: String) -> bool:
	if not _common_status_card_ids_loaded:
		_common_status_card_ids.clear()
		var db: Dictionary = load_card_db()
		for card_id_variant in db.keys():
			var card: CardData = db[card_id_variant] as CardData
			if card != null and card.rarity in ["Curse", "Status"]:
				_common_status_card_ids[card.id] = true
		_common_status_card_ids_loaded = true
	return bool(_common_status_card_ids.get(card_id, false))

static func card_archetype(card_id: String) -> String:
	if card_owner(card_id) == "nearl":
		var nearl_card: CardData = load_card_db().get(card_id, null) as CardData
		if nearl_card == null:
			return "neutral"
		if nearl_card.tags.has("Counter"):
			return "counter_guard"
		if nearl_card.tags.has("Radiance"):
			return "radiance_growth"
		if nearl_card.tags.has("Shield") or nearl_card.tags.has("Barrier"):
			return "shield_wall"
		return "neutral"
	if card_owner(card_id) == "exusiai":
		var exusiai_card: CardData = load_card_db().get(card_id, null) as CardData
		if exusiai_card == null:
			return "neutral"
		var exusiai_tags: PackedStringArray = exusiai_card.tags
		if exusiai_tags.has("Support"):
			return "support_mobility"
		if exusiai_tags.has("Mark") and (exusiai_tags.has("Finisher") or exusiai_tags.has("Shot")):
			return "mark_execution"
		if exusiai_tags.has("Burst"):
			return "burst_storm"
		if exusiai_tags.has("AmmoUse") or exusiai_tags.has("AmmoGain") or exusiai_tags.has("Reload"):
			return "ammo_tempo"
		if exusiai_tags.has("Tempo"):
			return "support_mobility"
		return "neutral"
	var overrides := {
		"echo_conduit": "will_burst",
		"focused_ray": "will_burst",
		"final_vector": "will_burst",
		"grand_equation": "will_burst",
		"ember_judgement": "will_burst",
		"field_command": "command_support",
		"tactical_briefing": "command_support",
		"rhodes_formation": "command_support",
		"command_overflow": "command_support",
		"voice_of_the_leader": "command_support",
		"resonance_mark": "resonance_combo",
		"echo_lattice": "resonance_combo",
		"chain_reaction": "resonance_combo",
		"absolute_resonance": "resonance_combo",
		"bloodline_casting": "overload_sacrifice",
		"desperate_focus": "overload_sacrifice",
		"controlled_overload": "overload_sacrifice",
		"black_ring_method": "overload_sacrifice",
		"ashes_to_ashes": "overload_sacrifice"
	}
	if overrides.has(card_id):
		return String(overrides[card_id])
	var card: CardData = load_card_db().get(card_id, null) as CardData
	if card == null:
		return "neutral"
	var tags: PackedStringArray = card.tags
	if tags.has("Overload"):
		return "overload_sacrifice"
	if tags.has("Support") or tags.has("Command") or tags.has("Tactic"):
		return "command_support"
	if tags.has("Resonance") or tags.has("Echo") or tags.has("Channel"):
		return "resonance_combo"
	if tags.has("Will") or tags.has("WillGain") or tags.has("WillSpend"):
		return "will_burst"
	return "neutral"

static func get_card_reward_pool(character_id: String = "amiya") -> Array[String]:
	var db: Dictionary = load_card_db()
	var result: Array[String] = []
	for card_id_variant in db.keys():
		var card: CardData = db[card_id_variant] as CardData
		if not is_card_reward_eligible(card, character_id):
			continue
		result.append(card.id)
	result.sort()
	return result

static func is_card_reward_eligible(card: CardData, character_id: String = "amiya") -> bool:
	# 设计说明：此处不检查 MetaUnlockManager.is_card_seen()。
	# 杀戮尖塔风格：奖励池包含所有合格卡牌（无论是否见过），
	# 玩家在奖励中首次遇到未见卡牌时，RunManager.add_card() 会调用
	# MetaUnlockManager.record_card_seen() 记录发现并入队解锁通知。
	# 图鉴门控只影响展示，不影响奖励池——这是"卡池渐进解锁"的核心。
	if card == null:
		return false
	if card.id.is_empty() or card.id.ends_with("_plus"):
		return false
	if card.rarity in ["Curse", "Status", "Basic", "Starter"]:
		return false
	if default_starter_deck_for_character(character_id).has(card.id):
		return false
	return is_card_available_to_character(card.id, character_id)

static func card_rarity_tier(card_or_rarity: Variant) -> String:
	var rarity: String = ""
	if card_or_rarity is CardData:
		rarity = (card_or_rarity as CardData).rarity
	else:
		rarity = String(card_or_rarity)
	match rarity:
		"Common":
			return "common"
		"Uncommon", "Elite":
			return "elite"
		"Rare", "Legendary":
			return "rare"
		"Basic", "Starter":
			return "starter"
		"Curse", "Status":
			return "status"
	return "common"

static func is_card_available_to_character(card_id: String, character_id: String) -> bool:
	if card_id.is_empty():
		return false
	var owner: String = card_owner(card_id)
	return owner == character_id or owner == "common"

static func get_character_card_pool_by_tags(character_id: String = "amiya", tags_any: Array = [], include_status: bool = false, include_upgrades: bool = false) -> Array[String]:
	var db: Dictionary = load_card_db()
	var result: Array[String] = []
	for card_id_variant in db.keys():
		var card: CardData = db[card_id_variant] as CardData
		if card == null or card.id.is_empty():
			continue
		if not include_upgrades and card.id.ends_with("_plus"):
			continue
		if not include_status and card.rarity in ["Curse", "Status", "Basic", "Starter"]:
			continue
		if not include_status and default_starter_deck_for_character(character_id).has(card.id):
			continue
		if not is_card_available_to_character(card.id, character_id):
			continue
		var matches_tag: bool = tags_any.is_empty()
		for tag_variant in tags_any:
			if String(tag_variant) in card.tags:
				matches_tag = true
				break
		if not matches_tag:
			continue
		result.append(card.id)
	result.sort()
	return result

static func normalize_character_card_choices(card_ids: Array, character_id: String, count_hint: int = -1, seed_value: int = 1, archetype_weights: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	var target_count: int = count_hint if count_hint >= 0 else card_ids.size()
	for card_id_variant in card_ids:
		var card_id: String = String(card_id_variant)
		if result.has(card_id):
			continue
		var card: CardData = load_card_db().get(card_id, null) as CardData
		if is_card_reward_eligible(card, character_id):
			result.append(card_id)
	if result.size() >= target_count:
		return result.slice(0, target_count)
	var pool: Array[String] = get_card_reward_pool(character_id)
	for existing_id in result:
		pool.erase(existing_id)
	if pool.is_empty():
		return result
	var replacements: Array[String] = _deterministic_weighted_card_choices(pool, max(0, target_count - result.size()), seed_value, archetype_weights)
	for replacement_id in replacements:
		if not result.has(replacement_id):
			result.append(replacement_id)
	return result

static func _deterministic_weighted_card_choices(pool: Array[String], count: int, seed_value: int, archetype_weights: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var available: Array[String] = pool.duplicate()
	var result: Array[String] = []
	while result.size() < count and not available.is_empty():
		var total_weight: float = 0.0
		var weights: Array[float] = []
		for card_id in available:
			var weight: float = 1.0
			if not archetype_weights.is_empty():
				var archetype: String = card_archetype(card_id)
				weight = max(0.05, float(archetype_weights.get(archetype, 1.0)))
			weights.append(weight)
			total_weight += weight
		var roll: float = rng.randf() * total_weight
		var picked_index: int = available.size() - 1
		for index in range(available.size()):
			roll -= weights[index]
			if roll <= 0.0:
				picked_index = index
				break
		result.append(available[picked_index])
		available.remove_at(picked_index)
	return result

static func get_normal_battle_reward_pool(character_id: String = "amiya") -> Array[String]:
	return _reward_card_pool_by_rarity(["Common"], character_id)

static func get_common_card_reward_pool(character_id: String = "amiya") -> Array[String]:
	return _reward_card_pool_by_rarity(["Common"], character_id)

static func get_uncommon_card_reward_pool(character_id: String = "amiya") -> Array[String]:
	return _reward_card_pool_by_tier("elite", character_id)

static func get_rare_card_reward_pool(character_id: String = "amiya") -> Array[String]:
	return _reward_card_pool_by_tier("rare", character_id)

static func get_elite_card_reward_pool(character_id: String = "amiya") -> Array[String]:
	return get_uncommon_card_reward_pool(character_id)

static func _reward_card_pool_by_tier(tier: String, character_id: String = "amiya") -> Array[String]:
	var db: Dictionary = load_card_db()
	var result: Array[String] = []
	for card_id_variant in db.keys():
		var card: CardData = db[card_id_variant] as CardData
		if not is_card_reward_eligible(card, character_id):
			continue
		if card_rarity_tier(card) != tier:
			continue
		result.append(card.id)
	result.sort()
	return result

static func _reward_card_pool_by_rarity(allowed_rarities: Array[String], character_id: String = "amiya") -> Array[String]:
	var db: Dictionary = load_card_db()
	var result: Array[String] = []
	for card_id_variant in db.keys():
		var card: CardData = db[card_id_variant] as CardData
		if not is_card_reward_eligible(card, character_id):
			continue
		if not allowed_rarities.has(card.rarity):
			continue
		result.append(card.id)
	result.sort()
	return result

static func get_module_reward_pool(character_id: String = "amiya") -> Array[String]:
	if character_id == "exusiai":
		return [
			"ex_m01_racing_magazine",
			"ex_m02_light_stock",
			"ex_m03_fast_feeder",
			"ex_m04_target_scope",
			"ex_m05_penguin_invoice",
			"ex_m06_muzzle_suppressor",
			"ex_m07_spare_pouch",
			"ex_m08_highspeed_loader",
			"ex_m09_cluster_calibrator",
			"ex_m10_tempo_pedal",
			"ex_m11_storm_permit",
			"ex_m12_chainfire_recorder",
			"ex_m13_airdrop_beacon",
			"ex_m14_hunter_clearance",
			"ex_m15_gunfire_halo",
			"ex_m16_heaven_circuit"
		]
	if character_id == "nearl":
		return [
			"nearl_m01_first_guard",
			"nearl_m02_counter_edge",
			"nearl_m03_opening_barrier",
			"nearl_m04_dawn_oath",
			"nearl_m05_first_counter_block",
			"nearl_m06_low_hp_counter",
			"nearl_m07_shield_draft",
			"nearl_m08_counter_draft",
			"nearl_m09_first_radiance_draw",
			"nearl_m10_broken_shield_counter",
			"nearl_m11_boss_bulwark",
			"nearl_m12_upgraded_counter",
			"nearl_m13_counter_heal",
			"nearl_m14_high_radiance_guard",
			"nearl_m15_full_radiance_counter",
			"nearl_m16_first_counter_guard"
		]
	if character_id == "kaltsit":
		return [
			"kaltsits_log"
		]
	return [
		"recorder_of_resolve",
		"signal_booster",
		"originium_fragment",
		"field_stabilizer",
		"field_medic_pack",
		"echo_pin",
		"reserve_battery",
		"dobermann_manual",
		"resonance_prism",
		"rhodes_tactical_console",
		"field_command_badge",
		"worn_terminal",
		"support_grid",
		"pain_converter",
		"resonance_anchor",
		"ashen_thread",
		"crown_of_responsibility",
		"ashen_halo"
	]

static func module_owner(module_id: String) -> String:
	if module_id.begins_with("ex_"):
		return "exusiai"
	if module_id.begins_with("kaltsit_") or module_id == "kaltsits_log":
		return "kaltsit"
	if module_id.begins_with("nearl_"):
		return "nearl"
	return "amiya"

static func is_module_available_to_character(module_id: String, character_id: String) -> bool:
	if module_id.is_empty():
		return false
	return module_owner(module_id) == character_id

static func normalize_character_module_choices(module_ids: Array, character_id: String, count_hint: int = -1, seed_value: int = 1) -> Array[String]:
	var result: Array[String] = []
	var target_count: int = count_hint if count_hint >= 0 else module_ids.size()
	for module_id_variant in module_ids:
		var module_id: String = String(module_id_variant)
		if result.has(module_id):
			continue
		if is_module_available_to_character(module_id, character_id):
			result.append(module_id)
	if result.size() >= target_count:
		return result.slice(0, target_count)
	var pool: Array[String] = get_module_reward_pool(character_id)
	for existing_id in result:
		pool.erase(existing_id)
	if pool.is_empty():
		return result
	var replacements: Array[String] = _deterministic_choices(pool, max(0, target_count - result.size()), seed_value)
	for replacement_id in replacements:
		if not result.has(replacement_id):
			result.append(replacement_id)
	return result

static func get_charm_reward_pool(character_id: String = "amiya") -> Array[String]:
	if character_id == "exusiai":
		return [
			"ex_h01_applepie_badge",
			"ex_h02_fast_sling",
			"ex_h03_red_dot_pendant",
			"ex_h04_delivery_badge",
			"ex_h05_spare_mag",
			"ex_h06_gunfire_cross",
			"ex_h07_express_terminal",
			"ex_h08_angel_shard"
		]
	if character_id == "nearl":
		return [
			"nearl_h01_kazimierz_badge",
			"nearl_h02_oath_pin",
			"nearl_h03_guard_lantern",
			"nearl_h04_counter_spur",
			"nearl_h05_radiant_shard",
			"nearl_h06_last_line",
			"nearl_h07_warm_glow",
			"nearl_h08_knight_seal"
		]
	if character_id == "kaltsit":
		return [
			"kaltsit_h01_clinical_tag",
			"kaltsit_h02_mon3tr_core",
			"kaltsit_h03_field_suture",
			"kaltsit_h04_diagnostic_chip"
		]
	return [
		"rabbit_emblem",
		"rhodes_pin",
		"broken_horn_token",
		"silent_bell",
		"sterile_strap",
		"burnt_paper_charm",
		"operators_thread",
		"embershard"
	]

static func charm_owner(charm_id: String) -> String:
	if charm_id.begins_with("ex_"):
		return "exusiai"
	if charm_id.begins_with("kaltsit_"):
		return "kaltsit"
	if charm_id.begins_with("nearl_"):
		return "nearl"
	return "amiya"

static func is_charm_available_to_character(charm_id: String, character_id: String) -> bool:
	if charm_id.is_empty():
		return false
	return charm_owner(charm_id) == character_id

static func normalize_character_charm_choices(charm_ids: Array, character_id: String, count_hint: int = -1, seed_value: int = 1) -> Array[String]:
	var result: Array[String] = []
	var target_count: int = count_hint if count_hint >= 0 else charm_ids.size()
	for charm_id_variant in charm_ids:
		var charm_id: String = String(charm_id_variant)
		if result.has(charm_id):
			continue
		if is_charm_available_to_character(charm_id, character_id):
			result.append(charm_id)
	if result.size() >= target_count:
		return result.slice(0, target_count)
	var pool: Array[String] = get_charm_reward_pool(character_id)
	for existing_id in result:
		pool.erase(existing_id)
	if pool.is_empty():
		return result
	var replacements: Array[String] = _deterministic_choices(pool, max(0, target_count - result.size()), seed_value)
	for replacement_id in replacements:
		if not result.has(replacement_id):
			result.append(replacement_id)
	return result

static func _deterministic_choices(pool: Array[String], count: int, seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var available: Array[String] = pool.duplicate()
	var result: Array[String] = []
	while result.size() < count and not available.is_empty():
		var picked_index: int = rng.randi_range(0, available.size() - 1)
		result.append(available[picked_index])
		available.remove_at(picked_index)
	return result

@warning_ignore("unused_parameter")
static func generate_node_metadata(floor_index: int, node_type: String, index: int, rng: RandomNumberGenerator = null, battle_generation_state: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {}
	var randomizer: RandomNumberGenerator = rng
	if randomizer == null:
		randomizer = RandomNumberGenerator.new()
		randomizer.randomize()
	match node_type:
		"battle":
			var template: Dictionary = pick_battle_template(floor_index, randomizer, battle_generation_state)
			data["enemy_ids"] = template.get("enemy_ids", [])
			data["encounter_tests"] = template.get("tests", [])
			data["encounter_primary_test"] = String(template.get("primary_test", ""))
		"elite":
			data["enemy_ids"] = get_random_elite_enemies(floor_index, randomizer)
		"boss":
			data["enemy_ids"] = get_boss_enemies(floor_index, randomizer)
			data["boss_brief"] = boss_briefing_for_enemies(data["enemy_ids"], floor_index)
		"event", "story":
			var general_events: Array[String] = [
				"temporary_ward", "dobermann_inspection", "nearl_principle", "kaltsit_briefing", "ws_broadcast",
				"tactical_debrief", "medical_supply_crate", "originium_fissure", "withdrawal_dispute",
				"old_operation_record", "operator_assembly", "mental_fluctuation", "broken_comms",
				"overloaded_supply", "kaltsit_silent_assessment", "originium_echo_corridor",
				"emergency_command_chain", "nameless_operator_letter", "midnight_maintenance",
				"footprints_on_ashes", "doctor_question",
				"burden_resonance", "evacuation_aftermath", "intelligence_convergence",
				"originium_aftershock", "doctor_reflection",
				"ruined_supply_convoy", "wandering_merchant", "collapsed_shelter",
				"originium_cache", "old_terminal_log"
			]
			var event_pool: Array[String] = []
			for general_event_id in general_events:
				event_pool.append(general_event_id)
			for character_event_id in character_event_ids(_current_run_character_id()):
				if not event_pool.has(character_event_id):
					event_pool.append(character_event_id)
			var event_db: Dictionary = load_event_db()
			var character_id: String = _current_run_character_id()
			var valid_events: Array[String] = []
			for event_id in event_pool:
				var ev: EventData = event_db.get(event_id, null) as EventData
				if ev == null:
					# 未知事件 ID 直接跳过：进入事件场景后数据缺失会软锁整个 run
					continue
				if not _event_available_to_character(ev, character_id):
					continue
				if not ev.conditions.is_empty() and not _event_conditions_met(ev.conditions):
					continue
				valid_events.append(event_id)
			# 本局去重：优先未经历的事件；全部经历过后才允许重复出现
			var seen_ids: Array = _seen_event_ids()
			if not seen_ids.is_empty():
				var fresh_events: Array[String] = []
				for event_id in valid_events:
					if not seen_ids.has(event_id):
						fresh_events.append(event_id)
				if not fresh_events.is_empty():
					valid_events = fresh_events
			if valid_events.is_empty():
				# 兜底：仅使用通过角色过滤的通用事件，绝不回退到含其他角色专属事件的未过滤列表
				for event_id in general_events:
					var fallback_ev: EventData = event_db.get(event_id, null) as EventData
					if fallback_ev != null and _event_available_to_character(fallback_ev, character_id):
						valid_events.append(event_id)
			if valid_events.is_empty():
				valid_events = ["temporary_ward"]
			data["event_id"] = valid_events[randomizer.randi_range(0, valid_events.size() - 1)]
	return data

static func _seen_event_ids() -> Array:
	var run_manager: Node = _run_manager()
	if run_manager != null:
		var seen: Variant = run_manager.get("seen_event_ids")
		if typeof(seen) == TYPE_ARRAY:
			return seen
	return []

static func character_event_ids(character_id: String) -> Array[String]:
	match character_id:
		"exusiai":
			return ["exusiai_delivery_detour", "exusiai_rooftop_cover"]
		"kaltsit":
			return ["kaltsit_field_triage", "kaltsit_mon3tr_diagnostics", "kaltsit_research_note"]
		"nearl":
			return ["nearl_evacuation_line", "nearl_knightly_oath", "nearl_oath_stone"]
	return ["amiya_command_room", "amiya_resonance_triage", "amiya_memory_fragment"]

static func _current_run_character_id() -> String:
	var run_manager: Node = _run_manager()
	if run_manager != null and run_manager.get("character") != null:
		var character: CharacterData = run_manager.get("character") as CharacterData
		if character != null and not character.id.is_empty():
			return character.id
	return "amiya"

static func _event_available_to_character(event_data: EventData, character_id: String) -> bool:
	if event_data == null:
		return false
	for tag in event_data.tags:
		var text: String = String(tag)
		if text.begins_with("character:"):
			return text == "character:%s" % character_id
	return true

static func _event_conditions_met(conditions: PackedStringArray) -> bool:
	var run_manager: Node = _run_manager()
	if run_manager == null:
		return false
	for condition in conditions:
		var cond: String = String(condition).strip_edges()
		if cond.begins_with("any:"):
			var flags: PackedStringArray = cond.substr(4).split(",")
			var any_met: bool = false
			for flag in flags:
				if run_manager.has_flag(flag.strip_edges()):
					any_met = true
					break
			if not any_met:
				return false
		elif cond.begins_with("not:"):
			if run_manager.has_flag(cond.substr(4).strip_edges()):
				return false
		else:
			var flag_name: String = cond.replace("has:", "") if cond.begins_with("has:") else cond
			if not run_manager.has_flag(flag_name.strip_edges()):
				return false
	return true

static func pick_battle_template(floor_index: int, rng: RandomNumberGenerator, state: Dictionary) -> Dictionary:
	var templates: Array = get_battle_templates(floor_index)
	if templates.is_empty():
		return {"enemy_ids": get_random_battle_enemies(floor_index, rng), "tests": PackedStringArray(), "primary_test": ""}
	var targets := {
		"rear_threat": 0.30,
		"aoe": 0.25,
		"armor": 0.20
	}
	var battle_count: int = int(state.get("battle_count", 0))
	var test_counts: Dictionary = state.get("test_counts", {})
	var recent_primary: Array[String] = []
	for entry in state.get("recent_primary_tests", []):
		recent_primary.append(String(entry))
	var weighted_templates: Array[Dictionary] = []
	var total_weight: float = 0.0
	for template in templates:
		var weight: float = float(template.get("weight", 1.0))
		var tests: Array = template.get("tests", [])
		var primary_test: String = String(template.get("primary_test", ""))
		if recent_primary.size() >= 2 and recent_primary[recent_primary.size() - 1] == primary_test and recent_primary[recent_primary.size() - 2] == primary_test:
			weight *= 0.05
		for test_name_variant in tests:
			var test_name: String = String(test_name_variant)
			if targets.has(test_name):
				var current_ratio: float = float(int(test_counts.get(test_name, 0))) / max(1.0, float(max(1, battle_count)))
				if current_ratio < float(targets[test_name]):
					weight *= 1.45
				elif current_ratio > float(targets[test_name]) + 0.10:
					weight *= 0.82
		if floor_index == 1 and tests.has("aoe"):
			weight *= 1.15
		total_weight += weight
		weighted_templates.append({"template": template, "weight": weight})
	var roll: float = rng.randf() * max(total_weight, 0.001)
	var chosen: Dictionary = templates[0]
	for entry in weighted_templates:
		roll -= float(entry.get("weight", 1.0))
		if roll <= 0.0:
			chosen = entry.get("template", chosen)
			break
	state["battle_count"] = battle_count + 1
	for test_name_variant in chosen.get("tests", []):
		var test_name: String = String(test_name_variant)
		test_counts[test_name] = int(test_counts.get(test_name, 0)) + 1
	state["test_counts"] = test_counts
	recent_primary.append(String(chosen.get("primary_test", "")))
	while recent_primary.size() > 2:
		recent_primary.pop_front()
	state["recent_primary_tests"] = recent_primary
	return chosen

static func get_battle_templates(floor_index: int) -> Array:
	var templates := {
		1: [
			{"enemy_ids": ["reunion_scout"], "tests": ["tempo"], "primary_test": "tempo", "weight": 1.2},
			{"enemy_ids": ["reunion_caster"], "tests": ["rear_threat", "point_kill"], "primary_test": "rear_threat", "weight": 1.2},
			{"enemy_ids": ["reunion_bladefighter"], "tests": ["tempo"], "primary_test": "tempo", "weight": 1.2},
			{"enemy_ids": ["molotov_thrower"], "tests": ["rear_threat", "attrition"], "primary_test": "rear_threat", "weight": 1.0},
			{"enemy_ids": ["originium_slug", "originium_slug"], "tests": ["aoe"], "primary_test": "aoe", "weight": 0.9},
			{"enemy_ids": ["slug_broodmother", "originium_slug"], "tests": ["aoe", "point_kill"], "primary_test": "aoe", "weight": 0.85},
			{"enemy_ids": ["reunion_scout", "reunion_caster"], "tests": ["rear_threat"], "primary_test": "rear_threat", "weight": 1.0},
			{"enemy_ids": ["stone_throwing_rioter", "originium_slug_alpha"], "tests": ["armor"], "primary_test": "armor", "weight": 0.9},
			{"enemy_ids": ["originium_slug"], "tests": ["tempo"], "primary_test": "tempo", "weight": 1.0}
		],
		2: [
			{"enemy_ids": ["riot_shieldbearer", "crossbow_sniper"], "tests": ["armor", "rear_threat"], "primary_test": "armor", "weight": 1.1},
			{"enemy_ids": ["reunion_medic", "reunion_caster"], "tests": ["rear_threat", "point_kill"], "primary_test": "rear_threat", "weight": 1.1},
			{"enemy_ids": ["demolition_runner", "reunion_scout"], "tests": ["burst", "point_kill"], "primary_test": "burst", "weight": 0.95},
			{"enemy_ids": ["drone_support_unit", "drone_support_unit", "crossbow_sniper"], "tests": ["aoe", "rear_threat"], "primary_test": "aoe", "weight": 1.15},
			{"enemy_ids": ["acid_originium_slug", "originium_slug_alpha", "originium_slug"], "tests": ["aoe", "armor"], "primary_test": "aoe", "weight": 1.1},
			{"enemy_ids": ["infected_fanatic", "mortar_crossbow_operator"], "tests": ["burst", "rear_threat"], "primary_test": "burst", "weight": 1.0}
		],
		3: [
			{"enemy_ids": ["crossbow_sniper", "reunion_bugler"], "tests": ["rear_threat", "tempo"], "primary_test": "rear_threat", "weight": 1.05},
			{"enemy_ids": ["originium_porter", "originium_pollutant"], "tests": ["attrition", "tempo"], "primary_test": "attrition", "weight": 1.0},
			{"enemy_ids": ["alley_arsonist", "disguised_scout"], "tests": ["tempo", "attrition"], "primary_test": "tempo", "weight": 0.95},
			{"enemy_ids": ["blazing_originium_slug", "originium_slug", "originium_slug_alpha"], "tests": ["aoe", "kill_order"], "primary_test": "aoe", "weight": 1.1},
			{"enemy_ids": ["slug_broodmother", "acid_originium_slug", "originium_slug"], "tests": ["aoe", "point_kill"], "primary_test": "aoe", "weight": 1.12},
			{"enemy_ids": ["riot_shieldbearer", "frostbite_stalker"], "tests": ["armor", "tempo"], "primary_test": "armor", "weight": 1.0}
		],
		4: [
			{"enemy_ids": ["originium_channeler", "originium_pollutant"], "tests": ["tempo", "rear_threat"], "primary_test": "tempo", "weight": 1.0},
			{"enemy_ids": ["blazing_originium_slug", "slug_broodmother", "originium_slug"], "tests": ["aoe", "kill_order"], "primary_test": "aoe", "weight": 1.15},
			{"enemy_ids": ["riot_shieldbearer", "crossbow_sniper"], "tests": ["armor", "rear_threat"], "primary_test": "armor", "weight": 1.05}
		]
	}
	return templates.get(floor_index, templates[1])

static func get_random_battle_enemies(floor_index: int, rng: RandomNumberGenerator) -> Array[String]:
	var pools := {
		1: [
			["reunion_scout"],
			["reunion_caster"],
			["reunion_bladefighter"],
			["stone_throwing_rioter"],
			["molotov_thrower"],
			["originium_slug"],
			["originium_slug_alpha"]
		],
		2: [
			["riot_shieldbearer"],
			["crossbow_sniper"],
			["reunion_caster"],
			["demolition_runner"],
			["reunion_medic"],
			["mortar_crossbow_operator"],
			["infected_fanatic"],
			["drone_support_unit"],
			["acid_originium_slug"]
		],
		3: [
			["crossbow_sniper"],
			["riot_shieldbearer"],
			["originium_porter"],
			["alley_arsonist"],
			["disguised_scout"],
			["reunion_bugler"],
			["frostbite_stalker"],
			["originium_pollutant"],
			["blazing_originium_slug"],
			["slug_broodmother"]
		],
		4: [
			["riot_shieldbearer"],
			["crossbow_sniper"],
			["originium_channeler"],
			["originium_pollutant"],
			["blazing_originium_slug"],
			["slug_broodmother"]
		]
	}
	var options: Array = pools.get(floor_index, pools[1])
	var selected: Array = options[rng.randi_range(0, options.size() - 1)]
	var result: Array[String] = []
	for enemy_id in selected:
		result.append(String(enemy_id))
	return result

static func get_random_elite_enemies(floor_index: int, rng: RandomNumberGenerator) -> Array[String]:
	var pools := {
		1: [["field_captain"], ["barricade_heavy_leader"], ["execution_demolitionist"]],
		2: [["field_captain"], ["originium_channeler"], ["hunter_sniper_officer"], ["formation_caster"], ["slug_hive_colossus"]],
		3: [["originium_channeler"], ["field_captain"], ["frenzied_smasher"], ["snowfield_ambush_captain"], ["formation_caster"]],
		4: [["originium_channeler"], ["slug_hive_colossus"], ["frenzied_smasher"]]
	}
	var options: Array = pools.get(floor_index, pools[1])
	var selected: Array = options[rng.randi_range(0, options.size() - 1)]
	var result: Array[String] = []
	for enemy_id in selected:
		result.append(String(enemy_id))
	return result

static func get_boss_enemies(floor_index: int, rng: RandomNumberGenerator = null) -> Array[String]:
	var randomizer: RandomNumberGenerator = rng
	if randomizer == null:
		randomizer = RandomNumberGenerator.new()
		randomizer.randomize()
	var result: Array[String] = []
	if floor_index == 1:
		var floor_one_options: Array[String] = ["scout_chief", "reunion_assault_commander"]
		result.append(floor_one_options[randomizer.randi_range(0, floor_one_options.size() - 1)])
		return result
	if floor_index == 2:
		var floor_two_options: Array[String] = ["lockdown_core", "chernobog_suppression_convoy", "originium_aberration_cluster"]
		result.append(floor_two_options[randomizer.randi_range(0, floor_two_options.size() - 1)])
		return result
	if floor_index == 3:
		result.append("w_boss")
		return result
	result.append("ash_echo")
	return result

static func boss_briefing_for_enemies(enemy_ids: Array, _floor_index: int = 1) -> String:
	var enemy_id: String = String(enemy_ids[0]) if not enemy_ids.is_empty() else ""
	match enemy_id:
		"scout_chief":
			return "侦察首领会用低消耗攻击和节奏压迫试探防线，第一层遇到它时更看重稳定护盾与及时清场。"
		"reunion_assault_commander":
			return "突击指挥官会带来更直接的伤害压力，适合提前留爆发牌，避免被连续进攻压低血线。"
		"lockdown_core":
			return "封锁核心擅长拖长战斗并制造防线压力，越晚处理越容易被它滚起护盾与干扰。"
		"chernobog_suppression_convoy":
			return "切尔诺伯格镇压车组会用连续高伤攻击碾压场面，进入前尽量准备护盾、反击或快速击破手段。"
		"originium_aberration_cluster":
			return "源石畸变集群依靠污染与高生命值消耗玩家，拖回合时要留意持续损耗。"
		"w_boss":
			return "W 是第三层终局首领，会混合爆破、延迟压力和高伤行动。不要把关键防御全交在同一回合。"
		"ash_echo":
			return "灰烬回响是隐藏终局首领，强度按最终战处理。它会像 W 一样施压，并惩罚准备不足的构筑。"
	return "本层首领会显著高于普通遭遇。进入前尽量确认血量、卡组厚度和关键防御。"
