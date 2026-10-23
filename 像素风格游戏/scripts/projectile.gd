class_name Projectile
extends Area2D
## 能量炮：直线飞行，命中机甲或地形后消失并通报主场景。
##
## 伤害数据由发射者（Mecha 的招式表）打包传入，弹丸本身
## 不含任何数值配置，只负责位移、命中检测与信号转发。

signal impact(at: Vector2, team: int)       ## 击中地形
signal struck(at: Vector2, team: int, blocked: bool)   ## 击中机甲

const LIFETIME := 1.6
const TEX := [
	preload("res://assets/fx/blue_bullet.png"),
	preload("res://assets/fx/red_bullet.png"),
]

var team := 0
var direction := 1          ## 1 = 向右，-1 = 向左
var speed := 260.0
var shooter: Node = null

var _spawn_pos := Vector2.ZERO
var _hit := {}

@onready var sprite: Sprite2D = $Sprite


func setup(p_shooter: Node, p_team: int, p_dir: int, p_pos: Vector2,
		p_speed: float, p_hit: Dictionary) -> void:
	shooter = p_shooter
	team = p_team
	direction = p_dir
	speed = p_speed
	_spawn_pos = p_pos
	_hit = p_hit


func _ready() -> void:
	add_to_group("projectile")
	global_position = _spawn_pos
	sprite.texture = TEX[clampi(team, 0, 1)]
	sprite.scale.x = float(direction)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	if position.x < -12.0 or position.x > 332.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body is Mecha:
		var hit := _hit.duplicate()
		hit["from"] = _spawn_pos
		hit["attacker"] = shooter
		var res: Dictionary = (body as Mecha).take_hit(hit)
		if not bool(res["ignored"]):
			emit_signal("struck", global_position, team, bool(res["blocked"]))
	else:
		emit_signal("impact", global_position, team)
	queue_free()
