extends SceneTree

func _initialize() -> void:
	print("EVENT_TEXT_CHARACTER_FILTER_SMOKE_TEST_START")
	var localization: Node = root.get_node_or_null("LocalizationManager")
	var run_manager: Node = root.get_node_or_null("RunManager")
	if localization == null or run_manager == null:
		_fail("缺少自动加载节点。")
		return
	localization.current_language = localization.LANG_ZH
	run_manager.character = Util.load_character("exusiai", ResourceLoader.CACHE_MODE_IGNORE)
	if run_manager.character == null:
		_fail("无法加载能天使角色资源。")
		return
	var checked_count: int = 0
	for event_record in _read_event_text_records():
		if _record_for_other_character(event_record, "exusiai"):
			continue
		var event_id: String = String(event_record.get("id", ""))
		_check_text("title:%s" % event_id, localization.event_title(event_id, String(event_record.get("title", ""))))
		_check_text("body:%s" % event_id, localization.event_body(event_id, String(event_record.get("body", ""))))
		checked_count += 2
		for label in Array(event_record.get("labels", [])):
			_check_text("label:%s" % event_id, localization.event_option_label(event_id, String(label)))
			checked_count += 1
		for result_text in Array(event_record.get("results", [])):
			_check_text("result:%s" % event_id, localization.event_result_for_event(event_id, String(result_text)))
			checked_count += 1
	print("EVENT_TEXT_CHARACTER_FILTER_SMOKE_TEST_OK checked=%d" % checked_count)
	quit(0)

func _read_event_text_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open("res://data/events")
	if dir == null:
		_fail("无法打开事件目录。")
		return records
	var id_regex := RegEx.new()
	id_regex.compile("^id = \"([^\"]+)\"")
	var title_regex := RegEx.new()
	title_regex.compile("^title = \"((?:[^\"\\\\]|\\\\.)*)\"")
	var body_regex := RegEx.new()
	body_regex.compile("^body = \"((?:[^\"\\\\]|\\\\.)*)\"")
	var label_regex := RegEx.new()
	label_regex.compile("\"label\": \"((?:[^\"\\\\]|\\\\.)*)\"")
	var result_regex := RegEx.new()
	result_regex.compile("\"result\": \"((?:[^\"\\\\]|\\\\.)*)\"")
	var character_tag_regex := RegEx.new()
	character_tag_regex.compile("\"(character:[^\"]+)\"")
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file := FileAccess.open("res://data/events/%s" % file_name, FileAccess.READ)
			if file != null:
				var raw_text: String = file.get_as_text()
				var record := {
					"id": _first_match(id_regex, raw_text),
					"title": _first_match(title_regex, raw_text),
					"body": _first_match(body_regex, raw_text),
					"labels": _all_matches(label_regex, raw_text),
					"results": _all_matches(result_regex, raw_text),
					"tags": _all_matches(character_tag_regex, raw_text)
				}
				records.append(record)
		file_name = dir.get_next()
	dir.list_dir_end()
	return records

func _first_match(regex: RegEx, text: String) -> String:
	var match_result: RegExMatch = regex.search(text)
	if match_result == null:
		return ""
	return match_result.get_string(1)

func _all_matches(regex: RegEx, text: String) -> Array[String]:
	var values: Array[String] = []
	for match_result in regex.search_all(text):
		values.append(match_result.get_string(1))
	return values

func _record_for_other_character(event_record: Dictionary, character_id: String) -> bool:
	for tag_variant in Array(event_record.get("tags", [])):
		var tag_text: String = String(tag_variant)
		if tag_text.begins_with("character:"):
			return tag_text != "character:%s" % character_id
	return false

func _check_text(context: String, value: String) -> void:
	var forbidden_terms: Array[String] = [
		"Amiya",
		"阿米娅",
		"阿米婭",
		"意志",
		"术式",
		"共振",
		"Will",
		"Arts",
		"Resonance",
	]
	for term in forbidden_terms:
		if value.contains(term):
			_fail("能天使事件文本仍含阿米娅体系词：%s term=%s -> %s" % [context, term, value])

func _fail(message: String) -> void:
	push_error(message)
	print("EVENT_TEXT_CHARACTER_FILTER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
