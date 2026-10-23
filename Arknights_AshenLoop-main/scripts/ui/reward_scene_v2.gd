extends Control

const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

@onready var panel: PanelContainer = $Panel
@onready var header_panel: PanelContainer = $Panel/Margin/VBox/HeaderPanel
@onready var eyebrow_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Eyebrow
@onready var title_label: Label = $Panel/Margin/VBox/HeaderPanel/HeaderMargin/HeaderVBox/Title
@onready var info_panel: PanelContainer = $Panel/Margin/VBox/InfoPanel
@onready var body_scroll: ScrollContainer = $Panel/Margin/VBox/InfoPanel/InfoMargin/BodyScroll
@onready var body_label: Label = $Panel/Margin/VBox/InfoPanel/InfoMargin/BodyScroll/Body
@onready var content_scroll: ScrollContainer = $Panel/Margin/VBox/ContentScroll
@onready var content_box: VBoxContainer = $Panel/Margin/VBox/ContentScroll/Content
@onready var cards_box: HBoxContainer = $Panel/Margin/VBox/ContentScroll/Content/Cards
@onready var summary_box: VBoxContainer = $Panel/Margin/VBox/ContentScroll/Content/ModuleBox
@onready var footer_panel: PanelContainer = $Panel/Margin/VBox/FooterPanel
@onready var footer_hint_label: Label = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/FooterHint
@onready var continue_button: Button = $Panel/Margin/VBox/FooterPanel/FooterMargin/FooterRow/Continue

var card_db: Dictionary = {}
var module_db: Dictionary = {}

func _ready() -> void:
	card_db = Util.load_card_db()
	module_db = Util.load_module_db()
	if content_box != null and summary_box != null and cards_box != null:
		content_box.move_child(summary_box, 1)
		content_box.move_child(cards_box, 2)
	_apply_ui_theme()
	if not LocalizationManager.language_changed.is_connected(_render):
		LocalizationManager.language_changed.connect(_render)
	_render()
	continue_button.pressed.connect(_on_continue)
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_render):
		LocalizationManager.language_changed.disconnect(_render)

