extends Control

const RESOLUTIONS := ["1920x1080", "1920x1200", "2560x1440", "2560x1600", "1600x900"]
const UI_SCALE_PRESETS := ["auto", "windows", "macbook", "custom"]
const BATTLE_SPEED_OPTIONS := [0.5, 1.0, 1.5, 2.0, 3.0]
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

signal close_requested
signal abandon_requested

@onready var resolution_options: OptionButton = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ResolutionOptions
@onready var display_mode_options: OptionButton = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/DisplayModeOptions
@onready var language_options: OptionButton = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/LanguageOptions
@onready var ui_scale_options: OptionButton = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleOptions
@onready var ui_scale_custom_slider: HSlider = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomSlider
@onready var ui_scale_custom_value: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomValue
@onready var fullscreen_toggle: CheckBox = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/FullscreenToggle
@onready var borderless_toggle: CheckBox = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BorderlessToggle
@onready var vsync_toggle: CheckBox = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VSyncToggle
@onready var auto_end_turn_toggle: CheckBox = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AutoEndTurnToggle
@onready var battle_speed_options: OptionButton = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BattleSpeedOptions
@onready var abandon_run_label: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AbandonRunLabel
@onready var abandon_run_button: Button = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AbandonRunButton
@onready var master_slider: HSlider = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterSlider
@onready var master_value: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterValue
@onready var music_slider: HSlider = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicSlider
@onready var music_value: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicValue
@onready var sfx_slider: HSlider = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxSlider
@onready var sfx_value: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxValue
@onready var voice_slider: HSlider = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceSlider
@onready var voice_value: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceValue
# 新增音量分组控件（动态构建）：警报/特殊/界面/战斗
var warning_label: Label
var warning_slider: HSlider
var warning_value: Label
var special_label: Label
var special_slider: HSlider
var special_value: Label
var ui_volume_label: Label
var ui_volume_slider: HSlider
var ui_volume_value: Label
var combat_label: Label
var combat_slider: HSlider
var combat_value: Label
@onready var back_button: Button = $Margin/LeftPanel/LeftMargin/LeftBox/Footer/Back
@onready var return_main_button: Button = $Margin/LeftPanel/LeftMargin/LeftBox/Footer/ReturnMain
@onready var left_panel: Control = $Margin/LeftPanel

var overlay_mode: bool = false
var battle_finished_provider: Callable = Callable()
var abandon_dialog: ConfirmationDialog = null
var loading_settings: bool = false
# 辅助功能设置控件（动态构建）
var animation_speed_options: OptionButton
var particle_quality_options: OptionButton
var screen_shake_options: OptionButton
var reduce_motion_toggle: CheckBox
var section_labels: Dictionary = {}
var category_tabs: HBoxContainer
var category_buttons: Dictionary = {}
var active_category: String = "video"

func _ready() -> void:
	_configure_overlay_visuals()
	_inject_section_headers()
	_build_category_tabs()
	_build_audio_group_sliders()
	_apply_ui_theme()
	_setup_option_buttons()
	_apply_text()
	_build_accessibility_section()
	_load_saved_settings()
	# overlay 模式下默认选中"游戏"类别，确保"放弃战斗"控件显示在正确分类下
	# （战斗中 enable_overlay_mode() 在 add_child 前调用，is_node_ready() 为 false 时会跳过其中的类别切换）
	if overlay_mode:
		active_category = "game"
	_select_settings_category(active_category)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_bind_interactions()
	# 非战斗 overlay 模式下隐藏"放弃战斗"区域
	if not overlay_mode:
		if abandon_run_button != null:
			abandon_run_button.visible = false
		if abandon_run_label != null:
			abandon_run_label.visible = false
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload 持久信号
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.disconnect(_on_language_changed)

func enable_overlay_mode() -> void:
	overlay_mode = true
	_configure_overlay_visuals()
	if is_node_ready():
		_configure_settings_layout()
	# 战斗 overlay 模式下切到"游戏"类别，让"放弃战斗"控件在正确的分类下显示
	if is_node_ready():
		_select_settings_category("game")

func set_battle_finished_provider(provider: Callable) -> void:
	battle_finished_provider = provider

func _setup_option_buttons() -> void:
	resolution_options.clear()
	display_mode_options.clear()
	language_options.clear()
	ui_scale_options.clear()
	battle_speed_options.clear()
	for item in RESOLUTIONS:
		resolution_options.add_item(item)
	for item in _display_mode_labels():
		display_mode_options.add_item(item)
	for item in _language_labels():
		language_options.add_item(item)
	for item in _ui_scale_option_labels():
		ui_scale_options.add_item(item)
	for item in _battle_speed_option_labels():
		battle_speed_options.add_item(item)
	ui_scale_options.disabled = false
	ui_scale_custom_slider.min_value = SettingsManager.MIN_CUSTOM_UI_SCALE
	ui_scale_custom_slider.max_value = SettingsManager.MAX_CUSTOM_UI_SCALE
	ui_scale_custom_slider.step = 0.05
	battle_speed_options.disabled = false

