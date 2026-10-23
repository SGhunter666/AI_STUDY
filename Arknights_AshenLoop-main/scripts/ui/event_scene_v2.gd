extends Control

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")

@onready var panel: PanelContainer = $Panel
@onready var header_panel: PanelContainer = $Panel/Margin/VBox/HeaderPanel
@onready var eyebrow_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Eyebrow
@onready var title_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Title
@onready var info_panel: PanelContainer = $Panel/Margin/VBox/InfoPanel
@onready var body_scroll: ScrollContainer = $Panel/Margin/VBox/InfoPanel/InfoMargin/BodyScroll
@onready var body_label: Label = $Panel/Margin/VBox/InfoPanel/InfoMargin/BodyScroll/Body
@onready var content_scroll: ScrollContainer = $Panel/Margin/VBox/ContentScroll
@onready var options_box: VBoxContainer = $Panel/Margin/VBox/ContentScroll/Options
@onready var footer_panel: PanelContainer = $Panel/Margin/VBox/FooterPanel
@onready var footer_hint_label: Label = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/FooterHint
@onready var confirm_button: Button = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/Confirm

var event_db: Dictionary = {}
var event_data: EventData
var runner: EventRunner = EventRunner.new()
var option_buttons: Array[Button] = []
var selected_option_index: int = -1

# 精致选项悬停预览（替代 Godot 内置 tooltip）
var _option_preview_overlay: Control
var _option_preview_panel: PanelContainer
var _option_preview_box: VBoxContainer
var _option_preview_tween: Tween = null
var _option_preview_version: int = 0

func _ready() -> void:
	_apply_ui_theme()
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	event_db = Util.load_event_db()
	# Confirm 按钮必须先连接：event_data 缺失的早退分支也要能返回地图，否则软锁整个 run
	confirm_button.pressed.connect(_confirm_selection)
	var node: MapNodeModel = RunManager.current_node()
	if node == null:
		SceneRouter.go_map()
		return
	event_data = event_db.get(String(node.metadata.get("event_id", "")), null)
	if event_data == null:
		eyebrow_label.text = LocalizationManager.text("event.eyebrow")
		title_label.text = LocalizationManager.text("event.empty_title")
		body_label.text = LocalizationManager.text("event.empty_body")
		footer_hint_label.text = LocalizationManager.text("event.empty_footer")
		confirm_button.text = LocalizationManager.text("event.continue")
		confirm_button.disabled = false
		return
	_apply_event_text()
	_rebuild_options()
	_build_option_preview_overlay()
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.disconnect(_on_language_changed)
	if _option_preview_tween != null:
		_option_preview_tween.kill()
		_option_preview_tween = null

func _on_language_changed(_language_code: String) -> void:
	if event_data != null:
		_apply_event_text()
	_rebuild_options()
	_refresh_footer_state()

func _apply_event_text() -> void:
	var resolved_title: String = LocalizationManager.event_title(event_data.id, event_data.title).strip_edges()
	var resolved_body: String = LocalizationManager.event_body(event_data.id, event_data.body).strip_edges()
	eyebrow_label.text = LocalizationManager.text("event.eyebrow")
	title_label.text = resolved_title if not resolved_title.is_empty() else LocalizationManager.text("event.empty_title")
	body_label.text = resolved_body if not resolved_body.is_empty() else LocalizationManager.text("event.empty_body")
	body_scroll.scroll_vertical = 0
	content_scroll.scroll_vertical = 0

