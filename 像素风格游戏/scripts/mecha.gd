class_name Mecha
extends CharacterBody2D
## 机甲角色：格斗游戏式的攻防状态机 + 程序化骨骼动画。
##
## 战斗系统按格斗游戏的三段式帧结构设计（startup / active / recovery）：
##   · 地面近战连段：轻斩 → 轻斩 → 重斩终结（命中确认后才开放取消窗口）
##   · 必杀取消：普通技命中后可取消成能量炮 / 破甲重击（街霸的 special cancel）
##   · 浮空追打：招式有浮空上限 jl，对手有浮空计数 juggle，必须 jl ≥ juggle 才打得中
##   · 反击命中：打在对手前摇上 → 伤害与硬直都更高（Counter Hit）
##   · 空中斩：滞空中攻击，用来打逆向、空中拦截与落地后的浮空追打
##   · 能量炮：不再是普通攻击，而是耗能极少的远程骚扰手段
##   · 防御：普通格挡只吃 1 点削减伤害；按下的 0.12s 内挡到则触发完美格挡
##   · 翻滚闪避：独立按键，方向取 A/D（不按则朝面向），全程无敌但有后摇
##   · 爆气脱身：受击硬直中消耗大量能量挣脱
##
## 命中判定用「面朝右坐标系」下的矩形判定框做 AABB 相交，
## 命中后统一走 take_hit()，不为近战另开一条伤害路径。

signal fired(projectile: Node2D)                     ## 请求主场景生成弹丸
signal effect(kind: String, at: Vector2, team: int)  ## 请求播放特效
signal hit_landed(victim: Mecha, attacker: Mecha, taken: int, blocked: bool, at: Vector2)
signal health_changed(mecha: Mecha)
signal meter_changed(mecha: Mecha)
signal died(mecha: Mecha)

enum State { IDLE, RUN, AIR, ATTACK, BLOCK, HURT, DODGE, DEAD }

# ------------------------------------------------------------------ 数值
const MAX_HP := 100
const MAX_METER := 100.0
const START_METER := 50.0
## 能量主要靠时间攒：命中只能补一点点，所以「什么时候花」才是决策点
const METER_REGEN := 9.0          # 每秒自然恢复
const SHOOT_COST := 8.0           # 远程攻击只需极少能量（≈1 秒自然回复）
const DODGE_COST := 20.0          # 翻滚闪避消耗 20 能量（≈2.2 秒自然回复）
const METER_DEAL := 4.0           # 命中对手时攻击方获得（已大幅下调）
const METER_DEAL_BLOCKED := 2.0
const METER_TAKE := 3.0           # 被命中时受击方获得
const METER_TAKE_BLOCKED := 1.0

const SPEED := 82.0               # 地面移动速度 px/s
const ACCEL := 1000.0
const FRICTION := 1400.0
const AIR_ACCEL := 420.0
const GRAVITY := 700.0
const MAX_FALL := 330.0
const JUMP_VELOCITY := -205.0     # 跳跃不消耗任何能量

# 翻滚闪避（独立按键触发）：全程无敌但距离短、耗能高、结束后有后摇
const DODGE_SPEED := 175.0        # 距离刻意压短，只用来躲判定而不是长途位移
const DODGE_TIME := 0.20          # 翻滚时长 = 无敌时长
const DODGE_RECOVERY := 0.18      # 后摇：这段时间不能行动，乱滚会被抓

const BLOCK_CHIP_DAMAGE := 1      # 格挡固定只扣 1 血（不分招式轻重）
const BLOCK_STUN := 0.10          # 格挡硬直：期间无法解除防御
const BLOCK_KNOCKBACK := 26.0
## 破甲重击：打穿防御。被破防的一方要承受大额削减伤害 + 长时间硬直，
## 并且一段时间内无法再举盾——这是「一直龟缩」的唯一正解。
const GUARD_BREAK_MULT := 0.55    # 破甲伤害按原伤害的比例（22 → 12）
const GUARD_BREAK_STUN := 0.75    # 破防硬直
const GUARD_LOCK_TIME := 1.30     # 破防后禁止举盾的时长
## 完美格挡（Just Guard）：按下防御的 0.12 秒内挡到 → 完全免伤并弹开对手。
## 这是「防御要吃时机」的核心：一直按住只能吃 1 点削减伤害，踩点挡才是真收益。
const GUARD_WINDOW := 0.12
const GUARD_SELF_STUN := 0.14
const GUARD_FX_HOLD := 0.28
const GUARD_REPEL := 96.0         # 完美格挡把对手弹开的力度
const GUARD_METER_BONUS := 14.0   # 完美格挡的能量回馈
const GUARD_ATTACKER_STUN := 1.0  # 被完美格挡后攻击方的固定硬直（1 秒）
const GUN_SPEED := 260.0
const GUN_DAMAGE := 12
const GUN_INVULN := 0.18          # 炮击命中给无敌帧，防止连射锁死对手
const HIT_FLASH := 0.12
## 取消衔接 / 反击命中时，光刃爆闪一下的时长。
## 连招系统的规则光靠 HUD 上的数字讲不清楚，得让刀自己闪一下才算「看得见」。
const BLADE_FLASH := 0.09
## 光刃在判定帧结束后还要亮多久（按后摇的比例），期间透明度线性淡出。
## 留这一段是为了让挥砍的弧线是完整的，而不是判定帧一结束刀就凭空消失。
const BLADE_LINGER := 0.45
## 出招头 2 帧的关节缓冲。从奔跑 / 举盾 / 滞空切进出招时姿态差最大，
## 一帧贴到位会「跳」一下；这两帧限制每帧最大转动 / 位移，之后再全速（详见 _update_rig）。
const START_BLEND_FRAMES := 2
const START_BLEND_STEP := 0.80        # 关节：弧度/帧，≈46°
const START_BLEND_SHIFT := 4.0        # 位移：像素/帧

# 连段递减：这是防止「无限连」的关键。
# 受击方连续被打时，硬直与伤害逐段衰减，连段必然自然断开并留出逃生窗口。
const COMBO_WINDOW := 1.1         # 超过这段时间没再挨打，连段计数归零
const STUN_DECAY := 0.15          # 每多挨一下，硬直 -15%
const DMG_DECAY := 0.10           # 每多挨一下，伤害 -10%
## 衰减下限。压到 0.3 是关键：这样连打时的残余硬直会明显短于招式间隔，
## 受击方一定能拿到几帧的行动窗口（按住防御即刻成立，或按爆气键强行脱身）。
const DECAY_FLOOR := 0.3

# 连招系统（街霸式简化版）的四条规则，全部集中在 MOVES 表与 take_hit 里：
#   1. 必杀取消  Special Cancel —— 普通技命中后，后摇期间可取消成能量炮 / 破甲重击
#   2. 起手递减  Starter Scaling —— 用哪一招起手，决定整条连段的衰减速度
#   3. 浮空追打  Juggle (JC/JL) —— 招式有浮空上限 jl，对手有浮空计数 juggle，必须 jl ≥ juggle
#   4. 反击命中  Counter Hit —— 打在对手前摇上，伤害 +25%、硬直 +30%
const COUNTER_DMG_MULT := 1.25    # 反击命中：伤害加成
const COUNTER_STUN_MULT := 1.30   # 反击命中：硬直加成

# 爆气脱身：受击硬直中消耗能量强行挣脱压制（受击方的主动反击手段）
const BURST_COST := 50.0
const BURST_INVULN := 0.55
const BURST_KNOCKBACK := 95.0