func _render(_language_code: String = "") -> void:
	var reward: Dictionary = RunManager.pending_rewards
	var card_choices: Array = _character_safe_card_choices(reward.get("card_choices", []))
	var picks_allowed: int = int(reward.get("picks_allowed", 1)) if not card_choices.is_empty() else 0
	var picked_ids: Array = reward.get("picked_ids", [])
	var picks_used: int = picked_ids.size()
	var picks_remaining: int = max(0, picks_allowed - picks_used)
	eyebrow_label.text = LocalizationManager.text("reward.eyebrow")
	title_label.text = LocalizationManager.text("reward.title").strip_edges()
	var body_text: String = String(reward.get("text", LocalizationManager.text("reward.body_default")))
	var module_id: String = _character_safe_module_id(String(reward.get("module_id", "")))
	if module_id != String(reward.get("module_id", "")):
		reward = reward.duplicate(true)
		reward["module_id"] = module_id
		RunManager.set_pending_rewards(reward)
	if not reward.is_empty() and picks_allowed > 1:
		body_text += "\n" + LocalizationManager.text("reward.pick_remaining", [picks_remaining, picks_allowed])
	var source_line: String = _reward_source_line(reward, card_choices)
	if not source_line.is_empty():
		body_text += "\n" + source_line
	body_label.text = body_text.strip_edges()
	body_scroll.scroll_vertical = 0
	content_scroll.scroll_vertical = 0
	for child in cards_box.get_children():
		child.queue_free()
	for child in summary_box.get_children():
		child.queue_free()
	var summary_entries: Array = reward.get("summary_entries", [])
	if not module_id.is_empty() and module_db.has(module_id):
		var pending_module: ModuleData = module_db[module_id] as ModuleData
		if pending_module != null:
			summary_entries = summary_entries.duplicate()
			summary_entries.push_front({
				"title": LocalizationManager.text("reward.module_bonus_title"),
				"subtitle": LocalizationManager.module_name(pending_module),
				"body": LocalizationManager.module_description(pending_module),
				"accent": Color(0.72, 0.92, 1.0, 0.84),
				"image_path": Util.module_icon_path(module_id)
			})
	var gold_reward: int = int(reward.get("gold", 0))
	if gold_reward > 0:
		summary_entries = summary_entries.duplicate()
		summary_entries.push_front({
			"title": LocalizationManager.text("reward.gold_title"),
			"subtitle": LocalizationManager.text("reward.gold_amount", [gold_reward]),
			"body": "",
			"accent": Color(0.95, 0.85, 0.55, 0.84),
			"image_path": ""
		})
	for summary_entry in summary_entries:
		if typeof(summary_entry) != TYPE_DICTIONARY:
			continue
		summary_box.add_child(_make_summary_panel(summary_entry))
	summary_box.visible = summary_box.get_child_count() > 0
	cards_box.visible = not card_choices.is_empty()
	for card_id in card_choices:
		if not card_db.has(card_id):
			continue
		var card: CardData = card_db[card_id]
		var button: Button = CARD_DISPLAY_FACTORY.create_card_button(
			card,
			LocalizationManager.card_name(card),
			LocalizationManager.card_description(card),
			card.cost,
			Util.load_card_art(card.id),
			CARD_DISPLAY_FACTORY.reward_card_size(),
			true,
			CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
		)
		var already_picked: bool = picked_ids.has(card_id)
		button.disabled = already_picked or picks_remaining <= 0
		button.modulate = Color(0.72, 0.76, 0.84, 0.82) if already_picked else Color(1, 1, 1, 1)
		button.pressed.connect(func(id: String = card_id) -> void:
			var inner_reward: Dictionary = RunManager.pending_rewards
			var inner_picked_ids: Array = inner_reward.get("picked_ids", [])
			var inner_picks_allowed: int = int(inner_reward.get("picks_allowed", 1))
			if inner_picked_ids.has(id) or inner_picked_ids.size() >= inner_picks_allowed:
				return
			SfxManager.play_card_select()
			RunManager.begin_save_batch()
			RunManager.add_card(id, "battle_reward" if String(inner_reward.get("type", "")) == "battle_reward" else "event_reward")
			inner_picked_ids.append(id)
			inner_reward["picked_ids"] = inner_picked_ids
			RunManager.set_pending_rewards(inner_reward)
			RunManager.end_save_batch()
			_render()
		)
		cards_box.add_child(button)
	var can_finish: bool = reward.is_empty() or card_choices.is_empty() or picks_remaining <= 0
	if reward.is_empty():
		footer_hint_label.text = LocalizationManager.text("reward.footer_empty")
	elif can_finish:
		footer_hint_label.text = LocalizationManager.text("reward.footer_ready")
	else:
		footer_hint_label.text = LocalizationManager.text("reward.footer_pending")
	continue_button.text = LocalizationManager.text("reward.continue") if can_finish else LocalizationManager.text("reward.skip")

func _character_safe_card_choices(raw_choices: Array) -> Array[String]:
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	var safe_choices: Array[String] = Util.normalize_character_card_choices(
		raw_choices,
		character_id,
		raw_choices.size(),
		RunManager.rng_seed + RunManager.current_floor * 131,
		RunManager.get_reward_bias_weights()
	)
	if safe_choices.size() != raw_choices.size() or _contains_unsafe_card_reward(raw_choices, character_id):
		var reward: Dictionary = RunManager.pending_rewards.duplicate(true)
		reward["card_choices"] = safe_choices
		RunManager.set_pending_rewards(reward)
	return safe_choices

