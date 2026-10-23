class_name CompendiumOverlay
extends Control

signal closed

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

var overlay_title: String = ""
var entries: Array[Dictionary] = []
var sections: Array[Dictionary] = []

var title_label: Label
var count_label: Label
var close_button: Button
var list_box: VBoxContainer
var empty_label: Label
var frame: PanelContainer


func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_ui()
	_render()


func setup(title_text: String, overlay_entries: Array[Dictionary]) -> void:
	overlay_title = title_text
	entries.clear()
	sections.clear()
	for entry in overlay_entries:
		entries.append(entry.duplicate(true))
	if is_inside_tree():
		_render()


func setup_sections(title_text: String, grouped_sections: Array[Dictionary]) -> void:
	overlay_title = title_text
	entries.clear()
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
	shade.color = Color(0.02, 0.03, 0.05, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	frame = PanelContainer.new()
	frame.layout_mode = 1
	frame.anchor_left = 0.08
	frame.anchor_top = 0.08
	frame.anchor_right = 0.92
	frame.anchor_bottom = 0.92
	frame.self_modulate = Color(1, 1, 1, 0.98)
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
	root.add_child(header)

	title_label = Label.new()
	title_label.layout_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_heading(title_label, 34, Color(0.98, 0.95, 0.82, 1.0), Color(0.04, 0.04, 0.06, 0.82))
	header.add_child(title_label)

	var count_panel := PanelContainer.new()
	count_panel.layout_mode = 2
	count_panel.custom_minimum_size = Vector2(116, 44)
	UI_THEME_KIT.apply_paper_panel(count_panel)
	header.add_child(count_panel)

	var count_margin := MarginContainer.new()
	count_margin.layout_mode = 2
	count_margin.add_theme_constant_override("margin_left", 12)
	count_margin.add_theme_constant_override("margin_top", 8)
	count_margin.add_theme_constant_override("margin_right", 12)
	count_margin.add_theme_constant_override("margin_bottom", 8)
	count_panel.add_child(count_margin)

	count_label = Label.new()
	count_label.layout_mode = 2
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI_THEME_KIT.apply_numeric(count_label, 18, Color(0.22, 0.16, 0.10, 1.0), Color(1.0, 1.0, 1.0, 0.12))
	count_margin.add_child(count_label)

	close_button = Button.new()
	close_button.layout_mode = 2
	close_button.custom_minimum_size = Vector2(76, 52)
	UI_THEME_KIT.apply_stone_button(close_button, "ghost", 22)
	UI_MOTION.wire_button_feedback(close_button, 1.02, 0.98, Color(0.88, 0.96, 1.0, 0.72), 5.0)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.layout_mode = 2
	list_box.add_theme_constant_override("separation", 14)
	scroll.add_child(list_box)

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
	count_label.text = LocalizationManager.text("overlay.count", [_entry_total_count()])
	close_button.text = LocalizationManager.text("overlay.close")
	for child in list_box.get_children():
		child.queue_free()

	if not sections.is_empty():
		var rendered_sections: bool = _render_sections()
		empty_label.visible = not rendered_sections
		empty_label.text = LocalizationManager.text("overlay.empty_entries")
		return

	if entries.is_empty():
		empty_label.visible = true
		empty_label.text = LocalizationManager.text("overlay.empty_entries")
		return

	empty_label.visible = false
	var use_grid: bool = false
	if not entries.is_empty():
		use_grid = String(entries[0].get("display_mode", "")) == "grid"
	if use_grid:
		_render_grid_entries_into(list_box, entries)
	else:
		for entry in entries:
			list_box.add_child(_make_entry_panel(entry))


func _render_sections() -> bool:
	var rendered_any: bool = false
	for section in sections:
		var section_entries: Array[Dictionary] = _dictionary_array(section.get("entries", []))
		if section_entries.is_empty():
			continue
		list_box.add_child(_make_section_block(section, section_entries))
		rendered_any = true
	return rendered_any


func _make_section_block(section: Dictionary, section_entries: Array[Dictionary]) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.layout_mode = 2
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 12)

	var title_text: String = String(section.get("title", ""))
	var subtitle_text: String = String(section.get("subtitle", ""))
	var body_text: String = String(section.get("body", ""))
	var accent_variant: Variant = section.get("accent", Color(0.84, 0.92, 1.0, 0.86))
	var accent: Color = accent_variant if typeof(accent_variant) == TYPE_COLOR else Color(0.84, 0.92, 1.0, 0.86)

	if not title_text.is_empty():
		var title := Label.new()
		title.layout_mode = 2
		UI_THEME_KIT.apply_heading(title, 28, accent, Color(0.04, 0.04, 0.06, 0.82))
		title.text = title_text
		block.add_child(title)

	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.layout_mode = 2
		UI_THEME_KIT.apply_body(subtitle, 18, Color(0.94, 0.95, 0.98, 0.90))
		subtitle.text = subtitle_text
		block.add_child(subtitle)

	if not body_text.is_empty():
		var body := Label.new()
		body.layout_mode = 2
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI_THEME_KIT.apply_body(body, 18, Color(0.88, 0.92, 0.97, 0.88))
		body.text = body_text
		block.add_child(body)

	if String(section.get("display_mode", "list")) == "grid":
		_render_grid_entries_into(block, section_entries)
	elif int(section.get("entry_columns", 1)) > 1:
		_render_list_columns_into(block, section_entries, max(1, int(section.get("entry_columns", 1))))
	else:
		for entry in section_entries:
			block.add_child(_make_entry_panel(entry))
	return block