## 招式帧数据表。box 为「面朝右」坐标系下的判定框（x 正向为前方）。
##
## 连招系统相关的三个字段：
##   cancel         —— 命中后可取消衔接的下一段（普通技链式取消），空串表示终点
##   special_cancel —— 后摇期间是否可取消成必杀技（能量炮 / 破甲重击）
##   jl             —— 浮空追打上限（Juggle Limit）：对手浮空计数 juggle 超过它就打不中
##   starter        —— 起手递减（Starter Scaling）：这一招作为连段第一段时，
##                     给后续所有段位追加的衰减量（轻技起手衰减慢、能连得长；
##                     重招起手衰减快、伤害高但连不上后续）
##
## startup 的取值：三个平A段（轻斩①②、重斩终结）**统一 0.12s**。
## 早期它们的 startup 只有 0.05s（3 帧），快到对手根本来不及反应，于是「狂按平A」
## 就成了压制力最强的打法。现在统一拉到 0.12s（≈7 帧）：
##   · 出招前多了一段看得见的收势，对手有机会读招、格挡或抢出手；
##   · 平A 的循环频率从约 5 次/秒降到约 3.7 次/秒；
##   · 三段 timing 一致 → 对手没法靠「哪段更快」来判断来的是哪一招，
##     只能靠**动作剪影**认招（这正是每段配不同 rig 的意义）。
## recovery 与 active 都没动，所以每段的「轻重」差别仍由后摇与击退体现。
const MOVES := {
	"light1": {
		"kind": "melee",
		"startup": 0.12, "active": 0.06, "recovery": 0.09,
		"dmg": 6, "hitstun": 0.26, "knock": 16.0, "lift": 0.0, "invuln": 0.0,
		"box": Rect2(4.0, -31.0, 21.0, 15.0),
		"cancel": "light2", "arc": "slash_a",
		# 最理想的起手技：衰减慢，可以接满整条连段
		"special_cancel": true, "jl": 1, "starter": 0.0,
		# 姿态「直刺」：手臂收到身后 → 笔直前伸，后臂反向甩出去配重
		"rig": {
			"wind":   {"af": 1.20, "ab": -0.55, "tor": -0.08, "tx": -1.5, "lf": 0.14, "lb": -0.10, "bob": 0.6},
			"strike": {"af": -1.72, "ab": 1.20, "tor": 0.08, "tx": 2.2, "lf": 0.30, "lb": -0.24, "bob": -0.5},
		},
	},
	"light2": {
		"kind": "melee",
		"startup": 0.12, "active": 0.06, "recovery": 0.12,
		"dmg": 7, "hitstun": 0.34, "knock": 20.0, "lift": 0.0, "invuln": 0.0,
		"box": Rect2(4.0, -33.0, 22.0, 18.0),
		"cancel": "heavy", "arc": "slash_a",
		# 轻斩②只能由轻斩①取消而来，永远不可能是连段的第一段，所以 starter 用不上
		"special_cancel": true, "jl": 1, "starter": 0.0,
		# 姿态「过肩下劈」：刀举到身后上方 → 整条躯干前压着劈到膝前。
		# 和轻斩①的直刺刻意做成一横一竖两种走向，连打时一眼能数出打到第几段
		"rig": {
			"wind":   {"af": 2.05, "ab": 1.30, "tor": -0.20, "tx": -3.0, "lf": 0.20, "lb": -0.16, "bob": 1.2},
			"strike": {"af": -0.62, "ab": -0.95, "tor": 0.34, "tx": 5.2, "lf": 0.44, "lb": -0.32, "bob": -1.8},
		},
	},
	"heavy": {
		# 连段收尾「重斩终结」：本身后摇很长，但命中后仍可取消成必杀技，
		# 于是「轻斩①② → 重斩 → 必杀」成为一条完整的四段连招。
		"kind": "melee",
		"startup": 0.12, "active": 0.08, "recovery": 0.36,
		"dmg": 15, "hitstun": 0.40, "knock": 60.0, "lift": -105.0, "invuln": 0.0,
		"box": Rect2(3.0, -35.0, 26.0, 26.0),
		"cancel": "", "arc": "slash_b",
		"special_cancel": true, "jl": 2, "starter": 0.12,
		# 姿态「上撩挑飞」：刀沉在身前低位、后臂往后甩、屈膝下蹲 → 撩到身前上方、身体后仰成弓。
		# 动作走向和它「把对手挑到空中」的结果一致，不用看血条也能读出这招会把人打飞。
		# 起手刻意和轻斩①②区分开：轻①收在身后偏低、轻②举到身后上方，重斩则是沉在身前低位
		"rig": {
			"wind":   {"af": -0.75, "ab": 0.85, "tor": 0.16, "tx": 2.8, "lf": 0.36, "lb": -0.38, "bob": 2.4},
			"strike": {"af": -2.55, "ab": -1.10, "tor": -0.36, "tx": -4.2, "lf": 0.22, "lb": -0.52, "bob": -2.4},
		},
	},
	"breaker": {
		# 破甲重击：前后摇都非常大、动作刻意夸张，但能打穿防御。
		# charge = 自定义「蓄力」姿态（不是普通的起手抬臂），见 _update_rig。
		# 浮空上限最高（jl = 4）：它是唯一能把对手从浮空里继续砸下来的招。
		"kind": "melee",
		"startup": 0.34, "active": 0.10, "recovery": 0.46,
		"dmg": 22, "hitstun": 0.52, "knock": 74.0, "lift": -70.0, "invuln": 0.0,
		"box": Rect2(5.0, -36.0, 30.0, 30.0),
		"cancel": "", "arc": "slash_c",
		"arm_from": 2.15, "arm_to": -1.95, "lean": 0.30,
		"charge": true, "lunge": 135.0, "guard_break": true,
		"special_cancel": false, "jl": 4, "starter": 0.12,
	},
	"air": {
		"kind": "melee",
		"startup": 0.06, "active": 0.11, "recovery": 0.12,
		"dmg": 9, "hitstun": 0.30, "knock": 24.0, "lift": -30.0, "invuln": 0.0,
		"box": Rect2(3.0, -27.0, 23.0, 22.0),
		"cancel": "", "arc": "slash_a",
		# 空中斩浮空上限高（jl = 3）：挑飞之后跳起来追打是它的主场
		"special_cancel": false, "jl": 3, "starter": 0.0,
		# 姿态「空中下劈」：双腿在空中前后大张、刀举过头 → 一记劈到前下方
		"rig": {
			"wind":   {"af": 2.60, "ab": 1.75, "tor": -0.22, "tx": -1.8, "lf": 0.60, "lb": -0.62, "bob": -1.6},
			"strike": {"af": -0.35, "ab": 0.10, "tor": 0.36, "tx": 3.2, "lf": 0.32, "lb": -0.42, "bob": 0.4},
		},
	},
	"shoot": {
		"kind": "shoot",
		"startup": 0.07, "active": 0.0, "recovery": 0.16,
		"dmg": GUN_DAMAGE, "hitstun": 0.24, "knock": 40.0, "lift": 0.0, "invuln": GUN_INVULN,
		"box": Rect2(0.0, 0.0, 0.0, 0.0),
		"cancel": "", "arc": "",
		"special_cancel": false, "jl": 2, "starter": 0.0,
		# 姿态「托炮瞄准 → 后坐」：双臂合拢把炮口推向前 → 身体被后坐力顶得后仰、双腿撑住。
		# 炮击没有判定帧（active = 0），所以「瞄准」在起手里完成，开炮瞬间正好吃上后坐
		"rig": {
			"wind":   {"af": -1.45, "ab": -1.35, "tor": 0.05, "tx": 1.0, "lf": 0.18, "lb": -0.22, "bob": 0.3},
			"strike": {"af": -1.80, "ab": -1.15, "tor": -0.24, "tx": -3.5, "lf": 0.34, "lb": -0.38, "bob": -0.6},
		},
	},
}

const BODY_HALF_W := 7.0           # 机甲受击框半宽
const BODY_H := 34.0

