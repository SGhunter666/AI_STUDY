class_name UIThemeKit
extends RefCounted

const FONT_THEME = preload("res://scripts/ui/font_theme.gd")


static func apply_top_hud(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.09, 0.11, 0.14, 0.84),
			Color(0.84, 0.90, 0.96, 0.16),
			14,
			2,
			Color(0.00, 0.00, 0.00, 0.28),
			20
		)
	)


static func apply_glass_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.08, 0.11, 0.15, 0.66),
			Color(0.88, 0.94, 1.0, 0.14),
			18,
			1,
			Color(0.00, 0.00, 0.00, 0.24),
			18
		)
	)


# 模糊着色器懒加载缓存
static var _blur_shader: Shader = null


# 加载毛玻璃着色器（懒加载，避免 preload 在资源未导入时导致整个类编译失败）
static func _get_blur_shader() -> Shader:
	if _blur_shader == null:
		var loaded = load("res://scripts/ui/frosted_glass.gdshader")
		if loaded is Shader:
			_blur_shader = loaded
	return _blur_shader


# 真毛玻璃：在面板下方放 BackBufferCopy + 模糊着色器，
# 捕获屏幕内容并施加高斯模糊，再叠加半透明玻璃色。
# 注意：需要在面板的父节点是 Control/Viewport 时才生效。
static func apply_glass_panel_blurred(panel: Control, blur_strength: float = 2.4) -> void:
	apply_glass_panel(panel)
	# 避免重复添加
	if panel.get_node_or_null("FrostLayer") != null:
		return
	var blur_shader: Shader = _get_blur_shader()
	if blur_shader == null:
		# 着色器加载失败时退化为普通玻璃面板
		return
	var frost := ColorRect.new()
	frost.name = "FrostLayer"
	frost.show_behind_parent = true
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 圆角裁剪：用 Control 的 clip_contents 配合 StyleBox
	frost.clip_contents = true
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = blur_shader
	shader_mat.set_shader_parameter("blur_amount", blur_strength)
	shader_mat.set_shader_parameter("tint_color", Color(0.08, 0.11, 0.15, 0.42))
	frost.material = shader_mat
	panel.add_child(frost)
	panel.move_child(frost, 0)


static func apply_page_section_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.09, 0.11, 0.14, 0.82),
			Color(0.96, 0.90, 0.76, 0.18),
			18,
			1,
			Color(0.00, 0.00, 0.00, 0.28),
			20
		)
	)


static func apply_paper_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.86, 0.79, 0.64, 0.90),
			Color(0.38, 0.29, 0.18, 0.42),
			18,
			2,
			Color(0.00, 0.00, 0.00, 0.20),
			24
		)
	)


static func apply_log_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.06, 0.06, 0.07, 0.78),
			Color(0.98, 0.88, 0.68, 0.18),
			18,
			1,
			Color(0.00, 0.00, 0.00, 0.28),
			20
		)
	)


static func apply_energy_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(
			Color(0.58, 0.26, 0.12, 0.96),
			Color(1.00, 0.90, 0.62, 0.92),
			999,
			3,
			Color(0.94, 0.62, 0.18, 0.28),
			22
		)
	)


static func apply_heading(label: Label, font_size: int = 30, tint: Color = Color(0.18, 0.13, 0.08, 1.0), outline: Color = Color(1.0, 0.98, 0.92, 0.20)) -> void:
	FONT_THEME.apply_to_label(label, "heading")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 2)


static func apply_body(label: Label, font_size: int = 19, tint: Color = Color(0.18, 0.16, 0.14, 0.96)) -> void:
	FONT_THEME.apply_to_label(label, "body")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	var luminance: float = tint.r * 0.299 + tint.g * 0.587 + tint.b * 0.114
	if luminance >= 0.62:
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.82))
	else:
		label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.18))
	label.add_theme_constant_override("outline_size", 1)


static func apply_glass_heading(label: Label, font_size: int = 30) -> void:
	apply_heading(label, font_size, Color(0.98, 0.95, 0.86, 1.0), Color(0.04, 0.04, 0.06, 0.82))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.48))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 1)


