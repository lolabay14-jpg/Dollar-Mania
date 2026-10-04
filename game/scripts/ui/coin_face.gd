class_name CoinFace
extends Control

var _side := "edge"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(168, 168)


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
