class_name CardDisplayFactory
extends Object

const GALLERY_CARD_SIZE := Vector2(232, 340)
const REWARD_CARD_SIZE := Vector2(232, 388)

static func gallery_card_size() -> Vector2:
	return GALLERY_CARD_SIZE


static func reward_card_size() -> Vector2:
	return REWARD_CARD_SIZE


static func create_card_button(
	card: CardData,
	card_name: String,
	card_description: String,
	cost_value: int,
	art: Texture2D,
	size: Vector2,
	show_description: bool = true,
	is_upgraded_visual: bool = false
) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = size
	button.size = size
	button.pivot_offset = size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _build_tooltip_text(card, card_name, card_description)
	_apply_card_styles(button, is_upgraded_visual)

	var art_rect: TextureRect = TextureRect.new()
	art_rect.name = "CardArt"
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_rect.layout_mode = 1
	art_rect.anchor_left = 0.0
	art_rect.anchor_top = 0.0
	art_rect.anchor_right = 1.0
	art_rect.anchor_bottom = 1.0
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.texture = art
	if is_upgraded_visual:
		art_rect.modulate = Color(1.06, 1.04, 0.98, 1.0)
	button.add_child(art_rect)

	var full_tint: ColorRect = ColorRect.new()
	full_tint.name = "FullTint"
	full_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_tint.layout_mode = 1
	full_tint.anchor_left = 0.0
	full_tint.anchor_top = 0.0
	full_tint.anchor_right = 1.0
	full_tint.anchor_bottom = 1.0
	full_tint.color = Color(0.02, 0.05, 0.11, 0.10)
	button.add_child(full_tint)

	var inner_frame: Panel = Panel.new()
	inner_frame.name = "InnerFrame"
	inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_frame.layout_mode = 1
	inner_frame.anchor_left = 0.0
	inner_frame.anchor_top = 0.0
	inner_frame.anchor_right = 1.0
	inner_frame.anchor_bottom = 1.0
	inner_frame.offset_left = 8.0
	inner_frame.offset_top = 8.0
	inner_frame.offset_right = -8.0
	inner_frame.offset_bottom = -8.0
	inner_frame.add_theme_stylebox_override("panel", _make_inner_frame_style(is_upgraded_visual))
	button.add_child(inner_frame)

	if is_upgraded_visual:
		var upgrade_glint: ColorRect = ColorRect.new()
		upgrade_glint.name = "UpgradeGlint"
		upgrade_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upgrade_glint.layout_mode = 1
		upgrade_glint.anchor_left = 0.0
		upgrade_glint.anchor_top = 0.0
		upgrade_glint.anchor_right = 1.0
		upgrade_glint.anchor_bottom = 0.0
		upgrade_glint.offset_left = 18.0
		upgrade_glint.offset_top = 18.0
		upgrade_glint.offset_right = -18.0
		upgrade_glint.offset_bottom = 90.0
		upgrade_glint.color = Color(0.96, 0.92, 0.62, 0.12)
		button.add_child(upgrade_glint)

	var is_large_reward_card: bool = show_description and size.y >= 350.0
	var description_weight: int = _description_layout_weight(card_description)
	var face_description: String = _card_face_description(card_description, is_large_reward_card, description_weight)
	var bottom_band_height: float = 152.0 if is_large_reward_card else 116.0
	if is_large_reward_card:
		if description_weight >= 88:
			bottom_band_height = 192.0
		elif description_weight >= 62:
			bottom_band_height = 178.0
		elif description_weight >= 42:
			bottom_band_height = 168.0
	var title_top: float = (-bottom_band_height + 14.0) if is_large_reward_card else -94.0
	var title_bottom: float = title_top + (38.0 if is_large_reward_card else 40.0)
	var description_top: float = title_bottom + (0.0 if is_large_reward_card else 2.0)
	var description_font_size: int = 12
	if is_large_reward_card:
		description_font_size = 10 if description_weight >= 88 else (11 if description_weight >= 42 else 12)

	var bottom_band: ColorRect = ColorRect.new()
	bottom_band.name = "BottomBand"
	bottom_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_band.layout_mode = 1
	bottom_band.anchor_left = 0.0
	bottom_band.anchor_top = 1.0
	bottom_band.anchor_right = 1.0
	bottom_band.anchor_bottom = 1.0
	bottom_band.offset_top = -bottom_band_height if show_description else -72.0
	bottom_band.color = Color(0.03, 0.06, 0.10, 0.74) if not is_upgraded_visual else Color(0.08, 0.10, 0.12, 0.76)
	button.add_child(bottom_band)

	var cost_panel: Panel = Panel.new()
	cost_panel.name = "CostPanel"
	cost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_panel.layout_mode = 1
	cost_panel.anchor_left = 0.0
	cost_panel.anchor_top = 0.0
	cost_panel.anchor_right = 0.0
	cost_panel.anchor_bottom = 0.0
	cost_panel.offset_left = 12.0
	cost_panel.offset_top = 12.0
	cost_panel.offset_right = 64.0
	cost_panel.offset_bottom = 64.0
	cost_panel.add_theme_stylebox_override("panel", _make_badge_style(_card_cost_color(card)))
	button.add_child(cost_panel)

	var cost_label: Label = Label.new()
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.layout_mode = 1
	cost_label.anchor_left = 0.0
	cost_label.anchor_top = 0.0
	cost_label.anchor_right = 1.0
	cost_label.anchor_bottom = 1.0
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	cost_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	cost_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08, 0.92))
	cost_label.add_theme_constant_override("outline_size", 2)
	cost_label.text = str(cost_value)
	cost_panel.add_child(cost_label)

	var type_panel: Panel = Panel.new()
	type_panel.name = "TypePanel"
	type_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_panel.layout_mode = 1
	type_panel.anchor_left = 1.0
	type_panel.anchor_top = 0.0
	type_panel.anchor_right = 1.0
	type_panel.anchor_bottom = 0.0
	type_panel.offset_left = -96.0
	type_panel.offset_top = 14.0
	type_panel.offset_right = -12.0
	type_panel.offset_bottom = 46.0
	type_panel.add_theme_stylebox_override("panel", _make_type_style(card))
	button.add_child(type_panel)

	if is_upgraded_visual:
		var upgrade_badge: Panel = Panel.new()
		upgrade_badge.name = "UpgradeBadge"
		upgrade_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upgrade_badge.layout_mode = 1
		upgrade_badge.anchor_left = 0.5
		upgrade_badge.anchor_top = 0.0
		upgrade_badge.anchor_right = 0.5
		upgrade_badge.anchor_bottom = 0.0
		upgrade_badge.offset_left = -28.0
		upgrade_badge.offset_top = 12.0
		upgrade_badge.offset_right = 28.0
		upgrade_badge.offset_bottom = 40.0
		upgrade_badge.add_theme_stylebox_override("panel", _make_upgrade_badge_style())
		button.add_child(upgrade_badge)

		var upgrade_label: Label = Label.new()
		upgrade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upgrade_label.layout_mode = 1
		upgrade_label.anchor_left = 0.0
		upgrade_label.anchor_top = 0.0
		upgrade_label.anchor_right = 1.0
		upgrade_label.anchor_bottom = 1.0
		upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		upgrade_label.add_theme_font_size_override("font_size", 12)
		upgrade_label.add_theme_color_override("font_color", Color(0.29, 0.22, 0.08, 1.0))
		upgrade_label.text = _upgrade_badge_label()
		upgrade_badge.add_child(upgrade_label)

	var type_label: Label = Label.new()
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_label.layout_mode = 1
	type_label.anchor_left = 0.0
	type_label.anchor_top = 0.0
	type_label.anchor_right = 1.0
	type_label.anchor_bottom = 1.0
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.96))
	type_label.text = _card_type_label(card)
	type_panel.add_child(type_label)

	var rarity_panel: Panel = Panel.new()
	rarity_panel.name = "RarityPanel"
	rarity_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_panel.layout_mode = 1
	rarity_panel.anchor_left = 1.0
	rarity_panel.anchor_top = 0.0
	rarity_panel.anchor_right = 1.0
	rarity_panel.anchor_bottom = 0.0
	rarity_panel.offset_left = -96.0
	rarity_panel.offset_top = 50.0
	rarity_panel.offset_right = -12.0
	rarity_panel.offset_bottom = 78.0
	rarity_panel.add_theme_stylebox_override("panel", _make_rarity_style(card))
	button.add_child(rarity_panel)

	var rarity_label: Label = Label.new()
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity_label.layout_mode = 1
	rarity_label.anchor_left = 0.0
	rarity_label.anchor_top = 0.0
	rarity_label.anchor_right = 1.0
	rarity_label.anchor_bottom = 1.0
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 0.98))
	rarity_label.text = _card_rarity_label(card)
	rarity_panel.add_child(rarity_label)

	var keyword_badges: Array[Dictionary] = _card_keyword_badges(card)
	if not keyword_badges.is_empty():
		var badge_stack: VBoxContainer = VBoxContainer.new()
		badge_stack.name = "KeywordBadgeStack"
		badge_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_stack.layout_mode = 1
		badge_stack.anchor_left = 1.0
		badge_stack.anchor_top = 0.0
		badge_stack.anchor_right = 1.0
		badge_stack.anchor_bottom = 0.0
		badge_stack.offset_left = -106.0
		badge_stack.offset_top = 84.0
		badge_stack.offset_right = -12.0
		badge_stack.offset_bottom = 152.0
		badge_stack.alignment = BoxContainer.ALIGNMENT_END
		badge_stack.add_theme_constant_override("separation", 5)
		button.add_child(badge_stack)
		for spec in keyword_badges:
			badge_stack.add_child(_make_keyword_badge(spec))

	var title_label: Label = Label.new()
	title_label.name = "CardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.layout_mode = 1
	title_label.anchor_left = 0.0
	title_label.anchor_top = 1.0
	title_label.anchor_right = 1.0
	title_label.anchor_bottom = 1.0
	title_label.offset_left = 14.0
	title_label.offset_top = title_top if show_description else -62.0
	title_label.offset_right = -14.0
	title_label.offset_bottom = title_bottom if show_description else -18.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18 if is_large_reward_card and description_weight >= 62 else (20 if show_description else 22))
	title_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0) if not is_upgraded_visual else Color(1.0, 0.95, 0.78, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.84))
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text = card_name
	button.add_child(title_label)

	if show_description:
		var desc_label: Label = Label.new()
		desc_label.name = "CardDescription"
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.layout_mode = 1
		desc_label.anchor_left = 0.0
		desc_label.anchor_top = 1.0
		desc_label.anchor_right = 1.0
		desc_label.anchor_bottom = 1.0
		desc_label.offset_left = 14.0
		desc_label.offset_top = description_top
		desc_label.offset_right = -14.0
		desc_label.offset_bottom = -12.0
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc_label.max_lines_visible = 5 if is_large_reward_card else 5
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.add_theme_font_size_override("font_size", description_font_size)
		desc_label.add_theme_constant_override("line_spacing", -1 if is_large_reward_card and description_weight >= 62 else 0)
		desc_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 0.94) if not is_upgraded_visual else Color(0.98, 0.96, 0.86, 0.96))
		desc_label.text = face_description
		button.add_child(desc_label)

	return button


