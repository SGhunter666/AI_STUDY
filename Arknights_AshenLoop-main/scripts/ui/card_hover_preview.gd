extends Control

# 卡牌悬停预览：鼠标悬停卡牌时，在卡牌旁边显示一张放大的预览卡，
# 含完整描述、升级信息、稀有度标签。杀戮尖塔风格。
# 用法：调用 show_preview(card) 显示，hide_preview() 隐藏。

const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")

var preview_card: Button = null
var detail_panel: PanelContainer
var detail_box: VBoxContainer
var name_label: Label
var rarity_label: Label
var desc_label: Label
var upgrade_label: Label
var archetype_label: Label
var keywords_box: HBoxContainer       # 关键词标签 badges
var terms_label: Label                # 术语详细说明
var owner_terms_label: Label          # 角色核心术语
var current_tween: Tween = null
var _preview_version: int = 0  # 版本号守卫，防止 await 期间竞态


func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 500
	_build_ui()
	visible = false


func _build_ui() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.layout_mode = 1
	# 锚点设为左上角（0,0），position 即相对父节点左上角的偏移
	# card_hover_preview 本身全屏覆盖，局部坐标 == 全局坐标
	detail_panel.anchor_left = 0.0
	detail_panel.anchor_top = 0.0
	detail_panel.anchor_right = 0.0
	detail_panel.anchor_bottom = 0.0
	detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.visible = false
	add_child(detail_panel)
	UI_THEME_KIT.apply_glass_panel_blurred(detail_panel, 2.4)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	detail_panel.add_child(margin)

	detail_box = VBoxContainer.new()
	detail_box.layout_mode = 2
	detail_box.add_theme_constant_override("separation", 10)
	margin.add_child(detail_box)

	name_label = Label.new()
	name_label.layout_mode = 2
	detail_box.add_child(name_label)

	rarity_label = Label.new()
	rarity_label.layout_mode = 2
	detail_box.add_child(rarity_label)

	desc_label = Label.new()
	desc_label.layout_mode = 2
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(320, 0)
	detail_box.add_child(desc_label)

	upgrade_label = Label.new()
	upgrade_label.layout_mode = 2
	upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_label.custom_minimum_size = Vector2(320, 0)
	upgrade_label.visible = false
	detail_box.add_child(upgrade_label)

	archetype_label = Label.new()
	archetype_label.layout_mode = 2
	detail_box.add_child(archetype_label)

	# 关键词标签 badges（彩色小标签）
	keywords_box = HBoxContainer.new()
	keywords_box.layout_mode = 2
	keywords_box.add_theme_constant_override("separation", 6)
	keywords_box.visible = false
	detail_box.add_child(keywords_box)

	# 角色核心术语（如"核心术语：射击 / 弹药 / 装填"）
	owner_terms_label = Label.new()
	owner_terms_label.layout_mode = 2
	owner_terms_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_terms_label.custom_minimum_size = Vector2(320, 0)
	owner_terms_label.visible = false
	detail_box.add_child(owner_terms_label)

	# 术语详细说明（每个关键词的简短释义）
	terms_label = Label.new()
	terms_label.layout_mode = 2
	terms_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terms_label.custom_minimum_size = Vector2(320, 0)
	terms_label.visible = false
	detail_box.add_child(terms_label)


