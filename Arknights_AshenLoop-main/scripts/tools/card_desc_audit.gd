extends SceneTree

# 一次性审计：比对卡牌描述中的数值与效果数据数值
# 用法：godot --headless --path . -s scripts/tools/card_desc_audit.gd

var Util = load("res://scripts/core/util.gd")

# 数值存在于 BattleManager/EffectResolver 代码钩子的卡
const CODE_HOOK_CARD_IDS := {
	"ex_s06_overheated_bolt": true,
	"ex_s06_overheated_bolt_plus": true,
}

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var db: Dictionary = Util.load_card_db(ResourceLoader.CACHE_MODE_IGNORE)
	var prefixes: Array[String] = ["nearl_", "ex_", "kaltsit_"]
	var issues: int = 0
	var card_ids: Array = db.keys()
	card_ids.sort()
	for card_id in card_ids:
		var card: CardData = db[card_id] as CardData
		if card == null:
			continue
		var owned: bool = false
		for prefix in prefixes:
			if card.id.begins_with(prefix):
				owned = true
				break
		if not owned:
			continue
		# Curse 类诅咒卡的数值语义隐式（如"少抽1张"=浪费抽牌位），跳过数值比对
		if card.rarity == "Curse":
			continue
		# 数值在代码钩子中实现的卡（描述数值 vs 效果数据无法比对）
		if card.id in CODE_HOOK_CARD_IDS:
			continue
		# "Mon3tr" 名称含 3，先剔除避免误报
		var clean_desc: String = card.description.replace("Mon3tr", "MONTR")
		var desc_numbers: Array[int] = _extract_numbers(clean_desc)
		var effect_numbers: Array[int] = []
		for effect in card.effects:
			if effect == null:
				continue
			_effect_numbers(effect, effect_numbers)
		for effect in card.conditional_effects:
			if effect == null:
				continue
			_effect_numbers(effect, effect_numbers)
		# 描述数值应都能在效果数值中找到对应（多重集包含检查）
		var remaining: Array[int] = effect_numbers.duplicate()
		var missing: Array[int] = []
		for n in desc_numbers:
			if remaining.has(n):
				remaining.erase(n)
			else:
				missing.append(n)
		if not missing.is_empty():
			issues += 1
			print("MISMATCH: %s | desc='%s' | desc_nums=%s | effect_nums=%s | missing=%s" % [
				card.id, card.description, str(desc_numbers), str(effect_numbers), str(missing)])
	print("AUDIT_DONE total_issues=", issues)
	quit(0)

func _effect_numbers(effect: EffectData, out: Array[int]) -> void:
	if effect.amount != 0:
		out.append(abs(effect.amount))
	if effect.amount_2 != 0:
		out.append(abs(effect.amount_2))
	# 条件阈值（如 radiance_gte:3、player_will_gte:3）也是效果承诺的数值
	var condition: String = effect.condition
	if not condition.is_empty() and condition.contains(":"):
		var threshold: String = condition.get_slice(":", 1)
		if threshold.is_valid_int():
			out.append(int(threshold))

func _extract_numbers(desc: String) -> Array[int]:
	var result: Array[int] = []
	var regex = RegEx.new()
	regex.compile("\\d+")
	for match in regex.search_all(desc):
		result.append(int(match.get_string()))
	return result