static func _description_layout_weight(text: String) -> int:
	var cleaned: String = text.strip_edges()
	if cleaned.is_empty():
		return 0
	var punctuation_weight: int = cleaned.count("；") * 8 + cleaned.count("，") * 4 + cleaned.count("。") * 3 + cleaned.count("/") * 3
	var newline_weight: int = cleaned.count("\n") * 18
	return cleaned.length() + punctuation_weight + newline_weight


static func _card_face_description(text: String, is_large_reward_card: bool, description_weight: int) -> String:
	var cleaned: String = text.replace("\n", " ").strip_edges()
	if cleaned.is_empty() or not is_large_reward_card:
		return cleaned
	var max_chars: int = 82
	if description_weight >= 88:
		max_chars = 56
	elif description_weight >= 62:
		max_chars = 64
	elif description_weight >= 42:
		max_chars = 74
	if cleaned.length() <= max_chars:
		return cleaned
	var sentence_breaks: Array[String] = ["。", "；", ";", "."]
	for separator in sentence_breaks:
		var index: int = cleaned.find(separator)
		if index >= 18 and index <= max_chars:
			return cleaned.substr(0, index + separator.length()).strip_edges()
	var trimmed: String = cleaned.substr(0, max(1, max_chars - 1)).strip_edges()
	while trimmed.ends_with("，") or trimmed.ends_with("、") or trimmed.ends_with(";") or trimmed.ends_with("；"):
		trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges()
	return "%s…" % trimmed