func show_preview(card: CardData, anchor_position: Vector2 = Vector2.ZERO) -> void:
	if card == null:
		hide_preview()
		return
	_preview_version += 1
	var version: int = _preview_version
	# 填充内容
	name_label.text = LocalizationManager.card_name(card)
	UI_THEME_KIT.apply_glass_heading(name_label, 28)

	rarity_label.text = _rarity_display(card)
	UI_THEME_KIT.apply_glass_body(rarity_label, 17)
	rarity_label.add_theme_color_override("font_color", _rarity_color(card))

	desc_label.text = LocalizationManager.card_description(card)
	UI_THEME_KIT.apply_glass_body(desc_label, 18)

	# 升级信息（如果有 _plus 版本）
	var upgraded_id: String = card.id + "_plus"
	var upgraded_card: CardData = Util.load_card_db().get(upgraded_id, null) as CardData
	if upgraded_card != null:
		upgrade_label.text = LocalizationManager.text("card.preview_upgraded", [LocalizationManager.card_description(upgraded_card)])
		UI_THEME_KIT.apply_glass_body(upgrade_label, 16)
		upgrade_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 0.92))
		upgrade_label.visible = true
	else:
		upgrade_label.visible = false

	# 原型标签
	var owner_id: String = Util.card_owner(card.id)
	if not owner_id.is_empty():
		archetype_label.text = LocalizationManager.text("card.preview_owner", [LocalizationManager.character_name(owner_id, owner_id.capitalize())])
		UI_THEME_KIT.apply_glass_hint(archetype_label, 15)
		archetype_label.visible = true
	else:
		archetype_label.visible = false

	# 关键词标签 badges
	for child in keywords_box.get_children():
		child.queue_free()
	var keyword_specs: Array[Dictionary] = CARD_DISPLAY_FACTORY.keyword_badges_for_preview(card)
	if not keyword_specs.is_empty():
		for spec in keyword_specs:
			var badge: PanelContainer = CARD_DISPLAY_FACTORY.make_keyword_badge_for_preview(spec)
			keywords_box.add_child(badge)
		keywords_box.visible = true
	else:
		keywords_box.visible = false

	# 角色核心术语
	var owner_terms: String = CARD_DISPLAY_FACTORY.owner_terms_line_for_preview(owner_id)
	if not owner_terms.is_empty():
		owner_terms_label.text = owner_terms
		UI_THEME_KIT.apply_glass_hint(owner_terms_label, 14)
		owner_terms_label.visible = true
	else:
		owner_terms_label.visible = false

	# 术语详细说明
	var term_lines: Array[String] = CARD_DISPLAY_FACTORY.term_lines_for_preview(card)
	if not term_lines.is_empty():
		terms_label.text = "\n".join(term_lines)
		UI_THEME_KIT.apply_glass_body(terms_label, 14)
		terms_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 0.88))
		terms_label.visible = true
	else:
		terms_label.visible = false

	# 定位：锚点在卡牌上方，避免遮挡手牌
	_layout_near(anchor_position)
	# await 期间若已有新的 show/hide 调用，放弃后续操作
	if version != _preview_version:
		return
	# 节点可能在 await 期间被 free，需要显式守卫
	if not is_inside_tree():
		return
	detail_panel.visible = true
	visible = true

	# 入场动画
	if current_tween != null:
		current_tween.kill()
	detail_panel.modulate.a = 0.0
	detail_panel.scale = Vector2(0.92, 0.92)
	detail_panel.pivot_offset = detail_panel.size * 0.5
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_tween.set_parallel(true)
	current_tween.tween_property(detail_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(detail_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_preview() -> void:
	_preview_version += 1  # 取消任何待处理的 show_preview
	if not visible:
		return
	if current_tween != null:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_tween.set_parallel(true)
	current_tween.tween_property(detail_panel, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	current_tween.tween_property(detail_panel, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	current_tween.finished.connect(func() -> void:
		detail_panel.visible = false
		visible = false
	, CONNECT_ONE_SHOT)


func _layout_near(anchor_position: Vector2) -> void:
	# 等 UI 计算完尺寸
	await get_tree().process_frame
	if detail_panel == null or not is_inside_tree():
		return
	var panel_size: Vector2 = detail_panel.size
	var viewport_size: Vector2 = get_viewport_rect().size
	# 默认放在锚点右上方
	var target_pos: Vector2 = anchor_position + Vector2(40, -panel_size.y - 20)
	# 超出右边界则放左侧
	if target_pos.x + panel_size.x > viewport_size.x - 20:
		target_pos.x = anchor_position.x - panel_size.x - 40
	# 超出上边界则放下方
	if target_pos.y < 20:
		target_pos.y = anchor_position.y + 40
	# 钳制到安全区
	target_pos.x = clamp(target_pos.x, 20, viewport_size.x - panel_size.x - 20)
	target_pos.y = clamp(target_pos.y, 20, viewport_size.y - panel_size.y - 20)
	detail_panel.position = target_pos
	detail_panel.pivot_offset = detail_panel.size * 0.5


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
