class_name TutorialOverlay
extends Control

signal dismissed

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

var frame: PanelContainer
var title_label: Label
var body_label: Label
var confirm_button: Button


func _ready() -> void:
	layout_mode = 3
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 600
	_build_ui()
	_apply_text()
	LocalizationManager.language_changed.connect(_apply_text)

func _exit_tree() -> void:
	# 断开 autoload 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)


func _build_ui() -> void:
	# 全屏遮罩
	var shade := ColorRect.new()
	shade.layout_mode = 1
	shade.anchor_left = 0.0
	shade.anchor_top = 0.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# 玻璃面板
	frame = PanelContainer.new()
	frame.layout_mode = 1
	frame.anchor_left = 0.14
	frame.anchor_top = 0.12
	frame.anchor_right = 0.86
	frame.anchor_bottom = 0.88
	frame.self_modulate = Color(1, 1, 1, 0.98)
	add_child(frame)
	UI_THEME_KIT.apply_glass_panel(frame)

	# 内边距
	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	frame.add_child(margin)

	# 垂直布局
	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# 标题
	title_label = Label.new()
	title_label.layout_mode = 2
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	UI_THEME_KIT.apply_heading(title_label, 38, Color(1.0, 0.88, 0.66, 1.0), Color(0.06, 0.05, 0.04, 0.88))
	title_label.add_theme_constant_override("outline_size", 4)

	# 正文
	body_label = Label.new()
	body_label.layout_mode = 2
	body_label.autowrap_mode = 3
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_label)
	UI_THEME_KIT.apply_glass_body(body_label, 20)

	# 弹性间隔
	var spacer := Control.new()
	spacer.layout_mode = 2
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# 确认按钮
	confirm_button = Button.new()
	confirm_button.layout_mode = 2
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(confirm_button)
	UI_THEME_KIT.apply_stone_button(confirm_button, "paper", 24)
	UI_MOTION.wire_button_feedback(confirm_button, 1.03, 0.97, Color(1.0, 0.88, 0.66, 0.78), 5.0)

	confirm_button.pressed.connect(_on_confirm_pressed)


func _apply_text(_language_code: String = "") -> void:
	if title_label == null:
		return
	title_label.text = LocalizationManager.text("tutorial.title")
	body_label.text = LocalizationManager.text("tutorial.body")
	confirm_button.text = LocalizationManager.text("tutorial.confirm")


func _on_confirm_pressed() -> void:
	if SfxManager != null:
		SfxManager.play_ui_click()
	SettingsManager.mark_tutorial_completed()
	dismissed.emit()
	queue_free()