static func create_codex_card_button(
	card: CardData,
	card_name: String,
	card_description: String,
	cost_value: int,
	art: Texture2D,
	size: Vector2,
	is_upgraded_visual: bool = false
) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = _build_tooltip_text(card, card_name, card_description)
	_apply_codex_card_styles(button, is_upgraded_visual)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.layout_mode = 1
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var art_frame := PanelContainer.new()
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.custom_minimum_size = Vector2(148, max(176.0, size.y - 28.0))
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_frame.add_theme_stylebox_override("panel", _make_codex_frame_style(is_upgraded_visual))
	row.add_child(art_frame)

	var art_margin := MarginContainer.new()
	art_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_margin.layout_mode = 2
	art_margin.add_theme_constant_override("margin_left", 8)
	art_margin.add_theme_constant_override("margin_top", 8)
	art_margin.add_theme_constant_override("margin_right", 8)
	art_margin.add_theme_constant_override("margin_bottom", 8)
	art_frame.add_child(art_margin)

	var art_rect := TextureRect.new()
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_rect.layout_mode = 2
	art_rect.custom_minimum_size = Vector2(132, max(160.0, size.y - 44.0))
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.texture = art
	if is_upgraded_visual:
		art_rect.modulate = Color(1.05, 1.03, 0.97, 1.0)
	art_margin.add_child(art_rect)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.layout_mode = 2
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	row.add_child(content)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.layout_mode = 2
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	content.add_child(top_row)

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.layout_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0) if not is_upgraded_visual else Color(1.0, 0.95, 0.78, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08, 0.88))
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.text = card_name
	top_row.add_child(title_label)

	top_row.add_child(_make_inline_badge(LocalizationManager.text("card.cost_badge", [cost_value]), _card_cost_color(card), Color(0.94, 0.98, 1.0, 0.78), 18))

	var meta_flow := HFlowContainer.new()
	meta_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_flow.layout_mode = 2
	meta_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_flow.add_theme_constant_override("h_separation", 8)
	meta_flow.add_theme_constant_override("v_separation", 8)
	content.add_child(meta_flow)

	meta_flow.add_child(_make_inline_badge(_card_type_label(card), _card_type_color(card), Color(0.94, 0.98, 1.0, 0.62), 13))
	meta_flow.add_child(_make_inline_badge(_card_rarity_label(card), _card_rarity_color(card), Color(1.0, 0.95, 0.80, 0.70), 13))

	var owner_id: String = _card_owner_id(card)
	if not owner_id.is_empty():
		meta_flow.add_child(_make_inline_badge(
			LocalizationManager.character_name(owner_id, owner_id.capitalize()),
			_card_owner_color(owner_id),
			_card_owner_color(owner_id).lightened(0.34),
			13
		))

	for spec in _card_keyword_badges(card, 4):
		meta_flow.add_child(_make_keyword_badge(spec, true))

	var desc_label := Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.layout_mode = 2
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.96) if not is_upgraded_visual else Color(0.98, 0.95, 0.86, 0.98))
	desc_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.82))
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.text = card_description
	content.add_child(desc_label)

	return button