func _bind_interactions() -> void:
	resolution_options.item_selected.connect(_on_resolution_selected)
	display_mode_options.item_selected.connect(_on_display_mode_selected)
	language_options.item_selected.connect(_on_language_selected)
	ui_scale_options.item_selected.connect(_on_ui_scale_selected)
	ui_scale_custom_slider.value_changed.connect(_on_ui_scale_custom_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	borderless_toggle.toggled.connect(_on_borderless_toggled)
	vsync_toggle.toggled.connect(_on_vsync_toggled)
	auto_end_turn_toggle.toggled.connect(_on_auto_end_turn_toggled)
	battle_speed_options.item_selected.connect(_on_battle_speed_selected)
	abandon_run_button.pressed.connect(_open_abandon_dialog)
	master_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		master_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	music_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		music_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	sfx_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		sfx_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	voice_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		voice_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	warning_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		warning_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	special_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		special_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	ui_volume_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		ui_volume_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	combat_slider.value_changed.connect(func(value: float) -> void:
		if loading_settings:
			return
		combat_value.text = "%d%%" % int(round(value))
		_save_audio_settings()
	)
	back_button.pressed.connect(func() -> void:
		_press_and_call(back_button, Callable(self, "_handle_back"))
	)
	return_main_button.pressed.connect(func() -> void:
		_press_and_call(return_main_button, Callable(self, "_return_to_main"))
	)

func _load_saved_settings() -> void:
	loading_settings = true
	var settings: Dictionary = SettingsManager.get_settings()
	_select_resolution(String(settings.get("resolution", RESOLUTIONS[0])))
	display_mode_options.select(int(settings.get("display_mode", 0)))
	fullscreen_toggle.set_pressed_no_signal(bool(settings.get("fullscreen", false)))
	borderless_toggle.set_pressed_no_signal(bool(settings.get("borderless", false)))
	vsync_toggle.set_pressed_no_signal(bool(settings.get("vsync", true)))
	auto_end_turn_toggle.set_pressed_no_signal(bool(settings.get("auto_end_turn", false)))
	_select_ui_scale_preset(String(settings.get("ui_scale_preset", "auto")))
	ui_scale_custom_slider.set_value_no_signal(float(settings.get("ui_scale_custom", SettingsManager.LOGICAL_UI_SCALE)))
	ui_scale_custom_value.text = "%d%%" % int(round(ui_scale_custom_slider.value * 100.0))
	_update_ui_scale_custom_visibility(String(settings.get("ui_scale_preset", "auto")))
	_select_battle_speed(float(settings.get("battle_speed", SettingsManager.DEFAULT_BATTLE_SPEED)))
	master_slider.set_value_no_signal(float(settings.get("master_volume", 80.0)))
	music_slider.set_value_no_signal(float(settings.get("music_volume", 70.0)))
	sfx_slider.set_value_no_signal(float(settings.get("sfx_volume", 75.0)))
	voice_slider.set_value_no_signal(float(settings.get("voice_volume", 85.0)))
	warning_slider.set_value_no_signal(float(settings.get("warning_volume", 80.0)))
	special_slider.set_value_no_signal(float(settings.get("special_volume", 80.0)))
	ui_volume_slider.set_value_no_signal(float(settings.get("ui_volume", 80.0)))
	combat_slider.set_value_no_signal(float(settings.get("combat_volume", 80.0)))
	master_value.text = "%d%%" % int(round(master_slider.value))
	music_value.text = "%d%%" % int(round(music_slider.value))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value))
	voice_value.text = "%d%%" % int(round(voice_slider.value))
	warning_value.text = "%d%%" % int(round(warning_slider.value))
	special_value.text = "%d%%" % int(round(special_slider.value))
	ui_volume_value.text = "%d%%" % int(round(ui_volume_slider.value))
	combat_value.text = "%d%%" % int(round(combat_slider.value))
	if LocalizationManager.current_language == LocalizationManager.LANG_ZH:
		language_options.select(0)
	else:
		language_options.select(1)
	# 辅助功能设置
	_load_accessibility_settings(settings)
	loading_settings = false


func _load_accessibility_settings(settings: Dictionary) -> void:
	if animation_speed_options != null:
		var anim_speed: float = float(settings.get("animation_speed", 1.0))
		var anim_index: int = 1
		if anim_speed <= 0.6:
			anim_index = 0
		elif anim_speed >= 1.9:
			anim_index = 3
		elif anim_speed >= 1.4:
			anim_index = 2
		animation_speed_options.select(anim_index)
		# 减少动效模式下禁用单独选项
		animation_speed_options.disabled = bool(settings.get("reduce_motion", false))
	if particle_quality_options != null:
		var quality: String = String(settings.get("particle_quality", "high"))
		var quality_index: int = 2
		match quality:
			"low":
				quality_index = 0
			"medium":
				quality_index = 1
		particle_quality_options.select(quality_index)
		particle_quality_options.disabled = bool(settings.get("reduce_motion", false))
	if screen_shake_options != null:
		var shake: float = float(settings.get("screen_shake", 1.0))
		var shake_index: int = 2
		if shake <= 0.05:
			shake_index = 0
		elif shake <= 0.6:
			shake_index = 1
		elif shake >= 1.4:
			shake_index = 3
		screen_shake_options.select(shake_index)
		screen_shake_options.disabled = bool(settings.get("reduce_motion", false))
	if reduce_motion_toggle != null:
		reduce_motion_toggle.set_pressed_no_signal(bool(settings.get("reduce_motion", false)))

