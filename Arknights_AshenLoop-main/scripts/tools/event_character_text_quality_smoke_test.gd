extends SceneTree

const CHARACTER_BANNED_TERMS := {
	"amiya": ["能天使", "弹药节奏"],
	"exusiai": ["阿米娅", "阿米婭", "意志", "术式", "共振", "Amiya", "Will", "Arts", "Resonance"],
	"kaltsit": ["阿米娅", "阿米婭", "能天使", "弹药节奏", "Amiya", "Exusiai"],
	"nearl": ["阿米娅", "阿米婭", "能天使", "弹药节奏", "Amiya", "Exusiai"],
}

func _initialize() -> void:
	print("EVENT_CHARACTER_TEXT_QUALITY_SMOKE_TEST_START")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	var run_manager: Node = root.get_node_or_null("RunManager")
	if localization == null or run_manager == null:
		_fail("缺少自动加载节点。")
		return
	localization.current_language = localization.LANG_ZH
	var event_db: Dictionary = Util.load_event_db()
	var checked_count: int = 0
	for character_id in CHARACTER_BANNED_TERMS.keys():
		run_manager.character = Util.load_character(character_id, ResourceLoader.CACHE_MODE_IGNORE)
		if run_manager.character == null:
			_fail("无法加载角色资源：%s" % character_id)
			return
		for event_id in event_db.keys():
			var event_data: EventData = event_db[event_id] as EventData
			if event_data == null:
				continue
			if not _event_available_to_character(event_data, character_id):
				continue
			_check_text(character_id, "%s.title" % event_data.id, localization.event_title(event_data.id, event_data.title))
			_check_text(character_id, "%s.body" % event_data.id, localization.event_body(event_data.id, event_data.body))
			checked_count += 2
			for option in event_data.options:
				_check_text(character_id, "%s.label" % event_data.id, localization.event_option_label(event_data.id, String(option.get("label", ""))))
				_check_text(character_id, "%s.result" % event_data.id, localization.event_result_for_event(event_data.id, String(option.get("result", ""))))
				checked_count += 2
	print("EVENT_CHARACTER_TEXT_QUALITY_SMOKE_TEST_OK checked=%d" % checked_count)
	quit(0)

func _event_available_to_character(event_data: EventData, character_id: String) -> bool:
	for tag in event_data.tags:
		var tag_text: String = String(tag)
		if tag_text.begins_with("character:"):
			return tag_text == "character:%s" % character_id
	return true

func _check_text(character_id: String, context: String, value: String) -> void:
	for term in Array(CHARACTER_BANNED_TERMS.get(character_id, [])):
		if value.contains(String(term)):
			_fail("%s 文本含不应出现的词：%s context=%s text=%s" % [character_id, term, context, value])

func _fail(message: String) -> void:
	push_error(message)
	print("EVENT_CHARACTER_TEXT_QUALITY_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
