class_name TuneLibrary
extends RefCounted

const DEFAULT_TUNES: Dictionary = {
	"resonance_apply_plus_one": {
		"title": "共振棱线",
		"short": "施加共振额外 +1",
		"description": "你施加共振时额外 +1。适合共振铺场和引爆流。",
		"archetype": "resonance_combo",
		"accent": "#71d7ff",
	},
	"support_echo_seed": {
		"title": "指挥回响",
		"short": "首张支援赋予回响",
		"description": "每回合第一张支援牌结算后，获得回响 50%，用于下一张术式牌。",
		"archetype": "command_support",
		"accent": "#f3b36d",
	},
	"will_arts_discount": {
		"title": "意志聚焦",
		"short": "意志至少为 4 时首张术式牌 -1 费",
		"description": "若当前意志至少为 4，本回合第一张术式牌费用 -1。",
		"archetype": "will_burst",
		"accent": "#95a2ff",
	},
	"overload_guard_matrix": {
		"title": "负荷护矩",
		"short": "首层过载转为护盾",
		"description": "每回合第一次获得过载时，立刻获得 6 点护盾。",
		"archetype": "overload_sacrifice",
		"accent": "#ff8d63",
	},
	"channel_quickcast": {
		"title": "预演快启",
		"short": "首张引导抽 1 并 +1 意志",
		"description": "每场战斗第一次打出引导牌后，立刻抽 1 并获得 1 点意志。",
		"archetype": "will_burst",
		"accent": "#7bd9d2",
	},
	"echo_guard_lattice": {
		"title": "回响护格",
		"short": "获得回响时追加护盾",
		"description": "每次获得回响时，立刻获得 5 点护盾。",
		"archetype": "resonance_combo",
		"accent": "#b8f1ff",
	},
}

const EXUSIAI_TUNES: Dictionary = {
	"ex_burst_entry_mag": {
		"title": "爆发备弹",
		"short": "进入爆发时恢复 1 发弹药",
		"description": "每次进入爆发时，立刻恢复 1 发弹药，让爆发回合更容易接起连射。",
		"archetype": "burst_window",
		"accent": "#ffb07a",
	},
	"ex_support_shot_link": {
		"title": "火线接力",
		"short": "首张支援后下一张射击牌 +2",
		"description": "每回合第一张支援牌结算后，下一张射击牌额外造成 2 点伤害。",
		"archetype": "support_chain",
		"accent": "#7dd6ff",
	},
	"ex_mark_trace_draw": {
		"title": "锁点追迹",
		"short": "本回合首次施加标记抽 1",
		"description": "每回合第一次施加标记后抽 1，让标记链更容易持续。",
		"archetype": "mark_control",
		"accent": "#d99fff",
	},
	"ex_reload_guard_screen": {
		"title": "掩体补弹",
		"short": "恢复弹药时获得 4 护盾",
		"description": "每次恢复弹药时，立刻获得 4 点护盾，适合边补弹边站场。",
		"archetype": "reload_tempo",
		"accent": "#96e7ff",
	},
	"ex_marked_shot_discount": {
		"title": "锁定压缩",
		"short": "场上有标记时首张射击牌 -1 费",
		"description": "若场上任一敌人带有标记，本回合第一张射击牌费用 -1。",
		"archetype": "mark_control",
		"accent": "#ff8eab",
	},
	"ex_first_refill_draw": {
		"title": "补弹火花",
		"short": "本战首次恢复弹药抽 1 并 +1 弹药",
		"description": "每场战斗第一次恢复弹药时，额外抽 1，并再恢复 1 发弹药。",
		"archetype": "reload_tempo",
		"accent": "#ffd07d",
	},
}

const DEFAULT_REWIRES: Dictionary = {
	"rewire_arts_bonus": {
		"title": "重构：每回合第一张术式牌 +2 伤害",
		"description": "每回合第一张术式牌额外获得 +2 伤害，适合稳定补输出。",
		"done": "已选择临时战术：每回合第一张术式牌 +2 伤害。",
		"shop_title": "重构：术式增幅",
		"shop_desc": "每回合第一张术式牌额外获得 +2 伤害，适合稳定补输出。",
		"shop_done": "已接入重构：每回合第一张术式 +2。",
		"accent": "#ffc47f",
	},
	"rewire_support_draw": {
		"title": "重构：每战第一次支援抽 2",
		"description": "每场战斗第一次打出支援牌时，额外抽 2 张牌。",
		"done": "已选择临时战术：每战第一次支援抽 2。",
		"shop_title": "重构：支援抽牌",
		"shop_desc": "每场战斗第一次打出支援牌时，额外抽 2 张牌。",
		"shop_done": "已接入重构：每战第一次支援抽 2。",
		"accent": "#8fe7ff",
	},
	"rewire_overload_minus_one": {
		"title": "重构：过载结算伤害 -1",
		"description": "过载结算时受到的伤害减少 1 点，适合高压透支流。",
		"done": "已选择临时战术：过载结算伤害 -1。",
		"shop_title": "重构：过载缓冲",
		"shop_desc": "过载结算时受到的伤害减少 1 点，适合高压透支流。",
		"shop_done": "已接入重构：过载结算伤害 -1。",
		"accent": "#ff9b77",
	},
}

