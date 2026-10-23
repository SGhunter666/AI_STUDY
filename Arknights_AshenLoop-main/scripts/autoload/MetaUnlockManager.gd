extends Node

# Meta 进度解锁系统：跨 run 持久化的发现/解锁状态
# - 卡牌/护符/模块：一开始全部解锁，获取纯靠随机奖励
# - 成就 flags（如 hidden_truth_cleared、first_victory_done）
# - 角色解锁（复用 CharacterData.unlock_flags 声明条件）

signal unlocks_changed
signal new_unlocks_available

const PROFILE_KEY := "meta_unlocks"

# 当 run 期间的发现累积到通知队列，run 结束后由主菜单/结算页弹出
# 结构：[{ "kind": "card"|"charm"|"module", "id": "xxx", "name": "显示名" }]
var _pending_notifications: Array[Dictionary] = []

func _ready() -> void:
	# 确保新玩家有默认结构
	_ensure_default_structure()

func _ensure_default_structure() -> void:
	var unlocks: Dictionary = _load_unlocks()
	var changed: bool = false
	# 不仅检查 key 是否存在，还检查值的类型是否合法，防止存档损坏导致空数组/错误类型
	if typeof(unlocks.get("cards_seen")) != TYPE_ARRAY:
		unlocks["cards_seen"] = []
		changed = true
	if typeof(unlocks.get("charms_seen")) != TYPE_ARRAY:
		unlocks["charms_seen"] = []
		changed = true
	if typeof(unlocks.get("modules_seen")) != TYPE_ARRAY:
		unlocks["modules_seen"] = []
		changed = true
	if typeof(unlocks.get("flags")) != TYPE_DICTIONARY:
		unlocks["flags"] = {}
		changed = true
	var unlocked: Variant = unlocks.get("characters_unlocked")
	if typeof(unlocked) != TYPE_ARRAY or (unlocked as Array).is_empty():
		unlocks["characters_unlocked"] = ["amiya", "nearl", "exusiai", "kaltsit"]
		changed = true
	if changed:
		_save_unlocks(unlocks)

func _load_unlocks() -> Dictionary:
	if SaveManager == null:
		return {}
	var profile: Dictionary = SaveManager.load_profile()
	var raw: Variant = profile.get(PROFILE_KEY, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw

func _save_unlocks(unlocks: Dictionary) -> void:
	if SaveManager == null:
		return
	SaveManager.update_profile({PROFILE_KEY: unlocks})
	unlocks_changed.emit()

# ===== 卡牌/护符/模块发现 =====
# 卡牌/护符/模块一开始全部解锁，不再有"首次发现"通知仪式。
# record_*_seen 保留为空操作以兼容现有调用方。

func record_card_seen(_card_id: String) -> void:
	pass

func record_charm_seen(_charm_id: String) -> void:
	pass

func record_module_seen(_module_id: String) -> void:
	pass

# ===== 解锁通知队列 =====
# 通知队列已废弃，始终为空。

func has_pending_notifications() -> bool:
	return false

func pop_pending_notifications() -> Array[Dictionary]:
	return []

func peek_pending_count() -> int:
	return 0

func is_card_seen(_card_id: String) -> bool:
	return true

func is_charm_seen(_charm_id: String) -> bool:
	return true

func is_module_seen(_module_id: String) -> bool:
	return true

# ===== 成就 flags =====

func set_flag(flag_id: String, value: bool = true) -> void:
	var unlocks: Dictionary = _load_unlocks()
	var flags: Dictionary = unlocks.get("flags", {}) if typeof(unlocks.get("flags")) == TYPE_DICTIONARY else {}
	if bool(flags.get(flag_id, false)) == value:
		return
	flags[flag_id] = value
	unlocks["flags"] = flags
	_save_unlocks(unlocks)

func has_flag(flag_id: String) -> bool:
	var unlocks: Dictionary = _load_unlocks()
	var flags: Variant = unlocks.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return false
	return bool((flags as Dictionary).get(flag_id, false))

# ===== 角色解锁 =====

func is_character_unlocked(character_id: String) -> bool:
	var unlocks: Dictionary = _load_unlocks()
	var unlocked: Variant = unlocks.get("characters_unlocked", ["amiya", "nearl", "exusiai", "kaltsit"])
	if typeof(unlocked) != TYPE_ARRAY:
		return false
	return (unlocked as Array).has(character_id)

func unlock_character(character_id: String) -> void:
	if character_id.is_empty():
		return
	var unlocks: Dictionary = _load_unlocks()
	var unlocked: Array = unlocks.get("characters_unlocked", ["amiya", "nearl", "exusiai", "kaltsit"]) if typeof(unlocks.get("characters_unlocked")) == TYPE_ARRAY else ["amiya", "nearl", "exusiai", "kaltsit"]
	if unlocked.has(character_id):
		return
	unlocked.append(character_id)
	unlocks["characters_unlocked"] = unlocked
	_save_unlocks(unlocks)

# 检查角色解锁条件（基于 CharacterData.unlock_flags 声明）
# unlock_flags 为空 = 无条件解锁
# unlock_flags 非空 = 所有 flag 都需满足
func check_character_unlock(character_data) -> bool:
	if character_data == null:
		return false
	if character_data.unlock_flags.is_empty():
		return true
	for flag in character_data.unlock_flags:
		if not has_flag(String(flag)):
			return false
	return true

# 从 run 结束时的 story_flags 提升关键成就到 profile
func promote_run_achievements(story_flags: Dictionary) -> void:
	var achievements_to_promote: Array[String] = [
		"hidden_truth_cleared",
		"hidden_route_unlocked",
		"ending_variant"
	]
	var changed: bool = false
	for flag_key in achievements_to_promote:
		if story_flags.has(flag_key):
			set_flag(flag_key, bool(story_flags[flag_key]) if flag_key != "ending_variant" else true)
			changed = true
	# 首次胜利成就
	if story_flags.has("run_won") and bool(story_flags.get("run_won", false)):
		set_flag("first_victory_done", true)
		changed = true
	if changed:
		unlocks_changed.emit()
