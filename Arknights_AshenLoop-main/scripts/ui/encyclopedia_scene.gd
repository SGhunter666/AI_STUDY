extends Control

const CARD_GALLERY_OVERLAY = preload("res://scripts/ui/card_gallery_overlay.gd")
const COMPENDIUM_OVERLAY = preload("res://scripts/ui/compendium_overlay.gd")
const TUNE_SUMMARY_PRESENTER = preload("res://scripts/ui/tune_summary_presenter.gd")
const UI_MOTION = preload("res://scripts/core/ui_motion.gd")
const UI_THEME_KIT = preload("res://scripts/ui/ui_theme_kit.gd")
const CHARACTER_ARCHIVE_ORDER: Array[String] = ["amiya", "nearl", "exusiai", "kaltsit"]

@onready var title_label: Label = $Title
@onready var header_panel: PanelContainer = $Margin/Scroll/Root/HeaderPanel
@onready var header_eyebrow: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderEyebrow
@onready var header_title: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderTitle
@onready var header_body: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderBody
@onready var cards_chip_label: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderStatsRow/CardsChip/ChipMargin/ChipLabel
@onready var modules_chip_label: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderStatsRow/ModulesChip/ChipMargin/ChipLabel
@onready var monsters_chip_label: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderStatsRow/MonstersChip/ChipMargin/ChipLabel
@onready var history_chip_label: Label = $Margin/Scroll/Root/HeaderPanel/HeaderMargin/HeaderBox/HeaderStatsRow/HistoryChip/ChipMargin/ChipLabel
@onready var primary_label: Label = $Margin/Scroll/Root/PrimaryLabel
@onready var secondary_label: Label = $Margin/Scroll/Root/SecondaryLabel
@onready var detail_panel: PanelContainer = $Margin/Scroll/Root/DetailPanel
@onready var detail_label: Label = $Margin/Scroll/Root/DetailPanel/DetailMargin/DetailLabel
@onready var scroll: ScrollContainer = $Margin/Scroll
@onready var back_button: Button = $BackButton
@onready var top_row: Container = $Margin/Scroll/Root/TopRow
@onready var bottom_row: Container = $Margin/Scroll/Root/BottomRow
@onready var cards_button: Button = $Margin/Scroll/Root/TopRow/CardsEntry
@onready var modules_button: Button = $Margin/Scroll/Root/TopRow/ModulesEntry
@onready var lab_button: Button = $Margin/Scroll/Root/TopRow/LabEntry
@onready var monster_button: Button = $Margin/Scroll/Root/TopRow/MonsterEntry
@onready var stats_button: Button = $Margin/Scroll/Root/BottomRow/StatsEntry
@onready var glossary_button: Button = $Margin/Scroll/Root/BottomRow/GlossaryEntry
@onready var history_button: Button = $Margin/Scroll/Root/BottomRow/HistoryEntry

var card_db: Dictionary = {}
var module_db: Dictionary = {}
var enemy_db: Dictionary = {}
var character_db: Dictionary = {}
var selected_entry_id: String = "cards"

func _ready() -> void:
	card_db = Util.load_card_db()
	module_db = Util.load_module_db()
	enemy_db = Util.load_enemy_db()
	character_db = Util.load_character_db()
	_prepare_interaction_layout()
	_apply_ui_theme()
	_apply_text()
	LocalizationManager.language_changed.connect(_apply_text)
	_select_entry("cards")
	call_deferred("_play_intro_animation")

func _exit_tree() -> void:
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)

func _apply_text(_language_code: String = "") -> void:
	var archive_card_count: int = _archive_card_count()
	title_label.text = LocalizationManager.text("codex.title")
	header_eyebrow.text = LocalizationManager.text("codex.header_eyebrow")
	header_title.text = LocalizationManager.text("codex.header_title")
	header_body.text = LocalizationManager.text("codex.header_body", [
		archive_card_count,
		module_db.size(),
		enemy_db.size()
	])
	primary_label.text = LocalizationManager.text("codex.section_primary")
	secondary_label.text = LocalizationManager.text("codex.section_secondary")
	back_button.text = LocalizationManager.text("codex.back")
	cards_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.cards"),
		LocalizationManager.text("codex.header_cards_chip", [archive_card_count])
	]
	modules_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.modules"),
		LocalizationManager.text("codex.header_modules_chip", [module_db.size()])
	]
	lab_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.lab"),
		LocalizationManager.text("codex.lab_body")
	]
	monster_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.monsters"),
		LocalizationManager.text("codex.header_monsters_chip", [enemy_db.size()])
	]
	stats_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.stats"),
		LocalizationManager.text("codex.stats_body")
	]
	glossary_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.glossary"),
		LocalizationManager.text("codex.glossary_body")
	]
	history_button.text = "%s\n%s" % [
		LocalizationManager.text("codex.history"),
		LocalizationManager.text("codex.header_history_chip", [_history_count()])
	]
	_update_header_stats()
	_refresh_entry_styles()

func _select_entry(entry_id: String) -> void:
	selected_entry_id = entry_id
	detail_label.text = LocalizationManager.text("codex.detail_%s" % entry_id)
	_refresh_entry_styles()

func _on_back_pressed() -> void:
	SceneRouter.go_main_menu()

func _on_cards_pressed() -> void:
	_select_entry("cards")
	_open_card_archive()

func _on_modules_pressed() -> void:
	_select_entry("modules")
	_open_module_archive()

func _on_lab_pressed() -> void:
	_select_entry("lab")
	_open_lab_archive()

func _on_monsters_pressed() -> void:
	_select_entry("monsters")
	_open_enemy_archive()

