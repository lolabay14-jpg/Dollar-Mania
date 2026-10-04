class_name UiMotion
extends RefCounted

static func settle(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.97, 0.97)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)


static func enter(column: MarginContainer, slide := 0) -> void:
	var top := column.get_theme_constant("margin_top")
	var left := column.get_theme_constant("margin_left")
	var right := column.get_theme_constant("margin_right")
	var shift_x := 42 * slide
	column.modulate.a = 0.0
	column.pivot_offset = column.size * 0.5
	column.scale = Vector2(0.985, 0.985)
	column.add_theme_constant_override("margin_top", top + 28)
	column.add_theme_constant_override("margin_left", left + shift_x)
	column.add_theme_constant_override("margin_right", right - shift_x)
	var tween := column.create_tween()
	tween.set_parallel(true)
	tween.tween_property(column, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(column, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void:
		column.add_theme_constant_override("margin_top", int(value))
	, float(top + 28), float(top), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void:
		column.add_theme_constant_override("margin_left", int(value))
	, float(left + shift_x), float(left), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void:
		column.add_theme_constant_override("margin_right", int(value))
	, float(right - shift_x), float(right), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func fade_in(control: CanvasItem) -> void:
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)


static func bind_button(button: BaseButton) -> void:
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func() -> void:
		if not button.button_pressed:
			_scale_to(button, Vector2(1.02, 1.02), 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		if not button.button_pressed:
			_scale_to(button, Vector2.ONE, 0.12)
	)
	button.button_down.connect(func() -> void:
		_scale_to(button, Vector2(0.96, 0.96), 0.06)
	)
	button.button_up.connect(func() -> void:
		_scale_to(button, Vector2.ONE, 0.1)
	)


static func pulse_selected(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func pop_in(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.visible = true
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.92, 0.92)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)


static func float_delta(host: Control, anchor: Control, text: String, positive: bool) -> void:
	if host == null or anchor == null or not host.is_inside_tree():
		return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 8
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiTheme.COL_GREEN if positive else UiTheme.COL_DANGER)
	host.add_child(label)
	label.global_position = anchor.global_position + Vector2(0, -4)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.16)
	tween.finished.connect(label.queue_free)


static func reveal(control: CanvasItem) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)


static func bind_fields(root: Node) -> void:
	for node in root.find_children("*", "LineEdit", true, false):
		if node is LineEdit:
			var field := node as LineEdit
			field.focus_entered.connect(func() -> void:
				field.modulate = Color(1.05, 1.03, 0.94)
			)
			field.focus_exited.connect(func() -> void:
				field.modulate = Color.WHITE
			)


static func bind_tree(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		if node is BaseButton and not node.has_meta("motion_bound"):
			node.set_meta("motion_bound", true)
			bind_button(node)


static func _scale_to(button: BaseButton, target: Vector2, duration := 0.14) -> void:
	button.pivot_offset = button.size * 0.5
	if button.has_meta("motion_tween"):
		var existing: Variant = button.get_meta("motion_tween")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()
	var tween := button.create_tween()
	button.set_meta("motion_tween", tween)
	tween.tween_property(button, "scale", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
