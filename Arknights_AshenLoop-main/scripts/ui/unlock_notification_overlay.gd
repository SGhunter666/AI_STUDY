extends Control

# 杀戮尖塔风格：run 结束后弹出"新发现"通知面板
# 显示本 run 中首次见到的卡牌/护符/模块列表

signal closed

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")

var notifications: Array[Dictionary] = []
var frame: PanelContainer
var content_box: VBoxContainer
var close_button: Button


func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 600
	_build_ui()
	_render()


func setup(notification_list: Array[Dictionary]) -> void:
	notifications = notification_list.duplicate(true)
	if is_inside_tree():
		_render()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.layout_mode = 1
	shade.anchor_left = 0.0
	shade.anchor_top = 0.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	frame = PanelContainer.new()
	frame.layout_mode = 1
	frame.anchor_left = 0.18
	frame.anchor_top = 0.14
	frame.anchor_right = 0.82
	frame.anchor_bottom = 0.86
	add_child(frame)
	UI_THEME_KIT.apply_paper_panel(frame)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(margin)

	var root := VBoxContainer.new()
	root.layout_mode = 2
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	# 标题区
	var header := HBoxContainer.new()
	header.layout_mode = 2
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_label := Label.new()
	title_label.layout_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_heading(title_label, 34, Color(0.38, 0.29, 0.18, 1.0), Color(1.0, 0.98, 0.92, 0.24))
	title_label.text = LocalizationManager.text("meta.unlock_notification_title")
	header.add_child(title_label)

	close_button = Button.new()
	close_button.layout_mode = 2
	close_button.custom_minimum_size = Vector2(72, 52)
	close_button.text = LocalizationManager.text("overlay.close")
	UI_THEME_KIT.apply_stone_button(close_button, "paper", 22)
	UI_MOTION.wire_button_feedback(close_button, 1.02, 0.98, Color(1.0, 0.92, 0.70, 0.78), 5.0)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# 正文描述
	var body_label := Label.new()
	body_label.layout_mode = 2
	body_label.name = "BodyLabel"
	UI_THEME_KIT.apply_body(body_label, 18, Color(0.22, 0.18, 0.14, 0.92))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.text = LocalizationManager.text("meta.unlock_notification_body")
	root.add_child(body_label)

	var scroll := ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.layout_mode = 2
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 14)
	scroll.add_child(content_box)

	call_deferred("_play_intro_animation")


func _render() -> void:
	if content_box == null:
		return
	for child in content_box.get_children():
		child.queue_free()

	# 按类型分组
	var cards: Array[Dictionary] = []
	var charms: Array[Dictionary] = []
	var modules: Array[Dictionary] = []
	for item in notifications:
		var kind: String = String(item.get("kind", ""))
		match kind:
			"card":
				cards.append(item)
			"charm":
				charms.append(item)
			"module":
				modules.append(item)

	if cards.is_empty() and charms.is_empty() and modules.is_empty():
		var empty_label := Label.new()
		empty_label.layout_mode = 2
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UI_THEME_KIT.apply_body(empty_label, 22, Color(0.30, 0.24, 0.18, 0.84))
		empty_label.text = LocalizationManager.text("meta.unlock_notification_empty")
		content_box.add_child(empty_label)
		return

	if not cards.is_empty():
		content_box.add_child(_make_group_section(
			LocalizationManager.text("meta.unlock_group_cards"),
			cards,
			Color(0.72, 0.90, 1.0, 0.92),
			"card"
		))
	if not charms.is_empty():
		content_box.add_child(_make_group_section(
			LocalizationManager.text("meta.unlock_group_charms"),
			charms,
			Color(0.86, 0.78, 1.0, 0.92),
			"charm"
		))
	if not modules.is_empty():
		content_box.add_child(_make_group_section(
			LocalizationManager.text("meta.unlock_group_modules"),
			modules,
			Color(0.96, 0.82, 0.58, 0.92),
			"module"
		))


func _make_group_section(title_text: String, items: Array[Dictionary], accent: Color, kind: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.layout_mode = 2
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.layout_mode = 2
	UI_THEME_KIT.apply_heading(header, 24, accent.darkened(0.12), Color(1.0, 0.98, 0.92, 0.20))
	header.text = "%s  (%d)" % [title_text, items.size()]
	section.add_child(header)

	# 卡牌类用网格显示缩略图，护符/模块用列表显示名字
	if kind == "card":
		var grid := _make_card_thumbnails(items)
		section.add_child(grid)
	else:
		for item in items:
			var row := HBoxContainer.new()
			row.layout_mode = 2
			row.add_theme_constant_override("separation", 10)
			var bullet := Label.new()
			bullet.layout_mode = 2
			UI_THEME_KIT.apply_body(bullet, 18, accent)
			bullet.text = "·"
			row.add_child(bullet)
			var name_label := Label.new()
			name_label.layout_mode = 2
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UI_THEME_KIT.apply_body(name_label, 18, Color(0.18, 0.14, 0.10, 0.94))
			name_label.text = String(item.get("name", item.get("id", "")))
			row.add_child(name_label)
			section.add_child(row)
	return section


func _make_card_thumbnails(items: Array[Dictionary]) -> GridContainer:
	var grid := GridContainer.new()
	grid.layout_mode = 2
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for item in items:
		var card_id: String = String(item.get("id", ""))
		var card: CardData = Util.load_card_db().get(card_id, null) as CardData
		if card == null:
			continue
		var thumb: Button = CARD_DISPLAY_FACTORY.create_card_button(
			card,
			LocalizationManager.card_name(card),
			LocalizationManager.card_description(card),
			card.cost,
			Util.load_card_art(card.id),
			Vector2(168, 240),
			false,
			CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
		)
		thumb.disabled = false
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_child(thumb)
	return grid


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _play_intro_animation() -> void:
	if frame == null:
		return
	UI_MOTION.reveal(frame, 0.03, Vector2(0, 24), 0.30, Vector2(0.98, 0.98))
