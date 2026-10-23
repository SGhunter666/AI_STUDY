extends Node2D
## 主场景：编排整场对战（准备 → 开战 → 回合结算 → 决出胜负）。
##
## 职责边界：
##   Mecha      = 角色逻辑（招式帧数据、命中判定、自己不知道对手是人还是 AI）
##   Projectile = 弹丸搬运（伤害数据由发射者的招式表打包传入）
##   Main       = 把各模块的信号翻译成画面表现：特效、顿帧、连击数、回合与胜负

const MECHA_SCENE := preload("res://scenes/mecha.tscn")

const GROUND_Y := 150.0
const SPAWN_L := 96.0
const SPAWN_R := 224.0
const ARENA_MIN := 18.0
const ARENA_MAX := 302.0
const READY_TIME := 1.15
const FIGHT_BANNER := 0.7
const ROUND_DELAY := 1.9         # 回合结束到下一回合的间隔
const OVER_DELAY := 1.0
const COMBO_HIDE := 1.1          # 连击数显示时长

enum Phase { READY, FIGHT, ROUND_END, MATCH_END }

@onready var world: Node2D = $WorldView/SubViewport/World
@onready var mechas: Node2D = $WorldView/SubViewport/World/Mechas
@onready var projectiles: Node2D = $WorldView/SubViewport/World/Projectiles
@onready var fx: FxLayer = $WorldView/SubViewport/World/FX
@onready var hud: GameHud = $HUD

var phase: Phase = Phase.READY
var phase_t := 0.0
var p1: Mecha
var p2: Mecha
var p2_ai := true
var rounds_to_win := 2

var round_wins := [0, 0]
var round_index := 1
var _banner_t := 0.0
var _over_shown := false
var _result := ""
var _combo_hide := [0.0, 0.0]


func _ready() -> void:
	UiFont.apply(self)
	InputSetup.ensure()
	Engine.time_scale = 1.0
	p2_ai = GameConfig.p2_ai
	rounds_to_win = GameConfig.rounds_to_win
	_spawn_mechas()
	_apply_names()
	hud.set_hints(hint_left(), hint_right(), global_hint())
	start_match()


# ================================================================ 对战流程
func start_match() -> void:
	round_wins = [0, 0]
	round_index = 1
	hud.set_rounds(0, 0, rounds_to_win)
	start_round()


func start_round() -> void:
	phase = Phase.READY
	phase_t = READY_TIME
	_over_shown = false
	_combo_hide = [0.0, 0.0]
	hud.clear_combo(0)
	hud.clear_combo(1)
	for p: Node in projectiles.get_children():
		p.queue_free()
	p1.reset_for_round(Vector2(SPAWN_L, GROUND_Y))
	p2.reset_for_round(Vector2(SPAWN_R, GROUND_Y))
	_set_frozen(true)
	_set_message("第 %d 回合" % round_index)


func _process(delta: float) -> void:
	for i in 2:
		if _combo_hide[i] > 0.0:
			_combo_hide[i] -= delta
			if _combo_hide[i] <= 0.0:
				hud.clear_combo(i)
	_update_burst_prompt()

	match phase:
		Phase.READY:
			phase_t -= delta
			if phase_t <= 0.0:
				phase = Phase.FIGHT
				_banner_t = FIGHT_BANNER
				_set_frozen(false)
				_set_message("开始！")
		Phase.FIGHT:
			if _banner_t > 0.0:
				_banner_t -= delta
				if _banner_t <= 0.0:
					_set_message("")
		Phase.ROUND_END:
			phase_t -= delta
			if phase_t <= 0.0:
				round_index += 1
				start_round()
		Phase.MATCH_END:
			phase_t -= delta
			if phase_t <= 0.0 and not _over_shown:
				_over_shown = true
				_set_message("%s\n按 R 重新开始" % _result)


## 全局热键用 _input 而非 _unhandled_input：战场位于 SubViewportContainer 中，
## _input 能保证事件一定送达，不受 GUI 层是否消费事件的影响。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("back_to_menu"):
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	elif event.is_action_pressed("toggle_ai"):
		p2_ai = not p2_ai
		p2.is_ai = p2_ai
		_apply_names()