func _apply_text() -> void:
	_apply_section_text()
	_apply_category_tab_text()
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Title.text = LocalizationManager.text("settings.title")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Body.text = LocalizationManager.text("settings.body")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ResolutionLabel.text = LocalizationManager.text("settings.resolution")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/DisplayModeLabel.text = LocalizationManager.text("settings.display_mode")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/LanguageLabel.text = LocalizationManager.text("settings.language")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleLabel.text = LocalizationManager.text("settings.ui_scale")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomLabel.text = LocalizationManager.text("settings.ui_scale_custom")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BattleSpeedLabel.text = LocalizationManager.text("settings.battle_speed")
	abandon_run_label.text = LocalizationManager.text("battle.abandon_section")
	abandon_run_button.text = LocalizationManager.text("battle.abandon")
	abandon_run_button.tooltip_text = LocalizationManager.text("battle.abandon_tooltip")
	fullscreen_toggle.text = LocalizationManager.text("settings.fullscreen")
	borderless_toggle.text = LocalizationManager.text("settings.borderless")
	vsync_toggle.text = LocalizationManager.text("settings.vsync")
	auto_end_turn_toggle.text = LocalizationManager.text("settings.auto_end_turn")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterLabel.text = LocalizationManager.text("settings.audio_group_master")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicLabel.text = LocalizationManager.text("settings.audio_group_music")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxLabel.text = LocalizationManager.text("settings.audio_group_sfx")
	$Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceLabel.text = LocalizationManager.text("settings.audio_group_voice")
	if warning_label != null:
		warning_label.text = LocalizationManager.text("settings.audio_group_warning")
	if special_label != null:
		special_label.text = LocalizationManager.text("settings.audio_group_special")
	if ui_volume_label != null:
		ui_volume_label.text = LocalizationManager.text("settings.audio_group_ui")
	if combat_label != null:
		combat_label.text = LocalizationManager.text("settings.audio_group_combat")
	back_button.text = _back_button_text()
	return_main_button.text = LocalizationManager.text("system.return_main")
	var display_index: int = display_mode_options.selected
	display_mode_options.clear()
	for item in _display_mode_labels():
		display_mode_options.add_item(item)
	display_mode_options.select(clamp(display_index, 0, 2))
	var language_index: int = language_options.selected
	language_options.clear()
	for item in _language_labels():
		language_options.add_item(item)
	language_options.select(clamp(language_index, 0, 1))
	if ui_scale_options.item_count > 0:
		var scale_index: int = ui_scale_options.selected
		ui_scale_options.clear()
		for item in _ui_scale_option_labels():
			ui_scale_options.add_item(item)
		ui_scale_options.select(clamp(scale_index, 0, UI_SCALE_PRESETS.size() - 1))
	if battle_speed_options.item_count > 0:
		var speed_index: int = battle_speed_options.selected
		battle_speed_options.clear()
		for item in _battle_speed_option_labels():
			battle_speed_options.add_item(item)
		battle_speed_options.select(clamp(speed_index, 0, BATTLE_SPEED_OPTIONS.size() - 1))
	_apply_accessibility_text()
	_select_settings_category(active_category)

func _on_language_changed(_language_code: String) -> void:
	_apply_text()


# 刷新动态构建的辅助功能区控件文本（语言切换时调用）
func _apply_accessibility_text() -> void:
	var vbox: VBoxContainer = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox
	var section_label: Label = vbox.get_node_or_null("SectionAccessibility")
	if section_label != null:
		section_label.text = LocalizationManager.text("settings.section_accessibility")
	var anim_label: Label = vbox.get_node_or_null("AnimationSpeedLabel")
	if anim_label != null:
		anim_label.text = LocalizationManager.text("settings.animation_speed")
	var particle_label: Label = vbox.get_node_or_null("ParticleQualityLabel")
	if particle_label != null:
		particle_label.text = LocalizationManager.text("settings.particle_quality")
	var shake_label: Label = vbox.get_node_or_null("ScreenShakeLabel")
	if shake_label != null:
		shake_label.text = LocalizationManager.text("settings.screen_shake")
	var reduce_desc: Label = vbox.get_node_or_null("ReduceMotionDesc")
	if reduce_desc != null:
		reduce_desc.text = LocalizationManager.text("settings.reduce_motion_desc")
	if reduce_motion_toggle != null:
		reduce_motion_toggle.text = LocalizationManager.text("settings.reduce_motion")
	# OptionButton 选项文本刷新（保留当前选中项）
	if animation_speed_options != null and animation_speed_options.item_count > 0:
		var anim_idx: int = animation_speed_options.selected
		animation_speed_options.clear()
		animation_speed_options.add_item(LocalizationManager.text("settings.animation_speed_slow"), 0)
		animation_speed_options.add_item(LocalizationManager.text("settings.animation_speed_normal"), 1)
		animation_speed_options.add_item(LocalizationManager.text("settings.animation_speed_fast"), 2)
		animation_speed_options.add_item(LocalizationManager.text("settings.animation_speed_fastest"), 3)
		animation_speed_options.select(clamp(anim_idx, 0, 3))
	if particle_quality_options != null and particle_quality_options.item_count > 0:
		var particle_idx: int = particle_quality_options.selected
		particle_quality_options.clear()
		particle_quality_options.add_item(LocalizationManager.text("settings.particle_quality_low"), 0)
		particle_quality_options.add_item(LocalizationManager.text("settings.particle_quality_medium"), 1)
		particle_quality_options.add_item(LocalizationManager.text("settings.particle_quality_high"), 2)
		particle_quality_options.select(clamp(particle_idx, 0, 2))
	if screen_shake_options != null and screen_shake_options.item_count > 0:
		var shake_idx: int = screen_shake_options.selected
		screen_shake_options.clear()
		screen_shake_options.add_item(LocalizationManager.text("settings.screen_shake_off"), 0)
		screen_shake_options.add_item(LocalizationManager.text("settings.screen_shake_low"), 1)
		screen_shake_options.add_item(LocalizationManager.text("settings.screen_shake_normal"), 2)
		screen_shake_options.add_item(LocalizationManager.text("settings.screen_shake_high"), 3)
		screen_shake_options.select(clamp(shake_idx, 0, 3))

