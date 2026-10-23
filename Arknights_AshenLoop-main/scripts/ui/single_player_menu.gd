extends Control

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UIThemeKit = preload("res://scripts/ui/ui_theme_kit.gd")
const PLAYABLE_CHARACTER_ORDER: Array[String] = ["amiya", "nearl", "exusiai", "kaltsit"]

@onready var scene_tag: Label = $SceneTag
@onready var info_panel: Control = $InfoPanel
@onready var info_margin: MarginContainer = $InfoPanel/InfoMargin
@onready var info_box: VBoxContainer = $InfoPanel/InfoMargin/InfoBox
@onready var header_label: Label = $InfoPanel/InfoMargin/InfoBox/Header
@onready var stat_line_label: Label = $InfoPanel/InfoMargin/InfoBox/StatLine
@onready var info_scroll: ScrollContainer = $InfoPanel/InfoMargin/InfoBox/InfoScroll
@onready var info_scroll_box: VBoxContainer = $InfoPanel/InfoMargin/InfoBox/InfoScroll/InfoScrollBox
@onready var body_label: Label = $InfoPanel/InfoMargin/InfoBox/InfoScroll/InfoScrollBox/Body
@onready var skill_header_label: Label = $InfoPanel/InfoMargin/InfoBox/InfoScroll/InfoScrollBox/SkillHeader
@onready var status_label: Label = $InfoPanel/InfoMargin/InfoBox/InfoScroll/InfoScrollBox/Status
@onready var hero_image: TextureRect = $HeroImage
@onready var amiya_button: Button = $PortraitStrip/StripMargin/Operators/Amiya
@onready var nearl_button: Button = $PortraitStrip/StripMargin/Operators/Locked1
@onready var exusiai_button: Button = $PortraitStrip/StripMargin/Operators/Locked2
@onready var kaltsit_button: Button = $PortraitStrip/StripMargin/Operators/Locked3
@onready var locked_buttons: Array[Button] = [
	$PortraitStrip/StripMargin/Operators/Locked4,
	$PortraitStrip/StripMargin/Operators/Locked5
]
@onready var back_button: Button = $Back
@onready var start_button: Button = $StartGame
@onready var ascension_panel: PanelContainer = $AscensionPanel
@onready var ascension_minus_button: Button = $AscensionPanel/AscensionMargin/AscensionBox/AscensionMinus
@onready var ascension_plus_button: Button = $AscensionPanel/AscensionMargin/AscensionBox/AscensionPlus
@onready var ascension_value_label: Label = $AscensionPanel/AscensionMargin/AscensionBox/AscensionValue
@onready var ascension_label: Label = $AscensionPanel/AscensionMargin/AscensionBox/AscensionLabel

var playable_buttons: Dictionary = {}
var selected_character_id: String = ""
var amiya_tile: Texture2D
var nearl_tile: Texture2D
var exusiai_tile: Texture2D
var kaltsit_tile: Texture2D
var locked_tile: Texture2D
var back_tile: Texture2D
var start_tile: Texture2D
var selected_operator_button: Button = null
var hero_transition_layer: Control
var hero_transition_old: TextureRect
var hero_transition_new: TextureRect
var hero_transition_flash: ColorRect
var hero_transition_tween: Tween
var overwrite_save_dialog: ConfirmationDialog

