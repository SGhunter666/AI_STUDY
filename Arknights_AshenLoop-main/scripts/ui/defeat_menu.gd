extends Control

const UIThemeKit = preload("res://scripts/ui/ui_theme_kit.gd")

@onready var title_label: Label = $Layout/Margin/Content/HeaderBox/Title
@onready var body_label: Label = $Layout/Margin/Content/HeaderBox/Body
@onready var overview_panel: PanelContainer = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/OverviewPanel
@onready var overview_header: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/OverviewPanel/OverviewMargin/OverviewBox/OverviewHeader
@onready var overview_label: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/OverviewPanel/OverviewMargin/OverviewBox/OverviewLabel
@onready var death_cause_panel: PanelContainer = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeathCausePanel
@onready var death_cause_header: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeathCausePanel/DeathCauseMargin/DeathCauseBox/DeathCauseHeader
@onready var death_cause_label: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeathCausePanel/DeathCauseMargin/DeathCauseBox/DeathCauseLabel
@onready var deck_panel: PanelContainer = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeckPanel
@onready var deck_header: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeckPanel/DeckMargin/DeckBox/DeckHeader
@onready var deck_label: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/DeckPanel/DeckMargin/DeckBox/DeckLabel
@onready var charms_panel: PanelContainer = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/CharmsPanel
@onready var charms_header: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/CharmsPanel/CharmsMargin/CharmsBox/CharmsHeader
@onready var charms_label: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/CharmsPanel/CharmsMargin/CharmsBox/CharmsLabel
@onready var modules_panel: PanelContainer = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/ModulesPanel
@onready var modules_header: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/ModulesPanel/ModulesMargin/ModulesBox/ModulesHeader
@onready var modules_label: Label = $Layout/Margin/Content/ReviewScroll/ReviewMargin/ReviewBox/ModulesPanel/ModulesMargin/ModulesBox/ModulesLabel
@onready var back_button: Button = $Layout/Margin/Content/Back

func _ready() -> void:
	SfxManager.play_defeat()
	_apply_styles()
	_apply_text()
	LocalizationManager.language_changed.connect(_apply_text)
	back_button.pressed.connect(func() -> void:
		SceneRouter.go_main_menu()
	)

func _exit_tree() -> void:
	# 断开 autoload 持久信号，避免场景销毁期间回调访问已释放子节点
	if LocalizationManager != null and LocalizationManager.language_changed.is_connected(_apply_text):
		LocalizationManager.language_changed.disconnect(_apply_text)

func _apply_styles() -> void:
	# 标题：大号红铜色 + 阴影
	UIThemeKit.apply_heading(title_label, 64, Color(1.0, 0.42, 0.36, 1.0), Color(0.04, 0.02, 0.04, 0.92))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.62))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_constant_override("shadow_outline_size", 2)
	# 副标题：玻璃质感
	UIThemeKit.apply_glass_body(body_label, 22)
	# 概览卡片：纸质 + 棕褐标题
	UIThemeKit.apply_paper_panel(overview_panel)
	UIThemeKit.apply_heading(overview_header, 26, Color(0.42, 0.32, 0.20, 1.0))
	UIThemeKit.apply_body(overview_label, 20, Color(0.20, 0.16, 0.12, 0.96))
	# 死因卡片：暗红纸质 + 深红标题
	_apply_tinted_paper_panel(death_cause_panel, Color(0.74, 0.36, 0.30, 0.92), Color(0.92, 0.36, 0.30, 0.78))
	UIThemeKit.apply_heading(death_cause_header, 26, Color(0.50, 0.12, 0.10, 1.0))
	UIThemeKit.apply_body(death_cause_label, 20, Color(0.30, 0.12, 0.10, 0.96))
	# 卡组卡片：纸质 + 蓝色标题
	UIThemeKit.apply_paper_panel(deck_panel)
	UIThemeKit.apply_heading(deck_header, 26, Color(0.20, 0.32, 0.52, 1.0))
	UIThemeKit.apply_body(deck_label, 19, Color(0.18, 0.16, 0.14, 0.94))
	# 护符卡片：纸质 + 琥珀金标题
	UIThemeKit.apply_paper_panel(charms_panel)
	UIThemeKit.apply_heading(charms_header, 26, Color(0.58, 0.42, 0.10, 1.0))
	UIThemeKit.apply_body(charms_label, 19, Color(0.18, 0.16, 0.14, 0.94))
	# 模块卡片：纸质 + 翠绿标题
	UIThemeKit.apply_paper_panel(modules_panel)
	UIThemeKit.apply_heading(modules_header, 26, Color(0.18, 0.42, 0.26, 1.0))
	UIThemeKit.apply_body(modules_label, 19, Color(0.18, 0.16, 0.14, 0.94))
	# 返回按钮：danger 石材
	UIThemeKit.apply_stone_button(back_button, "danger", 28)