func _render_grid_entries_into(parent: VBoxContainer, grid_entries: Array[Dictionary]) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var count_in_row: int = 0
	for entry in grid_entries:
		if count_in_row == 5:
			row = HBoxContainer.new()
			row.layout_mode = 2
			row.add_theme_constant_override("separation", 14)
			parent.add_child(row)
			count_in_row = 0
		row.add_child(_make_grid_entry_panel(entry))
		count_in_row += 1
	while count_in_row < 5:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 0)
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		count_in_row += 1


func _render_list_columns_into(parent: VBoxContainer, column_entries: Array[Dictionary], columns: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var count_in_row: int = 0
	for entry in column_entries:
		if count_in_row == columns:
			row = HBoxContainer.new()
			row.layout_mode = 2
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 16)
			parent.add_child(row)
			count_in_row = 0
		var panel: PanelContainer = _make_entry_panel(entry)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		count_in_row += 1
	while count_in_row < columns:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 0)
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		count_in_row += 1


func _make_entry_panel(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var operator_layout: bool = String(entry.get("layout", "")) == "operator"
	panel.custom_minimum_size = Vector2(0, 272 if operator_layout else 176)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.15, 0.22, 0.78)
	var accent_variant: Variant = entry.get("accent", Color(0.72, 0.86, 1.0, 0.72))
	var accent: Color = accent_variant if typeof(accent_variant) == TYPE_COLOR else Color(0.72, 0.86, 1.0, 0.72)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 24 if operator_layout else 18)
	margin.add_child(row)

	var image_path: String = String(entry.get("image_path", ""))
	if not image_path.is_empty():
		var portrait_frame := PanelContainer.new()
		portrait_frame.custom_minimum_size = Vector2(214, 214) if operator_layout else Vector2(132, 132)
		portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var portrait_style := StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.95, 0.97, 1.0, 0.08)
		portrait_style.border_color = accent
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
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load(image_path) as Texture2D
		portrait.custom_minimum_size = Vector2(196, 196) if operator_layout else Vector2(116, 116)
		portrait_margin.add_child(portrait)

	var box := VBoxContainer.new()
	box.layout_mode = 2
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var title := Label.new()
	title.layout_mode = 2
	title.add_theme_font_size_override("font_size", 30 if operator_layout else 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
	title.text = String(entry.get("title", ""))
	box.add_child(title)

	var subtitle_text: String = String(entry.get("subtitle", ""))
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.layout_mode = 2
		subtitle.add_theme_font_size_override("font_size", 20 if operator_layout else 18)
		subtitle.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.94))
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.text = subtitle_text
		box.add_child(subtitle)

	var body := Label.new()
	body.layout_mode = 2
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19 if operator_layout else 18)
	body.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 0.92))
	body.text = String(entry.get("body", ""))
	box.add_child(body)

	return panel


func _make_grid_entry_panel(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(184, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.15, 0.22, 0.76)
	var accent_variant: Variant = entry.get("accent", Color(0.72, 0.86, 1.0, 0.72))
	var accent: Color = accent_variant if typeof(accent_variant) == TYPE_COLOR else Color(0.72, 0.86, 1.0, 0.72)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.layout_mode = 2
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var image_path: String = String(entry.get("image_path", ""))
	if not image_path.is_empty():
		var frame_panel := PanelContainer.new()
		frame_panel.custom_minimum_size = Vector2(0, 138)
		UI_THEME_KIT.apply_page_section_panel(frame_panel)
		box.add_child(frame_panel)

		var frame_margin := MarginContainer.new()
		frame_margin.layout_mode = 2
		frame_margin.add_theme_constant_override("margin_left", 10)
		frame_margin.add_theme_constant_override("margin_top", 10)
		frame_margin.add_theme_constant_override("margin_right", 10)
		frame_margin.add_theme_constant_override("margin_bottom", 10)
		frame_panel.add_child(frame_margin)

		var image := TextureRect.new()
		image.layout_mode = 2
		image.custom_minimum_size = Vector2(0, 116)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = load(image_path) as Texture2D
		frame_margin.add_child(image)

	var title := Label.new()
	title.layout_mode = 2
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_heading(title, 22, Color(0.98, 0.96, 0.88, 1.0), Color(0.04, 0.04, 0.06, 0.82))
	title.text = String(entry.get("title", ""))
	box.add_child(title)

	var subtitle_text: String = String(entry.get("subtitle", ""))
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.layout_mode = 2
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI_THEME_KIT.apply_body(subtitle, 16, Color(0.78, 0.90, 0.98, 0.94))
		subtitle.text = subtitle_text
		box.add_child(subtitle)

	var body := Label.new()
	body.layout_mode = 2
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_body(body, 16, Color(0.92, 0.95, 0.98, 0.92))
	body.text = String(entry.get("body", ""))
	box.add_child(body)
	return panel


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _play_intro_animation() -> void:
	if frame == null:
		return
	UI_MOTION.reveal(frame, 0.03, Vector2(0, 18), 0.26, Vector2(0.99, 0.99))


func _entry_total_count() -> int:
	if sections.is_empty():
		return entries.size()
	var total: int = 0
	for section in sections:
		total += _dictionary_array(section.get("entries", [])).size()
	return total


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_variant in value:
		if typeof(entry_variant) == TYPE_DICTIONARY:
			result.append((entry_variant as Dictionary).duplicate(true))
	return result