func _ready() -> void:
	MusicManager.play_menu_bgm()
	playable_buttons = {
		"amiya": amiya_button,
		"nearl": nearl_button,
		"exusiai": exusiai_button,
		"kaltsit": kaltsit_button
	}
	amiya_tile = load("res://assets/ui_icons/amiya_tile.svg") as Texture2D
	nearl_tile = load("res://assets/ui_icons/nearl_tile.svg") as Texture2D
	exusiai_tile = load("res://assets/ui_icons/exusiai_tile.svg") as Texture2D
	kaltsit_tile = load("res://assets/ui_icons/kaltsit_tile.svg") as Texture2D
	locked_tile = load("res://assets/ui_icons/locked_tile.svg") as Texture2D
	back_tile = load("res://assets/ui_icons/back_tile.svg") as Texture2D
	start_tile = load("res://assets/ui_icons/start_tile.svg") as Texture2D
	_ensure_hero_transition_layer()
	_build_overwrite_save_dialog()
	LocalizationManager.language_changed.connect(_apply_text)
	for character_id in playable_buttons.keys():
		var button: Button = playable_buttons[character_id] as Button
		if button != null:
			button.pressed.connect(func(target_id: String = character_id) -> void:
				_select_character(target_id)
			)
	_apply_operator_icons()
	# 角色解锁门控：通过 MetaUnlockManager 判断角色是否可用
	# 当前 4 个角色 unlock_flags 均为空（无条件解锁），locked_buttons 是未来角色占位符
	for button in locked_buttons:
		button.disabled = true
		button.tooltip_text = LocalizationManager.text("menu.locked_character_hint")
		_attach_stone_feedback(button)
	for button_variant in playable_buttons.values():
		var playable_button: Button = button_variant as Button
		if playable_button != null:
			playable_button.disabled = false
			_attach_stone_feedback(playable_button)
	# 检查已注册角色是否需要 unlock 条件（未来扩展用，当前 4 个角色均为无条件解锁）
	for character_id in PLAYABLE_CHARACTER_ORDER:
		var char_data: CharacterData = Util.load_character(character_id)
		if char_data != null and not char_data.unlock_flags.is_empty():
			if MetaUnlockManager != null and not MetaUnlockManager.check_character_unlock(char_data):
				var button_to_lock: Button = playable_buttons.get(character_id) as Button
				if button_to_lock != null:
					button_to_lock.disabled = true
					button_to_lock.tooltip_text = LocalizationManager.text("menu.locked_character_hint")
	start_button.pressed.connect(_start_selected_run)
	_attach_stone_feedback(back_button)
	_attach_stone_feedback(start_button)
	# 难度选择按钮
	ascension_minus_button.pressed.connect(_on_ascension_minus)
	ascension_plus_button.pressed.connect(_on_ascension_plus)
	_attach_stone_feedback(ascension_minus_button)
	_attach_stone_feedback(ascension_plus_button)
	_refresh_ascension_display()
	_apply_safe_info_layout()
	get_viewport().size_changed.connect(_apply_safe_info_layout)
	back_button.pressed.connect(func() -> void:
		_press_and_call(back_button, Callable(SceneRouter, "go_main_menu"))
	)
	_select_character("amiya")
	call_deferred("_refresh_all_button_feedback")
	call_deferred("_apply_theme_kit_styles")
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload / viewport 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)
	var vp: Window = get_viewport()
	if vp != null and vp.size_changed.is_connected(_apply_safe_info_layout):
		vp.size_changed.disconnect(_apply_safe_info_layout)

func _apply_theme_kit_styles() -> void:
	# 信息面板：玻璃质感（与战斗/商店的玻璃面板统一）
	UIThemeKit.apply_glass_panel(info_panel)
	# 头部标题：玻璃质感大标题
	UIThemeKit.apply_glass_heading(header_label, 28)
	# 属性行：玻璃质感正文
	UIThemeKit.apply_glass_body(stat_line_label, 17)
	# 正文/状态：玻璃质感
	UIThemeKit.apply_glass_body(body_label, 16)
	UIThemeKit.apply_glass_body(status_label, 16)
	# 技能标题：玻璃质感中标题（琥珀金）
	UIThemeKit.apply_glass_heading(skill_header_label, 20)
	# 场景标签：琥珀金大标题
	UIThemeKit.apply_heading(scene_tag, 28, Color(0.97, 0.90, 0.52, 1.0), Color(0.04, 0.04, 0.06, 0.84))
	scene_tag.add_theme_constant_override("outline_size", 3)
	# 头像条容器：玻璃面板
	var strip_panel: PanelContainer = $PortraitStrip
	UIThemeKit.apply_glass_panel(strip_panel)
	# 难度面板：玻璃面板（小幅）
	var ascension_panel_container: PanelContainer = $AscensionPanel
	UIThemeKit.apply_glass_panel(ascension_panel_container)
	# 难度标签：琥珀金
	UIThemeKit.apply_chip_label(ascension_label, Color(0.97, 0.90, 0.52, 0.92), 18)
	# 难度数值：琥珀金大号
	UIThemeKit.apply_numeric(ascension_value_label, 24, Color(1.0, 0.85, 0.40, 1.0))
	# 返回/开始按钮：石材按钮（ghost 变体，保持 flat 视觉但统一主题色）
	# 注意：这两个按钮已有 ActionIcon 子节点和 feedback ring，apply_stone_button 会添加 normal/hover/pressed 样式
	# 但因为按钮 flat=true 且有自定义 icon，我们用更轻量的方式：只统一字体颜色和描边
	_apply_action_button_theme(back_button)
	_apply_action_button_theme(start_button)
	# 难度 +/- 按钮：小号石材按钮
	_apply_ascension_button_theme(ascension_minus_button)
	_apply_ascension_button_theme(ascension_plus_button)

