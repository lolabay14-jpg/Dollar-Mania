class_name SymbolView
extends Control

var _id := "coin"
var _winning := false
var _offset := 0.0


func set_symbol(symbol_id: String) -> void:
	_id = symbol_id
	queue_redraw()


func set_winning(winning: bool) -> void:
	_winning = winning
	set_process(winning)
	queue_redraw()


func set_nudge(value: float) -> void:
	_offset = value
	queue_redraw()


func _process(_delta: float) -> void:
	if _winning:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-3.0)
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var center := rect.get_center() + Vector2(0, _offset)
	var radius := minf(rect.size.x, rect.size.y) * 0.38
	var colors := _colors()
	draw_rounded_rect(rect, colors["panel"])
	draw_circle(center, radius + 5.0, Color(colors["face"], 0.22))
	draw_circle(center, radius, colors["face"])
	if _winning:
		var pulse := 0.45 + 0.55 * sin(float(Time.get_ticks_msec()) / 160.0)
		draw_arc(center, radius + 7.0, 0, TAU, 28, Color(UiTheme.COL_GOLD_SOFT, pulse), 3.0, true)
	_draw_glyph(center, radius, colors["ink"])


func draw_rounded_rect(rect: Rect2, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	draw_style_box(box, rect)


func _colors() -> Dictionary:
	match _id:
		"star":
			return {"panel": Color("241C0C"), "face": UiTheme.COL_GOLD, "ink": Color("FFF8E6")}
		"diamond":
			return {"panel": Color("102433"), "face": Color("1C4C66"), "ink": Color("E7FBFF")}
		"seven":
			return {"panel": Color("2C1218"), "face": Color("8E2436"), "ink": Color("FFE8EC")}
		"bonus":
			return {"panel": Color("241833"), "face": Color("6A4AA8"), "ink": Color("F6EEFF")}
		"coin":
			return {"panel": Color("2A220F"), "face": Color("E0A82E"), "ink": Color("1A1408")}
		_:
			return {"panel": Color("2A220F"), "face": UiTheme.COL_GOLD, "ink": Color("1A1408")}


func _draw_glyph(center: Vector2, radius: float, ink: Color) -> void:
	if _id == "star":
		_draw_star(center, radius * 0.62, ink)
		return
	if _id == "diamond":
		var reach := radius * 0.58
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -reach),
			center + Vector2(reach, 0),
			center + Vector2(0, reach),
			center + Vector2(-reach, 0),
		]), ink)
		return
	var text := "$"
	match _id:
		"seven":
			text = "7"
		"bonus":
			text = "B"
		"coin", "dollar":
			text = "$"
	var font := ThemeDB.fallback_font
	var font_size := int(radius * 1.15)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI / 2.0 + float(index) * PI / 5.0
		var reach := radius if index % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(points, color)