const EXUSIAI_REWIRES: Dictionary = {
	"ex_rewire_first_shot_bonus": {
		"title": "重构：每回合第一张射击牌 +2 伤害",
		"description": "每回合第一张射击牌额外造成 2 点伤害，适合稳定开火。",
		"done": "已选择临时战术：每回合第一张射击牌 +2 伤害。",
		"shop_title": "重构：首轮点射",
		"shop_desc": "每回合第一张射击牌额外造成 2 点伤害，适合稳定开火。",
		"shop_done": "已接入重构：每回合第一张射击牌 +2。",
		"accent": "#ffb26f",
	},
	"ex_rewire_reload_draw": {
		"title": "重构：每战首次补弹抽 2",
		"description": "每场战斗第一次恢复弹药时，额外抽 2 张牌，让装填回合不断档。",
		"done": "已选择临时战术：每战首次补弹抽 2。",
		"shop_title": "重构：装填节拍",
		"shop_desc": "每场战斗第一次恢复弹药时，额外抽 2 张牌，让装填回合不断档。",
		"shop_done": "已接入重构：每战首次补弹抽 2。",
		"accent": "#8fe6ff",
	},
	"ex_rewire_burst_ammo": {
		"title": "重构：爆发中首张射击牌返还 1 发弹药",
		"description": "每回合第一次在爆发状态下打出射击牌时，返还 1 发弹药。",
		"done": "已选择临时战术：爆发中首张射击牌返还 1 发弹药。",
		"shop_title": "重构：爆发补仓",
		"shop_desc": "每回合第一次在爆发状态下打出射击牌时，返还 1 发弹药。",
		"shop_done": "已接入重构：爆发中首张射击牌返还 1 发弹药。",
		"accent": "#ff8f8f",
	},
}

const CHARACTER_TUNE_POOLS: Dictionary = {
	"exusiai": EXUSIAI_TUNES,
}

const CHARACTER_REWIRE_POOLS: Dictionary = {
	"exusiai": EXUSIAI_REWIRES,
}

static func all_tunes() -> Dictionary:
	var result: Dictionary = DEFAULT_TUNES.duplicate(true)
	for tune_pool in CHARACTER_TUNE_POOLS.values():
		var typed_pool: Dictionary = tune_pool as Dictionary
		for tune_id in typed_pool.keys():
			result[String(tune_id)] = (typed_pool.get(tune_id, {}) as Dictionary).duplicate(true)
	return result

static func data(tune_id: String) -> Dictionary:
	return (all_tunes().get(tune_id, {}) as Dictionary).duplicate(true)

static func title(tune_id: String) -> String:
	return String(data(tune_id).get("title", tune_id))

static func short_text(tune_id: String) -> String:
	return String(data(tune_id).get("short", ""))

static func description(tune_id: String) -> String:
	return String(data(tune_id).get("description", ""))

static func archetype(tune_id: String) -> String:
	return String(data(tune_id).get("archetype", "neutral"))

static func accent(tune_id: String) -> Color:
	return Color(String(data(tune_id).get("accent", "#ffffff")))

static func available_tune_ids(excluded: Array[String] = []) -> Array[String]:
	return available_tune_ids_for_character("", excluded)

static func available_tune_ids_for_character(character_id: String, excluded: Array[String] = []) -> Array[String]:
	var result: Array[String] = []
	var tune_pool: Dictionary = _tune_pool_for_character(character_id)
	var tune_ids: Array[String] = []
	for tune_id in tune_pool.keys():
		tune_ids.append(String(tune_id))
	tune_ids.sort()
	for tune_id in tune_ids:
		if excluded.has(tune_id):
			continue
		result.append(tune_id)
	return result

static func offer_tunes(seed_value: int, count: int = 3, excluded: Array[String] = []) -> Array[String]:
	return offer_tunes_for_character("", seed_value, count, excluded)

static func offer_tunes_for_character(character_id: String, seed_value: int, count: int = 3, excluded: Array[String] = []) -> Array[String]:
	var available: Array[String] = available_tune_ids_for_character(character_id, excluded)
	if available.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else 1
	var result: Array[String] = []
	while result.size() < count and not available.is_empty():
		var index: int = rng.randi_range(0, available.size() - 1)
		result.append(available[index])
		available.remove_at(index)
	return result

static func rewire_entries(character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rewire_pool: Dictionary = _rewire_pool_for_character(character_id)
	var rewire_ids: Array[String] = []
	for rewire_id in rewire_pool.keys():
		rewire_ids.append(String(rewire_id))
	rewire_ids.sort()
	for rewire_id in rewire_ids:
		var entry: Dictionary = (rewire_pool.get(rewire_id, {}) as Dictionary).duplicate(true)
		entry["id"] = rewire_id
		result.append(entry)
	return result

static func rewire_data(rewire_id: String, character_id: String = "") -> Dictionary:
	var rewire_pool: Dictionary = _rewire_pool_for_character(character_id)
	if rewire_pool.has(rewire_id):
		return (rewire_pool.get(rewire_id, {}) as Dictionary).duplicate(true)
	for pool in CHARACTER_REWIRE_POOLS.values():
		var typed_pool: Dictionary = pool as Dictionary
		if typed_pool.has(rewire_id):
			return (typed_pool.get(rewire_id, {}) as Dictionary).duplicate(true)
	return (DEFAULT_REWIRES.get(rewire_id, {}) as Dictionary).duplicate(true)

static func _tune_pool_for_character(character_id: String) -> Dictionary:
	if CHARACTER_TUNE_POOLS.has(character_id):
		return (CHARACTER_TUNE_POOLS.get(character_id, {}) as Dictionary)
	return DEFAULT_TUNES

static func _rewire_pool_for_character(character_id: String) -> Dictionary:
	if CHARACTER_REWIRE_POOLS.has(character_id):
		return (CHARACTER_REWIRE_POOLS.get(character_id, {}) as Dictionary)
	return DEFAULT_REWIRES