func _on_stats_pressed() -> void:
	_select_entry("stats")
	_open_stats_archive()

func _on_history_pressed() -> void:
	_select_entry("history")
	_open_history_archive()

func _on_glossary_pressed() -> void:
	_select_entry("glossary")
	_open_glossary_archive()

func _open_card_archive() -> void:
	var overlay: CardGalleryOverlay = CARD_GALLERY_OVERLAY.new()
	overlay.setup_sections(LocalizationManager.text("codex.cards"), _card_archive_sections())
	add_child(overlay)

func _open_module_archive() -> void:
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup_sections(LocalizationManager.text("codex.modules_title"), _module_archive_sections())
	add_child(overlay)

func _open_enemy_archive() -> void:
	var entries: Array[Dictionary] = []
	var ids: Array[String] = []
	for raw_id in enemy_db.keys():
		ids.append(String(raw_id))
	ids.sort()
	for id in ids:
		var enemy_data: EnemyData = enemy_db[id] as EnemyData
		if enemy_data == null:
			continue
		var move_labels: Array[String] = []
		for move_variant in enemy_data.moves:
			if typeof(move_variant) != TYPE_DICTIONARY:
				continue
			var move: Dictionary = move_variant
			move_labels.append(LocalizationManager.intent_label(String(move.get("label", "Unknown"))))
		var tags: Array[String] = []
		for raw_tag in enemy_data.tags:
			tags.append(LocalizationManager.enemy_tag_name(String(raw_tag)))
		var subtitle: String = "%s   |   %s" % [
			LocalizationManager.text("codex.enemy_hp", [enemy_data.max_hp]),
			LocalizationManager.text("codex.enemy_gold", [enemy_data.gold_reward])
		]
		var body_lines: Array[String] = []
		if not tags.is_empty():
			body_lines.append(LocalizationManager.text("codex.enemy_tags", [", ".join(tags)]))
		body_lines.append(LocalizationManager.text("codex.enemy_ai", [LocalizationManager.ai_profile_name(enemy_data.ai_profile)]))
		if not move_labels.is_empty():
			body_lines.append(LocalizationManager.text("codex.enemy_moves", [", ".join(move_labels)]))
		entries.append({
			"title": LocalizationManager.enemy_name(enemy_data.id, enemy_data.display_name),
			"subtitle": subtitle,
			"body": "\n".join(body_lines),
			"accent": _enemy_accent(enemy_data),
			"image_path": _enemy_archive_image_path(enemy_data.id),
			"display_mode": "grid"
		})
	_open_compendium(LocalizationManager.text("codex.monsters_title"), entries)


func _enemy_archive_image_path(enemy_id: String) -> String:
	var direct_path: String = "res://assets/enemy_portraits/%s.png" % enemy_id
	# 用 ResourceLoader.exists 检查（支持 PCK 导出），不用 globalize_path
	if ResourceLoader.exists(direct_path):
		return direct_path
	match enemy_id:
		"reunion_scout":
			return "res://assets/enemy_portraits/reunion_scout.png"
		"reunion_caster":
			return "res://assets/enemy_portraits/reunion_caster.png"
		"riot_shieldbearer":
			return "res://assets/enemy_portraits/riot_shieldbearer.png"
		"crossbow_sniper":
			return "res://assets/enemy_portraits/crossbow_sniper.png"
		"field_captain":
			return "res://assets/enemy_portraits/field_captain.png"
		"originium_channeler":
			return "res://assets/enemy_portraits/originium_channeler.png"
		"scout_chief":
			return "res://assets/enemy_portraits/scout_chief.png"
		"lockdown_core":
			return "res://assets/enemy_portraits/lockdown_core.png"
		"w_boss":
			return "res://assets/enemy_portraits/w_boss.png"
		"ash_echo":
			return "res://assets/enemy_portraits/ash_echo.png"
	return ""

func _open_lab_archive() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	var entries: Array[Dictionary] = [
		{
			"title": LocalizationManager.text("codex.lab_entry_supply_title"),
			"body": LocalizationManager.text("codex.lab_entry_supply_body"),
			"accent": Color(0.72, 0.92, 1.0, 0.72),
			"display_mode": "grid"
		},
		{
			"title": LocalizationManager.text("codex.lab_entry_alchemy_title"),
			"body": LocalizationManager.text("codex.lab_entry_alchemy_body"),
			"accent": Color(0.86, 0.78, 1.0, 0.72),
			"display_mode": "grid"
		},
		{
			"title": LocalizationManager.text("codex.lab_entry_progress_title"),
			"body": LocalizationManager.text("codex.lab_entry_progress_body"),
			"accent": Color(0.98, 0.88, 0.62, 0.72),
			"display_mode": "grid"
		},
		{
			"title": LocalizationManager.text("codex.lab_entry_archive_title"),
			"body": LocalizationManager.text("codex.lab_entry_archive_body", [
				_archive_card_count(),
				module_db.size(),
				enemy_db.size(),
				history.size()
			]),
			"accent": Color(0.82, 0.92, 0.74, 0.72),
			"display_mode": "grid"
		}
	]
	_open_compendium(LocalizationManager.text("codex.lab_title"), entries)