func _inject_section_headers() -> void:
	var vbox: VBoxContainer = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox
	_add_section_before(vbox, "SectionVideo", "settings.section_video", "ResolutionLabel")
	_add_section_before(vbox, "SectionLanguage", "settings.section_language", "LanguageLabel")
	_add_section_before(vbox, "SectionGame", "settings.section_game", "AutoEndTurnToggle")
	_add_section_before(vbox, "SectionAudio", "settings.section_audio", "MasterLabel")


# 动态构建辅助功能设置区（动画速度/粒子质量/震屏强度/减少动效）
func _build_accessibility_section() -> void:
	var vbox: VBoxContainer = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox
	if vbox.has_node("SectionAccessibility"):
		return
	# 分区标题
	var section_label := Label.new()
	section_label.name = "SectionAccessibility"
	section_label.layout_mode = 2
	section_label.text = LocalizationManager.text("settings.section_accessibility")
	section_label.add_theme_font_size_override("font_size", 22)
	section_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66, 1.0))
	section_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
	section_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(section_label)
	section_labels["settings.section_accessibility"] = section_label

	# 动画速度
	var anim_label := Label.new()
	anim_label.name = "AnimationSpeedLabel"
	anim_label.layout_mode = 2
	anim_label.text = LocalizationManager.text("settings.animation_speed")
	vbox.add_child(anim_label)
	_apply_setting_label_theme(anim_label)

	var anim_options := OptionButton.new()
	anim_options.name = "AnimationSpeedOptions"
	anim_options.layout_mode = 2
	anim_options.custom_minimum_size = Vector2(0, 40)
	anim_options.add_item(LocalizationManager.text("settings.animation_speed_slow"), 0)
	anim_options.add_item(LocalizationManager.text("settings.animation_speed_normal"), 1)
	anim_options.add_item(LocalizationManager.text("settings.animation_speed_fast"), 2)
	anim_options.add_item(LocalizationManager.text("settings.animation_speed_fastest"), 3)
	vbox.add_child(anim_options)
	UI_THEME_KIT.apply_option_button(anim_options)
	# 选中处理
	anim_options.item_selected.connect(func(index: int) -> void:
		if loading_settings:
			return
		SfxManager.play_ui_click()
		var speeds: Array[float] = [0.5, 1.0, 1.5, 2.0]
		SettingsManager.save_settings({"animation_speed": speeds[index]})
	)
	animation_speed_options = anim_options

	# 粒子质量
	var particle_label := Label.new()
	particle_label.name = "ParticleQualityLabel"
	particle_label.layout_mode = 2
	particle_label.text = LocalizationManager.text("settings.particle_quality")
	vbox.add_child(particle_label)
	_apply_setting_label_theme(particle_label)

	var particle_options := OptionButton.new()
	particle_options.name = "ParticleQualityOptions"
	particle_options.layout_mode = 2
	particle_options.custom_minimum_size = Vector2(0, 40)
	particle_options.add_item(LocalizationManager.text("settings.particle_quality_low"), 0)
	particle_options.add_item(LocalizationManager.text("settings.particle_quality_medium"), 1)
	particle_options.add_item(LocalizationManager.text("settings.particle_quality_high"), 2)
	vbox.add_child(particle_options)
	UI_THEME_KIT.apply_option_button(particle_options)
	particle_options.item_selected.connect(func(index: int) -> void:
		if loading_settings:
			return
		SfxManager.play_ui_click()
		var qualities: Array[String] = ["low", "medium", "high"]
		SettingsManager.save_settings({"particle_quality": qualities[index]})
	)
	particle_quality_options = particle_options

	# 屏幕震动
	var shake_label := Label.new()
	shake_label.name = "ScreenShakeLabel"
	shake_label.layout_mode = 2
	shake_label.text = LocalizationManager.text("settings.screen_shake")
	vbox.add_child(shake_label)
	_apply_setting_label_theme(shake_label)

	var shake_options := OptionButton.new()
	shake_options.name = "ScreenShakeOptions"
	shake_options.layout_mode = 2
	shake_options.custom_minimum_size = Vector2(0, 40)
	shake_options.add_item(LocalizationManager.text("settings.screen_shake_off"), 0)
	shake_options.add_item(LocalizationManager.text("settings.screen_shake_low"), 1)
	shake_options.add_item(LocalizationManager.text("settings.screen_shake_normal"), 2)
	shake_options.add_item(LocalizationManager.text("settings.screen_shake_high"), 3)
	vbox.add_child(shake_options)
	UI_THEME_KIT.apply_option_button(shake_options)
	shake_options.item_selected.connect(func(index: int) -> void:
		if loading_settings:
			return
		SfxManager.play_ui_click()
		var shakes: Array[float] = [0.0, 0.5, 1.0, 1.5]
		SettingsManager.save_settings({"screen_shake": shakes[index]})
	)
	screen_shake_options = shake_options

	# 减少动效（总开关）
	var reduce_toggle := CheckBox.new()
	reduce_toggle.name = "ReduceMotionToggle"
	reduce_toggle.layout_mode = 2
	reduce_toggle.text = LocalizationManager.text("settings.reduce_motion")
	vbox.add_child(reduce_toggle)
	UI_THEME_KIT.apply_toggle(reduce_toggle)
	reduce_toggle.toggled.connect(func(pressed: bool) -> void:
		if loading_settings:
			return
		SfxManager.play_ui_click()
		SettingsManager.save_settings({"reduce_motion": pressed})
		# 同步刷新其他控件的状态显示
		_load_saved_settings()
		# 恢复正确的类别可见性（_load_saved_settings 可能改变自定义缩放控件可见性）
		_select_settings_category(active_category)
	)
	reduce_motion_toggle = reduce_toggle

	# 减少动效说明
	var reduce_desc := Label.new()
	reduce_desc.name = "ReduceMotionDesc"
	reduce_desc.layout_mode = 2
	reduce_desc.text = LocalizationManager.text("settings.reduce_motion_desc")
	reduce_desc.add_theme_font_size_override("font_size", 14)
	reduce_desc.add_theme_color_override("font_color", Color(0.72, 0.74, 0.80, 0.82))
	reduce_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reduce_desc)


