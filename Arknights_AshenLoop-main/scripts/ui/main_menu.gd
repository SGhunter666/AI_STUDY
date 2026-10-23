extends Control

const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")

@onready var save_slot_button: Button = $SaveSlot
@onready var menu_panel: PanelContainer = $CenterWrap/CenterBox/MenuPanel
@onready var single_player_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/SinglePlayer
@onready var multiplayer_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/Multiplayer
@onready var timeline_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/Timeline
@onready var settings_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/Settings
@onready var codex_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/Codex
@onready var quit_button: Button = $CenterWrap/CenterBox/MenuPanel/MenuMargin/Menu/Quit
@onready var center_wrap: CenterContainer = $CenterWrap
@onready var center_box: VBoxContainer = $CenterWrap/CenterBox
@onready var brand_top: Label = $CenterWrap/CenterBox/BrandTop
@onready var brand_bottom: Label = $CenterWrap/CenterBox/BrandBottom

func _ready() -> void:
	MusicManager.play_menu_bgm()
	_apply_ui_theme()
	_apply_text()
	_refresh_save_slot()
	LocalizationManager.language_changed.connect(_apply_text)
	RunManager.run_updated.connect(_refresh_save_slot)
	save_slot_button.pressed.connect(func() -> void:
		_press_and_call(save_slot_button, Callable(SceneRouter, "go_single_player"))
	)
	single_player_button.pressed.connect(func() -> void:
		_press_and_call(single_player_button, Callable(SceneRouter, "go_single_player"))
	)
	settings_button.pressed.connect(func() -> void:
		_press_and_call(settings_button, Callable(SceneRouter, "go_settings"))
	)
	codex_button.pressed.connect(func() -> void:
		_press_and_call(codex_button, Callable(SceneRouter, "go_encyclopedia"))
	)
	quit_button.pressed.connect(func() -> void:
		_press_and_call(quit_button, Callable(SceneRouter, "go_quit_page"))
	)
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	# 断开 autoload 持久信号
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)
	if RunManager != null and RunManager.run_updated.is_connected(_refresh_save_slot):
		RunManager.run_updated.disconnect(_refresh_save_slot)

func _apply_text(_language_code: String = "") -> void:
	brand_top.text = LocalizationManager.text("main.brand_top")
	brand_bottom.text = LocalizationManager.text("main.brand_bottom")
	single_player_button.text = LocalizationManager.text("main.single_player")
	multiplayer_button.text = LocalizationManager.text("main.multiplayer")
	timeline_button.text = LocalizationManager.text("main.timeline")
	settings_button.text = LocalizationManager.text("main.settings")
	codex_button.text = LocalizationManager.text("main.codex")
	quit_button.text = LocalizationManager.text("main.quit")
	_refresh_save_slot()

func _refresh_save_slot(_unused: Variant = null) -> void:
	if not RunManager.has_saved_run():
		save_slot_button.visible = false
		return
	var save_data: Dictionary = RunManager.saved_run_summary()
	var character_id: String = String(save_data.get("character_id", "amiya"))
	var character_name: String = LocalizationManager.character_name(character_id, character_id.capitalize())
	save_slot_button.visible = true
	save_slot_button.text = LocalizationManager.text("main.save_slot", [
		character_name,
		int(save_data.get("current_floor", 1)),
		int(save_data.get("hp", 0)),
		int(save_data.get("max_hp", 0))
	])

func _play_intro_animation() -> void:
	UI_MOTION.reveal(brand_top, 0.00, Vector2(0, 18), 0.28, Vector2(0.985, 0.985))
	UI_MOTION.reveal(brand_bottom, 0.04, Vector2(0, 24), 0.32, Vector2(0.985, 0.985))
	UI_MOTION.reveal(menu_panel, 0.08, Vector2(0, 30), 0.34, Vector2(0.985, 0.985))
	if save_slot_button.visible:
		UI_MOTION.reveal(save_slot_button, 0.00, Vector2(-20, 0), 0.28)
	UI_MOTION.reveal($VersionLabel, 0.06, Vector2(24, 0), 0.26)
	var menu_buttons: Array[Button] = [
		single_player_button, multiplayer_button, timeline_button, settings_button, codex_button, quit_button
	]
	for i in range(menu_buttons.size()):
		UI_MOTION.reveal(menu_buttons[i], 0.10 + float(i) * 0.05, Vector2(0, 14), 0.28)

func _press_and_call(button: Control, action: Callable) -> void:
	UI_MOTION.pulse_then(button, action, 0.96, 1.02, 0.06)

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_stone_button(save_slot_button, "ghost", 20)
	UI_THEME_KIT.apply_heading(brand_top, 40, Color(0.98, 0.88, 0.33, 1.0), Color(0.12, 0.08, 0.02, 0.84))
	UI_THEME_KIT.apply_heading(brand_bottom, 74, Color(0.98, 0.92, 0.46, 1.0), Color(0.10, 0.06, 0.02, 0.90))
	UI_THEME_KIT.apply_glass_panel(menu_panel)
	for button in [single_player_button, multiplayer_button, timeline_button, settings_button, codex_button, quit_button]:
		UI_THEME_KIT.apply_menu_text_button(button)
		UI_MOTION.wire_button_feedback(button, 1.02, 0.98, Color(1.0, 0.88, 0.62, 0.78), 6.0)
	UI_MOTION.wire_button_feedback(save_slot_button, 1.02, 0.98, Color(1.0, 0.90, 0.68, 0.68), 4.0)
	UI_MOTION.breathe(brand_bottom, 0.92, 1.0, 1.8)
	UI_MOTION.breathe($VersionLabel, 0.84, 0.94, 2.2)
