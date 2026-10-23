class_name CardGalleryOverlay
extends Control

signal closed

const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

var overlay_title: String = ""
var cards: Array[CardData] = []
var sections: Array[Dictionary] = []
# 卡牌图鉴模式（setup_sections 进入）：显示搜索筛选栏；
# 牌堆/抽牌堆浏览模式（setup 进入）：不显示搜索筛选栏
var gallery_mode: bool = false

var title_label: Label
var close_button: Button
var content_box: VBoxContainer
var empty_label: Label
var frame: PanelContainer
# 搜索筛选控件
var search_box: LineEdit
var rarity_chips: Dictionary = {}  # rarity -> Button
var owner_chips: Dictionary = {}   # owner_id -> Button
var search_query: String = ""
var active_rarities: Array[String] = []
var active_owners: Array[String] = []


func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_ui()
	_render()


func setup(title_text: String, card_list: Array[CardData]) -> void:
	overlay_title = title_text
	gallery_mode = false
	cards.clear()
	sections.clear()
	for card in card_list:
		cards.append(card)
	if is_inside_tree():
		_render()


func setup_sections(title_text: String, grouped_sections: Array[Dictionary]) -> void:
	overlay_title = title_text
	gallery_mode = true
	cards.clear()
	sections.clear()
	for section in grouped_sections:
		sections.append(section.duplicate(true))
	if is_inside_tree():
		_render()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.layout_mode = 1
	shade.anchor_left = 0.0
	shade.anchor_top = 0.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.color = Color(0.02, 0.03, 0.05, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	frame = PanelContainer.new()
	frame.layout_mode = 1
	frame.anchor_left = 0.08
	frame.anchor_top = 0.08
	frame.anchor_right = 0.92
	frame.anchor_bottom = 0.92
	frame.self_modulate = Color(1, 1, 1, 0.95)
	add_child(frame)
	UI_THEME_KIT.apply_glass_panel_blurred(frame, 2.8)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)

	var root := VBoxContainer.new()
	root.layout_mode = 2
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.layout_mode = 2
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	title_label = Label.new()
	title_label.layout_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_heading(title_label, 34, Color(0.98, 0.95, 0.82, 1.0), Color(0.04, 0.04, 0.06, 0.82))
	header.add_child(title_label)

	close_button = Button.new()
	close_button.layout_mode = 2
	close_button.custom_minimum_size = Vector2(64, 52)
	close_button.text = LocalizationManager.text("overlay.close")
	UI_THEME_KIT.apply_stone_button(close_button, "ghost", 22)
	UI_MOTION.wire_button_feedback(close_button, 1.02, 0.98, Color(0.88, 0.96, 1.0, 0.72), 5.0)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# 搜索筛选栏（仅卡牌图鉴模式下显示）
	if gallery_mode:
		_build_search_filter_bar(root)

	var scroll := ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.layout_mode = 2
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 18)
	scroll.add_child(content_box)

	empty_label = Label.new()
	empty_label.layout_mode = 2
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_body(empty_label, 24, Color(0.93, 0.94, 0.98, 0.84))
	root.add_child(empty_label)
	call_deferred("_play_intro_animation")


func _render() -> void:
	if title_label == null:
		return
	title_label.text = overlay_title
	close_button.text = LocalizationManager.text("overlay.close")

	for child in content_box.get_children():
		child.queue_free()

	if not sections.is_empty():
		var rendered_any: bool = _render_sections()
		empty_label.visible = not rendered_any
		empty_label.text = LocalizationManager.text("overlay.empty_cards")
		return

	if cards.is_empty():
		empty_label.visible = true
		empty_label.text = LocalizationManager.text("overlay.empty_cards")
		return

	empty_label.visible = false
	var empty_locked: Array[CardData] = []
	content_box.add_child(_make_card_section({
		"title": overlay_title,
		"cards": cards
	}, cards, empty_locked))


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _play_intro_animation() -> void:
	if frame == null:
		return
	UI_MOTION.reveal(frame, 0.03, Vector2(0, 18), 0.26, Vector2(0.99, 0.99))


func _render_sections() -> bool:
	var rendered_any: bool = false
	var has_filters: bool = not search_query.strip_edges().is_empty() or not active_rarities.is_empty() or not active_owners.is_empty()
	for section in sections:
		var section_cards: Array[CardData] = _section_cards(section.get("cards", []))
		var locked_cards: Array[CardData] = _section_cards(section.get("locked_cards", []))
		# 应用搜索筛选
		if has_filters:
			section_cards = _filter_cards(section_cards)
			# 搜索时隐藏锁定卡（搜索的是已解锁卡的名称/描述）
			locked_cards = []
		if section_cards.is_empty() and locked_cards.is_empty():
			continue
		content_box.add_child(_make_card_section(section, section_cards, locked_cards))
		rendered_any = true
	return rendered_any