func _rebuild_options() -> void:
	for child in options_box.get_children():
		child.queue_free()
	option_buttons.clear()
	if event_data == null:
		return
	selected_option_index = clamp(selected_option_index, -1, event_data.options.size() - 1)
	for index in range(event_data.options.size()):
		var option: Dictionary = event_data.options[index]
		var button: Button = Button.new()
		var option_text: String = _option_label(option)
		var preview_text: String = _option_preview(option)
		button.text = option_text if preview_text.is_empty() else "%s\n%s" % [option_text, preview_text]
		# 禁用 Godot 内置 tooltip，改用精致悬停预览面板
		button.tooltip_text = ""
		button.custom_minimum_size = Vector2(0, 94)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI_THEME_KIT.apply_stone_button(button, "paper", 22)
		button.add_theme_font_size_override("font_size", 20)
		UI_MOTION.wire_button_feedback(button, 1.02, 0.98, Color(1.0, 0.90, 0.68, 0.68), 5.0)
		button.pressed.connect(func(option_index: int = index) -> void:
			selected_option_index = option_index
			SfxManager.play_ui_click()
			_refresh_option_button_states()
			_refresh_footer_state()
		)
		# 悬停时展示精致预览（效果摘要 + 卡牌详情）
		button.mouse_entered.connect(func(opt: Dictionary = option, btn: Button = button) -> void:
			_show_option_preview(opt, btn)
		)
		button.mouse_exited.connect(func() -> void:
			_hide_option_preview()
		)
		options_box.add_child(button)
		option_buttons.append(button)
	_refresh_option_button_states()
	_refresh_footer_state()

func _refresh_option_button_states() -> void:
	for index in range(option_buttons.size()):
		var button: Button = option_buttons[index]
		if button == null:
			continue
		var selected: bool = index == selected_option_index
		UI_THEME_KIT.apply_stone_button(button, "stone" if selected else "paper", 22)
		button.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.96)

func _refresh_footer_state() -> void:
	if event_data == null:
		confirm_button.text = LocalizationManager.text("event.continue")
		confirm_button.disabled = false
		return
	if selected_option_index >= 0 and selected_option_index < event_data.options.size():
		var option: Dictionary = event_data.options[selected_option_index]
		footer_hint_label.text = LocalizationManager.text("event.selected_hint", [_option_label(option)])
		confirm_button.text = LocalizationManager.text("event.confirm")
		confirm_button.disabled = false
	else:
		footer_hint_label.text = LocalizationManager.text("event.choose_option")
		confirm_button.text = LocalizationManager.text("event.confirm")
		confirm_button.disabled = true

func _confirm_selection() -> void:
	if event_data == null:
		RunManager.complete_current_node()
		SceneRouter.go_map()
		return
	if selected_option_index < 0 or selected_option_index >= event_data.options.size():
		return
	var option: Dictionary = event_data.options[selected_option_index]
	# 记录本局已经历的事件，供地图生成去重
	RunManager.mark_event_seen(event_data.id)
	RunManager.begin_save_batch()
	var summary_entries: Array[Dictionary] = runner.apply_event_option(option)
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	var raw_reward_cards: Array = Array(_character_option_value(option, "reward_cards", []))
	var filtered_reward_cards: Array[String] = Util.normalize_character_card_choices(
		raw_reward_cards,
		character_id,
		raw_reward_cards.size(),
		RunManager.rng_seed + RunManager.current_floor * 97 + selected_option_index,
		RunManager.get_reward_bias_weights()
	)
	RunManager.set_pending_rewards({
		"type": "event_reward",
		"text": LocalizationManager.event_result_for_event(event_data.id, String(_character_option_value(option, "result", ""))),
		"card_choices": filtered_reward_cards,
		"summary_entries": summary_entries
	})
	RunManager.complete_current_node()
	RunManager.end_save_batch()
	SceneRouter.go_reward()

func _option_label(option: Dictionary) -> String:
	# 统一走 LocalizationManager：英文模式按中文原文反查英文选项，中文模式保留角色词汇替换
	var raw_label: String = String(option.get("label", ""))
	if raw_label.is_empty():
		return LocalizationManager.text("event.continue")
	return LocalizationManager.event_option_label(event_data.id if event_data != null else "", raw_label)

