class_name UnitState
extends RefCounted

var id: String = ""
var display_name: String = ""
var max_hp: int = 1
var hp: int = 1
var block: int = 0
var energy: int = 0
var will: int = 0
var ammo: int = 0
var max_ammo: int = 0
var mark: int = 0
var resonance: int = 0
var overload: int = 0
var echo_percent: int = 0
var burst_active: bool = false
var reload_queue: Array[Dictionary] = []
var intent: Dictionary = {}
var statuses: Dictionary = {}
var meta: Dictionary = {}

func is_dead() -> bool:
	return hp <= 0

func add_block(value: int) -> void:
	block += max(0, value)

func lose_hp(value: int) -> void:
	hp = max(0, hp - max(0, value))

func heal(value: int) -> void:
	hp = min(max_hp, hp + max(0, value))

func gain_will(value: int, max_will: int = 10) -> void:
	will = clamp(will + value, 0, max_will)

func spend_will(value: int) -> int:
	var spent: int = min(value, will)
	will -= spent
	return spent

func gain_ammo(value: int, cap: int = -1) -> void:
	var ammo_cap: int = max_ammo if cap < 0 else cap
	ammo = clamp(ammo + max(0, value), 0, max(0, ammo_cap))

func spend_ammo(value: int) -> int:
	var spent: int = min(max(0, value), ammo)
	ammo -= spent
	return spent

func fill_ammo() -> int:
	var restored: int = max(0, max_ammo - ammo)
	ammo = max_ammo
	return restored

func add_mark(value: int, max_mark: int = 9) -> void:
	mark = clamp(mark + max(0, value), 0, max_mark)

func consume_mark(value: int) -> int:
	var spent: int = min(max(0, value), mark)
	mark -= spent
	return spent

func add_resonance(value: int, max_resonance: int = 9) -> void:
	resonance = clamp(resonance + max(0, value), 0, max_resonance)

func consume_resonance(value: int) -> int:
	var spent: int = min(value, resonance)
	resonance -= spent
	return spent

func gain_overload(value: int) -> void:
	overload = max(0, overload + max(0, value))

func reduce_overload(value: int) -> void:
	overload = max(0, overload - max(0, value))

func clear_echo() -> void:
	echo_percent = 0

func apply_status(status_id: String, amount: int) -> void:
	statuses[status_id] = int(statuses.get(status_id, 0)) + amount

func clear_status(status_id: String) -> void:
	statuses.erase(status_id)
