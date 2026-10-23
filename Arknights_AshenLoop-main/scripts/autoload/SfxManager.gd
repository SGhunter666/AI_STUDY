extends Node

const SFX_PATHS := {
	"ui_click": "res://assets/sfx/ui_click.wav",
	"ui_open": "res://assets/sfx/ui_open.wav",
	"card_draw": "res://assets/sfx/card_draw.wav",
	"card_select": "res://assets/sfx/card_select.wav",
	"card_play": "res://assets/sfx/card_play.wav",
	"support_play": "res://assets/sfx/support_play.wav",
	"attack_hit": "res://assets/sfx/attack_hit.wav",
	"resonance_apply": "res://assets/sfx/resonance_apply.wav",
	"resonance_burst": "res://assets/sfx/resonance_burst.wav",
	"explosion_warn": "res://assets/sfx/explosion_warn.wav",
	"explosion_boom": "res://assets/sfx/explosion_boom.wav",
	"end_turn": "res://assets/sfx/end_turn.wav",
	"victory": "res://assets/sfx/victory.wav",
	"defeat": "res://assets/sfx/defeat.wav",
	"shop_open": "res://assets/sfx/shop_open.wav",
	"rest_open": "res://assets/sfx/rest_open.wav",
	"reward_open": "res://assets/sfx/reward_open.wav"
}

const CUE_CATEGORIES := {
	"ui_click": "ui",
	"ui_open": "ui",
	"card_draw": "combat",
	"card_select": "combat",
	"card_play": "combat",
	"support_play": "special",
	"attack_hit": "combat",
	"resonance_apply": "special",
	"resonance_burst": "special",
	"explosion_warn": "warning",
	"explosion_boom": "warning",
	"end_turn": "combat",
	"victory": "special",
	"defeat": "special",
	"shop_open": "ui",
	"rest_open": "ui",
	"reward_open": "ui"
}

const CATEGORY_PRIORITY := {
	"ui": 1,
	"combat": 2,
	"special": 3,
	"warning": 4
}

const CATEGORY_BASE_OFFSETS_DB := {
	"ui": -1.2,
	"combat": 0.0,
	"special": 1.1,
	"warning": 2.0
}

# 音效分类 -> 用户音量分组的设置键（master x 组音量 共同决定最终音量）
const CATEGORY_VOLUME_KEYS := {
	"ui": "ui_volume",
	"combat": "combat_volume",
	"special": "special_volume",
	"warning": "warning_volume"
}

const CATEGORY_DUCK_AMOUNT_DB := {
	"special": 3.5,
	"warning": 6.0
}

const CATEGORY_DUCK_DURATION_SEC := {
	"special": 0.22,
	"warning": 0.38
}

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()
var last_hit_time_msec: int = 0
var last_warning_time_msec: int = 0
var last_click_time_msec: int = 0

func _ready() -> void:
	rng.randomize()
	_load_streams()
	_build_pool()
	set_process(true)
	refresh_volume()

func refresh_volume() -> void:
	for player in players:
		if player != null:
			_apply_player_volume(player)

func play_ui_click() -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_click_time_msec < 28:
		return
	last_click_time_msec = now
	_play("ui_click", randf_range(0.98, 1.04), 0.0)

func play_ui_hover() -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_click_time_msec < 40:
		return
	last_click_time_msec = now
	_play("ui_click", randf_range(1.03, 1.07), -3.0)

func play_ui_open() -> void:
	_play("ui_open", randf_range(0.99, 1.02), -1.0)

func play_card_draw(count: int = 1) -> void:
	var pitch: float = 1.0 + min(0.08, float(max(0, count - 1)) * 0.02)
	_play("card_draw", pitch, -0.8)

func play_card_select() -> void:
	_play("card_select", randf_range(0.98, 1.03), -0.5)

func play_card_play() -> void:
	_play("card_play", randf_range(0.98, 1.02), 0.0)

func play_support_play() -> void:
	_play("support_play", randf_range(0.99, 1.02), 0.4)

func play_attack_hit(amount: int = 0) -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_hit_time_msec < 45:
		return
	last_hit_time_msec = now
	var volume_boost: float = min(3.0, float(max(amount, 0)) * 0.05)
	_play("attack_hit", randf_range(0.97, 1.02), volume_boost)

func play_shot_hit(amount: int = 0) -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_hit_time_msec < 32:
		return
	last_hit_time_msec = now
	var volume_boost: float = min(2.4, float(max(amount, 0)) * 0.04)
	_play("attack_hit", randf_range(1.10, 1.18), volume_boost - 0.4)

func play_reload(amount: int = 1) -> void:
	var pitch: float = 1.08 + min(0.10, float(max(0, amount - 1)) * 0.025)
	_play("card_draw", pitch, -1.0)

func play_mark_apply(amount: int = 1) -> void:
	var pitch: float = 1.08 + min(0.12, float(max(0, amount - 1)) * 0.03)
	_play("resonance_apply", pitch, -0.9)

