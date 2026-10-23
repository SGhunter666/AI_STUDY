class_name MapGenerator
extends RefCounted

## Slay-the-Spire style map: 15 rows, 7 lanes
## Row 0: battle (entry)
## Row 1-5: mixed (battle, event, elite early avoidance)
## Row 6: guaranteed event or shop
## Row 7-8: mid-floor mixed (elite allowed)
## Row 9: rest (mandatory rest before harder section)
## Row 10-12: late mixed (harder, elite heavy)
## Row 13: rest/shop (pre-boss recovery)
## Row 14: boss

const FLOOR_RULES := {
	1: {"rows": 15, "lanes": 7, "min_nodes": 2, "max_nodes": 4},
	2: {"rows": 15, "lanes": 7, "min_nodes": 2, "max_nodes": 4},
	3: {"rows": 15, "lanes": 7, "min_nodes": 3, "max_nodes": 4},
	4: {"rows": 8, "lanes": 5, "min_nodes": 2, "max_nodes": 3}
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# 本层是否减少事件节点（由 RunManager 的 next_floor_fewer_events flag 驱动）
var fewer_events_this_floor: bool = false

func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value

func generate_floor(floor_index: int, fewer_events: bool = false) -> Array[MapNodeModel]:
	fewer_events_this_floor = fewer_events
	var config: Dictionary = FLOOR_RULES.get(floor_index, FLOOR_RULES[1])
	var row_count: int = int(config.get("rows", 15))
	var lane_count: int = int(config.get("lanes", 7))
	var min_nodes: int = int(config.get("min_nodes", 2))
	var max_nodes: int = int(config.get("max_nodes", 4))
	var nodes: Array[MapNodeModel] = []
	var rows: Array = []
	var battle_generation_state: Dictionary = {
		"battle_count": 0,
		"test_counts": {},
		"recent_primary_tests": []
	}
	var flat_index: int = 0
	for row_index in range(row_count):
		var row_nodes: Array = []
		var lane_slots: Array[int] = _lane_slots_for_row(row_index, row_count, lane_count, min_nodes, max_nodes)
		var row_types: Array = _generate_row_types(floor_index, row_index, row_count, lane_slots.size())
		for lane_index in range(row_types.size()):
			var node: MapNodeModel = MapNodeModel.new()
			node.floor_index = floor_index
			node.index = flat_index
			node.row = row_index
			node.lane = lane_slots[lane_index]
			node.node_type = String(row_types[lane_index])
			node.id = "f%s_r%s_l%s" % [floor_index, row_index, node.lane]
			node.metadata = Util.generate_node_metadata(floor_index, node.node_type, flat_index, rng, battle_generation_state)
			row_nodes.append(node)
			nodes.append(node)
			flat_index += 1
		rows.append(row_nodes)
	for row_index in range(rows.size() - 1):
		var current_row: Array = rows[row_index]
		var next_row: Array = rows[row_index + 1]
		for node in current_row:
			node.next_ids = _build_links(node, next_row)
		_ensure_incoming_links(current_row, next_row)
	return nodes

func _lane_slots_for_row(row_index: int, row_count: int, lane_count: int, min_nodes: int, max_nodes: int) -> Array[int]:
	# Boss row: single center node
	if row_index == row_count - 1:
		return [int(floor(float(lane_count - 1) * 0.5))]
	var node_count: int = rng.randi_range(min_nodes, max_nodes)
	# First row: 2-4 spread entries
	if row_index == 0:
		node_count = max(2, min(node_count, 4))
	# Pre-boss row: 2-3 nodes funneling toward boss
	if row_index == row_count - 2:
		node_count = max(2, min(node_count, 3))
	node_count = min(node_count, lane_count)
	var lane_candidates: Array[int] = []
	for lane_index in range(lane_count):
		lane_candidates.append(lane_index)
	lane_candidates.shuffle()
	var picked: Array[int] = []
	while picked.size() < node_count and not lane_candidates.is_empty():
		picked.append(lane_candidates.pop_front())
	picked.sort()
	return picked

func _generate_row_types(floor_index: int, row_index: int, row_count: int, lane_count: int) -> Array[String]:
	if row_index == row_count - 1:
		var boss_row: Array[String] = []
		boss_row.append("boss")
		return boss_row
	var pool: Array = _pool_for_row(floor_index, row_index, row_count)
	var row_types: Array[String] = []
	for _lane_index in range(lane_count):
		row_types.append(String(pool[rng.randi_range(0, pool.size() - 1)]))
	_ensure_row_variety(row_types, pool)
	return row_types

func _pool_for_row(floor_index: int, row_index: int, row_count: int) -> Array[String]:
	var pool: Array[String] = _pool_for_row_raw(floor_index, row_index, row_count)
	_apply_fewer_events(pool)
	return pool

func _pool_for_row_raw(floor_index: int, row_index: int, row_count: int) -> Array[String]:
	var pool: Array[String] = []

	# Floor 4 (hidden floor) uses compact layout
	if floor_index == 4:
		return _pool_for_hidden_floor(row_index, row_count)

	# === Slay the Spire style row assignments ===

	# Row 0: always battle (entry encounters)
	if row_index == 0:
		pool.assign(["battle", "battle", "battle"])
		return pool

	# Row 1: mostly battle, some events
	if row_index == 1:
		pool.assign(["battle", "battle", "event"])
		return pool

	# Row 2-4: early mixed - battle heavy, events, first elite chance
	if row_index >= 2 and row_index <= 4:
		pool.assign(["battle", "battle", "event", "event"])
		if floor_index >= 2:
			pool.append("elite")
		if row_index >= 3:
			pool.append("rest")
		return pool

	# Row 5: mid-early transition - shop/event guaranteed row
	if row_index == 5:
		pool.assign(["event", "shop", "battle", "rest"])
		return pool

	# Row 6-8: mid-floor mixed
	if row_index >= 6 and row_index <= 8:
		pool.assign(["battle", "event", "elite", "rest"])
		if floor_index >= 2:
			pool.append("shop")
		if floor_index >= 3:
			pool.append("story")
		return pool

	# Row 9: guaranteed rest row (like StS campfire before hard section)
	if row_index == 9:
		pool.assign(["rest", "rest", "rest", "event"])
		return pool

	# Row 10-11: late mixed - harder encounters, elites
	if row_index >= 10 and row_index <= 11:
		pool.assign(["battle", "elite", "event", "shop"])
		if floor_index >= 2:
			pool.append("elite")
		return pool

	# Row 12: late transition
	if row_index == 12:
		pool.assign(["battle", "event", "shop", "story"])
		return pool

	# Row 13 (pre-boss): rest/shop recovery
	if row_index == row_count - 2:
		pool.assign(["rest", "rest", "shop", "event"])
		return pool

	# Fallback
	pool.assign(["battle", "event"])
	return pool

# next_floor_fewer_events：本层事件节点概率下降（有 2 个以上事件/剧情位的行才削减，保留保证结构）
func _apply_fewer_events(pool: Array[String]) -> void:
	if not fewer_events_this_floor:
		return
	var event_count: int = 0
	for entry in pool:
		if String(entry) == "event" or String(entry) == "story":
			event_count += 1
	if event_count < 2:
		return
	for i in range(pool.size() - 1, -1, -1):
		if String(pool[i]) == "event":
			pool[i] = "battle"
			return
	pool[pool.size() - 1] = "battle"

func _pool_for_hidden_floor(row_index: int, row_count: int) -> Array[String]:
	if row_index == 0:
		return ["battle", "battle", "battle"]
	if row_index == row_count - 2:
		return ["rest", "story", "event"]
	return ["story", "event", "elite", "battle"]

func _ensure_row_variety(row_types: Array[String], pool: Array[String]) -> void:
	var has_non_battle: bool = false
	for row_type in row_types:
		if String(row_type) != "battle":
			has_non_battle = true
			break
	if not has_non_battle:
		var special_pool: Array = []
		for option in pool:
			if String(option) != "battle":
				special_pool.append(option)
		if not special_pool.is_empty():
			row_types[rng.randi_range(0, row_types.size() - 1)] = String(special_pool[rng.randi_range(0, special_pool.size() - 1)])

func _build_links(node: MapNodeModel, next_row: Array) -> Array[String]:
	var links: Array[String] = []
	if next_row.is_empty():
		return links
	if next_row.size() == 1:
		links.append(next_row[0].id)
		return links
	var sorted_next: Array = next_row.duplicate()
	sorted_next.sort_custom(func(a: MapNodeModel, b: MapNodeModel) -> bool:
		var a_dist: int = abs(a.lane - node.lane)
		var b_dist: int = abs(b.lane - node.lane)
		if a_dist == b_dist:
			return a.lane < b.lane
		return a_dist < b_dist
	)
	# Always connect to nearest node
	links.append((sorted_next[0] as MapNodeModel).id)
	# Secondary link for branching paths
	if sorted_next.size() > 1:
		var secondary: MapNodeModel = sorted_next[1] as MapNodeModel
		if abs(secondary.lane - node.lane) <= 2 or rng.randf() < 0.40:
			links.append(secondary.id)
	# Occasional third link for wider branching
	if sorted_next.size() > 2 and rng.randf() < 0.15:
		var tertiary: MapNodeModel = sorted_next[2] as MapNodeModel
		if abs(tertiary.lane - node.lane) <= 2:
			links.append(tertiary.id)
	return links

func _ensure_incoming_links(current_row: Array, next_row: Array) -> void:
	for next_node_variant in next_row:
		var next_node: MapNodeModel = next_node_variant
		var has_incoming: bool = false
		for current_node_variant in current_row:
			var current_node: MapNodeModel = current_node_variant
			if current_node.next_ids.has(next_node.id):
				has_incoming = true
				break
		if has_incoming:
			continue
		var closest_current: MapNodeModel = null
		var closest_distance: int = 999999
		for current_node_variant in current_row:
			var current_node: MapNodeModel = current_node_variant
			var lane_distance: int = abs(current_node.lane - next_node.lane)
			if lane_distance < closest_distance:
				closest_distance = lane_distance
				closest_current = current_node
		if closest_current != null and not closest_current.next_ids.has(next_node.id):
			closest_current.next_ids.append(next_node.id)
