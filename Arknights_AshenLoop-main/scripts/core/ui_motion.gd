class_name UIMotion
extends RefCounted

# 安全链式调用：tween_property 可能返回 null（Tween 无效时），此时跳过 set_trans/set_ease
static func _apply_tweener(tweener: PropertyTweener, trans: int, ease: int) -> void:
	if tweener != null:
		tweener.set_trans(trans).set_ease(ease)

static func _apply_method_tweener(tweener: MethodTweener, trans: int, ease: int) -> void:
	if tweener != null:
		tweener.set_trans(trans).set_ease(ease)

static func reveal(control: Control, delay: float = 0.0, offset: Vector2 = Vector2(0, 26), duration: float = 0.32, start_scale: Vector2 = Vector2(0.98, 0.98)) -> Tween:
	if control == null:
		return null
	var tween: Tween = control.create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bind_cleanup(control, tween)
	var original_position: Vector2 = control.position
	control.position = original_position + offset
	control.modulate.a = 0.0
	control.scale = start_scale
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	_apply_tweener(tween.tween_property(control, "position", original_position, duration), Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_apply_tweener(tween.tween_property(control, "modulate:a", 1.0, duration), Tween.TRANS_SINE, Tween.EASE_OUT)
	_apply_tweener(tween.tween_property(control, "scale", Vector2.ONE, duration), Tween.TRANS_BACK, Tween.EASE_OUT)
	return tween

static func pulse(control: Control, press_scale: float = 0.94, rebound_scale: float = 1.02, duration: float = 0.08) -> Tween:
	if control == null:
		return null
	var tween: Tween = control.create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bind_cleanup(control, tween)
	_apply_tweener(tween.tween_property(control, "scale", Vector2.ONE * press_scale, duration), Tween.TRANS_QUAD, Tween.EASE_OUT)
	_apply_tweener(tween.tween_property(control, "scale", Vector2.ONE * rebound_scale, duration), Tween.TRANS_BACK, Tween.EASE_OUT)
	_apply_tweener(tween.tween_property(control, "scale", Vector2.ONE, duration * 0.9), Tween.TRANS_SINE, Tween.EASE_OUT)
	return tween


static func pulse_then(control: Control, action: Callable, press_scale: float = 0.94, rebound_scale: float = 1.02, duration: float = 0.08) -> void:
	if control == null:
		if action.is_valid():
			action.call()
		return
	var tween: Tween = pulse(control, press_scale, rebound_scale, duration)
	if tween == null:
		if action.is_valid():
			action.call()
		return
	tween.finished.connect(func() -> void:
		if action.is_valid():
			action.call()
	, CONNECT_ONE_SHOT)


static func wire_button_feedback(control: Control, hover_scale: float = 1.03, press_scale: float = 0.97, glow_color: Color = Color(0.76, 0.92, 1.0, 0.78), ring_padding: float = 4.0) -> void:
	if control == null or control.has_meta("ui_motion_feedback"):
		return
	control.set_meta("ui_motion_feedback", true)
	control.resized.connect(func() -> void:
		control.pivot_offset = control.size * 0.5
	)
	control.pivot_offset = control.size * 0.5
	var ring: Panel = control.get_node_or_null("FeedbackRing") as Panel
	if ring == null:
		ring = Panel.new()
		ring.name = "FeedbackRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.layout_mode = 1
		ring.anchor_left = 0.0
		ring.anchor_top = 0.0
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = -ring_padding
		ring.offset_top = -ring_padding
		ring.offset_right = ring_padding
		ring.offset_bottom = ring_padding
		control.add_child(ring)
		control.move_child(ring, 0)
	var state := {"hovered": false, "pressed": false}
	var apply_state := func() -> void:
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * (press_scale if state["pressed"] else (hover_scale if state["hovered"] else 1.0))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.corner_radius_top_left = 18
		style.corner_radius_top_right = 18
		style.corner_radius_bottom_right = 18
		style.corner_radius_bottom_left = 18
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		if state["hovered"]:
			style.border_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.72)
			style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.34)
			style.shadow_size = 18 if not state["pressed"] else 10
		else:
			style.border_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
			style.shadow_color = Color(0, 0, 0, 0)
			style.shadow_size = 0
		ring.add_theme_stylebox_override("panel", style)
	control.mouse_entered.connect(func() -> void:
		state["hovered"] = true
		apply_state.call()
		_play_sfx_method("play_ui_hover")
	)
	control.mouse_exited.connect(func() -> void:
		state["hovered"] = false
		state["pressed"] = false
		apply_state.call()
	)
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		button.button_down.connect(func() -> void:
			state["pressed"] = true
			apply_state.call()
		)
		button.button_up.connect(func() -> void:
			state["pressed"] = false
			apply_state.call()
		)
		button.pressed.connect(func() -> void:
			if bool(control.get_meta("sfx_click_disabled", false)):
				return
			_play_sfx_method("play_ui_click")
		)
	apply_state.call()


static func breathe(control: CanvasItem, min_alpha: float = 0.88, max_alpha: float = 1.0, duration: float = 1.8) -> Tween:
	if control == null:
		return null
	var tween: Tween = control.create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bind_cleanup(control, tween)
	tween.set_loops()
	_apply_tweener(tween.tween_property(control, "modulate:a", max_alpha, duration), Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_apply_tweener(tween.tween_property(control, "modulate:a", min_alpha, duration), Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	return tween


static func shake(control: Control, amplitude: Vector2 = Vector2(10, 6), duration: float = 0.24, steps: int = 4) -> Tween:
	if control == null:
		return null
	var tween: Tween = control.create_tween()
	if tween == null:
		return null
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bind_cleanup(control, tween)
	var origin: Vector2 = control.position
	for step in range(max(1, steps)):
		var direction: float = -1.0 if step % 2 == 0 else 1.0
		var factor: float = 1.0 - (float(step) / float(max(1, steps)))
		var target_offset := Vector2(amplitude.x * direction * factor, amplitude.y * (0.5 if step % 2 == 0 else -0.5) * factor)
		_apply_tweener(tween.tween_property(control, "position", origin + target_offset, duration / float(max(1, steps) * 2)), Tween.TRANS_SINE, Tween.EASE_OUT)
		_apply_tweener(tween.tween_property(control, "position", origin, duration / float(max(1, steps) * 2)), Tween.TRANS_SINE, Tween.EASE_IN)
	return tween

static func _bind_cleanup(owner: CanvasItem, tween: Tween) -> void:
	if owner == null or tween == null:
		return
	var node_owner: Node = owner as Node
	if node_owner == null:
		return
	node_owner.tree_exiting.connect(func() -> void:
		if tween != null:
			tween.kill()
	, CONNECT_ONE_SHOT)


static func _play_sfx_method(method_name: String) -> void:
	if typeof(SfxManager) == TYPE_NIL or SfxManager == null:
		return
	if SfxManager.has_method(method_name):
		SfxManager.call(method_name)