# 杀戮尖塔风格：未见卡牌的占位卡片（灰色剪影 + 问号 + 解锁提示）
static func create_locked_card_button(
	card: CardData,
	unlock_hint: String,
	size: Vector2
) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = size
	button.size = size
	button.pivot_offset = size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = true
	button.tooltip_text = unlock_hint
	_apply_locked_card_styles(button)

	# 深色底色覆盖（遮挡卡面）
	var dark_overlay: ColorRect = ColorRect.new()
	dark_overlay.name = "LockedOverlay"
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_overlay.layout_mode = 1
	dark_overlay.anchor_left = 0.0
	dark_overlay.anchor_top = 0.0
	dark_overlay.anchor_right = 1.0
	dark_overlay.anchor_bottom = 1.0
	dark_overlay.color = Color(0.04, 0.05, 0.08, 0.86)
	button.add_child(dark_overlay)

	# 问号图标（居中）
	var question_label: Label = Label.new()
	question_label.name = "QuestionMark"
	question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	question_label.layout_mode = 1
	question_label.anchor_left = 0.0
	question_label.anchor_top = 0.0
	question_label.anchor_right = 1.0
	question_label.anchor_bottom = 0.6
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.add_theme_font_size_override("font_size", 96)
	question_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 0.88))
	question_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.92))
	question_label.add_theme_constant_override("outline_size", 3)
	question_label.text = "?"
	button.add_child(question_label)

	# 底部解锁提示条
	var hint_band: ColorRect = ColorRect.new()
	hint_band.name = "HintBand"
	hint_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_band.layout_mode = 1
	hint_band.anchor_left = 0.0
	hint_band.anchor_top = 1.0
	hint_band.anchor_right = 1.0
	hint_band.anchor_bottom = 1.0
	hint_band.offset_top = -84.0
	hint_band.color = Color(0.06, 0.08, 0.12, 0.92)
	button.add_child(hint_band)

	# "未解锁"标题
	var locked_title: Label = Label.new()
	locked_title.name = "LockedTitle"
	locked_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_title.layout_mode = 1
	locked_title.anchor_left = 0.0
	locked_title.anchor_top = 1.0
	locked_title.anchor_right = 1.0
	locked_title.anchor_bottom = 1.0
	locked_title.offset_left = 12.0
	locked_title.offset_top = -74.0
	locked_title.offset_right = -12.0
	locked_title.offset_bottom = -50.0
	locked_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_title.add_theme_font_size_override("font_size", 20)
	locked_title.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94, 0.92))
	locked_title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.88))
	locked_title.add_theme_constant_override("outline_size", 2)
	locked_title.text = LocalizationManager.text("meta.locked_card_title")
	button.add_child(locked_title)

	# 解锁条件提示
	var hint_label: Label = Label.new()
	hint_label.name = "UnlockHint"
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.layout_mode = 1
	hint_label.anchor_left = 0.0
	hint_label.anchor_top = 1.0
	hint_label.anchor_right = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = 12.0
	hint_label.offset_top = -48.0
	hint_label.offset_right = -12.0
	hint_label.offset_bottom = -12.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.76, 0.80, 0.88, 0.86))
	hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.84))
	hint_label.add_theme_constant_override("outline_size", 1)
	hint_label.text = unlock_hint
	button.add_child(hint_label)

	# 显示角色归属（让玩家知道这是谁的新牌）
	var owner_id: String = _card_owner_id(card)
	if not owner_id.is_empty():
		var owner_badge: Panel = Panel.new()
		owner_badge.name = "OwnerBadge"
		owner_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owner_badge.layout_mode = 1
		owner_badge.anchor_left = 0.0
		owner_badge.anchor_top = 0.0
		owner_badge.anchor_right = 0.0
		owner_badge.anchor_bottom = 0.0
		owner_badge.offset_left = 12.0
		owner_badge.offset_top = 12.0
		owner_badge.offset_right = 96.0
		owner_badge.offset_bottom = 44.0
		owner_badge.add_theme_stylebox_override("panel", _make_owner_locked_style(owner_id))
		button.add_child(owner_badge)

		var owner_label: Label = Label.new()
		owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owner_label.layout_mode = 1
		owner_label.anchor_left = 0.0
		owner_label.anchor_top = 0.0
		owner_label.anchor_right = 1.0
		owner_label.anchor_bottom = 1.0
		owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		owner_label.add_theme_font_size_override("font_size", 13)
		owner_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.96))
		owner_label.text = LocalizationManager.character_name(owner_id, owner_id.capitalize())
		owner_badge.add_child(owner_label)

	return button


static func _apply_locked_card_styles(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.12, 0.16, 0.92)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_right = 20
	normal.corner_radius_bottom_left = 20
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.42, 0.46, 0.54, 0.56)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	normal.shadow_size = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)