# 动态构建新增音量分组滑条（警报/特殊/界面/战斗）
# 每组为 Label + HSlider + Value Label 三件套，范围 0-100，与既有主音量/音乐/音效/语音滑条一致
func _build_audio_group_sliders() -> void:
	var vbox: VBoxContainer = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox
	if vbox.has_node("WarningLabel"):
		return
	var group_defs: Array = [
		{"prefix": "Warning", "key": "settings.audio_group_warning"},
		{"prefix": "Special", "key": "settings.audio_group_special"},
		{"prefix": "UIVolume", "key": "settings.audio_group_ui"},
		{"prefix": "Combat", "key": "settings.audio_group_combat"}
	]
	for group_def in group_defs:
		var prefix: String = String(group_def["prefix"])
		var text_key: String = String(group_def["key"])
		var group_label := Label.new()
		group_label.name = "%sLabel" % prefix
		group_label.layout_mode = 2
		group_label.text = LocalizationManager.text(text_key)
		vbox.add_child(group_label)
		var group_slider := HSlider.new()
		group_slider.name = "%sSlider" % prefix
		group_slider.layout_mode = 2
		group_slider.min_value = 0.0
		group_slider.max_value = 100.0
		vbox.add_child(group_slider)
		var group_value := Label.new()
		group_value.name = "%sValue" % prefix
		group_value.layout_mode = 2
		group_value.text = "80%"
		vbox.add_child(group_value)
		match prefix:
			"Warning":
				warning_label = group_label
				warning_slider = group_slider
				warning_value = group_value
			"Special":
				special_label = group_label
				special_slider = group_slider
				special_value = group_value
			"UIVolume":
				ui_volume_label = group_label
				ui_volume_slider = group_slider
				ui_volume_value = group_value
			"Combat":
				combat_label = group_label
				combat_slider = group_slider
				combat_value = group_value


# 辅助：给设置项标签应用统一的次要标签样式
func _apply_setting_label_theme(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.84))
	label.add_theme_constant_override("outline_size", 1)

func _add_section_before(vbox: VBoxContainer, node_name: String, text_key: String, before_node_name: String) -> void:
	if vbox.has_node(node_name):
		section_labels[text_key] = vbox.get_node(node_name)
		return
	var before_node: Node = vbox.get_node_or_null(before_node_name)
	if before_node == null:
		return
	var label := Label.new()
	label.name = node_name
	label.layout_mode = 2
	label.text = LocalizationManager.text(text_key)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(label)
	vbox.move_child(label, before_node.get_index())
	section_labels[text_key] = label

func _build_category_tabs() -> void:
	var vbox: VBoxContainer = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox
	if category_tabs != null and is_instance_valid(category_tabs):
		return
	category_tabs = HBoxContainer.new()
	category_tabs.name = "CategoryTabs"
	category_tabs.layout_mode = 2
	category_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(category_tabs)
	var body_label: Node = vbox.get_node_or_null("Body")
	if body_label != null:
		vbox.move_child(category_tabs, body_label.get_index() + 1)
	for category in ["video", "language", "game", "audio", "accessibility"]:
		var button := Button.new()
		button.name = "%sTab" % category.capitalize()
		button.layout_mode = 2
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		category_tabs.add_child(button)
		category_buttons[category] = button
		button.pressed.connect(func(target_category: String = category) -> void:
			_select_settings_category(target_category)
		)

func _apply_category_tab_text() -> void:
	if category_buttons.is_empty():
		return
	var labels: Dictionary = {
		"video": LocalizationManager.text("settings.section_video"),
		"language": LocalizationManager.text("settings.section_language"),
		"game": LocalizationManager.text("settings.section_game"),
		"audio": LocalizationManager.text("settings.section_audio"),
		"accessibility": LocalizationManager.text("settings.section_accessibility")
	}
	for category in category_buttons.keys():
		var button: Button = category_buttons[category] as Button
		if button != null:
			button.text = String(labels.get(category, category.capitalize()))