func _open_stats_archive() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	var stats: Dictionary = profile.get("stats", {}) if typeof(profile.get("stats", {})) == TYPE_DICTIONARY else {}
	var runs_started: int = int(stats.get("runs_started", 0))
	var runs_won: int = int(stats.get("runs_won", 0))
	var win_rate: int = int(round((float(runs_won) / float(runs_started)) * 100.0)) if runs_started > 0 else 0
	var summary_entries: Array[Dictionary] = [
		{
			"title": LocalizationManager.text("codex.stats_profile_title"),
			"body": "\n".join([
				LocalizationManager.text("codex.stats_runs", [runs_started]),
				LocalizationManager.text("codex.stats_wins", [runs_won]),
				LocalizationManager.text("codex.stats_losses", [int(stats.get("runs_lost", 0))]),
				LocalizationManager.text("codex.stats_best_floor", [int(stats.get("best_floor", 0))]),
				LocalizationManager.text("codex.stats_total_gold", [int(stats.get("total_gold_collected", 0))]),
				LocalizationManager.text("codex.stats_winrate", [win_rate])
			]),
			"accent": Color(0.72, 0.90, 1.0, 0.82)
		}
	]
	# Meta 解锁进度统计
	var meta_progress_lines: Array[String] = []
	var seen_cards: int = _archive_card_count()
	var locked_cards: int = _archive_locked_card_count()
	var total_cards: int = seen_cards + locked_cards
	var card_progress: int = int(round((float(seen_cards) / float(total_cards)) * 100.0)) if total_cards > 0 else 0
	meta_progress_lines.append(LocalizationManager.text("meta.progress_cards", [seen_cards, total_cards, card_progress]))
	if MetaUnlockManager != null:
		var seen_modules: int = 0
		var total_modules: int = module_db.size()
		var unlocks: Dictionary = SaveManager.load_profile().get("meta_unlocks", {})
		seen_modules = Array(unlocks.get("modules_seen", [])).size()
		var module_progress: int = int(round((float(seen_modules) / float(total_modules)) * 100.0)) if total_modules > 0 else 0
		meta_progress_lines.append(LocalizationManager.text("meta.progress_modules", [seen_modules, total_modules, module_progress]))
		# 成就 flags
		var achievements: Array[String] = []
		if MetaUnlockManager.has_flag("first_victory_done"):
			achievements.append(LocalizationManager.text("meta.achievement_first_victory"))
		if MetaUnlockManager.has_flag("hidden_route_unlocked"):
			achievements.append(LocalizationManager.text("meta.achievement_hidden_route"))
		if MetaUnlockManager.has_flag("hidden_truth_cleared"):
			achievements.append(LocalizationManager.text("meta.achievement_hidden_truth"))
		if achievements.is_empty():
			meta_progress_lines.append(LocalizationManager.text("meta.achievements_none"))
		else:
			meta_progress_lines.append(LocalizationManager.text("meta.achievements_list", ["、".join(achievements)]))
	summary_entries.append({
		"title": LocalizationManager.text("meta.progress_title"),
		"body": "\n".join(meta_progress_lines),
		"accent": Color(0.96, 0.82, 0.58, 0.82)
	})
	var active_run_text: String
	if RunManager.has_saved_run():
		var save_data: Dictionary = RunManager.saved_run_summary()
		var active_lines: Array[String] = [
			LocalizationManager.text("codex.stats_active_operator", [
				LocalizationManager.character_name(String(save_data.get("character_id", "amiya")), "Amiya")
			]),
			LocalizationManager.text("codex.stats_active_run", [
			int(save_data.get("current_floor", 1)),
			int(save_data.get("hp", 0)),
			int(save_data.get("max_hp", 0)),
			int(save_data.get("gold", 0))
			]),
			LocalizationManager.text("codex.stats_deck_modules", [
				_save_array_size(save_data.get("deck", [])),
				_save_array_size(save_data.get("modules", []))
			])
		]
		active_run_text = "\n".join(active_lines)
	else:
		active_run_text = LocalizationManager.text("codex.stats_no_active_run")
	summary_entries.append({
		"title": LocalizationManager.text("single.resume"),
		"body": active_run_text,
		"accent": Color(0.95, 0.82, 0.62, 0.72)
	})
	summary_entries.append(TUNE_SUMMARY_PRESENTER.current_summary_entry())

	var sections: Array[Dictionary] = [
		{
			"title": LocalizationManager.text("codex.stats_summary_title"),
			"subtitle": LocalizationManager.text("codex.stats_summary_body"),
			"entries": summary_entries,
			"accent": Color(0.74, 0.90, 1.0, 0.82),
			"display_mode": "list"
		}
	]
	for character_id in _archive_character_ids():
		var character_stats: Dictionary = _character_profile_stats(profile, character_id)
		sections.append({
			"title": LocalizationManager.character_header(character_id, LocalizationManager.character_name(character_id, character_id.capitalize())),
			"subtitle": _operator_archive_tagline(character_id),
			"entries": [
				{
					"title": LocalizationManager.character_header(character_id, LocalizationManager.character_name(character_id, character_id.capitalize())),
					"subtitle": LocalizationManager.character_stats(character_id, ""),
					"body": _operator_archive_profile_body(character_id),
					"accent": _operator_accent(character_id),
					"image_path": _character_archive_image_path(character_id),
					"layout": "operator"
				},
				{
					"title": LocalizationManager.text("codex.stats_operator_summary_title"),
					"subtitle": _operator_archive_summary_caption(character_id),
					"body": _operator_archive_stat_body(character_id, character_stats),
					"accent": _operator_accent(character_id, 0.74)
				}
			],
			"accent": _operator_accent(character_id),
			"entry_columns": 2,
			"display_mode": "list"
		})
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup_sections(LocalizationManager.text("codex.stats_title"), sections)
	add_child(overlay)

