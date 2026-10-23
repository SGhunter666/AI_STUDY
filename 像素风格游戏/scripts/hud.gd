class_name GameHud
extends CanvasLayer
## HUD：血量条（含延迟回落的残影）、能量条、回合胜点、连段提示与说明文字。
##
## HUD 位于 640x360 的设计分辨率上，中文用矢量字体渲染依旧清晰；
## 战场本身跑在 320x180 的 SubViewport 内，保留像素颗粒感。

const TEAM_COLOR := [Color("#63e0ff"), Color("#ff7a54")]
const GHOST_COLOR := Color("#f0c048")
const METER_COLOR := [Color("#2f9ec9"), Color("#c25438")]
const PIP_EMPTY := Color("#2b2f3f")

const BAR_W := 228.0           # 血条填充宽度
const METER_W := 228.0         # 能量条填充宽度
const BAR_LEFT_X := 24.0       # 左侧填充起点
const BAR_RIGHT_X := 616.0     # 右侧填充终点（右对齐）

@onready var name_l: Label = $NameL
@onready var name_r: Label = $NameR
@onready var hp_l: Label = $HpL
@onready var hp_r: Label = $HpR
@onready var fill_l: ColorRect = $FillL
@onready var fill_r: ColorRect = $FillR
@onready var ghost_l: ColorRect = $GhostL
@onready var ghost_r: ColorRect = $GhostR
@onready var meter_l: ColorRect = $MeterFillL
@onready var meter_r: ColorRect = $MeterFillR
@onready var combo_l: Label = $ComboL
@onready var combo_r: Label = $ComboR
@onready var burst_l: Label = $BurstL
@onready var burst_r: Label = $BurstR
@onready var message: Label = $Message
@onready var hint_l: Label = $HintL
@onready var hint_r: Label = $HintR
@onready var hint_c: Label = $HintC

var _pips: Array = []
var _shown := [1.0, 1.0]       # 当前血量比例
var _ghost := [1.0, 1.0]       # 延迟回落的比例，用于显示刚刚失去的血量
var _meter := [0.5, 0.5]       # 能量比例


func _ready() -> void:
	fill_l.color = TEAM_COLOR[0]
	fill_r.color = TEAM_COLOR[1]
	ghost_l.color = GHOST_COLOR
	ghost_r.color = GHOST_COLOR
	meter_l.color = METER_COLOR[0]
	meter_r.color = METER_COLOR[1]
	_pips = [[$PipL1, $PipL2, $PipL3], [$PipR1, $PipR2, $PipR3]]
	combo_l.text = ""
	combo_r.text = ""
	refresh(0, Mecha.MAX_HP)
	refresh(1, Mecha.MAX_HP)
	set_meter(0, Mecha.START_METER)
	set_meter(1, Mecha.START_METER)
	set_rounds(0, 0, 2)


func _process(delta: float) -> void:
	for i in 2:
		_ghost[i] = move_toward(_ghost[i], _shown[i], delta * 0.5)
	var w_l := floorf(BAR_W * _shown[0])
	var w_r := floorf(BAR_W * _shown[1])
	fill_l.size.x = w_l
	fill_r.size.x = w_r
	fill_r.position.x = BAR_RIGHT_X - w_r
	ghost_l.size.x = floorf(BAR_W * _ghost[0])
	ghost_r.size.x = floorf(BAR_W * _ghost[1])
	ghost_r.position.x = BAR_RIGHT_X - ghost_r.size.x

	var m_l := floorf(METER_W * _meter[0])
	var m_r := floorf(METER_W * _meter[1])
	meter_l.size.x = m_l
	meter_r.size.x = m_r
	meter_r.position.x = BAR_RIGHT_X - m_r


func refresh(index: int, hp: int) -> void:
	var ratio := clampf(float(hp) / float(Mecha.MAX_HP), 0.0, 1.0)
	_shown[index] = ratio
	var label: Label = hp_l if index == 0 else hp_r
	label.text = "%d / %d" % [hp, Mecha.MAX_HP]
	label.modulate = Color("#ff5a5a") if ratio <= 0.3 else Color(1, 1, 1)


func set_meter(index: int, value: float) -> void:
	_meter[index] = clampf(value / Mecha.MAX_METER, 0.0, 1.0)


## needed = 拿下比赛所需胜场，决定显示几个回合胜点
func set_rounds(left: int, right: int, needed: int) -> void:
	for i in 2:
		var wins: int = left if i == 0 else right
		for k in 3:
			var pip: ColorRect = _pips[i][k]
			pip.visible = k < needed
			pip.color = TEAM_COLOR[i] if wins > k else PIP_EMPTY


## 受击硬直且能量足够时，提示玩家可以用爆气挣脱（教机制用，只在真人侧显示）
func set_burst_prompt(index: int, show: bool) -> void:
	var label: Label = burst_l if index == 0 else burst_r
	label.visible = show


func show_combo(index: int, count: int) -> void:
	var label: Label = combo_l if index == 0 else combo_r
	label.text = "%d 连击！" % count
	label.modulate = Color(1, 1, 1, 1)


func clear_combo(index: int) -> void:
	var label: Label = combo_l if index == 0 else combo_r
	label.text = ""


func set_names(left: String, right: String) -> void:
	name_l.text = left
	name_r.text = right


func set_message(text: String) -> void:
	message.text = text
	message.visible = text != ""


func set_hints(left: String, right: String, center: String) -> void:
	hint_l.text = left
	hint_r.text = right
	hint_c.text = center
