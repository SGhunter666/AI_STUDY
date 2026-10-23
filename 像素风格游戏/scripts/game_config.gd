class_name GameConfig
extends RefCounted
## 全局设置：由主菜单写入，游戏场景读取。
##
## 用静态变量而不是 autoload，是为了让「谁改了设置」这件事
## 在代码里一目了然，也免去在 project.godot 里加 autoload 条目。

static var p2_ai := true           ## 红方是对手电脑还是第二位玩家
static var ai_difficulty := 1      ## 0 简单 / 1 普通 / 2 困难
static var rounds_to_win := 2      ## 先赢几回合算拿下比赛（1~3）

const DIFFICULTY_NAMES := ["简单", "普通", "困难"]
## 难度对 AI 的影响系数：出刀概率、读招防御概率、思考间隔倍率
const DIFFICULTY_TUNING := [
	{"attack": 0.52, "block": 0.30, "think": 1.45},
	{"attack": 0.78, "block": 0.60, "think": 1.00},
	{"attack": 0.93, "block": 0.86, "think": 0.72},
]


static func difficulty_name() -> String:
	return DIFFICULTY_NAMES[clampi(ai_difficulty, 0, 2)]


static func tuning() -> Dictionary:
	return DIFFICULTY_TUNING[clampi(ai_difficulty, 0, 2)]
