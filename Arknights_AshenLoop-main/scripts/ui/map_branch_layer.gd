class_name MapBranchLayer
extends Control

var map_nodes: Array[MapNodeModel] = []
var node_buttons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_branch_data(nodes: Array[MapNodeModel], buttons: Dictionary) -> void:
	map_nodes = nodes
	node_buttons = buttons
	queue_redraw()

func _draw() -> void:
	if map_nodes.is_empty() or node_buttons.is_empty():
		return
	var centers: Dictionary = {}
	for node_id in node_buttons.keys():
		var button: Control = node_buttons[node_id] as Control
		if button == null or not is_instance_valid(button):
			continue
		centers[node_id] = _button_center(button)
	for node in map_nodes:
		if node == null:
			continue
		if not centers.has(node.id):
			continue
		for next_id in node.next_ids:
			if not centers.has(next_id):
				continue
			_draw_branch(
				centers[node.id] as Vector2,
				centers[next_id] as Vector2,
				_branch_color(node, next_id)
			)

func _button_center(button: Control) -> Vector2:
	var global_rect: Rect2 = button.get_global_rect()
	var center: Vector2 = global_rect.position + global_rect.size * 0.5
	return get_global_transform_with_canvas().affine_inverse() * center

func _draw_branch(start: Vector2, finish: Vector2, tint: Color) -> void:
	var from_point: Vector2 = start + Vector2(0, 26)
	var to_point: Vector2 = finish - Vector2(0, 26)
	var mid_y: float = lerp(from_point.y, to_point.y, 0.5)
	var points: Array[Vector2] = [
		from_point,
		Vector2(from_point.x, mid_y),
		Vector2(to_point.x, mid_y),
		to_point
	]
	for segment_index in range(points.size() - 1):
		draw_line(points[segment_index], points[segment_index + 1], tint.darkened(0.28), 7.0, true)
		draw_line(points[segment_index], points[segment_index + 1], tint, 3.2, true)

func _branch_color(node: MapNodeModel, next_id: String) -> Color:
	var source_completed: bool = node.completed
	var source_reachable: bool = RunManager.is_node_reachable(node.id)
	var next_reachable: bool = RunManager.is_node_reachable(next_id)
	if source_completed:
		return Color(0.88, 0.78, 0.58, 0.92)
	if source_reachable or next_reachable:
		return Color(0.96, 0.90, 0.74, 0.78)
	return Color(0.50, 0.40, 0.26, 0.30)
