extends Control

# 战斗中速度循环档位：与 settings_menu.gd 中 BATTLE_SPEED_OPTIONS 保持一致
const _BATTLE_SPEED_CYCLES: Array[float] = [0.5, 1.0, 1.5, 2.0, 3.0]
# 战斗日志保留的最大条数，超出后丢弃最旧条目并重建
const LOG_MAX_ENTRIES := 120

const SETTINGS_TILE: Texture2D = preload("res://assets/ui_icons/settings_tile.svg")
const HUD_ICON_HP: Texture2D = preload("res://assets/ui_icons/hud_hp.svg")
const HUD_ICON_GOLD: Texture2D = preload("res://assets/ui_icons/hud_gold.svg")
const HUD_ICON_DECK: Texture2D = preload("res://assets/ui_icons/hud_deck.svg")
const HUD_ICON_DISCARD: Texture2D = preload("res://assets/ui_icons/hud_discard.svg")
const HUD_ICON_FLOOR: Texture2D = preload("res://assets/ui_icons/hud_floor.svg")
const HUD_ICON_TUNE: Texture2D = preload("res://assets/ui_icons/hud_tune.svg")
const BATTLE_ICON_DAMAGE: Texture2D = preload("res://assets/battle_icons/damage.svg")
const BATTLE_ICON_BLOCK: Texture2D = preload("res://assets/battle_icons/block.svg")
const BATTLE_ICON_RESONANCE: Texture2D = preload("res://assets/battle_icons/resonance.svg")
const TUTORIAL_OVERLAY = preload("res://scripts/ui/tutorial_overlay.gd")
const BATTLE_AIM_VIEW = preload("res://scripts/ui/battle_aim_view.gd")
const BATTLE_ICON_SUPPORT: Texture2D = preload("res://assets/battle_icons/support.svg")
const BATTLE_ICON_EXPLOSION: Texture2D = preload("res://assets/battle_icons/explosion.svg")
const BATTLE_ICON_ARTS: Texture2D = preload("res://assets/battle_icons/arts.svg")
const BATTLE_ICON_WILL: Texture2D = preload("res://assets/battle_icons/will.svg")
const BATTLE_ICON_WEAK: Texture2D = preload("res://assets/battle_icons/weak.svg")
const BATTLE_ICON_VULNERABLE: Texture2D = preload("res://assets/battle_icons/vulnerable.svg")
const BATTLE_ICON_STRENGTH: Texture2D = preload("res://assets/battle_icons/strength.svg")
const BATTLE_ICON_AMMO: Texture2D = preload("res://assets/module_icons/ex_m01_racing_magazine.svg")
const BATTLE_ICON_RELOAD: Texture2D = preload("res://assets/module_icons/ex_m08_highspeed_loader.svg")
const BATTLE_ICON_MARK: Texture2D = preload("res://assets/module_icons/ex_m04_target_scope.svg")
const BATTLE_ICON_BURST: Texture2D = preload("res://assets/module_icons/ex_m15_gunfire_halo.svg")
const INTENT_ICON_ATTACK: Texture2D = preload("res://assets/ui_icons/intent_attack.svg")
const INTENT_ICON_BUFF: Texture2D = preload("res://assets/ui_icons/intent_buff.svg")
const INTENT_ICON_DEBUFF: Texture2D = preload("res://assets/ui_icons/intent_debuff.svg")
const INTENT_ICON_SPECIAL: Texture2D = preload("res://assets/ui_icons/intent_special.svg")
const SUPPORT_TILE_AMIYA: Texture2D = preload("res://assets/ui_icons/amiya_tile.svg")
const SUPPORT_TILE_NEARL: Texture2D = preload("res://assets/ui_icons/nearl_tile.svg")
const SUPPORT_TILE_EXUSIAI: Texture2D = preload("res://assets/ui_icons/exusiai_tile.svg")
const SUPPORT_TILE_KALTSIT: Texture2D = preload("res://assets/ui_icons/kaltsit_tile.svg")
const MON3TR_PORTRAIT: Texture2D = preload("res://assets/character_portraits/mon3tr_atlas.tres")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const CARD_DISPLAY_FACTORY = preload("res://scripts/ui/card_display_factory.gd")
const CARD_HOVER_PREVIEW = preload("res://scripts/ui/card_hover_preview.gd")
const CARD_GALLERY_OVERLAY = preload("res://scripts/ui/card_gallery_overlay.gd")
const COMBAT_ACTOR_VIEW = preload("res://scripts/ui/combat_actor_view.gd")
const ENEMY_VISUAL_RESOLVER = preload("res://scripts/ui/enemy_visual_resolver.gd")
const TUNE_SUMMARY_PRESENTER = preload("res://scripts/ui/tune_summary_presenter.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const SETTINGS_SCENE = preload("res://scenes/SettingsScene.tscn")

@onready var manager: BattleManager = $BattleManager
@onready var background_image: TextureRect = $BackgroundImage
@onready var shade: ColorRect = $Shade
@onready var hud_row: HBoxContainer = $TopHUD/HudMargin/HudRow
@onready var health_chip: Button = $TopHUD/HudMargin/HudRow/HealthChip
@onready var gold_chip: Button = $TopHUD/HudMargin/HudRow/GoldChip
@onready var deck_chip: Button = $TopHUD/HudMargin/HudRow/DeckChip
@onready var discard_chip: Button = $TopHUD/HudMargin/HudRow/DiscardChip
@onready var floor_chip: Button = $TopHUD/HudMargin/HudRow/FloorChip
@onready var turn_chip: Label = $TopHUD/HudMargin/HudRow/TurnChip
@onready var combat_info: Label = $TopHUD/HudMargin/HudRow/CombatInfo
@onready var settings_button: Button = $SettingsButton
@onready var battle_speed_button: Button = $BattleSpeedButton
@onready var arena: Control = $Arena
@onready var player_actor_stage: Control = $Arena/PlayerActorStage
@onready var player_frame: PanelContainer = $Arena/PlayerFrame
@onready var player_stats: Label = $Arena/PlayerFrame/PlayerStats
@onready var enemy_actor_stage: Control = $Arena/EnemyActorStage
@onready var enemy_container: HBoxContainer = $Arena/EnemyContainer
@onready var enemy_intent_frame: PanelContainer = $Arena/EnemyIntentFrame
@onready var enemy_intent_label: Label = $Arena/EnemyIntentFrame/EnemyIntentLabel
@onready var aim_hint_panel: PanelContainer = $Arena/TargetHintPanel
@onready var aim_hint_title: Label = $Arena/TargetHintPanel/HintMargin/HintVBox/HintTitle
@onready var aim_hint_body: Label = $Arena/TargetHintPanel/HintMargin/HintVBox/HintBody
@onready var energy_panel: PanelContainer = $BottomHUD/EnergyPanel
@onready var energy_icon: Label = $BottomHUD/EnergyPanel/EnergyIcon
@onready var energy_label: Label = $BottomHUD/EnergyPanel/EnergyLabel
@onready var hand_dock: PanelContainer = $BottomHUD/HandDock
@onready var hand_scroll: Control = $BottomHUD/HandDock/HandMargin/HandScroll
@onready var hand_container: Control = $BottomHUD/HandDock/HandMargin/HandScroll/HandContainer
@onready var log_frame: PanelContainer = $BottomHUD/LogFrame
@onready var log_title: Label = $BottomHUD/LogFrame/LogMargin/LogVBox/LogHeader/LogTitle
@onready var log_subtitle: Label = $BottomHUD/LogFrame/LogMargin/LogVBox/LogHeader/LogSubtitle
@onready var log_label: RichTextLabel = $BottomHUD/LogFrame/LogMargin/LogVBox/LogLabel
@onready var end_turn_button: Button = $BottomHUD/EndTurnButton

var enemy_visual_resolver = ENEMY_VISUAL_RESOLVER.new()
var battle_feedback_layer: Control
var player_damage_flash: ColorRect
var support_spotlight: ColorRect
var support_banner: PanelContainer
var support_banner_title: Label
var support_banner_body: Label
var support_banner_tween: Tween
var support_lane: PanelContainer
var support_lane_icon_plate: PanelContainer
var support_lane_icon: TextureRect
var support_lane_label: Label
var support_lane_tween: Tween
var support_cutin: PanelContainer
var support_cutin_accent: ColorRect
var support_cutin_badge: PanelContainer
var support_cutin_icon: TextureRect
var support_cutin_flash: ColorRect
var support_cutin_title: Label
var support_cutin_body: Label
var support_cutin_tween: Tween
var hand_overflow_toast: PanelContainer
var hand_overflow_toast_label: Label
var hand_overflow_toast_tween: Tween
var selected_target_index: int = 0
var player_actor_view: CombatActorView
var mon3tr_actor_view: CombatActorView
var enemy_actor_views: Array[CombatActorView] = []
var hovered_hand_card: Button = null
var card_hover_preview: Control = null
var hand_card_tweens: Dictionary = {}
var hand_interaction_locked: bool = false
var _log_entries: Array[Dictionary] = []
var aimed_card_index: int = -1
var aimed_card: CardData = null
var aimed_card_button: Button = null
var pending_draw_animation_cards: Array[CardData] = []
var current_ui_scale: float = 1.0
var end_turn_warning_label: Label
var aim_view: BattleAimView = null
var aim_pointer_down: bool = false
var battlefield_shake_tweens: Dictionary = {}
# _make_scene_tween 创建的 tween 统一登记表：_exit_tree 时集中 kill，替代逐 tween 的 tree_exiting 连接
var _scene_tweens: Array[Tween] = []
var w_phase_fx_seen: Dictionary = {}
var w_bomb_fx_seen: Dictionary = {}
var tune_button: Button
var settings_overlay: Control
# 模块图标条：显示在 TopHUD 下方，悬停展示精致预览
var module_strip: HBoxContainer
var module_preview_overlay: Control
var module_preview_panel: PanelContainer
var module_preview_box: VBoxContainer
var module_preview_tween: Tween = null
var module_preview_version: int = 0
var settings_overlay_opening: bool = false

func _ready() -> void:
	MusicManager.stop_menu_bgm()
	MusicManager.play_battle_bgm(_is_boss_battle_from_node())
	_ensure_tune_button()
	_embed_settings_icon()
	_attach_settings_feedback()
	_ensure_battle_feedback_layer()
	_ensure_hand_overflow_toast()
	_ensure_module_strip()
	_apply_ui_theme()
	_style_energy_orb()
	_ensure_end_turn_warning_label()
	_ensure_aim_view()
	_apply_battle_ui_scale()
	player_frame.visible = false
	enemy_container.visible = false
	enemy_intent_frame.visible = false
	_apply_static_text()
	LocalizationManager.language_changed.connect(_on_language_changed)
	manager.resolver.effect_resolved.connect(_on_battle_effect_resolved)
	manager.turn_started.connect(_on_turn_started)
	manager.cards_drawn.connect(_on_cards_drawn)
	manager.cards_overflowed.connect(_on_cards_overflowed)
	manager.enemy_action_started.connect(_on_enemy_action_started)
	manager.enemy_action_resolved.connect(_on_enemy_action_resolved)
	manager.enemy_turn_sequence_finished.connect(_on_enemy_turn_sequence_finished)
	settings_button.pressed.connect(_press_settings)
	if battle_speed_button != null:
		battle_speed_button.pressed.connect(_cycle_battle_speed)
		_refresh_battle_speed_button()
	deck_chip.pressed.connect(_open_draw_pile_overlay)
	discard_chip.pressed.connect(_open_discard_pile_overlay)
	manager.hand_changed.connect(_refresh_hand)
	manager.enemy_intents_updated.connect(_refresh_enemies)
	manager.state_changed.connect(_refresh_state)
	manager.log_message.connect(_append_log)
	manager.battle_ended.connect(_on_battle_ended)
	end_turn_button.pressed.connect(func() -> void:
		SfxManager.play_end_turn()
		manager.end_player_turn()
	)
	var enemies: Array[EnemyData] = _build_enemy_list()
	if RunManager.character == null or enemies.is_empty():
		log_label.text = "[color=#ffb3b3]%s[/color]" % LocalizationManager.text("battle.invalid_state")
		call_deferred("_return_from_invalid_state")
		return
	manager.configure(RunManager.character, enemies)
	_setup_actor_views()
	_refresh_state()
	hand_scroll.resized.connect(func() -> void:
		_layout_hand_fan(false)
	)
	resized.connect(func() -> void:
		_refresh_enemy_stage_layout()
	)
	# 瞄准轮询只在瞄准模式下需要，平时关闭以省去每帧开销
	set_process(false)
	call_deferred("_play_intro_animation")
	call_deferred("_maybe_show_tutorial_overlay")

func _exit_tree() -> void:
	MusicManager.stop_scene_bgm()
	# 断开 autoload 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.disconnect(_on_language_changed)
	_kill_scene_tween(support_banner_tween)
	support_banner_tween = null
	_kill_scene_tween(support_lane_tween)
	support_lane_tween = null
	_kill_scene_tween(support_cutin_tween)
	support_cutin_tween = null
	_kill_scene_tween(hand_overflow_toast_tween)
	hand_overflow_toast_tween = null
	_kill_scene_tween(module_preview_tween)
	module_preview_tween = null
	_clear_hand_card_tweens()
	_clear_battlefield_shake_tweens()
	for scene_tween in _scene_tweens.duplicate():
		if is_instance_valid(scene_tween):
			scene_tween.kill()
	_scene_tweens.clear()

func _return_from_invalid_state() -> void:
	if RunManager.has_active_run():
		SceneRouter.go_map()
	else:
		SceneRouter.go_main_menu()

func _on_language_changed(_language_code: String) -> void:
	_apply_static_text()
	_refresh_state()

func _apply_static_text() -> void:
	end_turn_button.text = LocalizationManager.text("battle.end_turn")
	settings_button.text = ""
	settings_button.tooltip_text = LocalizationManager.text("main.settings")
	if battle_speed_button != null:
		battle_speed_button.tooltip_text = LocalizationManager.text("battle.speed_tooltip")
		_refresh_battle_speed_button()
	combat_info.clip_text = true
	combat_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_title.text = LocalizationManager.text("battle.log_title")
	log_subtitle.text = LocalizationManager.text("battle.log_subtitle")
	if tune_button != null:
		tune_button.tooltip_text = TUNE_SUMMARY_PRESENTER.hud_tooltip()
	health_chip.tooltip_text = LocalizationManager.text("battle.hud_hp", [manager.player.hp, manager.player.max_hp]) if manager.player != null else LocalizationManager.text("battle.hud_hp", [0, 0])
	gold_chip.tooltip_text = LocalizationManager.text("battle.hud_gold", [RunManager.gold])
	deck_chip.tooltip_text = LocalizationManager.text("battle.inspect_draw")
	discard_chip.tooltip_text = LocalizationManager.text("battle.inspect_discard")
	floor_chip.tooltip_text = LocalizationManager.text("battle.hud_floor", [RunManager.current_floor])

func _build_enemy_list() -> Array[EnemyData]:
	var node: MapNodeModel = RunManager.current_node()
	var db: Dictionary = Util.load_enemy_db()
	var result: Array[EnemyData] = []
	if node == null:
		return result
	for enemy_id in node.metadata.get("enemy_ids", []):
		if db.has(enemy_id):
			result.append(db[enemy_id])
	return result

func _refresh_state() -> void:
	_refresh_hand()
	_refresh_enemies()
	_refresh_actor_views()
	if manager.player != null:
		health_chip.text = "%d/%d" % [manager.player.hp, manager.player.max_hp]
		health_chip.tooltip_text = LocalizationManager.text("battle.hud_hp", [manager.player.hp, manager.player.max_hp])
		gold_chip.text = str(RunManager.gold)
		gold_chip.tooltip_text = LocalizationManager.text("battle.hud_gold", [RunManager.gold])
		deck_chip.text = str(manager.deck.draw_pile.size())
		deck_chip.tooltip_text = LocalizationManager.text("battle.hud_draw", [manager.deck.draw_pile.size()])
		discard_chip.text = str(manager.deck.discard_pile.size())
		discard_chip.tooltip_text = LocalizationManager.text("battle.hud_discard", [manager.deck.discard_pile.size()])
		floor_chip.text = str(RunManager.current_floor)
		floor_chip.tooltip_text = LocalizationManager.text("battle.hud_floor", [RunManager.current_floor])
		turn_chip.text = ""
		if tune_button != null:
			tune_button.text = str(TUNE_SUMMARY_PRESENTER.current_tune_count())
			tune_button.tooltip_text = TUNE_SUMMARY_PRESENTER.hud_tooltip()
		_refresh_combat_info()
		energy_label.text = str(manager.player.energy)
		end_turn_button.disabled = manager.active_side != "player" or manager.battle_finished
	_refresh_module_strip()
	_update_end_turn_warning()
	_update_aim_hint()

func _refresh_hand() -> void:
	_clear_aim_mode(true)
	hovered_hand_card = null
	_clear_hand_card_tweens()
	_hide_card_hover_preview()
	for child in hand_container.get_children():
		child.queue_free()
	for i in range(manager.deck.hand.size()):
		var card: CardData = manager.deck.hand[i]
		var button: Button = CARD_DISPLAY_FACTORY.create_card_button(
			card,
			LocalizationManager.card_name(card),
			LocalizationManager.card_description(card),
			_display_card_cost(card),
			Util.load_card_art(card.id),
			_hand_card_size(),
			true,
			CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
		)
		button.disabled = _is_card_unplayable(card)
		button.modulate = _card_color(card, button.disabled)
		# 战斗场景使用精良 card_hover_preview，禁用 Godot 内置 tooltip 避免重复显示
		button.tooltip_text = ""
		button.mouse_entered.connect(func(target_button: Button = button, hovered_card: CardData = card) -> void:
			if aimed_card_button != null and aimed_card_button != target_button:
				return
			hovered_hand_card = target_button
			_refresh_actor_views()
			_layout_hand_fan(true)
			_show_card_hover_preview(hovered_card, target_button)
		)
		button.mouse_exited.connect(func(target_button: Button = button) -> void:
			if aimed_card_button != null and aimed_card_button != target_button:
				return
			if hovered_hand_card == target_button:
				hovered_hand_card = null
			_refresh_actor_views()
			_layout_hand_fan(true)
			_hide_card_hover_preview()
		)
		if _card_targets_enemy(card):
			button.button_down.connect(func(index: int = i, played_card: CardData = card, source_button: Button = button) -> void:
				_on_target_card_button_down(index, played_card, source_button)
			)
		else:
			button.pressed.connect(func(index: int = i, played_card: CardData = card) -> void:
				_on_card_pressed(index, played_card)
			)
		hand_container.add_child(button)
	call_deferred("_layout_hand_fan", false)
	call_deferred("_play_pending_draw_animations")

func _process(_delta: float) -> void:
	_update_aim_line()
	_poll_aim_release()

func _refresh_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()
	_update_enemy_intent_panel()

func _setup_actor_views() -> void:
	if player_actor_view == null:
		player_actor_view = COMBAT_ACTOR_VIEW.new()
		player_actor_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		player_actor_stage.add_child(player_actor_view)
		var character_id: String = "amiya"
		if RunManager.character != null:
			character_id = RunManager.character.id
		player_actor_view.setup_actor(
			LocalizationManager.active_character_name(),
			Util.load_character_portrait(character_id),
			null,
			Color(0.60, 0.84, 1.0, 1.0),
			"left"
		)
		player_actor_view.set_portrait_fit_mode(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		player_actor_view.apply_ui_scale(_actor_ui_scale())
	_refresh_mon3tr_actor_view()
	_refresh_enemy_stage_layout()
	_refresh_actor_views(true)

func _refresh_actor_views(force_rebuild: bool = false) -> void:
	if player_actor_view != null and manager.player != null:
		player_actor_view.update_stats(manager.player.hp, manager.player.max_hp, manager.player.block)
		player_actor_view.update_statuses(_player_status_entries())
		player_actor_view.set_state_badge("", Color.WHITE, "", null)
		player_actor_view.set_warning_state(_count_curse_in_hand("blast_countdown") > 0, Color(1.0, 0.44, 0.30, 1.0))
	_refresh_mon3tr_actor_view(force_rebuild)
	_refresh_enemy_stage_layout()
	var should_rebuild: bool = force_rebuild or enemy_actor_views.size() != manager.enemies.size()
	if should_rebuild:
		for child in enemy_actor_stage.get_children():
			child.queue_free()
		enemy_actor_views.clear()
		for i in range(manager.enemies.size()):
			var enemy: UnitState = manager.enemies[i]
			var actor_view: CombatActorView = COMBAT_ACTOR_VIEW.new()
			actor_view.custom_minimum_size = _enemy_actor_min_size()
			enemy_actor_stage.add_child(actor_view)
			actor_view.setup_actor(
				LocalizationManager.enemy_name(enemy.id, enemy.display_name),
				enemy_visual_resolver.actor_texture(enemy.id),
				enemy_visual_resolver.actor_emblem(enemy.id),
				enemy_visual_resolver.actor_accent(enemy.id),
				"right"
			)
			actor_view.apply_ui_scale(_enemy_actor_scale())
			actor_view.set_portrait_tint(enemy_visual_resolver.actor_tint(enemy.id))
			actor_view.actor_pressed.connect(func(index: int = i) -> void:
				_on_enemy_actor_pressed(index)
			)
			actor_view.mouse_entered.connect(func(index: int = i) -> void:
				_on_enemy_actor_hovered(index)
			)
			enemy_actor_views.append(actor_view)
	for i in range(min(enemy_actor_views.size(), manager.enemies.size())):
		var enemy: UnitState = manager.enemies[i]
		var actor_view: CombatActorView = enemy_actor_views[i]
		if actor_view != null:
			actor_view.update_stats(enemy.hp, enemy.max_hp, enemy.block)
			actor_view.update_statuses(_status_entries(enemy))
			actor_view.set_selected(i == selected_target_index)
			actor_view.set_preview_target(i == selected_target_index and _is_targeting_enemy_now())
			var w_phase: int = _enemy_w_phase(i)
			if _enemy_is_bomb_threat(enemy):
				var bomb_count: int = max(1, int(enemy.intent.get("value", 1)))
				actor_view.set_state_badge(LocalizationManager.text("battle.badge_bomb", [bomb_count]), Color(1.0, 0.50, 0.28, 1.0), LocalizationManager.text("battle.badge_bomb_tooltip"), BATTLE_ICON_EXPLOSION)
			elif w_phase >= 3:
				actor_view.set_state_badge(LocalizationManager.text("battle.badge_w_phase3"), Color(1.0, 0.24, 0.22, 1.0), LocalizationManager.text("battle.badge_w_phase3_tooltip"), BATTLE_ICON_EXPLOSION)
			elif w_phase >= 2:
				actor_view.set_state_badge(LocalizationManager.text("battle.badge_w_phase2"), Color(1.0, 0.32, 0.30, 1.0), LocalizationManager.text("battle.badge_w_phase2_tooltip"), BATTLE_ICON_EXPLOSION)
			else:
				actor_view.set_state_badge("", Color.WHITE, "", null)
			actor_view.set_warning_state(w_phase >= 2 or _enemy_is_bomb_threat(enemy), Color(1.0, 0.34, 0.30, 1.0))
			if w_phase >= 2:
				var phase_key: String = "%s_%d" % [str(enemy.get_instance_id()), w_phase]
				if not w_phase_fx_seen.has(phase_key):
					w_phase_fx_seen[phase_key] = true
					actor_view.play_arts()
					SfxManager.play_w_warning()
			if _enemy_is_bomb_threat(enemy):
				var bomb_key: String = "%s_%d" % [str(enemy.get_instance_id()), manager.turn_count]
				if not w_bomb_fx_seen.has(bomb_key):
					w_bomb_fx_seen[bomb_key] = true
					SfxManager.play_w_warning()
			var intent_data: Dictionary = _intent_visuals(enemy, enemy.intent)
			actor_view.set_intent(
				String(intent_data.get("icon", "")),
				String(intent_data.get("value", "")),
				intent_data.get("color", Color.WHITE),
				String(intent_data.get("tooltip", "")),
				intent_data.get("icon_texture", null) as Texture2D
			)
	_refresh_enemy_stage_layout()
	call_deferred("_refresh_enemy_stage_layout")
	_update_enemy_intent_panel()

func _refresh_mon3tr_actor_view(force_rebuild: bool = false) -> void:
	if manager == null:
		return
	var mon3tr_unit: UnitState = manager.mon3tr_display_unit()
	if mon3tr_unit == null:
		if mon3tr_actor_view != null and is_instance_valid(mon3tr_actor_view):
			mon3tr_actor_view.queue_free()
		mon3tr_actor_view = null
		return
	if mon3tr_actor_view == null or force_rebuild or not is_instance_valid(mon3tr_actor_view):
		if mon3tr_actor_view != null and is_instance_valid(mon3tr_actor_view):
			mon3tr_actor_view.queue_free()
		mon3tr_actor_view = COMBAT_ACTOR_VIEW.new()
		mon3tr_actor_view.name = "Mon3trActorView"
		mon3tr_actor_view.mouse_filter = Control.MOUSE_FILTER_PASS
		arena.add_child(mon3tr_actor_view)
		mon3tr_actor_view.setup_actor(
			"Mon3tr",
			MON3TR_PORTRAIT,
			null,
			Color(0.62, 1.0, 0.72, 1.0),
			"left"
		)
		mon3tr_actor_view.set_portrait_fit_mode(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		mon3tr_actor_view.set_state_badge_anchor_rect(0.06, -0.14, 0.42, -0.02)
		mon3tr_actor_view.set_footer_anchor_rects(
			Rect2(0.10, 0.765, 0.80, 0.070),
			Rect2(0.10, 0.865, 0.80, 0.052),
			Rect2(0.10, 0.930, 0.80, 0.050),
			Rect2(0.12, 0.990, 0.76, 0.050)
		)
		mon3tr_actor_view.apply_ui_scale(_mon3tr_actor_scale())
		# Mon3tr 机制说明通过精致 detail_popup 显示（悬停 state_badge 时触发）
		mon3tr_actor_view.tooltip_text = ""
		mon3tr_actor_view.move_to_front()
	_refresh_mon3tr_actor_layout()
	mon3tr_actor_view.update_stats(mon3tr_unit.hp, mon3tr_unit.max_hp, mon3tr_unit.block)
	mon3tr_actor_view.update_statuses(_status_entries(mon3tr_unit))
	var meltdown: bool = bool(manager.player.meta.get("mon3tr_in_meltdown", false))
	var critical: bool = mon3tr_unit.hp <= 2 and not meltdown
	if meltdown:
		mon3tr_actor_view.set_state_badge(LocalizationManager.text("battle.badge_meltdown"), Color(1.0, 0.50, 0.26, 1.0), LocalizationManager.text("battle.badge_meltdown_tooltip"), SUPPORT_TILE_KALTSIT)
	elif critical:
		mon3tr_actor_view.set_state_badge(LocalizationManager.text("battle.badge_critical"), Color(1.0, 0.82, 0.34, 1.0), LocalizationManager.text("battle.badge_critical_tooltip"), BATTLE_ICON_SUPPORT)
	else:
		mon3tr_actor_view.set_state_badge(LocalizationManager.text("battle.badge_guard"), Color(0.58, 1.0, 0.70, 1.0), LocalizationManager.text("battle.badge_guard_tooltip"), BATTLE_ICON_SUPPORT)
	mon3tr_actor_view.set_warning_state(critical or meltdown, Color(1.0, 0.46, 0.28, 1.0) if meltdown else Color(1.0, 0.82, 0.34, 1.0))

func _refresh_mon3tr_actor_layout() -> void:
	if mon3tr_actor_view == null or not is_instance_valid(mon3tr_actor_view) or arena == null:
		return
	var actor_size: Vector2 = _mon3tr_actor_size()
	mon3tr_actor_view.size = actor_size
	mon3tr_actor_view.custom_minimum_size = actor_size
	mon3tr_actor_view.apply_ui_scale(_mon3tr_actor_scale())
	var arena_size: Vector2 = arena.size
	var enemy_count: int = max(1, manager.enemies.size()) if manager != null else 1
	var enemy_left_anchor: float = _enemy_stage_left_anchor(enemy_count)
	var enemy_stage_width: float = arena_size.x * (0.99 - enemy_left_anchor)
	var enemy_actor_size: Vector2 = _enemy_actor_min_size()
	var enemy_separation: float = float(_enemy_stage_separation(enemy_count))
	var enemy_total_width: float = enemy_actor_size.x * float(enemy_count) + enemy_separation * float(max(0, enemy_count - 1))
	var first_enemy_left: float = arena_size.x * enemy_left_anchor + max(0.0, (enemy_stage_width - enemy_total_width) * 0.5)
	var desired_x: float = first_enemy_left - actor_size.x - 24.0 * current_ui_scale
	var x: float = clamp(desired_x, arena_size.x * 0.30, arena_size.x * 0.42)
	var y: float = clamp(arena_size.y * 0.18, 60.0 * current_ui_scale, max(60.0, arena_size.y - actor_size.y - 120.0 * current_ui_scale))
	mon3tr_actor_view.position = Vector2(x, y)

func _mon3tr_actor_size() -> Vector2:
	var scale_value: float = _mon3tr_actor_scale()
	return Vector2(360, 520) * scale_value

func _mon3tr_actor_scale() -> float:
	var enemy_count: int = max(1, manager.enemies.size()) if manager != null else 1
	if enemy_count >= 4:
		return clamp(0.72 + (current_ui_scale - 1.0) * 0.06, 0.68, 0.80)
	if enemy_count >= 3:
		return clamp(0.82 + (current_ui_scale - 1.0) * 0.08, 0.76, 0.92)
	return clamp(0.92 + (current_ui_scale - 1.0) * 0.10, 0.84, 1.08)

func _append_log(text: String, tone: String = "normal") -> void:
	if log_label == null or text.is_empty():
		return
	# 战斗日志有上限：长战斗（如 W 三阶段）中无限累积会让 RichTextLabel 重排越来越卡
	_log_entries.append({"text": text, "tone": tone})
	if _log_entries.size() > LOG_MAX_ENTRIES:
		_log_entries.pop_front()
		_rebuild_log_label()
		return
	log_label.push_color(_log_tone_color(tone))
	log_label.add_text("• " + text + "\n")
	log_label.pop()

func _rebuild_log_label() -> void:
	log_label.clear()
	for entry in _log_entries:
		log_label.push_color(_log_tone_color(String(entry.get("tone", "normal"))))
		log_label.add_text("• " + String(entry.get("text", "")) + "\n")
		log_label.pop()

func _on_battle_ended(victory: bool) -> void:
	_clear_aim_mode(true)
	if victory:
		return

func _is_boss_battle_from_node() -> bool:
	var node: MapNodeModel = RunManager.current_node()
	if node != null and node.node_type == "boss":
		return true
	return false

func _is_boss_battle() -> bool:
	if _is_boss_battle_from_node():
		return true
	for enemy_data in manager.enemy_datas:
		if "Boss" in enemy_data.tags:
			return true
	return false

func _embed_settings_icon() -> void:
	var icon_rect: TextureRect = settings_button.get_node_or_null("SettingsIcon") as TextureRect
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "SettingsIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.layout_mode = 1
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		settings_button.add_child(icon_rect)
	icon_rect.texture = SETTINGS_TILE

func _attach_settings_feedback() -> void:
	settings_button.flat = true
	settings_button.pivot_offset = settings_button.size * 0.5
	var ring: Panel = settings_button.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		ring = Panel.new()
		ring.name = "FeedbackRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.layout_mode = 1
		ring.anchor_left = 0.0
		ring.anchor_top = 0.0
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = -3.0
		ring.offset_top = -3.0
		ring.offset_right = 3.0
		ring.offset_bottom = 3.0
		settings_button.add_child(ring)
		settings_button.move_child(ring, 0)
	settings_button.mouse_entered.connect(func() -> void:
		_update_settings_feedback(false)
	)
	settings_button.button_down.connect(func() -> void:
		_update_settings_feedback(true)
	)
	settings_button.button_up.connect(func() -> void:
		_update_settings_feedback(false)
	)
	settings_button.mouse_exited.connect(func() -> void:
		_update_settings_feedback(false)
	)
	_update_settings_feedback(false)

func _confirm_abandon_run() -> void:
	if manager.battle_finished:
		return
	manager.abandon_battle()

func _update_settings_feedback(pressed: bool) -> void:
	var hovered: bool = settings_button.get_global_rect().has_point(settings_button.get_global_mouse_position())
	settings_button.pivot_offset = settings_button.size * 0.5
	settings_button.scale = Vector2(0.96, 0.96) if pressed else (Vector2(1.03, 1.03) if hovered else Vector2.ONE)
	var icon_rect: TextureRect = settings_button.get_node_or_null("SettingsIcon") as TextureRect
	if icon_rect != null:
		icon_rect.position = Vector2(0, 3) if pressed else Vector2.ZERO
	var ring: Panel = settings_button.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if hovered:
		style.border_color = Color(0.82, 0.95, 1.0, 0.76)
		style.shadow_color = Color(0.48, 0.78, 1.0, 0.48)
		style.shadow_size = 14 if not pressed else 6
	else:
		style.border_color = Color(0.82, 0.95, 1.0, 0.0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
	ring.add_theme_stylebox_override("panel", style)

func _play_intro_animation() -> void:
	UI_MOTION.reveal($TopHUD, 0.02, Vector2(0, -16), 0.24)
	if module_strip != null:
		UI_MOTION.reveal(module_strip, 0.06, Vector2(0, -10), 0.22)
	UI_MOTION.reveal($Arena, 0.08, Vector2(0, 18), 0.28, Vector2(0.99, 0.99))
	UI_MOTION.reveal($BottomHUD, 0.12, Vector2(0, 26), 0.30, Vector2(0.99, 0.99))
	if player_actor_view != null:
		UI_MOTION.reveal(player_actor_view, 0.10, Vector2(-16, 0), 0.30, Vector2(0.98, 0.98))
	for i in range(enemy_actor_views.size()):
		UI_MOTION.reveal(enemy_actor_views[i], 0.16 + i * 0.04, Vector2(16, 0), 0.28, Vector2(0.98, 0.98))

# 首次进入战斗时弹出新手引导 overlay，玩家点击"我知道了"后持久化完成状态
func _maybe_show_tutorial_overlay() -> void:
	if SettingsManager == null or SettingsManager.is_tutorial_completed():
		return
	var overlay = TUTORIAL_OVERLAY.new()
	add_child(overlay)


func _apply_battle_ui_scale() -> void:
	current_ui_scale = SettingsManager.get_ui_layout_scale()
	var text_scale: float = clamp(0.96 + (current_ui_scale - 1.0) * 0.44, 0.92, 1.10)
	var control_scale: float = clamp(0.96 + (current_ui_scale - 1.0) * 0.34, 0.92, 1.08)
	hud_row.add_theme_constant_override("separation", 8)
	for label in [health_chip, gold_chip, deck_chip, discard_chip, floor_chip, turn_chip]:
		if label is Control:
			(label as Control).add_theme_font_size_override("font_size", int(round(18 * text_scale)))
	if tune_button != null:
		tune_button.add_theme_font_size_override("font_size", int(round(18 * text_scale)))
	combat_info.custom_minimum_size = Vector2.ZERO
	combat_info.add_theme_font_size_override("font_size", int(round(18 * text_scale)))
	end_turn_button.add_theme_font_size_override("font_size", int(round(28 * text_scale)))
	log_label.add_theme_font_size_override("normal_font_size", int(round(18 * text_scale)))
	log_title.add_theme_font_size_override("font_size", int(round(18 * text_scale)))
	log_subtitle.add_theme_font_size_override("font_size", int(round(14 * text_scale)))
	aim_hint_title.add_theme_font_size_override("font_size", int(round(22 * text_scale)))
	aim_hint_body.add_theme_font_size_override("font_size", int(round(17 * text_scale)))
	energy_panel.custom_minimum_size = Vector2(114, 114) * control_scale
	energy_icon.add_theme_font_size_override("font_size", int(round(86 * control_scale)))
	energy_label.add_theme_font_size_override("font_size", int(round(38 * control_scale)))
	settings_button.custom_minimum_size = Vector2(56, 56) * control_scale
	if player_actor_view != null:
		player_actor_view.apply_ui_scale(_actor_ui_scale())
	_refresh_enemy_stage_layout()
	call_deferred("_refresh_enemy_stage_layout")
	for actor_view in enemy_actor_views:
		if actor_view != null:
			actor_view.custom_minimum_size = _enemy_actor_min_size()
			actor_view.apply_ui_scale(_enemy_actor_scale())

func _actor_ui_scale() -> float:
	return 1.0 + (current_ui_scale - 1.0) * 0.48

func _enemy_actor_min_size() -> Vector2:
	return Vector2(296, 436) * _enemy_actor_scale()

func _enemy_actor_scale() -> float:
	var base_scale: float = _actor_ui_scale()
	var enemy_count: int = max(1, manager.enemies.size())
	var stage_width: float = enemy_actor_stage.size.x if enemy_actor_stage != null and enemy_actor_stage.size.x > 1.0 else 0.0
	var available_width: float = stage_width if stage_width > 1.0 else $Arena.size.x * (0.99 - _enemy_stage_left_anchor(enemy_count))
	if available_width <= 1.0:
		return base_scale
	var separation: float = float(_enemy_stage_separation(enemy_count))
	var usable_width: float = max(220.0, available_width - max(0, enemy_count - 1) * separation - 28.0)
	var fit_scale: float = (usable_width / (296.0 * float(enemy_count))) * 0.95
	var density_cap: float = 1.0
	if enemy_count == 2:
		density_cap = 0.94
	elif enemy_count == 3:
		density_cap = 0.76 if _has_active_mon3tr_layout() else 0.88
	elif enemy_count >= 4:
		density_cap = 0.72
	var resolution_cap_boost: float = clamp(0.92 + (current_ui_scale - 0.86) * 0.70, 0.92, 1.16)
	density_cap *= resolution_cap_boost
	return clamp(min(base_scale, fit_scale, density_cap), 0.52, base_scale)

func _enemy_stage_left_anchor(enemy_count: int) -> float:
	if enemy_count <= 1:
		return 0.60
	if enemy_count == 2:
		return 0.48
	if enemy_count == 3:
		if _has_active_mon3tr_layout():
			return 0.50
		return 0.30
	if _has_active_mon3tr_layout():
		return 0.42
	return 0.22

func _has_active_mon3tr_layout() -> bool:
	return manager != null and manager.mon3tr_display_unit() != null

func _enemy_stage_separation(enemy_count: int) -> int:
	if enemy_count <= 1:
		return 0
	if enemy_count == 2:
		return 28
	if enemy_count == 3:
		return 18
	return 12

func _refresh_enemy_stage_layout() -> void:
	if enemy_actor_stage == null:
		return
	_refresh_mon3tr_actor_layout()
	var enemy_count: int = max(1, manager.enemies.size())
	enemy_actor_stage.anchor_left = _enemy_stage_left_anchor(enemy_count)
	enemy_actor_stage.anchor_right = 0.99
	var enemy_scale: float = _enemy_actor_scale()
	var actor_size: Vector2 = _enemy_actor_min_size()
	var separation: float = float(_enemy_stage_separation(enemy_count))
	var total_width: float = actor_size.x * float(enemy_actor_views.size()) + separation * float(max(0, enemy_actor_views.size() - 1))
	var start_x: float = max(0.0, (enemy_actor_stage.size.x - total_width) * 0.5)
	var actor_y: float = max(0.0, enemy_actor_stage.size.y - actor_size.y)
	for actor_view in enemy_actor_views:
		if actor_view != null:
			actor_view.custom_minimum_size = actor_size
			actor_view.apply_ui_scale(enemy_scale)
			actor_view.size = actor_size
			actor_view.update_minimum_size()
	var actor_index: int = 0
	for actor_view in enemy_actor_views:
		if actor_view == null:
			continue
		actor_view.position = Vector2(start_x + actor_index * (actor_size.x + separation), actor_y)
		actor_index += 1

func _hand_card_size() -> Vector2:
	var hand_scale: float = 1.0 + (current_ui_scale - 1.0) * 0.06
	return Vector2(152, 224) * hand_scale


# 卡牌悬停预览：鼠标悬停手牌时显示完整描述面板
func _show_card_hover_preview(card: CardData, source_button: Button) -> void:
	if card == null or source_button == null:
		return
	if card_hover_preview == null:
		card_hover_preview = CARD_HOVER_PREVIEW.new()
		add_child(card_hover_preview)
	# 以卡牌按钮的全局中心作为锚点
	var anchor_pos: Vector2 = source_button.global_position + source_button.size * 0.5
	# 偏移到卡牌顶部上方
	anchor_pos.y = source_button.global_position.y - 12.0
	card_hover_preview.show_preview(card, anchor_pos)


func _hide_card_hover_preview() -> void:
	if card_hover_preview != null and is_instance_valid(card_hover_preview):
		card_hover_preview.hide_preview()

func _press_settings() -> void:
	if settings_overlay_opening:
		return
	if settings_overlay != null and is_instance_valid(settings_overlay):
		return
	settings_overlay_opening = true
	settings_button.disabled = true
	var pulse_tween: Tween = UI_MOTION.pulse(settings_button, 0.94, 1.04, 0.06)
	pulse_tween.finished.connect(_open_settings_overlay, CONNECT_ONE_SHOT)

func _open_settings_overlay() -> void:
	if settings_overlay != null and is_instance_valid(settings_overlay):
		settings_overlay_opening = false
		settings_button.disabled = false
		return
	settings_overlay = SETTINGS_SCENE.instantiate() as Control
	if settings_overlay == null:
		settings_overlay_opening = false
		settings_button.disabled = false
		return
	if settings_overlay.has_method("enable_overlay_mode"):
		settings_overlay.enable_overlay_mode()
	# 注入"放弃战斗"战斗状态提供器
	if settings_overlay.has_method("set_battle_finished_provider"):
		settings_overlay.set_battle_finished_provider(func() -> bool:
			return manager.battle_finished
		)
	# 监听放弃战斗请求
	if settings_overlay.has_signal("abandon_requested"):
		settings_overlay.abandon_requested.connect(_confirm_abandon_run)
	if settings_overlay.has_signal("close_requested"):
		settings_overlay.close_requested.connect(_on_settings_overlay_closed)
	settings_overlay.tree_exited.connect(_on_settings_overlay_tree_exited)
	add_child(settings_overlay)
	move_child(settings_overlay, get_child_count() - 1)
	settings_overlay_opening = false

func _on_settings_overlay_closed() -> void:
	settings_overlay = null
	settings_overlay_opening = false
	settings_button.disabled = false

func _on_settings_overlay_tree_exited() -> void:
	settings_overlay = null
	settings_overlay_opening = false
	settings_button.disabled = false

func _ensure_tune_button() -> void:
	if tune_button != null:
		return
	tune_button = Button.new()
	tune_button.name = "TuneButton"
	tune_button.layout_mode = 2
	UI_THEME_KIT.apply_hud_chip(tune_button, HUD_ICON_TUNE, Color(0.72, 0.94, 1.0, 1.0), 18)
	UI_MOTION.wire_button_feedback(tune_button, 1.03, 0.97, Color(0.76, 0.92, 1.0, 0.72), 5.0)
	tune_button.pressed.connect(_open_tune_overlay)
	hud_row.add_child(tune_button)
	hud_row.move_child(tune_button, combat_info.get_index())

func _open_tune_overlay() -> void:
	UI_MOTION.pulse(tune_button, 0.95, 1.04, 0.06)
	TUNE_SUMMARY_PRESENTER.open_current_overlay(self)

# ===== 模块图标条 =====

func _ensure_module_strip() -> void:
	# 模块图标条放在 TopHUD 下方，左对齐
	module_strip = HBoxContainer.new()
	module_strip.layout_mode = 1
	module_strip.anchor_left = 0.0
	module_strip.anchor_top = 0.0
	module_strip.anchor_right = 0.76
	module_strip.anchor_bottom = 0.0
	module_strip.offset_left = 14.0
	module_strip.offset_top = 76.0
	module_strip.offset_right = 0.0
	module_strip.offset_bottom = 118.0
	module_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	module_strip.add_theme_constant_override("separation", 6)
	add_child(module_strip)

	# 悬停预览 overlay（全屏，鼠标穿透）
	module_preview_overlay = Control.new()
	module_preview_overlay.layout_mode = 1
	module_preview_overlay.anchor_left = 0.0
	module_preview_overlay.anchor_top = 0.0
	module_preview_overlay.anchor_right = 1.0
	module_preview_overlay.anchor_bottom = 1.0
	module_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	module_preview_overlay.z_index = 500
	module_preview_overlay.visible = false
	add_child(module_preview_overlay)

	module_preview_panel = PanelContainer.new()
	module_preview_panel.layout_mode = 1
	module_preview_panel.anchor_left = 0.0
	module_preview_panel.anchor_top = 0.0
	module_preview_panel.anchor_right = 0.0
	module_preview_panel.anchor_bottom = 0.0
	module_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	module_preview_panel.visible = false
	module_preview_overlay.add_child(module_preview_panel)
	UI_THEME_KIT.apply_glass_panel_blurred(module_preview_panel, 2.4)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	module_preview_panel.add_child(margin)

	module_preview_box = VBoxContainer.new()
	module_preview_box.layout_mode = 2
	module_preview_box.add_theme_constant_override("separation", 10)
	margin.add_child(module_preview_box)


func _refresh_module_strip() -> void:
	if module_strip == null:
		return
	# 清空旧图标
	for child in module_strip.get_children():
		child.queue_free()
	var module_ids: Array[String] = RunManager.modules
	if module_ids.is_empty():
		module_strip.visible = false
		return
	module_strip.visible = true
	var module_db: Dictionary = Util.load_module_db()
	for module_id in module_ids:
		var module_data: ModuleData = module_db.get(module_id, null) as ModuleData
		if module_data == null:
			continue
		var icon_texture: Texture2D = null
		var icon_path: String = Util.module_icon_path(module_id)
		if not icon_path.is_empty():
			icon_texture = load(icon_path) as Texture2D
		var chip := _make_module_chip(module_data, icon_texture)
		module_strip.add_child(chip)


func _make_module_chip(module_data: ModuleData, icon_texture: Texture2D) -> Control:
	var chip := Button.new()
	chip.flat = true
	chip.focus_mode = Control.FOCUS_NONE
	chip.tooltip_text = ""  # 禁用 Godot 内置 tooltip
	chip.custom_minimum_size = Vector2(44, 44)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	# 背景样式
	var bg := Panel.new()
	bg.layout_mode = 1
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.78)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = _module_rarity_color(module_data)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	bg.add_theme_stylebox_override("panel", style)
	chip.add_child(bg)

	# 图标
	var icon_rect := TextureRect.new()
	icon_rect.layout_mode = 1
	icon_rect.anchor_left = 0.12
	icon_rect.anchor_top = 0.12
	icon_rect.anchor_right = 0.88
	icon_rect.anchor_bottom = 0.88
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon_texture
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.modulate = Color(0.98, 0.96, 0.92, 1.0)
	icon_rect.visible = icon_texture != null
	chip.add_child(icon_rect)

	# 无图标时显示首字符
	if icon_texture == null:
		var fallback_label := Label.new()
		fallback_label.layout_mode = 1
		fallback_label.anchor_left = 0.0
		fallback_label.anchor_top = 0.0
		fallback_label.anchor_right = 1.0
		fallback_label.anchor_bottom = 1.0
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_label.add_theme_font_size_override("font_size", 18)
		fallback_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82, 0.92))
		fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_label.text = module_data.display_name.substr(0, 1) if not module_data.display_name.is_empty() else "?"
		chip.add_child(fallback_label)

	# 悬停展示精致预览
	chip.mouse_entered.connect(func() -> void:
		_show_module_preview(module_data, chip)
	)
	chip.mouse_exited.connect(func() -> void:
		_hide_module_preview()
	)
	return chip


func _module_rarity_color(module_data: ModuleData) -> Color:
	match String(module_data.rarity):
		"Common":
			return Color(0.86, 0.88, 0.92, 0.96)
		"Uncommon":
			return Color(0.56, 0.86, 0.74, 0.96)
		"Rare":
			return Color(0.96, 0.82, 0.48, 0.98)
	return Color(0.80, 0.82, 0.86, 0.92)


func _show_module_preview(module_data: ModuleData, chip: Button) -> void:
	if module_preview_panel == null or not is_inside_tree():
		return
	if chip == null or not is_instance_valid(chip):
		return
	module_preview_version += 1
	var version: int = module_preview_version
	if module_preview_tween != null:
		module_preview_tween.kill()
		module_preview_tween = null

	# 清空旧内容
	for child in module_preview_box.get_children():
		child.queue_free()

	# 模块名称 + 稀有度
	var name_row := HBoxContainer.new()
	name_row.layout_mode = 2
	name_row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.layout_mode = 2
	name_label.text = LocalizationManager.module_name(module_data)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 0.98))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	name_label.add_theme_constant_override("outline_size", 3)
	name_row.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.layout_mode = 2
	rarity_label.text = _module_rarity_display(module_data)
	rarity_label.add_theme_font_size_override("font_size", 15)
	rarity_label.add_theme_color_override("font_color", _module_rarity_color(module_data))
	rarity_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.86))
	rarity_label.add_theme_constant_override("outline_size", 2)
	name_row.add_child(rarity_label)
	module_preview_box.add_child(name_row)

	# 模块描述
	var desc_label := Label.new()
	desc_label.layout_mode = 2
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(300, 0)
	desc_label.text = LocalizationManager.module_description(module_data)
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94, 0.92))
	desc_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06, 0.80))
	desc_label.add_theme_constant_override("outline_size", 1)
	module_preview_box.add_child(desc_label)

	# 定位在 chip 下方
	_layout_module_preview_near(chip)
	if version != module_preview_version:
		return
	if not is_inside_tree():
		return
	module_preview_panel.visible = true
	module_preview_overlay.visible = true

	# 入场动画
	module_preview_panel.modulate.a = 0.0
	module_preview_panel.scale = Vector2(0.94, 0.94)
	module_preview_panel.pivot_offset = module_preview_panel.size * 0.5
	module_preview_tween = create_tween()
	if module_preview_tween == null:
		return
	module_preview_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	module_preview_tween.set_parallel(true)
	module_preview_tween.tween_property(module_preview_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	module_preview_tween.tween_property(module_preview_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_module_preview() -> void:
	module_preview_version += 1
	if module_preview_panel == null or not module_preview_panel.visible:
		return
	if module_preview_tween != null:
		module_preview_tween.kill()
	module_preview_tween = create_tween()
	if module_preview_tween == null:
		module_preview_panel.visible = false
		module_preview_overlay.visible = false
		return
	module_preview_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	module_preview_tween.set_parallel(true)
	module_preview_tween.tween_property(module_preview_panel, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	module_preview_tween.tween_property(module_preview_panel, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	module_preview_tween.finished.connect(func() -> void:
		if module_preview_panel != null:
			module_preview_panel.visible = false
		if module_preview_overlay != null:
			module_preview_overlay.visible = false
	, CONNECT_ONE_SHOT)


func _layout_module_preview_near(chip: Button) -> void:
	await get_tree().process_frame
	if module_preview_panel == null or not is_inside_tree():
		return
	var panel_size: Vector2 = module_preview_panel.size
	var viewport_size: Vector2 = get_viewport_rect().size
	var chip_rect: Rect2 = chip.get_global_rect()
	# 默认放在 chip 下方
	var target_pos: Vector2 = Vector2(chip_rect.position.x, chip_rect.end.y + 10)
	# 超出右边界则左移
	if target_pos.x + panel_size.x > viewport_size.x - 20:
		target_pos.x = viewport_size.x - panel_size.x - 20
	# 超出下边界则放上方
	if target_pos.y + panel_size.y > viewport_size.y - 20:
		target_pos.y = chip_rect.position.y - panel_size.y - 10
	# 钳制到安全区
	target_pos.x = clamp(target_pos.x, 20, viewport_size.x - panel_size.x - 20)
	target_pos.y = clamp(target_pos.y, 20, viewport_size.y - panel_size.y - 20)
	module_preview_panel.position = target_pos
	module_preview_panel.pivot_offset = module_preview_panel.size * 0.5


func _module_rarity_display(module_data: ModuleData) -> String:
	match String(module_data.rarity):
		"Common":
			return LocalizationManager.text("card.rarity_common")
		"Uncommon":
			return LocalizationManager.text("card.rarity_uncommon")
		"Rare":
			return LocalizationManager.text("card.rarity_rare")
	return String(module_data.rarity)

func _target_name() -> String:
	if manager.enemies.is_empty():
		return LocalizationManager.text("battle.target_none")
	selected_target_index = int(clamp(selected_target_index, 0, manager.enemies.size() - 1))
	var enemy: UnitState = manager.enemies[selected_target_index]
	return LocalizationManager.enemy_name(enemy.id, enemy.display_name)

func _is_card_unplayable(card: CardData) -> bool:
	if card.card_type == "Curse":
		return true
	return manager == null or not manager.can_play_card(card)

func _display_card_cost(card: CardData) -> int:
	if manager != null:
		return manager.current_card_cost(card)
	return 0

func _card_color(card: CardData, disabled: bool) -> Color:
	if card == null:
		return Color(0.86, 0.90, 0.98, 0.92) if not disabled else Color(0.62, 0.62, 0.66, 0.88)
	if disabled:
		return Color(0.62, 0.62, 0.66, 0.88)
	if "Arts" in card.tags:
		return Color(0.48, 0.88, 0.96, 1.0)
	if "Support" in card.tags:
		return Color(0.95, 0.60, 0.30, 1.0)
	if card.card_type == "Skill":
		return Color(0.76, 0.88, 1.0, 1.0)
	return Color(0.96, 0.82, 0.32, 1.0)

func _open_draw_pile_overlay() -> void:
	var cards: Array[CardData] = []
	for i in range(manager.deck.draw_pile.size() - 1, -1, -1):
		cards.append(manager.deck.draw_pile[i])
	_open_gallery(LocalizationManager.text("battle.draw_pile_title"), cards)

func _open_discard_pile_overlay() -> void:
	var cards: Array[CardData] = []
	for card in manager.deck.discard_pile:
		cards.append(card)
	cards.reverse()
	_open_gallery(LocalizationManager.text("battle.discard_pile_title"), cards)

func _open_gallery(title_text: String, cards: Array[CardData]) -> void:
	var overlay: CardGalleryOverlay = CARD_GALLERY_OVERLAY.new()
	overlay.setup(title_text, cards)
	add_child(overlay)

func _on_card_pressed(index: int, card: CardData) -> void:
	if hand_interaction_locked:
		return
	if _card_targets_enemy(card):
		return
	_clear_aim_mode(true)
	_play_card_from_hand(index, card)

func _on_target_card_button_down(index: int, card: CardData, source_button: Button) -> void:
	if hand_interaction_locked or source_button == null:
		return
	if aimed_card_index == index and aimed_card_button == source_button:
		return
	SfxManager.play_card_select()
	_enter_aim_mode(index, card, source_button)

func _play_card_from_hand(index: int, card: CardData) -> void:
	hand_interaction_locked = true
	if "Support" in card.tags:
		SfxManager.play_support_play()
	else:
		SfxManager.play_card_play()
	var target_center: Vector2 = _card_target_point(card)
	var source_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
	if index >= 0 and index < hand_container.get_child_count():
		var source_button: Control = hand_container.get_child(index) as Control
		if source_button != null:
			source_rect = source_button.get_global_rect()
	_play_exusiai_pre_cast_feedback(card, source_rect, target_center)
	await _play_card_launch_animation(card, source_rect, target_center)
	var played: bool = manager.play_card(index, selected_target_index)
	hand_interaction_locked = false
	if not played:
		_refresh_hand()
		_refresh_state()
		_append_log(LocalizationManager.text("battle.log.play_failed", [
			LocalizationManager.card_name(card),
			_display_card_cost(card),
			manager.player.energy if manager.player != null else 0
		]))
		return
	if player_actor_view == null:
		return
	if "Arts" in card.tags:
		player_actor_view.play_arts()
	elif "Support" in card.tags:
		player_actor_view.play_support()
		_play_support_cast_feedback(card)
	elif card.card_type == "Skill":
		player_actor_view.play_skill()
	else:
		player_actor_view.play_attack()

func _battle_text(zh: String, en: String) -> String:
	return zh if LocalizationManager.current_language == LocalizationManager.LANG_ZH else en

func _card_has_any_tag(card: CardData, tags: Array[String]) -> bool:
	if card == null:
		return false
	for tag in tags:
		if tag in card.tags:
			return true
	return false

func _play_exusiai_pre_cast_feedback(card: CardData, source_rect: Rect2, target_center: Vector2) -> void:
	if card == null:
		return
	if not _card_has_any_tag(card, ["Shot", "Reload", "AmmoGain", "Mark", "Burst", "Finisher"]):
		return
	if "Shot" in card.tags or "Finisher" in card.tags:
		if source_rect.size != Vector2.ZERO:
			var trace_count: int = 3 if "MultiHit" in card.tags or "Burst" in card.tags else 1
			if "Finisher" in card.tags:
				trace_count = max(trace_count, 2)
			for trace_index in range(trace_count):
				var delay: float = float(trace_index) * 0.035
				_spawn_shot_trace(source_rect.get_center(), target_center, delay, "Finisher" in card.tags)
		if player_actor_view != null:
			player_actor_view.play_attack()
	if "Reload" in card.tags or "AmmoGain" in card.tags:
		SfxManager.play_reload(1)
		_spawn_feedback_ring_for_unit(manager.player, Color(0.70, 0.92, 1.0, 1.0), Vector2(108, 108), -20.0, 0.26, 0.08, 0.72)
	if "Burst" in card.tags:
		SfxManager.play_burst_fire()
		_spawn_feedback_ring_for_unit(manager.player, Color(1.0, 0.86, 0.56, 1.0), Vector2(128, 128), -24.0, 0.34, 0.10, 0.84)
	if "Mark" in card.tags:
		SfxManager.play_mark_apply(1)

func _spawn_shot_trace(start_global: Vector2, end_global: Vector2, delay: float = 0.0, finisher: bool = false) -> void:
	if not is_instance_valid(battle_feedback_layer):
		return
	var line := Line2D.new()
	line.z_index = 870
	line.width = 3.6 if finisher else 2.2
	line.default_color = Color(1.0, 0.92, 0.66, 0.0) if finisher else Color(0.72, 0.96, 1.0, 0.0)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var start_local: Vector2 = _global_to_feedback_local(start_global + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0)))
	var end_local: Vector2 = _global_to_feedback_local(end_global + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 12.0)))
	var mid_local: Vector2 = start_local.lerp(end_local, 0.56) + Vector2(randf_range(-8.0, 8.0), randf_range(-18.0, 10.0))
	line.points = PackedVector2Array([start_local, mid_local, end_local])
	battle_feedback_layer.add_child(line)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(line, "default_color:a", 0.96, 0.025).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "width", 7.0 if finisher else 4.2, 0.035).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "default_color:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		line.queue_free()
	)

