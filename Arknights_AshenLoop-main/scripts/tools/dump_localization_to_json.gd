extends SceneTree

# 一次性工具：把 LocalizationManager 内联文本字典导出为 data/localization/strings.json
# 用法：godot --headless --path . -s scripts/tools/dump_localization_to_json.gd

const DICT_NAMES: Array[String] = [
	"ui_text",
	"node_type_names",
	"floor_names",
	"node_descriptions",
	"card_text",
	"module_text",
	"charm_text",
	"enemy_text",
	"intent_labels",
	"event_text",
	"event_result_text",
	"exusiai_event_text",
	"exusiai_event_option_text",
	"exusiai_event_result_text",
	"character_profiles",
]

var LocalizationManager: Node

func _initialize() -> void:
	LocalizationManager = root.get_node_or_null("LocalizationManager")
	call_deferred("_dump")

func _dump() -> void:
	if LocalizationManager == null:
		print("DUMP_FAIL LocalizationManager autoload not found")
		quit(1)
		return
	var data: Dictionary = {}
	var total_entries: int = 0
	for dict_name in DICT_NAMES:
		var value: Variant = LocalizationManager.get(dict_name)
		if typeof(value) != TYPE_DICTIONARY:
			print("DUMP_FAIL missing dict: ", dict_name)
			quit(1)
			return
		data[dict_name] = value
		total_entries += (value as Dictionary).size()
	DirAccess.make_dir_recursive_absolute("res://data/localization")
	var file: FileAccess = FileAccess.open("res://data/localization/strings.json", FileAccess.WRITE)
	if file == null:
		print("DUMP_FAIL cannot write file")
		quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("DUMP_OK dicts=", data.size(), " entries=", total_entries)
	quit()