func _option_preview(option: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Array = Array(_character_option_value(option, "effects", []))
	for effect in effects:
		var text_value: String = _effect_preview(effect)
		if not text_value.is_empty() and not parts.has(text_value):
			parts.append(text_value)
	var reward_cards: Array = Array(_character_option_value(option, "reward_cards", []))
	if not reward_cards.is_empty():
		parts.append(LocalizationManager.text("event.preview_reward_cards", [reward_cards.size()]))
	if parts.is_empty():
		return ""
	if parts.size() > 4:
		parts = parts.slice(0, 4)
		parts.append(LocalizationManager.text("event.preview_more"))
	return LocalizationManager.text("event.preview_choose_prefix") + " / ".join(parts)

func _effect_preview(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"gain_gold", "add_gold":
			return LocalizationManager.text("event.preview_gold_gain", [int(effect.get("amount", 0))])
		"lose_gold":
			return LocalizationManager.text("event.preview_gold_lose", [int(effect.get("amount", 0))])
		"lose_hp":
			return LocalizationManager.text("event.preview_hp_lose", [int(effect.get("amount", 0))])
		"heal":
			return LocalizationManager.text("event.preview_heal", [int(effect.get("amount", 0))])
		"heal_percent":
			return LocalizationManager.text("event.preview_heal_percent", [int(effect.get("amount", 0))])
		"add_card", "add_card_reward":
			var card_id: String = _safe_card_id(String(_character_effect_value(effect, "card_id", "")))
			return LocalizationManager.text("event.preview_add_card", [_card_name(card_id)]) if not card_id.is_empty() else ""
		"remove_card", "remove_selected_card":
			return LocalizationManager.text("event.preview_remove_card")
		"upgrade_random_card", "upgrade_selected_card":
			return LocalizationManager.text("event.preview_upgrade_card")
		"add_module":
			var module_id: String = _safe_module_id(String(_character_effect_value(effect, "module_id", "")))
			return LocalizationManager.text("event.preview_add_module", [_module_name(module_id)]) if not module_id.is_empty() else ""
		"add_charm":
			var charm_id: String = _safe_charm_id(String(_character_effect_value(effect, "charm_id", "")))
			return LocalizationManager.text("event.preview_add_charm", [_charm_name(charm_id)]) if not charm_id.is_empty() else ""
		"set_flag", "gain_story_flag", "apply_run_modifier":
			return _flag_preview(String(_character_effect_value(effect, "flag", _character_effect_value(effect, "modifier_id", ""))))
	return ""

func _flag_preview(flag_name: String) -> String:
	match flag_name:
		"next_floor_fewer_events":
			return LocalizationManager.text("event.flag_next_floor_fewer_events")
		"soft_start_next_battle":
			return LocalizationManager.text("event.flag_soft_start_next_battle")
		"doctor_ideal":
			return LocalizationManager.text("event.flag_doctor_ideal")
		"doctor_efficiency":
			return LocalizationManager.text("event.flag_doctor_efficiency")
		"doctor_burden":
			return LocalizationManager.text("event.flag_doctor_burden")
		"accept_burden_1", "accept_burden_2", "accept_burden_3":
			return LocalizationManager.text("event.flag_accept_burden")
		"floor_first_support_double":
			return LocalizationManager.text("event.flag_floor_first_support_double")
		"double_next_reward":
			return LocalizationManager.text("event.flag_double_next_reward")
		"next_battle_enemy_strength":
			return LocalizationManager.text("event.flag_next_battle_enemy_strength")
		"preview_two_nodes":
			return LocalizationManager.text("event.flag_preview_two_nodes")
		"next_battle_start_will_3":
			return LocalizationManager.text("event.flag_next_battle_start_will_3")
		"next_battle_start_energy_1":
			return LocalizationManager.text("event.flag_next_battle_start_energy_1")
		"next_battle_start_ammo_2":
			return LocalizationManager.text("event.flag_next_battle_start_ammo_2")
		"channel_upgrade_credit":
			return LocalizationManager.text("event.flag_channel_upgrade_credit")
		"legendary_offer_next_reward":
			return LocalizationManager.text("event.flag_legendary_offer_next_reward")
		"double_elite_reward":
			return LocalizationManager.text("event.flag_double_elite_reward")
		"support_upgrade_credit":
			return LocalizationManager.text("event.flag_support_upgrade_credit")
		"tune_resonance_apply":
			return LocalizationManager.text("event.flag_tune_resonance_apply")
		"tune_cost_pending":
			return LocalizationManager.text("event.flag_tune_cost_pending")
		"avoided_fissure":
			return LocalizationManager.text("event.flag_avoided_fissure")
		"energy_potion_2":
			return LocalizationManager.text("event.flag_energy_potion_2")
		"rest_upgrade_credit":
			return LocalizationManager.text("event.flag_rest_upgrade_credit")
		"evacuation_kind":
			return LocalizationManager.text("event.flag_evacuation_kind")
		"evacuation_efficient":
			return LocalizationManager.text("event.flag_evacuation_efficient")
		"evacuation_split":
			return LocalizationManager.text("event.flag_evacuation_split")
		"w_intents_clear":
			return LocalizationManager.text("event.flag_w_intents_clear")
		"lost_hidden_progress":
			return LocalizationManager.text("event.flag_lost_hidden_progress")
	return LocalizationManager.text("event.flag_generic")

func _card_name(card_id: String) -> String:
	var card: CardData = Util.load_card_db().get(card_id, null) as CardData
	return LocalizationManager.card_name(card) if card != null else card_id

func _module_name(module_id: String) -> String:
	var module_data: ModuleData = Util.load_module_db().get(module_id, null) as ModuleData
	return LocalizationManager.module_name(module_data) if module_data != null else module_id

func _charm_name(charm_id: String) -> String:
	var charm_data: CharmData = Util.load_charm_db().get(charm_id, null) as CharmData
	if charm_data != null:
		return LocalizationManager.charm_name(charm_data)
	return charm_id

func _current_character_id() -> String:
	return RunManager.character.id if RunManager.character != null else "amiya"

func _safe_card_id(card_id: String) -> String:
	if card_id.is_empty() or Util.is_card_available_to_character(card_id, _current_character_id()):
		return card_id
	var replacements: Array[String] = Util.normalize_character_card_choices(
		[card_id],
		_current_character_id(),
		1,
		RunManager.rng_seed + RunManager.current_floor * 131 + card_id.hash(),
		RunManager.get_reward_bias_weights()
	)
	return replacements[0] if not replacements.is_empty() else ""

func _safe_module_id(module_id: String) -> String:
	if module_id.is_empty() or Util.is_module_available_to_character(module_id, _current_character_id()):
		return module_id
	var replacements: Array[String] = Util.normalize_character_module_choices(
		[module_id],
		_current_character_id(),
		1,
		RunManager.rng_seed + RunManager.current_floor * 163 + module_id.hash()
	)
	return replacements[0] if not replacements.is_empty() else ""

func _safe_charm_id(charm_id: String) -> String:
	if charm_id.is_empty() or Util.is_charm_available_to_character(charm_id, _current_character_id()):
		return charm_id
	var replacements: Array[String] = Util.normalize_character_charm_choices(
		[charm_id],
		_current_character_id(),
		1,
		RunManager.rng_seed + RunManager.current_floor * 181 + charm_id.hash()
	)
	return replacements[0] if not replacements.is_empty() else ""

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_paper_panel(panel)
	UI_THEME_KIT.apply_glass_panel(header_panel)
	UI_THEME_KIT.apply_page_section_panel(info_panel)
	UI_THEME_KIT.apply_page_section_panel(footer_panel)
	UI_THEME_KIT.apply_heading(eyebrow_label, 15, Color(0.95, 0.86, 0.58, 0.96), Color(0.07, 0.06, 0.05, 0.66))
	UI_THEME_KIT.apply_glass_heading(title_label, 34)
	UI_THEME_KIT.apply_glass_body(body_label, 20)
	UI_THEME_KIT.apply_glass_hint(footer_hint_label, 18)
	UI_THEME_KIT.apply_stone_button(confirm_button, "paper", 22)
	UI_MOTION.wire_button_feedback(confirm_button, 1.02, 0.98, Color(1.0, 0.90, 0.68, 0.68), 5.0)

func _play_intro_animation() -> void:
	UI_MOTION.reveal(panel, 0.04, Vector2(0, 24), 0.30, Vector2(0.99, 0.99))
	var delay: float = 0.12
	for child in options_box.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		UI_MOTION.reveal(control, delay, Vector2(-18, 0), 0.24, Vector2(0.99, 0.99))
		delay += 0.05
	UI_MOTION.reveal(confirm_button, 0.16, Vector2(0, 14), 0.22, Vector2(0.99, 0.99))

func _character_option_value(option: Dictionary, key: String, default_value: Variant = null) -> Variant:
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	var direct_key: String = "%s_%s" % [key, character_id]
	if option.has(direct_key):
		return option.get(direct_key, default_value)
	var mapping_key: String = "%s_by_character" % key
	if option.has(mapping_key):
		var mapping: Dictionary = option.get(mapping_key, {})
		if mapping.has(character_id):
			return mapping[character_id]
	return option.get(key, default_value)

func _character_effect_value(effect: Dictionary, key: String, default_value: Variant = null) -> Variant:
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	var direct_key: String = "%s_%s" % [key, character_id]
	if effect.has(direct_key):
		return effect.get(direct_key, default_value)
	var mapping_key: String = "%s_by_character" % key
	if effect.has(mapping_key):
		var mapping: Dictionary = effect.get(mapping_key, {})
		if mapping.has(character_id):
			return mapping[character_id]
	return effect.get(key, default_value)


# ===== 精致选项悬停预览 =====

func _build_option_preview_overlay() -> void:
	_option_preview_overlay = Control.new()
	_option_preview_overlay.layout_mode = 1
	_option_preview_overlay.anchor_left = 0.0
	_option_preview_overlay.anchor_top = 0.0
	_option_preview_overlay.anchor_right = 1.0
	_option_preview_overlay.anchor_bottom = 1.0
	_option_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_option_preview_overlay.z_index = 400
	_option_preview_overlay.visible = false
	add_child(_option_preview_overlay)

	_option_preview_panel = PanelContainer.new()
	_option_preview_panel.layout_mode = 1
	_option_preview_panel.anchor_left = 0.0
	_option_preview_panel.anchor_top = 0.0
	_option_preview_panel.anchor_right = 0.0
	_option_preview_panel.anchor_bottom = 0.0
	_option_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_option_preview_panel.visible = false
	_option_preview_overlay.add_child(_option_preview_panel)
	UI_THEME_KIT.apply_glass_panel_blurred(_option_preview_panel, 2.4)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_option_preview_panel.add_child(margin)

	_option_preview_box = VBoxContainer.new()
	_option_preview_box.layout_mode = 2
	_option_preview_box.add_theme_constant_override("separation", 10)
	margin.add_child(_option_preview_box)


func _show_option_preview(option: Dictionary, button: Button) -> void:
	if _option_preview_panel == null or not is_inside_tree():
		return
	if button == null or not is_instance_valid(button):
		return
	_option_preview_version += 1
	var version: int = _option_preview_version
	# 立即 kill 旧 tween，防止 _hide_preview 的淡出回调在 await 期间覆盖 visible
	if _option_preview_tween != null:
		_option_preview_tween.kill()
		_option_preview_tween = null

	# 清空旧内容
	for child in _option_preview_box.get_children():
		child.queue_free()

	var has_content: bool = false

	# 1. 效果摘要
	var effects: Array = Array(_character_option_value(option, "effects", []))
	var summary_parts: Array[String] = []
	for effect in effects:
		var text_value: String = _effect_preview(effect)
		if not text_value.is_empty() and not summary_parts.has(text_value):
			summary_parts.append(text_value)
	if not summary_parts.is_empty():
		var summary_label := Label.new()
		summary_label.layout_mode = 2
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.custom_minimum_size = Vector2(340, 0)
		summary_label.text = "选择后：" + " / ".join(summary_parts)
		UI_THEME_KIT.apply_glass_body(summary_label, 17)
		summary_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.58, 0.96))
		_option_preview_box.add_child(summary_label)
		has_content = true

	# 2. 卡牌预览（reward_cards 可选池 + add_card 必定获得）
	var reward_cards: Array = Array(_character_option_value(option, "reward_cards", []))
	var add_card_ids: Array[String] = []
	for effect in effects:
		if String(effect.get("type", "")) == "add_card" or String(effect.get("type", "")) == "add_card_reward":
			var cid: String = _safe_card_id(String(_character_effect_value(effect, "card_id", "")))
			if not cid.is_empty() and not add_card_ids.has(cid):
				add_card_ids.append(cid)

	if not reward_cards.is_empty():
		has_content = true
		_add_section_title(LocalizationManager.text("event.preview_reward_cards"))
		for card_id in reward_cards:
			var card: CardData = Util.load_card_db().get(String(card_id), null) as CardData
			if card != null:
				_add_card_entry(card, true)

	if not add_card_ids.is_empty():
		has_content = true
		_add_section_title(LocalizationManager.text("event.preview_add_card"))
		for card_id in add_card_ids:
			var card: CardData = Util.load_card_db().get(card_id, null) as CardData
			if card != null:
				_add_card_entry(card, false)

	# 模块预览（add_module 效果）
	var add_module_ids: Array[String] = []
	for effect in effects:
		if String(effect.get("type", "")) == "add_module":
			var mid: String = _safe_module_id(String(_character_effect_value(effect, "module_id", "")))
			if not mid.is_empty() and not add_module_ids.has(mid):
				add_module_ids.append(mid)
	if not add_module_ids.is_empty():
		has_content = true
		_add_section_title(LocalizationManager.text("event.preview_add_module"))
		for module_id in add_module_ids:
			var module_data: ModuleData = Util.load_module_db().get(module_id, null) as ModuleData
			if module_data != null:
				_add_module_entry(module_data)

	# 护符预览（add_charm 效果）
	var add_charm_ids: Array[String] = []
	for effect in effects:
		if String(effect.get("type", "")) == "add_charm":
			var cid: String = _safe_charm_id(String(_character_effect_value(effect, "charm_id", "")))
			if not cid.is_empty() and not add_charm_ids.has(cid):
				add_charm_ids.append(cid)
	if not add_charm_ids.is_empty():
		has_content = true
		_add_section_title(LocalizationManager.text("event.preview_add_charm"))
		for charm_id in add_charm_ids:
			var charm_data: CharmData = Util.load_charm_db().get(charm_id, null) as CharmData
			if charm_data != null:
				_add_charm_entry(charm_data)

	# 3. 结果文本
	var result_text: String = LocalizationManager.event_result_for_event(
		event_data.id if event_data != null else "",
		String(_character_option_value(option, "result", ""))
	).strip_edges()
	if not result_text.is_empty():
		has_content = true
		if _option_preview_box.get_child_count() > 0:
			_add_section_divider()
		var result_label := Label.new()
		result_label.layout_mode = 2
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_label.custom_minimum_size = Vector2(340, 0)
		result_label.text = result_text
		UI_THEME_KIT.apply_glass_hint(result_label, 16)
		result_label.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90, 0.88))
		_option_preview_box.add_child(result_label)

	if not has_content:
		return

	# 定位在选项按钮右侧
	_layout_preview_near(button)
	if version != _option_preview_version:
		return
	if not is_inside_tree():
		return
	_option_preview_panel.visible = true
	_option_preview_overlay.visible = true

	# 入场动画
	if _option_preview_tween != null:
		_option_preview_tween.kill()
	_option_preview_panel.modulate.a = 0.0
	_option_preview_panel.scale = Vector2(0.94, 0.94)
	_option_preview_panel.pivot_offset = _option_preview_panel.size * 0.5
	_option_preview_tween = create_tween()
	if _option_preview_tween == null:
		return
	_option_preview_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_option_preview_tween.set_parallel(true)
	_option_preview_tween.tween_property(_option_preview_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_option_preview_tween.tween_property(_option_preview_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_option_preview() -> void:
	_option_preview_version += 1
	if _option_preview_panel == null or not _option_preview_panel.visible:
		return
	if _option_preview_tween != null:
		_option_preview_tween.kill()
	_option_preview_tween = create_tween()
	if _option_preview_tween == null:
		_option_preview_panel.visible = false
		_option_preview_overlay.visible = false
		return
	_option_preview_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_option_preview_tween.set_parallel(true)
	_option_preview_tween.tween_property(_option_preview_panel, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_option_preview_tween.tween_property(_option_preview_panel, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_option_preview_tween.finished.connect(func() -> void:
		if _option_preview_panel != null:
			_option_preview_panel.visible = false
		if _option_preview_overlay != null:
			_option_preview_overlay.visible = false
	, CONNECT_ONE_SHOT)


func _add_section_title(title_text: String) -> void:
	var label := Label.new()
	label.layout_mode = 2
	label.text = title_text
	UI_THEME_KIT.apply_glass_heading(label, 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62, 0.94))
	_option_preview_box.add_child(label)


func _add_section_divider() -> void:
	var divider := HSeparator.new()
	divider.layout_mode = 2
	_option_preview_box.add_child(divider)


func _add_card_entry(card: CardData, is_optional: bool) -> void:
	var entry_box := VBoxContainer.new()
	entry_box.layout_mode = 2
	entry_box.add_theme_constant_override("separation", 4)

	# 卡牌名称 + 稀有度
	var name_row := HBoxContainer.new()
	name_row.layout_mode = 2
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.layout_mode = 2
	name_label.text = LocalizationManager.card_name(card)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.98))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	name_label.add_theme_constant_override("outline_size", 3)
	name_row.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.layout_mode = 2
	rarity_label.text = _rarity_display(card)
	rarity_label.add_theme_font_size_override("font_size", 15)
	rarity_label.add_theme_color_override("font_color", _rarity_color(card))
	rarity_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.86))
	rarity_label.add_theme_constant_override("outline_size", 2)
	name_row.add_child(rarity_label)

	if is_optional:
		var tag_label := Label.new()
		tag_label.layout_mode = 2
		tag_label.text = LocalizationManager.text("event.preview_optional_tag")
		tag_label.add_theme_font_size_override("font_size", 14)
		tag_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.86))
		name_row.add_child(tag_label)

	entry_box.add_child(name_row)

	# 卡牌描述
	var desc_label := Label.new()
	desc_label.layout_mode = 2
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(340, 0)
	desc_label.text = LocalizationManager.card_description(card)
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 0.92))
	desc_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.80))
	desc_label.add_theme_constant_override("outline_size", 1)
	entry_box.add_child(desc_label)

	# 关键词 badges
	var keyword_specs: Array[Dictionary] = CARD_DISPLAY_FACTORY.keyword_badges_for_preview(card)
	if not keyword_specs.is_empty():
		var keywords_box := HBoxContainer.new()
		keywords_box.layout_mode = 2
		keywords_box.add_theme_constant_override("separation", 6)
		for spec in keyword_specs:
			var badge: PanelContainer = CARD_DISPLAY_FACTORY.make_keyword_badge_for_preview(spec)
			keywords_box.add_child(badge)
		entry_box.add_child(keywords_box)

	# 术语说明
	var term_lines: Array[String] = CARD_DISPLAY_FACTORY.term_lines_for_preview(card)
	if not term_lines.is_empty():
		var terms_label := Label.new()
		terms_label.layout_mode = 2
		terms_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		terms_label.custom_minimum_size = Vector2(340, 0)
		terms_label.text = "\n".join(term_lines)
		terms_label.add_theme_font_size_override("font_size", 14)
		terms_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 0.84))
		entry_box.add_child(terms_label)

	_option_preview_box.add_child(entry_box)


