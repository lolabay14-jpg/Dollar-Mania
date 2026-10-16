class_name CoinFace
extends Control

signal swiped

var _side := "edge"
var _armed := false
var _drag_from := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(168, 168)


func arm_swipe(enabled: bool) -> void:
	_armed = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_side(side: String) -> void:
	var next := side.to_lower()
	if next.begins_with("h"):
		_side = "heads"
	elif next.begins_with("t"):
		_side = "tails"
	else:
		_side = "edge"
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	if radius < 8.0:
		return
	draw_circle(center, radius + 6.0, Color("8A6414"))
	draw_circle(center, radius, Color("F5C542"))
	draw_arc(center, radius * 0.78, 0.0, TAU, 48, Color("FFF1B8"), 4.0)
	if _side == "edge":
		draw_rect(Rect2(center + Vector2(-radius * 0.15, -radius), Vector2(radius * 0.3, radius * 2.0)), Color("C8962E"))
		return
	var mark := "D" if _side == "heads" else "M"
	var font := ThemeDB.fallback_font
	var font_size := int(radius * 0.95)
	var text_size := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.35),
		mark,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("141008")
	)
	if _side == "tails":
		draw_arc(center, radius * 0.48, 0.6, TAU - 0.6, 24, Color("8A6414"), 3.0)


func _gui_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_drag_from = mouse.position
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask != 0 and motion.position.distance_to(_drag_from) > 28.0:
			_release_swipe()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_drag_from = touch.position
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.position.distance_to(_drag_from) > 28.0:
			_release_swipe()


func _release_swipe() -> void:
	if not _armed:
		return
	_armed = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	swiped.emit()
	accept_event()
