extends Node

const MENU_BGM: AudioStream = preload("res://主页面游戏背景bgm.mp3")
const MAP_BGM: AudioStream = preload("res://地图背景bgm.mp3")
const NORMAL_BATTLE_BGM: AudioStream = preload("res://战斗时背景bgm.mp3")
const BOSS_BATTLE_BGM: AudioStream = preload("res://Boss战bgm.mp3")

var menu_player: AudioStreamPlayer
var scene_player: AudioStreamPlayer

func _ready() -> void:
	menu_player = AudioStreamPlayer.new()
	menu_player.name = "MenuBGM"
	add_child(menu_player)
	scene_player = AudioStreamPlayer.new()
	scene_player.name = "SceneBGM"
	add_child(scene_player)

func _exit_tree() -> void:
	_release_player(menu_player)
	_release_player(scene_player)

func play_menu_bgm() -> void:
	if menu_player == null:
		return
	var stream_changed: bool = menu_player.stream != MENU_BGM
	if stream_changed and menu_player.playing:
		menu_player.stop()
	if stream_changed:
		menu_player.stream = MENU_BGM
	if menu_player.stream != null and "loop" in menu_player.stream:
		menu_player.stream.loop = true
	_apply_menu_volume()
	if stream_changed or not menu_player.playing:
		menu_player.play()

func stop_menu_bgm() -> void:
	_release_player(menu_player)

func refresh_menu_volume() -> void:
	_apply_menu_volume()
	_apply_scene_volume()

func play_map_bgm() -> void:
	_play_scene_stream(MAP_BGM)

func play_battle_bgm(is_boss: bool) -> void:
	_play_scene_stream(BOSS_BATTLE_BGM if is_boss else NORMAL_BATTLE_BGM)

func stop_scene_bgm() -> void:
	_release_player(scene_player)

func _apply_menu_volume() -> void:
	if menu_player == null:
		return
	menu_player.volume_db = _current_music_db()

func _apply_scene_volume() -> void:
	if scene_player == null:
		return
	scene_player.volume_db = _current_music_db()

func _play_scene_stream(stream: AudioStream) -> void:
	if scene_player == null or stream == null:
		return
	var stream_changed: bool = scene_player.stream != stream
	if stream_changed and scene_player.playing:
		scene_player.stop()
	if stream_changed:
		scene_player.stream = stream
	if scene_player.stream != null and "loop" in scene_player.stream:
		scene_player.stream.loop = true
	_apply_scene_volume()
	if stream_changed or not scene_player.playing:
		scene_player.play()

func _current_music_db() -> float:
	var profile: Dictionary = SaveManager.load_profile()
	var master: float = float(profile.get("master_volume", 80.0)) / 100.0
	var music: float = float(profile.get("music_volume", 70.0)) / 100.0
	var final_volume: float = max(0.001, master * music)
	return linear_to_db(final_volume)

func _release_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null