func _apply_action_button_theme(button: Button) -> void:
	# 保持 flat 视觉，但统一字体描边和阴影
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.88))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.42))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)
	button.add_theme_constant_override("shadow_outline_size", 1)

func _apply_ascension_button_theme(button: Button) -> void:
	# 难度 +/- 按钮：保持 flat，统一描边
	button.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.84))
	button.add_theme_constant_override("outline_size", 2)

func _apply_safe_info_layout() -> void:
	if info_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact_layout: bool = viewport_size.y < 820.0
	var short_layout: bool = viewport_size.y < 760.0
	var safe_right_margin: float = 72.0
	var safe_top: float = 88.0
	var bottom_buttons_top: float = viewport_size.y - 154.0
	var safe_bottom_y: float = bottom_buttons_top - (28.0 if compact_layout else 42.0)
	var available_height: float = max(220.0, safe_bottom_y - safe_top)
	var min_panel_height: float = 240.0 if short_layout else (300.0 if compact_layout else 360.0)
	var panel_width: float = clamp(viewport_size.x * 0.32, 360.0, 540.0)
	var panel_height: float = clamp(available_height, min_panel_height, 486.0)
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.anchor_top = 0.0
	info_panel.anchor_bottom = 0.0
	info_panel.offset_left = -safe_right_margin - panel_width
	info_panel.offset_right = -safe_right_margin
	info_panel.offset_top = safe_top
	info_panel.offset_bottom = safe_top + panel_height
	info_panel.clip_contents = true
	if info_margin != null:
		info_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		info_margin.offset_left = 0.0
		info_margin.offset_top = 0.0
		info_margin.offset_right = 0.0
		info_margin.offset_bottom = 0.0
		info_margin.add_theme_constant_override("margin_left", 20)
		info_margin.add_theme_constant_override("margin_top", 20)
		info_margin.add_theme_constant_override("margin_right", 20)
		info_margin.add_theme_constant_override("margin_bottom", 20)
	if info_box != null:
		info_box.add_theme_constant_override("separation", 9)
	if info_scroll != null:
		info_scroll.custom_minimum_size = Vector2(0.0, 185.0 if compact_layout else 250.0)
	if info_scroll_box != null:
		info_scroll_box.add_theme_constant_override("separation", 9)
	var wrapped_labels: Array[Label] = [header_label, stat_line_label, body_label, skill_header_label, status_label]
	for label in wrapped_labels:
		if label == null:
			continue
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_font_size_override("font_size", 27 if compact_layout else 28)
	stat_line_label.add_theme_font_size_override("font_size", 17)
	body_label.add_theme_font_size_override("font_size", 16)
	skill_header_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_font_size_override("font_size", 16)
	body_label.max_lines_visible = 7 if compact_layout else 9
	status_label.max_lines_visible = 8 if compact_layout else 11
	if info_scroll != null:
		info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		info_scroll.clip_contents = true

func _apply_operator_icons() -> void:
	_apply_playable_tile(amiya_button, amiya_tile, "amiya")
	_apply_playable_tile(nearl_button, nearl_tile, "nearl")
	_apply_playable_tile(exusiai_button, exusiai_tile, "exusiai")
	_apply_playable_tile(kaltsit_button, kaltsit_tile, "kaltsit")
	for button in locked_buttons:
		_embed_button_icon(button, locked_tile)
		button.text = ""
		button.tooltip_text = ""
	_embed_action_button(back_button, back_tile)
	_embed_action_button(start_button, start_tile)