static func _make_owner_locked_style(owner_id: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _card_owner_color(owner_id).darkened(0.34)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = _card_owner_color(owner_id).lightened(0.18)
	return style


static func _apply_card_styles(button: Button, is_upgraded_visual: bool = false) -> void:
	if is_upgraded_visual:
		button.add_theme_stylebox_override("normal", _make_card_style(Color(0, 0, 0, 0), Color(1.0, 0.91, 0.63, 0.72), 5, 12))
		button.add_theme_stylebox_override("hover", _make_card_style(Color(0, 0, 0, 0), Color(1.0, 0.96, 0.76, 1.0), 6, 28))
		button.add_theme_stylebox_override("pressed", _make_card_style(Color(0, 0, 0, 0), Color(1.0, 0.92, 0.72, 0.98), 6, 12))
		button.add_theme_stylebox_override("focus", _make_card_style(Color(0, 0, 0, 0), Color(1.0, 0.96, 0.76, 1.0), 6, 24))
		button.add_theme_stylebox_override("disabled", _make_card_style(Color(0, 0, 0, 0), Color(0.90, 0.84, 0.70, 0.22), 4, 0))
	else:
		button.add_theme_stylebox_override("normal", _make_card_style(Color(0, 0, 0, 0), Color(0.86, 0.95, 1.0, 0.54), 4, 6))
		button.add_theme_stylebox_override("hover", _make_card_style(Color(0, 0, 0, 0), Color(0.90, 0.98, 1.0, 0.98), 5, 24))
		button.add_theme_stylebox_override("pressed", _make_card_style(Color(0, 0, 0, 0), Color(0.80, 0.93, 1.0, 0.94), 5, 10))
		button.add_theme_stylebox_override("focus", _make_card_style(Color(0, 0, 0, 0), Color(0.90, 0.98, 1.0, 0.96), 5, 20))
		button.add_theme_stylebox_override("disabled", _make_card_style(Color(0, 0, 0, 0), Color(0.76, 0.84, 0.92, 0.18), 3, 0))


static func _apply_codex_card_styles(button: Button, is_upgraded_visual: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.08, 0.13, 0.90) if not is_upgraded_visual else Color(0.11, 0.09, 0.07, 0.92)
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_right = 22
	normal.corner_radius_bottom_left = 22
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.62, 0.84, 1.0, 0.26) if not is_upgraded_visual else Color(1.0, 0.88, 0.62, 0.34)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	normal.shadow_size = 6
	normal.content_margin_left = 0
	normal.content_margin_top = 0
	normal.content_margin_right = 0
	normal.content_margin_bottom = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.88, 0.97, 1.0, 0.88) if not is_upgraded_visual else Color(1.0, 0.95, 0.78, 0.92)
	hover.shadow_color = Color(0.64, 0.88, 1.0, 0.18) if not is_upgraded_visual else Color(1.0, 0.88, 0.62, 0.22)
	hover.shadow_size = 16
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.06)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)


static func _make_card_style(bg: Color, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.shadow_color = Color(0.45, 0.84, 1.0, 0.36) if shadow_size > 0 else Color(0, 0, 0, 0)
	style.shadow_size = shadow_size
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


static func _make_inner_frame_style(is_upgraded_visual: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.96, 0.80, 0.34) if is_upgraded_visual else Color(0.92, 0.96, 1.0, 0.18)
	return style


static func _make_badge_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.94, 0.98, 1.0, 0.72)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	return style


static func _make_type_style(card: CardData) -> StyleBoxFlat:
	var color: Color = _card_type_color(card)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.94, 0.98, 1.0, 0.60)
	return style


static func _make_rarity_style(card: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _card_rarity_color(card)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.96, 0.78, 0.68)
	return style


static func _make_upgrade_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.72, 0.96)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.98, 0.86, 0.95)
	style.shadow_color = Color(1.0, 0.88, 0.52, 0.35)
	style.shadow_size = 8
	return style


static func _make_codex_frame_style(is_upgraded_visual: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.98, 1.0, 0.06) if not is_upgraded_visual else Color(1.0, 0.96, 0.86, 0.08)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.78, 0.90, 1.0, 0.54) if not is_upgraded_visual else Color(1.0, 0.90, 0.68, 0.62)
	return style


static func has_upgrade_visual(card: CardData) -> bool:
	return card != null and card.has_meta("upgraded_visual") and bool(card.get_meta("upgraded_visual"))


static func _card_cost_color(card: CardData) -> Color:
	if "Arts" in card.tags:
		return Color(0.15, 0.55, 0.96, 0.92)
	if "Support" in card.tags:
		return Color(0.17, 0.72, 0.80, 0.92)
	if card.card_type == "Curse":
		return Color(0.52, 0.20, 0.62, 0.92)
	return Color(0.82, 0.34, 0.18, 0.92)


static func _card_type_color(card: CardData) -> Color:
	match card.card_type:
		"Attack":
			return Color(0.73, 0.20, 0.16, 0.74)
		"Skill":
			return Color(0.12, 0.42, 0.62, 0.74)
		"Power":
			return Color(0.60, 0.34, 0.12, 0.74)
		"Curse":
			return Color(0.42, 0.16, 0.52, 0.74)
	return Color(0.18, 0.28, 0.40, 0.74)


static func _card_rarity_color(card: CardData) -> Color:
	if card == null:
		return Color(0.26, 0.30, 0.36, 0.76)
	match Util.card_rarity_tier(card):
		"elite":
			return Color(0.32, 0.42, 0.72, 0.82)
		"rare":
			return Color(0.74, 0.48, 0.14, 0.88)
		"starter":
			return Color(0.42, 0.46, 0.48, 0.76)
		"status":
			return Color(0.42, 0.18, 0.50, 0.82)
	return Color(0.25, 0.48, 0.38, 0.78)


static func _card_type_label(card: CardData) -> String:
	if card == null:
		return ""
	var is_zh: bool = String(LocalizationManager.current_language) == "zh"
	match card.card_type:
		"Attack":
			return "攻击" if is_zh else "ATTACK"
		"Skill":
			return "技能" if is_zh else "SKILL"
		"Power":
			return "能力" if is_zh else "POWER"
		"Curse":
			return "诅咒" if is_zh else "CURSE"
		"Status":
			return "状态" if is_zh else "STATUS"
	return String(card.card_type)

static func _card_rarity_label(card: CardData) -> String:
	if card == null:
		return ""
	return LocalizationManager.rarity_name(card.rarity)

