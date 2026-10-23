class_name BattleAimView
extends Node

# 战斗瞄准视觉层：负责瞄准线（Line2D）与准星（Panel）的创建、样式与几何换算。
# 瞄准状态（选中卡牌、目标判定）仍由 battle_scene_v2 持有，本类只负责渲染。
# 注意：瞄准节点挂在 ui_root 下而非自身，保持与旧实现一致的 z_index 兄弟排序。

var aim_line: Line2D
var aim_reticle: Panel

func setup(ui_root: Control) -> void:
	if aim_line == null:
		aim_line = Line2D.new()
		aim_line.name = "AimLine"
		aim_line.visible = false
		aim_line.z_index = 720
		aim_line.width = 6.0
		aim_line.default_color = Color(1.0, 0.88, 0.58, 0.94)
		aim_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		aim_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		aim_line.joint_mode = Line2D.LINE_JOINT_ROUND
		ui_root.add_child(aim_line)
	if aim_reticle == null:
		aim_reticle = Panel.new()
		aim_reticle.name = "AimReticle"
		aim_reticle.visible = false
		aim_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aim_reticle.custom_minimum_size = Vector2(22, 22)
		aim_reticle.z_index = 721
		ui_root.add_child(aim_reticle)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.94, 0.76, 0.24)
		style.corner_radius_top_left = 99
		style.corner_radius_top_right = 99
		style.corner_radius_bottom_right = 99
		style.corner_radius_bottom_left = 99
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.92, 0.70, 0.94)
		style.shadow_color = Color(1.0, 0.84, 0.42, 0.24)
		style.shadow_size = 12
		aim_reticle.add_theme_stylebox_override("panel", style)

# 显示瞄准线：坐标传入全局坐标，内部换算为 ui_root 本地坐标
func show_aim(start_global: Vector2, end_global: Vector2, ui_root: Control) -> void:
	if aim_line == null or aim_reticle == null or ui_root == null:
		return
	var start_local: Vector2 = _global_to_local(start_global, ui_root)
	var end_local: Vector2 = _global_to_local(end_global, ui_root)
	aim_line.visible = true
	aim_reticle.visible = true
	aim_line.points = PackedVector2Array([start_local, end_local])
	aim_reticle.position = end_local - aim_reticle.custom_minimum_size * 0.5

func hide_aim() -> void:
	if aim_line != null:
		aim_line.visible = false
	if aim_reticle != null:
		aim_reticle.visible = false

# Godot 4 的 Control 没有 to_local()（仅 Node2D 有），用全局变换逆矩阵转换
func _global_to_local(point: Vector2, ui_root: Control) -> Vector2:
	return ui_root.get_global_transform().affine_inverse() * point
