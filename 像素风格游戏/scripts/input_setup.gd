class_name InputSetup
extends RefCounted
## 运行时注册输入映射。
## 放在代码里而不是 project.godot 中，是为了让按键方案在版本控制里可读、可改。

const BINDINGS := {
	# 玩家 1（蓝方）：J 斩击 / U 重击 / K 防御 / L 炮击 / ; 爆气 / Shift 翻滚闪避
	"p1_left": [KEY_A], "p1_right": [KEY_D], "p1_jump": [KEY_W],
	"p1_attack": [KEY_J], "p1_heavy": [KEY_U], "p1_block": [KEY_K],
	"p1_shoot": [KEY_L], "p1_burst": [KEY_SEMICOLON],
	"p1_dodge": [KEY_SHIFT, KEY_I],
	# 玩家 2（红方）：翻滚闪避不能用 Shift——Shift 是共享按键，
	# 绑给两个人会导致「一按两边一起滚」，所以红方固定用自己的键。
	"p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT], "p2_jump": [KEY_UP],
	"p2_attack": [KEY_PERIOD, KEY_KP_1], "p2_heavy": [KEY_O, KEY_KP_4],
	"p2_block": [KEY_SLASH, KEY_KP_2],
	"p2_shoot": [KEY_COMMA, KEY_KP_3], "p2_burst": [KEY_M, KEY_KP_0],
	"p2_dodge": [KEY_N, KEY_KP_5],
	# 全局
	"restart": [KEY_R], "toggle_ai": [KEY_T], "back_to_menu": [KEY_ESCAPE],
	# 主菜单
	"menu_up": [KEY_UP, KEY_W], "menu_down": [KEY_DOWN, KEY_S],
	"menu_left": [KEY_LEFT, KEY_A], "menu_right": [KEY_RIGHT, KEY_D],
	"menu_confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J],
	"menu_back": [KEY_ESCAPE, KEY_K],
}


static func ensure() -> void:
	for action_name: String in BINDINGS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		for keycode: int in BINDINGS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)