func _select_settings_category(category: String) -> void:
	active_category = category
	for category_key in category_buttons.keys():
		var button: Button = category_buttons[category_key] as Button
		if button != null:
			button.set_pressed_no_signal(category_key == active_category)
			_apply_category_button_style(button, category_key == active_category)
	_set_category_nodes_visible("video", active_category == "video")
	_set_category_nodes_visible("language", active_category == "language")
	_set_category_nodes_visible("game", active_category == "game")
	_set_category_nodes_visible("audio", active_category == "audio")
	_set_category_nodes_visible("accessibility", active_category == "accessibility")
	# 修正自定义 UI 缩放控件可见性：仅 video 类别且 preset 为 custom 时显示
	# _set_category_nodes_visible 会覆盖 _update_ui_scale_custom_visibility 的设置
	if active_category == "video":
		var preset: String = String(SettingsManager.get_settings().get("ui_scale_preset", "auto"))
		_update_ui_scale_custom_visibility(preset)

func _set_category_nodes_visible(category: String, visible: bool) -> void:
	for node_path in _category_node_paths(category):
		var node: CanvasItem = get_node_or_null(node_path) as CanvasItem
		if node != null:
			node.visible = visible

func _category_node_paths(category: String) -> Array[String]:
	match category:
		"video":
			return [
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SectionVideo",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ResolutionLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ResolutionOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/DisplayModeLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/DisplayModeOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/FullscreenToggle",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BorderlessToggle",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VSyncToggle"
			]
		"language":
			return [
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SectionLanguage",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/LanguageLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/LanguageOptions"
			]
		"game":
			return [
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SectionGame",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AutoEndTurnToggle",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BattleSpeedLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BattleSpeedOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AbandonRunLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AbandonRunButton"
			]
		"audio":
			return [
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SectionAudio",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/WarningLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/WarningSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/WarningValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SpecialLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SpecialSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SpecialValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIVolumeLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIVolumeSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIVolumeValue",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/CombatLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/CombatSlider",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/CombatValue"
			]
		"accessibility":
			return [
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SectionAccessibility",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AnimationSpeedLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/AnimationSpeedOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ParticleQualityLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ParticleQualityOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ScreenShakeLabel",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ScreenShakeOptions",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ReduceMotionToggle",
				"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ReduceMotionDesc"
			]
	return []

func _apply_section_text() -> void:
	for key in section_labels.keys():
		var label: Label = section_labels[key] as Label
		if label != null:
			label.text = LocalizationManager.text(String(key))

func _on_resolution_selected(index: int) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	var resolution_text: String = RESOLUTIONS[index]
	SettingsManager.save_settings({"resolution": resolution_text})
	SettingsManager.apply_saved_settings()

func _on_display_mode_selected(index: int) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	# 用 set_pressed_no_signal 避免触发 toggled 信号递归（双重保存/音效）
	fullscreen_toggle.set_pressed_no_signal(index == 2)
	SettingsManager.save_settings({"display_mode": index, "fullscreen": index == 2})
	SettingsManager.apply_saved_settings()

func _on_language_selected(index: int) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	if index == 0:
		LocalizationManager.set_language(LocalizationManager.LANG_ZH)
	else:
		LocalizationManager.set_language(LocalizationManager.LANG_EN)

func _on_ui_scale_selected(index: int) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	var safe_index: int = clamp(index, 0, UI_SCALE_PRESETS.size() - 1)
	var preset: String = UI_SCALE_PRESETS[safe_index]
	SettingsManager.save_settings({"ui_scale_preset": preset})
	_update_ui_scale_custom_visibility(preset)
	SettingsManager.apply_saved_settings()

func _on_ui_scale_custom_changed(value: float) -> void:
	if loading_settings:
		return
	ui_scale_custom_value.text = "%d%%" % int(round(value * 100.0))
	SettingsManager.save_settings({"ui_scale_custom": value})
	SettingsManager.apply_saved_settings()

func _update_ui_scale_custom_visibility(preset: String) -> void:
	var show_custom: bool = preset == "custom"
	if ui_scale_custom_slider != null:
		ui_scale_custom_slider.visible = show_custom
	if ui_scale_custom_value != null:
		ui_scale_custom_value.visible = show_custom
	var custom_label: CanvasItem = get_node_or_null("Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomLabel") as CanvasItem
	if custom_label != null:
		custom_label.visible = show_custom

func _on_battle_speed_selected(index: int) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	var safe_index: int = clamp(index, 0, BATTLE_SPEED_OPTIONS.size() - 1)
	SettingsManager.save_settings({"battle_speed": BATTLE_SPEED_OPTIONS[safe_index]})

func _on_fullscreen_toggled(enabled: bool) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	var display_mode: int = 2 if enabled else min(display_mode_options.selected, 1)
	display_mode_options.select(display_mode)
	SettingsManager.save_settings({"fullscreen": enabled, "display_mode": display_mode})
	SettingsManager.apply_saved_settings()

func _on_borderless_toggled(enabled: bool) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	SettingsManager.save_settings({"borderless": enabled})
	SettingsManager.apply_saved_settings()