func play_burst_fire() -> void:
	_play("support_play", randf_range(1.06, 1.12), 0.2)

func play_finisher_hit() -> void:
	_play("resonance_burst", randf_range(1.06, 1.10), 1.0)

func play_resonance_apply(amount: int = 1) -> void:
	var pitch: float = 1.0 + min(0.14, float(max(0, amount - 1)) * 0.03)
	_play("resonance_apply", pitch, -0.4)

func play_resonance_burst(layers: int = 1) -> void:
	var volume_boost: float = min(4.0, float(max(layers, 1)) * 0.16)
	_play("resonance_burst", randf_range(0.98, 1.01), volume_boost)

func play_w_warning() -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_warning_time_msec < 250:
		return
	last_warning_time_msec = now
	_play("explosion_warn", 1.0, 0.8)

func play_explosion() -> void:
	_play("explosion_boom", randf_range(0.98, 1.01), 1.2)

func play_end_turn() -> void:
	_play("end_turn", randf_range(0.98, 1.02), 0.0)

func play_victory() -> void:
	_play("victory", 1.0, 1.2)

func play_defeat() -> void:
	_play("defeat", 1.0, 0.8)

func play_shop_open() -> void:
	_play("shop_open", 1.0, 0.2)

func play_rest_open() -> void:
	_play("rest_open", 1.0, 0.0)

func play_reward_open() -> void:
	_play("reward_open", 1.0, 0.4)

func _load_streams() -> void:
	streams.clear()
	for cue_name in SFX_PATHS.keys():
		var path: String = String(SFX_PATHS[cue_name])
		if ResourceLoader.exists(path):
			streams[cue_name] = load(path)

func _build_pool() -> void:
	if not players.is_empty():
		return
	for index in range(18):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		add_child(player)
		players.append(player)

func _play(cue_name: String, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not streams.has(cue_name):
		return
	var player: AudioStreamPlayer = _next_player()
	if player == null:
		return
	var category: String = String(CUE_CATEGORIES.get(cue_name, "combat"))
	player.stop()
	player.stream = streams[cue_name]
	player.pitch_scale = pitch
	player.set_meta("sfx_category", category)
	player.set_meta("sfx_volume_offset_db", volume_offset_db)
	player.set_meta("sfx_duck_db", 0.0)
	player.set_meta("sfx_duck_until", 0)
	_apply_ducking_for_category(category)
	_apply_player_volume(player)
	player.play()

func _next_player() -> AudioStreamPlayer:
	for player in players:
		if player != null and not player.playing:
			return player
	return players[0] if not players.is_empty() else null

func _current_sfx_db(category: String = "combat") -> float:
	var profile: Dictionary = SaveManager.load_profile()
	var master: float = float(profile.get("master_volume", 80.0)) / 100.0
	var group_key: String = String(CATEGORY_VOLUME_KEYS.get(category, "sfx_volume"))
	var group_volume: float = float(profile.get(group_key, 75.0)) / 100.0
	var final_volume: float = max(0.001, master * group_volume)
	return linear_to_db(final_volume)

func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	for player in players:
		if player == null:
			continue
		if int(player.get_meta("sfx_duck_until", 0)) > 0 and now_usec >= int(player.get_meta("sfx_duck_until", 0)):
			player.set_meta("sfx_duck_until", 0)
			player.set_meta("sfx_duck_db", 0.0)
			_apply_player_volume(player)

func _apply_ducking_for_category(category: String) -> void:
	if not CATEGORY_DUCK_AMOUNT_DB.has(category):
		return
	var duck_amount: float = float(CATEGORY_DUCK_AMOUNT_DB.get(category, 0.0))
	var duration_sec: float = float(CATEGORY_DUCK_DURATION_SEC.get(category, 0.18))
	var current_priority: int = int(CATEGORY_PRIORITY.get(category, 2))
	var now_usec: int = Time.get_ticks_usec()
	var duck_until: int = now_usec + int(duration_sec * 1000000.0)
	for player in players:
		if player == null or not player.playing:
			continue
		var other_category: String = String(player.get_meta("sfx_category", "combat"))
		var other_priority: int = int(CATEGORY_PRIORITY.get(other_category, 2))
		if other_priority >= current_priority:
			continue
		player.set_meta("sfx_duck_db", duck_amount)
		player.set_meta("sfx_duck_until", duck_until)
		_apply_player_volume(player)

func _apply_player_volume(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var category: String = String(player.get_meta("sfx_category", "combat"))
	var base_db: float = _current_sfx_db(category)
	var category_offset_db: float = float(CATEGORY_BASE_OFFSETS_DB.get(category, 0.0))
	var volume_offset_db: float = float(player.get_meta("sfx_volume_offset_db", 0.0))
	var duck_db: float = float(player.get_meta("sfx_duck_db", 0.0))
	player.volume_db = base_db + category_offset_db + volume_offset_db - duck_db