func _add_module_entry(module_data: ModuleData) -> void:
	var entry_box := VBoxContainer.new()
	entry_box.layout_mode = 2
	entry_box.add_theme_constant_override("separation", 4)

	# 模块名称 + 稀有度
	var name_row := HBoxContainer.new()
	name_row.layout_mode = 2
	name_row.add_theme_constant_override("separation", 8)

	var icon_texture: Texture2D = null
	var icon_path: String = Util.module_icon_path(module_data.id)
	if not icon_path.is_empty():
		icon_texture = load(icon_path) as Texture2D
	if icon_texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.layout_mode = 2
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = icon_texture
		name_row.add_child(icon_rect)

	var name_label := Label.new()
	name_label.layout_mode = 2
	name_label.text = LocalizationManager.module_name(module_data)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.98))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	name_label.add_theme_constant_override("outline_size", 3)
	name_row.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.layout_mode = 2
	rarity_label.text = _module_rarity_display(module_data)
	rarity_label.add_theme_font_size_override("font_size", 15)
	rarity_label.add_theme_color_override("font_color", _module_rarity_color(module_data))
	rarity_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.86))
	rarity_label.add_theme_constant_override("outline_size", 2)
	name_row.add_child(rarity_label)
	entry_box.add_child(name_row)

	# 模块描述
	var desc_label := Label.new()
	desc_label.layout_mode = 2
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(340, 0)
	desc_label.text = LocalizationManager.module_description(module_data)
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 0.92))
	desc_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.80))
	desc_label.add_theme_constant_override("outline_size", 1)
	entry_box.add_child(desc_label)

	_option_preview_box.add_child(entry_box)


