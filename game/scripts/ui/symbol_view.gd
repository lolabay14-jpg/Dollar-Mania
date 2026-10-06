class_name SymbolView
extends Control

var _id := "coin"
var _winning := false
var _panel := StyleBoxFlat.new()


func _ready() -> void:
	_panel.set_corner_radius_all(16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_symbol(symbol_id: String) -> void:
	var next := symbol_id.to_lower()
	if next == _id and not _winning:
		return
	_id = next
	queue_redraw()


func set_winning(winning: bool) -> void:
	_winning = winning
	modulate = Color(1.12, 1.06, 0.78) if winning else Color.WHITE
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var colors := _colors()
	_panel.bg_color = colors["panel"]
	_panel.border_color = UiTheme.COL_GOLD_SOFT if _winning else Color(colors["face"], 0.85)
	_panel.border_width_left = 3 if _winning else 2
	_panel.border_width_top = _panel.border_width_left
	_panel.border_width_right = _panel.border_width_left
	_panel.border_width_bottom = _panel.border_width_left
	draw_style_box(_panel, rect)
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.36
	_draw_art(center, radius, colors)


func _colors() -> Dictionary:
	match _id:
		"star":
			return {"panel": Color("241C0C"), "face": UiTheme.COL_GOLD, "ink": Color("FFF8E6")}
		"diamond":
			return {"panel": Color("102433"), "face": Color("3E8CA8"), "ink": Color("F3FCFF")}
		"seven":
			return {"panel": Color("2C1218"), "face": Color("C43B52"), "ink": Color("FFF4F6")}
		"bonus", "berry":
			return {"panel": Color("2C1218"), "face": Color("D6455D"), "ink": Color("7C1E2E")}
		"dollar", "lemon":
			return {"panel": Color("2A2408"), "face": Color("F2D24B"), "ink": Color("8A6A10")}
		"cherry":
			return {"panel": Color("2A1014"), "face": Color("E23B45"), "ink": Color("7A1020")}
		"orange":
			return {"panel": Color("2A1A0C"), "face": Color("F08A24"), "ink": Color("8A3E08")}
		"melon":
			return {"panel": Color("102418"), "face": Color("3DDC97"), "ink": Color("E84B63")}
		"grapes":
			return {"panel": Color("1A1230"), "face": Color("7A4AD0"), "ink": Color("F4EEFF")}
		"ruby":
			return {"panel": Color("2C1016"), "face": Color("D23B55"), "ink": Color("FFE4EA")}
		"gold":
			return {"panel": Color("2A220F"), "face": Color("E0A82E"), "ink": Color("FFF6D8")}
		"jade":
			return {"panel": Color("102418"), "face": Color("3DDC97"), "ink": Color("EFFFF6")}
		"blue":
			return {"panel": Color("102433"), "face": Color("3E8CA8"), "ink": Color("F3FCFF")}
		_:
			return {"panel": Color("2A220F"), "face": Color("E0A82E"), "ink": Color("1A1408")}


func _draw_art(center: Vector2, radius: float, colors: Dictionary) -> void:
	var face: Color = colors["face"]
	var ink: Color = colors["ink"]
	match _id:
		"star":
			draw_circle(center, radius * 0.92, Color(face, 0.18))
			_draw_star(center, radius, face)
		"diamond", "ruby", "gold", "jade", "blue":
			_draw_gem(center, radius, face, ink)
		"seven":
			draw_circle(center, radius, face)
			_draw_text(center, "7", radius * 1.35, ink)
		"cherry":
			_draw_cherry(center, radius, face, ink)
		"lemon":
			_draw_lemon(center, radius, face, ink)
		"dollar":
			draw_circle(center, radius, face)
			_draw_text(center, "$", radius, ink)
		"orange":
			draw_circle(center, radius * 0.86, face)
			draw_circle(center + Vector2(0, -radius * 0.72), radius * 0.16, ink)
		"melon":
			draw_circle(center, radius * 0.9, face)
			draw_circle(center, radius * 0.55, ink)
			draw_circle(center, radius * 0.18, Color("F4F7FB"))
		"grapes":
			_draw_grapes(center, radius, face)
		"bonus", "berry":
			_draw_berry(center, radius, face, ink)
		_:
			draw_circle(center, radius, face)
			draw_arc(center, radius * 0.72, 0.4, PI - 0.4, 16, ink, maxf(radius * 0.12, 2.0))
			draw_circle(center, radius * 0.22, ink)


func _draw_text(center: Vector2, text: String, radius: float, ink: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := int(maxf(radius * 1.7, 22.0))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_gem(center: Vector2, radius: float, face: Color, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.72, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.72, 0),
	]), face)
	draw_line(center + Vector2(-radius * 0.36, 0), center + Vector2(radius * 0.36, 0), ink, 2.0)


func _draw_cherry(center: Vector2, radius: float, face: Color, ink: Color) -> void:
	var left := center + Vector2(-radius * 0.32, radius * 0.18)
	var right := center + Vector2(radius * 0.34, radius * 0.08)
	draw_circle(left, radius * 0.42, face)
	draw_circle(right, radius * 0.42, face)
	draw_line(left + Vector2(0, -radius * 0.2), center + Vector2(0, -radius * 0.7), ink, 3.0)
	draw_line(right + Vector2(0, -radius * 0.2), center + Vector2(0, -radius * 0.7), ink, 3.0)


func _draw_lemon(center: Vector2, radius: float, face: Color, ink: Color) -> void:
	draw_set_transform(center, 0.4, Vector2(1.25, 0.82))
	draw_circle(Vector2.ZERO, radius * 0.7, face)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center + Vector2(radius * 0.55, -radius * 0.15), radius * 0.12, ink)


func _draw_grapes(center: Vector2, radius: float, face: Color) -> void:
	var points: Array[Vector2] = [Vector2(-0.28, 0.2), Vector2(0.28, 0.2), Vector2(0, -0.12), Vector2(-0.28, -0.38), Vector2(0.28, -0.38)]
	for point in points:
		draw_circle(center + point * radius, radius * 0.28, face)


func _draw_berry(center: Vector2, radius: float, face: Color, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius * 0.9),
		center + Vector2(radius * 0.72, radius * 0.15),
		center + Vector2(0, radius * 0.9),
		center + Vector2(-radius * 0.72, radius * 0.15),
	]), face)
	draw_circle(center + Vector2(0, -radius * 0.95), radius * 0.22, ink)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI / 2.0 + float(index) * PI / 5.0
		var reach := radius * 0.46
		if index % 2 == 0:
			reach = radius
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, color)