func _enter_aim_mode(index: int, card: CardData, source_button: Button) -> void:
	if source_button == null:
		return
	aimed_card_index = index
	aimed_card = card
	aimed_card_button = source_button
	aim_pointer_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	hovered_hand_card = source_button
	set_process(true)
	_refresh_actor_views()
	_refresh_combat_info()
	_update_aim_hint()
	_update_enemy_intent_panel()
	_layout_hand_fan(true)
	_append_log(LocalizationManager.text("battle.log.aim_select", [LocalizationManager.card_name(card)]), "info")

func _clear_aim_mode(silent: bool = false) -> void:
	if aimed_card_index == -1 and aimed_card_button == null and aimed_card == null:
		return
	aimed_card_index = -1
	aimed_card = null
	aimed_card_button = null
	aim_pointer_down = false
	hovered_hand_card = null
	_update_aim_line()
	set_process(false)
	if silent:
		_update_aim_hint()
		_update_enemy_intent_panel()
		return
	_refresh_actor_views()
	_refresh_combat_info()
	_update_aim_hint()
	_update_enemy_intent_panel()
	_layout_hand_fan(true)

func _confirm_aimed_card() -> void:
	if aimed_card_index == -1 or aimed_card == null:
		return
	var index: int = aimed_card_index
	var card: CardData = aimed_card
	_clear_aim_mode(true)
	_play_card_from_hand(index, card)

