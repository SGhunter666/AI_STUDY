extends Node

signal language_changed(language_code: String)

const LANG_ZH := "zh"
const LANG_EN := "en"
# 文案数据已迁移至 data/localization/strings.json（由 dump_localization_to_json.gd 导出）
# 修改文案请直接编辑该 JSON；新增 key 时 zh/en 需同时提供
const STRINGS_PATH := "res://data/localization/strings.json"

var current_language: String = LANG_ZH

var ui_text: Dictionary = {}
var node_type_names: Dictionary = {}
var floor_names: Dictionary = {}
var node_descriptions: Dictionary = {}
var card_text: Dictionary = {}
var module_text: Dictionary = {}
var charm_text: Dictionary = {}
var enemy_text: Dictionary = {}
var intent_labels: Dictionary = {}
var event_text: Dictionary = {}
var event_result_text: Dictionary = {}
var exusiai_event_text: Dictionary = {}
var exusiai_event_option_text: Dictionary = {}
var exusiai_event_result_text: Dictionary = {}
var character_profiles: Dictionary = {}
var tune_text: Dictionary = {}
# 反查索引：事件选项/结果表与意图表以英文为键，运行时传入的是 .tres 中文原文，
# 加载时构建 zh -> en 反查表，保证英文模式能真正命中
var _intent_label_zh_to_entry: Dictionary = {}
var _event_option_zh_to_en: Dictionary = {}
var _event_result_zh_to_en: Dictionary = {}

func _init() -> void:
	_load_strings()