func _open_history_archive() -> void:
	var profile: Dictionary = SaveManager.load_profile()
	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	var grouped_entries: Dictionary = {}
	for history_variant in history:
		if typeof(history_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = history_variant
		var result_key: String = "codex.history_victory" if String(item.get("result", "defeat")) == "victory" else "codex.history_defeat"
		var result_text: String = LocalizationManager.text(result_key)
		var character_id: String = String(item.get("character_id", "amiya"))
		var character_name: String = LocalizationManager.character_name(character_id, character_id.capitalize())
		var character_entries: Array = grouped_entries.get(character_id, [])
		character_entries.append({
			"title": LocalizationManager.text("codex.history_entry", [
				result_text,
				int(item.get("floor", 0)),
				int(item.get("gold", 0)),
				int(item.get("deck_size", 0)),
				int(item.get("modules", 0))
			]),
			"subtitle": _format_history_timestamp(int(item.get("timestamp", 0))),
			"body": LocalizationManager.text("codex.history_record_body", [
				character_name,
				result_text,
				int(item.get("floor", 0)),
				int(item.get("gold", 0)),
				int(item.get("deck_size", 0)),
				int(item.get("modules", 0))
			]),
			"accent": _operator_accent(character_id, 0.78) if String(item.get("result", "defeat")) == "victory" else Color(0.92, 0.62, 0.62, 0.72)
		})
		grouped_entries[character_id] = character_entries
	var sections: Array[Dictionary] = []
	for character_id in _archive_character_ids():
		var raw_entries: Variant = grouped_entries.get(character_id, [])
		if typeof(raw_entries) != TYPE_ARRAY or (raw_entries as Array).is_empty():
			continue
		sections.append({
			"title": LocalizationManager.character_header(character_id, LocalizationManager.character_name(character_id, character_id.capitalize())),
			"subtitle": LocalizationManager.text("codex.header_history_chip", [(raw_entries as Array).size()]),
			"entries": raw_entries,
			"accent": _operator_accent(character_id),
			"display_mode": "list"
		})
	if sections.is_empty():
		_open_compendium(LocalizationManager.text("codex.history_title"), [])
		return
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup_sections(LocalizationManager.text("codex.history_title"), sections)
	add_child(overlay)

func _open_glossary_archive() -> void:
	var sections: Array[Dictionary] = [
		{
			"title": LocalizationManager.text("codex.glossary_general_title"),
			"subtitle": LocalizationManager.text("codex.glossary_general_body"),
			"entries": [
				_glossary_entry("energy", Color(0.98, 0.88, 0.64, 0.80)),
				_glossary_entry("block", Color(0.80, 0.92, 1.0, 0.80)),
				_glossary_entry("weak", Color(0.92, 0.78, 0.62, 0.80)),
				_glossary_entry("vulnerable", Color(0.98, 0.74, 0.62, 0.80)),
				_glossary_entry("strength", Color(1.0, 0.72, 0.52, 0.80)),
				_glossary_entry("slow", Color(0.76, 0.92, 1.0, 0.80)),
				_glossary_entry("heal", Color(0.78, 0.96, 0.84, 0.80)),
				_glossary_entry("status", Color(0.86, 0.90, 0.98, 0.80)),
				_glossary_entry("curse", Color(0.90, 0.72, 0.98, 0.80)),
				_glossary_entry("exhaust", Color(0.90, 0.86, 0.70, 0.80)),
				_glossary_entry("ethereal", Color(0.84, 0.80, 0.98, 0.80)),
				_glossary_entry("aoe", Color(0.98, 0.84, 0.66, 0.80)),
				_glossary_entry("multihit", Color(0.76, 0.90, 1.0, 0.80))
			],
			"accent": Color(0.82, 0.90, 1.0, 0.82),
			"display_mode": "list"
		},
		{
			"title": LocalizationManager.text("codex.glossary_amiya_title"),
			"subtitle": LocalizationManager.text("codex.glossary_amiya_body"),
			"entries": [
				_glossary_entry("will", _operator_accent("amiya")),
				_glossary_entry("arts", Color(0.82, 0.86, 1.0, 0.80)),
				_glossary_entry("resonance", Color(0.72, 0.96, 1.0, 0.80)),
				_glossary_entry("echo", Color(0.76, 0.86, 1.0, 0.80)),
				_glossary_entry("support", Color(0.74, 0.94, 0.98, 0.80)),
				_glossary_entry("command", Color(0.72, 0.90, 1.0, 0.80)),
				_glossary_entry("tactic", Color(0.98, 0.88, 0.70, 0.80)),
				_glossary_entry("channel", Color(0.76, 0.90, 1.0, 0.80)),
				_glossary_entry("overload", Color(0.98, 0.74, 0.74, 0.80)),
				_glossary_entry("strain", Color(0.98, 0.70, 0.70, 0.82)),
				_glossary_entry("rescue", Color(0.82, 0.96, 0.78, 0.80))
			],
			"accent": _operator_accent("amiya"),
			"display_mode": "list"
		},
		{
			"title": LocalizationManager.text("codex.glossary_exusiai_title"),
			"subtitle": LocalizationManager.text("codex.glossary_exusiai_body"),
			"entries": [
				_glossary_entry("shot", _operator_accent("exusiai")),
				_glossary_entry("ammo", Color(1.0, 0.76, 0.72, 0.80)),
				_glossary_entry("reload", Color(0.82, 0.92, 1.0, 0.82)),
				_glossary_entry("mark", Color(0.96, 0.78, 0.98, 0.82)),
				_glossary_entry("burst", Color(1.0, 0.80, 0.68, 0.82)),
				_glossary_entry("tempo", Color(0.74, 0.94, 0.98, 0.82)),
				_glossary_entry("finisher", Color(1.0, 0.78, 0.72, 0.82))
			],
			"accent": _operator_accent("exusiai"),
			"display_mode": "list"
		},
		{
			"title": LocalizationManager.text("codex.glossary_kaltsit_title"),
			"subtitle": LocalizationManager.text("codex.glossary_kaltsit_body"),
			"entries": [
				_glossary_entry("mon3tr", _operator_accent("kaltsit")),
				_glossary_entry("integrity", Color(0.78, 1.0, 0.84, 0.82)),
				_glossary_entry("medical", Color(0.74, 1.0, 0.86, 0.82)),
				_glossary_entry("repair", Color(0.80, 0.98, 0.90, 0.82)),
				_glossary_entry("meltdown", Color(1.0, 0.74, 0.58, 0.82)),
				_glossary_entry("protocol", Color(0.82, 0.96, 0.80, 0.82)),
				_glossary_entry("scalpel", Color(0.80, 0.96, 1.0, 0.82)),
				_glossary_entry("command", Color(0.72, 0.90, 1.0, 0.80))
			],
			"accent": _operator_accent("kaltsit"),
			"display_mode": "list"
		}
	]
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup_sections(LocalizationManager.text("codex.glossary_title"), sections)
	add_child(overlay)

func _open_compendium(title_text: String, entries: Array[Dictionary]) -> void:
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.setup(title_text, entries)
	add_child(overlay)

func _module_accent(rarity: String) -> Color:
	match rarity:
		"Rare":
			return Color(0.96, 0.82, 0.58, 0.82)
		"Elite":
			return Color(0.88, 0.78, 1.0, 0.82)
		_:
			return Color(0.72, 0.92, 1.0, 0.82)

func _enemy_accent(enemy_data: EnemyData) -> Color:
	if "Boss" in enemy_data.tags:
		return Color(0.98, 0.72, 0.62, 0.82)
	if "Elite" in enemy_data.tags:
		return Color(0.92, 0.82, 0.58, 0.82)
	return Color(0.72, 0.92, 1.0, 0.82)

func _format_history_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix_time, true)