func _on_battle_effect_resolved(effect_type: String, payload: Dictionary) -> void:
	if effect_type == "apply_resonance":
		var resonance_targets: Array = payload.get("targets", [])
		var resonance_amount: int = int(payload.get("amount", 0))
		SfxManager.play_resonance_apply(max(1, resonance_amount))
		for target_variant in resonance_targets:
			var resonance_target: UnitState = target_variant as UnitState
			if resonance_target != null and resonance_amount > 0:
				_play_resonance_gain_feedback(resonance_target)
				_spawn_unit_feedback(
					resonance_target,
					LocalizationManager.text("battle.float_resonance_gain", [resonance_amount]),
					Color(0.64, 0.88, 1.0, 1.0),
					20,
					-56.0,
					42.0,
					"resonance_gain"
				)
				_append_log(LocalizationManager.text("battle.log.resonance_apply", [
					_unit_display_name(resonance_target),
					resonance_amount
				]), "info")
		return
	if effect_type == "damage_per_target_resonance_consume_all":
		var target_unit: UnitState = payload.get("target", null) as UnitState
		var spent_layers: int = int(payload.get("layers", 0))
		if spent_layers > 0:
			SfxManager.play_resonance_burst(spent_layers)
			_play_resonance_burst_feedback(target_unit)
			_spawn_feedback_burst_for_unit(target_unit, BATTLE_ICON_RESONANCE, Color(0.74, 0.96, 1.0, 1.0), 4, 58.0, 24.0, 0.44)
			_shake_battlefield(clamp(0.28 + float(spent_layers) / 12.0, 0.28, 0.72))
			_spawn_unit_feedback(
				target_unit,
				LocalizationManager.text("battle.float_resonance_burst", [spent_layers]),
				Color(0.92, 0.98, 1.0, 1.0),
				20,
				-78.0,
				50.0,
				"resonance_burst"
			)
		if target_unit != null and spent_layers > 0:
			_append_log(LocalizationManager.text("battle.log.resonance_consume", [
				_unit_display_name(target_unit),
				spent_layers
			]), "action")
		return
	if effect_type == "damage_from_will_and_target_resonance":
		var combo_target: UnitState = payload.get("target", null) as UnitState
		var combo_layers: int = int(payload.get("resonance", 0))
		if combo_layers > 0:
			SfxManager.play_resonance_burst(combo_layers)
			_play_resonance_burst_feedback(combo_target)
			_spawn_feedback_burst_for_unit(combo_target, BATTLE_ICON_RESONANCE, Color(0.74, 0.96, 1.0, 1.0), 4, 58.0, 24.0, 0.44)
			_shake_battlefield(clamp(0.30 + float(combo_layers) / 11.0, 0.30, 0.76))
			_spawn_unit_feedback(
				combo_target,
				LocalizationManager.text("battle.float_resonance_burst", [combo_layers]),
				Color(0.92, 0.98, 1.0, 1.0),
				20,
				-78.0,
				50.0,
				"resonance_burst"
			)
		if combo_target != null and combo_layers > 0:
			_append_log(LocalizationManager.text("battle.log.resonance_consume", [
				_unit_display_name(combo_target),
				combo_layers
			]), "action")
		return
	if effect_type == "damage_resonant_all_consume":
		var total_layers: int = int(payload.get("layers", 0))
		if total_layers > 0:
			SfxManager.play_resonance_burst(total_layers)
			_shake_battlefield(clamp(0.34 + float(total_layers) / 14.0, 0.34, 0.82))
			for target_variant in payload.get("targets", []):
				var burst_target: UnitState = target_variant as UnitState
				if burst_target != null:
					_play_resonance_burst_feedback(burst_target)
					_spawn_feedback_burst_for_unit(burst_target, BATTLE_ICON_RESONANCE, Color(0.74, 0.96, 1.0, 1.0), 3, 52.0, 22.0, 0.40)
					_spawn_unit_feedback(
						burst_target,
						LocalizationManager.text("battle.float_resonance_burst", [1]),
						Color(0.92, 0.98, 1.0, 1.0),
						20,
						-78.0,
						50.0,
						"resonance_burst"
					)
		if total_layers > 0:
			_append_log(LocalizationManager.text("battle.log.resonance_consume_total", [total_layers]), "action")
		return
	if effect_type == "block":
		var block_amount: int = int(payload.get("amount", 0))
		if block_amount <= 0:
			return
		for target_variant in payload.get("targets", []):
			var block_target: UnitState = target_variant as UnitState
			if block_target == null:
				continue
			_spawn_feedback_ring_for_unit(block_target, Color(0.82, 0.92, 1.0, 1.0), Vector2(96, 96), -10.0, 0.28, 0.08, 0.66)
			if block_target == manager.player and player_actor_view != null:
				player_actor_view.play_block_absorb()
			else:
				var block_actor: CombatActorView = _enemy_actor_for_unit(block_target)
				if block_actor != null:
					block_actor.play_block_absorb()
			_spawn_unit_feedback(
				block_target,
				LocalizationManager.text("battle.float_block_gain", [block_amount]),
				Color(0.92, 0.97, 1.0, 1.0),
				20,
				-68.0,
				38.0,
				"block_gain"
			)
			_append_log(LocalizationManager.text("battle.log.block_gain", [_unit_display_name(block_target), block_amount]), "info")
		return
	if effect_type == "heal":
		var heal_amount: int = int(payload.get("amount", 0))
		if heal_amount <= 0:
			return
		for target_variant in payload.get("targets", []):
			var heal_target: UnitState = target_variant as UnitState
			if heal_target == null:
				continue
			_spawn_feedback_ring_for_unit(heal_target, Color(0.72, 1.0, 0.82, 1.0), Vector2(100, 100), -10.0, 0.30, 0.09, 0.72)
			if heal_target == manager.player and player_actor_view != null:
				player_actor_view.play_skill()
			else:
				var heal_actor: CombatActorView = _enemy_actor_for_unit(heal_target)
				if heal_actor != null:
					heal_actor.play_skill()
			_spawn_unit_feedback(
				heal_target,
				LocalizationManager.text("battle.float_heal", [heal_amount]),
				Color(0.82, 1.0, 0.88, 1.0),
				20,
				-74.0,
				40.0,
				"heal"
			)
			_append_log(LocalizationManager.text("battle.log.heal", [_unit_display_name(heal_target), heal_amount]), "info")
		return
	if effect_type == "gain_will":
		var will_gain: int = int(payload.get("amount", 0))
		if will_gain <= 0:
			return
		var will_target: UnitState = manager.player
		if player_actor_view != null:
			player_actor_view.play_skill()
		_spawn_feedback_ring_for_unit(will_target, Color(0.72, 0.84, 1.0, 1.0), Vector2(92, 92), -14.0, 0.28, 0.08, 0.70)
		_spawn_unit_feedback(
			will_target,
			LocalizationManager.text("battle.float_will_gain", [will_gain]),
			Color(0.86, 0.92, 1.0, 1.0),
			19,
			-104.0,
			36.0,
			"will_gain"
		)
		_append_log(LocalizationManager.text("battle.log.will_gain", [will_gain]), "info")
		return
	if effect_type == "consume_will":
		var will_spent: int = int(payload.get("amount", 0))
		if will_spent <= 0:
			return
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_will_spend", [will_spent]),
			Color(0.88, 0.84, 1.0, 1.0),
			19,
			-128.0,
			34.0,
			"will_spend"
		)
		_append_log(LocalizationManager.text("battle.log.will_spend", [will_spent]), "info")
		return
	if effect_type == "gain_energy":
		var energy_gain: int = int(payload.get("amount", 0))
		if energy_gain <= 0:
			return
		UI_MOTION.pulse(energy_panel, 0.96, 1.06, 0.08)
		var energy_anchor: Vector2 = _global_to_feedback_local(energy_panel.get_global_rect().get_center() + Vector2(0.0, -20.0))
		_spawn_floating_feedback(
			LocalizationManager.text("battle.float_energy_gain", [energy_gain]),
			energy_anchor,
			Color(1.0, 0.90, 0.58, 1.0),
			19,
			34.0,
			"energy_gain"
		)
		_append_log(LocalizationManager.text("battle.log.energy_gain", [energy_gain]), "info")
		return
	if effect_type == "gain_overload":
		var overload_gain: int = int(payload.get("amount", 0))
		if overload_gain <= 0:
			return
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_overload_gain", [overload_gain]),
			Color(1.0, 0.70, 0.52, 1.0),
			19,
			-150.0,
			34.0,
			"overload_gain"
		)
		_append_log(LocalizationManager.text("battle.log.overload_gain", [overload_gain]), "warning")
		return
	if effect_type == "reduce_overload":
		var overload_reduce: int = int(payload.get("amount", 0))
		if overload_reduce <= 0:
			return
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_overload_reduce", [overload_reduce]),
			Color(0.96, 0.86, 0.70, 1.0),
			19,
			-150.0,
			34.0,
			"overload_reduce"
		)
		_append_log(LocalizationManager.text("battle.log.overload_reduce", [overload_reduce]), "info")
		return
	if effect_type == "gain_echo" or effect_type == "set_echo_charges":
		var echo_amount: int = int(payload.get("amount", payload.get("charges", 0)))
		_spawn_feedback_ring_for_unit(manager.player, Color(0.80, 0.94, 1.0, 1.0), Vector2(104, 104), -18.0, 0.30, 0.08, 0.70)
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_echo_gain"),
			Color(0.84, 0.96, 1.0, 1.0),
			20,
			-178.0,
			38.0,
			"echo_gain"
		)
		if echo_amount > 0:
			_append_log(LocalizationManager.text("battle.log.echo_ready", [echo_amount]), "info")
		else:
			_append_log(LocalizationManager.text("battle.log.echo_ready_done"), "info")
		return
	if effect_type == "gain_radiance":
		var radiance_gain: int = int(payload.get("amount", 0))
		if radiance_gain <= 0:
			return
		_spawn_feedback_ring_for_unit(manager.player, Color(1.0, 0.92, 0.58, 1.0), Vector2(108, 108), -18.0, 0.30, 0.08, 0.72)
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_radiance_gain", [radiance_gain]),
			Color(1.0, 0.92, 0.58, 1.0),
			20,
			-154.0,
			38.0,
			"energy_gain"
		)
		return
	if effect_type == "gain_counter":
		var counter_gain: int = int(payload.get("amount", 0))
		if counter_gain <= 0:
			return
		_spawn_feedback_ring_for_unit(manager.player, Color(0.92, 0.98, 1.0, 1.0), Vector2(104, 104), -16.0, 0.26, 0.08, 0.70)
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_counter_gain", [counter_gain]),
			Color(0.86, 0.96, 1.0, 1.0),
			20,
			-138.0,
			34.0,
			"block_gain"
		)
		return
	if effect_type == "reduce_next_damage":
		var reduction_gain: int = int(payload.get("amount", 0))
		if reduction_gain <= 0:
			return
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_next_damage_reduction", [reduction_gain]),
			Color(0.82, 0.94, 1.0, 1.0),
			19,
			-142.0,
			34.0,
			"block_gain"
		)
		_append_log(LocalizationManager.text("battle.log.next_damage_reduction", [reduction_gain]), "info")
		return
	if effect_type in ["channel", "channel_damage_will", "channel_damage_turn_end", "channel_echo_next_turn"]:
		_spawn_feedback_ring_for_unit(manager.player, Color(0.78, 0.88, 1.0, 1.0), Vector2(112, 112), -24.0, 0.32, 0.08, 0.72)
		_spawn_unit_feedback(
			manager.player,
			LocalizationManager.text("battle.float_channel_ready"),
			Color(0.88, 0.94, 1.0, 1.0),
			20,
			-206.0,
			40.0,
			"channel_ready"
		)
		_append_log(LocalizationManager.text("battle.log.channel_ready"), "info")
		return
	if effect_type == "gain_ammo" or effect_type == "set_max_ammo_bonus":
		var ammo_gain: int = int(payload.get("amount", 0))
		if ammo_gain <= 0:
			return
		SfxManager.play_reload(ammo_gain)
		_spawn_feedback_ring_for_unit(manager.player, Color(0.70, 0.94, 1.0, 1.0), Vector2(106, 106), -18.0, 0.26, 0.08, 0.72)
		_spawn_unit_feedback(
			manager.player,
			_battle_text("装填 +%d" % ammo_gain, "Reload +%d" % ammo_gain),
			Color(0.82, 0.96, 1.0, 1.0),
			19,
			-134.0,
			34.0,
			"reload"
		)
		_append_log(_battle_text("能天使装填了 %d 发弹药。" % ammo_gain, "Exusiai reloads %d Ammo." % ammo_gain), "info")
		return
	if effect_type == "consume_ammo":
		var ammo_spent: int = int(payload.get("amount", 0))
		if ammo_spent <= 0:
			return
		_spawn_unit_feedback(
			manager.player,
			_battle_text("弹药 -%d" % ammo_spent, "Ammo -%d" % ammo_spent),
			Color(0.84, 0.94, 1.0, 1.0),
			18,
			-132.0,
			30.0,
			"reload"
		)
		return
	if effect_type == "queue_reload":
		var reload_entry: Dictionary = payload.get("entry", {})
		var queued_amount: int = int(reload_entry.get("amount", 0))
		SfxManager.play_reload(max(1, queued_amount))
		_spawn_unit_feedback(
			manager.player,
			_battle_text("待装填", "Reload Queued"),
			Color(0.82, 0.96, 1.0, 1.0),
			18,
			-154.0,
			30.0,
			"reload"
		)
		return
	if effect_type == "apply_mark":
		var mark_amount: int = int(payload.get("amount", 0))
		if mark_amount <= 0:
			return
		SfxManager.play_mark_apply(mark_amount)
		for target_variant in payload.get("targets", []):
			var mark_target: UnitState = target_variant as UnitState
			if mark_target == null:
				continue
			_spawn_feedback_ring_for_unit(mark_target, Color(1.0, 0.62, 0.72, 1.0), Vector2(104, 104), -14.0, 0.30, 0.08, 0.74)
			_spawn_unit_feedback(
				mark_target,
				_battle_text("标记 +%d" % mark_amount, "Mark +%d" % mark_amount),
				Color(1.0, 0.78, 0.84, 1.0),
				20,
				-82.0,
				40.0,
				"mark"
			)
			_append_log(_battle_text("%s 被锁定了 %d 层标记。" % [_unit_display_name(mark_target), mark_amount], "%s gains %d Mark." % [_unit_display_name(mark_target), mark_amount]), "warning")
		return
	if effect_type == "consume_mark":
		var consumed_mark: int = int(payload.get("amount", 0))
		var mark_target_unit: UnitState = payload.get("target", null) as UnitState
		if consumed_mark <= 0 or mark_target_unit == null:
			return
		_spawn_feedback_burst_for_unit(mark_target_unit, BATTLE_ICON_MARK, Color(1.0, 0.72, 0.78, 1.0), 4, 50.0, 22.0, 0.34)
		_spawn_unit_feedback(
			mark_target_unit,
			_battle_text("标记引爆 ×%d" % consumed_mark, "Mark Burst x%d" % consumed_mark),
			Color(1.0, 0.82, 0.86, 1.0),
			20,
			-100.0,
			42.0,
			"mark"
		)
		return
	if effect_type == "enter_burst":
		if manager != null and manager.player_character != null and manager.player_character.id == "exusiai":
			_spawn_feedback_ring_for_unit(manager.player, Color(1.0, 0.78, 0.48, 1.0), Vector2(112, 112), -18.0, 0.28, 0.08, 0.58)
			_spawn_unit_feedback(
				manager.player,
				_battle_text("爆发准备", "Burst Prepared"),
				Color(1.0, 0.86, 0.58, 1.0),
				20,
				-168.0,
				36.0,
				"burst"
			)
			_append_log(_battle_text("能天使准备爆发，下回合进入爆发射击。", "Exusiai prepares Burst for next turn."), "action")
			return
	if effect_type == "burst_activated":
		SfxManager.play_burst_fire()
		if player_actor_view != null:
			player_actor_view.play_resonance_burst()
		_spawn_feedback_ring_for_unit(manager.player, Color(1.0, 0.86, 0.58, 1.0), Vector2(136, 136), -22.0, 0.36, 0.10, 0.84)
		_spawn_feedback_burst_for_unit(manager.player, BATTLE_ICON_BURST, Color(1.0, 0.90, 0.62, 1.0), 8, 74.0, 22.0, 0.40)
		_shake_battlefield(0.22)
		_spawn_unit_feedback(
			manager.player,
			_battle_text("爆发射击", "Burst Fire"),
			Color(1.0, 0.90, 0.64, 1.0),
			22,
			-182.0,
			42.0,
			"burst"
		)
		_append_log(_battle_text("能天使进入爆发射击状态。", "Exusiai enters Burst Fire."), "action")
		return
	if effect_type == "exit_burst":
		_spawn_unit_feedback(
			manager.player,
			_battle_text("爆发结束", "Burst Ends"),
			Color(0.94, 0.88, 0.74, 1.0),
			18,
			-182.0,
			30.0,
			"burst"
		)
		return
	if effect_type == "apply_status":
		var status_profile: Dictionary = _status_feedback_visual(String(payload.get("status_id", "")))
		if status_profile.is_empty():
			return
		var status_amount: int = int(payload.get("amount", 0))
		for target_variant in payload.get("targets", []):
			var status_target: UnitState = target_variant as UnitState
			if status_target == null:
				continue
			if status_target == manager.player and player_actor_view != null:
				player_actor_view.play_skill()
			else:
				var status_actor: CombatActorView = _enemy_actor_for_unit(status_target)
				if status_actor != null:
					status_actor.play_skill()
			_spawn_unit_feedback(
				status_target,
				LocalizationManager.text(String(status_profile.get("text_key", "")), [status_amount]),
				status_profile.get("tint", Color.WHITE),
				18,
				-92.0,
				36.0,
				String(status_profile.get("style_kind", "default"))
			)
			_append_log(LocalizationManager.text("battle.log.status_gain", [
				_unit_display_name(status_target),
				String(status_profile.get("log_name", LocalizationManager.text("card.rarity_status")))
			]), "warning")
		return
	if effect_type == "team_debuff":
		var team_profile: Dictionary = _status_feedback_visual(String(payload.get("status_id", "")))
		if team_profile.is_empty():
			return
		var team_amount: int = int(payload.get("amount", 0))
		for target_variant in payload.get("targets", []):
			var debuff_target: UnitState = target_variant as UnitState
			if debuff_target == null:
				continue
			var debuff_actor: CombatActorView = _enemy_actor_for_unit(debuff_target)
			if debuff_actor != null:
				debuff_actor.play_skill()
			_spawn_unit_feedback(
				debuff_target,
				LocalizationManager.text(String(team_profile.get("text_key", "")), [team_amount]),
				team_profile.get("tint", Color.WHITE),
				18,
				-92.0,
				36.0,
				String(team_profile.get("style_kind", "default"))
			)
		_append_log(LocalizationManager.text("battle.log.team_debuff", [String(team_profile.get("log_name", LocalizationManager.text("battle.status_name_debuff")))]), "warning")
		return
	if effect_type != "damage":
		return
	var amount: int = int(payload.get("amount", 0))
	var absorbed: int = int(payload.get("absorbed", 0))
	var damage_before_block: int = int(payload.get("damage_before_block", 0))
	var damage_type: String = String(payload.get("damage_type", "normal"))
	var card_tags: Array = payload.get("card_tags", [])
	var is_shot_damage: bool = card_tags.has("Shot")
	var is_finisher_damage: bool = card_tags.has("Finisher")
	var block_broken: bool = bool(payload.get("block_broken", false))
	var impact_amount: int = max(amount, damage_before_block)
	if impact_amount <= 0 and absorbed <= 0:
		return
	if is_finisher_damage:
		SfxManager.play_finisher_hit()
	elif is_shot_damage:
		SfxManager.play_shot_hit(max(1, impact_amount))
	else:
		SfxManager.play_attack_hit(max(1, impact_amount))
	var source_unit: UnitState = payload.get("source") as UnitState
	var target_unit: UnitState = payload.get("target") as UnitState
	if source_unit == manager.player and player_actor_view != null:
		player_actor_view.play_attack()
	elif source_unit != null:
		var source_enemy_actor: CombatActorView = _enemy_actor_for_unit(source_unit)
		if source_enemy_actor != null:
			source_enemy_actor.play_attack()
	if target_unit == manager.player and player_actor_view != null:
		if absorbed > 0:
			player_actor_view.play_block_absorb()
		if block_broken:
			player_actor_view.play_block_break()
		if amount > 0:
			player_actor_view.play_hit()
			_shake_battlefield(clamp(0.75 + float(amount) / 18.0, 0.85, 1.45))
	elif target_unit != null:
		var target_enemy_actor: CombatActorView = _enemy_actor_for_unit(target_unit)
		if target_enemy_actor != null:
			if absorbed > 0:
				target_enemy_actor.play_block_absorb()
			if block_broken:
				target_enemy_actor.play_block_break()
			if amount > 0:
				target_enemy_actor.play_hit()
		if amount > 0:
			_shake_battlefield(clamp(0.34 + float(amount) / 26.0, 0.34, 0.88))
	var source_name: String = _unit_display_name(source_unit)
	var target_name: String = _unit_display_name(target_unit)
	if absorbed > 0:
		_spawn_unit_feedback(
			target_unit,
			LocalizationManager.text("battle.float_block_loss", [absorbed]),
			Color(0.92, 0.97, 1.0, 1.0),
			19,
			-12.0,
			34.0,
			"block_loss"
		)
		_append_log(LocalizationManager.text("battle.log.block_absorb", [target_name, absorbed]), "info")
	if block_broken:
		_spawn_feedback_ring_for_unit(target_unit, Color(1.0, 0.90, 0.68, 1.0), Vector2(118, 118), -8.0, 0.34, 0.08, 0.82)
		_spawn_feedback_burst_for_unit(target_unit, BATTLE_ICON_BLOCK, Color(1.0, 0.92, 0.68, 1.0), 5, 62.0, 22.0, 0.38)
		_shake_battlefield(0.24)
		_spawn_unit_feedback(
			target_unit,
			LocalizationManager.text("battle.float_block_break"),
			Color(1.0, 0.92, 0.62, 1.0),
			19,
			-68.0,
			40.0,
			"block_break"
		)
		_append_log(LocalizationManager.text("battle.log.block_break", [target_name]), "warning")
	if amount > 0:
		_play_damage_impact_feedback(source_unit, target_unit, amount, damage_type, is_shot_damage, is_finisher_damage)
		var damage_style_kind: String = "arts_damage" if damage_type == "arts" else "damage"
		var damage_tint: Color = Color(0.72, 0.92, 1.0, 1.0) if damage_type == "arts" else Color(1.0, 0.48, 0.42, 1.0)
		if is_shot_damage:
			damage_style_kind = "shot_damage"
			damage_tint = Color(0.82, 0.96, 1.0, 1.0)
		if is_finisher_damage:
			damage_style_kind = "finisher_damage"
			damage_tint = Color(1.0, 0.88, 0.60, 1.0)
		if amount >= 12:
			var damage_icon: Texture2D = BATTLE_ICON_ARTS if damage_type == "arts" else BATTLE_ICON_DAMAGE
			var damage_burst_tint: Color = Color(0.78, 0.96, 1.0, 1.0) if damage_type == "arts" else Color(1.0, 0.64, 0.58, 1.0)
			if is_shot_damage:
				damage_icon = BATTLE_ICON_AMMO
				damage_burst_tint = Color(0.72, 0.96, 1.0, 1.0)
			if is_finisher_damage:
				damage_icon = BATTLE_ICON_BURST
				damage_burst_tint = Color(1.0, 0.86, 0.56, 1.0)
			_spawn_feedback_burst_for_unit(target_unit, damage_icon, damage_burst_tint, 3, 50.0, 18.0, 0.30)
		if is_finisher_damage:
			_shake_battlefield(clamp(0.72 + float(amount) / 24.0, 0.72, 1.28))
		elif is_shot_damage:
			_shake_battlefield(clamp(0.24 + float(amount) / 34.0, 0.24, 0.62))
		var damage_feedback_text: String = LocalizationManager.text("battle.float_damage", [amount])
		var damage_font_size: int = 24
		if target_unit == manager.player and source_unit != manager.player:
			damage_feedback_text = LocalizationManager.text("battle.float_damage_detail", [source_name, target_name, amount])
			damage_font_size = 22
		_spawn_unit_feedback(
			target_unit,
			damage_feedback_text,
			damage_tint,
			damage_font_size,
			-44.0,
			56.0,
			damage_style_kind
		)
		_append_log(LocalizationManager.text("battle.log.damage_detail", [source_name, target_name, amount]), "warning" if target_unit == manager.player else "action")