func _add_charm_entry(charm_data: CharmData) -> void:
	var entry_box := VBoxContainer.new()
	entry_box.layout_mode = 2
	entry_box.add_theme_constant_override("separation", 4)

	# 护符名称
	var name_row := HBoxContainer.new()
	name_row.layout_mode = 2
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.layout_mode = 2
	name_label.text = LocalizationManager.charm_name(charm_data)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.98))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	name_label.add_theme_constant_override("outline_size", 3)
	name_row.add_child(name_label)

	var slot_label := Label.new()
	slot_label.layout_mode = 2
	slot_label.text = LocalizationManager.text("event.preview_charm_slot")
	slot_label.add_theme_font_size_override("font_size", 15)
	slot_label.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.86))
	slot_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.86))
	slot_label.add_theme_constant_override("outline_size", 2)
	name_row.add_child(slot_label)
	entry_box.add_child(name_row)

	# 护符描述
	var desc_label := Label.new()
	desc_label.layout_mode = 2
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(340, 0)
	desc_label.text = LocalizationManager.charm_description(charm_data)
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 0.92))
	desc_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.80))
	desc_label.add_theme_constant_override("outline_size", 1)
	entry_box.add_child(desc_label)

	_option_preview_box.add_child(entry_box)


func _module_rarity_display(module_data: ModuleData) -> String:
	match String(module_data.rarity):
		"Common":
			return LocalizationManager.text("card.rarity_common")
		"Uncommon":
			return LocalizationManager.text("card.rarity_uncommon")
		"Rare":
			return LocalizationManager.text("card.rarity_rare")
	return String(module_data.rarity)