func _on_vsync_toggled(enabled: bool) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	SettingsManager.save_settings({"vsync": enabled})
	SettingsManager.apply_saved_settings()

func _on_auto_end_turn_toggled(enabled: bool) -> void:
	if loading_settings:
		return
	SfxManager.play_ui_click()
	SettingsManager.save_settings({"auto_end_turn": enabled})

func _open_abandon_dialog() -> void:
	SfxManager.play_ui_click()
	if _is_battle_finished():
		return
	if abandon_dialog == null:
		abandon_dialog = ConfirmationDialog.new()
		abandon_dialog.name = "AbandonRunDialog"
		abandon_dialog.exclusive = true
		add_child(abandon_dialog)
		abandon_dialog.confirmed.connect(_confirm_abandon_run)
	abandon_dialog.title = LocalizationManager.text("battle.abandon_title")
	abandon_dialog.dialog_text = LocalizationManager.text("battle.abandon_body")
	abandon_dialog.ok_button_text = LocalizationManager.text("battle.abandon_confirm")
	abandon_dialog.cancel_button_text = LocalizationManager.text("battle.abandon_cancel")
	abandon_dialog.popup_centered()

func _confirm_abandon_run() -> void:
	if _is_battle_finished():
		return
	abandon_requested.emit()

func _is_battle_finished() -> bool:
	if battle_finished_provider.is_valid():
		return bool(battle_finished_provider.call())
	return false

func _save_audio_settings() -> void:
	SettingsManager.save_settings({
		"master_volume": master_slider.value,
		"music_volume": music_slider.value,
		"sfx_volume": sfx_slider.value,
		"voice_volume": voice_slider.value,
		"warning_volume": warning_slider.value,
		"special_volume": special_slider.value,
		"ui_volume": ui_volume_slider.value,
		"combat_volume": combat_slider.value
	})
	MusicManager.refresh_menu_volume()
	SfxManager.refresh_volume()

func _select_resolution(resolution_text: String) -> void:
	var index: int = RESOLUTIONS.find(resolution_text)
	resolution_options.select(index if index != -1 else 0)

func _select_ui_scale_preset(preset: String) -> void:
	var index: int = UI_SCALE_PRESETS.find(preset)
	ui_scale_options.select(index if index != -1 else 0)

func _select_battle_speed(speed: float) -> void:
	var index: int = BATTLE_SPEED_OPTIONS.find(speed)
	if index == -1:
		# 找最接近的档位
		var best_index: int = 1
		var best_diff: float = abs(BATTLE_SPEED_OPTIONS[1] - speed)
		for i in range(BATTLE_SPEED_OPTIONS.size()):
			var diff: float = abs(BATTLE_SPEED_OPTIONS[i] - speed)
			if diff < best_diff:
				best_diff = diff
				best_index = i
		index = best_index
	battle_speed_options.select(index)

func _ui_scale_option_labels() -> Array[String]:
	if LocalizationManager.current_language == LocalizationManager.LANG_ZH:
		return [
			"自动推荐（当前系统）",
			"Windows 推荐（100%）",
			"MacBook 推荐（175%）",
			"自定义"
		]
	return [
		"Auto Recommended",
		"Windows Recommended (100%)",
		"MacBook Recommended (175%)",
		"Custom"
	]

func _battle_speed_option_labels() -> Array[String]:
	var labels: Array[String] = []
	for speed in BATTLE_SPEED_OPTIONS:
		var label_key: String = "settings.battle_speed_x%d" % int(round(speed * 10.0))
		labels.append(LocalizationManager.text(label_key))
	return labels

func _display_mode_labels() -> Array[String]:
	var labels: Array[String] = []
	labels.append(LocalizationManager.text("settings.windowed"))
	labels.append(LocalizationManager.text("settings.maximized"))
	labels.append(LocalizationManager.text("settings.fullscreen_mode"))
	return labels

func _language_labels() -> Array[String]:
	if LocalizationManager.current_language == LocalizationManager.LANG_ZH:
		return ["简体中文", "英语"]
	return ["Simplified Chinese", "English"]

func _back_button_text() -> String:
	if overlay_mode:
		return LocalizationManager.text("system.return_game")
	if SceneRouter.return_scene_after_settings in [
		SceneRouter.MAP_SCENE,
		SceneRouter.BATTLE_SCENE,
		SceneRouter.EVENT_SCENE,
		SceneRouter.REWARD_SCENE,
		SceneRouter.SHOP_SCENE,
		SceneRouter.REST_SCENE
	]:
		return LocalizationManager.text("system.return_game")
	return LocalizationManager.text("settings.back")

func _play_intro_animation() -> void:
	UI_MOTION.reveal(left_panel, 0.04, Vector2(-34, 0), 0.36, Vector2(0.985, 0.985))
	UI_MOTION.reveal(back_button, 0.16, Vector2(0, 20), 0.26)
	UI_MOTION.reveal(return_main_button, 0.22, Vector2(0, 20), 0.26)

func _press_and_call(button: Control, action: Callable) -> void:
	UI_MOTION.pulse_then(button, action, 0.96, 1.02, 0.06)

func _handle_back() -> void:
	if overlay_mode:
		close_requested.emit()
		queue_free()
		return
	SceneRouter.return_from_settings()

func _return_to_main() -> void:
	RunManager.save_run_snapshot()
	SceneRouter.go_main_menu()

