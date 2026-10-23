class_name TuneSummaryPresenter
extends RefCounted

const TUNE_LIBRARY = preload("res://scripts/core/tune_library.gd")
const COMPENDIUM_OVERLAY = preload("res://scripts/ui/compendium_overlay.gd")


static func current_tune_ids() -> Array[String]:
	if not RunManager.tunes.is_empty():
		return RunManager.tunes.duplicate()
	if RunManager.has_saved_run():
		return _string_array_from_variant(RunManager.saved_run_summary().get("tunes", []))
	return []


static func current_tune_count() -> int:
	return current_tune_ids().size()


static func hud_text() -> String:
	return LocalizationManager.text("tune.hud_chip", [current_tune_count()])


static func hud_tooltip() -> String:
	if current_tune_count() <= 0:
		return LocalizationManager.text("tune.overlay_empty_body")
	return "%s\n%s" % [
		LocalizationManager.text("tune.overlay_title"),
		current_summary_text()
	]


static func current_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for tune_id in current_tune_ids():
		lines.append("%s：%s" % [
			LocalizationManager.tune_title(tune_id, TUNE_LIBRARY.title(tune_id)),
			LocalizationManager.tune_short(tune_id, TUNE_LIBRARY.short_text(tune_id))
		])
	return lines


static func current_summary_text() -> String:
	var lines: Array[String] = current_summary_lines()
	if lines.is_empty():
		return LocalizationManager.text("tune.overlay_empty_body")
	return "\n".join(lines)


static func current_summary_entry() -> Dictionary:
	return {
		"title": LocalizationManager.text("tune.overlay_title"),
		"subtitle": LocalizationManager.text("tune.overlay_intro_body", [current_tune_count()]),
		"body": current_summary_text(),
		"accent": Color(0.74, 0.92, 1.0, 0.80)
	}


static func current_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var tune_ids: Array[String] = current_tune_ids()
	if tune_ids.is_empty():
		entries.append({
			"title": LocalizationManager.text("tune.overlay_empty_title"),
			"body": LocalizationManager.text("tune.overlay_empty_body"),
			"accent": Color(0.72, 0.88, 1.0, 0.72)
		})
		return entries

	entries.append({
		"title": LocalizationManager.text("tune.overlay_intro_title"),
		"subtitle": LocalizationManager.text("tune.overlay_intro_body", [tune_ids.size()]),
		"body": current_summary_text(),
		"accent": Color(0.74, 0.92, 1.0, 0.80)
	})
	for tune_id in tune_ids:
		entries.append({
			"title": LocalizationManager.tune_title(tune_id, TUNE_LIBRARY.title(tune_id)),
			"subtitle": LocalizationManager.tune_short(tune_id, TUNE_LIBRARY.short_text(tune_id)),
			"body": LocalizationManager.tune_description(tune_id, TUNE_LIBRARY.description(tune_id)),
			"accent": TUNE_LIBRARY.accent(tune_id)
		})
	return entries


static func open_current_overlay(parent: Node) -> void:
	if parent == null:
		return
	var existing: Node = parent.get_node_or_null("TuneSummaryOverlay")
	if existing != null:
		existing.queue_free()
		return
	var overlay: CompendiumOverlay = COMPENDIUM_OVERLAY.new()
	overlay.name = "TuneSummaryOverlay"
	overlay.setup(LocalizationManager.text("tune.overlay_title"), current_entries())
	parent.add_child(overlay)


static func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(String(item))
	return result
