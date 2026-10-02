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


static func fade_in(control: CanvasItem) -> void:
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)


static func bind_button(button: BaseButton) -> void:
	button.mouse_entered.connect(func() -> void:
		button.modulate = Color(1.08, 1.04, 0.92)
	)
	button.mouse_exited.connect(func() -> void:
		button.modulate = Color.WHITE
	)
	button.button_down.connect(func() -> void:
		button.modulate = Color(0.78, 0.74, 0.62)
	)
	button.button_up.connect(func() -> void:
		button.modulate = Color(1.08, 1.04, 0.92)
	)


static func bind_tree(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		if node is BaseButton:
			bind_button(node)