func _apply_ui_theme() -> void:
	_configure_settings_layout()
	UI_THEME_KIT.apply_glass_panel(left_panel)
	UI_THEME_KIT.apply_heading($Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Title as Label, 42, Color(1.0, 0.96, 0.88, 1.0), Color(0.04, 0.05, 0.07, 0.74))
	UI_THEME_KIT.apply_body($Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Body as Label, 18, Color(0.92, 0.94, 0.98, 0.92))
	for key in section_labels.keys():
		var section_label: Label = section_labels[key] as Label
		if section_label != null:
			UI_THEME_KIT.apply_body(section_label, 22, Color(1.0, 0.92, 0.66, 1.0))
			section_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
			section_label.add_theme_constant_override("outline_size", 2)
	for label_path in [
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/ResolutionLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/DisplayModeLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/LanguageLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIScaleCustomLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/BattleSpeedLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MasterLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/MusicLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SfxLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/VoiceLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/WarningLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/SpecialLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/UIVolumeLabel",
		"Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/CombatLabel"
	]:
		var label: Label = get_node(label_path) as Label
		if label != null:
			UI_THEME_KIT.apply_body(label, 22, Color(0.98, 0.98, 0.98, 0.98))
	for option in [resolution_options, display_mode_options, language_options, ui_scale_options, battle_speed_options]:
		UI_THEME_KIT.apply_option_button(option)
		UI_MOTION.wire_button_feedback(option, 1.01, 0.99, Color(0.76, 0.92, 1.0, 0.56), 4.0)
	for category_key in category_buttons.keys():
		var category_button: Button = category_buttons[category_key] as Button
		if category_button != null:
			UI_MOTION.wire_button_feedback(category_button, 1.01, 0.99, Color(1.0, 0.88, 0.56, 0.44), 4.0)
			_apply_category_button_style(category_button, category_key == active_category)
	for toggle in [fullscreen_toggle, borderless_toggle, vsync_toggle, auto_end_turn_toggle]:
		UI_THEME_KIT.apply_toggle(toggle)
	for slider in [master_slider, music_slider, sfx_slider, voice_slider, ui_scale_custom_slider, warning_slider, special_slider, ui_volume_slider, combat_slider]:
		UI_THEME_KIT.apply_slider(slider)
	for value_label in [master_value, music_value, sfx_value, voice_value, ui_scale_custom_value, warning_value, special_value, ui_volume_value, combat_value]:
		UI_THEME_KIT.apply_numeric(value_label, 18, Color(1.0, 0.96, 0.88, 1.0))
	UI_THEME_KIT.apply_stone_button(back_button, "paper", 24)
	UI_THEME_KIT.apply_stone_button(return_main_button, "paper", 22)
	UI_MOTION.wire_button_feedback(back_button, 1.02, 0.98, Color(1.0, 0.88, 0.66, 0.68), 5.0)
	UI_MOTION.wire_button_feedback(return_main_button, 1.02, 0.98, Color(1.0, 0.88, 0.66, 0.68), 5.0)

func _configure_settings_layout() -> void:
	left_panel.custom_minimum_size = Vector2(560, 0) if overlay_mode else Vector2(760, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if overlay_mode else Control.SIZE_SHRINK_CENTER
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_margin: MarginContainer = $Margin/LeftPanel/LeftMargin as MarginContainer
	if left_margin != null:
		left_margin.add_theme_constant_override("margin_left", 26)
		left_margin.add_theme_constant_override("margin_top", 24)
		left_margin.add_theme_constant_override("margin_right", 26)
		left_margin.add_theme_constant_override("margin_bottom", 24)
	var title: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Title as Label
	var body: Label = $Margin/LeftPanel/LeftMargin/LeftBox/Scroll/VBox/Body as Label
	if title != null:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body != null:
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for option in [resolution_options, display_mode_options, language_options, ui_scale_options, battle_speed_options]:
		option.custom_minimum_size = Vector2(0, 50)
	for slider in [master_slider, music_slider, sfx_slider, voice_slider, ui_scale_custom_slider, warning_slider, special_slider, ui_volume_slider, combat_slider]:
		slider.custom_minimum_size = Vector2(0, 48)
	for button in [back_button, return_main_button]:
		button.custom_minimum_size = Vector2(0, 58)

func _apply_category_button_style(button: Button, selected: bool) -> void:
	UI_THEME_KIT.apply_stone_button(button, "danger" if selected else "ghost", 20)
	button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72, 1.0) if selected else Color(0.92, 0.96, 1.0, 0.92))

func _configure_overlay_visuals() -> void:
	if not is_node_ready():
		return
	var background_image: CanvasItem = get_node_or_null("BackgroundImage") as CanvasItem
	var background_shade: ColorRect = get_node_or_null("BackgroundShade") as ColorRect
	var left_shade: ColorRect = get_node_or_null("LeftShade") as ColorRect
	if overlay_mode:
		if background_image != null:
			background_image.visible = false
		if background_shade != null:
			background_shade.color = Color(0.02, 0.03, 0.05, 0.74)
		if left_shade != null:
			left_shade.color = Color(0.02, 0.03, 0.05, 0.84)
	else:
		if background_image != null:
			background_image.visible = true
		if background_shade != null:
			background_shade.color = Color(0.04, 0.05, 0.07, 0.22)
		if left_shade != null:
			left_shade.color = Color(0.03, 0.04, 0.06, 0.72)