static func apply_glass_body(label: Label, font_size: int = 19) -> void:
	apply_body(label, font_size, Color(0.97, 0.96, 0.92, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.40))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 1)


static func apply_glass_hint(label: Label, font_size: int = 18) -> void:
	apply_body(label, font_size, Color(0.98, 0.96, 0.90, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.84))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.34))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 1)


static func apply_chip_label(label: Label, tint: Color, font_size: int = 20) -> void:
	FONT_THEME.apply_to_label(label, "heading")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.82))
	label.add_theme_constant_override("outline_size", 1)


static func apply_hud_chip(button: Button, icon_texture: Texture2D, accent: Color, font_size: int = 18) -> void:
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.icon = icon_texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	FONT_THEME.apply_to_button(button, "numeric")
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.97, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.98, 0.97, 0.92, 0.94))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.94))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", accent)
	button.add_theme_constant_override("h_separation", 7)
	button.add_theme_constant_override("icon_max_width", 24)
	button.custom_minimum_size = Vector2(82, 38)
	var normal := _hud_chip_style(Color(0.07, 0.09, 0.12, 0.72), accent, 1, 10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _hud_chip_style(Color(0.10, 0.13, 0.17, 0.84), accent.lightened(0.12), 2, 14))
	button.add_theme_stylebox_override("pressed", _hud_chip_style(Color(0.05, 0.07, 0.10, 0.90), accent, 2, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", normal)


static func apply_health_hud_chip(button: Button, icon_texture: Texture2D) -> void:
	apply_hud_chip(button, icon_texture, Color(1.0, 0.42, 0.42, 1.0), 21)
	button.custom_minimum_size = Vector2(112, 42)
	button.add_theme_constant_override("h_separation", 9)
	button.add_theme_constant_override("icon_max_width", 28)


static func apply_numeric(label: Label, font_size: int = 18, tint: Color = Color(1, 1, 1, 1), outline: Color = Color(0.06, 0.06, 0.08, 0.94)) -> void:
	FONT_THEME.apply_to_label(label, "numeric")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 3)


static func apply_menu_text_button(button: Button, font_size: int = 38) -> void:
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	FONT_THEME.apply_to_button(button, "heading_spaced")
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.70, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.56, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.86, 0.86, 0.88, 0.42))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.96))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.00, 0.00, 0.00, 0.12), Color(1, 1, 1, 0.0), 18, 0, Color(0, 0, 0, 0), 0))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.04, 0.05, 0.07, 0.42), Color(1.0, 0.92, 0.70, 0.58), 18, 1, Color(1.0, 0.86, 0.56, 0.16), 14))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.04, 0.05, 0.07, 0.58), Color(1.0, 0.86, 0.54, 0.78), 18, 2, Color(1.0, 0.84, 0.52, 0.12), 8))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.04, 0.05, 0.07, 0.42), Color(1.0, 0.92, 0.70, 0.58), 18, 1, Color(1.0, 0.86, 0.56, 0.16), 14))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.00, 0.00, 0.00, 0.04), Color(1.0, 1.0, 1.0, 0.0), 18, 0, Color(0, 0, 0, 0), 0))


