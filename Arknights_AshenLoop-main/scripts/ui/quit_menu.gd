extends Control

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UIThemeKit = preload("res://scripts/ui/ui_theme_kit.gd")

@onready var panel: PanelContainer = $Layout/Center/Panel
@onready var title_label: Label = $Layout/Center/Panel/Margin/Content/Title
@onready var body_label: Label = $Layout/Center/Panel/Margin/Content/Body
@onready var hint_label: Label = $Layout/Center/Panel/Margin/Content/Hint
@onready var confirm_button: Button = $Layout/Center/Panel/Margin/Content/ButtonRow/Confirm
@onready var cancel_button: Button = $Layout/Center/Panel/Margin/Content/ButtonRow/Cancel

func _ready() -> void:
	_apply_theme_kit_styles()
	_apply_text()
	LocalizationManager.language_changed.connect(_apply_text)
	confirm_button.pressed.connect(func() -> void:
		SfxManager.play_ui_click()
		RunManager.flush_persistent_state()
		get_tree().quit()
	)
	cancel_button.pressed.connect(func() -> void:
		SfxManager.play_ui_click()
		SceneRouter.go_main_menu()
	)
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)

func _apply_theme_kit_styles() -> void:
	# 面板：真毛玻璃（叠加模糊背景）
	UIThemeKit.apply_glass_panel_blurred(panel, 3.0)
	# 标题：红色大标题（提示破坏性操作）+ 深色描边
	UIThemeKit.apply_glass_heading(title_label, 42)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.66, 0.60, 1.0))
	# 正文：玻璃质感
	UIThemeKit.apply_glass_body(body_label, 22)
	UIThemeKit.apply_glass_body(hint_label, 17)
	# 取消按钮：ghost 变体（弱化，引导用户选择安全项）
	UIThemeKit.apply_stone_button(cancel_button, "ghost", 24)
	# 确认按钮：danger 变体（红色强调，提示破坏性）
	UIThemeKit.apply_stone_button(confirm_button, "danger", 24)

func _apply_text(_language_code: String = "") -> void:
	title_label.text = LocalizationManager.text("quit.title")
	body_label.text = LocalizationManager.text("quit.body")
	hint_label.text = LocalizationManager.text("quit.hint")
	confirm_button.text = LocalizationManager.text("quit.confirm")
	cancel_button.text = LocalizationManager.text("quit.cancel")

func _play_intro_animation() -> void:
	UI_MOTION.reveal(panel, 0.04, Vector2(0, 12), 0.26, Vector2(0.98, 0.98))