func _save_array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var array_value: Array = value
	return array_value.size()

func _apply_ui_theme() -> void:
	UI_THEME_KIT.apply_heading(title_label, 40, Color(0.98, 0.92, 0.72, 1.0), Color(0.10, 0.08, 0.03, 0.88))
	UI_THEME_KIT.apply_stone_button(back_button, "danger", 24)
	UI_MOTION.wire_button_feedback(back_button, 1.02, 0.98, Color(1.0, 0.86, 0.62, 0.76), 5.0)
	UI_THEME_KIT.apply_glass_panel(header_panel)
	UI_THEME_KIT.apply_chip_label(header_eyebrow, Color(0.86, 0.92, 1.0, 0.82), 16)
	UI_THEME_KIT.apply_glass_heading(header_title, 36)
	UI_THEME_KIT.apply_glass_body(header_body, 20)
	UI_THEME_KIT.apply_glass_heading(primary_label, 22)
	UI_THEME_KIT.apply_glass_heading(secondary_label, 22)
	UI_THEME_KIT.apply_page_section_panel(detail_panel)
	UI_THEME_KIT.apply_glass_body(detail_label, 21)
	for chip in _header_chip_labels():
		UI_THEME_KIT.apply_numeric(chip, 18, Color(0.98, 0.96, 0.88, 1.0), Color(0.06, 0.07, 0.10, 0.92))
		var chip_panel: PanelContainer = chip.get_parent().get_parent() as PanelContainer
		if chip_panel != null:
			UI_THEME_KIT.apply_paper_panel(chip_panel)
	for button in _all_entry_buttons():
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = false
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		UI_MOTION.wire_button_feedback(button, 1.02, 0.98, Color(0.88, 0.96, 1.0, 0.74), 6.0)
		button.icon = _entry_icon_texture(button)
		button.expand_icon = false
	_refresh_entry_styles()

func _refresh_entry_styles() -> void:
	for button in _large_entry_buttons():
		var is_selected: bool = button == _button_for_entry(selected_entry_id)
		_apply_directory_button_style(button, is_selected, 28, Vector2(0, 104))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for button in _small_entry_buttons():
		var is_selected: bool = button == _button_for_entry(selected_entry_id)
		_apply_directory_button_style(button, is_selected, 24, Vector2(0, 92))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _all_entry_buttons() -> Array[Button]:
	return [
		cards_button,
		modules_button,
		lab_button,
		monster_button,
		stats_button,
		glossary_button,
		history_button
	]

func _large_entry_buttons() -> Array[Button]:
	return [cards_button, modules_button, lab_button, monster_button]

func _small_entry_buttons() -> Array[Button]:
	return [stats_button, glossary_button, history_button]

func _button_for_entry(entry_id: String) -> Button:
	match entry_id:
		"cards":
			return cards_button
		"modules":
			return modules_button
		"lab":
			return lab_button
		"monsters":
			return monster_button
		"stats":
			return stats_button
		"glossary":
			return glossary_button
		"history":
			return history_button
	return null

func _play_intro_animation() -> void:
	UI_MOTION.reveal(back_button, 0.00, Vector2(-18, 0), 0.24, Vector2(0.98, 0.98))
	UI_MOTION.reveal(title_label, 0.02, Vector2(0, 20), 0.28, Vector2(0.99, 0.99))
	_fade_reveal(primary_label, 0.06)
	var top_delay: float = 0.10
	for button in _large_entry_buttons():
		_fade_reveal(button, top_delay, 0.98)
		top_delay += 0.03
	_fade_reveal(secondary_label, top_delay + 0.02)
	var bottom_delay: float = top_delay + 0.06
	for button in _small_entry_buttons():
		_fade_reveal(button, bottom_delay, 0.985)
		bottom_delay += 0.03
	_fade_reveal(detail_panel, bottom_delay + 0.04)

