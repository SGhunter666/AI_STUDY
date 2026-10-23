class_name FxLayer
extends Node2D
## 特效层：生成一次性像素特效（炮口火光、命中爆炸、弹丸、盾牌火星）。
##
## 所有特效都是即用即弃的 Sprite2D + Tween，不做对象池——
## 这个 Demo 的瞬时特效数量很少，保持代码直白比省几个对象更重要。

const TEX := {
	"muzzle": [
		preload("res://assets/fx/blue_muzzle.png"),
		preload("res://assets/fx/red_muzzle.png"),
	],
	"hit": [
		preload("res://assets/fx/blue_hit.png"),
		preload("res://assets/fx/red_hit.png"),
	],
	"spark": [
		preload("res://assets/fx/blue_spark.png"),
		preload("res://assets/fx/red_spark.png"),
	],
	"slash_a": [
		preload("res://assets/fx/blue_slash_a.png"),
		preload("res://assets/fx/red_slash_a.png"),
	],
	"slash_b": [
		preload("res://assets/fx/blue_slash_b.png"),
		preload("res://assets/fx/red_slash_b.png"),
	],
	"burst": [
		preload("res://assets/fx/blue_burst.png"),
		preload("res://assets/fx/red_burst.png"),
	],
	"guard": [
		# 完美格挡用共用的金白贴图，不走阵营配色
		preload("res://assets/fx/guard.png"),
		preload("res://assets/fx/guard.png"),
	],
	"roll": [
		preload("res://assets/fx/blue_roll.png"),
		preload("res://assets/fx/red_roll.png"),
	],
	"charge": [
		preload("res://assets/fx/blue_charge.png"),
		preload("res://assets/fx/red_charge.png"),
	],
	"shatter": [
		preload("res://assets/fx/blue_shatter.png"),
		preload("res://assets/fx/red_shatter.png"),
	],
	"slash_c": [
		preload("res://assets/fx/blue_slash_c.png"),
		preload("res://assets/fx/red_slash_c.png"),
	],
}


## 生成一个「炸开」特效：放大 + 淡出，使用叠加混合
func burst(kind: String, at: Vector2, team: int, life := 0.18, grow := 1.9) -> void:
	if not TEX.has(kind):
		return
	var s := Sprite2D.new()
	s.texture = TEX[kind][clampi(team, 0, 1)]
	s.position = at
	s.z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(grow, grow), life)
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.chain().tween_callback(s.queue_free)


## 生成一个随时间上下浮动的命中数字（不做字体素材，直接用 Label）
func floating_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1))
	l.add_theme_constant_override("outline_size", 2)
	l.position = at
	l.z_index = 20
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 10.0, 0.45)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.12)
	tw.chain().tween_callback(l.queue_free)