## 招式姿态（rig）的关键帧约定 —— 每个非蓄力招式在 MOVES 表里带两帧关键剪影：
##   wind    起手收势（startup 结束时到达）
##   strike  挥出到位（判定帧结束时到达）
## 收招统一从 strike 插回下面的 POSE_IDLE。
## 每帧姿态 = 7 个关节目标（都在「面朝右」坐标系里）：
##   af / ab  前臂 / 后臂：0 = 自然垂下，负 = 往身体前方抬，正 = 往身后抬
##            （±1.57 = 水平，±3.14 = 竖直向上，所以 ±2.5 就是「高举过顶」）
##   tor      躯干俯仰：负 = 后仰，正 = 前压
##   tx       躯干前后位移：正 = 向前顶
##   lf / lb  前腿 / 后腿摆角
##   bob      重心高低：正 = 下沉（下蹲蓄势），负 = 上拔（起跳 / 后仰）
## 这些数字只影响画面，绝不参与 startup/active/recovery 的推进，
## 所以重做动画不会动到连招的帧数时序。
const POSE_IDLE := {"af": 0.10, "ab": 0.10, "tor": 0.0, "tx": 0.0, "lf": 0.0, "lb": 0.0, "bob": 0.0}

# ------------------------------------------------------------------ 素材
const TEX := {
	0: {
		"torso": preload("res://assets/mecha/blue_torso.png"),
		"arm": preload("res://assets/mecha/blue_arm.png"),
		"leg": preload("res://assets/mecha/blue_leg.png"),
		"shield": preload("res://assets/mecha/blue_shield.png"),
		"blade": preload("res://assets/mecha/blue_blade.png"),
	},
	1: {
		"torso": preload("res://assets/mecha/red_torso.png"),
		"arm": preload("res://assets/mecha/red_arm.png"),
		"leg": preload("res://assets/mecha/red_leg.png"),
		"shield": preload("res://assets/mecha/red_shield.png"),
		"blade": preload("res://assets/mecha/red_blade.png"),
	},
}
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

# ------------------------------------------------------------------ 对外状态
var team := 0                     ## 0 = 蓝方，1 = 红方
var is_ai := false                ## true 时由 AiBrain 接管
var opponent: Mecha = null
var frozen := false               ## 开场倒计时/回合结算期间禁止操作
var input_prefix := "p1_"
var arena_min_x := 18.0
var arena_max_x := 302.0
var facing := 1                   ## 1 = 朝右，-1 = 朝左
var hp := MAX_HP
var meter := START_METER
var state: State = State.IDLE
var brain: AiBrain = null
var combo_taken := 0              ## 连续挨打的衰减计数（决定硬直/伤害递减）
var combo_display := 0            ## 真正的连段数：只在持续被打中累加，站起来就归零
var juggle := 0                   ## 浮空计数（Juggle Count）：0 = 未被挑飞；1+ = 浮空中，
                                  ## 后续追打必须用 jl ≥ juggle 的招才打得中
var last_move := ""               ## 最近结束的招式名（AI 用来判断连段收招）

# ------------------------------------------------------------------ 内部节点
@onready var visual: Node2D = $Visual
@onready var torso: Sprite2D = $Visual/Torso
@onready var arm_front: Sprite2D = $Visual/ArmFront
@onready var arm_back: Sprite2D = $Visual/ArmBack
@onready var leg_front: Sprite2D = $Visual/LegFront
@onready var leg_back: Sprite2D = $Visual/LegBack
@onready var shield: Sprite2D = $Visual/Shield
@onready var blade: Sprite2D = $Visual/Blade
@onready var muzzle: Marker2D = $Visual/ArmFront/Muzzle

# ------------------------------------------------------------------ 内部状态
var _clock := 0.0
var _anim_t := 0.0
var _run_phase := 0.0
var _flash_t := 0.0
var _hurt_t := 0.0
var _invuln_t := 0.0
var _block_stun_t := 0.0
var _combo_t := 0.0                ## 连续挨打的计时器
var _dodge_t := 0.0                ## 翻滚剩余时长
var _dodge_recover_t := 0.0        ## 翻滚后摇剩余时长
var _roll_dir := 1                 ## 翻滚方向（1 = 朝面向方向，-1 = 朝背后）
var _roll_angle := 0.0             ## 翻滚累计角度，用来做旋转动画
var _guard_t := 0.0                ## 完美格挡窗口剩余（按下防御后开始倒数）
var _guard_flash_t := 0.0          ## 完美格挡成功的特效保持时间
var _block_held := false           ## 本帧是否按住防御（含 AI），用于补同帧的状态时序差

var _move_name := ""
var _move: Dictionary = {}
var _atk_t := 0.0
var _atk_started := false          ## 判定帧是否已经开启
var _hit_confirmed := false        ## 本次攻击是否「有效命中」（决定能否取消连段）
var _hit_used := false             ## 本次攻击是否已经结算过一次（防止判定帧内每帧重复扣血）
var _buffered_attack := false      ## 攻击键输入缓冲，让连段不必帧级精准
var _buffered_heavy := false       ## 重击键输入缓冲（必杀取消成破甲重击用）
var _buffered_shoot := false       ## 炮击键输入缓冲（必杀取消成能量炮用）
var _combo_starter := 0.0          ## 当前连段的起手衰减（由连段第一段的招式决定）
var _charge_k := 0.0               ## 蓄力进度 0..1（只用于重击的光刃辉光）
var _charge_fx_t := 0.0            ## 蓄力粒子的发射节拍
var _blade_flash_t := 0.0          ## 光刃爆闪剩余时间（取消衔接 / 反击命中时点亮）
var _guard_lock_t := 0.0           ## 被破防后禁止举盾的剩余时间
var _blade_on := false

var _prev_jump := false
var _prev_atk := false
var _prev_heavy := false
var _prev_shoot := false
var _prev_burst := false
var _prev_block := false
var _prev_dodge := false
var _prev_left := false
var _prev_right := false

var _death_tween: Tween = null
const _TORSO_BASE := Vector2(0.0, -14.0)
const _ARM_F_BASE := Vector2(1.0, -30.0)     ## 前臂肩点的静止位置
const _ARM_B_BASE := Vector2(-3.0, -30.0)
const _SHIELD_BASE := Vector2(2.0, -26.0)
const _ROLL_PIVOT := Vector2(0.0, -17.0)   ## 翻滚时绕它旋转（身体中心）


func _ready() -> void:
	add_to_group("mecha")
	_apply_team_textures()
	_set_facing(1 if team == 0 else -1)
	visual.scale.x = float(facing)
	if is_ai:
		brain = AiBrain.new()
	hp = MAX_HP
	meter = START_METER


func _apply_team_textures() -> void:
	var set_tex: Dictionary = TEX[clampi(team, 0, 1)]
	var legs: Texture2D = set_tex["leg"]
	var arms: Texture2D = set_tex["arm"]
	torso.texture = set_tex["torso"]
	shield.texture = set_tex["shield"]
	blade.texture = set_tex["blade"]
	leg_front.texture = legs
	leg_back.texture = legs
	arm_front.texture = arms
	arm_back.texture = arms


## 回合开始时复位（位置、血量、能量、动作、死亡动画）
func reset_for_round(spawn: Vector2) -> void:
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	hp = MAX_HP
	meter = START_METER
	state = State.IDLE
	velocity = Vector2.ZERO
	position = spawn
	_invuln_t = 0.5
	_hurt_t = 0.0
	_atk_t = 0.0
	_dodge_t = 0.0
	_dodge_recover_t = 0.0
	_roll_angle = 0.0
	_guard_t = 0.0
	_guard_flash_t = 0.0
	_guard_lock_t = 0.0
	_block_held = false
	_block_stun_t = 0.0
	_combo_t = 0.0
	combo_taken = 0
	_combo_starter = 0.0
	juggle = 0
	last_move = ""
	_move = {}
	_move_name = ""
	_atk_started = false
	_hit_confirmed = false
	_hit_used = false
	_charge_k = 0.0
	_charge_fx_t = 0.0
	_blade_flash_t = 0.0
	_buffered_attack = false
	_buffered_heavy = false
	_buffered_shoot = false
	_blade_on = false
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	visual.modulate = Color(1, 1, 1, 1)
	shield.visible = false
	blade.visible = false
	_set_facing(1 if team == 0 else -1)
	visual.scale.x = float(facing)
	emit_signal("health_changed", self)
	emit_signal("meter_changed", self)


