extends CanvasLayer

const FADE_IN_TIME: float = 0.22
const FADE_OUT_TIME: float = 0.30
# 页面过渡：淡出时新页面从 0.985× 微缩放 + 上移 14px 滑入，营造层次感
const PAGE_INTRO_SCALE: float = 0.985
const PAGE_INTRO_OFFSET: float = 14.0
const PAGE_INTRO_TIME: float = 0.36

var overlay: ColorRect
var is_transitioning: bool = false
var queued_scene: String = ""

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_overlay()

func _ensure_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	overlay = ColorRect.new()
	overlay.name = "SceneFade"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.02, 0.03, 0.05, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

func transition_to(path: String) -> void:
	if path.is_empty():
		return
	if is_transitioning:
		queued_scene = path
		return
	_run_transition(path)

func _run_transition(path: String) -> void:
	is_transitioning = true
	queued_scene = ""
	_ensure_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# 动画速度倍率：减少动效模式时动画最快
	var speed_mult: float = SettingsManager.get_animation_speed() if SettingsManager != null else 1.0
	var fade_in_time: float = FADE_IN_TIME / speed_mult
	var fade_out_time: float = FADE_OUT_TIME / speed_mult
	# 减少动效模式：跳过页面入场动画
	var skip_intro: bool = SettingsManager.is_reduce_motion() if SettingsManager != null else false
	var fade_in: Tween = _make_transition_tween()
	if fade_in == null:
		# tween 创建失败，直接切换场景
		get_tree().change_scene_to_file(path)
		await get_tree().process_frame
		is_transitioning = false
		return
	var fade_in_tweener = fade_in.tween_property(overlay, "color:a", 1.0, fade_in_time)
	if fade_in_tweener != null:
		fade_in_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	# 新场景内容滑入动画（缩放 + 上移 + 淡入）
	if not skip_intro:
		_play_page_intro()
	var fade_out: Tween = _make_transition_tween()
	if fade_out == null:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		return
	var fade_out_tweener = fade_out.tween_property(overlay, "color:a", 0.0, fade_out_time)
	if fade_out_tweener != null:
		fade_out_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	if not queued_scene.is_empty():
		var next_scene: String = queued_scene
		queued_scene = ""
		_run_transition(next_scene)

# 新场景根 Control 的入场动画：从微缩放+下偏移淡入到正常
func _play_page_intro() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not (scene_root is Control):
		return
	var root_control: Control = scene_root as Control
	# 动画速度倍率：与 fade in/out 保持一致
	var speed_mult: float = SettingsManager.get_animation_speed() if SettingsManager != null else 1.0
	var intro_time: float = PAGE_INTRO_TIME / speed_mult
	var original_position: Vector2 = root_control.position
	root_control.modulate.a = 0.0
	root_control.scale = Vector2(PAGE_INTRO_SCALE, PAGE_INTRO_SCALE)
	root_control.pivot_offset = root_control.size * 0.5
	root_control.position = original_position + Vector2(0, PAGE_INTRO_OFFSET)
	var intro_tween: Tween = root_control.create_tween()
	if intro_tween == null:
		# tween 创建失败，直接恢复可见性
		root_control.modulate.a = 1.0
		root_control.scale = Vector2.ONE
		root_control.position = original_position
		return
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.set_parallel(true)
	var t1 = intro_tween.tween_property(root_control, "modulate:a", 1.0, intro_time)
	if t1 != null:
		t1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var t2 = intro_tween.tween_property(root_control, "scale", Vector2.ONE, intro_time)
	if t2 != null:
		t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var t3 = intro_tween.tween_property(root_control, "position", original_position, intro_time)
	if t3 != null:
		t3.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 确保 size 变化后 pivot 跟随中心（动画期间持续更新，动画结束后断开）
	var resize_handler := func() -> void:
		if root_control != null:
			root_control.pivot_offset = root_control.size * 0.5
	root_control.resized.connect(resize_handler)
	intro_tween.finished.connect(func() -> void:
		if root_control != null and root_control.resized.is_connected(resize_handler):
			root_control.resized.disconnect(resize_handler)
	, CONNECT_ONE_SHOT)

func _make_transition_tween() -> Tween:
	# TransitionManager 是 autoload，不会退出 tree，无需 tree_exiting cleanup
	var tween: Tween = create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween
