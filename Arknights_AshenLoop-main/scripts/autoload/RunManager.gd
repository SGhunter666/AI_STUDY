extends Node

const TUNE_LIBRARY = preload("res://scripts/core/tune_library.gd")

signal run_started
signal run_updated
signal floor_changed(floor_index: int)
signal gold_changed(amount: int)
signal hp_changed(current: int, max_value: int)
signal modules_changed
signal charms_changed
signal deck_changed
signal map_changed

var exit_flush_done: bool = false
var character: CharacterData
var current_floor: int = 0
var current_node_id: String = ""
var gold: int = 99
# 本局累计获得的金币（含已花掉的部分，用于"累计带回金币"统计）
var gold_collected_this_run: int = 0
var hp: int = 72
var max_hp: int = 72
var ascension_level: int = 0

var deck: Array[String] = []
var modules: Array[String] = []
var charms: Array[String] = []
var owned_charms: Array[String] = []
var tunes: Array[String] = []
var story_flags: Dictionary = {}
# 本局已经历过的事件 ID（用于事件去重，避免同局重复刷同一事件）
var seen_event_ids: Array[String] = []
var map_nodes: Array[MapNodeModel] = []
var reachable_node_ids: Array[String] = []
var pending_rewards: Dictionary = {}
var rng_seed: int = 0
var last_run_summary: Dictionary = {}
var last_death_cause: Dictionary = {}
var pending_interfloor_rest: bool = false
var run_won: bool = false
var save_batch_depth: int = 0
var save_snapshot_queued: bool = false

func _ready() -> void:
	var root_window: Window = get_tree().root
	if root_window != null and not root_window.close_requested.is_connected(_on_window_close_requested):
		root_window.close_requested.connect(_on_window_close_requested)

func _notification(what: int) -> void:
	# 操作系统级退出（Cmd+Q / Dock 退出等）不一定触发 close_requested，在此统一落盘
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_persistent_state()

func start_new_run(char_data: CharacterData, seed_value: int = 0) -> void:
	exit_flush_done = false
	save_batch_depth = 0
	save_snapshot_queued = false
	character = char_data
	current_floor = 1
	current_node_id = ""
	gold = 99
	gold_collected_this_run = 0
	# 读取难度等级（来自 SettingsManager），并应用到本局
	ascension_level = _read_ascension_level_from_settings()
	max_hp = char_data.max_hp
	hp = char_data.max_hp
	# 难度 1+：起血 -2 / 级，最低不低于 30
	if ascension_level >= 1:
		var hp_penalty: int = ascension_level * 2
		max_hp = max(30, char_data.max_hp - hp_penalty)
		hp = max_hp
	# 难度 6+：起血再 -10
	if ascension_level >= 6:
		max_hp = max(20, max_hp - 10)
		hp = max_hp
	deck = _starter_deck_for_character(char_data)
	modules.clear()
	charms.clear()
	owned_charms.clear()
	tunes.clear()
	for charm_id in char_data.starter_charms:
		var normalized_charm: String = String(charm_id)
		if normalized_charm.is_empty():
			continue
		if not owned_charms.has(normalized_charm):
			owned_charms.append(normalized_charm)
		if not charms.has(normalized_charm) and charms.size() < max_charm_slots():
			charms.append(normalized_charm)
	_apply_run_start_charms()
	story_flags.clear()
	seen_event_ids.clear()
	pending_rewards.clear()
	last_run_summary.clear()
	last_death_cause.clear()
	pending_interfloor_rest = false
	run_won = false
	rng_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	var character_focus: String = _character_focus_archetype(char_data.id)
	story_flags["character_focus_archetype"] = character_focus
	story_flags["soft_focus_archetype"] = character_focus if not character_focus.is_empty() else _seeded_soft_focus_archetype()
	story_flags["battle_reward_archetypes"] = []
	_generate_floor_map(current_floor)
	_record_run_started()
	# 记录起始卡牌/护符到 meta 解锁系统（图鉴发现）
	if MetaUnlockManager != null:
		for starter_card_id in deck:
			MetaUnlockManager.record_card_seen(starter_card_id)
		for starter_charm_id in owned_charms:
			MetaUnlockManager.record_charm_seen(starter_charm_id)
	run_started.emit()
	run_updated.emit()
	floor_changed.emit(current_floor)
	save_run_snapshot()

func abandon_run() -> void:
	exit_flush_done = false
	save_batch_depth = 0
	save_snapshot_queued = false
	character = null
	current_floor = 0
	current_node_id = ""
	gold = 99
	hp = 72
	max_hp = 72
	ascension_level = 0
	deck.clear()
	modules.clear()
	charms.clear()
	owned_charms.clear()
	tunes.clear()
	story_flags.clear()
	map_nodes.clear()
	reachable_node_ids.clear()
	pending_rewards.clear()
	last_run_summary.clear()
	last_death_cause.clear()
	pending_interfloor_rest = false
	run_won = false
	clear_saved_run()
	run_updated.emit()
	map_changed.emit()

func add_gold(amount: int) -> void:
	gold += amount
	if amount > 0:
		gold_collected_this_run += amount
	gold_changed.emit(gold)
	run_updated.emit()
	save_run_snapshot()

func lose_hp(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	run_updated.emit()
	save_run_snapshot()

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	run_updated.emit()
	save_run_snapshot()

func heal_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	run_updated.emit()
	save_run_snapshot()

func add_card(card_id: String, source: String = "generic") -> void:
	if card_id.is_empty():
		return
	deck.append(card_id)
	_record_card_gain(card_id, source)
	if MetaUnlockManager != null:
		MetaUnlockManager.record_card_seen(card_id)
	deck_changed.emit()
	run_updated.emit()
	save_run_snapshot()

func remove_card(card_id: String) -> bool:
	var idx: int = deck.find(card_id)
	if idx == -1:
		return false
	deck.remove_at(idx)
	deck_changed.emit()
	run_updated.emit()
	save_run_snapshot()
	return true

func add_module(module_id: String) -> void:
	if not modules.has(module_id):
		modules.append(module_id)
	if MetaUnlockManager != null:
		MetaUnlockManager.record_module_seen(module_id)
	modules_changed.emit()
	run_updated.emit()
	save_run_snapshot()

func add_charm(charm_id: String, auto_equip_if_slot: bool = true) -> void:
	if charm_id.is_empty():
		return
	var changed: bool = false
	if not owned_charms.has(charm_id):
		owned_charms.append(charm_id)
		changed = true
	if auto_equip_if_slot and not charms.has(charm_id) and charms.size() < max_charm_slots():
		charms.append(charm_id)
		changed = true
	if not changed:
		return
	if MetaUnlockManager != null:
		MetaUnlockManager.record_charm_seen(charm_id)
	charms_changed.emit()
	run_updated.emit()
	save_run_snapshot()

func equip_charm(charm_id: String, slot_index: int = -1) -> bool:
	if charm_id.is_empty() or not owned_charms.has(charm_id):
		return false
	if slot_index < 0:
		if charms.has(charm_id):
			return true
		if charms.size() < max_charm_slots():
			charms.append(charm_id)
		elif not charms.is_empty():
			charms[0] = charm_id
		else:
			charms.append(charm_id)
	else:
		var target_slot: int = int(clamp(slot_index, 0, max_charm_slots() - 1))
		while charms.size() <= target_slot and charms.size() < max_charm_slots():
			charms.append("")
		var existing_slot: int = charms.find(charm_id)
		if existing_slot == target_slot:
			pass  # 已在目标槽位，无需操作
		elif existing_slot != -1:
			# 交换槽位：把目标槽位原有内容放到原槽位，避免护符丢失
			var swapped: String = charms[target_slot]
			charms[existing_slot] = swapped
			charms[target_slot] = charm_id
		else:
			# 新装备到指定槽位
			charms[target_slot] = charm_id
		# 只移除尾部空槽位，保持已装备护符的槽位索引稳定
		charms = _trim_trailing_empty(charms)
		# 压实内部空串孔洞（指定槽位补位的历史遗留），避免 has_relic("") 等幽灵判定与存读档漂移
		var compacted_charms: Array[String] = []
		for existing_charm in charms:
			if not String(existing_charm).is_empty():
				compacted_charms.append(String(existing_charm))
		charms = compacted_charms
	charms_changed.emit()
	run_updated.emit()
	save_run_snapshot()
	return true

func add_tune(tune_id: String) -> bool:
	if tune_id.is_empty() or tunes.has(tune_id):
		return false
	tunes.append(tune_id)
	run_updated.emit()
	save_run_snapshot()
	return true

func has_tune(tune_id: String) -> bool:
	return tunes.has(tune_id)

func tune_offer(seed_value: int, count: int = 3) -> Array[String]:
	var character_id: String = character.id if character != null else ""
	return TUNE_LIBRARY.offer_tunes_for_character(character_id, seed_value, count, tunes)

func tune_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for tune_id in tunes:
		var title: String = LocalizationManager.tune_title(tune_id, TUNE_LIBRARY.title(tune_id)) if LocalizationManager != null else TUNE_LIBRARY.title(tune_id)
		var short_text: String = LocalizationManager.tune_short(tune_id, TUNE_LIBRARY.short_text(tune_id)) if LocalizationManager != null else TUNE_LIBRARY.short_text(tune_id)
		lines.append("%s：%s" % [title, short_text])
	return lines

func has_relic(relic_id: String) -> bool:
	if relic_id.is_empty():
		return false
	return modules.has(relic_id) or charms.has(relic_id)

func is_charm_owned(charm_id: String) -> bool:
	return owned_charms.has(charm_id)

func is_charm_equipped(charm_id: String) -> bool:
	return charms.has(charm_id)

func max_charm_slots() -> int:
	return 2

func unequipped_owned_charms() -> Array[String]:
	var result: Array[String] = []
	for charm_id in owned_charms:
		if not charms.has(charm_id):
			result.append(charm_id)
	return result

func set_flag(flag_name: String, value = true) -> void:
	story_flags[flag_name] = value
	run_updated.emit()
	save_run_snapshot()

func has_flag(flag_name: String) -> bool:
	return bool(story_flags.get(flag_name, false))

# 记录本局已经历的事件（用于地图生成去重，避免同局重复刷同一事件）
func mark_event_seen(event_id: String) -> void:
	if event_id.is_empty() or seen_event_ids.has(event_id):
		return
	seen_event_ids.append(event_id)
	run_updated.emit()
	save_run_snapshot()

func current_node() -> MapNodeModel:
	if current_node_id.is_empty():
		return null
	return get_node_by_id(current_node_id)

func clear_stale_node_selection() -> void:
	if current_node_id.is_empty():
		return
	# The map scene should never remain open while a node is actively selected.
	# If we returned here with a leftover selection, always clear it so routes
	# become clickable again instead of leaving the whole floor disabled.
	current_node_id = ""
	run_updated.emit()
	map_changed.emit()
	save_run_snapshot()

func get_node_by_id(node_id: String) -> MapNodeModel:
	for node in map_nodes:
		if node.id == node_id:
			return node
	return null

func select_node(node_id: String) -> bool:
	if not is_node_reachable(node_id):
		return false
	var node: MapNodeModel = get_node_by_id(node_id)
	if node == null or node.completed:
		return false
	current_node_id = node_id
	run_updated.emit()
	map_changed.emit()
	save_run_snapshot()
	return true

func complete_current_node() -> void:
	var node: MapNodeModel = current_node()
	if node == null:
		return
	node.completed = true
	current_node_id = ""
	if node.node_type == "boss":
		_finish_floor()
	else:
		reachable_node_ids = node.next_ids.duplicate()
	map_changed.emit()
	run_updated.emit()
	save_run_snapshot()

func is_node_reachable(node_id: String) -> bool:
	return current_node_id.is_empty() and reachable_node_ids.has(node_id)

func get_rows() -> Array:
	var grouped: Dictionary = {}
	var row_indexes: Array[int] = []
	for node in map_nodes:
		if not grouped.has(node.row):
			grouped[node.row] = []
			row_indexes.append(node.row)
		var row_nodes: Array = grouped[node.row]
		row_nodes.append(node)
	row_indexes.sort()
	var rows: Array = []
	for row_index in row_indexes:
		var row_nodes: Array = grouped[row_index]
		row_nodes.sort_custom(func(a: MapNodeModel, b: MapNodeModel) -> bool:
			return a.lane < b.lane
		)
		rows.append(row_nodes)
	return rows

func _generate_floor_map(floor_index: int) -> void:
	# next_floor_fewer_events：本层事件节点减少，生成时消费
	var fewer_events: bool = has_flag("next_floor_fewer_events")
	if fewer_events:
		set_flag("next_floor_fewer_events", false)
	map_nodes = MapGenerator.new(rng_seed + floor_index * 997 + deck.size() * 31 + modules.size() * 17).generate_floor(floor_index, fewer_events)
	reachable_node_ids.clear()
	current_node_id = ""
	var first_row: int = -1
	for node in map_nodes:
		if first_row == -1 or node.row < first_row:
			first_row = node.row
	for node in map_nodes:
		if node.row == first_row:
			reachable_node_ids.append(node.id)
	map_changed.emit()

func _finish_floor() -> void:
	if current_floor < 3:
		current_floor += 1
		_generate_floor_map(current_floor)
		pending_interfloor_rest = true
		floor_changed.emit(current_floor)
		save_run_snapshot()
		return
	if current_floor == 3 and _should_unlock_hidden_floor():
		run_won = true
		story_flags["run_won"] = true
		story_flags["hidden_route_unlocked"] = true
		current_floor = 4
		_generate_floor_map(current_floor)
		pending_interfloor_rest = true
		floor_changed.emit(current_floor)
		save_run_snapshot()
		return
	if current_floor == 3:
		run_won = true
		story_flags["run_won"] = true
		story_flags["ending_variant"] = "standard"
	elif current_floor == 4:
		run_won = true
		story_flags["run_won"] = true
		story_flags["hidden_truth_cleared"] = true
		story_flags["ending_variant"] = "hidden"
	set_flag("run_complete", true)
	reachable_node_ids.clear()
	clear_saved_run()

func should_take_interfloor_rest() -> bool:
	return pending_interfloor_rest

func consume_interfloor_rest() -> void:
	pending_interfloor_rest = false
	run_updated.emit()
	save_run_snapshot()

func _should_unlock_hidden_floor() -> bool:
	var score: int = 0
	if has_flag("accept_burden_1"):
		score += 1
	if has_flag("accept_burden_2"):
		score += 1
	if has_flag("accept_burden_3"):
		score += 1
	if has_flag("self_damage_rescue_4"):
		score += 1
	if _count_rhodes_modules() >= 3:
		score += 1
	if has_flag("spared_w"):
		score += 1
	return score >= 2

func _count_rhodes_modules() -> int:
	var tracked: Array[String] = ["rhodes_tactical_console", "field_command_badge", "ashen_thread", "rhodes_pin", "operators_thread"]
	var total: int = 0
	for module_id in tracked:
		if modules.has(module_id) or owned_charms.has(module_id) or charms.has(module_id):
			total += 1
	return total

func has_active_run() -> bool:
	return character != null and current_floor > 0 and not has_flag("run_complete")

func get_reward_bias_weights() -> Dictionary:
	var weights: Dictionary = {
		"will_burst": 1.0,
		"resonance_combo": 1.0,
		"command_support": 1.0,
		"overload_sacrifice": 1.0,
		"ammo_tempo": 1.0,
		"mark_execution": 1.0,
		"burst_storm": 1.0,
		"support_mobility": 1.0,
		"neutral": 1.0
	}
	var is_exusiai: bool = character != null and String(character.id) == "exusiai"
	var soft_focus: String = String(story_flags.get("soft_focus_archetype", ""))
	var recent_archetypes: Array[String] = _string_array_from_variant(story_flags.get("battle_reward_archetypes", []))
	if current_floor == 1 and not soft_focus.is_empty() and recent_archetypes.size() < 2 and weights.has(soft_focus):
		weights[soft_focus] = float(weights[soft_focus]) * 1.18
	var character_focus: String = String(story_flags.get("character_focus_archetype", ""))
	if not character_focus.is_empty() and weights.has(character_focus):
		weights[character_focus] = float(weights[character_focus]) * 1.16
	if has_flag("doctor_ideal"):
		if is_exusiai:
			if weights.has("support_mobility"):
				weights["support_mobility"] = float(weights["support_mobility"]) * 1.35
			if weights.has("ammo_tempo"):
				weights["ammo_tempo"] = float(weights["ammo_tempo"]) * 1.18
			if weights.has("mark_execution"):
				weights["mark_execution"] = float(weights["mark_execution"]) * 1.08
		else:
			if weights.has("command_support"):
				weights["command_support"] = float(weights["command_support"]) * 1.35
			if weights.has("support_mobility"):
				weights["support_mobility"] = float(weights["support_mobility"]) * 1.22
			if weights.has("resonance_combo"):
				weights["resonance_combo"] = float(weights["resonance_combo"]) * 1.10
	if has_flag("doctor_efficiency"):
		if is_exusiai:
			if weights.has("mark_execution"):
				weights["mark_execution"] = float(weights["mark_execution"]) * 1.32
			if weights.has("burst_storm"):
				weights["burst_storm"] = float(weights["burst_storm"]) * 1.26
		else:
			if weights.has("will_burst"):
				weights["will_burst"] = float(weights["will_burst"]) * 1.35
			if weights.has("burst_storm"):
				weights["burst_storm"] = float(weights["burst_storm"]) * 1.25
	if has_flag("doctor_burden"):
		if is_exusiai:
			if weights.has("burst_storm"):
				weights["burst_storm"] = float(weights["burst_storm"]) * 1.30
			if weights.has("ammo_tempo"):
				weights["ammo_tempo"] = float(weights["ammo_tempo"]) * 1.18
		else:
			if weights.has("overload_sacrifice"):
				weights["overload_sacrifice"] = float(weights["overload_sacrifice"]) * 1.35
			if weights.has("will_burst"):
				weights["will_burst"] = float(weights["will_burst"]) * 1.10
	if recent_archetypes.size() >= 2:
		var last_archetype: String = recent_archetypes[recent_archetypes.size() - 1]
		var prev_archetype: String = recent_archetypes[recent_archetypes.size() - 2]
		if last_archetype == prev_archetype and weights.has(last_archetype):
			weights[last_archetype] = float(weights[last_archetype]) * 1.25
	var deck_counts: Dictionary = _deck_archetype_counts()
	var dominant: String = ""
	var dominant_count: int = 0
	for archetype in deck_counts.keys():
		var count: int = int(deck_counts[archetype])
		if archetype == "neutral":
			continue
		if count > dominant_count:
			dominant = String(archetype)
			dominant_count = count
	if not dominant.is_empty() and dominant_count >= 3 and weights.has(dominant):
		weights[dominant] = float(weights[dominant]) * 1.15
	return weights

func has_saved_run() -> bool:
	var profile: Dictionary = SaveManager.load_profile()
	return typeof(profile.get("run_save", null)) == TYPE_DICTIONARY

func saved_run_summary() -> Dictionary:
	var profile: Dictionary = SaveManager.load_profile()
	var save_data: Variant = profile.get("run_save", {})
	return save_data if typeof(save_data) == TYPE_DICTIONARY else {}

func saved_run_character_id() -> String:
	var save_data: Dictionary = saved_run_summary()
	return String(save_data.get("character_id", ""))

func has_conflicting_saved_run(character_id: String) -> bool:
	if not has_saved_run():
		return false
	var saved_character_id: String = saved_run_character_id()
	return not saved_character_id.is_empty() and saved_character_id != character_id

func save_run_snapshot() -> void:
	if not has_active_run():
		return
	if save_batch_depth > 0:
		save_snapshot_queued = true
		return
	SaveManager.update_profile({"run_save": _serialize_run()})

func checkpoint_run() -> void:
	save_run_snapshot()

func begin_save_batch() -> void:
	save_batch_depth += 1

func end_save_batch() -> void:
	if save_batch_depth <= 0:
		return
	save_batch_depth -= 1
	if save_batch_depth == 0 and save_snapshot_queued:
		save_snapshot_queued = false
		save_run_snapshot()

func set_pending_rewards(value: Dictionary) -> void:
	pending_rewards = value.duplicate(true)
	run_updated.emit()
	save_run_snapshot()

func clear_pending_rewards() -> void:
	pending_rewards.clear()
	run_updated.emit()
	save_run_snapshot()

func set_last_run_summary(summary: Dictionary) -> void:
	last_run_summary = summary.duplicate(true)
	run_updated.emit()
	save_run_snapshot()

func flush_persistent_state() -> void:
	if exit_flush_done:
		return
	exit_flush_done = true
	save_run_snapshot()

func clear_saved_run() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	profile.erase("run_save")
	profile["run_save"] = null
	SaveManager.save_profile(profile)

func record_run_result(victory: bool) -> void:
	var profile: Dictionary = SaveManager.load_profile()
	var stats: Dictionary = profile.get("stats", {}) if typeof(profile.get("stats", {})) == TYPE_DICTIONARY else {}
	stats["runs_started"] = int(stats.get("runs_started", 0))
	stats["runs_won"] = int(stats.get("runs_won", 0)) + (1 if victory else 0)
	stats["runs_lost"] = int(stats.get("runs_lost", 0)) + (0 if victory else 1)
	stats["best_floor"] = max(int(stats.get("best_floor", 0)), current_floor)
	stats["total_gold_collected"] = int(stats.get("total_gold_collected", 0)) + gold_collected_this_run
	profile["stats"] = stats
	var character_id: String = character.id if character != null else "amiya"
	var character_stats: Dictionary = _profile_character_stats(profile, character_id)
	character_stats["runs_won"] = int(character_stats.get("runs_won", 0)) + (1 if victory else 0)
	character_stats["runs_lost"] = int(character_stats.get("runs_lost", 0)) + (0 if victory else 1)
	character_stats["best_floor"] = max(int(character_stats.get("best_floor", 0)), current_floor)
	character_stats["total_gold_collected"] = int(character_stats.get("total_gold_collected", 0)) + gold_collected_this_run
	_set_profile_character_stats(profile, character_id, character_stats)

	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	var record: Dictionary = {
		"character_id": character_id,
		"floor": current_floor,
		"gold": gold,
		"deck_size": deck.size(),
		"modules": modules.size(),
		"result": "victory" if victory else "defeat",
		"timestamp": int(Time.get_unix_time_from_system())
	}
	history.insert(0, record)
	while history.size() > 8:
		history.pop_back()
	profile["run_history"] = history
	SaveManager.save_profile(profile)
	# 通关当前难度且该难度为已解锁最高级时，解锁下一级（全局共享）
	if victory and SettingsManager != null and SettingsManager.has_method("unlock_next_ascension"):
		if ascension_level >= SettingsManager.get_ascension_unlocked():
			SettingsManager.unlock_next_ascension()
	# 提升关键 story_flags 到 meta 解锁系统（跨 run 持久化成就）
	if MetaUnlockManager != null:
		MetaUnlockManager.promote_run_achievements(story_flags)

func load_saved_run() -> bool:
	var save_data: Dictionary = saved_run_summary()
	if save_data.is_empty():
		return false
	var char_id: String = String(save_data.get("character_id", ""))
	var char_data: CharacterData = Util.load_character(char_id)
	if char_data == null:
		return false
	exit_flush_done = false
	save_batch_depth = 0
	save_snapshot_queued = false
	character = char_data
	current_floor = int(save_data.get("current_floor", 1))
	current_node_id = String(save_data.get("current_node_id", ""))
	gold = int(save_data.get("gold", 99))
	hp = int(save_data.get("hp", char_data.max_hp))
	max_hp = int(save_data.get("max_hp", char_data.max_hp))
	ascension_level = int(save_data.get("ascension_level", 0))
	deck = _string_array_from_variant(save_data.get("deck", []))
	var repaired_empty_deck: bool = _ensure_run_deck_not_empty(char_data, "load_saved_run")
	modules = _string_array_from_variant(save_data.get("modules", []))
	var loaded_equipped_charms: Array[String] = _string_array_from_variant(save_data.get("charms", []))
	owned_charms = _string_array_from_variant(save_data.get("owned_charms", loaded_equipped_charms))
	charms.clear()
	for charm_id in loaded_equipped_charms:
		if owned_charms.has(charm_id) and not charms.has(charm_id) and charms.size() < max_charm_slots():
			charms.append(charm_id)
	tunes = _string_array_from_variant(save_data.get("tunes", []))
	reachable_node_ids = _string_array_from_variant(save_data.get("reachable_node_ids", []))
	pending_rewards = save_data.get("pending_rewards", {}) if typeof(save_data.get("pending_rewards", {})) == TYPE_DICTIONARY else {}
	last_run_summary = save_data.get("last_run_summary", {}) if typeof(save_data.get("last_run_summary", {})) == TYPE_DICTIONARY else {}
	story_flags = save_data.get("story_flags", {}) if typeof(save_data.get("story_flags", {})) == TYPE_DICTIONARY else {}
	seen_event_ids = _string_array_from_variant(save_data.get("seen_event_ids", []))
	gold_collected_this_run = int(save_data.get("gold_collected_this_run", 0))
	rng_seed = int(save_data.get("rng_seed", int(Time.get_unix_time_from_system())))
	pending_interfloor_rest = bool(save_data.get("pending_interfloor_rest", false))
	run_won = bool(save_data.get("run_won", false))
	map_nodes = []
	for node_data_variant in save_data.get("map_nodes", []):
		if typeof(node_data_variant) != TYPE_DICTIONARY:
			continue
		var node_data: Dictionary = node_data_variant
		var node: MapNodeModel = MapNodeModel.new()
		node.id = String(node_data.get("id", ""))
		node.node_type = String(node_data.get("node_type", "battle"))
		node.floor_index = int(node_data.get("floor_index", current_floor))
		node.index = int(node_data.get("index", 0))
		node.row = int(node_data.get("row", 0))
		node.lane = int(node_data.get("lane", 0))
		node.next_ids = _string_array_from_variant(node_data.get("next_ids", []))
		node.completed = bool(node_data.get("completed", false))
		node.metadata = node_data.get("metadata", {}) if typeof(node_data.get("metadata", {})) == TYPE_DICTIONARY else {}
		map_nodes.append(node)
	run_started.emit()
	run_updated.emit()
	floor_changed.emit(current_floor)
	map_changed.emit()
	if repaired_empty_deck:
		save_run_snapshot()
	return true

func _serialize_run() -> Dictionary:
	var serialized_nodes: Array[Dictionary] = []
	for node in map_nodes:
		serialized_nodes.append({
			"id": node.id,
			"node_type": node.node_type,
			"floor_index": node.floor_index,
			"index": node.index,
			"row": node.row,
			"lane": node.lane,
			"next_ids": node.next_ids.duplicate(),
			"completed": node.completed,
			"metadata": node.metadata.duplicate(true)
		})
	return {
		"character_id": character.id,
		"current_floor": current_floor,
		"current_node_id": current_node_id,
		"gold": gold,
		"hp": hp,
		"max_hp": max_hp,
		"ascension_level": ascension_level,
		"deck": deck.duplicate(),
		"modules": modules.duplicate(),
		"charms": charms.duplicate(),
		"owned_charms": owned_charms.duplicate(),
		"tunes": tunes.duplicate(),
		"story_flags": story_flags.duplicate(true),
		"seen_event_ids": seen_event_ids.duplicate(),
		"gold_collected_this_run": gold_collected_this_run,
		"map_nodes": serialized_nodes,
		"reachable_node_ids": reachable_node_ids.duplicate(),
		"pending_rewards": pending_rewards.duplicate(true),
		"rng_seed": rng_seed,
		"last_run_summary": last_run_summary.duplicate(true),
		"pending_interfloor_rest": pending_interfloor_rest,
		"run_won": run_won
	}

func _apply_run_start_charms() -> void:
	if charms.has("rabbit_emblem"):
		deck.append("mental_tuning")
	if charms.has("ex_h01_applepie_badge"):
		deck.append("ex_b06_burst_entry")

func _starter_deck_for_character(char_data: CharacterData) -> Array[String]:
	var result: Array[String] = []
	if char_data == null:
		return result
	for card_id in char_data.starter_deck:
		var normalized_card_id: String = String(card_id)
		if not normalized_card_id.is_empty():
			result.append(normalized_card_id)
	if result.is_empty():
		result = Util.default_starter_deck_for_character(char_data.id)
	return result

func _ensure_run_deck_not_empty(char_data: CharacterData, source: String = "") -> bool:
	if not deck.is_empty():
		return false
	var starter_cards: Array[String] = _starter_deck_for_character(char_data)
	if starter_cards.is_empty():
		return false
	deck = starter_cards
	if not source.is_empty():
		push_warning("Run deck was empty during %s; restored %d starter cards for %s." % [source, deck.size(), char_data.id])
	return true

func _record_run_started() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	var stats: Dictionary = profile.get("stats", {}) if typeof(profile.get("stats", {})) == TYPE_DICTIONARY else {}
	stats["runs_started"] = int(stats.get("runs_started", 0)) + 1
	profile["stats"] = stats
	var character_id: String = character.id if character != null else "amiya"
	var character_stats: Dictionary = _profile_character_stats(profile, character_id)
	character_stats["runs_started"] = int(character_stats.get("runs_started", 0)) + 1
	_set_profile_character_stats(profile, character_id, character_stats)
	SaveManager.save_profile(profile)

func _profile_character_stats(profile: Dictionary, character_id: String) -> Dictionary:
	var all_stats: Dictionary = profile.get("character_stats", {}) if typeof(profile.get("character_stats", {})) == TYPE_DICTIONARY else {}
	var stats: Dictionary = all_stats.get(character_id, {}) if typeof(all_stats.get(character_id, {})) == TYPE_DICTIONARY else {}
	stats["runs_started"] = int(stats.get("runs_started", 0))
	stats["runs_won"] = int(stats.get("runs_won", 0))
	stats["runs_lost"] = int(stats.get("runs_lost", 0))
	stats["best_floor"] = int(stats.get("best_floor", 0))
	stats["total_gold_collected"] = int(stats.get("total_gold_collected", 0))
	return stats

func _set_profile_character_stats(profile: Dictionary, character_id: String, stats: Dictionary) -> void:
	var all_stats: Dictionary = profile.get("character_stats", {}) if typeof(profile.get("character_stats", {})) == TYPE_DICTIONARY else {}
	all_stats[character_id] = stats.duplicate(true)
	profile["character_stats"] = all_stats

func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(String(item))
	return result

func _record_card_gain(card_id: String, source: String) -> void:
	if source != "battle_reward":
		return
	var archetype: String = Util.card_archetype(card_id)
	if archetype == "neutral":
		return
	var recent_archetypes: Array[String] = _string_array_from_variant(story_flags.get("battle_reward_archetypes", []))
	recent_archetypes.append(archetype)
	while recent_archetypes.size() > 4:
		recent_archetypes.pop_front()
	story_flags["battle_reward_archetypes"] = recent_archetypes

func _deck_archetype_counts() -> Dictionary:
	var counts: Dictionary = {
		"will_burst": 0,
		"resonance_combo": 0,
		"command_support": 0,
		"overload_sacrifice": 0,
		"ammo_tempo": 0,
		"mark_execution": 0,
		"burst_storm": 0,
		"support_mobility": 0,
		"neutral": 0
	}
	for card_id in deck:
		var archetype: String = Util.card_archetype(String(card_id))
		counts[archetype] = int(counts.get(archetype, 0)) + 1
	return counts

func _seeded_soft_focus_archetype() -> String:
	var options: Array[String] = ["will_burst", "resonance_combo", "command_support", "overload_sacrifice"]
	if character != null and character.id == "exusiai":
		options = ["ammo_tempo", "mark_execution", "burst_storm", "support_mobility"]
	if options.is_empty():
		return ""
	return options[abs(rng_seed) % options.size()]

func _character_focus_archetype(character_id: String) -> String:
	match character_id:
		"amiya":
			return "will_burst"
		"nearl":
			return "command_support"
		"exusiai":
			return "ammo_tempo"
		"kaltsit":
			return "resonance_combo"
		_:
			return ""

func _on_window_close_requested() -> void:
	flush_persistent_state()
	get_tree().quit()

# 只移除尾部空字符串，保持已装备护符的槽位索引稳定
func _trim_trailing_empty(values: Array[String]) -> Array[String]:
	var result: Array[String] = values.duplicate()
	while not result.is_empty() and result.back().is_empty():
		result.pop_back()
	return result

func _read_ascension_level_from_settings() -> int:
	if SettingsManager != null and SettingsManager.has_method("get_ascension_level"):
		return SettingsManager.get_ascension_level()
	return 0

# 难度等级对战斗的影响（被 BattleManager 调用）
func ascension_enemy_hp_bonus() -> int:
	# 难度 2+：敌人血量 +5%/级（每级 +2 HP 取整，最低 +0）
	if ascension_level < 2:
		return 0
	return (ascension_level - 1) * 2

func ascension_enemy_damage_bonus() -> int:
	# 难度 4+：敌人伤害加成（4-6 +1，7-9 +2，10-12 +3，...）
	if ascension_level < 4:
		return 0
	return (ascension_level - 4) / 3 + 1

func ascension_gold_penalty() -> float:
	# 难度 3+：金币奖励 -5%/级（最低 -50%）
	if ascension_level < 3:
		return 0.0
	return clamp(float(ascension_level - 2) * 0.05, 0.0, 0.5)

func ascension_starting_energy_penalty() -> int:
	# 难度 10+：起能量 -1；难度 16+：再 -1
	if ascension_level >= 16:
		return 2
	if ascension_level >= 10:
		return 1
	return 0