func _apply_playable_tile(button: Button, texture: Texture2D, character_id: String) -> void:
	if button == null:
		return
	_embed_button_icon(button, texture)
	button.text = ""
	button.tooltip_text = LocalizationManager.character_name(character_id, character_id.capitalize())

func _embed_button_icon(button: Button, texture: Texture2D) -> void:
	var icon_rect_node: Node = button.get_node_or_null("TileIcon")
	var icon_rect: TextureRect = icon_rect_node as TextureRect
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "TileIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.layout_mode = 1
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.offset_left = 0.0
		icon_rect.offset_top = 0.0
		icon_rect.offset_right = 0.0
		icon_rect.offset_bottom = 0.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon_rect)
	icon_rect.texture = texture

func _embed_action_button(button: Button, texture: Texture2D) -> void:
	var icon_rect_node: Node = button.get_node_or_null("ActionIcon")
	var icon_rect: TextureRect = icon_rect_node as TextureRect
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "ActionIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.layout_mode = 1
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 0.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.offset_left = 0.0
		icon_rect.offset_top = 0.0
		icon_rect.offset_right = 96.0
		icon_rect.offset_bottom = 0.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon_rect)
	icon_rect.texture = texture

func _attach_stone_feedback(button: Button) -> void:
	_ensure_feedback_ring(button)
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func() -> void:
		_apply_button_visual_state(button, false)
	)
	button.button_down.connect(func() -> void:
		_apply_button_visual_state(button, true)
	)
	button.button_up.connect(func() -> void:
		_apply_button_visual_state(button, false)
	)
	button.mouse_exited.connect(func() -> void:
		_apply_button_visual_state(button, false)
	)
	_apply_button_visual_state(button, false)

func _set_button_pressed_visual(button: Button, pressed: bool) -> void:
	var icon_rect: Control = button.get_node_or_null("ActionIcon") as Control
	if icon_rect == null:
		icon_rect = button.get_node_or_null("TileIcon") as Control
	if icon_rect != null:
		icon_rect.position = Vector2(0, 3) if pressed else Vector2.ZERO

func _ensure_feedback_ring(button: Button) -> void:
	var ring: Panel = button.get_node_or_null("FeedbackRing") as Panel
	if ring != null:
		return
	ring = Panel.new()
	ring.name = "FeedbackRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.layout_mode = 1
	if button.get_node_or_null("TileIcon") != null:
		ring.anchor_left = 0.0
		ring.anchor_top = 0.0
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = 0.0
		ring.offset_top = 0.0
		ring.offset_right = 0.0
		ring.offset_bottom = 0.0
	else:
		ring.anchor_left = 0.0
		ring.anchor_top = 0.0
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = -4.0
		ring.offset_top = -4.0
		ring.offset_right = 4.0
		ring.offset_bottom = 4.0
	button.add_child(ring)
	button.move_child(ring, 0)

func _apply_button_visual_state(button: Button, pressed: bool) -> void:
	var hovered: bool = button.get_global_rect().has_point(button.get_global_mouse_position())
	var selected: bool = button == selected_operator_button
	button.pivot_offset = button.size * 0.5
	var is_tile_button: bool = button.get_node_or_null("TileIcon") != null
	if is_tile_button:
		button.scale = Vector2.ONE
	elif pressed:
		button.scale = Vector2(0.96, 0.96)
	elif hovered:
		button.scale = Vector2(1.03, 1.03)
	else:
		button.scale = Vector2.ONE
	_set_button_pressed_visual(button, pressed)
	_update_feedback_ring(button, hovered, selected, pressed)

