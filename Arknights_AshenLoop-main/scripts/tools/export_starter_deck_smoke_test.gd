extends SceneTree

const DECK_CONTROLLER_SCRIPT := preload("res://scripts/battle/DeckController.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	var character_ids: Array[String] = ["amiya", "exusiai", "kaltsit", "nearl"]
	for character_id in character_ids:
		_check_character_starter_deck(character_id)
	if failures.is_empty():
		print("EXPORT_STARTER_DECK_SMOKE_TEST_OK")
		return 0
	push_error("EXPORT_STARTER_DECK_SMOKE_TEST_FAILED")
	for failure in failures:
		push_error(failure)
	return 1

func _check_character_starter_deck(character_id: String) -> void:
	var character: CharacterData = Util.load_character(character_id, ResourceLoader.CACHE_MODE_IGNORE)
	if character == null:
		_fail("缺少角色资源：%s。" % character_id)
		return
	if character.starter_deck.is_empty():
		_fail("%s 的初始牌组为空。" % character_id)
		return
	var deck_ids: Array[String] = []
	for card_id in character.starter_deck:
		deck_ids.append(String(card_id))
	var fallback_ids: Array[String] = Util.default_starter_deck_for_character(character_id)
	if fallback_ids.size() != deck_ids.size():
		_fail("%s 的导出兜底初始牌组数量异常：%d，期望 %d。" % [character_id, fallback_ids.size(), deck_ids.size()])
		return
	var controller: DeckController = DECK_CONTROLLER_SCRIPT.new()
	controller.setup(deck_ids, {}, 20260512)
	if controller.draw_pile.size() != deck_ids.size():
		_fail("%s 在空卡牌数据库兜底下应加载 %d 张初始牌，实际 %d。" % [character_id, deck_ids.size(), controller.draw_pile.size()])
		return
	var drawn: Array[CardData] = controller.draw_cards(min(5, deck_ids.size()))
	if drawn.is_empty():
		_fail("%s 在导出兜底路径下无法抽到初始牌。" % character_id)
	controller.setup(fallback_ids, {}, 20260512)
	if controller.draw_pile.size() != fallback_ids.size():
		_fail("%s 的硬编码导出兜底无法加载完整初始牌组。" % character_id)

func _fail(message: String) -> void:
	failures.append(message)