func _update_header_stats() -> void:
	cards_chip_label.text = LocalizationManager.text("codex.header_cards_chip", [_archive_card_count()])
	modules_chip_label.text = LocalizationManager.text("codex.header_modules_chip", [module_db.size()])
	monsters_chip_label.text = LocalizationManager.text("codex.header_monsters_chip", [enemy_db.size()])
	history_chip_label.text = LocalizationManager.text("codex.header_history_chip", [_history_count()])

func _history_count() -> int:
	var profile: Dictionary = SaveManager.load_profile()
	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	return history.size()

func _header_chip_labels() -> Array[Label]:
	return [
		cards_chip_label,
		modules_chip_label,
		monsters_chip_label,
		history_chip_label
	]

func _entry_icon_texture(button: Button) -> Texture2D:
	var path: String = ""
	match button:
		cards_button:
			path = "res://assets/ui_icons/codex_entry_cards.svg"
		modules_button:
			path = "res://assets/ui_icons/codex_entry_modules.svg"
		lab_button:
			path = "res://assets/ui_icons/codex_entry_lab.svg"
		monster_button:
			path = "res://assets/ui_icons/codex_entry_monsters.svg"
		stats_button:
			path = "res://assets/ui_icons/codex_entry_stats.svg"
		glossary_button:
			path = "res://assets/ui_icons/codex_entry_glossary.svg"
		history_button:
			path = "res://assets/ui_icons/codex_entry_history.svg"
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _prepare_interaction_layout() -> void:
	if scroll != null:
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll.scroll_horizontal = 0
	if header_panel != null:
		header_panel.visible = false
	for row in [top_row, bottom_row]:
		if row == null:
			continue
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.modulate = Color(1, 1, 1, 1)
		row.position = Vector2.ZERO
		row.scale = Vector2.ONE
	if detail_panel != null:
		detail_panel.modulate = Color(1, 1, 1, 1)
		detail_panel.position = Vector2.ZERO
		detail_panel.scale = Vector2.ONE
	for label in [primary_label, secondary_label]:
		if label == null:
			continue
		label.modulate = Color(1, 1, 1, 1)
		label.position = Vector2.ZERO
		label.scale = Vector2.ONE
	for button in _all_entry_buttons():
		if button == null:
			continue
		button.visible = true
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.modulate = Color(1, 1, 1, 1)
		button.position = Vector2.ZERO
		button.scale = Vector2.ONE

func _fade_reveal(control: Control, delay: float, start_scale_value: float = 0.99) -> void:
	if control == null:
		return
	UI_MOTION.reveal(control, delay, Vector2.ZERO, 0.26, Vector2.ONE * start_scale_value)

func _archive_cards() -> Array[CardData]:
	var preferred_cards: Dictionary = {}
	var ids: Array[String] = []
	for raw_id in card_db.keys():
		ids.append(String(raw_id))
	ids.sort()
	for id in ids:
		var card: CardData = card_db[id] as CardData
		if card == null:
			continue
		var archive_id_check: String = _archive_card_id(id)
		# 图鉴门控：未见过的卡牌跳过（由 _archive_locked_cards 单独返回占位）
		if MetaUnlockManager != null and not MetaUnlockManager.is_card_seen(id) and not MetaUnlockManager.is_card_seen(archive_id_check):
			continue
		var archive_id: String = _archive_card_id(id)
		if archive_id.is_empty():
			continue
		if not preferred_cards.has(archive_id) or not id.ends_with("_plus"):
			preferred_cards[archive_id] = card
	var ordered_ids: Array[String] = []
	for raw_archive_id in preferred_cards.keys():
		ordered_ids.append(String(raw_archive_id))
	ordered_ids.sort()
	var cards: Array[CardData] = []
	for archive_id in ordered_ids:
		var archive_card: CardData = preferred_cards[archive_id] as CardData
		if archive_card != null:
			cards.append(archive_card)
	return cards

# 杀戮尖塔风格：未见过的卡牌作为"锁定占位"返回（灰色问号卡片）
func _archive_locked_cards() -> Array[CardData]:
	if MetaUnlockManager == null:
		return []
	var preferred_cards: Dictionary = {}
	var ids: Array[String] = []
	for raw_id in card_db.keys():
		ids.append(String(raw_id))
	ids.sort()
	for id in ids:
		var card: CardData = card_db[id] as CardData
		if card == null:
			continue
		var archive_id_check: String = _archive_card_id(id)
		# 只收未见过的卡牌
		if MetaUnlockManager.is_card_seen(id) or MetaUnlockManager.is_card_seen(archive_id_check):
			continue
		var archive_id: String = _archive_card_id(id)
		if archive_id.is_empty():
			continue
		if not preferred_cards.has(archive_id) or not id.ends_with("_plus"):
			preferred_cards[archive_id] = card
	var ordered_ids: Array[String] = []
	for raw_archive_id in preferred_cards.keys():
		ordered_ids.append(String(raw_archive_id))
	ordered_ids.sort()
	var cards: Array[CardData] = []
	for archive_id in ordered_ids:
		var archive_card: CardData = preferred_cards[archive_id] as CardData
		if archive_card != null:
			cards.append(archive_card)
	return cards

