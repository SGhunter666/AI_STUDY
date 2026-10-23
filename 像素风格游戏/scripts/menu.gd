extends Node2D
## 主菜单：像素机甲风格的主页。
##
## 背景直接复用对战场景的夜城图层与机甲骨架（静态对峙待机），
## 菜单项画在 640x360 的 UI 层上，因此中文清晰、像素背景依旧颗粒分明。

const MECHA_SCENE := preload("res://scenes/mecha.tscn")
const GAME_SCENE := "res://scenes/main.tscn"

const OPTIONS := ["开始游戏", "设置", "退出游戏"]
const OPTION_Y := [140.0, 182.0, 224.0]
const SETTING_Y := [132.0, 174.0, 216.0]

enum Mode { MAIN, SETTINGS }

var _mode := Mode.MAIN
var _index := 0
var _row := 0
var _t := 0.0

@onready var cursor: Label = $UI/Cursor
@onready var hint: Label = $UI/Hint
@onready var title: Label = $UI/Title
@onready var subtitle: Label = $UI/Subtitle
@onready var option_labels: Array = [$UI/Opt0, $UI/Opt1, $UI/Opt2]
@onready var settings: Control = $UI/SettingsPanel
@onready var settings_cursor: Label = $UI/SettingsPanel/Cursor
@onready var setting_values: Array = [$UI/SettingsPanel/Val0, $UI/SettingsPanel/Val1, $UI/SettingsPanel/Val2]

var _main_items: Array = []
var _title_y := 0.0


func _ready() -> void:
	UiFont.apply(self)
	InputSetup.ensure()
	Engine.time_scale = 1.0
	_title_y = title.position.y
	# 设置面板的背景是半透明的，主菜单的文字必须整体藏起来，否则会透出来叠在一起
	_main_items = [title, subtitle, option_labels[0], option_labels[1], option_labels[2], cursor, hint]
	settings.visible = false
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	# 标题缓慢浮动 + 光标小幅呼吸，让静态主页有生命感
	title.position.y = _title_y + sin(_t * 1.6) * 2.0
	cursor.position.x = _cursor_base_x() + sin(_t * 6.0) * 1.5


func _input(event: InputEvent) -> void:
	if _mode == Mode.MAIN:
		if event.is_action_pressed("menu_up"):
			_index = (_index - 1 + OPTIONS.size()) % OPTIONS.size()
			_refresh()
		elif event.is_action_pressed("menu_down"):
			_index = (_index + 1) % OPTIONS.size()
			_refresh()
		elif event.is_action_pressed("menu_confirm"):
			_activate()
		elif event.is_action_pressed("menu_back"):
			get_tree().quit()
	else:
		if event.is_action_pressed("menu_up"):
			_row = (_row - 1 + SETTING_Y.size()) % SETTING_Y.size()
			_refresh()
		elif event.is_action_pressed("menu_down"):
			_row = (_row + 1) % SETTING_Y.size()
			_refresh()
		elif event.is_action_pressed("menu_left"):
			_adjust(-1)
		elif event.is_action_pressed("menu_right"):
			_adjust(1)
		elif event.is_action_pressed("menu_confirm") or event.is_action_pressed("menu_back"):
			_close_settings()


# ------------------------------------------------------------------ 主菜单
func _activate() -> void:
	match _index:
		0:
			get_tree().change_scene_to_file(GAME_SCENE)
		1:
			_mode = Mode.SETTINGS
			_row = 0
			settings.visible = true
			_refresh()
		2:
			get_tree().quit()


func _close_settings() -> void:
	_mode = Mode.MAIN
	settings.visible = false
	_refresh()


# ------------------------------------------------------------------ 设置项
func _adjust(delta: int) -> void:
	match _row:
		0:
			GameConfig.p2_ai = not GameConfig.p2_ai
		1:
			GameConfig.ai_difficulty = clampi(GameConfig.ai_difficulty + delta, 0, 2)
		2:
			GameConfig.rounds_to_win = clampi(GameConfig.rounds_to_win + delta, 1, 3)
	_refresh()


func _refresh() -> void:
	var in_main := _mode == Mode.MAIN
	for item: Node in _main_items:
		item.visible = in_main
	for i in OPTIONS.size():
		var l: Label = option_labels[i]
		l.modulate = Color(1, 1, 1, 1) if (in_main and i == _index) else Color(0.5, 0.56, 0.68, 1)
	if in_main:
		cursor.position.y = OPTION_Y[_index] - 2.0
		hint.text = "↑ / ↓ 选择      Enter / J 确认      ESC 退出游戏"

	setting_values[0].text = "电脑" if GameConfig.p2_ai else "双人"
	setting_values[1].text = GameConfig.difficulty_name()
	setting_values[2].text = "%d 胜" % GameConfig.rounds_to_win
	settings_cursor.visible = not in_main
	for i in SETTING_Y.size():
		var dim := Color(0.5, 0.56, 0.68, 1) if (in_main or i != _row) else Color(1, 1, 1, 1)
		setting_values[i].modulate = dim
	if not in_main:
		settings_cursor.position.y = SETTING_Y[_row] - 2.0


## 光标位置跟着当前选项文字的实际宽度走，不用手工对齐
func _cursor_base_x() -> float:
	if _mode != Mode.MAIN:
		return 0.0
	var w: float = option_labels[_index].get_minimum_size().x
	return 320.0 - w * 0.5 - 26.0