static func _upgrade_badge_label() -> String:
	return "升" if String(LocalizationManager.current_language) == "zh" else "UP"


# ===== 暴露给 card_hover_preview 的 public 方法 =====

static func keyword_badges_for_preview(card: CardData) -> Array[Dictionary]:
	return _card_keyword_badges(card, 5)

static func term_lines_for_preview(card: CardData) -> Array[String]:
	return _card_tooltip_term_lines(card)

static func owner_terms_line_for_preview(owner_id: String) -> String:
	return _card_owner_terms_line(owner_id)

static func make_keyword_badge_for_preview(spec: Dictionary) -> PanelContainer:
	return _make_keyword_badge(spec, false)


static func _build_tooltip_text(card: CardData, card_name: String, card_description: String) -> String:
	var lines: Array[String] = [card_name, card_description]
	if card != null:
		lines.append(LocalizationManager.text("card.tooltip_rarity", [_card_rarity_label(card)]))
	var owner_id: String = _card_owner_id(card)
	var owner_line: String = _card_owner_tooltip_line(owner_id)
	if not owner_line.is_empty():
		lines.append(owner_line)
	var owner_terms_line: String = _card_owner_terms_line(owner_id)
	if not owner_terms_line.is_empty():
		lines.append(owner_terms_line)
	var keyword_names: Array[String] = _card_keyword_names(card, 5)
	if not keyword_names.is_empty():
		lines.append(LocalizationManager.text("card.tooltip_tags", [" / ".join(keyword_names)]))
	var term_lines: Array[String] = _card_tooltip_term_lines(card)
	if not term_lines.is_empty():
		lines.append("")
		lines.append(LocalizationManager.text("card.tooltip_terms"))
		lines.append_array(term_lines)
	return "\n".join(lines)


static func _card_keyword_badges(card: CardData, max_count: int = 2) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	if card == null:
		return badges
	for spec in _card_keyword_specs():
		if _card_has_tag(card, String(spec.get("tag", ""))):
			badges.append(spec)
		if badges.size() >= max_count:
			break
	return badges


static func _card_keyword_names(card: CardData, max_count: int = 5) -> Array[String]:
	var names: Array[String] = []
	for spec in _card_keyword_badges(card, max_count):
		names.append(_keyword_label(spec))
	return names


static func _card_tooltip_term_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = []
	var seen_terms: Array[String] = []
	for spec in _card_keyword_specs():
		if not _card_has_tag(card, String(spec.get("tag", ""))):
			continue
		var body_key: String = String(spec.get("term_body_key", ""))
		if body_key.is_empty() or seen_terms.has(body_key):
			continue
		seen_terms.append(body_key)
		var title: String = String(spec.get("tooltip_name", _keyword_label(spec)))
		var body: String = LocalizationManager.text(body_key)
		lines.append("%s：%s" % [title, _short_glossary_summary(body)])
	return lines


static func _short_glossary_summary(body: String) -> String:
	var cleaned: String = body.replace("%%", "%").replace("\n", " ").strip_edges()
	if cleaned.is_empty():
		return ""
	if "。" in cleaned:
		return cleaned.get_slice("。", 0).strip_edges() + "。"
	if ". " in cleaned:
		return cleaned.get_slice(". ", 0).strip_edges() + "."
	return cleaned


static func _card_has_tag(card: CardData, tag_name: String) -> bool:
	if card == null:
		return false
	var expected: String = tag_name.to_lower()
	for tag in card.tags:
		if String(tag).to_lower() == expected:
			return true
	return false


static func _card_owner_id(card: CardData) -> String:
	if card == null:
		return ""
	return Util.card_owner(card.id)


static func _card_owner_color(owner_id: String) -> Color:
	match owner_id:
		"amiya":
			return Color(0.22, 0.52, 0.90, 0.92)
		"nearl":
			return Color(0.72, 0.58, 0.18, 0.92)
		"exusiai":
			return Color(0.76, 0.24, 0.28, 0.92)
		"kaltsit":
			return Color(0.18, 0.60, 0.46, 0.92)
		_:
			return Color(0.24, 0.34, 0.46, 0.92)


static func _card_owner_tooltip_line(owner_id: String) -> String:
	if owner_id.is_empty():
		return ""
	var is_zh: bool = String(LocalizationManager.current_language) == "zh"
	match owner_id:
		"amiya":
			return "所属：阿米娅" if is_zh else "Operator: Amiya"
		"nearl":
			return "所属：临光" if is_zh else "Operator: Nearl"
		"exusiai":
			return "所属：能天使" if is_zh else "Operator: Exusiai"
		"kaltsit":
			return "所属：凯尔希" if is_zh else "Operator: Kal'tsit"
		_:
			return ""


static func _card_owner_terms_line(owner_id: String) -> String:
	if owner_id.is_empty():
		return ""
	var is_zh: bool = String(LocalizationManager.current_language) == "zh"
	match owner_id:
		"amiya":
			return "核心术语：意志 / 共振 / 回响 / 支援 / 过载" if is_zh else "Core terms: Will / Resonance / Echo / Support / Overload"
		"nearl":
			return "核心术语：护盾 / 回复 / 救援 / 支援" if is_zh else "Core terms: Block / Heal / Rescue / Support"
		"exusiai":
			return "核心术语：射击 / 弹药 / 装填 / 标记 / 爆发" if is_zh else "Core terms: Shot / Ammo / Reload / Mark / Burst"
		"kaltsit":
			return "核心术语：Mon3tr / 完整性 / 医疗 / 修复 / 指令：融毁" if is_zh else "Core terms: Mon3tr / Integrity / Medical / Repair / Meltdown"
		_:
			return ""