func _update_feedback_ring(button: Button, hovered: bool, selected: bool, pressed: bool) -> void:
	var ring: Panel = button.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	var is_tile_button: bool = button.get_node_or_null("TileIcon") != null
	var corner_radius: int = 14 if is_tile_button else 18
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if selected:
		style.border_color = Color(0.88, 0.97, 1.0, 0.95)
		style.shadow_color = Color(0.60, 0.86, 1.0, 0.58)
		style.shadow_size = 12 if is_tile_button else 18
		style.shadow_offset = Vector2.ZERO
	elif hovered:
		style.border_color = Color(0.82, 0.95, 1.0, 0.74)
		style.shadow_color = Color(0.48, 0.78, 1.0, 0.42)
		style.shadow_size = 10 if is_tile_button else 14
		style.shadow_offset = Vector2.ZERO
	else:
		style.border_color = Color(0.82, 0.95, 1.0, 0.0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
	if pressed:
		style.shadow_size = max(0, style.shadow_size - 10)
	ring.add_theme_stylebox_override("panel", style)

func _select_character(character_id: String) -> void:
	var previous_character_id: String = selected_character_id
	var selection_changed: bool = previous_character_id != character_id
	if selection_changed:
		SfxManager.play_ui_click()
	selected_character_id = character_id
	selected_operator_button = playable_buttons.get(character_id, amiya_button) as Button
	var selection_texture: Texture2D = Util.load_character_selection_image(character_id)
	if not selection_changed or previous_character_id.is_empty():
		_apply_hero_image(selection_texture)
	else:
		_play_character_switch_transition(previous_character_id, character_id, selection_texture)
	start_button.disabled = false
	_apply_text()
	if selection_changed and not previous_character_id.is_empty():
		_play_selection_text_transition(_character_switch_direction(previous_character_id, character_id))
	_refresh_all_button_feedback()

func _start_selected_run() -> void:
	if selected_character_id.is_empty():
		return
	SfxManager.play_ui_click()
	var save_data: Dictionary = RunManager.saved_run_summary()
	if RunManager.has_saved_run() and String(save_data.get("character_id", "")) == selected_character_id:
		if RunManager.load_saved_run():
			UI_MOTION.pulse_then(start_button, Callable(self, "_resume_saved_run"), 0.96, 1.02, 0.06)
			return
	if RunManager.has_conflicting_saved_run(selected_character_id):
		_show_overwrite_save_dialog()
		return
	_begin_new_run_for_selected_character()

func _on_ascension_minus() -> void:
	SfxManager.play_ui_click()
	var current: int = SettingsManager.get_ascension_level()
	SettingsManager.set_ascension_level(current - 1)
	_refresh_ascension_display()

func _on_ascension_plus() -> void:
	SfxManager.play_ui_click()
	var current: int = SettingsManager.get_ascension_level()
	var unlocked: int = SettingsManager.get_ascension_unlocked()
	# 仅允许在已解锁范围内上调
	var next_level: int = min(current + 1, unlocked)
	SettingsManager.set_ascension_level(next_level)
	_refresh_ascension_display()

func _refresh_ascension_display() -> void:
	var level: int = SettingsManager.get_ascension_level()
	var unlocked: int = SettingsManager.get_ascension_unlocked()
	ascension_value_label.text = str(level)
	ascension_minus_button.disabled = level <= 0
	# + 按钮上限为已解锁难度（而非 MAX_ASCENSION_LEVEL）
	ascension_plus_button.disabled = level >= unlocked
	ascension_value_label.tooltip_text = _ascension_tooltip(level, unlocked)

func _ascension_tooltip(level: int, unlocked: int) -> String:
	if level <= 0:
		return LocalizationManager.text("ascension.tooltip_zero_unlock", [unlocked])
	return LocalizationManager.text("ascension.tooltip_active_unlock", [level, unlocked])

func _apply_text(_language_code: String = "") -> void:
	scene_tag.text = LocalizationManager.text("single.header")
	back_button.text = ""
	back_button.tooltip_text = LocalizationManager.text("single.back")
	start_button.text = ""
	start_button.tooltip_text = _start_button_text()
	ascension_label.text = LocalizationManager.text("ascension.label")
	_refresh_ascension_display()
	_apply_operator_icons()
	if playable_buttons.has(selected_character_id):
		header_label.text = LocalizationManager.character_header(selected_character_id, LocalizationManager.text("single.header"))
		stat_line_label.text = LocalizationManager.character_stats(selected_character_id, "")
		body_label.text = LocalizationManager.character_intro(selected_character_id, LocalizationManager.text("single.body"))
		skill_header_label.text = LocalizationManager.text("single.skill_header")
		status_label.text = _selected_character_status_text()
	else:
		header_label.text = LocalizationManager.text("single.header")
		stat_line_label.text = ""
		body_label.text = LocalizationManager.text("single.body")
		skill_header_label.text = LocalizationManager.text("single.skill_header")
		var profile: Dictionary = SaveManager.load_profile()
		var stats: Dictionary = profile.get("stats", {}) if typeof(profile.get("stats", {})) == TYPE_DICTIONARY else {}
		status_label.text = LocalizationManager.text("single.status", [int(stats.get("runs_started", 0))])
	_refresh_overwrite_save_dialog()

func _selected_character_status_text() -> String:
	var base_text: String = LocalizationManager.character_mechanic(selected_character_id, "")
	var save_data: Dictionary = RunManager.saved_run_summary()
	if save_data.is_empty() or String(save_data.get("character_id", "")) != selected_character_id:
		return base_text
	return "%s\n\n%s" % [
		base_text,
		LocalizationManager.text("single.resume_hint", [
			int(save_data.get("current_floor", 1)),
			int(save_data.get("gold", 0)),
			int(save_data.get("hp", 0)),
			int(save_data.get("max_hp", 0))
		])
	]

func _start_button_text() -> String:
	var save_data: Dictionary = RunManager.saved_run_summary()
	if not save_data.is_empty() and String(save_data.get("character_id", "")) == selected_character_id:
		return LocalizationManager.text("single.resume")
	return LocalizationManager.text("single.start")

func _build_overwrite_save_dialog() -> void:
	overwrite_save_dialog = ConfirmationDialog.new()
	overwrite_save_dialog.name = "OverwriteSaveDialog"
	overwrite_save_dialog.exclusive = true
	add_child(overwrite_save_dialog)
	overwrite_save_dialog.confirmed.connect(_confirm_overwrite_saved_run)
	_refresh_overwrite_save_dialog()

func _refresh_overwrite_save_dialog() -> void:
	if overwrite_save_dialog == null:
		return
	overwrite_save_dialog.title = LocalizationManager.text("single.overwrite_save_title")
	overwrite_save_dialog.ok_button_text = LocalizationManager.text("single.overwrite_save_confirm")
	overwrite_save_dialog.cancel_button_text = LocalizationManager.text("single.overwrite_save_cancel")

func _show_overwrite_save_dialog() -> void:
	if overwrite_save_dialog == null:
		return
	var save_data: Dictionary = RunManager.saved_run_summary()
	var saved_character_id: String = String(save_data.get("character_id", "amiya"))
	var saved_character_name: String = LocalizationManager.character_name(saved_character_id, saved_character_id.capitalize())
	var next_character_name: String = LocalizationManager.character_name(selected_character_id, selected_character_id.capitalize())
	overwrite_save_dialog.dialog_text = LocalizationManager.text("single.overwrite_save_body", [
		saved_character_name,
		int(save_data.get("current_floor", 1)),
		int(save_data.get("hp", 0)),
		int(save_data.get("max_hp", 0)),
		int(save_data.get("gold", 0)),
		next_character_name
	])
	overwrite_save_dialog.popup_centered()

func _confirm_overwrite_saved_run() -> void:
	RunManager.clear_saved_run()
	_begin_new_run_for_selected_character()

func _begin_new_run_for_selected_character() -> void:
	var character_data: CharacterData = Util.load_character(selected_character_id)
	if character_data == null:
		status_label.text = LocalizationManager.text("single.missing_character_resource", [selected_character_id])
		return
	RunManager.start_new_run(character_data)
	UI_MOTION.pulse_then(start_button, Callable(SceneRouter, "go_map"), 0.96, 1.02, 0.06)

func _resume_saved_run() -> void:
	if not RunManager.pending_rewards.is_empty():
		SceneRouter.go_reward()
		return
	var node: MapNodeModel = RunManager.current_node()
	if node == null:
		SceneRouter.go_map()
		return
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
			SceneRouter.go_map()

func _refresh_all_button_feedback() -> void:
	for button_variant in playable_buttons.values():
		var playable_button: Button = button_variant as Button
		if playable_button != null:
			_apply_button_visual_state(playable_button, false)
	for button in locked_buttons:
		_apply_button_visual_state(button, false)
	_apply_button_visual_state(back_button, false)
	_apply_button_visual_state(start_button, false)

func _apply_hero_image(texture: Texture2D) -> void:
	hero_image.texture = texture
	hero_image.visible = texture != null
	hero_image.position = Vector2.ZERO
	hero_image.scale = Vector2.ONE
	hero_image.modulate = Color(1, 1, 1, 1)

func _ensure_hero_transition_layer() -> void:
	if hero_transition_layer != null:
		return
	hero_transition_layer = Control.new()
	hero_transition_layer.name = "HeroTransitionLayer"
	hero_transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_transition_layer.layout_mode = 1
	hero_transition_layer.anchor_left = 0.0
	hero_transition_layer.anchor_top = 0.0
	hero_transition_layer.anchor_right = 1.0
	hero_transition_layer.anchor_bottom = 1.0
	hero_transition_layer.offset_left = 0.0
	hero_transition_layer.offset_top = 0.0
	hero_transition_layer.offset_right = 0.0
	hero_transition_layer.offset_bottom = 0.0
	hero_transition_layer.visible = false
	add_child(hero_transition_layer)
	move_child(hero_transition_layer, hero_image.get_index() + 1)

	hero_transition_old = TextureRect.new()
	hero_transition_old.name = "PreviousHero"
	hero_transition_old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_transition_old.layout_mode = 1
	hero_transition_old.anchor_left = 0.0
	hero_transition_old.anchor_top = 0.0
	hero_transition_old.anchor_right = 1.0
	hero_transition_old.anchor_bottom = 1.0
	hero_transition_old.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_transition_old.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_transition_layer.add_child(hero_transition_old)

	hero_transition_new = TextureRect.new()
	hero_transition_new.name = "NextHero"
	hero_transition_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_transition_new.layout_mode = 1
	hero_transition_new.anchor_left = 0.0
	hero_transition_new.anchor_top = 0.0
	hero_transition_new.anchor_right = 1.0
	hero_transition_new.anchor_bottom = 1.0
	hero_transition_new.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_transition_new.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_transition_layer.add_child(hero_transition_new)

	hero_transition_flash = ColorRect.new()
	hero_transition_flash.name = "HeroFlash"
	hero_transition_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_transition_flash.layout_mode = 1
	hero_transition_flash.anchor_left = 0.0
	hero_transition_flash.anchor_top = 0.0
	hero_transition_flash.anchor_right = 1.0
	hero_transition_flash.anchor_bottom = 1.0
	hero_transition_flash.color = Color(0.16, 0.06, 0.08, 0.0)
	hero_transition_layer.add_child(hero_transition_flash)

func _kill_hero_transition_tween() -> void:
	if hero_transition_tween != null:
		hero_transition_tween.kill()
		hero_transition_tween = null
	if hero_transition_layer != null and hero_transition_layer.visible:
		if hero_transition_new != null and hero_transition_new.texture != null:
			_apply_hero_image(hero_transition_new.texture)
		hero_transition_layer.visible = false
		if hero_transition_old != null:
			hero_transition_old.texture = null
		if hero_transition_new != null:
			hero_transition_new.texture = null

func _character_switch_direction(previous_character_id: String, next_character_id: String) -> int:
	var previous_index: int = PLAYABLE_CHARACTER_ORDER.find(previous_character_id)
	var next_index: int = PLAYABLE_CHARACTER_ORDER.find(next_character_id)
	if previous_index == -1 or next_index == -1 or previous_index == next_index:
		return 1
	return 1 if next_index > previous_index else -1

func _play_character_switch_transition(previous_character_id: String, next_character_id: String, next_texture: Texture2D) -> void:
	if next_texture == null:
		_apply_hero_image(next_texture)
		return
	_ensure_hero_transition_layer()
	_kill_hero_transition_tween()
	var previous_texture: Texture2D = hero_image.texture
	if previous_texture == null:
		_apply_hero_image(next_texture)
		return
	hero_transition_old.texture = previous_texture
	hero_transition_old.visible = true
	hero_transition_old.position = Vector2.ZERO
	hero_transition_old.scale = Vector2.ONE
	hero_transition_old.modulate = Color(1, 1, 1, 0.94)

	var direction: int = _character_switch_direction(previous_character_id, next_character_id)
	var outgoing_offset: Vector2 = Vector2(-72.0 * direction, 0.0)
	var incoming_start: Vector2 = Vector2(88.0 * direction, 0.0)

	hero_transition_new.texture = next_texture
	hero_transition_new.visible = true
	hero_transition_new.position = incoming_start
	hero_transition_new.scale = Vector2(1.03, 1.03)
	hero_transition_new.modulate = Color(1, 1, 1, 0.0)

	hero_transition_flash.color = Color(0.20, 0.08, 0.08, 0.0)
	hero_transition_layer.visible = true
	hero_image.visible = false

	hero_transition_tween = create_tween()
	hero_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	hero_transition_tween.set_parallel(true)
	hero_transition_tween.tween_property(hero_transition_old, "position", outgoing_offset, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hero_transition_tween.tween_property(hero_transition_old, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hero_transition_tween.tween_property(hero_transition_old, "scale", Vector2(0.985, 0.985), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hero_transition_tween.tween_property(hero_transition_new, "position", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hero_transition_tween.tween_property(hero_transition_new, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hero_transition_tween.tween_property(hero_transition_new, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var flash_in: PropertyTweener = hero_transition_tween.tween_property(hero_transition_flash, "color:a", 0.20, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_in.set_delay(0.02)
	var flash_out: PropertyTweener = hero_transition_tween.tween_property(hero_transition_flash, "color:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash_out.set_delay(0.14)

	hero_transition_tween.finished.connect(func() -> void:
		_apply_hero_image(next_texture)
		hero_transition_layer.visible = false
		hero_transition_old.texture = null
		hero_transition_new.texture = null
		hero_transition_tween = null
	, CONNECT_ONE_SHOT)

func _play_selection_text_transition(direction: int = 1) -> void:
	var base_offset: float = -18.0 * direction
	UI_MOTION.reveal(header_label, 0.00, Vector2(base_offset, 0), 0.18, Vector2(0.992, 0.992))
	UI_MOTION.reveal(stat_line_label, 0.02, Vector2(base_offset, 0), 0.18, Vector2(0.992, 0.992))
	UI_MOTION.reveal(body_label, 0.04, Vector2(base_offset * 0.78, 0), 0.20, Vector2(0.992, 0.992))
	UI_MOTION.reveal(skill_header_label, 0.06, Vector2(base_offset * 0.78, 0), 0.18, Vector2(0.992, 0.992))
	UI_MOTION.reveal(status_label, 0.08, Vector2(base_offset * 0.66, 0), 0.20, Vector2(0.992, 0.992))

func _play_intro_animation() -> void:
	UI_MOTION.reveal($SceneTag, 0.02, Vector2(-18, 0), 0.26)
	UI_MOTION.reveal($InfoPanel, 0.06, Vector2(-34, 0), 0.34, Vector2(0.985, 0.985))
	UI_MOTION.reveal($PortraitStrip, 0.12, Vector2(0, 26), 0.34, Vector2(0.99, 0.99))
	UI_MOTION.reveal(back_button, 0.18, Vector2(-16, 18), 0.24)
	UI_MOTION.reveal(start_button, 0.20, Vector2(16, 18), 0.24)
	var operator_buttons: Array = [amiya_button, nearl_button, exusiai_button, kaltsit_button] + locked_buttons
	for i in range(operator_buttons.size()):
		var button: Control = operator_buttons[i] as Control
		if button != null:
			UI_MOTION.reveal(button, 0.22 + float(i) * 0.03, Vector2(0, 14), 0.22)

func _press_and_call(button: Control, action: Callable) -> void:
	SfxManager.play_ui_click()
	UI_MOTION.pulse_then(button, action, 0.96, 1.02, 0.06)
