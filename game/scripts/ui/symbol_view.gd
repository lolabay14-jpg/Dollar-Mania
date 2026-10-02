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
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	draw_circle(center, radius, colors["face"])
	_draw_glyph(center, radius * 0.78, colors["ink"])


func _colors() -> Dictionary:
	match _id:
		"star":
			return {"panel": Color("241C0C"), "face": UiTheme.COL_GOLD, "ink": Color("FFF8E6")}
		"diamond":
			return {"panel": Color("102433"), "face": Color("3E8CA8"), "ink": Color("F3FCFF")}
		"seven":
			return {"panel": Color("2C1218"), "face": Color("C43B52"), "ink": Color("FFF4F6")}
		"bonus":
			return {"panel": Color("241833"), "face": Color("8B7CFF"), "ink": Color("F7F4FF")}
		"dollar":
			return {"panel": Color("1C2410"), "face": Color("7DDC4A"), "ink": Color("F4FFE8")}
		_:
			return {"panel": Color("2A220F"), "face": Color("E0A82E"), "ink": Color("1A1408")}


func _draw_glyph(center: Vector2, radius: float, ink: Color) -> void:
	if _id == "star" or _id == "bonus":
		_draw_star(center, radius, ink)
		return
	if _id == "diamond":
		var reach := radius
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -reach),
			center + Vector2(reach * 0.72, 0),
			center + Vector2(0, reach),
			center + Vector2(-reach * 0.72, 0),
		]), ink)
		return
	var text := "$"
	if _id == "seven":
		text = "7"
	elif _id == "dollar":
		text = "$"
	var font := ThemeDB.fallback_font
	var font_size := int(maxf(radius * 1.85, 22.0))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := font.get_ascent(font_size) * 0.36
	draw_string(
		font,
		center + Vector2(-text_size.x * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ink
	)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI / 2.0 + float(index) * PI / 5.0
		var reach := radius if index % 2 == 0 else radius * 0.46
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, color)
