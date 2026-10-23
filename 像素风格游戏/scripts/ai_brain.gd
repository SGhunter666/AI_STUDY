class_name AiBrain
extends RefCounted
## 机甲 AI：一个「想一点、动一点」的轻量行为树。
##
## 目标不是把玩家打爆，而是让 Demo 单人就能试玩，且打得像样：
##   · 近身压迫，进入斩击距离就出刀（连段由 Mecha 的取消机制自动衔接）
##   · 对面前摇就举盾读招，看到来弹也举盾
##   · 距离远且能量够就放炮，中距离用冲刺拉近
##
## update() 返回与人类玩家完全相同的意图字典，
## 因此 Mecha 无需区分对手是人还是电脑。

const MELEE_RANGE := 36.0        # 进入这个距离就出斩
const CLOSE_RANGE := 100.0       # 超过这个距离用冲刺拉近
const GUN_RANGE := 145.0
const THREAT_FRONT := 130.0      # 正面来弹的预警距离
const THREAT_HEIGHT := 20.0
const REACT_DIST := 46.0         # 这个距离内读对手前摇
const DODGE_REACT_RANGE := 70.0  # 这个距离内才考虑翻滚闪躲
const BREAK_RANGE := 40.0        # 这个距离内才用破甲重击

var _t := 0.0
var _think_at := 0.0
## 每次「思考」后固定下来的决策，避免每帧抖动
var _move_dir := 0
var _want_attack := false
var _want_jump := false
var _want_roll := 0              ## 中距离向前翻滚抢距离（世界方向）
var _want_shoot := false
var _want_burst := false
var _want_dodge := 0
var _want_break := false
var _block_until := 0.0
var _pressure_until := 0.0      ## 连段收招后的歇手时间，避免无限压制
var _jump_at := 0.0
var _last_seen_move := ""
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func update(delta: float, me: Mecha, foe: Mecha) -> Dictionary:
	_t += delta
	var tune := GameConfig.tuning()
	var dx := foe.position.x - me.position.x
	var dist := absf(dx)
	var toward := 1 if dx > 0.0 else -1

	# AI 被打到多段时用爆气脱身挣脱压制（和玩家用同一套机制）
	if me.state == Mecha.State.HURT and me.combo_taken >= 3 \
			and me.meter >= Mecha.BURST_COST and _rng.randf() < 0.55:
		_want_burst = true

	# 翻滚闪避：对手起手且自己能量够 → 有几率滚开（能量贵，不能乱用）
	if me.can_act() and me.meter >= Mecha.DODGE_COST and _rng.randf() < 0.35:
		if _foe_winding_up(me, foe, dist) and dist < DODGE_REACT_RANGE:
			_want_dodge = -toward
		else:
			_want_dodge = 0
	else:
		_want_dodge = 0

	if _t >= _think_at:
		var close := dist < CLOSE_RANGE
		# 近身时思考更频繁，出招/防御才跟得上；难度会整体加快或放慢
		_think_at = _t + _rng.randf_range(0.09, 0.20 if close else 0.34) * float(tune["think"])

		# 一套连段打完（重斩收招）后主动歇手，把节奏还给对手
		if me.last_move == "heavy" and me.last_move != _last_seen_move:
			_pressure_until = _t + _rng.randf_range(0.32, 0.58)
		_last_seen_move = me.last_move

		# 读招防御带失误率，难度决定失误多少
		var threat := _incoming_fire(me) or (_foe_winding_up(me, foe, dist)
			and _rng.randf() < float(tune["block"]))
		if threat:
			_move_dir = 0
			_block_until = _t + _rng.randf_range(0.20, 0.40)
		else:
			if dist > MELEE_RANGE:
				_move_dir = toward
			elif dist < 20.0 and _rng.randf() < 0.35:
				_move_dir = -toward            # 贴太近时退半步重新起手
			else:
				_move_dir = 0

			# 中距离用翻滚抢距离（能量够才敢用）
			_want_roll = toward if (dist > MELEE_RANGE + 26.0 and dist < CLOSE_RANGE
				and me.meter >= Mecha.DODGE_COST and _rng.randf() < 0.3) else 0

			# 远距离且能量充足时用炮击压制
			_want_shoot = dist > GUN_RANGE and me.can_shoot() and _rng.randf() < 0.5

			if me.is_on_floor() and dist > 70.0 and _t >= _jump_at and _rng.randf() < 0.14:
				_jump_at = _t + _rng.randf_range(1.4, 3.0)
				_want_jump = true

		# 出刀意愿：进入斩击距离就出手，但连段收招后要歇手，且难度决定出手率
		_want_attack = dist < MELEE_RANGE and _t >= _pressure_until \
			and _rng.randf() < float(tune["attack"])

	# 破甲重击：对手在举盾时用，这是拆龟缩的正解。
	# 但前后摇极大，所以只在「对手确实在防御」且距离合适时才敢用。
	_want_break = (foe.state == Mecha.State.BLOCK and dist < BREAK_RANGE
		and _rng.randf() < float(tune["attack"]) * 0.55)

	var jump := _want_jump
	var burst := _want_burst
	# 读招闪躲优先：对手起手时往后滚；否则才是向前滚抢距离
	var dodge := _want_dodge if _want_dodge != 0 else _want_roll
	var use_break := _want_break
	_want_jump = false
	_want_roll = 0
	_want_burst = false
	_want_break = false
	return {
		# 注意：这里不能再用 is_attack_ready() / can_shoot() 把「想不想出招」过滤掉。
		# Mecha 的输入缓冲（连段取消、必杀取消）靠的就是「出招途中按键仍然为真」，
		# 一旦在招式进行中把意图压成 false，AI 就永远接不上连段。
		# 能不能真正出招由 Mecha._advance_state 的 _can_act() 兜底。
		"move": _move_dir,
		"jump": jump,
		"attack": _want_attack,
		"heavy": use_break,
		"shoot": _want_shoot,
		"burst": burst,
		"block": _t < _block_until,
		"dodge": dodge,
	}


## 对手正在出招（读前摇防御）
func _foe_winding_up(me: Mecha, foe: Mecha, dist: float) -> bool:
	if dist > REACT_DIST or foe.state != Mecha.State.ATTACK:
		return false
	return true


## 是否有来自正面的敌方弹丸
func _incoming_fire(me: Mecha) -> bool:
	for node: Node in me.get_tree().get_nodes_in_group("projectile"):
		var p := node as Projectile
		if p == null or p.team == me.team:
			continue
		var d: Vector2 = p.global_position - me.global_position
		if absf(d.y) > THREAT_HEIGHT or absf(d.x) > THREAT_FRONT:
			continue
		if signf(d.x) == float(me.facing) and p.direction == -me.facing:
			return true
	return false