func _contains_unsafe_card_reward(card_ids: Array, character_id: String) -> bool:
	for card_id_variant in card_ids:
		var card_id: String = String(card_id_variant)
		var card: CardData = card_db.get(card_id, null) as CardData
		if not Util.is_card_reward_eligible(card, character_id):
			return true
	return false

func _reward_source_line(reward: Dictionary, card_choices: Array) -> String:
	if reward.is_empty():
		return ""
	var parts: Array[String] = []
	match String(reward.get("type", "")):
		"battle_reward":
			parts.append(LocalizationManager.text("reward.source_battle"))
		"event_reward":
			parts.append(LocalizationManager.text("reward.source_event"))
	var module_id: String = String(reward.get("module_id", ""))
	if not module_id.is_empty() and module_db.has(module_id):
		var module_data: ModuleData = module_db[module_id] as ModuleData
		if module_data != null:
			parts.append(LocalizationManager.text("reward.module_bonus", [LocalizationManager.module_name(module_data)]))
	var quality_counts := {"common": 0, "elite": 0, "rare": 0}
	for card_id_variant in card_choices:
		var card: CardData = card_db.get(String(card_id_variant), null) as CardData
		if card == null:
			continue
		var tier: String = Util.card_rarity_tier(card)
		if quality_counts.has(tier):
			quality_counts[tier] = int(quality_counts[tier]) + 1
	var quality_parts: Array[String] = []
	if int(quality_counts.get("common", 0)) > 0:
		quality_parts.append(LocalizationManager.text("reward.quality_common", [int(quality_counts.get("common", 0))]))
	if int(quality_counts.get("elite", 0)) > 0:
		quality_parts.append(LocalizationManager.text("reward.quality_elite", [int(quality_counts.get("elite", 0))]))
	if int(quality_counts.get("rare", 0)) > 0:
		quality_parts.append(LocalizationManager.text("reward.quality_rare", [int(quality_counts.get("rare", 0))]))
	if not quality_parts.is_empty():
		parts.append(LocalizationManager.text("reward.quality_distribution", ["、".join(quality_parts) if LocalizationManager.current_language == "zh" else ", ".join(quality_parts)]))
	return "\n".join(parts)

func _character_safe_module_id(module_id: String) -> String:
	if module_id.is_empty():
		return ""
	var character_id: String = RunManager.character.id if RunManager.character != null else "amiya"
	if Util.is_module_available_to_character(module_id, character_id):
		return module_id
	var replacements: Array[String] = Util.normalize_character_module_choices(
		[module_id],
		character_id,
		1,
		RunManager.rng_seed + RunManager.current_floor * 173 + module_id.hash()
	)
	return replacements[0] if not replacements.is_empty() else ""

func _on_continue() -> void:
	var reward: Dictionary = RunManager.pending_rewards
	var module_id: String = _character_safe_module_id(String(reward.get("module_id", "")))
	var gold_reward: int = int(reward.get("gold", 0))
	RunManager.begin_save_batch()
	if not module_id.is_empty():
		RunManager.add_module(module_id)
	if gold_reward > 0:
		RunManager.add_gold(gold_reward)
	RunManager.clear_pending_rewards()
	if RunManager.has_flag("run_complete"):
		RunManager.set_last_run_summary({
			"floor": RunManager.current_floor,
			"gold": RunManager.gold,
			"deck_size": RunManager.deck.size(),
			"modules": RunManager.modules.size()
		})
		RunManager.end_save_batch()
		RunManager.record_run_result(true)
		RunManager.clear_saved_run()
		SceneRouter.go_victory()
	elif RunManager.should_take_interfloor_rest():
		RunManager.end_save_batch()
		SceneRouter.go_rest()
	else:
		RunManager.end_save_batch()
		SceneRouter.go_map()

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_paper_panel(panel)
	UI_THEME_KIT.apply_glass_panel(header_panel)
	UI_THEME_KIT.apply_page_section_panel(info_panel)
	UI_THEME_KIT.apply_page_section_panel(footer_panel)
	UI_THEME_KIT.apply_heading(eyebrow_label, 15, Color(0.95, 0.86, 0.58, 0.96), Color(0.07, 0.06, 0.05, 0.66))
	UI_THEME_KIT.apply_glass_heading(title_label, 34)
	UI_THEME_KIT.apply_glass_body(body_label, 20)
	UI_THEME_KIT.apply_glass_hint(footer_hint_label, 18)
	UI_THEME_KIT.apply_stone_button(continue_button, "paper", 24)
	UI_MOTION.wire_button_feedback(continue_button, 1.02, 0.98, Color(1.0, 0.88, 0.64, 0.72), 5.0)
	if summary_box != null:
		summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cards_box != null:
		cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _play_intro_animation() -> void:
	UI_MOTION.reveal(panel, 0.04, Vector2(0, 24), 0.30, Vector2(0.99, 0.99))
	UI_MOTION.reveal(continue_button, 0.14, Vector2(0, 16), 0.24, Vector2(0.99, 0.99))