func _module_rarity_color(module_data: ModuleData) -> Color:
	match String(module_data.rarity):
		"Common":
			return Color(0.86, 0.88, 0.92, 0.96)
		"Uncommon":
			return Color(0.56, 0.86, 0.74, 0.96)
		"Rare":
			return Color(0.96, 0.82, 0.48, 0.98)
	return Color(0.80, 0.82, 0.86, 0.92)


func _layout_preview_near(button: Button) -> void:
	await get_tree().process_frame
	if _option_preview_panel == null or not is_inside_tree():
		return
	var panel_size: Vector2 = _option_preview_panel.size
	var viewport_size: Vector2 = get_viewport_rect().size
	var btn_rect: Rect2 = button.get_global_rect()
	# 默认放在按钮右侧
	var target_pos: Vector2 = Vector2(btn_rect.end.x + 24, btn_rect.position.y)
	# 超出右边界则放左侧
	if target_pos.x + panel_size.x > viewport_size.x - 20:
		target_pos.x = btn_rect.position.x - panel_size.x - 24
	# 超出下边界则上移
	if target_pos.y + panel_size.y > viewport_size.y - 20:
		target_pos.y = max(20, viewport_size.y - panel_size.y - 20)
	# 钳制到安全区
	target_pos.x = clamp(target_pos.x, 20, viewport_size.x - panel_size.x - 20)
	target_pos.y = clamp(target_pos.y, 20, viewport_size.y - panel_size.y - 20)
	_option_preview_panel.position = target_pos
	_option_preview_panel.pivot_offset = _option_preview_panel.size * 0.5


func _rarity_display(card: CardData) -> String:
	var rarity: String = String(card.rarity)
	match rarity:
		"Starter", "Basic":
			return LocalizationManager.text("card.rarity_basic")
		"Common":
			return LocalizationManager.text("card.rarity_common")
		"Uncommon":
			return LocalizationManager.text("card.rarity_uncommon")
		"Rare":
			return LocalizationManager.text("card.rarity_rare")
		"Curse":
			return LocalizationManager.text("card.rarity_curse")
		"Status":
			return LocalizationManager.text("card.rarity_status")
	return rarity


func _rarity_color(card: CardData) -> Color:
	match String(card.rarity):
		"Common":
			return Color(0.86, 0.88, 0.92, 0.96)
		"Uncommon":
			return Color(0.56, 0.86, 0.74, 0.96)
		"Rare":
			return Color(0.96, 0.82, 0.48, 0.98)
		"Curse":
			return Color(0.88, 0.58, 0.72, 0.96)
		"Status":
			return Color(0.72, 0.72, 0.76, 0.92)
	return Color(0.80, 0.82, 0.86, 0.92)
