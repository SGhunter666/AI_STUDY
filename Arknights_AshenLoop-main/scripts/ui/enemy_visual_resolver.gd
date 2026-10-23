class_name EnemyVisualResolver
extends RefCounted

const NODE_BATTLE_ICON: Texture2D = preload("res://assets/ui_icons/node_battle.svg")
const NODE_ELITE_ICON: Texture2D = preload("res://assets/ui_icons/node_elite.svg")
const NODE_BOSS_ICON: Texture2D = preload("res://assets/ui_icons/node_boss.svg")

var portrait_cache: Dictionary = {}

func actor_texture(enemy_id: String) -> Texture2D:
	var direct_path: String = "res://assets/enemy_portraits/%s.png" % enemy_id
	if FileAccess.file_exists(ProjectSettings.globalize_path(direct_path)):
		return _load_portrait(direct_path)
	match enemy_id:
		"reunion_scout":
			return _load_portrait("res://assets/enemy_portraits/reunion_scout.png")
		"reunion_caster":
			return _load_portrait("res://assets/enemy_portraits/reunion_caster.png")
		"riot_shieldbearer":
			return _load_portrait("res://assets/enemy_portraits/riot_shieldbearer.png")
		"crossbow_sniper":
			return _load_portrait("res://assets/enemy_portraits/crossbow_sniper.png")
		"field_captain":
			return _load_portrait("res://assets/enemy_portraits/field_captain.png")
		"originium_channeler":
			return _load_portrait("res://assets/enemy_portraits/originium_channeler.png")
		"scout_chief":
			return _load_portrait("res://assets/enemy_portraits/scout_chief.png")
		"lockdown_core":
			return _load_portrait("res://assets/enemy_portraits/lockdown_core.png")
		"w_boss":
			return _load_portrait("res://assets/enemy_portraits/w_boss.png")
		"ash_echo":
			return _load_portrait("res://assets/enemy_portraits/ash_echo.png")
	return null

func actor_emblem(enemy_id: String) -> Texture2D:
	match enemy_id:
		"field_captain", "originium_channeler":
			return NODE_ELITE_ICON
		"scout_chief", "lockdown_core", "w_boss", "ash_echo":
			return NODE_BOSS_ICON
		_:
			return NODE_BATTLE_ICON

func actor_accent(enemy_id: String) -> Color:
	match enemy_id:
		"reunion_scout":
			return Color(0.88, 0.88, 0.92, 1.0)
		"reunion_caster":
			return Color(0.74, 0.58, 1.0, 1.0)
		"riot_shieldbearer":
			return Color(0.80, 0.86, 0.96, 1.0)
		"crossbow_sniper":
			return Color(0.92, 0.78, 0.54, 1.0)
		"field_captain":
			return Color(0.98, 0.42, 0.38, 1.0)
		"originium_channeler":
			return Color(0.82, 0.54, 1.0, 1.0)
		"scout_chief":
			return Color(0.92, 0.66, 0.46, 1.0)
		"lockdown_core":
			return Color(0.78, 0.80, 0.88, 1.0)
		"w_boss":
			return Color(1.0, 0.50, 0.66, 1.0)
		"ash_echo":
			return Color(0.82, 0.58, 1.0, 1.0)
		_:
			return Color(0.96, 0.86, 0.70, 1.0)

func actor_tint(enemy_id: String) -> Color:
	match enemy_id:
		"reunion_scout":
			return Color(0.96, 0.98, 1.0, 1.0)
		"reunion_caster":
			return Color(0.92, 0.88, 1.0, 1.0)
		"riot_shieldbearer":
			return Color(0.90, 0.94, 1.0, 1.0)
		"crossbow_sniper":
			return Color(1.0, 0.95, 0.86, 1.0)
		"field_captain":
			return Color(1.0, 0.90, 0.92, 1.0)
		"originium_channeler":
			return Color(0.90, 0.86, 1.0, 1.0)
		"scout_chief":
			return Color(1.0, 0.94, 0.88, 1.0)
		"lockdown_core":
			return Color(0.86, 0.88, 0.96, 1.0)
		"w_boss":
			return Color(1.0, 0.90, 0.94, 1.0)
		"ash_echo":
			return Color(0.95, 0.90, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _load_portrait(resource_path: String) -> Texture2D:
	if portrait_cache.has(resource_path):
		return portrait_cache[resource_path] as Texture2D
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	portrait_cache[resource_path] = texture
	return texture
