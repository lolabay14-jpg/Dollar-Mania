extends CanvasLayer

## Full-screen fade used between menus and the slot machine.

var slide := 0
var _shade: ColorRect
var _glow: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_shade = ColorRect.new()
	_shade.color = Color("070B14")
	_shade.color.a = 0.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_glow = ColorRect.new()
	_glow.color = Color("F5C542")
	_glow.color.a = 0.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.anchor_top = 0.5
	_glow.anchor_bottom = 0.5
	_glow.offset_top = -2.0
	_glow.offset_bottom = 2.0
	add_child(_glow)


func cover() -> void:
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var view := _current_view()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_shade, "color:a", 0.94, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_glow, "color:a", 0.55, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if view:
		view.pivot_offset = view.size * 0.5
		tween.tween_property(view, "scale", Vector2(0.985, 0.985), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished


func reveal() -> void:
	var view := _current_view()
	if view:
		view.scale = Vector2(1.015, 1.015)
		view.pivot_offset = view.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_shade, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_glow, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if view:
		tween.tween_property(view, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if view and is_instance_valid(view):
		view.scale = Vector2.ONE


func _current_view() -> Control:
	var tree := get_tree()
	if tree == null or tree.current_scene == null or not tree.current_scene is Control:
		return null
	return tree.current_scene