# 按搜索词 + 稀有度 + 角色筛选卡牌
func _filter_cards(card_list: Array[CardData]) -> Array[CardData]:
	var result: Array[CardData] = []
	var query: String = search_query.to_lower().strip_edges()
	for card in card_list:
		if card == null:
			continue
		# 稀有度筛选
		if not active_rarities.is_empty():
			if not active_rarities.has(String(card.rarity)):
				continue
		# 角色筛选
		if not active_owners.is_empty():
			var owner_id: String = Util.card_owner(card.id)
			if not active_owners.has(owner_id):
				continue
		# 搜索词筛选（匹配卡牌名/描述/ID）
		if not query.is_empty():
			var name_text: String = LocalizationManager.card_name(card).to_lower()
			var desc_text: String = LocalizationManager.card_description(card).to_lower()
			if not name_text.contains(query) and not desc_text.contains(query) and not String(card.id).to_lower().contains(query):
				continue
		result.append(card)
	return result


# 搜索筛选栏：搜索框 + 稀有度 chips + 角色 chips
func _build_search_filter_bar(parent: VBoxContainer) -> void:
	var filter_root := VBoxContainer.new()
	filter_root.layout_mode = 2
	filter_root.add_theme_constant_override("separation", 8)
	parent.add_child(filter_root)

	# 搜索框
	search_box = LineEdit.new()
	search_box.layout_mode = 2
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.placeholder_text = LocalizationManager.text("codex.search_placeholder")
	search_box.clear_button_enabled = true
	search_box.custom_minimum_size = Vector2(0, 44)
	UI_THEME_KIT.apply_line_edit(search_box, 18)
	search_box.text_changed.connect(_on_search_changed)
	filter_root.add_child(search_box)

	# 稀有度 chips 行
	var rarity_row := HBoxContainer.new()
	rarity_row.layout_mode = 2
	rarity_row.add_theme_constant_override("separation", 8)
	filter_root.add_child(_make_filter_row_label(LocalizationManager.text("codex.filter_rarity"), rarity_row))
	var rarities: Array[String] = ["Common", "Uncommon", "Rare", "Curse"]
	for rarity in rarities:
		var chip := Button.new()
		chip.layout_mode = 2
		chip.text = _rarity_chip_label(rarity)
		UI_THEME_KIT.apply_filter_chip(chip, false, _rarity_color(rarity), 15)
		chip.toggled.connect(_on_rarity_chip_toggled.bind(rarity))
		rarity_chips[rarity] = chip
		rarity_row.add_child(chip)

	# 角色 chips 行
	var owner_row := HBoxContainer.new()
	owner_row.layout_mode = 2
	owner_row.add_theme_constant_override("separation", 8)
	filter_root.add_child(_make_filter_row_label(LocalizationManager.text("codex.filter_character"), owner_row))
	var owner_ids: Array[String] = ["amiya", "nearl", "exusiai", "kaltsit"]
	for owner_id in owner_ids:
		var chip := Button.new()
		chip.layout_mode = 2
		chip.text = LocalizationManager.character_name(owner_id, owner_id.capitalize())
		UI_THEME_KIT.apply_filter_chip(chip, false, _owner_color(owner_id), 15)
		chip.toggled.connect(_on_owner_chip_toggled.bind(owner_id))
		owner_chips[owner_id] = chip
		owner_row.add_child(chip)


# 辅助：给 chips 行加个标题标签
func _make_filter_row_label(text: String, row: HBoxContainer) -> HBoxContainer:
	var wrapper := HBoxContainer.new()
	wrapper.layout_mode = 2
	wrapper.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.layout_mode = 2
	UI_THEME_KIT.apply_body(label, 15, Color(0.78, 0.82, 0.88, 0.82))
	label.text = text
	wrapper.add_child(label)
	wrapper.add_child(row)
	return wrapper


func _rarity_chip_label(rarity: String) -> String:
	match rarity:
		"Common":
			return LocalizationManager.text("card.rarity_common")
		"Uncommon":
			return LocalizationManager.text("card.rarity_uncommon")
		"Rare":
			return LocalizationManager.text("card.rarity_rare")
		"Curse":
			return LocalizationManager.text("card.rarity_curse")
	return rarity


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":
			return Color(0.78, 0.82, 0.88, 1.0)
		"Uncommon":
			return Color(0.56, 0.86, 0.74, 1.0)
		"Rare":
			return Color(0.96, 0.82, 0.48, 1.0)
		"Curse":
			return Color(0.88, 0.58, 0.72, 1.0)
	return Color(0.80, 0.82, 0.86, 1.0)


func _owner_color(owner_id: String) -> Color:
	match owner_id:
		"amiya":
			return Color(0.72, 0.80, 1.0, 1.0)
		"nearl":
			return Color(0.96, 0.86, 0.58, 1.0)
		"exusiai":
			return Color(0.92, 0.62, 0.58, 1.0)
		"kaltsit":
			return Color(0.58, 0.92, 0.84, 1.0)
	return Color(0.80, 0.82, 0.86, 1.0)


func _on_search_changed(new_text: String) -> void:
	search_query = new_text
	_render()