func _archive_card_id(card_id: String) -> String:
	if card_id.ends_with("_plus") and card_id.length() > 5:
		return card_id.substr(0, card_id.length() - 5)
	return card_id

func _archive_card_count() -> int:
	return _archive_cards().size()

func _archive_locked_card_count() -> int:
	return _archive_locked_cards().size()

func _archive_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for character_id in CHARACTER_ARCHIVE_ORDER:
		if character_db.has(character_id) and _character_has_archive_presence(character_id):
			ids.append(character_id)
	for raw_id in character_db.keys():
		var character_id: String = String(raw_id)
		if not ids.has(character_id) and _character_has_archive_presence(character_id):
			ids.append(character_id)
	return ids

func _character_archive_image_path(character_id: String) -> String:
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = "res://assets/character_portraits/%s.%s" % [character_id, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

func _glossary_entry(term_id: String, accent: Color) -> Dictionary:
	return {
		"title": LocalizationManager.text("codex.term_%s_title" % term_id),
		"body": LocalizationManager.text("codex.term_%s_body" % term_id),
		"accent": accent
	}

func _operator_archive_profile_body(character_id: String) -> String:
	var lines: Array[String] = []
	var intro: String = LocalizationManager.character_intro(character_id, "")
	if not intro.is_empty():
		lines.append(intro)
	var mechanic: String = LocalizationManager.character_mechanic(character_id, "")
	if not mechanic.is_empty():
		if not lines.is_empty():
			lines.append("")
		lines.append(mechanic)
	return "\n".join(lines)

func _operator_archive_tagline(character_id: String) -> String:
	match character_id:
		"amiya":
			return LocalizationManager.text("codex.operator_tagline_amiya")
		"exusiai":
			return LocalizationManager.text("codex.operator_tagline_exusiai")
		"nearl":
			return LocalizationManager.text("codex.operator_tagline_nearl")
		"kaltsit":
			return LocalizationManager.text("codex.operator_tagline_kaltsit")
		_:
			return LocalizationManager.character_stats(character_id, "")

func _operator_archive_summary_caption(character_id: String) -> String:
	match character_id:
		"amiya":
			return LocalizationManager.text("codex.operator_summary_caption_amiya")
		"exusiai":
			return LocalizationManager.text("codex.operator_summary_caption_exusiai")
		"nearl":
			return LocalizationManager.text("codex.operator_summary_caption_nearl")
		"kaltsit":
			return LocalizationManager.text("codex.operator_summary_caption_kaltsit")
		_:
			return LocalizationManager.text("codex.operator_summary_caption_default")

func _operator_archive_stat_body(character_id: String, character_stats: Dictionary = {}) -> String:
	var lines: Array[String] = []
	var runs_started: int = int(character_stats.get("runs_started", 0))
	var runs_won: int = int(character_stats.get("runs_won", 0))
	var win_rate: int = int(round((float(runs_won) / float(runs_started)) * 100.0)) if runs_started > 0 else 0
	lines.append(LocalizationManager.text("codex.stats_runs", [runs_started]))
	lines.append(LocalizationManager.text("codex.stats_wins", [runs_won]))
	lines.append(LocalizationManager.text("codex.stats_losses", [int(character_stats.get("runs_lost", 0))]))
	lines.append(LocalizationManager.text("codex.stats_best_floor", [int(character_stats.get("best_floor", 0))]))
	lines.append(LocalizationManager.text("codex.stats_total_gold", [int(character_stats.get("total_gold_collected", 0))]))
	lines.append(LocalizationManager.text("codex.stats_winrate", [win_rate]))
	lines.append("")
	lines.append(LocalizationManager.text("codex.operator_card_count", [_character_card_count(character_id)]))
	lines.append(LocalizationManager.text("codex.operator_module_count", [_character_module_count(character_id)]))
	lines.append(LocalizationManager.text("codex.operator_charm_count", [_character_charm_count(character_id)]))
	return "\n".join(lines)

func _character_card_count(character_id: String) -> int:
	var count: int = 0
	for card in _archive_cards():
		if card != null and Util.card_owner(card.id) == character_id:
			count += 1
	return count

func _character_module_count(character_id: String) -> int:
	var count: int = 0
	for raw_id in module_db.keys():
		if Util.module_owner(String(raw_id)) == character_id:
			count += 1
	return count

func _character_charm_count(character_id: String) -> int:
	var charm_db: Dictionary = Util.load_charm_db()
	var count: int = 0
	for raw_id in charm_db.keys():
		if Util.charm_owner(String(raw_id)) == character_id:
			count += 1
	return count

func _operator_accent(character_id: String, alpha: float = 0.82) -> Color:
	match character_id:
		"amiya":
			return Color(0.72, 0.90, 1.0, alpha)
		"nearl":
			return Color(0.98, 0.90, 0.68, alpha)
		"exusiai":
			return Color(1.0, 0.74, 0.74, alpha)
		"kaltsit":
			return Color(0.78, 0.96, 0.86, alpha)
		_:
			return Color(0.84, 0.88, 0.96, alpha)

func _character_has_archive_presence(character_id: String) -> bool:
	if _character_card_count(character_id) > 0:
		return true
	if _character_module_count(character_id) > 0:
		return true
	if _character_charm_count(character_id) > 0:
		return true
	var profile: Dictionary = SaveManager.load_profile()
	var character_stats: Dictionary = _character_profile_stats(profile, character_id)
	if int(character_stats.get("runs_started", 0)) > 0:
		return true
	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	for raw_item in history:
		if typeof(raw_item) == TYPE_DICTIONARY and String((raw_item as Dictionary).get("character_id", "")) == character_id:
			return true
	var save_data: Dictionary = RunManager.saved_run_summary()
	return String(save_data.get("character_id", "")) == character_id

func _character_profile_stats(profile: Dictionary, character_id: String) -> Dictionary:
	var all_stats: Dictionary = profile.get("character_stats", {}) if typeof(profile.get("character_stats", {})) == TYPE_DICTIONARY else {}
	var stats: Dictionary = all_stats.get(character_id, {}) if typeof(all_stats.get(character_id, {})) == TYPE_DICTIONARY else {}
	var normalized: Dictionary = {
		"runs_started": int(stats.get("runs_started", 0)),
		"runs_won": int(stats.get("runs_won", 0)),
		"runs_lost": int(stats.get("runs_lost", 0)),
		"best_floor": int(stats.get("best_floor", 0)),
		"total_gold_collected": int(stats.get("total_gold_collected", 0))
	}
	if int(normalized.get("runs_started", 0)) > 0:
		return normalized
	var history: Array = profile.get("run_history", []) if typeof(profile.get("run_history", [])) == TYPE_ARRAY else []
	for raw_item in history:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		if String(item.get("character_id", "")) != character_id:
			continue
		normalized["runs_started"] = int(normalized.get("runs_started", 0)) + 1
		if String(item.get("result", "defeat")) == "victory":
			normalized["runs_won"] = int(normalized.get("runs_won", 0)) + 1
		else:
			normalized["runs_lost"] = int(normalized.get("runs_lost", 0)) + 1
		normalized["best_floor"] = max(int(normalized.get("best_floor", 0)), int(item.get("floor", 0)))
		normalized["total_gold_collected"] = int(normalized.get("total_gold_collected", 0)) + int(item.get("gold", 0))
	return normalized

func _card_archive_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for character_id in _archive_character_ids():
		var section_cards: Array[CardData] = []
		for card in _archive_cards():
			if card != null and Util.card_owner(card.id) == character_id:
				section_cards.append(card)
		# 杀戮尖塔风格：未见过的卡牌作为锁定占位显示
		var locked_cards: Array[CardData] = []
		for card in _archive_locked_cards():
			if card != null and Util.card_owner(card.id) == character_id:
				locked_cards.append(card)
		if section_cards.is_empty() and locked_cards.is_empty():
			continue
		var subtitle_parts: Array[String] = [
			LocalizationManager.text("codex.operator_card_count", [section_cards.size()])
		]
		if not locked_cards.is_empty():
			subtitle_parts.append(LocalizationManager.text("meta.locked_count", [locked_cards.size()]))
		subtitle_parts.append(_operator_archive_tagline(character_id))
		sections.append({
			"title": LocalizationManager.character_header(character_id, LocalizationManager.character_name(character_id, character_id.capitalize())),
			"subtitle": "   |   ".join(subtitle_parts),
			"cards": section_cards,
			"locked_cards": locked_cards,
			"accent": _operator_accent(character_id)
		})
	return sections

func _module_archive_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for character_id in _archive_character_ids():
		var entries: Array[Dictionary] = []
		var ids: Array[String] = []
		for raw_id in module_db.keys():
			var module_id: String = String(raw_id)
			if Util.module_owner(module_id) == character_id:
				ids.append(module_id)
		ids.sort()
		for id in ids:
			var module_data: ModuleData = module_db[id] as ModuleData
			if module_data == null:
				continue
			entries.append({
				"title": LocalizationManager.module_name(module_data),
				"subtitle": LocalizationManager.text("codex.module_rarity", [LocalizationManager.rarity_name(module_data.rarity)]),
				"body": LocalizationManager.module_description(module_data),
				"accent": _module_accent(module_data.rarity),
				"image_path": Util.module_icon_path(id),
				"display_mode": "grid"
			})
		if entries.is_empty():
			continue
		sections.append({
			"title": LocalizationManager.character_header(character_id, LocalizationManager.character_name(character_id, character_id.capitalize())),
			"subtitle": LocalizationManager.text("codex.operator_module_count", [entries.size()]),
			"entries": entries,
			"accent": _operator_accent(character_id),
			"display_mode": "grid"
		})
	return sections

func _apply_directory_button_style(button: Button, is_selected: bool, font_size: int, minimum_size: Vector2) -> void:
	button.flat = false
	button.custom_minimum_size = minimum_size
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 0.98) if is_selected else Color(0.94, 0.96, 0.98, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.90, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.90, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.88))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_constant_override("h_separation", 14)
	button.add_theme_constant_override("content_margin_left", 12)
	button.add_theme_constant_override("content_margin_top", 12)
	button.add_theme_constant_override("content_margin_right", 12)
	button.add_theme_constant_override("content_margin_bottom", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.00, 0.00, 0.00, 0.00)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_right = 18
	normal.corner_radius_bottom_left = 18
	normal.content_margin_left = 12
	normal.content_margin_top = 12
	normal.content_margin_right = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.12, 0.18, 0.18)
	hover.border_color = Color(0.88, 0.96, 1.0, 0.38)
	hover.border_width_left = 1
	hover.border_width_top = 1
	hover.border_width_right = 1
	hover.border_width_bottom = 1
	hover.shadow_color = Color(0.62, 0.82, 1.0, 0.14)
	hover.shadow_size = 12
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.16, 0.22, 0.24)
	var selected := hover.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.12, 0.16, 0.22, 0.24)
	selected.border_color = Color(0.96, 0.88, 0.68, 0.58)
	selected.shadow_color = Color(0.98, 0.88, 0.66, 0.14)
	button.add_theme_stylebox_override("normal", selected if is_selected else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)