func _apply_tinted_paper_panel(panel: PanelContainer, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)

func _apply_text(_language_code: String = "") -> void:
	title_label.text = LocalizationManager.text("defeat.title")
	body_label.text = LocalizationManager.text("defeat.body")
	back_button.text = LocalizationManager.text("defeat.retry")
	overview_header.text = LocalizationManager.text("defeat.section_overview")
	death_cause_header.text = LocalizationManager.text("defeat.section_death")
	deck_header.text = LocalizationManager.text("defeat.section_deck")
	charms_header.text = LocalizationManager.text("defeat.section_charms")
	modules_header.text = LocalizationManager.text("defeat.section_modules")
	var summary: Dictionary = RunManager.last_run_summary
	# 概览：角色 / 楼层 / 难度 / HP
	var char_name: String = String(summary.get("character_name", ""))
	var floor_value: int = int(summary.get("floor", 0))
	var ascension: int = int(summary.get("ascension_level", 0))
	var final_hp: int = int(summary.get("final_hp", 0))
	var max_hp: int = int(summary.get("max_hp", 0))
	var gold_value: int = int(summary.get("gold", 0))
	var deck_size: int = int(summary.get("deck_size", 0))
	var ascension_text: String = ""
	if ascension > 0:
		ascension_text = LocalizationManager.text("defeat.ascension", [ascension])
	overview_label.text = LocalizationManager.text("defeat.overview", [char_name, floor_value, ascension_text, final_hp, max_hp, gold_value, deck_size])
	# 死因
	var death_cause: Dictionary = summary.get("death_cause", {})
	var abandoned: bool = bool(summary.get("abandoned", false))
	if abandoned:
		death_cause_label.text = LocalizationManager.text("defeat.abandoned")
	elif death_cause.is_empty():
		death_cause_label.text = LocalizationManager.text("defeat.empty")
	else:
		var enemy_name: String = String(death_cause.get("enemy_name", ""))
		var dmg: int = int(death_cause.get("damage", 0))
		var battle_turn: int = int(summary.get("battle_turn", 0))
		death_cause_label.text = LocalizationManager.text("defeat.death_cause", [enemy_name, dmg, battle_turn])
	# 卡组列表
	var deck_list: Array = summary.get("deck_list", [])
	deck_label.text = _summarize_card_list(deck_list)
	# 护符列表
	var charms_list: Array = summary.get("charms_list", [])
	var owned_charms: Array = summary.get("owned_charms_list", [])
	charms_label.text = _summarize_charms(charms_list, owned_charms)
	# 模块列表
	var modules_list: Array = summary.get("modules_list", [])
	modules_label.text = _summarize_modules(modules_list)

func _summarize_card_list(deck_list: Array) -> String:
	if deck_list.is_empty():
		return LocalizationManager.text("defeat.empty")
	var card_db: Dictionary = Util.load_card_db()
	var counts: Dictionary = {}
	for card_id_variant in deck_list:
		var card_id: String = String(card_id_variant)
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var parts: Array[String] = []
	for card_id in counts.keys():
		var card: CardData = card_db.get(card_id, null) as CardData
		var display_name: String = LocalizationManager.card_name(card) if card != null else card_id
		var count: int = int(counts[card_id])
		if count > 1:
			parts.append("%s ×%d" % [display_name, count])
		else:
			parts.append(display_name)
	return "• " + "\n• ".join(parts)

func _summarize_charms(equipped: Array, owned: Array) -> String:
	if owned.is_empty():
		return LocalizationManager.text("defeat.empty")
	var charm_db: Dictionary = Util.load_charm_db()
	var parts: Array[String] = []
	for charm_id_variant in owned:
		var charm_id: String = String(charm_id_variant)
		var charm_data: CharmData = charm_db.get(charm_id, null) as CharmData
		var display_name: String = LocalizationManager.charm_name(charm_data) if charm_data != null else charm_id
		var is_equipped: bool = equipped.has(charm_id)
		var prefix: String = "★ " if is_equipped else "  "
		parts.append(prefix + display_name)
	return "• " + "\n• ".join(parts)

func _summarize_modules(modules_list: Array) -> String:
	if modules_list.is_empty():
		return LocalizationManager.text("defeat.empty")
	var module_db: Dictionary = Util.load_module_db()
	var parts: Array[String] = []
	for module_id_variant in modules_list:
		var module_id: String = String(module_id_variant)
		var module_data = module_db.get(module_id, null)
		var display_name: String = module_id
		if module_data is ModuleData:
			display_name = LocalizationManager.module_name(module_data)
		parts.append(display_name)
	return "• " + "\n• ".join(parts)
