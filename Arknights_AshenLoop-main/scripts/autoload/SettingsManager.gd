extends Node

const MACBOOK_RECOMMENDED_UI_SCALE := 1.75
const WINDOWS_RECOMMENDED_UI_SCALE := 1.0
const LOGICAL_UI_SCALE := 1.0
const MIN_CUSTOM_UI_SCALE := 0.75
const MAX_CUSTOM_UI_SCALE := 2.0
const DEFAULT_BATTLE_SPEED := 1.0
const MAX_ASCENSION_LEVEL := 20
const DEFAULT_SETTINGS := {
	"resolution": "1920x1080",
	"display_mode": 0,
	"ui_scale": LOGICAL_UI_SCALE,
	"ui_scale_preset": "auto",
	"ui_scale_custom": LOGICAL_UI_SCALE,
	"battle_speed": DEFAULT_BATTLE_SPEED,
	"ascension_level": 0,
	"fullscreen": false,
	"borderless": false,
	"vsync": true,
	"auto_end_turn": false,
	"master_volume": 80.0,
	"music_volume": 70.0,
	"sfx_volume": 75.0,
	"voice_volume": 85.0,
	"warning_volume": 80.0,
	"special_volume": 80.0,
	"ui_volume": 80.0,
	"combat_volume": 80.0,
	"tutorial_completed": false,
	"animation_speed": 1.0,
	"particle_quality": "high",
	"screen_shake": 1.0,
	"reduce_motion": false
}

func _ready() -> void:
	apply_saved_settings()
	_apply_global_font_theme()


func _apply_global_font_theme() -> void:
	# 设置项目级默认字体主题（正文雅黑作为所有控件的默认字体）
	# 标题/数字字体由 UIThemeKit 在各场景按需应用
	var FontThemeClass = load("res://scripts/ui/font_theme.gd")
	var project_theme: Theme = FontThemeClass.create_project_theme()
	get_tree().root.set_theme(project_theme)

func get_settings() -> Dictionary:
	var profile: Dictionary = SaveManager.load_profile()
	for key in DEFAULT_SETTINGS.keys():
		if not profile.has(key):
			profile[key] = DEFAULT_SETTINGS[key]
	# 兼容旧存档：ui_scale 字段保留但仅在 preset 为 custom 时使用 ui_scale_custom
	return profile

func save_settings(overrides: Dictionary) -> void:
	var profile: Dictionary = get_settings()
	for key in overrides.keys():
		var key_name: String = String(key)
		if key_name == "ui_scale_custom":
			var clamped_value: float = clamp(float(overrides[key]), MIN_CUSTOM_UI_SCALE, MAX_CUSTOM_UI_SCALE)
			profile[key_name] = clamped_value
		else:
			profile[key_name] = overrides[key]
	SaveManager.save_profile(profile)

func apply_saved_settings() -> void:
	apply_settings(get_settings())

func apply_settings(settings: Dictionary) -> void:
	var display_mode: int = int(settings.get("display_mode", 0))
	if bool(settings.get("fullscreen", false)):
		display_mode = 2
	_apply_display_mode(display_mode)
	_apply_resolution(String(settings.get("resolution", "1920x1080")))
	_apply_borderless(bool(settings.get("borderless", false)))
	_apply_vsync(bool(settings.get("vsync", true)))
	_apply_ui_scale(get_ui_display_scale())