func _on_turn_started(side: String) -> void:
	if end_turn_button != null:
		end_turn_button.disabled = side != "player" or manager.battle_finished
	if side == "player":
		_clear_enemy_action_focus()
		for enemy in manager.enemies:
			if _enemy_is_bomb_threat(enemy):
				SfxManager.play_w_warning()
				break
	if side == "enemy":
		_clear_enemy_action_focus()

func _play_enemy_intent_telegraph(enemy: UnitState, intent: Dictionary) -> void:
	if enemy == null:
		return
	var intent_visual: Dictionary = _intent_visuals(enemy, intent)
	var telegraph_tint: Color = intent_visual.get("color", Color(1.0, 0.82, 0.34, 1.0))
	var badge_icon: Texture2D = intent_visual.get("icon_texture", INTENT_ICON_SPECIAL) as Texture2D
	var intent_type: String = String(intent.get("type", "attack"))
	var ring_size: Vector2 = Vector2(118, 118)
	var burst_count: int = 3
	var burst_radius: float = 44.0
	match intent_type:
		"release":
			ring_size = Vector2(144, 144)
			burst_count = 5
			burst_radius = 58.0
		"attack":
			ring_size = Vector2(132, 132)
			burst_count = 4
			burst_radius = 52.0
		"gain_block":
			ring_size = Vector2(120, 120)
			burst_count = 3
			burst_radius = 42.0
		"apply_curse", "shuffle_and_debuff", "apply_debuff", "rule_shift":
			ring_size = Vector2(128, 128)
			burst_count = 4
			burst_radius = 50.0
		"charge":
			ring_size = Vector2(124, 124)
			burst_count = 4
			burst_radius = 48.0
	_spawn_feedback_ring_for_unit(enemy, telegraph_tint, ring_size, -16.0, 0.24, 0.08, 0.84)
	_spawn_feedback_burst_for_unit(enemy, badge_icon, telegraph_tint, burst_count, burst_radius, 18.0, 0.24)

func _on_enemy_action_started(enemy: UnitState, intent: Dictionary) -> void:
	_clear_enemy_action_focus()
	var actor_view: CombatActorView = _enemy_actor_for_unit(enemy)
	if actor_view == null:
		return
	var intent_type: String = String(intent.get("type", "attack"))
	_play_enemy_intent_telegraph(enemy, intent)
	actor_view.set_action_focus(true)
	actor_view.play_intent_pulse(1.18 if intent_type == "release" else (1.14 if intent_type == "attack" else 1.10))
	match intent_type:
		"attack":
			actor_view.play_attack()
			SfxManager.play_attack_hit()
		"release":
			actor_view.play_attack()
			SfxManager.play_finisher_hit()
			_shake_battlefield(0.16)
		"gain_block":
			actor_view.play_block_absorb()
		"apply_curse", "shuffle_and_debuff", "apply_debuff", "rule_shift":
			actor_view.play_arts()
			if _enemy_is_bomb_threat(enemy):
				SfxManager.play_w_warning()
			else:
				SfxManager.play_card_play()
		"charge":
			actor_view.play_support()
			_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_charge"), Color(1.0, 0.78, 0.38, 1.0), 22, -76.0, 46.0, "finisher_damage")
		_:
			actor_view.play_skill()

func _on_enemy_action_resolved(enemy: UnitState, intent: Dictionary, result: Dictionary) -> void:
	var result_type: String = String(result.get("type", intent.get("type", "")))
	match result_type:
		"attack":
			var mon3tr_damage: int = int(result.get("mon3tr_damage", 0))
			var attack_amount: int = int(result.get("amount", 0))
			var absorbed_amount: int = int(result.get("absorbed", 0))
			var reduced_amount: int = int(result.get("reduced", 0))
			if mon3tr_damage > 0:
				var mon3tr_unit: UnitState = manager.mon3tr_display_unit()
				_spawn_unit_feedback(mon3tr_unit, LocalizationManager.text("battle.float_integrity_loss", [mon3tr_damage]), Color(0.78, 1.0, 0.82, 1.0), 20, -78.0, 44.0, "block_gain")
				if mon3tr_actor_view != null and is_instance_valid(mon3tr_actor_view):
					mon3tr_actor_view.play_hit()
			_play_enemy_attack_resolution_feedback(enemy, attack_amount, absorbed_amount, reduced_amount)
			if bool(result.get("block_broken", false)) and player_actor_view != null:
				player_actor_view.play_block_break()
			var counter_damage: int = int(result.get("counter_damage", 0))
			if counter_damage > 0:
				_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_counter_damage", [counter_damage]), Color(1.0, 0.94, 0.68, 1.0), 22, -92.0, 48.0, "finisher_damage")
				_spawn_feedback_burst_for_unit(enemy, SUPPORT_TILE_NEARL, Color(1.0, 0.92, 0.58, 1.0), 4, 54.0, 18.0, 0.30)
				if player_actor_view != null:
					player_actor_view.play_skill()
		"gain_block":
			var block_amount: int = int(result.get("amount", 0))
			if block_amount > 0:
				_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_enemy_block_gain", [block_amount]), Color(0.86, 0.96, 1.0, 1.0), 24, -68.0, 52.0, "block_gain")
		"apply_debuff":
			_spawn_enemy_status_action_feedback(result)
		"apply_curse":
			var curse_count: int = max(1, int(result.get("amount", 1)))
			_play_curse_card_insert_feedback(String(result.get("status_id", "hesitation")), curse_count, enemy)
			_spawn_unit_feedback(manager.player, LocalizationManager.text("battle.float_curse_insert", [curse_count]), Color(0.96, 0.76, 1.0, 1.0), 22, -70.0, 52.0, "status_vulnerable")
		"shuffle_and_debuff":
			_play_deck_disruption_feedback(enemy)
			_spawn_unit_feedback(manager.player, LocalizationManager.text("battle.float_deck_disrupt"), Color(0.96, 0.76, 1.0, 1.0), 22, -70.0, 52.0, "status_weak")
		"rule_shift":
			_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_rule_shift"), Color(1.0, 0.86, 0.46, 1.0), 22, -72.0, 52.0, "finisher_damage")
		"charge":
			var charge_amount: int = int(result.get("amount", 0))
			_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_charge_gain", [charge_amount]), Color(1.0, 0.78, 0.38, 1.0), 22, -72.0, 52.0, "finisher_damage")
		"release":
			var release_mon3tr_damage: int = int(result.get("mon3tr_damage", 0))
			var release_absorbed: int = int(result.get("absorbed", 0))
			var release_reduced: int = int(result.get("reduced", 0))
			if release_mon3tr_damage > 0:
				var release_mon3tr_unit: UnitState = manager.mon3tr_display_unit()
				_spawn_unit_feedback(release_mon3tr_unit, LocalizationManager.text("battle.float_integrity_loss", [release_mon3tr_damage]), Color(1.0, 0.86, 0.64, 1.0), 20, -82.0, 48.0, "finisher_damage")
				if mon3tr_actor_view != null and is_instance_valid(mon3tr_actor_view):
					mon3tr_actor_view.play_block_break()
			var release_amount: int = int(result.get("amount", 0))
			_play_enemy_attack_resolution_feedback(enemy, release_amount, release_absorbed, release_reduced, true)
			if bool(result.get("block_broken", false)) and player_actor_view != null:
				player_actor_view.play_block_break()
			var release_counter_damage: int = int(result.get("counter_damage", 0))
			if release_counter_damage > 0:
				_spawn_unit_feedback(enemy, LocalizationManager.text("battle.float_counter_damage", [release_counter_damage]), Color(1.0, 0.94, 0.68, 1.0), 22, -92.0, 48.0, "finisher_damage")
				_spawn_feedback_burst_for_unit(enemy, SUPPORT_TILE_NEARL, Color(1.0, 0.92, 0.58, 1.0), 4, 54.0, 18.0, 0.30)
				if player_actor_view != null:
					player_actor_view.play_skill()
			_shake_battlefield(0.50)
	var text: String = String(result.get("text", ""))
	if not text.is_empty():
		_append_log(text, "warning" if result.get("target", null) == manager.player else "action")

func _spawn_enemy_status_action_feedback(result: Dictionary) -> void:
	var status_id: String = String(result.get("status_id", ""))
	var status_amount: int = max(1, int(result.get("status_amount", 1)))
	var visual: Dictionary = _status_feedback_visual(status_id)
	var text_key: String = String(visual.get("text_key", ""))
	var feedback_text: String = "%s +%d" % [status_id, status_amount]
	if not text_key.is_empty():
		feedback_text = LocalizationManager.text(text_key, [status_amount])
	_spawn_unit_feedback(
		manager.player,
		feedback_text,
		visual.get("tint", Color(0.96, 0.76, 1.0, 1.0)),
		22,
		-70.0,
		52.0,
		String(visual.get("style_kind", "status_vulnerable"))
	)

func _play_damage_impact_feedback(source_unit: UnitState, target_unit: UnitState, amount: int, damage_type: String, is_shot_damage: bool, is_finisher_damage: bool) -> void:
	if source_unit == null or target_unit == null or amount <= 0:
		return
	var is_player_attack: bool = source_unit == manager.player and target_unit != manager.player
	var is_enemy_attack: bool = target_unit == manager.player and source_unit != manager.player
	if not is_player_attack and not is_enemy_attack:
		return
	var tint: Color = Color(1.0, 0.58, 0.46, 1.0)
	if damage_type == "arts":
		tint = Color(0.68, 0.92, 1.0, 1.0)
	if is_shot_damage:
		tint = Color(0.78, 0.96, 1.0, 1.0)
	if is_finisher_damage:
		tint = Color(1.0, 0.86, 0.52, 1.0)
	var source_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(source_unit))
	var target_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(target_unit))
	var trace_width: float = 5.0 if is_player_attack else 7.0
	var trace_duration: float = 0.22 if is_player_attack else 0.28
	_spawn_attack_trace(source_point, target_point, tint, trace_width, trace_duration)
	if is_player_attack:
		_spawn_impact_slash_cluster(target_unit, tint, amount >= 14 or is_finisher_damage)
		_spawn_feedback_ring_for_unit(target_unit, tint, Vector2(104, 104), -8.0, 0.24, 0.06, 0.72)
		if amount >= 10 or is_finisher_damage:
			_spawn_feedback_ring_for_unit(target_unit, tint, Vector2(138, 138), -8.0, 0.34, 0.05, 0.58)
	else:
		_spawn_feedback_ring_for_unit(target_unit, Color(1.0, 0.32, 0.28, 1.0), Vector2(132, 132), -12.0, 0.30, 0.10, 0.88)
		_spawn_feedback_burst_for_unit(target_unit, BATTLE_ICON_DAMAGE, Color(1.0, 0.46, 0.38, 1.0), 5, 62.0, 20.0, 0.34)
		_spawn_impact_slash_cluster(target_unit, Color(1.0, 0.34, 0.30, 1.0), amount >= 12)
		_flash_player_damage(amount)

func _play_enemy_attack_resolution_feedback(enemy: UnitState, damage_amount: int, absorbed_amount: int, reduced_amount: int = 0, is_release: bool = false) -> void:
	if enemy == null or manager == null or manager.player == null:
		return
	var tint: Color = Color(1.0, 0.76, 0.62, 1.0) if not is_release else Color(1.0, 0.86, 0.54, 1.0)
	var source_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(enemy))
	var player_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(manager.player))
	_spawn_attack_trace(source_point, player_point, tint, 7.0 if not is_release else 8.0, 0.26 if not is_release else 0.30)
	var enemy_text: String = LocalizationManager.text("battle.float_strike", [max(damage_amount + absorbed_amount + reduced_amount, damage_amount)])
	if is_release:
		enemy_text = LocalizationManager.text("battle.float_release", [max(damage_amount + absorbed_amount + reduced_amount, damage_amount)])
	if damage_amount > 0 or absorbed_amount > 0 or reduced_amount > 0:
		_spawn_unit_feedback(enemy, enemy_text, tint, 18, -98.0, 30.0, "finisher_damage" if is_release else "damage")
	var parts: Array[String] = []
	if reduced_amount > 0:
		parts.append(LocalizationManager.text("battle.float_reduced", [reduced_amount]))
	if absorbed_amount > 0:
		parts.append(LocalizationManager.text("battle.float_blocked", [absorbed_amount]))
	if damage_amount > 0:
		parts.append(LocalizationManager.text("event.preview_hp_lose", [damage_amount]))
	elif absorbed_amount > 0 or reduced_amount > 0:
		parts.append(LocalizationManager.text("battle.float_fully_blocked"))
	if not parts.is_empty():
		var player_text: String = "\n".join(parts)
		_spawn_unit_feedback(
			manager.player,
			player_text,
			Color(1.0, 0.88, 0.76, 1.0) if damage_amount > 0 else Color(0.88, 0.98, 1.0, 1.0),
			21 if damage_amount > 0 else 20,
			-112.0,
			50.0,
			"damage" if damage_amount > 0 else "block_break"
		)
	if damage_amount > 0 and player_actor_view != null:
		player_actor_view.play_hit()
		_shake_battlefield(clamp(0.75 + float(damage_amount) / 18.0, 0.85, 1.45))
	elif damage_amount <= 0 and absorbed_amount > 0 and player_actor_view != null:
		player_actor_view.play_block_absorb()