func _on_rarity_chip_toggled(pressed: bool, rarity: String) -> void:
	if pressed:
		if not active_rarities.has(rarity):
			active_rarities.append(rarity)
	else:
		active_rarities.erase(rarity)
	# 重新应用 chip 样式以反映 toggle 状态
	var chip: Button = rarity_chips.get(rarity)
	if chip != null:
		UI_THEME_KIT.apply_filter_chip(chip, pressed, _rarity_color(rarity), 15)
	_render()


func _on_owner_chip_toggled(pressed: bool, owner_id: String) -> void:
	if pressed:
		if not active_owners.has(owner_id):
			active_owners.append(owner_id)
	else:
		active_owners.erase(owner_id)
	# 重新应用 chip 样式以反映 toggle 状态
	var chip: Button = owner_chips.get(owner_id)
	if chip != null:
		UI_THEME_KIT.apply_filter_chip(chip, pressed, _owner_color(owner_id), 15)
	_render()


func _make_card_section(section: Dictionary, filtered_cards: Array[CardData], filtered_locked: Array[CardData]) -> VBoxContainer:
	var section_box := VBoxContainer.new()
	section_box.layout_mode = 2
	section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_box.add_theme_constant_override("separation", 12)

	var title_text: String = String(section.get("title", ""))
	var subtitle_text: String = String(section.get("subtitle", ""))
	var accent_variant: Variant = section.get("accent", Color(0.84, 0.92, 1.0, 0.86))
	var accent: Color = accent_variant if typeof(accent_variant) == TYPE_COLOR else Color(0.84, 0.92, 1.0, 0.86)

	if not title_text.is_empty():
		var title := Label.new()
		title.layout_mode = 2
		UI_THEME_KIT.apply_heading(title, 28, accent, Color(0.04, 0.04, 0.06, 0.82))
		title.text = title_text
		section_box.add_child(title)

	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.layout_mode = 2
		UI_THEME_KIT.apply_body(subtitle, 18, Color(0.92, 0.95, 0.98, 0.90))
		subtitle.text = subtitle_text
		section_box.add_child(subtitle)

	var section_cards: Array[CardData] = filtered_cards
	if not section_cards.is_empty():
		section_box.add_child(_make_cards_grid(section_cards))

	# 杀戮尖塔风格：锁定卡牌占位区
	var locked_cards: Array[CardData] = filtered_locked
	if not locked_cards.is_empty():
		var locked_header := Label.new()
		locked_header.layout_mode = 2
		UI_THEME_KIT.apply_body(locked_header, 16, Color(0.72, 0.76, 0.84, 0.82))
		locked_header.text = LocalizationManager.text("meta.locked_section_title")
		section_box.add_child(locked_header)
		section_box.add_child(_make_locked_cards_grid(locked_cards))

	return section_box


func _make_locked_cards_grid(card_list: Array[CardData]) -> VBoxContainer:
	const CARDS_PER_ROW := 4
	var list := VBoxContainer.new()
	list.name = "LockedCardsGrid"
	list.layout_mode = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)

	var row := HBoxContainer.new()
	row.name = "LockedCardsRow"
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	list.add_child(row)

	var count_in_row: int = 0
	for card in card_list:
		if count_in_row == CARDS_PER_ROW:
			row = HBoxContainer.new()
			row.name = "LockedCardsRow"
			row.layout_mode = 2
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			list.add_child(row)
			count_in_row = 0
		var unlock_hint: String = LocalizationManager.text("meta.locked_card_hint_default")
		var button: Button = CARD_DISPLAY_FACTORY.create_locked_card_button(
			card,
			unlock_hint,
			CARD_DISPLAY_FACTORY.gallery_card_size()
		)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.modulate = Color(0.82, 0.84, 0.88, 1.0)
		row.add_child(button)
		count_in_row += 1
	return list


func _make_cards_grid(card_list: Array[CardData]) -> VBoxContainer:
	const CARDS_PER_ROW := 4
	var list := VBoxContainer.new()
	list.name = "CardsGrid"
	list.layout_mode = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)

	var row := HBoxContainer.new()
	row.name = "CardsRow"
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	list.add_child(row)

	var count_in_row: int = 0
	for card in card_list:
		if count_in_row == CARDS_PER_ROW:
			row = HBoxContainer.new()
			row.name = "CardsRow"
			row.layout_mode = 2
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			list.add_child(row)
			count_in_row = 0
		var button: Button = CARD_DISPLAY_FACTORY.create_card_button(
			card,
			LocalizationManager.card_name(card),
			LocalizationManager.card_description(card),
			card.cost,
			Util.load_card_art(card.id),
			CARD_DISPLAY_FACTORY.gallery_card_size(),
			true,
			CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
		)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
		count_in_row += 1
	return list


func _section_cards(raw_cards: Variant) -> Array[CardData]:
	var result: Array[CardData] = []
	if typeof(raw_cards) != TYPE_ARRAY:
		return result
	for card_variant in raw_cards:
		var card: CardData = card_variant as CardData
		if card != null:
			result.append(card)
	return result