static func apply_stone_button(button: BaseButton, variant: String = "stone", font_size: int = 24) -> void:
	var fill: Color = Color(0.16, 0.22, 0.30, 0.90)
	var border: Color = Color(0.88, 0.94, 1.0, 0.56)
	var shadow: Color = Color(0.46, 0.74, 0.98, 0.14)
	var text_color: Color = Color(0.98, 0.99, 1.0, 1.0)
	var hover_text: Color = Color(1.0, 1.0, 1.0, 1.0)
	match variant:
		"paper":
			fill = Color(0.84, 0.78, 0.66, 0.96)
			border = Color(0.42, 0.32, 0.20, 0.56)
			shadow = Color(0.00, 0.00, 0.00, 0.10)
			text_color = Color(0.20, 0.16, 0.12, 1.0)
			hover_text = Color(0.14, 0.10, 0.08, 1.0)
		"danger":
			fill = Color(0.62, 0.44, 0.20, 0.98)
			border = Color(1.00, 0.90, 0.70, 0.94)
			shadow = Color(0.98, 0.78, 0.34, 0.18)
			text_color = Color(1.0, 0.98, 0.94, 1.0)
			hover_text = Color(1.0, 1.0, 0.96, 1.0)
		"node":
			fill = Color(0.18, 0.20, 0.22, 0.92)
			border = Color(0.90, 0.92, 0.96, 0.32)
			shadow = Color(0.30, 0.40, 0.52, 0.10)
		"ghost":
			fill = Color(0.08, 0.10, 0.12, 0.32)
			border = Color(0.86, 0.92, 1.0, 0.22)
			shadow = Color(0.34, 0.62, 0.94, 0.08)
	if button is Button:
		(button as Button).flat = false
	button.focus_mode = Control.FOCUS_NONE
	FONT_THEME.apply_to_button(button, "heading")
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", hover_text)
	button.add_theme_color_override("font_pressed_color", hover_text)
	button.add_theme_color_override("font_disabled_color", Color(text_color.r, text_color.g, text_color.b, 0.46))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.86) if variant != "paper" else Color(1.0, 1.0, 1.0, 0.14))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override("normal", _button_style(fill, border, 18, 2, shadow, 16))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), border.lightened(0.12), 18, 2, shadow.lightened(0.10), 22))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.10), border, 18, 2, shadow, 8))
	button.add_theme_stylebox_override("focus", _button_style(fill.lightened(0.06), border.lightened(0.10), 18, 2, shadow, 18))
	button.add_theme_stylebox_override("disabled", _button_style(Color(fill.r, fill.g, fill.b, 0.38), Color(border.r, border.g, border.b, 0.12), 18, 1, Color(0, 0, 0, 0), 0))


static func apply_end_turn_button(button: Button) -> void:
	apply_stone_button(button, "danger", 30)
	button.add_theme_constant_override("h_separation", 8)


static func apply_option_button(button: OptionButton) -> void:
	apply_stone_button(button, "stone", 20)


static func apply_toggle(toggle: BaseButton) -> void:
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 0.96))
	toggle.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.72))
	toggle.add_theme_constant_override("outline_size", 1)


static func apply_slider(slider: Range) -> void:
	if not (slider is HSlider):
		return
	var h_slider: HSlider = slider as HSlider
	h_slider.add_theme_constant_override("grabber_offset", 2)
	h_slider.add_theme_stylebox_override("slider", _make_stylebox(Color(0.88, 0.91, 0.98, 0.24), Color(0.92, 0.94, 0.98, 0.16), 999, 1, Color(0, 0, 0, 0), 0))
	h_slider.add_theme_stylebox_override("grabber_area", _make_stylebox(Color(0.88, 0.91, 0.98, 0.10), Color(0.92, 0.94, 0.98, 0.10), 999, 1, Color(0, 0, 0, 0), 0))
	h_slider.add_theme_stylebox_override("grabber_area_highlight", _make_stylebox(Color(1.0, 0.88, 0.54, 0.28), Color(1.0, 0.92, 0.74, 0.18), 999, 1, Color(0, 0, 0, 0), 0))
	h_slider.add_theme_icon_override("grabber", _make_slider_grabber(Color(1.0, 0.92, 0.74, 1.0), Color(0.48, 0.34, 0.18, 1.0)))
	h_slider.add_theme_icon_override("grabber_highlight", _make_slider_grabber(Color(1.0, 0.97, 0.86, 1.0), Color(0.48, 0.34, 0.18, 1.0)))