func _spawn_mechas() -> void:
	p1 = _make_mecha(0, "p1_", SPAWN_L, false)
	p2 = _make_mecha(1, "p2_", SPAWN_R, p2_ai)
	p1.opponent = p2
	p2.opponent = p1


func _make_mecha(p_team: int, p_prefix: String, x: float, ai: bool) -> Mecha:
	var m := MECHA_SCENE.instantiate() as Mecha
	m.team = p_team
	m.input_prefix = p_prefix
	m.is_ai = ai
	m.arena_min_x = ARENA_MIN
	m.arena_max_x = ARENA_MAX
	m.position = Vector2(x, GROUND_Y)
	mechas.add_child(m)
	m.fired.connect(_on_fired)
	m.effect.connect(_on_effect)
	m.hit_landed.connect(_on_hit_landed)
	m.health_changed.connect(_on_health_changed)
	m.meter_changed.connect(_on_meter_changed)
	m.died.connect(_on_died)
	return m


func _apply_names() -> void:
	hud.set_names("蓝方 · 玩家 1", "红方 · " + ("电脑" if p2_ai else "玩家 2"))


func _set_frozen(value: bool) -> void:
	for m: Mecha in [p1, p2]:
		if m != null:
			m.frozen = value


## 挨打且能量够时提示「可以爆气」，让玩家在受压制的那一刻就知道自己还有手段
func _update_burst_prompt() -> void:
	for m: Mecha in [p1, p2]:
		if m == null:
			continue
		var show := (not m.is_ai) and m.state == Mecha.State.HURT \
			and m.meter >= Mecha.BURST_COST and not m.frozen
		hud.set_burst_prompt(m.team, show)


func _set_message(text: String) -> void:
	hud.set_message(text)


func team_name(team: int) -> String:
	return "蓝方" if team == 0 else "红方"


func hint_left() -> String:
	return "A/D 移动   W 跳跃   J 斩击   U 重击   K 防御   L 炮击"


func hint_right() -> String:
	return "←/→ 移动   ↑ 跳跃   . 斩击   O 重击   / 防御   , 炮击"


func global_hint() -> String:
	# Shift 是共享键，所以只给蓝方；红方用自己的 N —— 否则一按两边一起滚。
	# 开头那句是连招系统唯一的教学：新玩家最需要知道的就是「命中后能取消成必杀技」。
	# 措辞刻意避开了系统字体缺字形的「杀」字，否则会渲染成豆腐块。
	return "连招：斩击命中后接 U / L 出重击 / 炮击   重击可破防，1.3 秒举不起盾   " \
		+ "翻滚 蓝方 Shift · 红方 N   ; / M 爆气   R 重开   ESC 主菜单"


# ================================================================ 信号编排
func _on_fired(p: Node2D) -> void:
	projectiles.add_child(p)
	var proj := p as Projectile
	proj.impact.connect(_on_impact)


func _on_impact(at: Vector2, team: int) -> void:
	fx.burst("spark", at, team, 0.16, 1.2)


func _on_effect(kind: String, at: Vector2, team: int) -> void:
	match kind:
		"muzzle":
			fx.burst("muzzle", at, team, 0.1, 1.6)
		"slash_a":
			fx.burst(kind, at, team, 0.13, 1.25)
		"slash_b":
			fx.burst(kind, at, team, 0.2, 1.5)
		"burst":
			fx.burst(kind, at, team, 0.34, 2.3)
			fx.burst("hit", at, team, 0.26, 2.6)
		"guard":
			# 完美格挡：金白菱形闪光 + 白色冲击 + 文字提示。
			# 给得比普通格挡的火花大得多，因为这是最值得玩家立刻看到的事件。
			fx.burst(kind, at, team, 0.32, 2.2)
			fx.burst("hit", at, team, 0.18, 2.6)
			fx.floating_text(at + Vector2(0.0, -30.0), "完美格挡", Color(1.0, 0.86, 0.32))
		"roll":
			fx.burst(kind, at, team, 0.24, 1.5)
		"charge":
			# 蓄力粒子：尺寸刻意收小、寿命也短，否则几层叠加会糊成一大团，
			# 把「抡刀」这个真正要传达的动作给盖住。
			fx.burst(kind, at, team, 0.14, 0.7)
		"guardbreak":
			# 破防：护盾碎裂 + 大命中爆炸 + 文字提示，和普通格挡彻底区分开
			fx.burst("shatter", at, team, 0.34, 2.0)
			fx.burst("hit", at, team, 0.24, 2.6)
			fx.floating_text(at + Vector2(0.0, -30.0), "破防！", Color(1.0, 0.52, 0.28))
		"counter":
			# 反击命中（Counter Hit）：打在对手前摇上。红色文字让它和普通命中一眼分开，
			# 因为这个瞬间值得玩家立刻意识到「我刚才读招读对了」。
			# 火花刻意收小、文字再往上抬一截——命中爆炸本来就大，别把字糊掉。
			fx.burst("spark", at, team, 0.18, 1.6)
			fx.floating_text(at + Vector2(-8.0, -12.0), "反击命中!", Color("#ff5a72"))
		"hit":
			fx.burst("hit", at, team, 0.22, 2.2)
		"spark":
			fx.burst("spark", at, team, 0.16, 1.4)
		"impact":
			fx.burst("spark", at, team, 0.14, 1.1)


