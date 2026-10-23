class_name BattleState
extends RefCounted

var turn_number: int = 0
var played_support_this_turn: int = 0
var delayed_effect_queue: Array[Dictionary] = []
var player_echo_state: Dictionary = {}
var lost_hp_this_turn: int = 0
var lost_hp_this_battle: int = 0
var cards_played_this_turn: int = 0
var story_combat_flags: Dictionary = {}

func reset_turn() -> void:
	played_support_this_turn = 0
	lost_hp_this_turn = 0
	cards_played_this_turn = 0

