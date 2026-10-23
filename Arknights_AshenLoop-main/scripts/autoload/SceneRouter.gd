extends Node

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const SINGLE_PLAYER_SCENE := "res://scenes/SinglePlayerScene.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/EncyclopediaScene.tscn"
const SETTINGS_SCENE := "res://scenes/SettingsScene.tscn"
const QUIT_SCENE := "res://scenes/QuitScene.tscn"
const DEFEAT_SCENE := "res://scenes/DefeatScene.tscn"
const VICTORY_SCENE := "res://scenes/VictoryScene.tscn"
const MAP_SCENE := "res://scenes/MapScene.tscn"
const BATTLE_SCENE := "res://scenes/BattleScene.tscn"
const EVENT_SCENE := "res://scenes/EventScene.tscn"
const REWARD_SCENE := "res://scenes/RewardScene.tscn"
const SHOP_SCENE := "res://scenes/ShopScene.tscn"
const REST_SCENE := "res://scenes/RestScene.tscn"

var return_scene_after_settings: String = MAIN_MENU_SCENE
var suppress_navigation: bool = false
var last_requested_scene: String = ""

func go_to(path: String) -> void:
	last_requested_scene = path
	if suppress_navigation:
		return
	RunManager.checkpoint_run()
	TransitionManager.transition_to(path)

func go_main_menu() -> void:
	MusicManager.stop_scene_bgm()
	MusicManager.play_menu_bgm()
	go_to(MAIN_MENU_SCENE)

func go_single_player() -> void:
	go_to(SINGLE_PLAYER_SCENE)

func go_encyclopedia() -> void:
	go_to(ENCYCLOPEDIA_SCENE)

func go_settings(return_scene: String = MAIN_MENU_SCENE) -> void:
	return_scene_after_settings = return_scene
	go_to(SETTINGS_SCENE)

func return_from_settings() -> void:
	go_to(return_scene_after_settings)

func go_quit_page() -> void:
	go_to(QUIT_SCENE)

func go_defeat() -> void:
	go_to(DEFEAT_SCENE)

func go_victory() -> void:
	go_to(VICTORY_SCENE)

func go_map() -> void:
	go_to(MAP_SCENE)

func go_battle() -> void:
	go_to(BATTLE_SCENE)

func go_event() -> void:
	go_to(EVENT_SCENE)

func go_reward() -> void:
	go_to(REWARD_SCENE)

func go_shop() -> void:
	go_to(SHOP_SCENE)

func go_rest() -> void:
	go_to(REST_SCENE)
