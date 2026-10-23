extends Node

const SAVE_PATH := "user://save_profile.json"
const TEMP_SAVE_PATH := "user://save_profile.json.tmp"
const BACKUP_SAVE_PATH := "user://save_profile.json.bak"
# 写入/读取失败（如文件被杀软或同步软件短暂占用）时短间隔重试，避免元进度丢失
const SAVE_MAX_ATTEMPTS := 3
const SAVE_RETRY_DELAY_MSEC := 40

func save_profile(data: Dictionary) -> void:
	for attempt: int in SAVE_MAX_ATTEMPTS:
		if _save_profile_attempt(data):
			return
		if attempt < SAVE_MAX_ATTEMPTS - 1:
			OS.delay_msec(SAVE_RETRY_DELAY_MSEC)

func _save_profile_attempt(data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			dir.remove(BACKUP_SAVE_PATH.get_file())
		var backup_error: Error = dir.rename(SAVE_PATH.get_file(), BACKUP_SAVE_PATH.get_file())
		if backup_error != OK:
			dir.remove(TEMP_SAVE_PATH.get_file())
			return false
	var save_error: Error = dir.rename(TEMP_SAVE_PATH.get_file(), SAVE_PATH.get_file())
	if save_error == OK:
		return true
	if FileAccess.file_exists(BACKUP_SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH):
		dir.rename(BACKUP_SAVE_PATH.get_file(), SAVE_PATH.get_file())
	return false

func load_profile() -> Dictionary:
	var profile_result: Dictionary = _try_load_profile_from_path(SAVE_PATH)
	if bool(profile_result.get("loaded", false)):
		return profile_result.get("profile", {})
	# 主存档不存在或解析失败，尝试加载备份（检查 BACKUP 而非 SAVE_PATH）
	if FileAccess.file_exists(BACKUP_SAVE_PATH):
		var backup_result: Dictionary = _try_load_profile_from_path(BACKUP_SAVE_PATH)
		if bool(backup_result.get("loaded", false)):
			return backup_result.get("profile", {})
	return {}

func _try_load_profile_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"loaded": false, "profile": {}}
	var txt: String = ""
	var opened: bool = false
	# 文件存在但被占用时短间隔重试读取，避免误判为损坏而用默认值覆盖
	for attempt: int in SAVE_MAX_ATTEMPTS:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			txt = file.get_as_text()
			file.close()
			opened = true
			break
		if attempt < SAVE_MAX_ATTEMPTS - 1:
			OS.delay_msec(SAVE_RETRY_DELAY_MSEC)
	if not opened:
		return {"loaded": false, "profile": {}}
	if txt.strip_edges().is_empty():
		# 空文件按损坏处理：回退到备份，避免后续 update_profile 用补丁键覆盖掉完整 profile
		return {"loaded": false, "profile": {}}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(txt)
	if parse_error != OK:
		return {"loaded": false, "profile": {}}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"loaded": false, "profile": {}}
	return {"loaded": true, "profile": parsed}

func update_profile(patch: Dictionary) -> void:
	var profile: Dictionary = load_profile()
	for key in patch.keys():
		profile[key] = patch[key]
	save_profile(profile)

func remove_profile_key(key: String) -> void:
	var profile: Dictionary = load_profile()
	if profile.has(key):
		profile.erase(key)
	save_profile(profile)
