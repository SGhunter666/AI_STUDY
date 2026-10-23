extends Control

const TUNE_LIBRARY = preload("res://scripts/core/tune_library.gd")
const REST_MANAGER = preload("res://scripts/rest/RestManager.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

@onready var panel: PanelContainer = $Panel
@onready var header_panel: PanelContainer = $Panel/Margin/VBox/HeaderPanel
@onready var eyebrow_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Eyebrow
@onready var title_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Title
@onready var info_panel: PanelContainer = $Panel/Margin/VBox/InfoPanel
@onready var info_scroll: ScrollContainer = $Panel/Margin/VBox/InfoPanel/InfoMargin/InfoScroll
@onready var info_label: Label = $Panel/Margin/VBox/InfoPanel/InfoMargin/InfoScroll/Info
@onready var content_scroll: ScrollContainer = $Panel/Margin/VBox/ContentScroll
@onready var service_list: VBoxContainer = $Panel/Margin/VBox/ContentScroll/ServiceList
@onready var footer_panel: PanelContainer = $Panel/Margin/VBox/FooterPanel
@onready var footer_hint_label: Label = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/FooterHint
@onready var continue_button: Button = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/Continue

var service_used: bool = false
var upgrade_picker_active: bool = false
var remove_picker_active: bool = false
var express_terminal_free_used_here: bool = false
var rest_manager = REST_MANAGER.new()
var service_buttons: Array[Button] = []
var card_buttons: Array[Button] = []

func _ready() -> void:
	_apply_safe_layout()
	get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_ui_theme()
	_refresh_header_text()
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if RunManager.should_take_interfloor_rest():
		content_scroll.visible = false
		RunManager.heal_full()
		info_label.text = LocalizationManager.text("rest.interfloor_done")
	else:
		content_scroll.visible = true
		info_label.text = LocalizationManager.text("rest.choose_service")
		_build_rest_services()
		_append_tune_summary()
	_refresh_footer_hint()
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload / viewport 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.disconnect(_on_language_changed)
	var vp: Window = get_viewport()
	if vp != null and vp.size_changed.is_connected(_apply_safe_layout):
		vp.size_changed.disconnect(_apply_safe_layout)

func _apply_safe_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact_layout: bool = _is_compact_layout(viewport_size)
	var side_margin: float = clamp(viewport_size.x * 0.12, 110.0, 220.0)
	var vertical_margin: float = 24.0 if compact_layout else 42.0
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2.ZERO
	panel.clip_contents = true
	panel.offset_left = side_margin
	panel.offset_top = vertical_margin
	panel.offset_right = -side_margin
	panel.offset_bottom = -vertical_margin
	var outer_margin: int = 14 if compact_layout else 28
	var margin_container: MarginContainer = $Panel/Margin as MarginContainer
	if margin_container != null:
		margin_container.add_theme_constant_override("margin_left", outer_margin)
		margin_container.add_theme_constant_override("margin_top", outer_margin)
		margin_container.add_theme_constant_override("margin_right", outer_margin)
		margin_container.add_theme_constant_override("margin_bottom", outer_margin)
	var vbox: VBoxContainer = $Panel/Margin/VBox as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", 8 if compact_layout else 16)
	header_panel.custom_minimum_size = Vector2(0, 48 if compact_layout else 68)
	info_panel.custom_minimum_size = Vector2(0, 84 if compact_layout else 146)
	footer_panel.custom_minimum_size = Vector2(0, 54 if compact_layout else 76)
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _is_compact_layout(viewport_size: Vector2 = Vector2.ZERO) -> bool:
	var size := viewport_size
	if size == Vector2.ZERO:
		size = get_viewport_rect().size
	var scale_factor: float = max(1.0, get_tree().root.content_scale_factor)
	return size.y < 900.0 or size.y / scale_factor < 900.0

func _service_button_height() -> int:
	return 44 if _is_compact_layout() else 52

func _on_language_changed(_language_code: String) -> void:
	_refresh_header_text()
	_refresh_footer_hint()

func _build_rest_services() -> void:
	_clear_dynamic_entries()
	upgrade_picker_active = false
	remove_picker_active = false
	service_buttons.clear()
	express_terminal_free_used_here = false
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	_add_service_button(LocalizationManager.text("rest.service_recover"), _recover)
	_add_service_button(LocalizationManager.text("rest.service_upgrade"), _show_upgrade_card_list)
	_add_service_button(LocalizationManager.text("rest.service_remove"), _show_remove_card_list)
	for tune_id in rest_manager.offered_tunes():
		_add_service_button(
			LocalizationManager.text("rest.service_tune", [LocalizationManager.tune_title(tune_id, TUNE_LIBRARY.title(tune_id)), LocalizationManager.tune_short(tune_id, TUNE_LIBRARY.short_text(tune_id))]),
			func(id = tune_id) -> void:
				_apply_tune_choice(id)
		)
	for rewire_entry in TUNE_LIBRARY.rewire_entries(character_id):
		var rewire_id: String = String(rewire_entry.get("id", ""))
		var rewire_title: String = LocalizationManager.rewire_field(rewire_id, "title", String(rewire_entry.get("title", rewire_id)))
		var rewire_done: String = LocalizationManager.rewire_field(rewire_id, "done", String(rewire_entry.get("done", rewire_title)))
		_add_service_button(rewire_title, func(id := rewire_id, message := rewire_done) -> void:
			_rewire(id, message)
		)
	_add_service_button(LocalizationManager.text("rest.service_equip_charm"), _equip_next_charm)

func _add_service_button(label: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, _service_button_height())
	UI_THEME_KIT.apply_stone_button(button, "paper", 18)
	UI_MOTION.wire_button_feedback(button, 1.02, 0.98, Color(1.0, 0.88, 0.66, 0.70), 5.0)
	service_buttons.append(button)
	button.pressed.connect(func() -> void:
		if service_used:
			return
		var finalize_service: bool = true
		var result: Variant = callback.call()
		if typeof(result) == TYPE_BOOL:
			finalize_service = bool(result)
		if not finalize_service:
			return
		service_used = true
		content_scroll.visible = false
		_disable_service_buttons()
		_refresh_footer_hint()
	)
	service_list.add_child(button)

func _disable_service_buttons() -> void:
	for button in service_buttons:
		if is_instance_valid(button) and button != continue_button:
			button.disabled = true

func _recover() -> void:
	RunManager.heal(int(ceil(float(RunManager.max_hp) * 0.3)))
	info_label.text = LocalizationManager.text("rest.done_recover")
	_refresh_footer_hint()

# 引导/支援强化额度：挑选列表优先展示对应路线卡牌，额度在打开挑选器时一次性消耗
func _prioritized_upgrade_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var priority_tag: String = ""
	if RunManager.has_flag("channel_upgrade_credit"):
		priority_tag = "Channel"
		RunManager.set_flag("channel_upgrade_credit", false)
	elif RunManager.has_flag("support_upgrade_credit"):
		priority_tag = "Support"
		RunManager.set_flag("support_upgrade_credit", false)
	if priority_tag.is_empty():
		return entries
	var prioritized: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for entry in entries:
		var entry_card: CardData = entry.get("card", null) as CardData
		if entry_card != null and priority_tag in entry_card.tags:
			prioritized.append(entry)
		else:
			rest.append(entry)
	prioritized.append_array(rest)
	if not prioritized.is_empty():
		info_label.text = LocalizationManager.text("rest.upgrade_priority_hint", [LocalizationManager.text("rest.upgrade_priority_" + priority_tag.to_lower())])
	return prioritized

func _show_upgrade_card_list() -> bool:
	var card_db: Dictionary = Util.load_card_db()
	var upgradeable: Array[Dictionary] = []
	for index in range(RunManager.deck.size()):
		var card: CardData = card_db.get(RunManager.deck[index], null) as CardData
		if card != null and not card.upgraded_id.is_empty() and card_db.has(card.upgraded_id):
			upgradeable.append({"index": index, "card": card, "upgraded": card_db[card.upgraded_id] as CardData})
	if upgradeable.is_empty():
		info_label.text = LocalizationManager.text("rest.done_upgrade_none")
		_refresh_footer_hint()
		return true
	# 引导/支援强化额度：本次升级挑选列表优先展示对应路线的牌（额度一次性消耗）
	upgradeable = _prioritized_upgrade_entries(upgradeable)
	_clear_dynamic_entries()
	upgrade_picker_active = true
	info_label.text = LocalizationManager.text("rest.pick_card_to_upgrade")
	_refresh_footer_hint()
	for entry in upgradeable:
		var card: CardData = entry["card"]
		var upgraded: CardData = entry["upgraded"]
		var deck_index: int = int(entry["index"])
		var btn: Button = Button.new()
		var card_name: String = LocalizationManager.card_name(card)
		var upgraded_desc: String = LocalizationManager.card_description(upgraded)
		btn.text = LocalizationManager.text("rest.upgrade_choice", [card_name])
		btn.tooltip_text = LocalizationManager.text("rest.upgrade_choice_tooltip", [card_name, upgraded_desc])
		btn.custom_minimum_size = Vector2(0, 50 if _is_compact_layout() else 60)
		UI_THEME_KIT.apply_stone_button(btn, "paper", 16)
		UI_MOTION.wire_button_feedback(btn, 1.02, 0.98, Color(0.72, 0.92, 1.0, 0.70), 5.0)
		btn.pressed.connect(func(idx: int = deck_index, c: CardData = card, u: CardData = upgraded) -> void:
			RunManager.deck[idx] = u.id
			RunManager.deck_changed.emit()
			RunManager.run_updated.emit()
			RunManager.save_run_snapshot()
			info_label.text = LocalizationManager.text("rest.done_upgrade", [LocalizationManager.card_name(c)])
			# 休整升级额度：本次升级不占用休整次数
			if RunManager.has_flag("rest_upgrade_credit"):
				RunManager.set_flag("rest_upgrade_credit", false)
				info_label.text += LocalizationManager.text("rest.upgrade_credit_free_note")
			else:
				service_used = true
			upgrade_picker_active = false
			content_scroll.visible = false
			_disable_service_buttons()
			_clear_dynamic_entries()
			_refresh_footer_hint()
		)
		service_list.add_child(btn)
		card_buttons.append(btn)
	var back_button: Button = Button.new()
	back_button.text = LocalizationManager.text("rest.back_services")
	back_button.custom_minimum_size = Vector2(0, 42 if _is_compact_layout() else 48)
	UI_THEME_KIT.apply_stone_button(back_button, "ghost", 16)
	UI_MOTION.wire_button_feedback(back_button, 1.02, 0.98, Color(0.72, 0.92, 1.0, 0.54), 5.0)
	back_button.pressed.connect(func() -> void:
		upgrade_picker_active = false
		info_label.text = LocalizationManager.text("rest.choose_service")
		_build_rest_services()
		_append_tune_summary()
		_refresh_footer_hint()
	)
	service_list.add_child(back_button)
	card_buttons.append(back_button)
	content_scroll.scroll_vertical = 0
	return false

func _show_remove_card_list() -> bool:
	if RunManager.deck.is_empty():
		info_label.text = LocalizationManager.text("rest.done_remove_none")
		_refresh_footer_hint()
		return true
	_clear_dynamic_entries()
	remove_picker_active = true
	info_label.text = LocalizationManager.text("rest.pick_card_to_remove")
	_refresh_footer_hint()
	var card_db: Dictionary = Util.load_card_db()
	for deck_index in range(RunManager.deck.size()):
		var card_id: String = RunManager.deck[deck_index]
		var card: CardData = card_db.get(card_id, null) as CardData
		var card_name: String = LocalizationManager.card_name(card) if card != null else card_id
		var card_desc: String = LocalizationManager.card_description(card) if card != null else ""
		var btn: Button = Button.new()
		btn.text = LocalizationManager.text("rest.remove_choice", [card_name])
		btn.tooltip_text = LocalizationManager.text("rest.remove_choice_tooltip", [card_name + "\n" + card_desc if not card_desc.is_empty() else card_name])
		btn.custom_minimum_size = Vector2(0, 50 if _is_compact_layout() else 60)
		UI_THEME_KIT.apply_stone_button(btn, "paper", 16)
		UI_MOTION.wire_button_feedback(btn, 1.02, 0.98, Color(1.0, 0.62, 0.56, 0.70), 5.0)
		btn.pressed.connect(func(idx: int = deck_index, c: CardData = card, name_str: String = card_name) -> void:
			var removed_id: String = RunManager.deck[idx]
			RunManager.remove_card(removed_id)
			info_label.text = LocalizationManager.text("rest.done_remove", [name_str])
			service_used = true
			remove_picker_active = false
			content_scroll.visible = false
			_disable_service_buttons()
			_clear_dynamic_entries()
			_refresh_footer_hint()
		)
		service_list.add_child(btn)
		card_buttons.append(btn)
	var back_button: Button = Button.new()
	back_button.text = LocalizationManager.text("rest.back_services")
	back_button.custom_minimum_size = Vector2(0, 42 if _is_compact_layout() else 48)
	UI_THEME_KIT.apply_stone_button(back_button, "ghost", 16)
	UI_MOTION.wire_button_feedback(back_button, 1.02, 0.98, Color(1.0, 0.62, 0.56, 0.54), 5.0)
	back_button.pressed.connect(func() -> void:
		remove_picker_active = false
		info_label.text = LocalizationManager.text("rest.choose_service")
		_build_rest_services()
		_append_tune_summary()
		_refresh_footer_hint()
	)
	service_list.add_child(back_button)
	card_buttons.append(back_button)
	content_scroll.scroll_vertical = 0
	return false

func _clear_card_buttons() -> void:
	for btn in card_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	card_buttons.clear()

func _clear_dynamic_entries() -> void:
	for child in service_list.get_children():
		child.queue_free()
	service_buttons.clear()
	card_buttons.clear()
	content_scroll.scroll_vertical = 0
	info_scroll.scroll_vertical = 0

func _apply_tune_choice(tune_id: String) -> void:
	if not rest_manager.apply_tune(tune_id):
		info_label.text = LocalizationManager.text("rest.done_tune_duplicate")
		_refresh_footer_hint()
		return
	info_label.text = LocalizationManager.text("rest.done_tune", [LocalizationManager.tune_title(tune_id, TUNE_LIBRARY.title(tune_id)), LocalizationManager.tune_description(tune_id, TUNE_LIBRARY.description(tune_id))])
	_append_tune_summary()
	_refresh_footer_hint()

func _rewire(flag_id: String, message: String) -> void:
	RunManager.set_flag(flag_id, true)
	info_label.text = message
	_refresh_footer_hint()

func _equip_next_charm() -> bool:
	var used_free_swap: bool = false
	# 免费整备额度仅在成功整备时才消耗，避免无符可整备时白扣
	for charm_id in RunManager.unequipped_owned_charms():
		if RunManager.equip_charm(charm_id):
			if RunManager.has_relic("ex_h07_express_terminal") and not express_terminal_free_used_here:
				express_terminal_free_used_here = true
				used_free_swap = true
			info_label.text = LocalizationManager.text("rest.done_equip_charm", [LocalizationManager.charm_name_by_id(charm_id)])
			if used_free_swap:
				info_label.text += LocalizationManager.text("rest.express_terminal_free_note")
				_refresh_footer_hint()
				return false
			return true
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	for charm_id in Util.get_charm_reward_pool(character_id):
		if not RunManager.is_charm_owned(charm_id):
			RunManager.add_charm(charm_id, false)
			RunManager.equip_charm(charm_id)
			if RunManager.has_relic("ex_h07_express_terminal") and not express_terminal_free_used_here:
				express_terminal_free_used_here = true
				used_free_swap = true
			info_label.text = LocalizationManager.text("rest.done_equip_charm", [LocalizationManager.charm_name_by_id(charm_id)])
			if used_free_swap:
				info_label.text += LocalizationManager.text("rest.express_terminal_free_note")
				_refresh_footer_hint()
				return false
			_refresh_footer_hint()
			return true
	info_label.text = LocalizationManager.text("rest.done_equip_charm_full")
	_refresh_footer_hint()
	return not used_free_swap

func _append_tune_summary() -> void:
	var lines: Array[String] = RunManager.tune_summary_lines()
	if lines.is_empty():
		return
	info_label.text += LocalizationManager.text("rest.current_tunes", ["\n".join(lines)])

func _on_continue_pressed() -> void:
	if RunManager.should_take_interfloor_rest():
		RunManager.consume_interfloor_rest()
	RunManager.complete_current_node()
	if RunManager.has_flag("run_complete"):
		SceneRouter.go_main_menu()
	else:
		SceneRouter.go_map()

func _refresh_header_text() -> void:
	eyebrow_label.text = LocalizationManager.text("rest.eyebrow")
	title_label.text = LocalizationManager.node_type_name("rest")
	continue_button.text = LocalizationManager.text("reward.continue")

func _refresh_footer_hint() -> void:
	if RunManager.should_take_interfloor_rest():
		footer_hint_label.text = LocalizationManager.text("rest.footer_interfloor")
	elif upgrade_picker_active:
		footer_hint_label.text = LocalizationManager.text("rest.footer_upgrade")
	elif remove_picker_active:
		footer_hint_label.text = LocalizationManager.text("rest.footer_remove")
	elif service_used:
		footer_hint_label.text = LocalizationManager.text("rest.footer_used")
	else:
		footer_hint_label.text = LocalizationManager.text("rest.footer_default")
	footer_panel.visible = RunManager.should_take_interfloor_rest() or service_used

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_paper_panel(panel)
	UI_THEME_KIT.apply_glass_panel(header_panel)
	UI_THEME_KIT.apply_page_section_panel(info_panel)
	UI_THEME_KIT.apply_page_section_panel(footer_panel)
	UI_THEME_KIT.apply_heading(eyebrow_label, 15, Color(0.95, 0.86, 0.58, 0.96), Color(0.07, 0.06, 0.05, 0.66))
	UI_THEME_KIT.apply_glass_heading(title_label, 30)
	UI_THEME_KIT.apply_glass_body(info_label, 18)
	UI_THEME_KIT.apply_glass_hint(footer_hint_label, 18)
	UI_THEME_KIT.apply_stone_button(continue_button, "paper", 24)
	UI_MOTION.wire_button_feedback(continue_button, 1.02, 0.98, Color(1.0, 0.88, 0.66, 0.70), 5.0)

func _play_intro_animation() -> void:
	UI_MOTION.reveal(panel, 0.04, Vector2(0, 24), 0.30, Vector2(0.99, 0.99))