# LineEdit 样式：玻璃质感输入框，用于图鉴搜索
static func apply_line_edit(line_edit: LineEdit, font_size: int = 18) -> void:
	line_edit.add_theme_font_override("font", FONT_THEME.body_font())
	line_edit.add_theme_font_size_override("font_size", font_size)
	line_edit.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92, 1.0))
	line_edit.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.84))
	line_edit.add_theme_constant_override("outline_size", 1)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.72, 0.74, 0.80, 0.72))
	line_edit.add_theme_color_override("caret_color", Color(1.0, 0.92, 0.74, 1.0))
	line_edit.add_theme_color_override("selection_color", Color(1.0, 0.86, 0.46, 0.42))
	var normal := _make_stylebox(
		Color(0.06, 0.09, 0.13, 0.78),
		Color(0.88, 0.94, 1.0, 0.18),
		14, 1, Color(0.0, 0.0, 0.0, 0.22), 10
	)
	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", _make_stylebox(
		Color(0.08, 0.11, 0.16, 0.86),
		Color(1.0, 0.88, 0.54, 0.62),
		14, 2, Color(1.0, 0.74, 0.32, 0.24), 14
	))
	line_edit.add_theme_stylebox_override("read_only", normal)
	line_edit.add_theme_constant_override("content_left_margin", 12)
	line_edit.add_theme_constant_override("content_right_margin", 12)
	line_edit.add_theme_constant_override("content_top_margin", 6)
	line_edit.add_theme_constant_override("content_bottom_margin", 6)


# 筛选 chip 按钮（toggle 风格）：用于图鉴稀有度/角色筛选
static func apply_filter_chip(button: Button, active: bool, accent: Color = Color(1.0, 0.88, 0.54, 1.0), font_size: int = 16) -> void:
	FONT_THEME.apply_to_button(button, "heading")
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_pressed = active
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.88) if not active else Color(0.04, 0.04, 0.06, 0.92))
	button.add_theme_color_override("font_hover_color", Color.WHITE if not active else Color(0.02, 0.02, 0.04, 0.96))
	button.add_theme_color_override("font_pressed_color", Color.WHITE if not active else Color(0.02, 0.02, 0.04, 0.96))
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.74) if not active else Color(1.0, 0.98, 0.92, 0.18))
	button.add_theme_constant_override("outline_size", 1)
	var fill: Color = accent if active else Color(0.08, 0.11, 0.15, 0.72)
	var border: Color = accent.lightened(0.08) if active else Color(0.88, 0.94, 1.0, 0.18)
	var shadow: Color = accent.darkened(0.32) if active else Color(0.0, 0.0, 0.0, 0.20)
	var shadow_size: int = 14 if active else 8
	button.add_theme_stylebox_override("normal", _make_stylebox(fill, border, 999, 2, shadow, shadow_size))
	button.add_theme_stylebox_override("hover", _make_stylebox(fill.lightened(0.08), border.lightened(0.12), 999, 2, shadow.lightened(0.10), shadow_size + 4))
	button.add_theme_stylebox_override("pressed", _make_stylebox(fill.darkened(0.10), border, 999, 2, shadow, 6))
	button.add_theme_stylebox_override("focus", _make_stylebox(fill, border, 999, 2, shadow, shadow_size))
	button.custom_minimum_size = Vector2(0, 32)


static func _button_style(fill: Color, border: Color, radius: int, border_width: int, shadow_color: Color, shadow_size: int) -> StyleBoxFlat:
	var style := _make_stylebox(fill, border, radius, border_width, shadow_color, shadow_size)
	style.content_margin_left = 18
	style.content_margin_top = 10
	style.content_margin_right = 18
	style.content_margin_bottom = 10
	return style


static func _hud_chip_style(fill: Color, accent: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := _make_stylebox(fill, accent.darkened(0.08), 12, border_width, accent.darkened(0.32), shadow_size)
	style.content_margin_left = 10
	style.content_margin_top = 5
	style.content_margin_right = 12
	style.content_margin_bottom = 5
	style.border_color = Color(accent.r, accent.g, accent.b, 0.54)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	return style


static func _make_stylebox(fill: Color, border: Color, radius: int, border_width: int, shadow_color: Color, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	return style


static func _make_slider_grabber(fill: Color, border: Color) -> ImageTexture:
	var size := Vector2i(24, 24)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	for y in range(size.y):
		for x in range(size.x):
			var distance: float = center.distance_to(Vector2(x, y))
			if distance <= 10.5:
				image.set_pixel(x, y, fill)
			if distance <= 10.5 and distance >= 8.2:
				image.set_pixel(x, y, border)
	var texture := ImageTexture.create_from_image(image)
	return texture