# ================================================================ 主循环
func _physics_process(delta: float) -> void:
	_clock += delta
	_tick_timers(delta)

	if state == State.DEAD:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	var intent := _read_intent(delta)
	var grounded := is_on_floor()
	# 输入缓冲：三种攻击键的按压都缓存起来，等连段窗口一开就立即衔接。
	# 必杀取消（能量炮 / 破甲重击）也靠这两个缓冲才能接在普通技后面。
	if bool(intent["attack"]):
		_buffered_attack = true
	if bool(intent["heavy"]):
		_buffered_heavy = true
	if bool(intent["shoot"]):
		_buffered_shoot = true
	# 防御「按下的那一瞬间」开启完美格挡窗口。
	# 放在这里而不是 _poll_keys，是为了让 AI 也走同一条路径。
	var block_now := bool(intent["block"]) and grounded and not frozen
	if block_now and not _block_held:
		_guard_t = GUARD_WINDOW
	_block_held = block_now

	# 爆气脱身：受击硬直/格挡硬直中，消耗能量强行挣脱压制。
	# 本帧跳过 _advance_state，避免同一次按键紧接着又触发射炮。
	if (state == State.HURT or state == State.BLOCK) \
			and bool(intent["burst"]) and meter >= BURST_COST:
		_do_burst()
	else:
		_advance_state(intent, grounded, delta)

	# 水平运动：攻击/受击/防御/翻滚中不受控
	if state == State.DODGE:
		pass                                   # 翻滚速度由 _advance_state 维持
	elif state == State.HURT:
		pass                                   # 受击时保留击退速度，否则击退会被摩擦力吃掉
	else:
		var dir := 0
		if _can_act() and not frozen:
			dir = int(intent["move"])
		if grounded:
			velocity.x = move_toward(velocity.x, dir * SPEED, (ACCEL if dir != 0 else FRICTION) * delta)
		else:
			velocity.x = move_toward(velocity.x, dir * SPEED, AIR_ACCEL * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	position.x = clampf(position.x, arena_min_x, arena_max_x)

	if state == State.ATTACK:
		_tick_attack(delta)

	_update_facing()
	_update_rig(delta)


func _tick_timers(delta: float) -> void:
	_invuln_t = maxf(0.0, _invuln_t - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	_block_stun_t = maxf(0.0, _block_stun_t - delta)
	_guard_t = maxf(0.0, _guard_t - delta)
	_guard_flash_t = maxf(0.0, _guard_flash_t - delta)
	_dodge_recover_t = maxf(0.0, _dodge_recover_t - delta)
	_guard_lock_t = maxf(0.0, _guard_lock_t - delta)
	_blade_flash_t = maxf(0.0, _blade_flash_t - delta)
	# 能量随时间缓慢回复：命中只补一点点，所以「什么时候花」才是决策点
	if state != State.DEAD:
		gain_meter(METER_REGEN * delta)
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			# 只有「确实隔了足够久没再挨打」才让衰减归零。
			# 关键：不能在受击方刚站起来的瞬间就归零——那样衰减会被反复重置，
			# 残余硬直又回到满值，连打照样能把人锁死。
			combo_taken = 0
			_combo_starter = 0.0         # 连段结束，起手递减也跟着清掉
	# 落地即清空浮空计数：再次起跳或被挑飞会重新开始计数
	if is_on_floor():
		juggle = 0
	if state == State.HURT:
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			state = State.IDLE
			combo_display = 0            # 站回可行动 = 这段连段结束（只影响 HUD 显示）


## 可自由行动（可移动/起跳/出新招）。
## 翻滚后摇期间不算可行动——这是闪避的成本，乱滚会被抓。
func _can_act() -> bool:
	if _dodge_recover_t > 0.0:
		return false
	return state == State.IDLE or state == State.RUN or state == State.AIR


func _advance_state(intent: Dictionary, grounded: bool, delta: float) -> void:
	match state:
		State.HURT:
			return                                   # 受击硬直中完全无法操作
		State.DODGE:
			_dodge_t -= delta
			velocity.x = float(_roll_dir) * DODGE_SPEED
			# 旋转符号要乘上 facing：Visual 有 scale.x = -1 镜像，
			# 镜像会把旋转方向翻转过来，不补这一下会出现「往右滚却逆时针转」。
			_roll_angle += delta / DODGE_TIME * TAU * float(_roll_dir * facing)
			if _dodge_t <= 0.0:
				# 翻滚结束进入后摇：期间不能行动，所以乱滚是要付出代价的
				_dodge_recover_t = DODGE_RECOVERY
				state = State.AIR if not grounded else State.IDLE
			return
		State.ATTACK:
			return                                   # 招式时序在 _tick_attack 里推进
		State.BLOCK:
			# 被破防后一段时间内举不起盾；正在举盾时被破防也会立刻掉出来
			if _guard_lock_t > 0.0:
				state = State.IDLE
			elif (not bool(intent["block"]) and _block_stun_t <= 0.0) or not grounded:
				state = State.IDLE
			else:
				return
		_:
			pass

	if not _can_act():
		return                                       # 翻滚后摇期间不接受任何新指令

	if bool(intent["block"]) and grounded and _guard_lock_t <= 0.0:
		state = State.BLOCK
	elif bool(intent["heavy"]) and grounded:
		_start_move("breaker")
	elif bool(intent["attack"]):
		_start_move("light1" if grounded else "air")
	elif bool(intent["shoot"]) and meter >= SHOOT_COST and grounded:
		_start_move("shoot")
	elif int(intent["dodge"]) != 0 and meter >= DODGE_COST and grounded:
		_start_dodge(int(intent["dodge"]))
	elif bool(intent["jump"]) and grounded:
		velocity.y = JUMP_VELOCITY              # 跳跃不消耗能量
	else:
		state = State.AIR if not grounded else (State.RUN if absf(velocity.x) > 8.0 else State.IDLE)


# ================================================================ 输入
func _poll_keys() -> Dictionary:
	var p := input_prefix
	# 菜单里的展示机甲没有按键前缀，这里兜一手，避免读到不存在的动作
	if not InputMap.has_action(p + "left"):
		return _empty_intent()
	var left := Input.is_action_pressed(p + "left")
	var right := Input.is_action_pressed(p + "right")
	var jump := Input.is_action_pressed(p + "jump")
	var atk := Input.is_action_pressed(p + "attack")
	var heavy := Input.is_action_pressed(p + "heavy")
	var shoot := Input.is_action_pressed(p + "shoot")
	var burst := Input.is_action_pressed(p + "burst")
	var block := Input.is_action_pressed(p + "block")
	var dodge_pressed := Input.is_action_pressed(p + "dodge")

	# 翻滚闪避：独立按键。方向优先按 A/D，没按方向键就朝角色当前面向滚
	var dodge := 0
	if dodge_pressed and not _prev_dodge:
		if left and not right:
			dodge = -1
		elif right and not left:
			dodge = 1
		else:
			dodge = facing            # 没按方向键 → 朝面向翻滚

	var out := {
		"move": int(right) - int(left),
		"jump": jump and not _prev_jump,
		"attack": atk and not _prev_atk,
		"heavy": heavy and not _prev_heavy,
		"shoot": shoot and not _prev_shoot,
		"burst": burst and not _prev_burst,
		"block": block,
		"dodge": dodge,
	}
	_prev_left = left
	_prev_right = right
	_prev_jump = jump
	_prev_atk = atk
	_prev_heavy = heavy
	_prev_shoot = shoot
	_prev_burst = burst
	_prev_block = block
	_prev_dodge = dodge_pressed
	return out


func _read_intent(delta: float) -> Dictionary:
	if is_ai and brain == null:
		brain = AiBrain.new()          # 支持运行中从「玩家」切换为「电脑」
	if frozen:
		_poll_keys()                   # 冻结时仍更新按键边沿，避免解冻瞬间误触发
		return _empty_intent()
	if is_ai and brain != null and opponent != null:
		return brain.update(delta, self, opponent)
	return _poll_keys()


func _empty_intent() -> Dictionary:
	return {
		"move": 0, "jump": false, "attack": false, "heavy": false,
		"shoot": false, "burst": false, "block": false, "dodge": 0,
	}


func _update_facing() -> void:
	if opponent == null or state == State.DEAD or frozen:
		return
	if state == State.ATTACK or state == State.BLOCK or state == State.HURT or state == State.DODGE:
		return
	var d := opponent.position.x - position.x
	if absf(d) > 6.0:
		_set_facing(1 if d > 0.0 else -1)


func _set_facing(f: int) -> void:
	if f == facing and visual.scale.x == float(facing):
		return
	facing = f
	visual.scale.x = float(facing)


# ================================================================ 招式
func can_act() -> bool:
	return _can_act() and not frozen


func is_attack_ready() -> bool:
	return can_act()


func can_shoot() -> bool:
	return can_act() and meter >= SHOOT_COST and is_on_floor()


func can_dodge() -> bool:
	return can_act() and meter >= DODGE_COST and is_on_floor()


## 「面朝右」坐标系 → 世界坐标判定框（朝左时水平镜像）
func _mirror_box(b: Rect2) -> Rect2:
	var x := position.x + b.position.x if facing > 0 else position.x - b.position.x - b.size.x
	return Rect2(x, position.y + b.position.y, b.size.x, b.size.y)


## 受击判定框（与碰撞体同尺寸）
func body_box() -> Rect2:
	return Rect2(position.x - BODY_HALF_W, position.y - BODY_H, BODY_HALF_W * 2.0, BODY_H)


func _start_move(move_name: String) -> void:
	if not MOVES.has(move_name):
		return
	_move_name = move_name
	_move = MOVES[move_name]
	state = State.ATTACK
	_atk_t = 0.0
	_atk_started = false
	_hit_confirmed = false
	_hit_used = false
	_buffered_attack = false
	_buffered_heavy = false
	_buffered_shoot = false
	_blade_on = false
	if String(_move["kind"]) == "shoot":
		meter -= SHOOT_COST
		emit_signal("meter_changed", self)


func _end_move() -> void:
	last_move = _move_name
	state = State.AIR if not is_on_floor() else State.IDLE
	_move = {}
	_move_name = ""
	_atk_t = 0.0
	_atk_started = false
	_hit_confirmed = false
	_hit_used = false
	_buffered_attack = false
	_buffered_heavy = false
	_buffered_shoot = false
	_charge_k = 0.0
	_charge_fx_t = 0.0
	_blade_on = false


func _tick_attack(delta: float) -> void:
	_atk_t += delta
	var startup := float(_move["startup"])
	var active := float(_move["active"])
	var recovery := float(_move["recovery"])
	var swing := startup + active

	# 光刃从起手就亮起来（对手看得见「刀要来了」），判定帧结束后再随收招慢慢散掉，
	# 而不是在判定帧结束的那一瞬间凭空消失——否则挥砍的弧线会被硬生生切掉，
	# 手臂还在往前送、刀却已经没了。消散的透明度在 _update_rig 里算。
	_blade_on = String(_move["kind"]) == "melee" and _atk_t < swing + recovery * BLADE_LINGER

	# 蓄力重击：前摇期间在身后上方反复喷出能量粒子，作为「要来了」的预兆
	if bool(_move.get("charge", false)) and _atk_t < startup:
		_charge_fx_t -= delta
		if _charge_fx_t <= 0.0:
			_charge_fx_t = 0.09
			emit_signal("effect", "charge",
				global_position + Vector2(-float(facing) * 9.0, -30.0), team)

	if not _atk_started and _atk_t >= startup:
		_atk_started = true
		_on_active_start()

	if _atk_started and _atk_t < swing:
		_check_melee_hit()

	# 连段取消：必须「命中确认」且「本次判定帧已经结束」才开放取消窗口。
	# 空挥（没打中）不开放取消，乱按没有用；也不能取消掉自己的前摇，
	# 所以不存在无脑无后摇的无限连。
	if _hit_confirmed and _atk_t >= swing:
		var special := bool(_move.get("special_cancel", false))
		# ① 必杀取消：普通技命中后直接取消成必杀技，跳过本招的后摇。
		#    重击优先于链式取消——因为按下 U 的意图很明确就是要出重击。
		#    每次成功衔接都点一次光刃爆闪：这是「这套连招接上了」的画面上唯一证据。
		if special and _buffered_heavy:
			_blade_flash_t = BLADE_FLASH
			_start_move("breaker")
			return
		if special and _buffered_shoot and meter >= SHOOT_COST:
			_blade_flash_t = BLADE_FLASH
			_start_move("shoot")
			return
		# ② 链式取消：轻斩① → 轻斩② → 重斩终结
		var nxt := String(_move["cancel"])
		if nxt != "" and _buffered_attack:
			_blade_flash_t = BLADE_FLASH
			_start_move(nxt)
			return

	if _atk_t >= swing + recovery:
		_end_move()


func _on_active_start() -> void:
	var arc := String(_move["arc"])
	if arc != "":
		emit_signal("effect", arc, _mirror_box(_move["box"]).get_center(), team)
	# 重击在判定帧向前突进一段，让「抡进来」这个动作在画面上真的成立
	var lunge := float(_move.get("lunge", 0.0))
	if lunge != 0.0:
		velocity.x = float(facing) * lunge
	if String(_move["kind"]) == "shoot":
		_fire()


func _check_melee_hit() -> void:
	# _hit_used 与 _hit_confirmed 是两件事：
	#   _hit_used      = 本次挥砍已经结算过（被挡也算），判定帧内不再重复扣血
	#   _hit_confirmed = 本次挥砍「打实了」，才开放连段取消窗口
	# 早期只用了 _hit_confirmed 一个标记，于是被格挡时判定帧内每帧都会再扣一次血。
	if _hit_used or opponent == null or opponent.state == State.DEAD:
		return
	var world_box := _mirror_box(_move["box"])
	if not world_box.intersects(opponent.body_box()):
		return
	var hit := {
		"dmg": int(_move["dmg"]),
		"hitstun": float(_move["hitstun"]),
		"knock": float(_move["knock"]),
		"lift": float(_move["lift"]),
		"invuln": float(_move["invuln"]),
		"from": global_position,
		"attacker": self,
		"guard_break": bool(_move.get("guard_break", false)),
	}
	var res: Dictionary = opponent.take_hit(hit)
	if bool(res["ignored"]):
		# 浮空上限不足（jl < 对手浮空计数）时这一挥是真的打空了，
		# 也要把 _hit_used 置位，否则判定帧内每帧都会重复判定一次。
		if bool(res.get("whiff", false)):
			_hit_used = true
		return
	_hit_used = true
	emit_signal("effect", "impact", world_box.get_center(), team)
	# 反击命中：攻方这边也点一次光刃爆闪，和受击方的白色闪白对称，
	# 这样「我读招抢到了先手」在接触点上就能看到，不用等 HUD 的飘字
	if bool(res.get("counter", false)):
		_blade_flash_t = BLADE_FLASH
	if bool(res["blocked"]):
		# 被格挡 = 这套连段到此为止：不给取消窗口，攻方必须吃完自己的后摇。
		# 完美格挡会把攻方弹得更远，这就是「防御吃时机」给防守方的回报。
		velocity.x = -float(facing) * (70.0 if bool(res["just_guard"]) else 34.0)
		return
	_hit_confirmed = true


## 翻滚闪避：消耗 20 能量，全程无敌，距离短，结束后有后摇。
## dir 是世界方向（-1 左 / +1 右）。
func _start_dodge(dir: int) -> void:
	_roll_dir = dir
	_dodge_t = DODGE_TIME
	_roll_angle = 0.0
	state = State.DODGE
	meter -= DODGE_COST
	emit_signal("meter_changed", self)
	velocity.x = float(dir) * DODGE_SPEED
	_invuln_t = maxf(_invuln_t, DODGE_TIME)     # 翻滚期间全程无敌
	# 在翻滚起点留下速度线，明确告诉对手「他闪过去了」
	emit_signal("effect", "roll", global_position + Vector2(0.0, -17.0), team)


func _fire() -> void:
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	var at := muzzle.global_position + Vector2(facing * 3.0, 0.0)
	# 伤害数据来自招式表，弹丸只负责搬运
	var hit := {
		"dmg": int(_move["dmg"]),
		"hitstun": float(_move["hitstun"]),
		"knock": float(_move["knock"]),
		"lift": float(_move["lift"]),
		"invuln": float(_move["invuln"]),
		"jl": int(_move.get("jl", 0)),     # 浮空追打上限：空中的对手也要 jl 够高才打得中
		"starter": float(_move.get("starter", 0.0)),
	}
	p.setup(self, team, facing, at, GUN_SPEED, hit)
	emit_signal("fired", p)
	emit_signal("effect", "muzzle", at, team)


func gain_meter(amount: float) -> void:
	var before := meter
	meter = clampf(meter + amount, 0.0, MAX_METER)
	if not is_equal_approx(before, meter):
		emit_signal("meter_changed", self)


# ================================================================ 受击
## hit = { dmg, hitstun, knock, lift, invuln, from, attacker }
## 返回 { ignored, blocked, taken }
##
## 连续挨打时按 combo_taken 递减硬直与伤害：
## 第 n 段硬直 = 基础硬直 × max(FLOOR, 1 - 0.15(n-1))。
## 这条衰减保证任何连段都会自然断开，受击方一定能拿回行动权。
func take_hit(hit: Dictionary) -> Dictionary:
	if state == State.DEAD or _invuln_t > 0.0:
		return {"ignored": true, "blocked": false, "taken": 0}
	var from: Vector2 = hit["from"]
	var toward := signf(from.x - position.x)
	if toward == 0.0:
		toward = float(-facing)
	var was_hurt := state == State.HURT
	var facing_hit := int(toward) == facing
	# 判定「是否在防御」时不能只看 BLOCK 状态：
	# 同一物理帧里攻击方可能先执行，防守方的 BLOCK 状态还没生效。
	# 所以这里用「防御键按住 + 完美格挡窗口」来补上这一帧的判定。
	var guarding := facing_hit and _block_held and is_on_floor() \
		and state != State.HURT and state != State.DODGE and state != State.DEAD
	var just_guard := guarding and _guard_t > 0.0
	var blocked := facing_hit and (state == State.BLOCK or just_guard)

	var raw := int(hit["dmg"])
	var guard_break := bool(hit.get("guard_break", false))
	# 反击命中（Counter Hit）：这一下打在对手的「前摇」上（state == ATTACK 且判定帧还没开）。
	# 于是「读招抢先手」有实打实的回报：伤害 +25%、硬直 +30%。
	var counter := raw > 0 and state == State.ATTACK and not _atk_started
	# 浮空追打（Juggle）：对手已经浮空中，而这一招的浮空上限 jl 不够高 → 直接打空。
	# 这条保证「挑飞之后不能无限追打」，越往后越必须换更重的招才追得下去。
	var jl := int(hit.get("jl", 0))
	if juggle > 0 and jl < juggle:
		return {"ignored": true, "blocked": false, "taken": 0, "whiff": true}

	var stage := combo_taken + 1
	# 用「上一段起手技」定下的起手递减（Starter Scaling）来算这一段；
	# 这一段自己若是连段第一段，才把它的 starter 记下来供后面几段使用——
	# 起手递减只影响后续段位，不影响起手那一击本身。
	var stun_scale := maxf(DECAY_FLOOR, 1.0 - STUN_DECAY * float(stage - 1) - _combo_starter * 0.5)
	var dmg_scale := maxf(DECAY_FLOOR, 1.0 - DMG_DECAY * float(stage - 1) - _combo_starter)
	if counter:
		stun_scale *= COUNTER_STUN_MULT
		dmg_scale *= COUNTER_DMG_MULT
	var taken := maxi(1, int(roundf(float(raw) * dmg_scale))) if raw > 0 else 0

	if just_guard:
		# 完美格挡：完全免伤，并把攻击方钉在原地 1 秒（固定硬直，不参与递减）。
		# 这一秒就是防守方拿回的、完全无风险的进攻权。
		taken = 0
		_guard_t = 0.0
		_guard_flash_t = GUARD_FX_HOLD
		_block_stun_t = GUARD_SELF_STUN
		gain_meter(GUARD_METER_BONUS)
		emit_signal("effect", "guard", global_position + Vector2(facing * 7.0, -22.0), team)
		_repel_attacker(hit.get("attacker", null), GUARD_REPEL, GUARD_ATTACKER_STUN)
	elif blocked and guard_break:
		# 破甲：直接打穿防御。伤害按比例削减但依然很痛，
		# 并附带长硬直 + 一段时间内禁止再举盾（破防）。
		# 注意顺序：上面 just_guard 分支优先，所以「完美格挡」连破甲重击也能挡下——
		# 这让「读招踩点」成为对抗重击的正解，而不是无脑按住防御。
		taken = maxi(1, int(roundf(float(raw) * GUARD_BREAK_MULT)))
		velocity.x = -toward * float(hit["knock"]) * 0.55
		_hurt_t = GUARD_BREAK_STUN
		_guard_lock_t = GUARD_LOCK_TIME
		_guard_t = 0.0
		if state != State.DEAD:
			state = State.HURT
		emit_signal("effect", "guardbreak", global_position + Vector2(0.0, -22.0), team)
	elif blocked:
		# 普通格挡：固定只扣 1 血，不分招式轻重
		taken = BLOCK_CHIP_DAMAGE
		velocity.x = -toward * BLOCK_KNOCKBACK
		_block_stun_t = BLOCK_STUN
		combo_taken = 0                # 成功格挡即打断对手的连段
		combo_display = 0
		_combo_starter = 0.0
		_combo_t = 0.0
		emit_signal("effect", "spark", global_position + Vector2(facing * 8.0, -24.0), team)
	else:
		velocity.x = -toward * float(hit["knock"])
		var lift := float(hit["lift"])
		if lift != 0.0:
			velocity.y = lift
		_hurt_t = float(hit["hitstun"]) * stun_scale
		_invuln_t = float(hit["invuln"])
		_flash_t = HIT_FLASH
		# 浮空计数（Juggle Count）：在空中继续被追打就递增；站在地上被挑飞则从 1 起算。
		# 落地时（见 _tick_timers）会清回 0，所以再次起跳不会被上一轮的浮空限制卡住。
		if not is_on_floor():
			juggle += 1
		elif lift < 0.0:
			juggle = 1
		# 这是本段连段的第一击 → 记下它的起手递减，供后面几段共用
		if not was_hurt:
			_combo_starter = float(hit.get("starter", 0.0))
		combo_taken = stage
		combo_display = (combo_display + 1) if was_hurt else 1
		_combo_t = COMBO_WINDOW
		if state != State.DEAD:
			state = State.HURT
		if counter:
			emit_signal("effect", "counter", global_position + Vector2(0.0, -32.0), team)
		emit_signal("effect", "hit", global_position + Vector2(0.0, -20.0), team)

	_apply_damage(taken)
	emit_signal("hit_landed", self, hit.get("attacker", null), taken, blocked and not just_guard,
		global_position + Vector2(0.0, -26.0))
	emit_signal("health_changed", self)
	return {"ignored": false, "blocked": blocked, "taken": taken,
		"just_guard": just_guard, "counter": counter}


## 把攻击方震开；stun > 0 时还给一段固定硬直（完美格挡的惩罚）
func _repel_attacker(attacker: Variant, power: float, stun := 0.0) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var foe := attacker as Mecha
	if foe == null or foe.state == State.DEAD:
		return
	var away := signf(foe.position.x - position.x)
	if away == 0.0:
		away = float(facing)
	foe.velocity.x = away * power
	foe.velocity.y = minf(foe.velocity.y, -45.0)
	if stun > 0.0:
		foe.force_stun(stun)


## 施加一段固定硬直（不吃连段递减），并中断当前正在进行的招式。
## 完美格挡的 1 秒惩罚用它，所以必须先把攻击状态干净地收掉。
func force_stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	_move_name = ""
	_move = {}
	_atk_t = 0.0
	_atk_started = false
	_hit_confirmed = false
	_hit_used = false
	_buffered_attack = false
	_buffered_heavy = false
	_buffered_shoot = false
	_blade_on = false
	_invuln_t = 0.0
	_hurt_t = seconds
	combo_taken = 0               # 固定硬直：不参与连段递减，也不累加连段数
	combo_display = 0
	_combo_starter = 0.0
	_combo_t = 0.0
	state = State.HURT


## 爆气脱身：受击硬直中消耗能量强行挣脱，把对手震开（受击方的反击手段）
func _do_burst() -> void:
	meter -= BURST_COST
	combo_taken = 0
	_combo_starter = 0.0
	_combo_t = 0.0
	_hurt_t = 0.0
	_block_stun_t = 0.0
	_atk_t = 0.0
	_move = {}
	_move_name = ""
	state = State.IDLE
	_invuln_t = BURST_INVULN
	velocity = Vector2(0.0, -110.0)
	emit_signal("meter_changed", self)
	emit_signal("effect", "burst", global_position + Vector2(0.0, -18.0), team)
	# 爆气震开对手：用一次零伤害命中打出硬直，这样击退不会被摩擦力立刻吃掉。
	# attacker 传 null，避免爆气方再回收一份能量。
	if opponent != null and is_instance_valid(opponent) and opponent.state != State.DEAD:
		opponent.take_hit({
			"dmg": 0, "hitstun": 0.30, "knock": BURST_KNOCKBACK, "lift": -55.0,
			"invuln": 0.0, "from": global_position, "attacker": null,
			"jl": 99,              # 爆气冲击波无视浮空上限，空中的对手也一样震得开
		})


func _apply_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		_die()


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity.x = -float(facing) * 30.0
	emit_signal("died", self)
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "rotation", 1.45, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(visual, "position:y", -3.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(visual, "modulate:a", 0.35, 0.7).set_delay(0.35)
	shield.visible = false
	blade.visible = false


# ================================================================ 动画
## 在两个姿态关键帧之间插值。姿态结构见 POSE_IDLE 上方的约定。
func _pose_mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {
		"af": lerpf(float(a["af"]), float(b["af"]), k),
		"ab": lerpf(float(a["ab"]), float(b["ab"]), k),
		"tor": lerpf(float(a["tor"]), float(b["tor"]), k),
		"tx": lerpf(float(a["tx"]), float(b["tx"]), k),
		"lf": lerpf(float(a["lf"]), float(b["lf"]), k),
		"lb": lerpf(float(a["lb"]), float(b["lb"]), k),
		"bob": lerpf(float(a["bob"]), float(b["bob"]), k),
	}


## 让关节逼近目标：limit > 0 时改用「每帧最多走这么多」的限速方式（起手缓冲用），
## 否则按系数 k 做一阶插值。
func _approach(current: float, target: float, k: float, limit: float) -> float:
	if limit > 0.0:
		return move_toward(current, target, limit)
	return lerpf(current, target, k)


func _approach_v(current: Vector2, target: Vector2, k: float, limit: float) -> Vector2:
	if limit > 0.0:
		return current.move_toward(target, limit)
	return current.lerp(target, k)


func _update_rig(delta: float) -> void:
	_anim_t += delta

	var t_leg_f := 0.0
	var t_leg_b := 0.0
	var t_arm_f := 0.10
	var t_arm_b := 0.10
	var t_torso := 0.0
	var bob := 0.0
	var torso_x := 0.0
	var body_dy := 0.0
	var shield_on := false
	var roll_rotate := false
	_charge_k = 0.0

	match state:
		State.IDLE:
			var s := sin(_anim_t * 2.6)
			bob = s * 0.9
			t_arm_f = 0.10 + s * 0.07
			t_arm_b = 0.10 - s * 0.07
			t_leg_f = -s * 0.03
			t_leg_b = s * 0.03
			t_torso = s * 0.012
		State.RUN:
			_run_phase += delta * (7.2 + absf(velocity.x) * 0.055)
			var s := sin(_run_phase * PI)
			t_leg_f = s * 0.45
			t_leg_b = -s * 0.45
			t_arm_f = 0.08 - s * 0.38
			t_arm_b = 0.08 + s * 0.38
			bob = -absf(sin(_run_phase * TAU)) * 1.3
			# 摆腿是绕髋旋转，脚会随之抬起；整体下沉一点让脚掌贴住地面
			body_dy = absf(s) * 1.5
			t_torso = 0.06
			torso_x = 1.0
		State.AIR:
			t_leg_f = 0.34
			t_leg_b = -0.26
			t_arm_f = -0.42
			t_arm_b = 0.42
			bob = -1.0
			t_torso = 0.04
		State.DODGE:
			# 翻滚：四肢收拢成球，整体绕身体中心旋转一圈（详见下方 visual 变换）
			t_leg_f = 0.95
			t_leg_b = 0.80
			t_arm_f = 1.15
			t_arm_b = 1.15
			t_torso = 0.5
			bob = 8.0
			body_dy = 3.0
			roll_rotate = true
		State.ATTACK:
			var startup := float(_move["startup"])
			var active := float(_move["active"])
			var recovery := float(_move["recovery"])
			var swing := startup + active
			if bool(_move.get("charge", false)):
				# 蓄力型重击（破甲重击）：前摇刻意不套用通用的「起手收势」，
				# 而是做成一个拖得久、看得清的蓄力动作——
				# 手臂慢慢抡到身后上方、身体后仰、前腿大步扎稳、重心下沉，
				# 判定帧才整条手臂猛地劈出并向前突进。详见设计文档 1.3.1。
				var lean := float(_move["lean"])
				if _atk_t < startup:
					var k := clampf(_atk_t / startup, 0.0, 1.0)
					_charge_k = k
					# 蓄力越到后面越紧绷：用平方让前半段慢、后半段加速到位
					t_arm_f = lerpf(0.30, float(_move["arm_from"]), k * k)
					t_arm_b = -0.35 - 0.55 * k
					t_torso = -0.32 * k
					torso_x = -5.0 * k
					t_leg_f = 0.36 * k
					t_leg_b = -0.50 * k
					bob = 3.4 * k
				elif _atk_t < swing:
					var k := clampf((_atk_t - startup) / active, 0.0, 1.0)
					t_arm_f = lerpf(float(_move["arm_from"]), float(_move["arm_to"]), k)
					t_arm_b = -0.90 + 0.55 * k
					t_torso = lerpf(-0.32, lean, k)
					torso_x = lerpf(-5.0, lean * 10.0, k)
					t_leg_f = 0.36
					t_leg_b = -0.50
					bob = lerpf(3.4, -1.6, k)
				else:
					var kr := clampf((_atk_t - swing) / recovery, 0.0, 1.0)
					t_arm_f = lerpf(float(_move["arm_to"]), 0.10, kr)
					t_arm_b = lerpf(-0.35, -0.05, kr)
					t_torso = lean * (1.0 - kr)
					torso_x = lean * 10.0 * (1.0 - kr)
					t_leg_f = lerpf(0.36, 0.26, kr)
					t_leg_b = lerpf(-0.50, -0.22, kr)
					bob = lerpf(-1.6, -0.4, kr)
			elif _move.has("rig"):
				# 其余招式：全部由 MOVES 表里的两帧关键剪影驱动（见 POSE_IDLE 上方的约定）。
				# 每招的 wind / strike 剪影都不一样，所以轻①是直刺、轻②是过肩下劈、
				# 重斩是上撩挑飞、空中斩是空中下劈、炮击是托炮后坐——一眼分得开。
				var rig: Dictionary = _move["rig"]
				var pose: Dictionary
				if _atk_t < startup:
					# 起手：从中立架势收到「蓄势」剪影，缓入缓出，让对手看得出要出什么
					pose = _pose_mix(POSE_IDLE, rig["wind"],
						smoothstep(0.0, 1.0, clampf(_atk_t / startup, 0.0, 1.0)))
				elif active > 0.0 and _atk_t < swing:
					# 判定帧：匀速挥出，时长本来就短，读起来就是「唰」的一下
					pose = _pose_mix(rig["wind"], rig["strike"],
						clampf((_atk_t - startup) / active, 0.0, 1.0))
				else:
					# 收招：从「挥出」慢慢回到中立，缓出（收得稳、不像弹回去）。
					# 判定帧为 0 的招（能量炮）没有中间那段，挥出动作在这里顺势补齐。
					pose = _pose_mix(rig["strike"], POSE_IDLE,
						smoothstep(0.0, 1.0, clampf((_atk_t - swing) / recovery, 0.0, 1.0)))
				t_arm_f = pose["af"]
				t_arm_b = pose["ab"]
				t_torso = pose["tor"]
				torso_x = pose["tx"]
				t_leg_f = pose["lf"]
				t_leg_b = pose["lb"]
				bob = pose["bob"]
		State.BLOCK:
			shield_on = true
			t_arm_f = -1.18
			t_arm_b = -0.6
			t_torso = -0.10
			t_leg_f = -0.14
			t_leg_b = 0.12
			bob = 0.6
		State.HURT:
			t_arm_f = 0.55
			t_arm_b = 0.62
			t_leg_f = -0.12
			t_leg_b = 0.24
			t_torso = -0.22
			torso_x = -1.5
			bob = -0.5
		State.DEAD:
			return

	# 关节逼近目标的速度。出招期间直接贴到关键帧曲线上——曲线自己已经是平滑的
	# （起手 smoothstep、判定帧匀速、收招 smoothstep），再叠一层一阶平滑只会拖后腿：
	# 早期所有状态共用 18.0 这个系数（≈0.30/帧），而一次挥砍关键帧在 4 帧里要跑掉
	# 3 弧度，手臂永远追不上，动作就只剩「软绵绵地挪一下」——这是攻击动画看起来
	# 没做完的主因。其余状态才继续用一阶平滑，避免站立 / 奔跑 / 受击之间硬切。
	#
	# 但起手头 2 帧要加一道缓冲：从奔跑 / 举盾 / 滞空切进出招时姿态差最大
	# （举盾切出刀，前臂要一次甩过 1.3 弧度），一帧走完就是「跳」一下。
	# 这里不去降插值系数，而是直接限制**每帧最多走多远**：
	#   · 姿态差大的切换被摊平到 2 帧，峰值速度减半，跳变消失；
	#   · 姿态差本来就小的（待机直接出刀）几乎不受影响，照样是「唰」的一下。
	# 第 3 帧起解除限制，全速直贴曲线。
	var k_rot := clampf(delta * 18.0, 0.0, 1.0)
	var rot_limit := 0.0
	var pos_limit := 0.0
	if state == State.ATTACK:
		k_rot = 1.0
		if int(roundf(_atk_t * 60.0)) <= START_BLEND_FRAMES:
			rot_limit = START_BLEND_STEP
			pos_limit = START_BLEND_SHIFT
	leg_front.rotation = _approach(leg_front.rotation, t_leg_f, k_rot, rot_limit)
	leg_back.rotation = _approach(leg_back.rotation, t_leg_b, k_rot, rot_limit)
	arm_front.rotation = _approach(arm_front.rotation, t_arm_f, k_rot, rot_limit)
	arm_back.rotation = _approach(arm_back.rotation, t_arm_b, k_rot, rot_limit)
	torso.rotation = _approach(torso.rotation, t_torso, k_rot, rot_limit)
	# 上半身整体随 torso_x / bob 移动：躯干、两条手臂、护盾一起走，双腿留在原地扎稳。
	# 只挪 Torso 是不够的——那样一前倾躯干就会从肩膀处「滑出去」，腋下裂出一道缝。
	torso.position = _approach_v(torso.position, _TORSO_BASE + Vector2(torso_x, bob), k_rot, pos_limit)
	arm_front.position = _approach_v(arm_front.position, _ARM_F_BASE + Vector2(torso_x, bob), k_rot, pos_limit)
	arm_back.position = _approach_v(arm_back.position, _ARM_B_BASE + Vector2(torso_x, bob), k_rot, pos_limit)
	shield.position = _approach_v(shield.position, _SHIELD_BASE + Vector2(torso_x, bob), k_rot, pos_limit)
	shield.visible = (shield_on or _guard_flash_t > 0.0) and state != State.DEAD \
		and _guard_lock_t <= 0.0            # 破防期间护盾是碎的，举不起来

	if roll_rotate:
		# 翻滚：绕「身体中心」而不是脚底旋转。
		# 节点旋转是绕自身原点（脚底）转的，所以这里补一个平移把旋转轴搬到腰部：
		#   p -> C + R(θ)(p - C)  等价于  rotation = θ, position = C - R(θ)C
		visual.rotation = _roll_angle
		visual.position = _ROLL_PIVOT - _ROLL_PIVOT.rotated(_roll_angle)
	else:
		visual.rotation = 0.0
		visual.position = Vector2(0.0, lerpf(visual.position.y, body_dy, clampf(delta * 12.0, 0.0, 1.0)))

	# 光刃挂在手臂末端：手臂局部「向下」方向 = +y，而刃贴图朝向 +x，故补 90°
	var hand := Vector2(0.0, 13.0).rotated(arm_front.rotation)
	blade.position = arm_front.position + hand
	blade.rotation = arm_front.rotation + PI * 0.5
	# 取消衔接 / 反击命中时强行把光刃点亮一下：爆闪正好落在两招的接缝上，
	# 「这套连招接上了」就有了画面证据，而不是只有 HUD 上跳动的数字
	var flashing := _blade_flash_t > 0.0
	blade.visible = (_blade_on or flashing) and state != State.DEAD
	# 判定帧结束后光刃随收招淡出（BLADE_LINGER 那一段），把挥砍弧线补完整
	var fade := 1.0
	if state == State.ATTACK and _blade_on:
		var sw := float(_move["startup"]) + float(_move["active"])
		if _atk_t > sw:
			fade = clampf(1.0 - (_atk_t - sw) / (float(_move["recovery"]) * BLADE_LINGER), 0.0, 1.0)
			# 淡出的同时往回收一点，读起来就是能量散掉而不是被关掉
			fade = fade * fade
	# 蓄力时光刃越攒越亮、越攒越大，让对手远远就能看出「这一下很重」
	var glow := 0.85 + 0.15 * sin(_anim_t * 40.0)
	if _charge_k > 0.0:
		glow = minf(1.6, glow + 1.0 * _charge_k)
		blade.scale = Vector2.ONE * (1.0 + 0.45 * _charge_k)
	else:
		blade.scale = Vector2.ONE
	if flashing:
		glow = maxf(glow, 2.6)
		blade.scale = Vector2.ONE * 1.35
	blade.modulate = Color(glow, glow, glow, fade)

	# 受击闪白 / 完美格挡的护盾高亮
	var bright := 2.2 if _flash_t > 0.0 else 1.0
	if _guard_flash_t > 0.0:
		bright = 1.9
	visual.modulate = Color(bright, bright, bright, 1.0)