func _spawn_attack_trace(start_point: Vector2, end_point: Vector2, tint: Color, width: float = 5.0, duration: float = 0.22) -> void:
	if not is_instance_valid(battle_feedback_layer):
		return
	var direction: Vector2 = end_point - start_point
	if direction.length() <= 4.0:
		return
	var normal: Vector2 = direction.normalized().orthogonal()
	var mid_point: Vector2 = start_point.lerp(end_point, 0.62) + normal * randf_range(-18.0, 18.0)
	var line := Line2D.new()
	line.z_index = 760
	line.width = width
	line.default_color = Color(tint.r, tint.g, tint.b, 0.86)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.points = PackedVector2Array([start_point, mid_point, end_point])
	line.modulate = Color(1, 1, 1, 0)
	battle_feedback_layer.add_child(line)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(line, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "width", maxf(width * 0.34, 1.5), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(line, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		line.queue_free()
	)

func _spawn_impact_slash_cluster(unit: UnitState, tint: Color, strong: bool = false) -> void:
	if unit == null or not is_instance_valid(battle_feedback_layer):
		return
	var center: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(unit))
	var slash_count: int = 4 if strong else 3
	var slash_length: float = 78.0 if strong else 56.0
	for index in range(slash_count):
		var angle: float = randf_range(-0.72, 0.72) + (PI * 0.10)
		var axis: Vector2 = Vector2(cos(angle), sin(angle))
		var offset: Vector2 = Vector2(randf_range(-24.0, 24.0), randf_range(-18.0, 20.0))
		var slash_center: Vector2 = center + offset
		var line := Line2D.new()
		line.z_index = 770 + index
		line.width = 5.0 if strong else 4.0
		line.default_color = Color(tint.r, tint.g, tint.b, 0.92)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.points = PackedVector2Array([
			slash_center - axis * slash_length * 0.5,
			slash_center + axis * slash_length * 0.5
		])
		line.modulate = Color(1, 1, 1, 0)
		line.scale = Vector2(0.40, 0.40)
		battle_feedback_layer.add_child(line)
		var tween: Tween = _make_scene_tween()
		if tween == null:
			return
		tween.set_parallel(true)
		tween.tween_property(line, "modulate:a", 1.0, 0.04 + float(index) * 0.01).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(line, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(line, "width", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(line, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(func() -> void:
			line.queue_free()
		)

func _play_curse_card_insert_feedback(curse_id: String, curse_count: int, enemy: UnitState) -> void:
	if manager == null or manager.card_db == null or not manager.card_db.has(curse_id) or not is_instance_valid(battle_feedback_layer):
		return
	var curse_card: CardData = manager.card_db.get(curse_id, null) as CardData
	if curse_card == null:
		return
	var card_size := Vector2(136, 200)
	var card_clone: Button = CARD_DISPLAY_FACTORY.create_card_button(
		curse_card,
		LocalizationManager.card_name(curse_card),
		LocalizationManager.card_description(curse_card),
		_display_card_cost(curse_card),
		Util.load_card_art(curse_card.id),
		card_size,
		true,
		CARD_DISPLAY_FACTORY.has_upgrade_visual(curse_card)
	)
	card_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_clone.z_index = 850
	card_clone.pivot_offset = card_size * 0.5
	card_clone.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card_clone.scale = Vector2(0.58, 0.58)
	var source_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(enemy if enemy != null else manager.player))
	var center_point: Vector2 = _global_to_feedback_local(arena.get_global_rect().get_center()) + Vector2(0.0, -40.0)
	var discard_point: Vector2 = _global_to_feedback_local(discard_chip.get_global_rect().get_center())
	card_clone.position = source_point - card_size * 0.5
	battle_feedback_layer.add_child(card_clone)

	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.z_index = 830
	dim.color = Color(0.08, 0.04, 0.12, 0.0)
	battle_feedback_layer.add_child(dim)
	battle_feedback_layer.move_child(dim, max(0, card_clone.get_index()))

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 852
	badge.add_theme_stylebox_override("panel", _make_feedback_badge_style(Color(0.18, 0.08, 0.24, 0.94), Color(0.96, 0.76, 1.0, 0.88), Color(0.20, 0.05, 0.28, 0.35)))
	var badge_margin := MarginContainer.new()
	badge_margin.add_theme_constant_override("margin_left", 10)
	badge_margin.add_theme_constant_override("margin_right", 10)
	badge_margin.add_theme_constant_override("margin_top", 6)
	badge_margin.add_theme_constant_override("margin_bottom", 6)
	badge.add_child(badge_margin)
	var badge_label := Label.new()
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var curse_name: String = LocalizationManager.card_name(curse_card)
	if curse_count > 1:
		badge_label.text = LocalizationManager.text("battle.curse_insert_multi", [curse_name, curse_count])
	else:
		badge_label.text = LocalizationManager.text("battle.curse_insert_single", [curse_name])
	badge_label.add_theme_font_size_override("font_size", 18)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.88, 1.0, 1.0))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_margin.add_child(badge_label)
	battle_feedback_layer.add_child(badge)
	badge.custom_minimum_size = Vector2(260, 0)
	badge.position = center_point + Vector2(-130.0, -144.0)
	badge.modulate = Color(1, 1, 1, 0)

	_spawn_feedback_ring_for_unit(manager.player, Color(0.94, 0.62, 1.0, 1.0), Vector2(138, 138), -16.0, 0.34, 0.09, 0.76)
	if enemy != null:
		_spawn_attack_trace(source_point, center_point, Color(0.94, 0.62, 1.0, 1.0), 5.0, 0.24)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(dim, "color:a", 0.28, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_clone, "position", center_point - card_size * 0.5, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_clone, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_clone, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.42)
	tween.chain().set_parallel(true)
	tween.tween_property(card_clone, "position", discard_point - card_size * 0.5, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card_clone, "scale", Vector2(0.34, 0.34), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card_clone, "rotation_degrees", randf_range(-10.0, 10.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card_clone, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(badge, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(dim, "color:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(card_clone):
			card_clone.queue_free()
		if is_instance_valid(badge):
			badge.queue_free()
		if is_instance_valid(dim):
			dim.queue_free()
		_pulse_discard_chip()
	)

func _play_deck_disruption_feedback(enemy: UnitState) -> void:
	if not is_instance_valid(battle_feedback_layer):
		return
	var source_point: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(enemy if enemy != null else manager.player))
	var deck_point: Vector2 = _global_to_feedback_local(deck_chip.get_global_rect().get_center())
	var discard_point: Vector2 = _global_to_feedback_local(discard_chip.get_global_rect().get_center())
	_spawn_attack_trace(source_point, deck_point, Color(0.80, 0.58, 1.0, 1.0), 5.0, 0.24)
	_spawn_attack_trace(deck_point, discard_point, Color(0.80, 0.58, 1.0, 1.0), 4.0, 0.22)
	_spawn_feedback_ring(_global_to_feedback_local(deck_chip.get_global_rect().get_center()), Color(0.88, 0.68, 1.0, 1.0), Vector2(84, 84), 0.28, 0.08, 0.74)
	_pulse_discard_chip()

func _pulse_discard_chip() -> void:
	if discard_chip == null:
		return
	discard_chip.pivot_offset = discard_chip.size * 0.5
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.tween_property(discard_chip, "scale", Vector2(1.10, 1.10), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(discard_chip, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_enemy_turn_sequence_finished() -> void:
	_clear_enemy_action_focus()

func _clear_enemy_action_focus() -> void:
	for actor_view in enemy_actor_views:
		if actor_view != null:
			actor_view.set_action_focus(false)

func _enemy_actor_for_unit(unit: UnitState) -> CombatActorView:
	for i in range(min(manager.enemies.size(), enemy_actor_views.size())):
		if manager.enemies[i] == unit:
			return enemy_actor_views[i]
	return null

func _play_resonance_gain_feedback(target_unit: UnitState) -> void:
	if target_unit == null:
		return
	_spawn_feedback_ring_for_unit(target_unit, Color(0.64, 0.88, 1.0, 1.0), Vector2(104, 104), -10.0, 0.34, 0.10, 0.70)
	if target_unit == manager.player and player_actor_view != null:
		player_actor_view.play_resonance_gain()
		return
	var target_enemy_actor: CombatActorView = _enemy_actor_for_unit(target_unit)
	if target_enemy_actor != null:
		target_enemy_actor.play_resonance_gain()

func _play_resonance_burst_feedback(target_unit: UnitState) -> void:
	if target_unit == null:
		return
	_spawn_feedback_ring_for_unit(target_unit, Color(0.60, 0.88, 1.0, 1.0), Vector2(132, 132), -12.0, 0.42, 0.14, 0.88)
	if target_unit == manager.player and player_actor_view != null:
		player_actor_view.play_resonance_burst()
		return
	var target_enemy_actor: CombatActorView = _enemy_actor_for_unit(target_unit)
	if target_enemy_actor != null:
		target_enemy_actor.play_resonance_burst()

func _spawn_feedback_ring_for_unit(unit: UnitState, tint: Color, size: Vector2, y_offset: float = -12.0, duration: float = 0.36, fill_alpha: float = 0.10, outline_alpha: float = 0.82) -> void:
	if unit == null:
		return
	var anchor_point: Vector2 = _feedback_global_anchor_for_unit(unit) + Vector2(0.0, y_offset)
	_spawn_feedback_ring(_global_to_feedback_local(anchor_point), tint, size, duration, fill_alpha, outline_alpha)

func _spawn_feedback_ring(local_position: Vector2, tint: Color, size: Vector2, duration: float = 0.36, fill_alpha: float = 0.10, outline_alpha: float = 0.82) -> void:
	if not is_instance_valid(battle_feedback_layer):
		return
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = size
	ring.position = local_position - size * 0.5
	ring.modulate = Color(1, 1, 1, 0)
	ring.scale = Vector2(0.34, 0.34)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(tint.r, tint.g, tint.b, fill_alpha)
	ring_style.corner_radius_top_left = int(round(max(size.x, size.y)))
	ring_style.corner_radius_top_right = int(round(max(size.x, size.y)))
	ring_style.corner_radius_bottom_right = int(round(max(size.x, size.y)))
	ring_style.corner_radius_bottom_left = int(round(max(size.x, size.y)))
	ring_style.border_width_left = 2
	ring_style.border_width_top = 2
	ring_style.border_width_right = 2
	ring_style.border_width_bottom = 2
	ring_style.border_color = Color(tint.r, tint.g, tint.b, outline_alpha)
	ring_style.shadow_color = Color(tint.r, tint.g, tint.b, outline_alpha * 0.36)
	ring_style.shadow_size = 16
	ring.add_theme_stylebox_override("panel", ring_style)
	battle_feedback_layer.add_child(ring)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(ring, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(1.02, 1.02), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "position:y", ring.position.y - 10.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(ring, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		ring.queue_free()
	)

func _spawn_feedback_burst_for_unit(unit: UnitState, icon_texture: Texture2D, tint: Color, count: int = 4, radius: float = 56.0, badge_size: float = 22.0, duration: float = 0.34) -> void:
	if unit == null or not is_instance_valid(battle_feedback_layer) or count <= 0:
		return
	var center: Vector2 = _global_to_feedback_local(_feedback_global_anchor_for_unit(unit))
	for index in range(count):
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(badge_size, badge_size)
		badge.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			Color(tint.r, tint.g, tint.b, 0.18),
			Color(tint.r, tint.g, tint.b, 0.90),
			Color(tint.r, tint.g, tint.b, 0.18)
		))
		battle_feedback_layer.add_child(badge)

		var center_container := CenterContainer.new()
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(center_container)

		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(maxf(badge_size - 9.0, 10.0), maxf(badge_size - 9.0, 10.0))
		icon_rect.texture = icon_texture
		icon_rect.modulate = tint
		center_container.add_child(icon_rect)

		var angle: float = (TAU / float(count)) * float(index) + randf_range(-0.24, 0.24)
		var burst_distance: float = radius * randf_range(0.72, 1.04)
		var start_position: Vector2 = center - Vector2(badge_size, badge_size) * 0.5 + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		var end_position: Vector2 = center + Vector2(cos(angle), sin(angle)) * burst_distance - Vector2(badge_size, badge_size) * 0.5
		badge.position = start_position
		badge.modulate = Color(1, 1, 1, 0)
		badge.scale = Vector2(0.54, 0.54)
		badge.rotation = randf_range(-0.22, 0.22)

		var tween: Tween = _make_scene_tween()
		if tween == null:
			return
		tween.set_parallel(true)
		tween.tween_property(badge, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(badge, "position", end_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(badge, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(badge, "scale", Vector2(0.86, 0.86), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(func() -> void:
			badge.queue_free()
		)

func _ensure_battle_feedback_layer() -> void:
	if is_instance_valid(battle_feedback_layer):
		return
	battle_feedback_layer = Control.new()
	battle_feedback_layer.name = "BattleFeedbackLayer"
	battle_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_feedback_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_feedback_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	battle_feedback_layer.grow_vertical = Control.GROW_DIRECTION_BOTH
	battle_feedback_layer.z_index = 640
	arena.add_child(battle_feedback_layer)

	player_damage_flash = ColorRect.new()
	player_damage_flash.name = "PlayerDamageFlash"
	player_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_damage_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	player_damage_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	player_damage_flash.z_index = 645
	player_damage_flash.color = Color(0.86, 0.08, 0.06, 0.0)
	player_damage_flash.visible = false
	battle_feedback_layer.add_child(player_damage_flash)

	support_spotlight = ColorRect.new()
	support_spotlight.name = "SupportSpotlight"
	support_spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_spotlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	support_spotlight.grow_horizontal = Control.GROW_DIRECTION_BOTH
	support_spotlight.grow_vertical = Control.GROW_DIRECTION_BOTH
	support_spotlight.color = Color(0.18, 0.28, 0.42, 0.0)
	support_spotlight.visible = false
	battle_feedback_layer.add_child(support_spotlight)

	support_banner = PanelContainer.new()
	support_banner.name = "SupportBanner"
	support_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_banner.anchor_left = 0.5
	support_banner.anchor_right = 0.5
	support_banner.offset_left = -236.0
	support_banner.offset_right = 236.0
	support_banner.offset_top = 16.0
	support_banner.offset_bottom = 92.0
	support_banner.visible = false
	support_banner.modulate = Color(1, 1, 1, 0)
	battle_feedback_layer.add_child(support_banner)

	var banner_margin := MarginContainer.new()
	banner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_margin.add_theme_constant_override("margin_left", 18)
	banner_margin.add_theme_constant_override("margin_top", 12)
	banner_margin.add_theme_constant_override("margin_right", 18)
	banner_margin.add_theme_constant_override("margin_bottom", 12)
	support_banner.add_child(banner_margin)

	var banner_vbox := VBoxContainer.new()
	banner_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_vbox.add_theme_constant_override("separation", 2)
	banner_margin.add_child(banner_vbox)

	support_banner_title = Label.new()
	support_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	support_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_vbox.add_child(support_banner_title)

	support_banner_body = Label.new()
	support_banner_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	support_banner_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	support_banner_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_vbox.add_child(support_banner_body)

	support_lane = PanelContainer.new()
	support_lane.name = "SupportLane"
	support_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_lane.anchor_left = 0.18
	support_lane.anchor_right = 0.82
	support_lane.offset_top = 108.0
	support_lane.offset_bottom = 156.0
	support_lane.visible = false
	support_lane.modulate = Color(1, 1, 1, 0)
	battle_feedback_layer.add_child(support_lane)

	var lane_margin := MarginContainer.new()
	lane_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane_margin.add_theme_constant_override("margin_left", 18)
	lane_margin.add_theme_constant_override("margin_top", 6)
	lane_margin.add_theme_constant_override("margin_right", 18)
	lane_margin.add_theme_constant_override("margin_bottom", 6)
	support_lane.add_child(lane_margin)

	var lane_row := HBoxContainer.new()
	lane_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lane_row.add_theme_constant_override("separation", 12)
	lane_margin.add_child(lane_row)

	support_lane_icon_plate = PanelContainer.new()
	support_lane_icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_lane_icon_plate.custom_minimum_size = Vector2(34, 34)
	lane_row.add_child(support_lane_icon_plate)

	var lane_icon_center := CenterContainer.new()
	lane_icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	support_lane_icon_plate.add_child(lane_icon_center)

	support_lane_icon = TextureRect.new()
	support_lane_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	support_lane_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	support_lane_icon.custom_minimum_size = Vector2(18, 18)
	lane_icon_center.add_child(support_lane_icon)

	support_lane_label = Label.new()
	support_lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	support_lane_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	support_lane_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_row.add_child(support_lane_label)

	support_cutin = PanelContainer.new()
	support_cutin.name = "SupportCutin"
	support_cutin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_cutin.anchor_left = 0.04
	support_cutin.anchor_right = 0.34
	support_cutin.offset_top = 136.0
	support_cutin.offset_bottom = 208.0
	support_cutin.visible = false
	support_cutin.modulate = Color(1, 1, 1, 0)
	battle_feedback_layer.add_child(support_cutin)

	support_cutin_flash = ColorRect.new()
	support_cutin_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_cutin_flash.anchor_left = 0.0
	support_cutin_flash.anchor_top = 0.0
	support_cutin_flash.anchor_right = 0.0
	support_cutin_flash.anchor_bottom = 1.0
	support_cutin_flash.offset_left = -96.0
	support_cutin_flash.offset_right = -28.0
	support_cutin_flash.color = Color(1.0, 0.90, 0.72, 0.0)
	support_cutin.add_child(support_cutin_flash)

	support_cutin_accent = ColorRect.new()
	support_cutin_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_cutin_accent.anchor_left = 0.0
	support_cutin_accent.anchor_top = 0.0
	support_cutin_accent.anchor_right = 0.0
	support_cutin_accent.anchor_bottom = 1.0
	support_cutin_accent.offset_left = 0.0
	support_cutin_accent.offset_right = 6.0
	support_cutin_accent.color = Color(1.0, 0.86, 0.56, 0.94)
	support_cutin.add_child(support_cutin_accent)

	var cutin_margin := MarginContainer.new()
	cutin_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutin_margin.add_theme_constant_override("margin_left", 18)
	cutin_margin.add_theme_constant_override("margin_top", 12)
	cutin_margin.add_theme_constant_override("margin_right", 18)
	cutin_margin.add_theme_constant_override("margin_bottom", 12)
	support_cutin.add_child(cutin_margin)

	var cutin_hbox := HBoxContainer.new()
	cutin_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutin_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cutin_hbox.add_theme_constant_override("separation", 14)
	cutin_margin.add_child(cutin_hbox)

	support_cutin_badge = PanelContainer.new()
	support_cutin_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_cutin_badge.custom_minimum_size = Vector2(54, 54)
	cutin_hbox.add_child(support_cutin_badge)

	var cutin_badge_center := CenterContainer.new()
	cutin_badge_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	support_cutin_badge.add_child(cutin_badge_center)

	support_cutin_icon = TextureRect.new()
	support_cutin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	support_cutin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	support_cutin_icon.custom_minimum_size = Vector2(28, 28)
	cutin_badge_center.add_child(support_cutin_icon)

	var cutin_vbox := VBoxContainer.new()
	cutin_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cutin_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cutin_vbox.add_theme_constant_override("separation", 2)
	cutin_hbox.add_child(cutin_vbox)

	support_cutin_title = Label.new()
	support_cutin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	support_cutin_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cutin_vbox.add_child(support_cutin_title)

	support_cutin_body = Label.new()
	support_cutin_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	support_cutin_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	support_cutin_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cutin_vbox.add_child(support_cutin_body)

func _ensure_hand_overflow_toast() -> void:
	if is_instance_valid(hand_overflow_toast):
		return
	if not is_instance_valid(battle_feedback_layer):
		_ensure_battle_feedback_layer()
	hand_overflow_toast = PanelContainer.new()
	hand_overflow_toast.name = "HandOverflowToast"
	hand_overflow_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_overflow_toast.anchor_left = 0.24
	hand_overflow_toast.anchor_top = 0.13
	hand_overflow_toast.anchor_right = 0.76
	hand_overflow_toast.anchor_bottom = 0.21
	hand_overflow_toast.offset_left = 0.0
	hand_overflow_toast.offset_top = 0.0
	hand_overflow_toast.offset_right = 0.0
	hand_overflow_toast.offset_bottom = 0.0
	hand_overflow_toast.z_index = 980
	hand_overflow_toast.visible = false
	hand_overflow_toast.modulate = Color(1, 1, 1, 0)
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.07, 0.10, 0.13, 0.94)
	toast_style.border_color = Color(0.84, 0.90, 0.98, 0.72)
	toast_style.set_border_width_all(2)
	toast_style.corner_radius_top_left = 16
	toast_style.corner_radius_top_right = 16
	toast_style.corner_radius_bottom_left = 16
	toast_style.corner_radius_bottom_right = 16
	toast_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	toast_style.shadow_size = 16
	hand_overflow_toast.add_theme_stylebox_override("panel", toast_style)
	battle_feedback_layer.add_child(hand_overflow_toast)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	hand_overflow_toast.add_child(margin)

	hand_overflow_toast_label = Label.new()
	hand_overflow_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_overflow_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_overflow_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_THEME_KIT.apply_heading(hand_overflow_toast_label, 18, Color(1.0, 0.95, 0.78, 1.0), Color(0.0, 0.0, 0.0, 0.92))
	margin.add_child(hand_overflow_toast_label)

func _play_support_cast_feedback(card: CardData) -> void:
	if card == null or not is_instance_valid(battle_feedback_layer):
		return
	if support_banner_tween != null:
		support_banner_tween.kill()
	if support_lane_tween != null:
		support_lane_tween.kill()
	if support_cutin_tween != null:
		support_cutin_tween.kill()
	var support_profile: Dictionary = _support_feedback_profile(card)
	if player_actor_view != null:
		player_actor_view.play_support()
	_spawn_feedback_ring_for_unit(manager.player, Color(1.0, 0.88, 0.62, 1.0), Vector2(140, 140), -4.0, 0.44, 0.12, 0.88)
	_spawn_feedback_burst_for_unit(manager.player, support_profile.get("icon_texture", BATTLE_ICON_SUPPORT) as Texture2D, support_profile.get("float_tint", Color(0.98, 0.92, 0.70, 1.0)), 6, 68.0, 20.0, 0.34)
	_shake_battlefield(0.18)
	support_spotlight.visible = true
	support_spotlight.color = support_profile.get("spotlight_color", Color(0.30, 0.18, 0.06, 0.0))
	support_banner.visible = true
	support_banner.modulate = Color(1, 1, 1, 0)
	support_banner.position = Vector2(0, -10)
	support_banner.scale = Vector2(0.96, 0.96)
	support_lane.visible = true
	support_lane.modulate = Color(1, 1, 1, 0)
	support_lane.position = Vector2(0, -8)
	support_cutin.visible = true
	support_cutin.modulate = Color(1, 1, 1, 0)
	support_cutin.position = Vector2(-40, 0)
	support_cutin.scale = Vector2(0.96, 0.96)
	if support_cutin_flash != null:
		support_cutin_flash.color = support_profile.get("flash_color", Color(1.0, 0.90, 0.72, 0.0))
		support_cutin_flash.position.x = -96.0
	if support_cutin_accent != null:
		support_cutin_accent.color = support_profile.get("accent_color", Color(1.0, 0.86, 0.56, 0.94))
	if support_cutin_badge != null:
		support_cutin_badge.scale = Vector2(0.90, 0.90)
	if support_lane_icon != null:
		support_lane_icon.texture = support_profile.get("icon_texture", BATTLE_ICON_SUPPORT) as Texture2D
		support_lane_icon.modulate = support_profile.get("icon_tint", Color(1.0, 0.98, 0.92, 1.0))
	if support_lane_label != null:
		support_lane_label.text = String(support_profile.get("lane_text", support_profile.get("cutin_title", LocalizationManager.text("battle.support_cutin_title"))))
	support_banner_title.text = String(support_profile.get("banner_title", LocalizationManager.text("battle.support_banner_title")))
	support_banner_body.text = String(support_profile.get("banner_body", LocalizationManager.text("battle.support_banner_body", [LocalizationManager.card_name(card)])))
	support_cutin_title.text = String(support_profile.get("cutin_title", LocalizationManager.text("battle.support_cutin_title")))
	support_cutin_body.text = String(support_profile.get("cutin_body", LocalizationManager.text("battle.support_cutin_body", [LocalizationManager.card_name(card)])))
	if support_cutin_icon != null:
		support_cutin_icon.texture = support_profile.get("icon_texture", BATTLE_ICON_SUPPORT) as Texture2D
		support_cutin_icon.modulate = support_profile.get("icon_tint", Color(1.0, 0.98, 0.92, 1.0))
	if support_banner != null:
		support_banner.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			support_profile.get("banner_bg", Color(0.18, 0.22, 0.28, 0.94)),
			support_profile.get("banner_border", Color(1.0, 0.88, 0.62, 0.78)),
			support_profile.get("banner_shadow", Color(0.10, 0.12, 0.16, 0.20))
		))
	if support_cutin != null:
		support_cutin.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			support_profile.get("cutin_bg", Color(0.16, 0.20, 0.28, 0.94)),
			support_profile.get("cutin_border", Color(1.0, 0.88, 0.62, 0.72)),
			support_profile.get("cutin_shadow", Color(0.12, 0.10, 0.08, 0.22))
		))
	if support_cutin_badge != null:
		support_cutin_badge.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			support_profile.get("badge_bg", Color(0.28, 0.18, 0.10, 0.96)),
			support_profile.get("badge_border", Color(1.0, 0.88, 0.62, 0.90)),
			support_profile.get("badge_shadow", Color(0.26, 0.14, 0.08, 0.18))
		))
	if support_lane != null:
		var lane_bg: Color = support_profile.get("cutin_bg", Color(0.16, 0.20, 0.28, 0.94))
		support_lane.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			Color(lane_bg.r, lane_bg.g, lane_bg.b, 0.84),
			support_profile.get("cutin_border", Color(1.0, 0.88, 0.62, 0.72)),
			support_profile.get("cutin_shadow", Color(0.12, 0.10, 0.08, 0.22))
		))
	if support_lane_icon_plate != null:
		support_lane_icon_plate.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			support_profile.get("badge_bg", Color(0.28, 0.18, 0.10, 0.96)),
			support_profile.get("badge_border", Color(1.0, 0.88, 0.62, 0.90)),
			support_profile.get("badge_shadow", Color(0.26, 0.14, 0.08, 0.18))
		))
	if support_lane_label != null:
		UI_THEME_KIT.apply_heading(
			support_lane_label,
			18,
			support_profile.get("float_tint", Color(0.98, 0.92, 0.70, 1.0)),
			Color(0.04, 0.05, 0.08, 0.82)
		)
	_spawn_unit_feedback(
		manager.player,
		LocalizationManager.text("battle.float_support"),
		support_profile.get("float_tint", Color(0.98, 0.92, 0.70, 1.0)),
		20,
		-82.0,
		46.0,
		"support"
	)
	support_banner_tween = _make_scene_tween()
	if support_banner_tween == null:
		return
	support_banner_tween.set_parallel(true)
	support_banner_tween.tween_property(support_spotlight, "color:a", 0.24, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	support_banner_tween.tween_property(support_banner, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	support_banner_tween.tween_property(support_banner, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	support_banner_tween.tween_property(support_banner, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	support_banner_tween.chain().tween_interval(0.24)
	support_banner_tween.set_parallel(true)
	support_banner_tween.tween_property(support_spotlight, "color:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	support_banner_tween.tween_property(support_banner, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_banner_tween.tween_property(support_banner, "position:y", -8.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	support_banner_tween.tween_property(support_banner, "scale", Vector2(0.98, 0.98), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_banner_tween.finished.connect(func() -> void:
		support_banner.visible = false
		support_spotlight.visible = false
		support_banner_tween = null
	)
	support_lane_tween = _make_scene_tween()
	if support_lane_tween == null:
		return
	support_lane_tween.set_parallel(true)
	support_lane_tween.tween_property(support_lane, "modulate:a", 1.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	support_lane_tween.tween_property(support_lane, "position:y", 0.0, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	support_lane_tween.chain().tween_interval(0.18)
	support_lane_tween.set_parallel(true)
	support_lane_tween.tween_property(support_lane, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_lane_tween.tween_property(support_lane, "position:y", 8.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	support_lane_tween.finished.connect(func() -> void:
		support_lane.visible = false
		support_lane_tween = null
	)
	support_cutin_tween = _make_scene_tween()
	if support_cutin_tween == null:
		return
	support_cutin_tween.set_parallel(true)
	support_cutin_tween.tween_property(support_cutin, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	support_cutin_tween.tween_property(support_cutin, "position:x", 0.0, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	support_cutin_tween.tween_property(support_cutin, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if support_cutin_badge != null:
		support_cutin_tween.tween_property(support_cutin_badge, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if support_cutin_flash != null:
		var flash_target_x: float = maxf(support_cutin.size.x, 240.0) + 72.0
		support_cutin_tween.tween_property(support_cutin_flash, "position:x", flash_target_x, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		support_cutin_tween.tween_property(support_cutin_flash, "color:a", 0.16, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		support_cutin_tween.chain().tween_property(support_cutin_flash, "color:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_cutin_tween.chain().tween_interval(0.12)
	support_cutin_tween.set_parallel(true)
	support_cutin_tween.tween_property(support_cutin, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_cutin_tween.tween_property(support_cutin, "position:x", 22.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	support_cutin_tween.tween_property(support_cutin, "scale", Vector2(0.98, 0.98), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	support_cutin_tween.finished.connect(func() -> void:
		support_cutin.visible = false
		support_cutin_tween = null
	)

func _feedback_global_anchor_for_unit(unit: UnitState) -> Vector2:
	if unit == null:
		return arena.get_global_rect().get_center()
	if manager != null and unit == manager.mon3tr_display_unit():
		if mon3tr_actor_view != null and is_instance_valid(mon3tr_actor_view):
			var mon3tr_rect: Rect2 = mon3tr_actor_view.get_global_rect()
			return mon3tr_rect.get_center() + Vector2(0.0, -mon3tr_rect.size.y * 0.20)
	if unit == manager.player:
		if player_actor_view != null:
			var player_rect: Rect2 = player_actor_view.get_global_rect()
			return player_rect.get_center() + Vector2(0.0, -player_rect.size.y * 0.22)
		return player_frame.get_global_rect().get_center()
	var enemy_actor: CombatActorView = _enemy_actor_for_unit(unit)
	if enemy_actor != null:
		var enemy_rect: Rect2 = enemy_actor.get_global_rect()
		return enemy_rect.get_center() + Vector2(0.0, -enemy_rect.size.y * 0.18)
	return enemy_container.get_global_rect().get_center()

func _global_to_feedback_local(point: Vector2) -> Vector2:
	if not is_instance_valid(battle_feedback_layer):
		return point
	return battle_feedback_layer.get_global_transform_with_canvas().affine_inverse() * point

func _spawn_unit_feedback(unit: UnitState, text: String, tint: Color, font_size: int = 22, y_offset: float = -36.0, rise: float = 46.0, style_kind: String = "default") -> void:
	if text.is_empty():
		return
	var anchor_point: Vector2 = _feedback_global_anchor_for_unit(unit) + Vector2(0.0, y_offset)
	_spawn_floating_feedback(text, _global_to_feedback_local(anchor_point), tint, font_size, rise, style_kind)

func _floating_feedback_profile(style_kind: String) -> Dictionary:
	match style_kind:
		"block_gain":
			return {
				"icon_texture": BATTLE_ICON_BLOCK,
				"icon": "▣",
				"badge_bg": Color(0.18, 0.26, 0.38, 0.96),
				"badge_border": Color(0.82, 0.93, 1.0, 0.88),
				"badge_tint": Color(0.96, 0.99, 1.0, 1.0),
				"badge_shadow": Color(0.10, 0.18, 0.28, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.84, 0.84),
				"settle_scale": Vector2(1.05, 1.05),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.42,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.05, 0.10, 0.18, 0.86)
			}
		"heal":
			return {
				"icon_texture": BATTLE_ICON_SUPPORT,
				"icon": "✚",
				"badge_bg": Color(0.16, 0.36, 0.20, 0.96),
				"badge_border": Color(0.82, 1.0, 0.88, 0.92),
				"badge_tint": Color(0.96, 1.0, 0.96, 1.0),
				"badge_shadow": Color(0.10, 0.28, 0.12, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.08, 1.08),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.44,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.04, 0.14, 0.06, 0.86)
			}
		"will_gain":
			return {
				"icon_texture": BATTLE_ICON_WILL,
				"icon": "意",
				"badge_bg": Color(0.20, 0.24, 0.52, 0.96),
				"badge_border": Color(0.78, 0.86, 1.0, 0.92),
				"badge_tint": Color(0.96, 0.98, 1.0, 1.0),
				"badge_shadow": Color(0.10, 0.14, 0.32, 0.20),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.84, 0.84),
				"settle_scale": Vector2(1.08, 1.08),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.44,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.05, 0.08, 0.22, 0.86)
			}
		"will_spend":
			return {
				"icon_texture": BATTLE_ICON_WILL,
				"icon": "意",
				"badge_bg": Color(0.28, 0.20, 0.42, 0.96),
				"badge_border": Color(0.90, 0.78, 1.0, 0.90),
				"badge_tint": Color(0.98, 0.94, 1.0, 1.0),
				"badge_shadow": Color(0.16, 0.08, 0.24, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.04, 1.04),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.12, 0.05, 0.18, 0.86)
			}
		"energy_gain":
			return {
				"icon_texture": BATTLE_ICON_SUPPORT,
				"icon": "☼",
				"badge_bg": Color(0.44, 0.24, 0.10, 0.96),
				"badge_border": Color(1.0, 0.90, 0.68, 0.92),
				"badge_tint": Color(1.0, 0.98, 0.92, 1.0),
				"badge_shadow": Color(0.28, 0.14, 0.04, 0.18),
				"badge_size": 30.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.10, 1.10),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.36,
				"fade_time": 0.16,
				"side_shift": 3.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.18, 0.08, 0.02, 0.88)
			}
		"overload_gain":
			return {
				"icon_texture": BATTLE_ICON_EXPLOSION,
				"icon": "↯",
				"badge_bg": Color(0.42, 0.12, 0.08, 0.96),
				"badge_border": Color(1.0, 0.72, 0.58, 0.92),
				"badge_tint": Color(1.0, 0.96, 0.92, 1.0),
				"badge_shadow": Color(0.28, 0.08, 0.04, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.80, 0.80),
				"settle_scale": Vector2(1.12, 1.12),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-3.0, 3.0)),
				"shadow_color": Color(0.18, 0.04, 0.02, 0.88)
			}
		"overload_reduce":
			return {
				"icon_texture": BATTLE_ICON_EXPLOSION,
				"icon": "↯",
				"badge_bg": Color(0.44, 0.28, 0.12, 0.96),
				"badge_border": Color(1.0, 0.90, 0.68, 0.92),
				"badge_tint": Color(1.0, 0.98, 0.92, 1.0),
				"badge_shadow": Color(0.24, 0.14, 0.04, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.06, 1.06),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.18, 0.10, 0.03, 0.86)
			}
		"echo_gain":
			return {
				"icon_texture": BATTLE_ICON_RESONANCE,
				"icon": "◌",
				"badge_bg": Color(0.16, 0.30, 0.42, 0.96),
				"badge_border": Color(0.82, 0.95, 1.0, 0.92),
				"badge_tint": Color(0.98, 1.0, 1.0, 1.0),
				"badge_shadow": Color(0.08, 0.18, 0.26, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.08, 1.08),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.42,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.05, 0.12, 0.18, 0.86)
			}
		"channel_ready":
			return {
				"icon_texture": BATTLE_ICON_SUPPORT,
				"icon": "⟲",
				"badge_bg": Color(0.20, 0.24, 0.34, 0.96),
				"badge_border": Color(0.86, 0.92, 1.0, 0.90),
				"badge_tint": Color(0.98, 0.99, 1.0, 1.0),
				"badge_shadow": Color(0.08, 0.10, 0.16, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.06, 1.06),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.42,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.06, 0.08, 0.14, 0.86)
			}
		"status_weak":
			return {
				"icon_texture": BATTLE_ICON_WEAK,
				"icon": "虚",
				"badge_bg": Color(0.30, 0.16, 0.42, 0.96),
				"badge_border": Color(0.84, 0.72, 1.0, 0.90),
				"badge_tint": Color(0.98, 0.96, 1.0, 1.0),
				"badge_shadow": Color(0.14, 0.06, 0.20, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.04, 1.04),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.10, 0.04, 0.16, 0.86)
			}
		"status_vulnerable":
			return {
				"icon_texture": BATTLE_ICON_VULNERABLE,
				"icon": "易",
				"badge_bg": Color(0.42, 0.16, 0.18, 0.96),
				"badge_border": Color(1.0, 0.74, 0.72, 0.90),
				"badge_tint": Color(1.0, 0.96, 0.96, 1.0),
				"badge_shadow": Color(0.20, 0.06, 0.06, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.04, 1.04),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.16, 0.04, 0.04, 0.86)
			}
		"status_strength":
			return {
				"icon_texture": BATTLE_ICON_STRENGTH,
				"icon": "力",
				"badge_bg": Color(0.48, 0.24, 0.10, 0.96),
				"badge_border": Color(1.0, 0.86, 0.64, 0.92),
				"badge_tint": Color(1.0, 0.98, 0.94, 1.0),
				"badge_shadow": Color(0.22, 0.10, 0.04, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.04, 1.04),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.40,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.16, 0.08, 0.03, 0.86)
			}
		"damage":
			return {
				"icon_texture": BATTLE_ICON_DAMAGE,
				"icon": "✦",
				"badge_bg": Color(0.38, 0.10, 0.12, 0.96),
				"badge_border": Color(1.0, 0.72, 0.68, 0.90),
				"badge_tint": Color(1.0, 0.92, 0.90, 1.0),
				"badge_shadow": Color(0.40, 0.10, 0.12, 0.20),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.74, 0.74),
				"settle_scale": Vector2(1.10, 1.10),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.14,
				"travel_time": 0.54,
				"fade_time": 0.14,
				"side_shift": 10.0,
				"rotation": deg_to_rad(randf_range(-5.0, 5.0)),
				"shadow_color": Color(0.18, 0.02, 0.02, 0.92)
			}
		"shot_damage":
			return {
				"icon_texture": BATTLE_ICON_AMMO,
				"icon": "•",
				"badge_bg": Color(0.10, 0.26, 0.34, 0.98),
				"badge_border": Color(0.74, 0.96, 1.0, 0.96),
				"badge_tint": Color(0.96, 1.0, 1.0, 1.0),
				"badge_shadow": Color(0.06, 0.22, 0.30, 0.22),
				"badge_size": 30.0,
				"entry_scale": Vector2(0.68, 0.68),
				"settle_scale": Vector2(1.16, 1.16),
				"exit_scale": Vector2(0.96, 0.96),
				"entry_time": 0.04,
				"settle_time": 0.12,
				"travel_time": 0.48,
				"fade_time": 0.14,
				"side_shift": 14.0,
				"rotation": deg_to_rad(randf_range(-7.0, 7.0)),
				"shadow_color": Color(0.02, 0.12, 0.18, 0.94)
			}
		"finisher_damage":
			return {
				"icon_texture": BATTLE_ICON_BURST,
				"icon": "✦",
				"badge_bg": Color(0.50, 0.18, 0.10, 0.98),
				"badge_border": Color(1.0, 0.88, 0.58, 0.98),
				"badge_tint": Color(1.0, 0.98, 0.88, 1.0),
				"badge_shadow": Color(0.44, 0.16, 0.06, 0.24),
				"badge_size": 34.0,
				"entry_scale": Vector2(0.62, 0.62),
				"settle_scale": Vector2(1.24, 1.24),
				"exit_scale": Vector2(0.94, 0.94),
				"entry_time": 0.04,
				"settle_time": 0.16,
				"travel_time": 0.58,
				"fade_time": 0.16,
				"side_shift": 16.0,
				"rotation": deg_to_rad(randf_range(-8.0, 8.0)),
				"shadow_color": Color(0.20, 0.06, 0.02, 0.96)
			}
		"arts_damage":
			return {
				"icon_texture": BATTLE_ICON_ARTS,
				"icon": "✦",
				"badge_bg": Color(0.10, 0.24, 0.42, 0.96),
				"badge_border": Color(0.72, 0.92, 1.0, 0.92),
				"badge_tint": Color(0.96, 0.99, 1.0, 1.0),
				"badge_shadow": Color(0.08, 0.20, 0.42, 0.20),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.74, 0.74),
				"settle_scale": Vector2(1.10, 1.10),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.14,
				"travel_time": 0.54,
				"fade_time": 0.14,
				"side_shift": 10.0,
				"rotation": deg_to_rad(randf_range(-5.0, 5.0)),
				"shadow_color": Color(0.04, 0.12, 0.24, 0.92)
			}
		"block_loss":
			return {
				"icon_texture": BATTLE_ICON_BLOCK,
				"icon": "▣",
				"badge_bg": Color(0.18, 0.28, 0.40, 0.96),
				"badge_border": Color(0.78, 0.90, 1.0, 0.88),
				"badge_tint": Color(0.94, 0.98, 1.0, 1.0),
				"badge_shadow": Color(0.12, 0.22, 0.34, 0.16),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.88, 0.88),
				"settle_scale": Vector2(1.02, 1.02),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.08,
				"settle_time": 0.12,
				"travel_time": 0.42,
				"fade_time": 0.16,
				"side_shift": 4.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.05, 0.10, 0.18, 0.84)
			}
		"block_break":
			return {
				"icon_texture": BATTLE_ICON_BLOCK,
				"icon": "✷",
				"badge_bg": Color(0.40, 0.26, 0.10, 0.96),
				"badge_border": Color(1.0, 0.90, 0.72, 0.92),
				"badge_tint": Color(1.0, 0.98, 0.92, 1.0),
				"badge_shadow": Color(0.40, 0.22, 0.08, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.78, 0.78),
				"settle_scale": Vector2(1.16, 1.16),
				"exit_scale": Vector2(0.96, 0.96),
				"entry_time": 0.05,
				"settle_time": 0.14,
				"travel_time": 0.48,
				"fade_time": 0.18,
				"side_shift": 8.0,
				"rotation": deg_to_rad(randf_range(-4.0, 4.0)),
				"shadow_color": Color(0.22, 0.12, 0.02, 0.90)
			}
		"resonance_gain":
			return {
				"icon_texture": BATTLE_ICON_RESONANCE,
				"icon": "◎",
				"badge_bg": Color(0.10, 0.34, 0.42, 0.96),
				"badge_border": Color(0.72, 0.96, 1.0, 0.92),
				"badge_tint": Color(0.96, 1.0, 1.0, 1.0),
				"badge_shadow": Color(0.08, 0.30, 0.36, 0.18),
				"badge_size": 28.0,
				"entry_scale": Vector2(0.82, 0.82),
				"settle_scale": Vector2(1.06, 1.06),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.12,
				"travel_time": 0.46,
				"fade_time": 0.16,
				"side_shift": 5.0,
				"rotation": deg_to_rad(randf_range(-3.0, 3.0)),
				"shadow_color": Color(0.03, 0.18, 0.24, 0.88)
			}
		"resonance_burst":
			return {
				"icon_texture": BATTLE_ICON_RESONANCE,
				"icon": "◈",
				"badge_bg": Color(0.08, 0.38, 0.48, 0.98),
				"badge_border": Color(0.74, 0.98, 1.0, 0.96),
				"badge_tint": Color(1.0, 1.0, 1.0, 1.0),
				"badge_shadow": Color(0.08, 0.32, 0.40, 0.22),
				"badge_size": 30.0,
				"entry_scale": Vector2(0.72, 0.72),
				"settle_scale": Vector2(1.18, 1.18),
				"exit_scale": Vector2(0.95, 0.95),
				"entry_time": 0.05,
				"settle_time": 0.16,
				"travel_time": 0.56,
				"fade_time": 0.18,
				"side_shift": 12.0,
				"rotation": deg_to_rad(randf_range(-6.0, 6.0)),
				"shadow_color": Color(0.02, 0.16, 0.24, 0.92)
			}
		"support":
			return {
				"icon_texture": BATTLE_ICON_SUPPORT,
				"icon": "✚",
				"badge_bg": Color(0.42, 0.24, 0.10, 0.96),
				"badge_border": Color(1.0, 0.88, 0.62, 0.94),
				"badge_tint": Color(1.0, 0.98, 0.90, 1.0),
				"badge_shadow": Color(0.42, 0.24, 0.10, 0.22),
				"badge_size": 30.0,
				"entry_scale": Vector2(0.80, 0.80),
				"settle_scale": Vector2(1.12, 1.12),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.06,
				"settle_time": 0.14,
				"travel_time": 0.52,
				"fade_time": 0.16,
				"side_shift": 6.0,
				"rotation": deg_to_rad(randf_range(-2.0, 2.0)),
				"shadow_color": Color(0.20, 0.12, 0.02, 0.86)
			}
		"reload":
			return {
				"icon_texture": BATTLE_ICON_RELOAD,
				"icon": "↻",
				"badge_bg": Color(0.12, 0.24, 0.34, 0.96),
				"badge_border": Color(0.76, 0.94, 1.0, 0.92),
				"badge_tint": Color(0.96, 1.0, 1.0, 1.0),
				"badge_shadow": Color(0.06, 0.14, 0.20, 0.18),
				"badge_size": 29.0,
				"entry_scale": Vector2(0.78, 0.78),
				"settle_scale": Vector2(1.10, 1.10),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.05,
				"settle_time": 0.12,
				"travel_time": 0.42,
				"fade_time": 0.16,
				"side_shift": 5.0,
				"rotation": deg_to_rad(randf_range(-3.0, 3.0)),
				"shadow_color": Color(0.03, 0.08, 0.12, 0.88)
			}
		"mark":
			return {
				"icon_texture": BATTLE_ICON_MARK,
				"icon": "⌖",
				"badge_bg": Color(0.40, 0.12, 0.16, 0.96),
				"badge_border": Color(1.0, 0.72, 0.78, 0.94),
				"badge_tint": Color(1.0, 0.96, 0.98, 1.0),
				"badge_shadow": Color(0.26, 0.08, 0.12, 0.20),
				"badge_size": 30.0,
				"entry_scale": Vector2(0.76, 0.76),
				"settle_scale": Vector2(1.12, 1.12),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.05,
				"settle_time": 0.14,
				"travel_time": 0.46,
				"fade_time": 0.16,
				"side_shift": 6.0,
				"rotation": deg_to_rad(randf_range(-4.0, 4.0)),
				"shadow_color": Color(0.16, 0.03, 0.05, 0.90)
			}
		"burst":
			return {
				"icon_texture": BATTLE_ICON_BURST,
				"icon": "✦",
				"badge_bg": Color(0.42, 0.24, 0.08, 0.98),
				"badge_border": Color(1.0, 0.92, 0.62, 0.96),
				"badge_tint": Color(1.0, 0.98, 0.88, 1.0),
				"badge_shadow": Color(0.30, 0.16, 0.04, 0.22),
				"badge_size": 32.0,
				"entry_scale": Vector2(0.70, 0.70),
				"settle_scale": Vector2(1.16, 1.16),
				"exit_scale": Vector2(0.98, 0.98),
				"entry_time": 0.05,
				"settle_time": 0.14,
				"travel_time": 0.48,
				"fade_time": 0.16,
				"side_shift": 7.0,
				"rotation": deg_to_rad(randf_range(-4.0, 4.0)),
				"shadow_color": Color(0.18, 0.08, 0.02, 0.92)
			}
		_:
			return {
				"icon_texture": BATTLE_ICON_SUPPORT,
				"icon": "•",
				"badge_bg": Color(0.18, 0.22, 0.28, 0.94),
				"badge_border": Color(0.88, 0.94, 1.0, 0.36),
				"badge_tint": Color(0.98, 0.98, 1.0, 1.0),
				"badge_shadow": Color(0.10, 0.12, 0.16, 0.16),
				"badge_size": 26.0,
				"entry_scale": Vector2(0.92, 0.92),
				"settle_scale": Vector2.ONE,
				"exit_scale": Vector2.ONE,
				"entry_time": 0.08,
				"settle_time": 0.10,
				"travel_time": 0.48,
				"fade_time": 0.16,
				"side_shift": 0.0,
				"rotation": 0.0,
				"shadow_color": Color(0.04, 0.05, 0.08, 0.88)
			}