func _load_strings() -> void:
	if not FileAccess.file_exists(STRINGS_PATH):
		push_error("缺少本地化数据文件: " + STRINGS_PATH)
		return
	var file: FileAccess = FileAccess.open(STRINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取本地化数据文件: " + STRINGS_PATH)
		return
	var txt: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		push_error("本地化数据解析失败: " + STRINGS_PATH)
		return
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("本地化数据根节点类型错误: " + STRINGS_PATH)
		return
	var data: Dictionary = parsed
	ui_text = data.get("ui_text", {})
	node_type_names = data.get("node_type_names", {})
	floor_names = _restore_int_keys(data.get("floor_names", {}))
	node_descriptions = data.get("node_descriptions", {})
	card_text = data.get("card_text", {})
	module_text = data.get("module_text", {})
	charm_text = data.get("charm_text", {})
	enemy_text = data.get("enemy_text", {})
	intent_labels = data.get("intent_labels", {})
	event_text = data.get("event_text", {})
	event_result_text = data.get("event_result_text", {})
	exusiai_event_text = data.get("exusiai_event_text", {})
	exusiai_event_option_text = data.get("exusiai_event_option_text", {})
	exusiai_event_result_text = data.get("exusiai_event_result_text", {})
	character_profiles = data.get("character_profiles", {})
	tune_text = data.get("tune_text", {})
	_build_reverse_indices()

# 构建中文原文 -> 英文文案的反查索引（intent_labels 为 {en: {zh, en}} 结构，事件表为 {en: zh} 结构）
func _build_reverse_indices() -> void:
	_intent_label_zh_to_entry.clear()
	for key in intent_labels:
		var entry: Dictionary = intent_labels[key]
		var zh_value: String = String(entry.get("zh", ""))
		if not zh_value.is_empty():
			_intent_label_zh_to_entry[zh_value] = entry
	_event_option_zh_to_en.clear()
	for key in exusiai_event_option_text:
		var zh_value: String = String(exusiai_event_option_text[key])
		if not zh_value.is_empty():
			_event_option_zh_to_en[zh_value] = String(key)
	_event_result_zh_to_en.clear()
	for table in [event_result_text, exusiai_event_result_text]:
		for key in table:
			var zh_value: String = String(table[key])
			if not zh_value.is_empty():
				_event_result_zh_to_en[zh_value] = String(key)

# JSON 键只能是字符串；floor_names 原本用整数键，这里还原
func _restore_int_keys(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return source
	var all_numeric: bool = true
	for key in source.keys():
		if not String(key).is_valid_int():
			all_numeric = false
			break
	if not all_numeric:
		return source
	var restored: Dictionary = {}
	for key in source.keys():
		restored[int(String(key))] = source[key]
	return restored

func _ready() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	current_language = String(profile.get("language", LANG_ZH))

func set_language(language_code: String) -> void:
	current_language = language_code
	var profile: Dictionary = SaveManager.load_profile()
	profile["language"] = current_language
	SaveManager.save_profile(profile)
	language_changed.emit(current_language)

func text(key: String, format_args: Array = []) -> String:
	var entry: Dictionary = ui_text.get(key, {})
	var raw: String = String(entry.get(current_language, key))
	var resolved: String = raw % format_args if not format_args.is_empty() else raw
	return resolved.replace("%%", "%")

func character_name(character_id: String, fallback: String = "") -> String:
	var entry: Dictionary = character_profiles.get(character_id, {})
	if entry.is_empty():
		return fallback if not fallback.is_empty() else character_id.capitalize()
	return String(entry.get("zh_name" if current_language == LANG_ZH else "en_name", fallback))

func character_header(character_id: String, fallback: String = "") -> String:
	var entry: Dictionary = character_profiles.get(character_id, {})
	if entry.is_empty():
		return fallback if not fallback.is_empty() else character_name(character_id, character_id)
	return String(entry.get("zh_header" if current_language == LANG_ZH else "en_header", fallback))

func character_stats(character_id: String, fallback: String = "") -> String:
	var entry: Dictionary = character_profiles.get(character_id, {})
	if entry.is_empty():
		return fallback
	return String(entry.get("zh_stats" if current_language == LANG_ZH else "en_stats", fallback))

func character_intro(character_id: String, fallback: String = "") -> String:
	var entry: Dictionary = character_profiles.get(character_id, {})
	if entry.is_empty():
		return fallback
	return String(entry.get("zh_intro" if current_language == LANG_ZH else "en_intro", fallback))

func character_mechanic(character_id: String, fallback: String = "") -> String:
	var entry: Dictionary = character_profiles.get(character_id, {})
	if entry.is_empty():
		return fallback
	return String(entry.get("zh_mechanic" if current_language == LANG_ZH else "en_mechanic", fallback))

func active_character_name() -> String:
	if RunManager.character == null:
		return character_name("amiya", "Amiya")
	return character_name(RunManager.character.id, RunManager.character.display_name)

func active_character_id() -> String:
	if RunManager.character == null:
		return "amiya"
	return String(RunManager.character.id)

func card_name(card: CardData) -> String:
	if card == null:
		return ""
	if card_text.has(card.id):
		var entry: Dictionary = card_text[card.id]
		var lang_key: String = "zh_name" if current_language == LANG_ZH else "en_name"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return localized
	return card.display_name

func card_description(card: CardData) -> String:
	if card == null:
		return ""
	if card_text.has(card.id):
		var entry: Dictionary = card_text[card.id]
		var lang_key: String = "zh_desc" if current_language == LANG_ZH else "en_desc"
		var localized_description: String = String(entry.get(lang_key, "")).strip_edges()
		if not localized_description.is_empty():
			return localized_description
	var resource_description: String = String(card.description).strip_edges()
	if not resource_description.is_empty():
		return resource_description
	return _fallback_card_description(card)

func _fallback_card_description(card: CardData) -> String:
	if card == null:
		return ""
	var parts: Array[String] = []
	for effect in card.effects:
		if effect == null:
			continue
		var text_value: String = _effect_summary(effect)
		if not text_value.is_empty():
			parts.append(text_value)
	for effect in card.conditional_effects:
		if effect == null:
			continue
		var conditional_text: String = _effect_summary(effect)
		if not conditional_text.is_empty():
			parts.append(conditional_text)
	return "。".join(parts)

func _effect_summary(effect: EffectData) -> String:
	match effect.effect_type:
		"damage":
			return text("card.effect_damage", [effect.amount])
		"block":
			return text("card.effect_block", [effect.amount])
		"draw":
			return text("card.effect_draw", [effect.amount])
		"heal":
			return text("card.effect_heal", [effect.amount])
		"gain_counter":
			return text("card.effect_gain_counter", [effect.amount])
		"gain_radiance":
			return text("card.effect_gain_radiance", [effect.amount])
	return ""

func module_name(module_data: ModuleData) -> String:
	if module_data == null:
		return ""
	if module_text.has(module_data.id):
		var entry: Dictionary = module_text[module_data.id]
		var lang_key: String = "zh_name" if current_language == LANG_ZH else "en_name"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return localized
	return module_data.display_name

func module_description(module_data: ModuleData) -> String:
	if module_data == null:
		return ""
	if module_text.has(module_data.id):
		var entry: Dictionary = module_text[module_data.id]
		var lang_key: String = "zh_desc" if current_language == LANG_ZH else "en_desc"
		var localized: String = String(entry.get(lang_key, "")).strip_edges()
		if not localized.is_empty():
			return localized
	return module_data.description

func charm_name(charm_data: CharmData) -> String:
	if charm_data == null:
		return ""
	if charm_text.has(charm_data.id):
		var entry: Dictionary = charm_text[charm_data.id]
		var lang_key: String = "zh_name" if current_language == LANG_ZH else "en_name"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return localized
	return charm_data.display_name

func charm_name_by_id(charm_id: String) -> String:
	if charm_text.has(charm_id):
		var entry: Dictionary = charm_text[charm_id]
		var lang_key: String = "zh_name" if current_language == LANG_ZH else "en_name"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return localized
	var charm_db: Dictionary = Util.load_charm_db()
	if charm_db.has(charm_id):
		return (charm_db[charm_id] as CharmData).display_name
	return charm_id

func charm_description(charm_data: CharmData) -> String:
	if charm_data == null:
		return ""
	if charm_text.has(charm_data.id):
		var entry: Dictionary = charm_text[charm_data.id]
		var lang_key: String = "zh_desc" if current_language == LANG_ZH else "en_desc"
		var localized: String = String(entry.get(lang_key, "")).strip_edges()
		if not localized.is_empty():
			return localized
	return charm_data.description

func rarity_name(rarity: String) -> String:
	match rarity:
		"Common":
			return text("codex.rarity_common")
		"Uncommon", "Elite":
			return text("codex.rarity_elite")
		"Rare", "Legendary":
			return text("codex.rarity_rare")
		"Basic", "Starter":
			return text("codex.rarity_basic")
	return rarity

func enemy_tag_name(tag: String) -> String:
	match tag:
		"Reunion":
			return text("codex.tag_reunion")
		"Ranged":
			return text("codex.tag_ranged")
		"Arts":
			return text("codex.tag_arts")
		"Guard":
			return text("codex.tag_guard")
		"Boss":
			return text("codex.tag_boss")
		"Elite":
			return text("codex.tag_elite")
		"Siege":
			return text("codex.tag_siege")
		"Infected":
			return text("codex.tag_infected")
		"Drone":
			return text("codex.tag_drone")
		"Originium":
			return text("codex.tag_originium")
		"Slug":
			return text("codex.tag_slug")
		"Burn":
			return text("codex.tag_burn")
		"Bomb":
			return text("codex.tag_bomb")
		"Support":
			return text("codex.tag_support")
		"Trick":
			return text("codex.tag_trick")
		"Frost":
			return text("codex.tag_frost")
		"Acid":
			return text("codex.tag_acid")
		"Hidden":
			return text("codex.tag_hidden")
	return tag

func ai_profile_name(ai_profile: String) -> String:
	match ai_profile:
		"basic":
			return text("codex.ai_basic")
		"w_boss":
			return text("codex.ai_w_boss")
		"tank":
			return text("codex.ai_tank")
		"debuffer":
			return text("codex.ai_debuffer")
		"caster":
			return text("codex.ai_caster")
	return ai_profile

func enemy_name(enemy_id: String, fallback: String) -> String:
	if enemy_text.has(enemy_id):
		var entry: Dictionary = enemy_text[enemy_id]
		var lang_key: String = "zh_name" if current_language == LANG_ZH else "en_name"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return localized
	return fallback

func intent_label(label: String) -> String:
	# 调用方传入的是中文意图标签（如"攻击 6"），通过 zh -> entry 反查命中
	var entry: Variant = _intent_label_zh_to_entry.get(label, null)
	if entry == null:
		return label
	return String((entry as Dictionary).get(current_language, label))

func _event_entry_for(event_id: String) -> Dictionary:
	# 能天使运行时优先使用其专属事件文案，其余角色使用通用事件文案
	if active_character_id() == "exusiai" and exusiai_event_text.has(event_id):
		return exusiai_event_text[event_id]
	return event_text.get(event_id, {})

func event_title(event_id: String, fallback: String) -> String:
	var entry: Dictionary = _event_entry_for(event_id)
	if not entry.is_empty():
		var lang_key: String = "zh_title" if current_language == LANG_ZH else "en_title"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			# 中文模式保留角色词汇替换（能天使运行时 共振->标记 等），与修复前行为一致
			return event_text_for_character(localized, active_character_id()) if current_language == LANG_ZH else localized
	return event_text_for_character(fallback, active_character_id())

func event_body(event_id: String, fallback: String) -> String:
	var entry: Dictionary = _event_entry_for(event_id)
	if not entry.is_empty():
		var lang_key: String = "zh_body" if current_language == LANG_ZH else "en_body"
		var localized: String = String(entry.get(lang_key, ""))
		if not localized.is_empty():
			return event_text_for_character(localized, active_character_id()) if current_language == LANG_ZH else localized
	return event_text_for_character(fallback, active_character_id())

func event_option_label(_event_id: String, fallback: String) -> String:
	# 英文模式按 .tres 中文原文反查英文选项；中文模式保留角色词汇替换
	if current_language == LANG_EN and _event_option_zh_to_en.has(fallback):
		return String(_event_option_zh_to_en[fallback])
	return event_text_for_character(fallback, active_character_id())

func event_result(result_text: String) -> String:
	return event_result_for_event("", result_text)

func event_result_for_event(_event_id: String, result_text: String) -> String:
	# 英文模式按 .tres 中文原文反查英文结果；中文模式保留角色词汇替换
	if current_language == LANG_EN and _event_result_zh_to_en.has(result_text):
		return String(_event_result_zh_to_en[result_text])
	return event_text_for_character(result_text, active_character_id())

func event_text_for_character(raw_text: String, character_id: String) -> String:
	var output: String = raw_text
	match character_id:
		"exusiai":
			output = output.replace("共振", "标记")
			output = output.replace("术式", "火力")
			output = output.replace("意志", "弹药节奏")
	return output

# 调律/重构文案访问器：按 id 查 tune_text 分组，缺省回退到调用方传入的原文
func tune_title(tune_id: String, fallback: String = "") -> String:
	return _tune_field(tune_id, "title", fallback)

func tune_short(tune_id: String, fallback: String = "") -> String:
	return _tune_field(tune_id, "short", fallback)

func tune_description(tune_id: String, fallback: String = "") -> String:
	return _tune_field(tune_id, "desc", fallback)

func rewire_field(rewire_id: String, field_name: String, fallback: String = "") -> String:
	return _tune_field(rewire_id, field_name, fallback)

func _tune_field(entry_id: String, field_name: String, fallback: String) -> String:
	var entry: Dictionary = tune_text.get(entry_id, {})
	if entry.is_empty():
		return fallback
	var lang_key: String = "zh_" + field_name if current_language == LANG_ZH else "en_" + field_name
	var localized: String = String(entry.get(lang_key, ""))
	return localized if not localized.is_empty() else fallback

func node_type_name(node_type: String) -> String:
	var entry: Dictionary = node_type_names.get(node_type, {})
	return String(entry.get(current_language, node_type))

func floor_name(floor_index: int) -> String:
	var entry: Dictionary = floor_names.get(floor_index, {})
	return String(entry.get(current_language, text("map.header")))

func node_description(node_type: String) -> String:
	var entry: Dictionary = node_descriptions.get(node_type, {})
	return String(entry.get(current_language, node_type))