func _make_summary_panel(entry: Dictionary) -> PanelContainer:
	var panel_container := PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(0, 132)
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_glass_panel(panel_container)
	var accent_variant: Variant = entry.get("accent", Color(0.90, 0.84, 0.72, 0.84))
	var accent: Color = accent_variant if typeof(accent_variant) == TYPE_COLOR else Color(0.90, 0.84, 0.72, 0.84)
	var style: StyleBoxFlat = panel_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.border_color = accent
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		panel_container.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel_container.add_child(margin)

	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var image_path: String = String(entry.get("image_path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var portrait_frame := PanelContainer.new()
		portrait_frame.custom_minimum_size = Vector2(88, 88)
		var portrait_style := StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.94, 0.97, 1.0, 0.10)
		portrait_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
		portrait_style.border_width_left = 2
		portrait_style.border_width_top = 2
		portrait_style.border_width_right = 2
		portrait_style.border_width_bottom = 2
		portrait_style.corner_radius_top_left = 16
		portrait_style.corner_radius_top_right = 16
		portrait_style.corner_radius_bottom_right = 16
		portrait_style.corner_radius_bottom_left = 16
		portrait_frame.add_theme_stylebox_override("panel", portrait_style)
		row.add_child(portrait_frame)

		var portrait_margin := MarginContainer.new()
		portrait_margin.layout_mode = 2
		portrait_margin.add_theme_constant_override("margin_left", 8)
		portrait_margin.add_theme_constant_override("margin_top", 8)
		portrait_margin.add_theme_constant_override("margin_right", 8)
		portrait_margin.add_theme_constant_override("margin_bottom", 8)
		portrait_frame.add_child(portrait_margin)

		var portrait := TextureRect.new()
		portrait.layout_mode = 2
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(72, 72)
		portrait.texture = load(image_path) as Texture2D
		portrait_margin.add_child(portrait)

	var box := VBoxContainer.new()
	box.layout_mode = 2
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var title := Label.new()
	title.layout_mode = 2
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_heading(title, 22, Color(0.98, 0.94, 0.84, 1.0), Color(0.04, 0.04, 0.05, 0.72))
	title.text = String(entry.get("title", ""))
	box.add_child(title)

	var subtitle_text: String = String(entry.get("subtitle", "")).strip_edges()
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.layout_mode = 2
		subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI_THEME_KIT.apply_numeric(subtitle, 18, accent, Color(0.04, 0.04, 0.05, 0.82))
		subtitle.text = subtitle_text
		box.add_child(subtitle)

	var body_text: String = String(entry.get("body", "")).strip_edges()
	if not body_text.is_empty():
		var body := Label.new()
		body.layout_mode = 2
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI_THEME_KIT.apply_body(body, 18, Color(0.92, 0.94, 0.98, 0.92))
		body.text = body_text
		box.add_child(body)

	return panel_container