func _spawn_floating_feedback(text: String, local_position: Vector2, tint: Color, font_size: int = 22, rise: float = 46.0, style_kind: String = "default") -> void:
	if not is_instance_valid(battle_feedback_layer) or text.is_empty():
		return
	var profile: Dictionary = _floating_feedback_profile(style_kind)
	var wrapper := HBoxContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 8)
	battle_feedback_layer.add_child(wrapper)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_size: float = float(profile.get("badge_size", 28.0))
	badge.custom_minimum_size = Vector2(badge_size, badge_size)
	badge.add_theme_stylebox_override("panel", _make_feedback_badge_style(
		profile.get("badge_bg", Color(0.18, 0.22, 0.28, 0.94)),
		profile.get("badge_border", Color(0.88, 0.94, 1.0, 0.36)),
		profile.get("badge_shadow", Color(0.10, 0.12, 0.16, 0.16))
	))
	wrapper.add_child(badge)

	var badge_center := CenterContainer.new()
	badge_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_center)

	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(maxf(badge_size - 10.0, 16.0), maxf(badge_size - 10.0, 16.0))
	var icon_texture: Texture2D = profile.get("icon_texture", null) as Texture2D
	icon_rect.texture = icon_texture
	icon_rect.modulate = profile.get("badge_tint", tint)
	icon_rect.visible = icon_texture != null
	badge_center.add_child(icon_rect)

	var icon_label := Label.new()
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.text = String(profile.get("icon", "•"))
	UI_THEME_KIT.apply_heading(icon_label, maxi(font_size - 7, 14), profile.get("badge_tint", tint), Color(0.04, 0.05, 0.08, 0.76))
	icon_label.visible = icon_texture == null
	badge_center.add_child(icon_label)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	UI_THEME_KIT.apply_heading(label, font_size, tint, profile.get("shadow_color", Color(0.04, 0.05, 0.08, 0.88)))
	wrapper.add_child(label)

	var size_hint: Vector2 = wrapper.get_combined_minimum_size()
	wrapper.size = size_hint
	wrapper.pivot_offset = size_hint * 0.5
	wrapper.position = local_position - size_hint * 0.5
	wrapper.modulate = Color(1, 1, 1, 0)
	wrapper.scale = profile.get("entry_scale", Vector2(0.92, 0.92))
	wrapper.rotation = float(profile.get("rotation", 0.0))
	var side_shift: float = float(profile.get("side_shift", 0.0))
	var drift_x: float = randf_range(-side_shift, side_shift)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(wrapper, "modulate:a", 1.0, float(profile.get("entry_time", 0.08))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "scale", profile.get("settle_scale", Vector2.ONE), float(profile.get("settle_time", 0.10))).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "position:y", wrapper.position.y - rise, float(profile.get("travel_time", 0.48))).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if absf(drift_x) > 0.0:
		tween.tween_property(wrapper, "position:x", wrapper.position.x + drift_x, float(profile.get("travel_time", 0.48))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(wrapper, "scale", profile.get("exit_scale", Vector2.ONE), float(profile.get("fade_time", 0.16))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(wrapper, "modulate:a", 0.0, float(profile.get("fade_time", 0.16))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		wrapper.queue_free()
	)

func _make_feedback_badge_style(bg: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(999)
	style.shadow_color = shadow
	style.shadow_size = 10
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _support_feedback_profile(card: CardData) -> Dictionary:
	if card == null:
		return {
			"icon_texture": SUPPORT_TILE_AMIYA,
			"accent_color": Color(0.76, 0.86, 1.0, 0.94),
			"flash_color": Color(0.88, 0.94, 1.0, 0.0),
			"spotlight_color": Color(0.08, 0.18, 0.32, 0.0),
			"banner_bg": Color(0.12, 0.18, 0.28, 0.94),
			"banner_border": Color(0.78, 0.88, 1.0, 0.76),
			"banner_shadow": Color(0.08, 0.10, 0.16, 0.20),
			"cutin_bg": Color(0.10, 0.14, 0.24, 0.94),
			"cutin_border": Color(0.78, 0.88, 1.0, 0.72),
			"cutin_shadow": Color(0.08, 0.10, 0.16, 0.18),
			"badge_bg": Color(0.16, 0.22, 0.36, 0.96),
			"badge_border": Color(0.78, 0.88, 1.0, 0.88),
			"badge_shadow": Color(0.08, 0.12, 0.20, 0.18),
			"float_tint": Color(0.84, 0.94, 1.0, 1.0),
			"icon_tint": Color(1.0, 1.0, 1.0, 1.0),
			"banner_title": "指挥链接通" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Command Link",
			"banner_body": "阿米娅把节奏重新接上，下一拍继续推进。" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Amiya stitches the tempo back together so the squad can keep pushing.",
			"cutin_title": "阿米娅协调支援" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Amiya Support",
			"cutin_body": LocalizationManager.card_name(card),
			"lane_text": "阿米娅支援切入" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Amiya Support Inbound"
		}
	var card_id: String = card.id.to_lower()
	if "nearl" in card_id or card_id in ["ace_last_stand", "medical_evac_route", "stabilize_line"]:
		return {
			"icon_texture": SUPPORT_TILE_NEARL,
			"accent_color": Color(1.0, 0.90, 0.66, 0.94),
			"flash_color": Color(1.0, 0.92, 0.72, 0.0),
			"spotlight_color": Color(0.28, 0.18, 0.06, 0.0),
			"banner_bg": Color(0.24, 0.18, 0.10, 0.94),
			"banner_border": Color(1.0, 0.90, 0.66, 0.80),
			"banner_shadow": Color(0.14, 0.10, 0.04, 0.20),
			"cutin_bg": Color(0.20, 0.16, 0.10, 0.94),
			"cutin_border": Color(1.0, 0.88, 0.66, 0.74),
			"cutin_shadow": Color(0.14, 0.10, 0.04, 0.18),
			"badge_bg": Color(0.38, 0.28, 0.12, 0.96),
			"badge_border": Color(1.0, 0.90, 0.70, 0.90),
			"badge_shadow": Color(0.22, 0.16, 0.06, 0.18),
			"float_tint": Color(1.0, 0.92, 0.74, 1.0),
			"icon_tint": Color(1.0, 0.98, 0.92, 1.0),
			"banner_title": "前线护卫切入" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Frontline Guard",
			"banner_body": "临光把阵线稳住，直接把这一拍顶住。" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Nearl braces the line and turns the exchange back in your favor.",
			"cutin_title": "临光支援到位" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Nearl Support",
			"cutin_body": LocalizationManager.card_name(card),
			"lane_text": "临光支援到位" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Nearl Support Online"
		}
	if "exusiai" in card_id or "greythroat" in card_id or card_id in ["guided_fire", "discipline_note", "signal_relay"]:
		return {
			"icon_texture": SUPPORT_TILE_EXUSIAI,
			"accent_color": Color(0.64, 0.88, 1.0, 0.94),
			"flash_color": Color(0.82, 0.96, 1.0, 0.0),
			"spotlight_color": Color(0.04, 0.18, 0.28, 0.0),
			"banner_bg": Color(0.10, 0.20, 0.28, 0.94),
			"banner_border": Color(0.72, 0.94, 1.0, 0.80),
			"banner_shadow": Color(0.06, 0.10, 0.14, 0.20),
			"cutin_bg": Color(0.08, 0.18, 0.24, 0.94),
			"cutin_border": Color(0.70, 0.94, 1.0, 0.74),
			"cutin_shadow": Color(0.06, 0.10, 0.14, 0.18),
			"badge_bg": Color(0.14, 0.28, 0.38, 0.96),
			"badge_border": Color(0.74, 0.94, 1.0, 0.90),
			"badge_shadow": Color(0.06, 0.14, 0.18, 0.18),
			"float_tint": Color(0.82, 0.96, 1.0, 1.0),
			"icon_tint": Color(1.0, 1.0, 1.0, 1.0),
			"banner_title": "火力覆盖展开" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Cover Fire",
			"banner_body": "能天使把火线补满了，别让空档白白溜走。" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Exusiai fills the gap with covering fire. Keep pressing the opening.",
			"cutin_title": "能天使支援火力" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Exusiai Support",
			"cutin_body": LocalizationManager.card_name(card),
			"lane_text": "能天使火力切入" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Exusiai Fire Support"
		}
	if "kaltsit" in card_id or card_id in ["pulse_scan", "delayed_directive", "channel_pulse", "thought_acceleration", "tactical_network", "strategic_rotation"]:
		return {
			"icon_texture": SUPPORT_TILE_KALTSIT,
			"accent_color": Color(0.74, 0.96, 0.86, 0.94),
			"flash_color": Color(0.88, 1.0, 0.94, 0.0),
			"spotlight_color": Color(0.08, 0.22, 0.16, 0.0),
			"banner_bg": Color(0.10, 0.22, 0.18, 0.94),
			"banner_border": Color(0.76, 0.98, 0.88, 0.80),
			"banner_shadow": Color(0.06, 0.12, 0.10, 0.20),
			"cutin_bg": Color(0.08, 0.18, 0.16, 0.94),
			"cutin_border": Color(0.76, 0.96, 0.88, 0.72),
			"cutin_shadow": Color(0.06, 0.12, 0.10, 0.18),
			"badge_bg": Color(0.14, 0.28, 0.24, 0.96),
			"badge_border": Color(0.78, 0.98, 0.90, 0.90),
			"badge_shadow": Color(0.06, 0.14, 0.10, 0.18),
			"float_tint": Color(0.84, 1.0, 0.92, 1.0),
			"icon_tint": Color(1.0, 1.0, 1.0, 1.0),
			"banner_title": "战术接管开始" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Tactical Control",
			"banner_body": "凯尔希把节奏压稳了，先把局面收紧再出手。" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Kal'tsit tightens the field first, then gives you the clean window to act.",
			"cutin_title": "凯尔希冷静接管" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Kal'tsit Support",
			"cutin_body": LocalizationManager.card_name(card),
			"lane_text": "凯尔希战术接管" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Kal'tsit Tactical Override"
		}
	return {
		"icon_texture": SUPPORT_TILE_AMIYA if card.tags.has("support") else BATTLE_ICON_SUPPORT,
		"accent_color": Color(0.76, 0.86, 1.0, 0.94),
		"flash_color": Color(0.88, 0.94, 1.0, 0.0),
		"spotlight_color": Color(0.08, 0.18, 0.32, 0.0),
		"banner_bg": Color(0.12, 0.18, 0.28, 0.94),
		"banner_border": Color(0.78, 0.88, 1.0, 0.76),
		"banner_shadow": Color(0.08, 0.10, 0.16, 0.20),
		"cutin_bg": Color(0.10, 0.14, 0.24, 0.94),
		"cutin_border": Color(0.78, 0.88, 1.0, 0.72),
		"cutin_shadow": Color(0.08, 0.10, 0.16, 0.18),
		"badge_bg": Color(0.16, 0.22, 0.36, 0.96),
		"badge_border": Color(0.78, 0.88, 1.0, 0.88),
		"badge_shadow": Color(0.08, 0.12, 0.20, 0.18),
		"float_tint": Color(0.84, 0.94, 1.0, 1.0),
		"icon_tint": Color(1.0, 1.0, 1.0, 1.0),
		"banner_title": "支援联动就绪" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Support Online",
		"banner_body": "联动已经接上，下一拍可以打得更狠一点。" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "The support chain is live. The next beat can hit much harder.",
		"cutin_title": "战场支援推进" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Support Chain",
		"cutin_body": LocalizationManager.card_name(card),
		"lane_text": "战场支援推进" if LocalizationManager.current_language == LocalizationManager.LANG_ZH else "Support Chain Engaged"
	}

func _status_feedback_visual(status_id: String) -> Dictionary:
	match status_id:
		"weak":
			return {
				"text_key": "battle.float_status_weak",
				"style_kind": "status_weak",
				"tint": Color(0.90, 0.80, 1.0, 1.0),
				"log_name": LocalizationManager.text("battle.status_name_weak")
			}
		"vulnerable":
			return {
				"text_key": "battle.float_status_vulnerable",
				"style_kind": "status_vulnerable",
				"tint": Color(1.0, 0.82, 0.82, 1.0),
				"log_name": LocalizationManager.text("battle.status_name_vulnerable")
			}
		"strength":
			return {
				"text_key": "battle.float_status_strength",
				"style_kind": "status_strength",
				"tint": Color(1.0, 0.90, 0.72, 1.0),
				"log_name": LocalizationManager.text("battle.status_name_strength")
			}
		_:
			return {}

func _update_enemy_intent_panel() -> void:
	if manager.enemies.is_empty():
		enemy_intent_frame.visible = false
		enemy_intent_label.text = LocalizationManager.text("battle.target_none")
		return
	enemy_intent_frame.visible = true
	selected_target_index = int(clamp(selected_target_index, 0, manager.enemies.size() - 1))
	var enemy: UnitState = manager.enemies[selected_target_index]
	var intent_text: String = LocalizationManager.intent_label(_intent_display_label(enemy.intent))
	var resource_line: String = LocalizationManager.text("battle.enemy_panel_block", [enemy.block])
	if enemy.resonance > 0:
		resource_line += LocalizationManager.text("battle.enemy_panel_resonance", [enemy.resonance])
	enemy_intent_label.text = LocalizationManager.text("battle.enemy_intent_panel", [
		LocalizationManager.enemy_name(enemy.id, enemy.display_name),
		enemy.hp,
		enemy.max_hp,
		resource_line,
		intent_text
	])

func _layout_hand_fan(animate: bool = true) -> void:
	var cards: Array = hand_container.get_children()
	if cards.is_empty():
		return
	var area_width: float = max(hand_scroll.size.x, 700.0)
	var card_size: Vector2 = _hand_card_size()
	var count: int = cards.size()
	var spread: float = min(area_width * 0.74, (150.0 + card_size.x * 0.10) * max(1, count - 1))
	var max_angle: float = min(16.0, 4.0 + count * 1.5)
	var base_y: float = max(hand_scroll.size.y, card_size.y + 88.0) - card_size.y - 70.0
	var hovered_index: int = cards.find(hovered_hand_card)
	var aimed_index: int = cards.find(aimed_card_button)
	for i in range(count):
		var card_button: Button = cards[i] as Button
		if card_button == null:
			continue
		var card: CardData = manager.deck.hand[i] if i < manager.deck.hand.size() else null
		var base_modulate: Color = _card_color(card, card_button.disabled)
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var centered: float = t - 0.5
		var x: float = area_width * 0.5 + centered * spread - card_size.x * 0.5
		if aimed_index != -1 and i != aimed_index:
			var aimed_distance: int = abs(i - aimed_index)
			var aimed_push: float = (36.0 + card_size.x * 0.10) / float(max(1, aimed_distance))
			x += -aimed_push if i < aimed_index else aimed_push
		elif hovered_index != -1 and i != hovered_index:
			var distance: int = abs(i - hovered_index)
			var push_strength: float = (22.0 + card_size.x * 0.04) / float(distance)
			x += -push_strength if i < hovered_index else push_strength
		var arc_strength: float = 1.0 - min(1.0, abs(centered) * 2.0)
		var y: float = base_y + (1.0 - arc_strength) * (24.0 + card_size.y * 0.012)
		var hovered: bool = hovered_hand_card == card_button
		var aimed: bool = aimed_card_button == card_button
		var target_position: Vector2 = Vector2(x, y - (28.0 + card_size.y * 0.03 if hovered else 0.0))
		var target_rotation: float = centered * max_angle
		var target_scale: Vector2 = Vector2.ONE * (1.10 if hovered else 1.0)
		var target_modulate: Color = base_modulate
		if aimed:
			target_position = Vector2(area_width * 0.5 - card_size.x * 0.5, base_y - (92.0 + card_size.y * 0.05))
			target_rotation = 0.0
			target_scale = Vector2.ONE * 1.14
			target_modulate = base_modulate.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.10)
		elif aimed_index != -1:
			target_position.y += 36.0 + (1.0 - arc_strength) * 10.0
			target_rotation *= 0.72
			target_scale = Vector2.ONE * 0.92
			target_modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, base_modulate.a * 0.52)
		elif hovered:
			target_rotation *= 0.22
			target_modulate = base_modulate.lerp(Color(1.0, 1.0, 1.0, base_modulate.a), 0.08)
		card_button.pivot_offset = card_size * 0.5
		card_button.z_index = 220 + i if aimed else (100 + i if hovered else i)
		if animate:
			_tween_hand_card(card_button, target_position, target_rotation, target_scale, target_modulate)
		else:
			card_button.position = target_position
			card_button.rotation_degrees = target_rotation
			card_button.scale = target_scale
			card_button.modulate = target_modulate

func _tween_hand_card(card_button: Button, target_position: Vector2, target_rotation: float, target_scale: Vector2, target_modulate: Color) -> void:
	var instance_id: int = card_button.get_instance_id()
	var existing_tween: Tween = hand_card_tweens.get(instance_id) as Tween
	if existing_tween != null:
		existing_tween.kill()
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	hand_card_tweens[instance_id] = tween
	tween.set_parallel(true)
	tween.tween_property(card_button, "position", target_position, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_button, "rotation_degrees", target_rotation, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_button, "scale", target_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_button, "modulate", target_modulate, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _hovered_card_targets_enemy() -> bool:
	if hovered_hand_card == null:
		return false
	var cards: Array = hand_container.get_children()
	var hovered_index: int = cards.find(hovered_hand_card)
	if hovered_index == -1 or hovered_index >= manager.deck.hand.size():
		return false
	var card: CardData = manager.deck.hand[hovered_index]
	return _card_targets_enemy(card)

func _card_targets_enemy(card: CardData) -> bool:
	if card == null or card.card_type == "Curse":
		return false
	for effect in card.effects:
		if _effect_targets_enemy(effect):
			return true
	for effect in card.conditional_effects:
		if _effect_targets_enemy(effect):
			return true
	return false

func _effect_targets_enemy(effect: EffectData) -> bool:
	if effect == null:
		return false
	var effect_target: String = String(effect.target)
	if effect_target in ["enemy", "all_enemies", "random_enemy"]:
		return true
	if effect_target == "" and effect.effect_type in ["damage", "spend_all_will_damage", "damage_all", "apply_status"]:
		return true
	return false

func _card_target_point(card: CardData) -> Vector2:
	if _card_targets_enemy(card) and selected_target_index >= 0 and selected_target_index < enemy_actor_views.size():
		var actor_view: CombatActorView = enemy_actor_views[selected_target_index]
		if actor_view != null:
			var rect: Rect2 = actor_view.get_global_rect()
			return rect.get_center()
	if player_actor_view != null:
		return player_actor_view.get_global_rect().get_center()
	return get_viewport_rect().get_center()

func _play_card_launch_animation(card: CardData, source_rect: Rect2, target_point: Vector2) -> void:
	if source_rect.size == Vector2.ZERO:
		return
	var clone: Button = CARD_DISPLAY_FACTORY.create_card_button(
		card,
		LocalizationManager.card_name(card),
		LocalizationManager.card_description(card),
			_display_card_cost(card),
		Util.load_card_art(card.id),
		source_rect.size,
		true,
		CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
	)
	clone.disabled = true
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clone.z_index = 900
	clone.position = source_rect.position
	clone.pivot_offset = source_rect.size * 0.5
	add_child(clone)
	var windup_position: Vector2 = source_rect.position + Vector2(0.0, -48.0)
	var target_position: Vector2 = target_point - source_rect.size * 0.5
	var windup: Tween = _make_scene_tween()
	if windup == null:
		return
	windup.set_parallel(true)
	windup.tween_property(clone, "position", windup_position, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	windup.tween_property(clone, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	windup.tween_property(clone, "rotation_degrees", 0.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await windup.finished
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(clone, "position", target_position, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(clone, "scale", Vector2(0.68, 0.68), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(clone, "rotation_degrees", 10.0 if target_point.x > source_rect.position.x else -10.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(clone, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	clone.queue_free()

func _on_cards_drawn(cards: Array[CardData], _source: String) -> void:
	SfxManager.play_card_draw(cards.size())
	for card in cards:
		pending_draw_animation_cards.append(card)

func _on_cards_overflowed(cards: Array[CardData], _source: String) -> void:
	if cards.is_empty():
		return
	_show_hand_overflow_toast()
	_append_log(LocalizationManager.text("battle.log.hand_overflow_cards", [cards.size()]), "warning")

func _show_hand_overflow_toast() -> void:
	_ensure_hand_overflow_toast()
	if not is_instance_valid(hand_overflow_toast) or hand_overflow_toast_label == null:
		return
	hand_overflow_toast_label.text = LocalizationManager.text("battle.hand_overflow_toast")
	_kill_scene_tween(hand_overflow_toast_tween)
	hand_overflow_toast.visible = true
	hand_overflow_toast.modulate = Color(1, 1, 1, 0)
	hand_overflow_toast.scale = Vector2(0.96, 0.96)
	hand_overflow_toast_tween = _make_scene_tween()
	if hand_overflow_toast_tween == null:
		return
	hand_overflow_toast_tween.set_parallel(false)
	hand_overflow_toast_tween.tween_property(hand_overflow_toast, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hand_overflow_toast_tween.parallel().tween_property(hand_overflow_toast, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hand_overflow_toast_tween.tween_interval(0.78)
	hand_overflow_toast_tween.tween_property(hand_overflow_toast, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hand_overflow_toast_tween.finished.connect(func() -> void:
		if is_instance_valid(hand_overflow_toast):
			hand_overflow_toast.visible = false
	)

func _play_pending_draw_animations() -> void:
	if pending_draw_animation_cards.is_empty():
		return
	var count: int = min(pending_draw_animation_cards.size(), hand_container.get_child_count())
	if count <= 0:
		pending_draw_animation_cards.clear()
		return
	var cards_to_animate: Array = pending_draw_animation_cards.slice(max(0, pending_draw_animation_cards.size() - count), pending_draw_animation_cards.size())
	pending_draw_animation_cards.clear()
	var start_index: int = hand_container.get_child_count() - count
	for offset in range(count):
		var target_button: Button = hand_container.get_child(start_index + offset) as Button
		if target_button == null:
			continue
		var card: CardData = cards_to_animate[offset]
		_animate_draw_to_hand(card, target_button, float(offset) * 0.05)

func _animate_draw_to_hand(card: CardData, target_button: Button, delay: float) -> void:
	if card == null or target_button == null:
		return
	var target_rect: Rect2 = target_button.get_global_rect()
	var final_modulate: Color = target_button.modulate
	target_button.modulate = Color(final_modulate.r, final_modulate.g, final_modulate.b, 0.06)
	var clone: Button = CARD_DISPLAY_FACTORY.create_card_button(
		card,
		LocalizationManager.card_name(card),
		LocalizationManager.card_description(card),
			_display_card_cost(card),
		Util.load_card_art(card.id),
		target_rect.size,
		true,
		CARD_DISPLAY_FACTORY.has_upgrade_visual(card)
	)
	clone.disabled = true
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clone.z_index = 860
	clone.pivot_offset = target_rect.size * 0.5
	var deck_center: Vector2 = deck_chip.get_global_rect().get_center()
	clone.position = deck_center - target_rect.size * 0.5
	clone.scale = Vector2.ONE * 0.42
	clone.rotation_degrees = randf_range(-12.0, 12.0)
	clone.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(clone)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(clone, "position", target_rect.position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(clone, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(clone, "rotation_degrees", target_button.rotation_degrees, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(clone, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var reveal_tween: Tween = _make_scene_tween()
	if reveal_tween == null:
		return
	if delay > 0.0:
		reveal_tween.tween_interval(delay + 0.10)
	reveal_tween.tween_property(target_button, "modulate", final_modulate, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		target_button.modulate = final_modulate
		clone.queue_free()
	)

func _ensure_aim_view() -> void:
	if aim_view == null:
		aim_view = BATTLE_AIM_VIEW.new()
		add_child(aim_view)
		aim_view.setup(self)

func _update_aim_line() -> void:
	if aim_view == null:
		return
	if aimed_card == null or aimed_card_button == null or not is_instance_valid(aimed_card_button) or not _card_targets_enemy(aimed_card):
		aim_view.hide_aim()
		return
	var start_global: Vector2 = aimed_card_button.get_global_rect().get_center() + Vector2(0.0, -aimed_card_button.size.y * 0.18)
	aim_view.show_aim(start_global, get_global_mouse_position(), self)

func _shake_battlefield(intensity: float) -> void:
	# 屏幕震动强度倍率：设置中可调/关闭，减少动效模式关闭
	var shake_scale: float = SettingsManager.get_screen_shake() if SettingsManager != null else 1.0
	if shake_scale <= 0.0:
		return
	var scaled_intensity: float = intensity * shake_scale
	_shake_control(background_image, Vector2(8, 5) * scaled_intensity)
	_shake_control(shade, Vector2(6, 4) * scaled_intensity)
	_shake_control($Arena, Vector2(12, 7) * scaled_intensity)

func _flash_player_damage(amount: int) -> void:
	if player_damage_flash == null or not is_instance_valid(player_damage_flash) or amount <= 0:
		return
	var peak_alpha: float = clamp(0.16 + float(amount) / 80.0, 0.18, 0.38)
	player_damage_flash.visible = true
	player_damage_flash.color = Color(0.86, 0.08, 0.06, 0.0)
	var tween: Tween = _make_scene_tween()
	if tween == null:
		return
	tween.tween_property(player_damage_flash, "color:a", peak_alpha, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_damage_flash, "color:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(player_damage_flash):
			player_damage_flash.visible = false
	)

func _shake_control(control: Control, amplitude: Vector2) -> void:
	if control == null:
		return
	var key: int = control.get_instance_id()
	var base_position: Vector2 = control.get_meta("shake_base_position", control.position)
	var existing_tween: Tween = battlefield_shake_tweens.get(key) as Tween
	if existing_tween != null:
		existing_tween.kill()
	control.position = base_position
	control.set_meta("shake_base_position", base_position)
	var tween: Tween = UI_MOTION.shake(control, amplitude, 0.22, 4)
	battlefield_shake_tweens[key] = tween
	tween.finished.connect(func() -> void:
		control.position = base_position
		battlefield_shake_tweens.erase(key)
	)

func _make_scene_tween() -> Tween:
	if not is_inside_tree():
		return null
	var tween: Tween = create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 应用战斗速度倍率（设置项 battle_speed 控制，1.0 为原始速度）
	tween.set_speed_scale(_battle_animation_speed_scale())
	# 登记到统一注册表，_exit_tree 时集中清理；顺手剔除已完成/被 kill 的旧 tween，避免注册表无限增长
	var alive_tweens: Array[Tween] = []
	for registered in _scene_tweens:
		if is_instance_valid(registered) and registered.is_valid():
			alive_tweens.append(registered)
	_scene_tweens = alive_tweens
	_scene_tweens.append(tween)
	return tween

func _battle_animation_speed_scale() -> float:
	if SettingsManager != null and SettingsManager.has_method("get_battle_speed"):
		return SettingsManager.get_battle_speed()
	return 1.0

func _cycle_battle_speed() -> void:
	if SettingsManager == null or not SettingsManager.has_method("get_battle_speed"):
		return
	SfxManager.play_ui_click()
	var current_speed: float = SettingsManager.get_battle_speed()
	var next_index: int = 0
	for i in range(_BATTLE_SPEED_CYCLES.size()):
		if is_equal_approx(_BATTLE_SPEED_CYCLES[i], current_speed):
			next_index = (i + 1) % _BATTLE_SPEED_CYCLES.size()
			break
	SettingsManager.save_settings({"battle_speed": _BATTLE_SPEED_CYCLES[next_index]})
	_refresh_battle_speed_button()

func _refresh_battle_speed_button() -> void:
	if battle_speed_button == null:
		return
	var speed: float = _battle_animation_speed_scale()
	# 显示如 "1x"、"1.5x"、"2x"
	if is_equal_approx(speed, round(speed)):
		battle_speed_button.text = "%dx" % int(round(speed))
	else:
		battle_speed_button.text = "%.1fx" % speed

func _kill_scene_tween(tween: Tween) -> void:
	if tween != null:
		tween.kill()

func _clear_hand_card_tweens() -> void:
	for tween_value in hand_card_tweens.values():
		_kill_scene_tween(tween_value as Tween)
	hand_card_tweens.clear()

func _clear_battlefield_shake_tweens() -> void:
	for tween_value in battlefield_shake_tweens.values():
		_kill_scene_tween(tween_value as Tween)
	battlefield_shake_tweens.clear()

func _player_status_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if manager.player == null:
		return entries
	entries = _status_entries(manager.player)
	if manager.player.will > 0:
		entries.append({
			"icon": "意",
			"icon_texture": BATTLE_ICON_WILL,
			"amount": str(manager.player.will),
			"tooltip": LocalizationManager.text("battle.status_will", [
				manager.player.will,
				min(manager.player.will, 6),
				4 if manager.player.will >= 4 else 0
			]),
			"kind": "resource",
			"bg": Color(0.22, 0.28, 0.58, 0.88),
			"border": Color(0.72, 0.84, 1.0, 0.90),
			"fg": Color(0.98, 0.98, 1.0, 1.0)
		})
	var countdown_count: int = _count_curse_in_hand("blast_countdown")
	if countdown_count > 0:
		entries.append({
			"icon": "炸",
			"icon_texture": BATTLE_ICON_EXPLOSION,
			"amount": str(countdown_count),
			"tooltip": LocalizationManager.text("battle.status_blast_countdown", [countdown_count, countdown_count * 8]),
			"kind": "warning",
			"bg": Color(0.62, 0.18, 0.12, 0.90),
			"border": Color(1.0, 0.72, 0.52, 0.94),
			"fg": Color(1.0, 0.96, 0.92, 1.0)
		})
	if bool(manager.player.meta.get("support_trigger_ready", false)):
		entries.append({
			"icon": "领",
			"icon_texture": BATTLE_ICON_SUPPORT,
			"amount": "",
			"tooltip": LocalizationManager.text("battle.status_leader_ready"),
			"kind": "buff",
			"bg": Color(0.66, 0.44, 0.14, 0.88),
			"border": Color(1.0, 0.88, 0.54, 0.92),
			"fg": Color(1.0, 0.98, 0.92, 1.0)
		})
	if manager.player_character != null and manager.player_character.id == "nearl":
		var radiance: int = 0
		if manager.has_method("nearl_radiance"):
			radiance = int(manager.call("nearl_radiance"))
		if radiance > 0:
			entries.append({
				"icon": "耀",
				"icon_texture": SUPPORT_TILE_NEARL,
				"amount": str(radiance),
				"tooltip": LocalizationManager.text("battle.status_radiance", [
					radiance,
					int(manager.call("nearl_shield_bonus")) if manager.has_method("nearl_shield_bonus") else 0,
					int(manager.call("nearl_heal_bonus")) if manager.has_method("nearl_heal_bonus") else 0
				]),
				"kind": "buff",
				"bg": Color(0.64, 0.46, 0.12, 0.90),
				"border": Color(1.0, 0.90, 0.54, 0.96),
				"fg": Color(1.0, 0.98, 0.90, 1.0)
			})
		var counter_total: int = int(manager.player.meta.get("nearl_counter", 0))
		if counter_total > 0:
			entries.append({
				"icon": "反",
				"icon_texture": BATTLE_ICON_BLOCK,
				"amount": str(counter_total),
				"tooltip": LocalizationManager.text("battle.status_counter", [
					counter_total,
					radiance,
					int(manager.call("nearl_counter_damage")) if manager.has_method("nearl_counter_damage") else counter_total + radiance
				]),
				"kind": "buff",
				"bg": Color(0.20, 0.38, 0.50, 0.90),
				"border": Color(0.76, 0.94, 1.0, 0.94),
				"fg": Color(0.96, 0.99, 1.0, 1.0)
			})
		var next_reduction: int = int(manager.player.meta.get("nearl_next_damage_reduction", 0))
		if next_reduction > 0:
			entries.append({
				"icon": "减",
				"icon_texture": BATTLE_ICON_BLOCK,
				"amount": str(next_reduction),
				"tooltip": LocalizationManager.text("battle.status_next_damage_reduction", [next_reduction]),
				"kind": "buff",
				"bg": Color(0.24, 0.34, 0.54, 0.90),
				"border": Color(0.78, 0.88, 1.0, 0.94),
				"fg": Color(0.96, 0.98, 1.0, 1.0)
			})
	return entries

func _pending_reload_amount(unit: UnitState) -> int:
	var total: int = 0
	if unit == null:
		return total
	for raw_entry in unit.reload_queue:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var reload_entry: Dictionary = raw_entry
		total += int(reload_entry.get("amount", 0))
	return total

func _status_entries(unit: UnitState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit == null:
		return entries
	if unit.resonance > 0:
		entries.append({
			"icon": "共",
			"icon_texture": BATTLE_ICON_RESONANCE,
			"amount": str(unit.resonance),
			"tooltip": LocalizationManager.text("battle.status_resonance", [unit.resonance]),
			"kind": "debuff",
			"bg": Color(0.18, 0.34, 0.70, 0.90),
			"border": Color(0.74, 0.88, 1.0, 0.96),
			"fg": Color(0.98, 0.99, 1.0, 1.0)
		})
	if unit.max_ammo > 0:
		entries.append({
			"icon": "弹",
			"icon_texture": BATTLE_ICON_AMMO,
			"amount": str(unit.ammo),
			"tooltip": LocalizationManager.text("battle.status_ammo", [unit.ammo, unit.max_ammo]),
			"kind": "resource",
			"bg": Color(0.62, 0.22, 0.22, 0.88),
			"border": Color(1.0, 0.76, 0.72, 0.94),
			"fg": Color(1.0, 0.96, 0.92, 1.0)
		})
	var pending_reload: int = _pending_reload_amount(unit)
	if pending_reload > 0:
		entries.append({
			"icon": "装",
			"icon_texture": BATTLE_ICON_RELOAD,
			"amount": str(pending_reload),
			"tooltip": LocalizationManager.text("battle.status_reload", [pending_reload]),
			"kind": "buff",
			"bg": Color(0.22, 0.42, 0.60, 0.88),
			"border": Color(0.82, 0.92, 1.0, 0.94),
			"fg": Color(0.96, 0.98, 1.0, 1.0)
		})
	if unit.mark > 0:
		entries.append({
			"icon": "标",
			"icon_texture": BATTLE_ICON_MARK,
			"amount": str(unit.mark),
			"tooltip": LocalizationManager.text("battle.status_mark", [unit.mark]),
			"kind": "debuff",
			"bg": Color(0.52, 0.22, 0.48, 0.88),
			"border": Color(0.94, 0.78, 0.98, 0.94),
			"fg": Color(1.0, 0.96, 1.0, 1.0)
		})
	if unit.burst_active:
		entries.append({
			"icon": "爆",
			"icon_texture": BATTLE_ICON_BURST,
			"tooltip": LocalizationManager.text("battle.status_burst"),
			"kind": "buff",
			"bg": Color(0.72, 0.30, 0.18, 0.88),
			"border": Color(1.0, 0.84, 0.68, 0.94),
			"fg": Color(1.0, 0.98, 0.94, 1.0)
		})
	elif bool(unit.meta.get("burst_prepared_next_turn", false)):
		entries.append({
			"icon": "备",
			"icon_texture": BATTLE_ICON_BURST,
			"tooltip": LocalizationManager.text("battle.status_burst_prepared"),
			"kind": "buff",
			"bg": Color(0.54, 0.32, 0.18, 0.88),
			"border": Color(1.0, 0.78, 0.52, 0.94),
			"fg": Color(1.0, 0.96, 0.88, 1.0)
		})
	var status_ids: Array[String] = []
	for status_id in unit.statuses.keys():
		status_ids.append(String(status_id))
	status_ids.sort()
	for status_id in status_ids:
		var amount: int = int(unit.statuses.get(status_id, 0))
		if amount <= 0:
			continue
		match status_id:
			"weak":
				entries.append({
					"icon": "虚",
					"icon_texture": BATTLE_ICON_WEAK,
					"amount": str(amount),
					"tooltip": LocalizationManager.text("battle.status_weak", [amount]),
					"kind": "debuff",
					"bg": Color(0.34, 0.18, 0.54, 0.88),
					"border": Color(0.76, 0.58, 1.0, 0.92),
					"fg": Color(0.98, 0.94, 1.0, 1.0)
				})
			"vulnerable":
				entries.append({
					"icon": "易",
					"icon_texture": BATTLE_ICON_VULNERABLE,
					"amount": str(amount),
					"tooltip": LocalizationManager.text("battle.status_vulnerable", [amount]),
					"kind": "debuff",
					"bg": Color(0.62, 0.18, 0.18, 0.88),
					"border": Color(1.0, 0.68, 0.68, 0.92),
					"fg": Color(1.0, 0.96, 0.96, 1.0)
				})
			"strength":
				entries.append({
					"icon": "力",
					"icon_texture": BATTLE_ICON_STRENGTH,
					"amount": str(amount),
					"tooltip": LocalizationManager.text("battle.status_strength", [amount, amount]),
					"kind": "buff",
					"bg": Color(0.68, 0.34, 0.10, 0.88),
					"border": Color(1.0, 0.82, 0.56, 0.92),
					"fg": Color(1.0, 0.98, 0.94, 1.0)
				})
	return entries

func _select_enemy_target(index: int, silent: bool = false) -> void:
	if index < 0 or index >= manager.enemies.size():
		return
	selected_target_index = index
	if not silent:
		var enemy: UnitState = manager.enemies[index]
		_append_log(LocalizationManager.text("battle.targeting", [LocalizationManager.enemy_name(enemy.id, enemy.display_name)]), "info")
	_refresh_actor_views()
	_refresh_combat_info()
	_update_aim_hint()
	_update_enemy_intent_panel()

func _on_enemy_actor_hovered(index: int) -> void:
	if aimed_card_index == -1 or aimed_card == null:
		return
	if not _card_targets_enemy(aimed_card):
		return
	if index == selected_target_index:
		return
	_select_enemy_target(index, true)

func _on_enemy_actor_pressed(index: int) -> void:
	if aimed_card_index != -1 and aimed_card != null and _card_targets_enemy(aimed_card):
		_select_enemy_target(index, true)
		_confirm_aimed_card()
		return
	_select_enemy_target(index)

func _refresh_combat_info() -> void:
	if manager.player == null:
		return
	if aimed_card != null and _card_targets_enemy(aimed_card):
		combat_info.text = LocalizationManager.text("battle.combat_info_aim", [
			manager.turn_count,
			_target_name(),
			LocalizationManager.card_name(aimed_card)
		])
		return
	combat_info.text = LocalizationManager.text("battle.combat_info", [
		manager.turn_count,
		_target_name(),
		LocalizationManager.text("battle.buff_ready") if bool(manager.player.meta.get("support_trigger_ready", false)) else LocalizationManager.text("battle.buff_idle")
	])

func _update_aim_hint() -> void:
	if aim_hint_panel == null:
		return
	if aimed_card != null and _card_targets_enemy(aimed_card):
		aim_hint_panel.visible = true
		aim_hint_title.text = LocalizationManager.text("battle.target_hint_title", [LocalizationManager.card_name(aimed_card)])
		aim_hint_body.text = LocalizationManager.text("battle.target_hint_body", [_target_name()])
		aim_hint_panel.self_modulate = Color(1.0, 0.92, 0.78, 0.98)
	else:
		aim_hint_panel.visible = false

func _is_targeting_enemy_now() -> bool:
	if aimed_card != null:
		return _card_targets_enemy(aimed_card)
	return _hovered_card_targets_enemy()

func _unhandled_input(event: InputEvent) -> void:
	if aimed_card_index == -1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_clear_aim_mode()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_aim_mode()
		get_viewport().set_input_as_handled()

func _enemy_index_at_global_pos(global_pos: Vector2) -> int:
	for i in range(min(enemy_actor_views.size(), manager.enemies.size())):
		var actor_view: CombatActorView = enemy_actor_views[i]
		if actor_view == null or not is_instance_valid(actor_view):
			continue
		if manager.enemies[i] == null or manager.enemies[i].is_dead():
			continue
		if actor_view.get_global_rect().has_point(global_pos):
			return i
	return -1

func _poll_aim_release() -> void:
	if aimed_card_index == -1 or not aim_pointer_down:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	aim_pointer_down = false
	var mouse_pos: Vector2 = get_global_mouse_position()
	var enemy_index: int = _enemy_index_at_global_pos(mouse_pos)
	if enemy_index != -1:
		_select_enemy_target(enemy_index, true)
		_confirm_aimed_card()
		return
	if aimed_card_button != null and is_instance_valid(aimed_card_button) and aimed_card_button.get_global_rect().has_point(mouse_pos):
		hovered_hand_card = aimed_card_button
		_refresh_actor_views()
		_refresh_combat_info()
		_update_aim_hint()
		_update_enemy_intent_panel()
		_layout_hand_fan(true)
		return
	_clear_aim_mode()

func _style_energy_orb() -> void:
	UI_THEME_KIT.apply_energy_panel(energy_panel)
	UI_THEME_KIT.apply_numeric(energy_label, 38, Color(1.0, 0.98, 0.94, 1.0))
	energy_icon.add_theme_color_override("font_color", Color(1.0, 0.74, 0.18, 0.90))
	UI_MOTION.breathe(energy_panel, 0.90, 1.0, 1.7)

func _ensure_end_turn_warning_label() -> void:
	if end_turn_warning_label != null:
		return
	end_turn_warning_label = Label.new()
	end_turn_warning_label.name = "EndTurnWarning"
	end_turn_warning_label.layout_mode = 1
	end_turn_warning_label.anchor_left = 0.79
	end_turn_warning_label.anchor_top = 0.01
	end_turn_warning_label.anchor_right = 0.98
	end_turn_warning_label.anchor_bottom = 0.09
	end_turn_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_turn_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_turn_warning_label.add_theme_font_size_override("font_size", 18)
	end_turn_warning_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88, 1.0))
	end_turn_warning_label.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02, 0.96))
	end_turn_warning_label.add_theme_constant_override("outline_size", 4)
	end_turn_warning_label.visible = false
	$BottomHUD.add_child(end_turn_warning_label)

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_top_hud($TopHUD)
	UI_THEME_KIT.apply_glass_panel(hand_dock)
	UI_THEME_KIT.apply_log_panel(log_frame)
	UI_THEME_KIT.apply_glass_panel(player_frame)
	UI_THEME_KIT.apply_glass_panel(enemy_intent_frame)
	UI_THEME_KIT.apply_glass_panel(aim_hint_panel)
	UI_THEME_KIT.apply_health_hud_chip(health_chip, HUD_ICON_HP)
	UI_THEME_KIT.apply_hud_chip(gold_chip, HUD_ICON_GOLD, Color(1.0, 0.82, 0.36, 1.0), 18)
	UI_THEME_KIT.apply_hud_chip(floor_chip, HUD_ICON_FLOOR, Color(0.96, 0.84, 0.50, 1.0), 18)
	UI_THEME_KIT.apply_chip_label(turn_chip, Color(0.84, 1.0, 0.86, 1.0), 20)
	UI_THEME_KIT.apply_body(combat_info, 19, Color(0.97, 0.95, 0.90, 0.98))
	UI_THEME_KIT.apply_heading(player_stats, 24, Color(1.0, 0.96, 0.90, 1.0), Color(0.06, 0.06, 0.08, 0.72))
	UI_THEME_KIT.apply_body(enemy_intent_label, 19, Color(0.96, 0.92, 0.78, 1.0))
	UI_THEME_KIT.apply_heading(log_title, 18, Color(1.0, 0.94, 0.82, 1.0), Color(0.04, 0.04, 0.06, 0.72))
	UI_THEME_KIT.apply_body(log_subtitle, 14, Color(0.78, 0.84, 0.92, 0.82))
	UI_THEME_KIT.apply_heading(aim_hint_title, 22, Color(1.0, 0.95, 0.84, 1.0), Color(0.06, 0.04, 0.02, 0.70))
	UI_THEME_KIT.apply_body(aim_hint_body, 17, Color(0.90, 0.92, 0.96, 0.96))
	UI_THEME_KIT.apply_hud_chip(deck_chip, HUD_ICON_DECK, Color(0.60, 0.88, 1.0, 1.0), 18)
	UI_THEME_KIT.apply_hud_chip(discard_chip, HUD_ICON_DISCARD, Color(0.70, 0.72, 1.0, 1.0), 18)
	UI_THEME_KIT.apply_end_turn_button(end_turn_button)
	UI_THEME_KIT.apply_stone_button(settings_button, "ghost", 18)
	if battle_speed_button != null:
		UI_THEME_KIT.apply_stone_button(battle_speed_button, "ghost", 18)
		UI_MOTION.wire_button_feedback(battle_speed_button, 1.03, 0.97, Color(1.0, 0.88, 0.56, 0.62), 4.0)
	end_turn_button.set_meta("sfx_click_disabled", true)
	UI_MOTION.wire_button_feedback(deck_chip, 1.03, 0.97, Color(0.72, 0.90, 1.0, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(discard_chip, 1.03, 0.97, Color(0.82, 0.88, 1.0, 0.72), 5.0)
	UI_MOTION.wire_button_feedback(end_turn_button, 1.03, 0.97, Color(1.0, 0.88, 0.64, 0.80), 6.0)
	if support_banner != null:
		UI_THEME_KIT.apply_glass_panel(support_banner)
		var support_style: StyleBoxFlat = support_banner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if support_style != null:
			support_style.bg_color = Color(0.08, 0.12, 0.18, 0.82)
			support_style.border_color = Color(1.0, 0.88, 0.66, 0.66)
			support_style.border_width_left = 2
			support_style.border_width_top = 2
			support_style.border_width_right = 2
			support_style.border_width_bottom = 2
			support_style.shadow_color = Color(0.38, 0.70, 1.0, 0.20)
			support_style.shadow_size = 20
			support_banner.add_theme_stylebox_override("panel", support_style)
	if support_banner_title != null:
		UI_THEME_KIT.apply_heading(support_banner_title, 18, Color(1.0, 0.92, 0.70, 1.0), Color(0.04, 0.05, 0.08, 0.76))
	if support_banner_body != null:
		UI_THEME_KIT.apply_body(support_banner_body, 16, Color(0.92, 0.96, 1.0, 0.96))
	if support_cutin != null:
		UI_THEME_KIT.apply_glass_panel(support_cutin)
		var cutin_style: StyleBoxFlat = support_cutin.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if cutin_style != null:
			cutin_style.bg_color = Color(0.14, 0.10, 0.08, 0.86)
			cutin_style.border_color = Color(1.0, 0.86, 0.56, 0.74)
			cutin_style.border_width_left = 3
			cutin_style.border_width_top = 1
			cutin_style.border_width_right = 1
			cutin_style.border_width_bottom = 1
			cutin_style.shadow_color = Color(1.0, 0.76, 0.36, 0.22)
			cutin_style.shadow_size = 18
			support_cutin.add_theme_stylebox_override("panel", cutin_style)
	if support_cutin_badge != null:
		support_cutin_badge.add_theme_stylebox_override("panel", _make_feedback_badge_style(
			Color(0.42, 0.24, 0.10, 0.96),
			Color(1.0, 0.88, 0.62, 0.94),
			Color(0.42, 0.24, 0.10, 0.24)
		))
	if support_cutin_icon != null:
		support_cutin_icon.modulate = Color(1.0, 0.98, 0.92, 1.0)
	if support_cutin_title != null:
		UI_THEME_KIT.apply_heading(support_cutin_title, 18, Color(1.0, 0.92, 0.72, 1.0), Color(0.04, 0.05, 0.08, 0.76))
	if support_cutin_body != null:
		UI_THEME_KIT.apply_body(support_cutin_body, 16, Color(0.96, 0.96, 0.94, 0.98))

func _log_tone_color(tone: String) -> Color:
	match tone:
		"info":
			return Color(0.80, 0.90, 1.0, 0.96)
		"action":
			return Color(1.0, 0.92, 0.80, 0.96)
		"warning":
			return Color(1.0, 0.76, 0.70, 0.98)
		_:
			return Color(0.96, 0.96, 0.96, 0.94)

func _update_end_turn_warning() -> void:
	if end_turn_warning_label == null:
		return
	var countdown_count: int = _count_curse_in_hand("blast_countdown")
	var any_w_phase_three: bool = _any_enemy_w_phase_three()
	var any_w_phase_two: bool = _any_enemy_w_phase_two()
	if countdown_count > 0:
		end_turn_warning_label.visible = true
		end_turn_warning_label.text = LocalizationManager.text("battle.warning_bomb", [countdown_count])
		end_turn_warning_label.self_modulate = Color(1.0, 0.62, 0.36, 1.0)
		end_turn_button.self_modulate = Color(1.0, 0.78, 0.72, 1.0)
		end_turn_button.tooltip_text = LocalizationManager.text("battle.warning_bomb_tooltip", [countdown_count])
	elif any_w_phase_three:
		end_turn_warning_label.visible = true
		end_turn_warning_label.text = LocalizationManager.text("battle.warning_w_phase3")
		end_turn_warning_label.self_modulate = Color(1.0, 0.56, 0.52, 0.98)
		end_turn_button.self_modulate = Color(1.0, 0.86, 0.82, 1.0)
		end_turn_button.tooltip_text = LocalizationManager.text("battle.warning_w_phase3_tooltip")
	elif any_w_phase_two:
		end_turn_warning_label.visible = true
		end_turn_warning_label.text = LocalizationManager.text("battle.warning_w_phase2")
		end_turn_warning_label.self_modulate = Color(1.0, 0.76, 0.72, 0.96)
		end_turn_button.self_modulate = Color(1.0, 0.92, 0.90, 1.0)
		end_turn_button.tooltip_text = LocalizationManager.text("battle.warning_w_phase2_tooltip")
	else:
		end_turn_warning_label.visible = false
		end_turn_button.self_modulate = Color(0.90, 0.94, 1.0, 1.0)
		end_turn_button.tooltip_text = ""

func _intent_visuals(source_enemy: UnitState, intent: Dictionary) -> Dictionary:
	var intent_type: String = _intent_display_type(intent)
	var label_text: String = LocalizationManager.intent_label(_intent_display_label(intent))
	match intent_type:
		"attack":
			var preview_amount: int = _intent_display_value(intent)
			var preview: Dictionary = manager.resolver.preview_damage(
				source_enemy,
				manager.player,
				preview_amount,
				null,
				true
			)
			var damage_before_block: int = int(preview.get("damage_before_block", 0))
			var absorbed: int = int(preview.get("absorbed", 0))
			var damage_after_block: int = int(preview.get("damage_after_block", 0))
			var attack_tooltip: String = LocalizationManager.text("battle.intent_attack_tooltip", [
				label_text,
				damage_before_block,
				absorbed,
				damage_after_block
			])
			if _intent_is_disguised(intent):
				attack_tooltip += LocalizationManager.text("battle.intent_disguised")
			return {
				"icon_texture": INTENT_ICON_ATTACK,
				"icon": "⚔",
				"value": str(damage_before_block),
				"color": Color(1.0, 0.42, 0.32, 1.0),
				"tooltip": attack_tooltip
			}
		"apply_curse", "shuffle_and_debuff":
			var curse_count: int = max(1, _intent_display_value(intent))
			var curse_value_text: String = "×%d" % curse_count if curse_count > 1 else "!"
			return {
				"icon_texture": INTENT_ICON_DEBUFF,
				"icon": "✦",
				"value": curse_value_text,
				"color": Color(0.92, 0.48, 1.0, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_curse_count_tooltip", [label_text, curse_count])
			}
		"rule_shift":
			return {
				"icon_texture": INTENT_ICON_BUFF,
				"icon": "↯",
				"value": "",
				"color": Color(1.0, 0.82, 0.34, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_rule_tooltip", [label_text])
			}
		"gain_block":
			var block_value: int = _intent_display_value(intent)
			return {
				"icon_texture": INTENT_ICON_BUFF,
				"icon": "🛡",
				"value": "+%d" % block_value,
				"color": Color(0.62, 0.88, 1.0, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_block_tooltip", [label_text, block_value])
			}
		"apply_debuff":
			return {
				"icon_texture": INTENT_ICON_DEBUFF,
				"icon": "✦",
				"value": "!",
				"color": Color(0.92, 0.48, 1.0, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_debuff_tooltip", [label_text])
			}
		"charge":
			var charge_value: int = _intent_display_value(intent)
			return {
				"icon_texture": INTENT_ICON_BUFF,
				"icon": "◈",
				"value": "+%d" % charge_value,
				"color": Color(1.0, 0.70, 0.28, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_charge_tooltip", [label_text, charge_value])
			}
		"release":
			var charged_damage: int = int(source_enemy.meta.get("charged_damage", 0))
			return {
				"icon_texture": INTENT_ICON_SPECIAL,
				"icon": "💥",
				"value": str(charged_damage),
				"color": Color(1.0, 0.36, 0.18, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_release_tooltip", [label_text, charged_damage])
			}
		_:
			return {
				"icon_texture": INTENT_ICON_SPECIAL,
				"icon": "◆",
				"value": "",
				"color": Color(0.34, 0.78, 0.96, 1.0),
				"tooltip": LocalizationManager.text("battle.intent_other_tooltip", [label_text])
			}

func _intent_display_type(intent: Dictionary) -> String:
	return String(intent.get("display_type", intent.get("type", "attack")))

func _intent_display_label(intent: Dictionary) -> String:
	return String(intent.get("display_label", intent.get("label", "Unknown")))

func _intent_display_value(intent: Dictionary) -> int:
	return int(intent.get("display_value", intent.get("value", 0)))

func _intent_is_disguised(intent: Dictionary) -> bool:
	if not intent.has("display_type") and not intent.has("display_value") and not intent.has("display_label"):
		return false
	var type_changed: bool = String(intent.get("display_type", intent.get("type", ""))) != String(intent.get("type", ""))
	var value_changed: bool = int(intent.get("display_value", intent.get("value", 0))) != int(intent.get("value", 0))
	var label_changed: bool = String(intent.get("display_label", intent.get("label", ""))) != String(intent.get("label", ""))
	return type_changed or value_changed or label_changed

func _unit_display_name(unit: UnitState) -> String:
	if unit == null:
		return LocalizationManager.text("battle.target_none")
	if manager.player == unit:
		return LocalizationManager.active_character_name()
	return LocalizationManager.enemy_name(unit.id, unit.display_name)

func _count_curse_in_hand(curse_id: String) -> int:
	if manager == null or manager.deck == null:
		return 0
	var total: int = 0
	for card in manager.deck.hand:
		if card != null and card.id == curse_id:
			total += 1
	return total

func _enemy_is_bomb_threat(enemy: UnitState) -> bool:
	if enemy == null:
		return false
	return String(enemy.intent.get("type", "")) == "apply_curse" and String(enemy.intent.get("curse", "")) == "blast_countdown"

func _enemy_w_phase(index: int) -> int:
	if index < 0 or index >= manager.enemies.size() or index >= manager.enemy_datas.size():
		return 0
	var enemy: UnitState = manager.enemies[index]
	if enemy == null:
		return 0
	if manager.enemy_datas[index].id != "w_boss":
		return 0
	if enemy.hp <= int(ceil(float(enemy.max_hp) * 0.25)) or bool(enemy.intent.get("phase_three", false)):
		return 3
	if enemy.hp <= int(ceil(float(enemy.max_hp) * 0.5)) or bool(enemy.intent.get("phase_two", false)):
		return 2
	return 1

func _enemy_is_w_phase_two(index: int) -> bool:
	return _enemy_w_phase(index) >= 2

func _enemy_is_w_phase_three(index: int) -> bool:
	return _enemy_w_phase(index) >= 3

func _any_enemy_w_phase_two() -> bool:
	for index in range(min(manager.enemies.size(), manager.enemy_datas.size())):
		if _enemy_is_w_phase_two(index):
			return true
	return false

func _any_enemy_w_phase_three() -> bool:
	for index in range(min(manager.enemies.size(), manager.enemy_datas.size())):
		if _enemy_is_w_phase_three(index):
			return true
	return false