func _on_hit_landed(victim: Mecha, attacker: Mecha, taken: int, blocked: bool, at: Vector2) -> void:
	# 能量收支：攻击方拿得多，被击方也拿一点，保证劣势方有爆气翻盘的手段
	victim.gain_meter(Mecha.METER_TAKE_BLOCKED if blocked else Mecha.METER_TAKE)

	var text := "格挡 -%d" % taken if blocked else "-%d" % taken
	if taken > 0:
		fx.floating_text(at + Vector2(-10.0, -8.0), text,
			Color("#9ad8ff") if blocked else Color("#ffd166"))
	_hitstop(0.035 if blocked else 0.07)

	if attacker == null:
		return
	attacker.gain_meter(Mecha.METER_DEAL_BLOCKED if blocked else Mecha.METER_DEAL)
	if blocked:
		# 被格挡 = 连段被打断，攻击方要吃完自己的后摇
		_combo_hide[attacker.team] = 0.0
		hud.clear_combo(attacker.team)
		return
	# 连段数只在对手一直站不起来时累加，站起来就归零
	if victim.combo_display >= 2:
		hud.show_combo(attacker.team, victim.combo_display)
		_combo_hide[attacker.team] = COMBO_HIDE
	# 浮空追打：对手已经在空中还被打中，说明这一招的浮空上限够高。
	# 显示出来玩家才看得懂「为什么这一下能追到、那一下追不到」。
	if victim.juggle >= 2:
		fx.floating_text(at + Vector2(13.0, -4.0), "追打 x%d" % victim.juggle, Color("#c9a0ff"))


func _on_health_changed(m: Mecha) -> void:
	hud.refresh(m.team, m.hp)


func _on_meter_changed(m: Mecha) -> void:
	hud.set_meter(m.team, m.meter)


func _on_died(loser: Mecha) -> void:
	if phase == Phase.ROUND_END or phase == Phase.MATCH_END:
		return
	var winner := 1 - loser.team
	round_wins[winner] += 1
	_set_frozen(true)
	Engine.time_scale = 1.0
	for p: Node in projectiles.get_children():
		p.queue_free()
	fx.burst("hit", loser.global_position + Vector2(0.0, -18.0), loser.team, 0.5, 3.4)
	hud.set_rounds(round_wins[0], round_wins[1], rounds_to_win)
	hud.clear_combo(0)
	hud.clear_combo(1)

	if round_wins[winner] >= rounds_to_win:
		phase = Phase.MATCH_END
		phase_t = OVER_DELAY
		_result = "%s 获胜 %d : %d" % [team_name(winner), round_wins[winner], round_wins[1 - winner]]
		_set_message(_result)
	else:
		phase = Phase.ROUND_END
		phase_t = ROUND_DELAY
		_result = "%s 拿下本回合" % team_name(winner)
		_set_message(_result)


## 命中顿帧：短时间拉低时间缩放，让打击更有分量。
## 注意必须在结束后无条件恢复，否则终局一击会把整场对战留在慢动作里。
func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
