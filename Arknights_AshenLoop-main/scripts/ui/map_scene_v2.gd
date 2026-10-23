extends Control

const SETTINGS_TILE: Texture2D = preload("res://assets/ui_icons/settings_tile.svg")
const HUD_ICON_HP: Texture2D = preload("res://assets/ui_icons/hud_hp.svg")
const HUD_ICON_GOLD: Texture2D = preload("res://assets/ui_icons/hud_gold.svg")
const HUD_ICON_DECK: Texture2D = preload("res://assets/ui_icons/hud_deck.svg")
const HUD_ICON_MODULE: Texture2D = preload("res://assets/ui_icons/hud_module.svg")
const HUD_ICON_FLOOR: Texture2D = preload("res://assets/ui_icons/hud_floor.svg")
const HUD_ICON_TUNE: Texture2D = preload("res://assets/ui_icons/hud_tune.svg")
const CARD_GALLERY_OVERLAY = preload("res://scripts/ui/card_gallery_overlay.gd")
const COMPENDIUM_OVERLAY = preload("res://scripts/ui/compendium_overlay.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const TUNE_SUMMARY_PRESENTER = preload("res://scripts/ui/tune_summary_presenter.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const MAP_BRANCH_LAYER = preload("res://scripts/ui/map_branch_layer.gd")

@onready var hud_row: HBoxContainer = $TopHUD/HudMargin/HudRow
@onready var hero_chip: Label = $TopHUD/HudMargin/HudRow/HeroChip
@onready var hp_chip: Button = $TopHUD/HudMargin/HudRow/HpChip
@onready var gold_chip: Button = $TopHUD/HudMargin/HudRow/GoldChip
@onready var deck_chip: Button = $TopHUD/HudMargin/HudRow/DeckChip
@onready var module_chip: Button = $TopHUD/HudMargin/HudRow/ModuleChip
@onready var floor_chip: Button = $TopHUD/HudMargin/HudRow/FloorChip
@onready var spacer: Control = $TopHUD/HudMargin/HudRow/Spacer
@onready var settings_button: Button = $TopHUD/HudMargin/HudRow/SettingsButton
@onready var top_hud: PanelContainer = $TopHUD
@onready var paper_frame: PanelContainer = $PaperFrame
@onready var info_panel: PanelContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel
@onready var legend_panel: PanelContainer = $PaperFrame/PaperMargin/PaperContent/LegendPanel
@onready var info_eyebrow_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoEyebrow
@onready var info_title_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoTitle
@onready var info_body_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoBody
@onready var deck_summary_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoStats/DeckSummary/ChipMargin/ChipLabel
@onready var module_summary_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoStats/ModuleSummary/ChipMargin/ChipLabel
@onready var charm_summary_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoStats/CharmSummary/ChipMargin/ChipLabel
@onready var tune_summary_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoStats/TuneSummary/ChipMargin/ChipLabel
@onready var node_detail_panel: PanelContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/NodeDetailPanel
@onready var node_detail_title_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/NodeDetailPanel/NodeDetailMargin/NodeDetailBox/NodeDetailTitle
@onready var node_detail_body_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/NodeDetailPanel/NodeDetailMargin/NodeDetailBox/NodeDetailBody
@onready var actions_label: Label = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionsLabel
@onready var inspect_deck_button: Button = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionButtons/InspectDeckButton
@onready var inspect_modules_button: Button = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionButtons/InspectModulesButton
@onready var inspect_tunes_button: Button = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionButtons/InspectTunesButton
@onready var inspect_charms_button: Button = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionButtons/InspectCharmsButton
@onready var header_label: Label = $PaperFrame/PaperMargin/PaperContent/MapColumn/Header
@onready var hint_label: Label = $PaperFrame/PaperMargin/PaperContent/MapColumn/Hint
@onready var legend_title_label: Label = $PaperFrame/PaperMargin/PaperContent/LegendPanel/LegendMargin/LegendBox/LegendTitle
@onready var legend_items_box: VBoxContainer = $PaperFrame/PaperMargin/PaperContent/LegendPanel/LegendMargin/LegendBox/LegendItems
@onready var map_scroll: ScrollContainer = $PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll
@onready var map_canvas: Control = $PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll/MapCanvas
@onready var rows_box: VBoxContainer = $PaperFrame/PaperMargin/PaperContent/MapColumn/Scroll/MapCanvas/Rows

var node_icons: Dictionary = {}
var node_buttons: Dictionary = {}
var tune_button: Button
var branch_layer: Control
var card_db: Dictionary = {}
var module_db: Dictionary = {}
var enemy_db: Dictionary = {}
var _did_initial_node_focus: bool = false
var _focus_pending: bool = false

func _ready() -> void:
	MusicManager.stop_menu_bgm()
	MusicManager.play_map_bgm()
	RunManager.clear_stale_node_selection()
	card_db = Util.load_card_db()
	module_db = Util.load_module_db()
	enemy_db = Util.load_enemy_db()
	move_child(top_hud, get_child_count() - 1)
	_load_node_icons()
	_ensure_tune_button()
	_apply_ui_theme()
	_embed_settings_icon()
	_attach_settings_feedback()
	LocalizationManager.language_changed.connect(_refresh)
	RunManager.map_changed.connect(_refresh)
	RunManager.run_updated.connect(_refresh)
	deck_chip.pressed.connect(_open_deck_overlay)
	module_chip.pressed.connect(_open_module_overlay)
	inspect_deck_button.pressed.connect(_open_deck_overlay)
	inspect_modules_button.pressed.connect(_open_module_overlay)
	inspect_tunes_button.pressed.connect(_open_tune_overlay)
	inspect_charms_button.pressed.connect(_open_charm_overlay)
	_configure_map_scroll()
	map_canvas.resized.connect(_queue_branch_refresh)
	map_scroll.resized.connect(_queue_branch_refresh)
	rows_box.resized.connect(_queue_branch_refresh)
	resized.connect(_queue_layout_bounds)
	settings_button.pressed.connect(func() -> void:
		_press_settings()
	)
	_ensure_branch_layer()
	_refresh()
	_reset_layout_visuals()
	call_deferred("_play_intro_animation")
	# 布局通过 resized 信号和 call_deferred 触发，无需每帧 _process 计算
	get_viewport().size_changed.connect(_queue_layout_bounds)
	# 初始化时显式触发一次布局计算，确保 paper_frame/top_hud 等 offset 正确设置
	call_deferred("_enforce_layout_bounds")

func _exit_tree() -> void:
	# 断开 autoload 持久信号，避免 queue_free 延迟期间回调访问已销毁子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_refresh):
		LocalizationManager.language_changed.disconnect(_refresh)
	if RunManager != null:
		if RunManager.map_changed.is_connected(_refresh):
			RunManager.map_changed.disconnect(_refresh)
		if RunManager.run_updated.is_connected(_refresh):
			RunManager.run_updated.disconnect(_refresh)
	var vp: Window = get_viewport()
	if vp != null and vp.size_changed.is_connected(_queue_layout_bounds):
		vp.size_changed.disconnect(_queue_layout_bounds)

func _input(event: InputEvent) -> void:
	if _map_max_scroll() <= 0:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if not _is_point_inside_map_scroll(mouse_button.position):
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			map_scroll.scroll_vertical = max(map_scroll.scroll_vertical - 120, 0)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			map_scroll.scroll_vertical = min(map_scroll.scroll_vertical + 120, _map_max_scroll())
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		if not _is_point_inside_map_scroll(get_global_mouse_position()):
			return
		var pan: InputEventPanGesture = event as InputEventPanGesture
		map_scroll.scroll_vertical = clampi(
			map_scroll.scroll_vertical + int(round(pan.delta.y * 80.0)),
			0,
			_map_max_scroll()
		)
		get_viewport().set_input_as_handled()

func _refresh(_unused: Variant = null) -> void:
	hero_chip.text = LocalizationManager.active_character_name()
	hp_chip.text = "%d/%d" % [RunManager.hp, RunManager.max_hp]
	hp_chip.tooltip_text = LocalizationManager.text("map.hud_hp", [RunManager.hp, RunManager.max_hp])
	gold_chip.text = str(RunManager.gold)
	gold_chip.tooltip_text = LocalizationManager.text("map.hud_gold", [RunManager.gold])
	deck_chip.text = str(RunManager.deck.size())
	module_chip.text = str(RunManager.modules.size())
	deck_chip.tooltip_text = LocalizationManager.text("map.inspect_deck")
	module_chip.tooltip_text = LocalizationManager.text("map.inspect_modules")
	floor_chip.text = str(RunManager.current_floor)
	floor_chip.tooltip_text = LocalizationManager.text("map.hud_floor", [RunManager.current_floor])
	if tune_button != null:
		tune_button.text = str(TUNE_SUMMARY_PRESENTER.current_tune_count())
		tune_button.tooltip_text = TUNE_SUMMARY_PRESENTER.hud_tooltip()
	info_eyebrow_label.text = LocalizationManager.text("codex.header_eyebrow")
	info_title_label.text = LocalizationManager.text("map.sidebar_title")
	info_body_label.text = LocalizationManager.text("map.sidebar_body", [
		RunManager.current_floor,
		LocalizationManager.floor_name(RunManager.current_floor)
	])
	deck_summary_label.text = LocalizationManager.text("map.hud_deck", [RunManager.deck.size()])
	module_summary_label.text = LocalizationManager.text("map.hud_modules", [RunManager.modules.size()])
	charm_summary_label.text = LocalizationManager.text("map.sidebar_charms", [RunManager.charms.size()])
	tune_summary_label.text = LocalizationManager.text("tune.hud_chip", [TUNE_SUMMARY_PRESENTER.current_tune_count()])
	actions_label.text = LocalizationManager.text("map.sidebar_actions")
	inspect_deck_button.text = LocalizationManager.text("map.inspect_deck")
	inspect_modules_button.text = LocalizationManager.text("map.inspect_modules")
	inspect_tunes_button.text = LocalizationManager.text("tune.overlay_title")
	inspect_charms_button.text = LocalizationManager.text("map.inspect_charms")
	node_detail_title_label.text = LocalizationManager.text("map.sidebar_preview_title")
	settings_button.text = ""
	settings_button.tooltip_text = LocalizationManager.text("main.settings")
	header_label.text = LocalizationManager.text("map.header", [RunManager.current_floor, LocalizationManager.floor_name(RunManager.current_floor)])
	hint_label.text = _hint_text()
	legend_title_label.text = LocalizationManager.text("map.legend_title")
	_restore_node_preview()
	_refresh_legend()
	node_buttons.clear()
	for child in rows_box.get_children():
		child.queue_free()
	if RunManager.has_flag("run_complete"):
		var done_label: Label = Label.new()
		done_label.text = LocalizationManager.text("map.complete")
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_label.add_theme_font_size_override("font_size", 24)
		rows_box.add_child(done_label)
		return
	_did_initial_node_focus = false
	for row_nodes in RunManager.get_rows():
		_add_row(row_nodes)
	_apply_preview_two_nodes()
	_reset_layout_visuals()
	_queue_branch_refresh()
	call_deferred("_focus_reachable_nodes_once")
	_queue_layout_bounds()

func _add_row(row_nodes: Array) -> void:
	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.mouse_filter = Control.MOUSE_FILTER_PASS
	row_box.add_theme_constant_override("separation", 18)
	row_box.custom_minimum_size = Vector2(0, _row_height())
	rows_box.add_child(row_box)
	var sorted_nodes: Array = row_nodes.duplicate()
	sorted_nodes.sort_custom(func(a: MapNodeModel, b: MapNodeModel) -> bool:
		return a.lane < b.lane
	)
	var previous_lane: int = -1
	for node_variant in sorted_nodes:
		var node: MapNodeModel = node_variant
		if previous_lane == -1:
			if node.lane > 0:
				var initial_spacer: Control = Control.new()
				initial_spacer.custom_minimum_size = Vector2(float(node.lane) * _lane_step(), 1.0)
				initial_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row_box.add_child(initial_spacer)
		else:
			var lane_gap: int = max(0, node.lane - previous_lane - 1)
			if lane_gap > 0:
				var spacer_gap: Control = Control.new()
				spacer_gap.custom_minimum_size = Vector2(float(lane_gap) * _lane_step(), 1.0)
				spacer_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row_box.add_child(spacer_gap)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2.ONE * _node_button_side()
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.tooltip_text = LocalizationManager.node_type_name(node.node_type)
		button.disabled = not RunManager.is_node_reachable(node.id)
		button.modulate = _node_color(node)
		button.mouse_force_pass_scroll_events = true
		UI_THEME_KIT.apply_stone_button(button, "node", 18)
		UI_MOTION.wire_button_feedback(button, 1.04, 0.96, Color(0.88, 0.95, 1.0, 0.72), 5.0)
		_add_node_icon(button, node)
		node_buttons[node.id] = button
		button.mouse_entered.connect(func(target_node: MapNodeModel = node) -> void:
			_show_node_preview(target_node)
		)
		button.mouse_exited.connect(func() -> void:
			_restore_node_preview()
		)
		button.pressed.connect(func(target_id: String = node.id, target_button: Button = button) -> void:
			_on_node_pressed(target_id, target_button)
		)
		row_box.add_child(button)
		previous_lane = node.lane

func _add_node_icon(button: Button, node: MapNodeModel) -> void:
	var texture: Texture2D = node_icons.get("event") as Texture2D
	if node_icons.has(node.node_type):
		texture = node_icons[node.node_type] as Texture2D
	if texture == null:
		return
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.layout_mode = 1
	icon_rect.anchor_left = 0.12
	icon_rect.anchor_top = 0.12
	icon_rect.anchor_right = 0.88
	icon_rect.anchor_bottom = 0.88
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = texture
	icon_rect.modulate = _node_icon_modulate(node)
	button.add_child(icon_rect)

func _refresh_legend() -> void:
	for child in legend_items_box.get_children():
		child.queue_free()
	var legend_order: Array[String] = ["battle", "elite", "event", "story", "shop", "rest", "boss"]
	for node_type in legend_order:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon_holder: Control = Control.new()
		icon_holder.custom_minimum_size = Vector2(36, 36)
		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.layout_mode = 1
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = node_icons.get(node_type) as Texture2D
		icon.modulate = _node_icon_modulate_for_legend(node_type)
		icon_holder.add_child(icon)
		var label: Label = Label.new()
		label.text = LocalizationManager.node_type_name(node_type)
		UI_THEME_KIT.apply_glass_body(label, 20)
		row.add_child(icon_holder)
		row.add_child(label)
		legend_items_box.add_child(row)

func _load_node_icons() -> void:
	node_icons = {
		"battle": load("res://assets/ui_icons/node_battle.svg"),
		"elite": load("res://assets/ui_icons/node_elite.svg"),
		"boss": load("res://assets/ui_icons/node_boss.svg"),
		"event": load("res://assets/ui_icons/node_event.svg"),
		"story": load("res://assets/ui_icons/node_story.svg"),
		"rest": load("res://assets/ui_icons/node_rest.svg"),
		"shop": load("res://assets/ui_icons/node_shop.svg")
	}

func _node_color(node: MapNodeModel) -> Color:
	if node.completed:
		return Color(1, 1, 1, 0.78)
	if RunManager.is_node_reachable(node.id):
		return Color(1, 1, 1, 1)
	return Color(1, 1, 1, 0.56)

func _node_icon_modulate(node: MapNodeModel) -> Color:
	if node.completed:
		return Color(0.80, 0.74, 0.70, 0.96)
	if RunManager.is_node_reachable(node.id):
		match node.node_type:
			"elite":
				return Color(1.0, 0.76, 0.76, 1.0)
			"boss":
				return Color(1.0, 0.64, 0.64, 1.0)
			"rest":
				return Color(0.96, 0.90, 0.82, 1.0)
			"shop":
				return Color(0.90, 0.98, 0.88, 1.0)
			"event", "story":
				return Color(1.0, 0.96, 0.82, 1.0)
		return Color(1.0, 1.0, 1.0, 1.0)
	return Color(0.80, 0.74, 0.70, 0.72)

func _node_icon_modulate_for_legend(node_type: String) -> Color:
	match node_type:
		"elite":
			return Color(1.0, 0.76, 0.76, 1.0)
		"boss":
			return Color(1.0, 0.64, 0.64, 1.0)
		"rest":
			return Color(0.96, 0.90, 0.82, 1.0)
		"shop":
			return Color(0.90, 0.98, 0.88, 1.0)
		"event", "story":
			return Color(1.0, 0.96, 0.82, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)

func _hint_text() -> String:
	var current: MapNodeModel = RunManager.current_node()
	if current != null:
		return LocalizationManager.text("map.current_node", [LocalizationManager.node_type_name(current.node_type)])
	if RunManager.has_flag("run_complete"):
		return LocalizationManager.text("map.complete")
	return LocalizationManager.text("map.pick_route")

func _on_node_pressed(node_id: String, button: Button) -> void:
	if not RunManager.select_node(node_id):
		return
	for button_value in node_buttons.values():
		var node_button: Button = button_value as Button
		if node_button != null:
			node_button.disabled = true
	UI_MOTION.pulse(button, 0.92, 1.05, 0.07)
	var node: MapNodeModel = RunManager.current_node()
	if node == null:
		return
	_route_for_node(node)

func _route_for_node(node: MapNodeModel) -> void:
	match node.node_type:
		"battle", "elite", "boss":
			SceneRouter.go_battle()
		"event", "story":
			SceneRouter.go_event()
		"rest":
			SceneRouter.go_rest()
		"shop":
			SceneRouter.go_shop()
		_:
			SceneRouter.go_battle()

func _embed_settings_icon() -> void:
	settings_button.text = ""
	var icon_rect: TextureRect = settings_button.get_node_or_null("SettingsIcon") as TextureRect
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "SettingsIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.layout_mode = 1
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		settings_button.add_child(icon_rect)
	icon_rect.texture = SETTINGS_TILE

func _attach_settings_feedback() -> void:
	settings_button.flat = true
	settings_button.pivot_offset = settings_button.size * 0.5
	var ring: Panel = settings_button.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		ring = Panel.new()
		ring.name = "FeedbackRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.layout_mode = 1
		ring.anchor_left = 0.0
		ring.anchor_top = 0.0
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = -3.0
		ring.offset_top = -3.0
		ring.offset_right = 3.0
		ring.offset_bottom = 3.0
		settings_button.add_child(ring)
		settings_button.move_child(ring, 0)
	settings_button.mouse_entered.connect(func() -> void:
		_update_settings_feedback(false)
	)
	settings_button.button_down.connect(func() -> void:
		_update_settings_feedback(true)
	)
	settings_button.button_up.connect(func() -> void:
		_update_settings_feedback(false)
	)
	settings_button.mouse_exited.connect(func() -> void:
		_update_settings_feedback(false)
	)
	_update_settings_feedback(false)

func _ensure_tune_button() -> void:
	if tune_button != null:
		return
	tune_button = Button.new()
	tune_button.name = "TuneButton"
	tune_button.layout_mode = 2
	UI_THEME_KIT.apply_hud_chip(tune_button, HUD_ICON_TUNE, Color(0.72, 0.94, 1.0, 1.0), 18)
	UI_MOTION.wire_button_feedback(tune_button, 1.03, 0.97, Color(0.76, 0.92, 1.0, 0.72), 5.0)
	tune_button.pressed.connect(_open_tune_overlay)
	hud_row.add_child(tune_button)
	hud_row.move_child(tune_button, spacer.get_index())

func _ensure_branch_layer() -> void:
	if branch_layer != null:
		return
	branch_layer = MAP_BRANCH_LAYER.new()
	branch_layer.name = "MapBranchLayer"
	branch_layer.layout_mode = 1
	branch_layer.anchor_left = 0.0
	branch_layer.anchor_top = 0.0
	branch_layer.anchor_right = 1.0
	branch_layer.anchor_bottom = 1.0
	branch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(branch_layer)
	map_canvas.move_child(branch_layer, 0)

func _queue_branch_refresh() -> void:
	call_deferred("_refresh_branch_lines")

func _refresh_branch_lines() -> void:
	if branch_layer == null:
		return
	_enforce_layout_bounds()
	_refresh_map_canvas_size()
	branch_layer.set_branch_data(RunManager.map_nodes, node_buttons)

func _configure_map_scroll() -> void:
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.follow_focus = false
	map_scroll.mouse_force_pass_scroll_events = true
	rows_box.mouse_filter = Control.MOUSE_FILTER_PASS
	rows_box.mouse_force_pass_scroll_events = true
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_canvas.mouse_force_pass_scroll_events = true

func _refresh_map_canvas_size() -> void:
	var minimum: Vector2 = rows_box.get_combined_minimum_size()
	var canvas_width: float = max(map_scroll.size.x - 12.0, minimum.x)
	var canvas_height: float = max(map_scroll.size.y, minimum.y, rows_box.size.y)
	map_canvas.custom_minimum_size = Vector2(canvas_width, canvas_height)
	map_canvas.size = Vector2(canvas_width, canvas_height)

func _queue_layout_bounds() -> void:
	call_deferred("_enforce_layout_bounds")

func _enforce_layout_bounds() -> void:
	var viewport_size: Vector2 = size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	var compact_height: bool = viewport_size.y < 840.0
	var compact_width: bool = viewport_size.x < 1450.0
	var side_margin: float = clampf(viewport_size.x * 0.035, 28.0, 78.0)
	var top_margin: float = 8.0
	var hud_height: float = 58.0 if compact_height else 62.0
	var scale_factor: float = maxf(1.0, get_tree().root.content_scale_factor)
	var paper_top: float = 68.0 if viewport_size.y < 620.0 else (78.0 if compact_height else 92.0)
	paper_top = maxf(paper_top, top_margin + hud_height * scale_factor + 16.0)
	var paper_bottom: float = 12.0 if viewport_size.y < 620.0 else (18.0 if compact_height else 40.0)
	top_hud.offset_left = 12.0
	top_hud.offset_top = top_margin
	top_hud.offset_right = -12.0
	top_hud.offset_bottom = top_margin + hud_height
	info_panel.custom_minimum_size.x = clampf(viewport_size.x * 0.18, 184.0, 236.0)
	legend_panel.custom_minimum_size.x = clampf(viewport_size.x * 0.13, 128.0, 176.0)
	legend_panel.visible = not (compact_width and viewport_size.y < 760.0)
	paper_frame.offset_left = side_margin
	paper_frame.offset_top = paper_top
	paper_frame.offset_right = -side_margin
	paper_frame.offset_bottom = -paper_bottom
	_apply_compact_sidebar(compact_height)

func _map_max_scroll() -> int:
	var bar: VScrollBar = map_scroll.get_v_scroll_bar()
	if bar == null:
		return 0
	return max(int(round(bar.max_value - bar.page)), 0)

func _is_point_inside_map_scroll(point: Vector2) -> bool:
	return map_scroll.get_global_rect().has_point(point)

func _focus_reachable_nodes() -> void:
	if node_buttons.is_empty():
		return
	# 定位第一个可达节点所在行，无论它在当前视口上方还是下方，
	# 都把该行滚到视口上部；上方已完成的行允许滚出视口
	var top_y: float = INF
	for node_variant in RunManager.map_nodes:
		var node: MapNodeModel = node_variant as MapNodeModel
		if node == null or not RunManager.is_node_reachable(node.id):
			continue
		var button: Control = node_buttons.get(node.id, null) as Control
		if button == null:
			continue
		var row_box: Control = button.get_parent() as Control
		if row_box == null:
			continue
		var btn_y: float = row_box.position.y + button.position.y
		top_y = min(top_y, btn_y)
	if not is_finite(top_y):
		return
	var margin: float = 36.0
	var target: int = clampi(int(round(top_y - margin)), 0, _map_max_scroll())
	# 用 deferred 赋值，确保在当帧布局计算完成后生效
	map_scroll.set_deferred("scroll_vertical", target)

func _focus_reachable_nodes_once() -> void:
	if _did_initial_node_focus or _focus_pending:
		return
	_did_initial_node_focus = true
	_focus_pending = true
	# 等待布局稳定：旧节点释放、行容器与 canvas 尺寸依次生效
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		_focus_pending = false
		return
	_enforce_layout_bounds()
	# 再等一帧让 scrollbar 的 max_value 在 canvas 尺寸更新后生效，
	# 否则 scroll_vertical 会被钳制到 0 导致画面停回顶部
	await get_tree().process_frame
	if not is_inside_tree():
		_focus_pending = false
		return
	_focus_reachable_nodes()
	_focus_pending = false

func _apply_compact_sidebar(compact_height: bool) -> void:
	var viewport_size: Vector2 = size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	var ultra_compact_height: bool = viewport_size.y < 620.0
	var info_margin: MarginContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin
	var paper_margin: MarginContainer = $PaperFrame/PaperMargin
	var info_box: VBoxContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox
	var info_stats: VBoxContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/InfoStats
	var action_buttons: VBoxContainer = $PaperFrame/PaperMargin/PaperContent/InfoPanel/InfoMargin/InfoBox/ActionButtons
	var compact_margin: int = 12 if compact_height else 18
	var paper_margin_y: int = 14 if compact_height else 22
	paper_margin.add_theme_constant_override("margin_left", 22 if compact_height else 28)
	paper_margin.add_theme_constant_override("margin_top", paper_margin_y)
	paper_margin.add_theme_constant_override("margin_right", 20 if compact_height else 24)
	paper_margin.add_theme_constant_override("margin_bottom", 14 if compact_height else 20)
	info_margin.add_theme_constant_override("margin_left", compact_margin)
	info_margin.add_theme_constant_override("margin_top", compact_margin)
	info_margin.add_theme_constant_override("margin_right", compact_margin)
	info_margin.add_theme_constant_override("margin_bottom", compact_margin)
	info_box.add_theme_constant_override("separation", 8 if compact_height else 14)
	info_stats.add_theme_constant_override("separation", 7 if compact_height else 10)
	action_buttons.add_theme_constant_override("separation", 7 if compact_height else 10)
	info_eyebrow_label.visible = not ultra_compact_height
	info_title_label.visible = not ultra_compact_height
	info_body_label.visible = not compact_height
	actions_label.visible = not compact_height
	action_buttons.visible = not ultra_compact_height
	if compact_height:
		info_body_label.text = ""
		actions_label.text = ""
	if ultra_compact_height:
		info_eyebrow_label.text = ""
		info_title_label.text = ""
	node_detail_panel.custom_minimum_size.y = 92.0 if ultra_compact_height else (104.0 if compact_height else 140.0)
	for stat_variant in info_stats.get_children():
		var stat_panel: Control = stat_variant as Control
		if stat_panel != null:
			stat_panel.custom_minimum_size.y = 32.0 if ultra_compact_height else (36.0 if compact_height else 48.0)
	for button_variant in action_buttons.get_children():
		var action_button: Button = button_variant as Button
		if action_button != null:
			action_button.visible = not ultra_compact_height
			if ultra_compact_height:
				action_button.text = ""
			action_button.custom_minimum_size.y = 0.0 if ultra_compact_height else (38.0 if compact_height else 48.0)
	rows_box.add_theme_constant_override("separation", _row_separation())

func _is_compact_map_layout() -> bool:
	var viewport_size: Vector2 = size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	return viewport_size.x < 1100.0 or viewport_size.y < 680.0

func _node_button_side() -> float:
	return 60.0 if _is_compact_map_layout() else 72.0

func _lane_step() -> float:
	return 76.0 if _is_compact_map_layout() else 94.0

func _row_height() -> float:
	return 64.0 if _is_compact_map_layout() else 78.0

func _row_separation() -> int:
	return 22 if _is_compact_map_layout() else 36

func _open_tune_overlay() -> void:
	UI_MOTION.pulse(tune_button, 0.95, 1.04, 0.06)
	TUNE_SUMMARY_PRESENTER.open_current_overlay(self)

func _open_deck_overlay() -> void:
	UI_MOTION.pulse(deck_chip, 0.95, 1.04, 0.06)
	var cards: Array[CardData] = []
	for card_id_variant in RunManager.deck:
		var card_id: String = String(card_id_variant)
		var card: CardData = card_db.get(card_id, null) as CardData
		if card != null:
			cards.append(card)
	var overlay: CardGalleryOverlay = CARD_GALLERY_OVERLAY.new()
	overlay.setup(LocalizationManager.text("map.deck_title"), cards)
	add_child(overlay)

func _open_module_overlay() -> void:
	UI_MOTION.pulse(module_chip, 0.95, 1.04, 0.06)
	var entries: Array[Dictionary] = []
	if RunManager.modules.is_empty():
		entries.append({
			"title": LocalizationManager.text("map.modules_title"),
			"body": LocalizationManager.text("map.no_modules"),
			"accent": Color(0.72, 0.92, 1.0, 0.76),
			"display_mode": "grid"
		})
	else:
		for module_id_variant in RunManager.modules:
			var module_id: String = String(module_id_variant)
			var module_data: ModuleData = module_db.get(module_id, null) as ModuleData
			if module_data == null:
				continue
			entries.append({
				"title": LocalizationManager.module_name(module_data),
				"subtitle": LocalizationManager.text("codex.module_rarity", [LocalizationManager.rarity_name(module_data.rarity)]),
				"body": LocalizationManager.module_description(module_data),
				"accent": _module_accent(module_data.rarity),
				"image_path": Util.module_icon_path(module_id),
				"display_mode": "grid"
			})
	if entries.is_empty():
		entries.append({
			"title": LocalizationManager.text("map.modules_title"),
			"body": LocalizationManager.text("map.no_modules"),
			"accent": Color(0.72, 0.92, 1.0, 0.76),
			"display_mode": "grid"
		})
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup(LocalizationManager.text("map.modules_title"), entries)
	add_child(overlay)

func _open_charm_overlay() -> void:
	# 查看护符 overlay：分"已装备"和"已拥有未装备"两节展示
	var charm_db: Dictionary = Util.load_charm_db()
	var equipped_sections: Array[Dictionary] = []
	var unequipped_entries: Array[Dictionary] = []
	# 已装备的护符
	var equipped_entries: Array[Dictionary] = []
	for charm_id_variant in RunManager.charms:
		var charm_id: String = String(charm_id_variant)
		if charm_id.is_empty():
			continue
		var charm_data: CharmData = charm_db.get(charm_id, null) as CharmData
		if charm_data == null:
			continue
		equipped_entries.append({
			"title": LocalizationManager.charm_name(charm_data),
			"subtitle": LocalizationManager.text("map.charm_equipped"),
			"body": LocalizationManager.charm_description(charm_data),
			"accent": Color(1.0, 0.85, 0.40, 0.84),
			"display_mode": "grid"
		})
	# 已拥有但未装备的护符
	for charm_id_variant in RunManager.owned_charms:
		var charm_id: String = String(charm_id_variant)
		if charm_id.is_empty() or RunManager.charms.has(charm_id):
			continue
		var charm_data: CharmData = charm_db.get(charm_id, null) as CharmData
		if charm_data == null:
			continue
		unequipped_entries.append({
			"title": LocalizationManager.charm_name(charm_data),
			"subtitle": LocalizationManager.text("map.charm_unequipped"),
			"body": LocalizationManager.charm_description(charm_data),
			"accent": Color(0.70, 0.65, 0.55, 0.62),
			"display_mode": "grid"
		})
	# 组装 sections
	if not equipped_entries.is_empty():
		equipped_sections.append({
			"title": LocalizationManager.text("map.charms_equipped_section"),
			"entries": equipped_entries
		})
	if not unequipped_entries.is_empty():
		equipped_sections.append({
			"title": LocalizationManager.text("map.charms_unequipped_section"),
			"entries": unequipped_entries
		})
	# 空状态兜底
	if equipped_sections.is_empty():
		equipped_sections.append({
			"title": LocalizationManager.text("map.charms_title"),
			"entries": [{
				"title": LocalizationManager.text("map.charms_title"),
				"body": LocalizationManager.text("map.no_charms"),
				"accent": Color(1.0, 0.85, 0.40, 0.76),
				"display_mode": "grid"
			}]
		})
	var charm_overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	charm_overlay.setup_sections(LocalizationManager.text("map.charms_title"), equipped_sections)
	add_child(charm_overlay)

func _update_settings_feedback(pressed: bool) -> void:
	var hovered: bool = settings_button.get_global_rect().has_point(settings_button.get_global_mouse_position())
	settings_button.pivot_offset = settings_button.size * 0.5
	settings_button.scale = Vector2(0.96, 0.96) if pressed else (Vector2(1.03, 1.03) if hovered else Vector2.ONE)
	var icon_rect: TextureRect = settings_button.get_node_or_null("SettingsIcon") as TextureRect
	if icon_rect != null:
		icon_rect.position = Vector2(0, 3) if pressed else Vector2.ZERO
	var ring: Panel = settings_button.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if hovered:
		style.border_color = Color(0.82, 0.95, 1.0, 0.76)
		style.shadow_color = Color(0.48, 0.78, 1.0, 0.48)
		style.shadow_size = 14 if not pressed else 6
	else:
		style.border_color = Color(0.82, 0.95, 1.0, 0.0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
	ring.add_theme_stylebox_override("panel", style)

func _reset_layout_visuals() -> void:
	$TopHUD.scale = Vector2.ONE
	$TopHUD.modulate.a = 1.0
	$PaperFrame.scale = Vector2.ONE
	$PaperFrame.modulate.a = 1.0
	_enforce_layout_bounds()
	for row_variant in rows_box.get_children():
		var row_control: Control = row_variant as Control
		if row_control != null:
			row_control.scale = Vector2.ONE
			row_control.modulate.a = 1.0

func _press_settings() -> void:
	SfxManager.play_ui_click()
	UI_MOTION.pulse_then(settings_button, Callable(self, "_open_settings_scene"), 0.94, 1.04, 0.06)

func _open_settings_scene() -> void:
	SceneRouter.go_settings(SceneRouter.MAP_SCENE)

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_top_hud($TopHUD)
	UI_THEME_KIT.apply_paper_panel($PaperFrame)
	UI_THEME_KIT.apply_page_section_panel(info_panel)
	UI_THEME_KIT.apply_page_section_panel($PaperFrame/PaperMargin/PaperContent/LegendPanel)
	UI_THEME_KIT.apply_chip_label(hero_chip, Color(1.0, 0.95, 0.84, 1.0), 22)
	UI_THEME_KIT.apply_health_hud_chip(hp_chip, HUD_ICON_HP)
	UI_THEME_KIT.apply_hud_chip(gold_chip, HUD_ICON_GOLD, Color(1.0, 0.82, 0.36, 1.0), 18)
	UI_THEME_KIT.apply_hud_chip(deck_chip, HUD_ICON_DECK, Color(0.60, 0.88, 1.0, 1.0), 18)
	UI_THEME_KIT.apply_hud_chip(module_chip, HUD_ICON_MODULE, Color(0.58, 0.94, 0.72, 1.0), 18)
	UI_MOTION.wire_button_feedback(deck_chip, 1.03, 0.97, Color(0.72, 0.90, 1.0, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(module_chip, 1.03, 0.97, Color(0.72, 1.0, 0.84, 0.72), 5.0)
	UI_THEME_KIT.apply_hud_chip(floor_chip, HUD_ICON_FLOOR, Color(0.96, 0.84, 0.50, 1.0), 18)
	UI_THEME_KIT.apply_chip_label(info_eyebrow_label, Color(0.82, 0.92, 1.0, 0.82), 14)
	UI_THEME_KIT.apply_heading(info_title_label, 24, Color(0.98, 0.95, 0.86, 1.0), Color(0.02, 0.03, 0.05, 0.84))
	UI_THEME_KIT.apply_body(info_body_label, 16, Color(0.92, 0.94, 0.98, 0.90))
	UI_THEME_KIT.apply_page_section_panel(node_detail_panel)
	node_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_heading(node_detail_title_label, 20, Color(0.98, 0.95, 0.86, 1.0), Color(0.02, 0.03, 0.05, 0.72))
	node_detail_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI_THEME_KIT.apply_glass_hint(node_detail_body_label, 14)
	UI_THEME_KIT.apply_heading(actions_label, 18, Color(0.98, 0.95, 0.86, 0.96), Color(0.02, 0.03, 0.05, 0.72))
	for chip_label in [deck_summary_label, module_summary_label, charm_summary_label, tune_summary_label]:
		UI_THEME_KIT.apply_numeric(chip_label, 17, Color(0.98, 0.96, 0.88, 1.0), Color(0.06, 0.07, 0.10, 0.92))
		var chip_panel: PanelContainer = chip_label.get_parent().get_parent() as PanelContainer
		if chip_panel != null:
			UI_THEME_KIT.apply_paper_panel(chip_panel)
	UI_THEME_KIT.apply_stone_button(inspect_deck_button, "ghost", 16)
	UI_THEME_KIT.apply_stone_button(inspect_modules_button, "ghost", 16)
	UI_THEME_KIT.apply_stone_button(inspect_tunes_button, "ghost", 16)
	UI_THEME_KIT.apply_stone_button(inspect_charms_button, "ghost", 16)
	UI_MOTION.wire_button_feedback(inspect_deck_button, 1.02, 0.98, Color(0.72, 0.90, 1.0, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(inspect_modules_button, 1.02, 0.98, Color(0.72, 1.0, 0.84, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(inspect_tunes_button, 1.02, 0.98, Color(0.82, 0.96, 1.0, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(inspect_charms_button, 1.02, 0.98, Color(1.0, 0.88, 0.55, 0.72), 5.0)
	UI_THEME_KIT.apply_heading(header_label, 30, Color(0.20, 0.14, 0.09, 1.0))
	UI_THEME_KIT.apply_body(hint_label, 20, Color(0.30, 0.20, 0.12, 0.95))
	UI_THEME_KIT.apply_glass_heading(legend_title_label, 24)
	UI_THEME_KIT.apply_stone_button(settings_button, "ghost", 18)

func _module_accent(rarity: String) -> Color:
	match rarity:
		"Legendary":
			return Color(1.0, 0.86, 0.52, 0.92)
		"Rare":
			return Color(0.80, 0.74, 1.0, 0.92)
		"Uncommon":
			return Color(0.62, 0.90, 0.80, 0.92)
	return Color(0.72, 0.92, 1.0, 0.76)

func _play_intro_animation() -> void:
	UI_MOTION.reveal($TopHUD, 0.02, Vector2.ZERO, 0.28, Vector2(0.985, 0.985))
	UI_MOTION.reveal(info_panel, 0.10, Vector2(-18, 0), 0.28, Vector2(0.99, 0.99))
	var row_delay: float = 0.14
	for row_variant in rows_box.get_children():
		var row_control: Control = row_variant as Control
		if row_control == null:
			continue
		UI_MOTION.reveal(row_control, row_delay, Vector2(0, 12), 0.22, Vector2(0.995, 0.995))
		row_delay += 0.04

func _show_node_preview(node: MapNodeModel) -> void:
	node_detail_title_label.text = LocalizationManager.node_type_name(node.node_type)
	node_detail_body_label.text = _node_preview_summary(node)

func _node_preview_summary(node: MapNodeModel) -> String:
	var route_names: Array[String] = []
	for next_id_variant in node.next_ids:
		var next_id: String = String(next_id_variant)
		var next_node: MapNodeModel = null
		for candidate in RunManager.map_nodes:
			if candidate.id == next_id:
				next_node = candidate
				break
		if next_node != null:
			route_names.append(LocalizationManager.node_type_name(next_node.node_type))
	var route_preview: Array[String] = []
	for index in range(min(route_names.size(), 2)):
		route_preview.append(route_names[index])
	if route_names.size() > 2:
		route_preview.append("…")
	var route_text: String = LocalizationManager.text("map.sidebar_preview_route", [", ".join(route_preview)]) if not route_preview.is_empty() else LocalizationManager.text("map.sidebar_preview_route", [LocalizationManager.text("map.route_no_next")])
	var metadata: Dictionary = node.metadata if typeof(node.metadata) == TYPE_DICTIONARY else {}
	var enemy_ids: Array = metadata.get("enemy_ids", []) if typeof(metadata.get("enemy_ids", [])) == TYPE_ARRAY else []
	var test_hint: String = _node_test_preview(node)
	var enemy_hint: String = ""
	if not enemy_ids.is_empty():
		var preview_names: Array[String] = []
		for enemy_id_variant in enemy_ids:
			var enemy_id: String = String(enemy_id_variant)
			var enemy_data: EnemyData = enemy_db.get(enemy_id, null) as EnemyData
			if enemy_data != null:
				preview_names.append(LocalizationManager.enemy_name(enemy_data.id, enemy_data.display_name))
		if not preview_names.is_empty():
			if preview_names.size() >= 2:
				enemy_hint = LocalizationManager.text("map.sidebar_preview_enemy_brief", [preview_names[0], preview_names.size()])
			else:
				enemy_hint = LocalizationManager.text("map.sidebar_preview_enemy_list", [", ".join(preview_names)])
	var reward_text: String = LocalizationManager.text("reward.continue")
	match node.node_type:
		"battle":
			reward_text = LocalizationManager.text("map.sidebar_reward_battle")
		"elite":
			reward_text = LocalizationManager.text("map.sidebar_reward_elite")
		"boss":
			reward_text = LocalizationManager.text("map.sidebar_reward_boss")
		"shop":
			reward_text = LocalizationManager.text("map.sidebar_reward_shop")
		"event", "story":
			reward_text = LocalizationManager.text("map.sidebar_reward_event")
		"rest":
			reward_text = LocalizationManager.text("map.sidebar_reward_rest")
	var body_lines: Array[String] = [
		LocalizationManager.text("map.sidebar_preview_tests", [test_hint])
	]
	if not enemy_hint.is_empty():
		body_lines.append(enemy_hint)
	var boss_brief: String = String(metadata.get("boss_brief", "")).strip_edges()
	if not boss_brief.is_empty():
		body_lines.append(LocalizationManager.text("map.sidebar_boss_brief", [boss_brief]))
	body_lines.append(route_text)
	body_lines.append(LocalizationManager.text("map.sidebar_preview_reward", [reward_text]))
	return "\n".join(body_lines)

func _restore_node_preview() -> void:
	node_detail_title_label.text = LocalizationManager.text("map.sidebar_preview_title")
	node_detail_body_label.text = LocalizationManager.text("map.sidebar_preview_default")

func _apply_preview_two_nodes() -> void:
	# 事件标记 preview_two_nodes：本层地图额外显示两个可预览节点（tooltip 摘要 + 角标）。
	# 标记持续整层，不在这里消耗。
	if not RunManager.has_flag("preview_two_nodes"):
		return
	var current: MapNodeModel = RunManager.current_node()
	var candidates: Array = []
	for node_variant in RunManager.map_nodes:
		var node: MapNodeModel = node_variant as MapNodeModel
		if node == null or node.completed or node.node_type == "boss":
			continue
		if current != null and node.id == current.id:
			continue
		candidates.append(node)
	# 确定性选取：按行号、再按泳道号排序，取前两个
	candidates.sort_custom(func(a: MapNodeModel, b: MapNodeModel) -> bool:
		if a.row == b.row:
			return a.lane < b.lane
		return a.row < b.row
	)
	for index in range(min(2, candidates.size())):
		var target: MapNodeModel = candidates[index]
		var button: Button = node_buttons.get(target.id, null) as Button
		if button == null:
			continue
		button.tooltip_text = "%s\n%s" % [
			LocalizationManager.node_type_name(target.node_type),
			_node_preview_summary(target)
		]
		_add_preview_badge(button)

func _add_preview_badge(button: Button) -> void:
	if button == null or button.get_node_or_null("PreviewBadge") != null:
		return
	var badge: Label = Label.new()
	badge.name = "PreviewBadge"
	badge.text = LocalizationManager.text("map.preview_badge")
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.layout_mode = 1
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -58.0
	badge.offset_top = 2.0
	badge.offset_right = 2.0
	badge.offset_bottom = 16.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 11)
	badge.modulate = Color(1.0, 1.0, 1.0, 0.75)
	button.add_child(badge)

func _node_test_preview(node: MapNodeModel) -> String:
	var metadata: Dictionary = node.metadata if typeof(node.metadata) == TYPE_DICTIONARY else {}
	var tests: Array = metadata.get("encounter_tests", []) if typeof(metadata.get("encounter_tests", [])) == TYPE_ARRAY else []
	if not tests.is_empty():
		var labels: Array[String] = []
		for test_variant in tests:
			labels.append(_encounter_test_label(String(test_variant)))
		return " / ".join(labels)
	if metadata.has("encounter_primary_test"):
		return _encounter_test_label(String(metadata.get("encounter_primary_test", "")))
	return LocalizationManager.node_type_name(node.node_type)

func _encounter_test_label(test_id: String) -> String:
	match test_id:
		"aoe":
			return LocalizationManager.text("map.test_aoe")
		"armor":
			return LocalizationManager.text("map.test_armor")
		"rear_threat":
			return LocalizationManager.text("map.test_rear_threat")
		"point_kill":
			return LocalizationManager.text("map.test_point_kill")
		"burst":
			return LocalizationManager.text("map.test_burst")
		"attrition":
			return LocalizationManager.text("map.test_attrition")
		"tempo":
			return LocalizationManager.text("map.test_tempo")
		"kill_order":
			return LocalizationManager.text("map.test_kill_order")
	return LocalizationManager.node_type_name(test_id)
