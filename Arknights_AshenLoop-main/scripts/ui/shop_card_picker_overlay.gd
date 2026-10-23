class_name ShopCardPickerOverlay
extends Control

# 商店服务选牌弹层：以网格展示卡组卡牌，点击选中一张并发出 card_picked。
# 用于"移除一张牌 / 升级一张牌"等需要玩家自选目标的服务；
# 取消（或点遮罩）不产生任何效果，购买确认由调用方在 card_picked 后处理。

signal card_picked(card_id: String)
signal cancelled

const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

var picker_title: String = ""
var picker_hint: String = ""
var entries: Array[Dictionary] = []  # {card: CardData, note: String}

var frame: PanelContainer
var title_label: Label
var hint_label: Label
var content_box: VBoxContainer
var empty_label: Label

func setup(title_text: String, hint_text: String, card_entries: Array[Dictionary]) -> void:
	picker_title = title_text
	picker_hint = hint_text
	entries.clear()
	for entry in card_entries:
		entries.append(entry.duplicate())
	if is_inside_tree():
		_render()

func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_ui()
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
	# 点击遮罩空白处 = 取消（不产生任何效果）
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_on_cancel_pressed()
	)
	add_child(shade)

	frame = PanelContainer.new()
	frame.layout_mode = 1
	frame.anchor_left = 0.10
	frame.anchor_top = 0.08
	frame.anchor_right = 0.90
	frame.anchor_bottom = 0.92
	frame.self_modulate = Color(1, 1, 1, 0.96)
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
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.layout_mode = 2
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	title_label = Label.new()
	title_label.layout_mode = 2
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_heading(title_label, 32, Color(0.98, 0.95, 0.82, 1.0), Color(0.04, 0.04, 0.06, 0.82))
	header.add_child(title_label)

	var cancel_button := Button.new()
	cancel_button.layout_mode = 2
	cancel_button.custom_minimum_size = Vector2(96, 52)
	cancel_button.text = LocalizationManager.text("overlay.cancel")
	UI_THEME_KIT.apply_stone_button(cancel_button, "ghost", 20)
	UI_MOTION.wire_button_feedback(cancel_button, 1.02, 0.98, Color(0.88, 0.96, 1.0, 0.72), 5.0)
	cancel_button.pressed.connect(_on_cancel_pressed)
	header.add_child(cancel_button)

	hint_label = Label.new()
	hint_label.layout_mode = 2
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_body(hint_label, 18, Color(0.92, 0.95, 0.98, 0.90))
	root.add_child(hint_label)

	var scroll := ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.layout_mode = 2
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 12)
	scroll.add_child(content_box)

	empty_label = Label.new()
	empty_label.layout_mode = 2
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI_THEME_KIT.apply_body(empty_label, 22, Color(0.93, 0.94, 0.98, 0.84))
	root.add_child(empty_label)
	call_deferred("_play_intro_animation")

func _render() -> void:
	if title_label == null:
		return
	title_label.text = picker_title
	hint_label.text = picker_hint
	for child in content_box.get_children():
		child.queue_free()
	if entries.is_empty():
		empty_label.visible = true
		return
	empty_label.visible = false
	content_box.add_child(_make_cards_grid())

func _make_cards_grid() -> VBoxContainer:
	const CARDS_PER_ROW := 4
	var list := VBoxContainer.new()
	list.layout_mode = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	var row := HBoxContainer.new()
	row.layout_mode = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	list.add_child(row)
	var count_in_row: int = 0
	for entry in entries:
		var card: CardData = entry.get("card", null) as CardData
		if card == null:
			continue
		if count_in_row == CARDS_PER_ROW:
			row = HBoxContainer.new()
			row.layout_mode = 2
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			list.add_child(row)
			count_in_row = 0
		row.add_child(_make_card_button(card, String(entry.get("note", ""))))
		count_in_row += 1
	return list

func _make_card_button(card: CardData, note: String) -> Button:
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
	var note_text: String = note.strip_edges()
	if not note_text.is_empty():
		button.tooltip_text = "%s\n%s" % [button.tooltip_text, note_text]
	var card_id: String = card.id
	button.pressed.connect(func() -> void:
		_on_card_pressed(card_id)
	)
	return button

func _on_card_pressed(card_id: String) -> void:
	card_picked.emit(card_id)
	queue_free()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _play_intro_animation() -> void:
	if frame == null:
		return
	UI_MOTION.reveal(frame, 0.03, Vector2(0, 18), 0.26, Vector2(0.99, 0.99))
