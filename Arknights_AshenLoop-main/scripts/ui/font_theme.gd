class_name FontTheme
extends RefCounted

# 字体系统：为不同用途提供差异化的字体
# 标题：Bahnschrift（Windows 工业感无衬线，棱角分明）→ 雅黑 → 默认
# 正文：Microsoft YaHei UI（中文清晰）→ 默认
# 数字/数值：Consolas（等宽，数值对齐）→ Bahnschrift → 默认
# 所有字体均带 fallback 链，确保跨平台/无字体时仍可显示

static var _heading_font: SystemFont = null
static var _body_font: SystemFont = null
static var _numeric_font: SystemFont = null
static var _heading_spaced_font: FontVariation = null


static func heading_font() -> Font:
	# 标题字体：Bahnschrift 是 Windows 10+ 自带的工业感字体，
	# 棱角分明、半压缩字宽，非常适合明日方舟的硬朗气质
	if _heading_font == null:
		_heading_font = SystemFont.new()
		_heading_font.font_names = ["Bahnschrift", "Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI", "Arial"]
		_heading_font.font_weight = 700
		_heading_font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_heading_font.generate_mipmaps = true
	return _heading_font


static func heading_spaced_font() -> Font:
	# 带字间距的标题字：用 FontVariation 包装 SystemFont 实现字间距（Godot 4 正确做法）
	if _heading_spaced_font == null:
		var base_font := SystemFont.new()
		base_font.font_names = ["Bahnschrift", "Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI", "Arial"]
		base_font.font_weight = 700
		base_font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		base_font.generate_mipmaps = true
		_heading_spaced_font = FontVariation.new()
		_heading_spaced_font.base_font = base_font
		# 字间距（FontVariation 支持 spacing_glyph / spacing_space 属性）
		_heading_spaced_font.spacing_glyph = 60
		_heading_spaced_font.spacing_space = 80
	return _heading_spaced_font


static func body_font() -> Font:
	# 正文字体：雅黑清晰易读，字重常规
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI", "Arial"]
		_body_font.font_weight = 400
		_body_font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_body_font.generate_mipmaps = true
	return _body_font


static func numeric_font() -> Font:
	# 数字字体：Consolas 等宽，数值对齐整齐
	if _numeric_font == null:
		_numeric_font = SystemFont.new()
		_numeric_font.font_names = ["Consolas", "Bahnschrift", "Microsoft YaHei UI", "Segoe UI", "Arial"]
		_numeric_font.font_weight = 600
		_numeric_font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_numeric_font.generate_mipmaps = true
	return _numeric_font


# 将字体应用到 Label（标题/正文/数字/带间距标题）
static func apply_to_label(label: Label, kind: String = "body") -> void:
	if label == null:
		return
	match kind:
		"heading":
			label.add_theme_font_override("font", heading_font())
		"heading_spaced":
			label.add_theme_font_override("font", heading_spaced_font())
		"numeric":
			label.add_theme_font_override("font", numeric_font())
		_:
			label.add_theme_font_override("font", body_font())


# 将字体应用到 Button
static func apply_to_button(button: Button, kind: String = "body") -> void:
	if button == null:
		return
	match kind:
		"heading":
			button.add_theme_font_override("font", heading_font())
		"heading_spaced":
			button.add_theme_font_override("font", heading_spaced_font())
		"numeric":
			button.add_theme_font_override("font", numeric_font())
		_:
			button.add_theme_font_override("font", body_font())


# 创建项目级 Theme（供 project.godot 或 Viewport 使用）
static func create_project_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	# Label 默认用正文字体
	theme.set_font("font", "Label", body_font())
	# Button 默认用正文字体
	theme.set_font("font", "Button", body_font())
	# LineEdit 用正文字体
	theme.set_font("font", "LineEdit", body_font())
	return theme