func get_ui_layout_scale() -> float:
	var window_size: Vector2 = Vector2(get_window().size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return LOGICAL_UI_SCALE
	var width_scale: float = window_size.x / 1920.0
	var height_scale: float = window_size.y / 1080.0
	var resolution_scale: float = sqrt(width_scale * height_scale)
	return clamp(resolution_scale, 0.86, 1.24)

func get_ui_display_scale() -> float:
	var profile: Dictionary = SaveManager.load_profile()
	var preset: String = String(profile.get("ui_scale_preset", DEFAULT_SETTINGS["ui_scale_preset"]))
	match preset:
		"windows":
			return WINDOWS_RECOMMENDED_UI_SCALE
		"macbook":
			return MACBOOK_RECOMMENDED_UI_SCALE
		"custom":
			var custom_value: float = float(profile.get("ui_scale_custom", LOGICAL_UI_SCALE))
			return clamp(custom_value, MIN_CUSTOM_UI_SCALE, MAX_CUSTOM_UI_SCALE)
		_:
			return WINDOWS_RECOMMENDED_UI_SCALE if OS.get_name() == "Windows" else MACBOOK_RECOMMENDED_UI_SCALE

func get_battle_speed() -> float:
	var profile: Dictionary = SaveManager.load_profile()
	var speed: float = float(profile.get("battle_speed", DEFAULT_BATTLE_SPEED))
	# 限定在合理范围：0.5x ~ 4x
	return clamp(speed, 0.5, 4.0)

# 动画速度倍率（0.5x 慢 ~ 1.0x 正常 ~ 2.0x 快）
func get_animation_speed() -> float:
	var profile: Dictionary = SaveManager.load_profile()
	# 减少动效模式强制动画速度为最快
	if bool(profile.get("reduce_motion", false)):
		return 2.0
	var speed: float = float(profile.get("animation_speed", 1.0))
	return clamp(speed, 0.5, 2.0)

# 粒子质量："low" / "medium" / "high"
func get_particle_quality() -> String:
	var profile: Dictionary = SaveManager.load_profile()
	# 减少动效模式强制粒子为低
	if bool(profile.get("reduce_motion", false)):
		return "low"
	return String(profile.get("particle_quality", "high"))

# 粒子数量缩放倍率（供 GPUParticles2D.amount 使用）
func get_particle_amount_scale() -> float:
	match get_particle_quality():
		"low":
			return 0.0
		"medium":
			return 0.4
	return 1.0

# 屏幕震动强度倍率（0.0 关闭 ~ 1.0 正常 ~ 1.5 增强）
func get_screen_shake() -> float:
	var profile: Dictionary = SaveManager.load_profile()
	# 减少动效模式强制震屏关闭
	if bool(profile.get("reduce_motion", false)):
		return 0.0
	var shake: float = float(profile.get("screen_shake", 1.0))
	return clamp(shake, 0.0, 1.5)

# 减少动效模式（综合开关）
func is_reduce_motion() -> bool:
	var profile: Dictionary = SaveManager.load_profile()
	return bool(profile.get("reduce_motion", false))

func get_ascension_level() -> int:
	var profile: Dictionary = SaveManager.load_profile()
	var level: int = int(profile.get("ascension_level", 0))
	return clamp(level, 0, MAX_ASCENSION_LEVEL)

func set_ascension_level(level: int) -> void:
	var clamped: int = clamp(level, 0, MAX_ASCENSION_LEVEL)
	save_settings({"ascension_level": clamped})

# 已解锁的最高难度等级（全局共享）。初始为 0，通关难度 N 后解锁 N+1。
func get_ascension_unlocked() -> int:
	var profile: Dictionary = SaveManager.load_profile()
	var unlocked: int = int(profile.get("ascension_unlocked", 0))
	return clamp(unlocked, 0, MAX_ASCENSION_LEVEL)

func unlock_next_ascension() -> void:
	var current_unlocked: int = get_ascension_unlocked()
	var next_unlocked: int = min(current_unlocked + 1, MAX_ASCENSION_LEVEL)
	if next_unlocked <= current_unlocked:
		return
	SaveManager.update_profile({"ascension_unlocked": next_unlocked})

# 新手引导是否已完成（首次进入战斗时弹出教程 overlay，玩家点击"我知道了"后持久化）
func is_tutorial_completed() -> bool:
	var profile: Dictionary = SaveManager.load_profile()
	return bool(profile.get("tutorial_completed", false))

func mark_tutorial_completed() -> void:
	SaveManager.update_profile({"tutorial_completed": true})

func _apply_display_mode(mode_index: int) -> void:
	match mode_index:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_resolution(resolution_text: String) -> void:
	var parts: PackedStringArray = resolution_text.split("x")
	if parts.size() != 2:
		return
	var width: int = int(parts[0])
	var height: int = int(parts[1])
	if width <= 0 or height <= 0:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		get_window().size = Vector2i(width, height)

func _apply_borderless(enabled: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, enabled)

func _apply_vsync(enabled: bool) -> void:
	var mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_ui_scale(scale_value: float) -> void:
	var root: Window = get_tree().root
	root.content_scale_factor = max(0.75, scale_value)