static func _card_keyword_specs() -> Array[Dictionary]:
	return [
		{"tag": "Support", "zh": "支援", "en": "SUPPORT", "tooltip_name": "支援", "term_body_key": "codex.term_support_body", "fill": Color(0.12, 0.58, 0.66, 0.92), "border": Color(0.76, 0.97, 1.0, 0.92)},
		{"tag": "Command", "zh": "指挥", "en": "COMMAND", "tooltip_name": "指挥", "term_body_key": "codex.term_command_body", "fill": Color(0.16, 0.60, 0.74, 0.92), "border": Color(0.80, 0.98, 1.0, 0.94)},
		{"tag": "Mon3tr", "zh": "Mon3tr", "en": "MON3TR", "tooltip_name": "Mon3tr", "term_body_key": "codex.term_mon3tr_body", "fill": Color(0.16, 0.48, 0.30, 0.92), "border": Color(0.76, 1.0, 0.82, 0.94)},
		{"tag": "Medical", "zh": "医疗", "en": "MED", "tooltip_name": "医疗", "term_body_key": "codex.term_medical_body", "fill": Color(0.18, 0.56, 0.38, 0.92), "border": Color(0.78, 1.0, 0.86, 0.94)},
		{"tag": "Repair", "zh": "修复", "en": "REPAIR", "tooltip_name": "修复", "term_body_key": "codex.term_integrity_body", "fill": Color(0.22, 0.54, 0.44, 0.92), "border": Color(0.80, 1.0, 0.92, 0.94)},
		{"tag": "Integrity", "zh": "完整性", "en": "INTEG.", "tooltip_name": "完整性", "term_body_key": "codex.term_integrity_body", "fill": Color(0.24, 0.42, 0.34, 0.92), "border": Color(0.84, 1.0, 0.86, 0.94)},
		{"tag": "Meltdown", "zh": "融毁", "en": "MELT", "tooltip_name": "指令：融毁", "term_body_key": "codex.term_meltdown_body", "fill": Color(0.74, 0.30, 0.14, 0.92), "border": Color(1.0, 0.82, 0.62, 0.94)},
		{"tag": "Protocol", "zh": "协议", "en": "PROTO", "tooltip_name": "协议", "term_body_key": "codex.term_protocol_body", "fill": Color(0.30, 0.42, 0.34, 0.92), "border": Color(0.84, 1.0, 0.84, 0.94)},
		{"tag": "Scalpel", "zh": "手术刀", "en": "SCALP.", "tooltip_name": "手术刀", "term_body_key": "codex.term_scalpel_body", "fill": Color(0.32, 0.48, 0.52, 0.92), "border": Color(0.82, 0.98, 1.0, 0.94)},
		{"tag": "Tactic", "zh": "战术", "en": "TACTIC", "tooltip_name": "战术", "term_body_key": "codex.term_tactic_body", "fill": Color(0.40, 0.34, 0.22, 0.92), "border": Color(1.0, 0.90, 0.72, 0.92)},
		{"tag": "Arts", "zh": "术式", "en": "ARTS", "tooltip_name": "术式", "term_body_key": "codex.term_arts_body", "fill": Color(0.18, 0.44, 0.82, 0.92), "border": Color(0.82, 0.92, 1.0, 0.94)},
		{"tag": "Resonance", "zh": "共振", "en": "RESON.", "tooltip_name": "共振", "term_body_key": "codex.term_resonance_body", "fill": Color(0.18, 0.42, 0.78, 0.92), "border": Color(0.72, 0.88, 1.0, 0.94)},
		{"tag": "Echo", "zh": "回响", "en": "ECHO", "tooltip_name": "回响", "term_body_key": "codex.term_echo_body", "fill": Color(0.42, 0.30, 0.78, 0.92), "border": Color(0.88, 0.82, 1.0, 0.94)},
		{"tag": "Channel", "zh": "引导", "en": "CHANNEL", "tooltip_name": "引导", "term_body_key": "codex.term_channel_body", "fill": Color(0.24, 0.46, 0.62, 0.92), "border": Color(0.80, 0.92, 1.0, 0.92)},
		{"tag": "Overload", "zh": "过载", "en": "OVERLD", "tooltip_name": "过载", "term_body_key": "codex.term_overload_body", "fill": Color(0.70, 0.26, 0.24, 0.92), "border": Color(1.0, 0.78, 0.74, 0.94)},
		{"tag": "WillSpend", "zh": "耗志", "en": "WILL", "tooltip_name": "耗志", "term_body_key": "codex.term_will_body", "fill": Color(0.34, 0.28, 0.66, 0.92), "border": Color(0.86, 0.82, 1.0, 0.94)},
		{"tag": "WillGain", "zh": "蓄志", "en": "WILL+", "tooltip_name": "意志", "term_body_key": "codex.term_will_body", "fill": Color(0.28, 0.34, 0.74, 0.92), "border": Color(0.84, 0.88, 1.0, 0.94)},
		{"tag": "Will", "zh": "意志", "en": "WILL", "tooltip_name": "意志", "term_body_key": "codex.term_will_body", "fill": Color(0.28, 0.34, 0.74, 0.92), "border": Color(0.84, 0.88, 1.0, 0.94)},
		{"tag": "Block", "zh": "护盾", "en": "BLOCK", "tooltip_name": "护盾", "term_body_key": "codex.term_block_body", "fill": Color(0.24, 0.34, 0.48, 0.92), "border": Color(0.84, 0.92, 1.0, 0.92)},
		{"tag": "Heal", "zh": "回复", "en": "HEAL", "tooltip_name": "回复", "term_body_key": "codex.term_heal_body", "fill": Color(0.20, 0.58, 0.40, 0.92), "border": Color(0.80, 1.0, 0.86, 0.92)},
		{"tag": "Rescue", "zh": "救援", "en": "RESCUE", "tooltip_name": "救援", "term_body_key": "codex.term_rescue_body", "fill": Color(0.24, 0.54, 0.38, 0.92), "border": Color(0.84, 0.98, 0.82, 0.92)},
		{"tag": "Curse", "zh": "诅咒", "en": "CURSE", "tooltip_name": "诅咒", "term_body_key": "codex.term_curse_body", "fill": Color(0.46, 0.20, 0.58, 0.92), "border": Color(0.92, 0.78, 1.0, 0.92)},
		{"tag": "Status", "zh": "状态", "en": "STATUS", "tooltip_name": "状态牌", "term_body_key": "codex.term_status_body", "fill": Color(0.34, 0.38, 0.48, 0.92), "border": Color(0.88, 0.92, 0.98, 0.92)},
		{"tag": "MultiHit", "zh": "连击", "en": "MULTI", "tooltip_name": "连击", "term_body_key": "codex.term_multihit_body", "fill": Color(0.22, 0.48, 0.72, 0.92), "border": Color(0.78, 0.92, 1.0, 0.92)},
		{"tag": "AOE", "zh": "范围", "en": "AOE", "tooltip_name": "范围伤害", "term_body_key": "codex.term_aoe_body", "fill": Color(0.62, 0.34, 0.18, 0.92), "border": Color(1.0, 0.86, 0.70, 0.92)},
		{"tag": "AoE", "zh": "范围", "en": "AOE", "tooltip_name": "范围伤害", "term_body_key": "codex.term_aoe_body", "fill": Color(0.62, 0.34, 0.18, 0.92), "border": Color(1.0, 0.86, 0.70, 0.92)},
		{"tag": "Shot", "zh": "射击", "en": "SHOT", "tooltip_name": "射击", "term_body_key": "codex.term_shot_body", "fill": Color(0.76, 0.28, 0.28, 0.92), "border": Color(1.0, 0.82, 0.80, 0.94)},
		{"tag": "AmmoUse", "zh": "耗弹", "en": "AMMO-", "tooltip_name": "弹药", "term_body_key": "codex.term_ammo_body", "fill": Color(0.72, 0.22, 0.20, 0.92), "border": Color(1.0, 0.80, 0.74, 0.94)},
		{"tag": "AmmoGain", "zh": "补弹", "en": "AMMO+", "tooltip_name": "弹药", "term_body_key": "codex.term_ammo_body", "fill": Color(0.22, 0.52, 0.78, 0.92), "border": Color(0.84, 0.94, 1.0, 0.94)},
		{"tag": "Reload", "zh": "装填", "en": "RELOAD", "tooltip_name": "装填", "term_body_key": "codex.term_reload_body", "fill": Color(0.28, 0.48, 0.68, 0.92), "border": Color(0.84, 0.94, 1.0, 0.94)},
		{"tag": "Mark", "zh": "标记", "en": "MARK", "tooltip_name": "标记", "term_body_key": "codex.term_mark_body", "fill": Color(0.56, 0.22, 0.52, 0.92), "border": Color(0.94, 0.80, 0.98, 0.94)},
		{"tag": "Burst", "zh": "爆发", "en": "BURST", "tooltip_name": "爆发", "term_body_key": "codex.term_burst_body", "fill": Color(0.78, 0.32, 0.18, 0.92), "border": Color(1.0, 0.86, 0.70, 0.94)},
		{"tag": "Tempo", "zh": "节奏", "en": "TEMPO", "tooltip_name": "节奏", "term_body_key": "codex.term_tempo_body", "fill": Color(0.24, 0.52, 0.58, 0.92), "border": Color(0.82, 0.98, 1.0, 0.94)},
		{"tag": "Finisher", "zh": "终结", "en": "FINISH", "tooltip_name": "终结", "term_body_key": "codex.term_finisher_body", "fill": Color(0.80, 0.28, 0.24, 0.92), "border": Color(1.0, 0.82, 0.78, 0.94)}
	]


static func _keyword_label(spec: Dictionary) -> String:
	if String(LocalizationManager.current_language) == "zh":
		return String(spec.get("zh", spec.get("tag", "")))
	return String(spec.get("en", spec.get("tag", "")))


static func _make_keyword_badge(spec: Dictionary, compact: bool = false) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(0.0, 28.0 if compact else 24.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = spec.get("fill", Color(0.20, 0.30, 0.42, 0.90))
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = spec.get("border", Color(0.94, 0.98, 1.0, 0.60))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 4
	badge.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12 if compact else 10)
	label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.82))
	label.add_theme_constant_override("outline_size", 1)
	label.text = _keyword_label(spec)
	badge.add_child(label)
	return badge


static func _make_inline_badge(text_value: String, fill: Color, border: Color, font_size: int) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(0, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	badge.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	badge.add_child(margin)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.layout_mode = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.82))
	label.add_theme_constant_override("outline_size", 1)
	label.text = text_value
	margin.add_child(label)
	return badge
