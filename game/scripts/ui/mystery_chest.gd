class_name MysteryChest
extends Control

var open_amount := 0.0:
	set(value):
		open_amount = value
		queue_redraw()

var shake := 0.0:
	set(value):
		shake = value
		queue_redraw()

var prize := -1.0:
	set(value):
		prize = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 280)


func _process(delta: float) -> void:
	_time += delta
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 16.0:
		return
	draw_rect(rect, Color("1A1208"), true)
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color("3A2410"), true)
	for index in 5:
		var x := 24.0 + float(index) * (size.x - 48.0) / 4.0
		draw_circle(Vector2(x, size.y * 0.72 + sin(_time + float(index)) * 3.0), 7.0, Color("F5C542"))
	var wobble := sin(_time * 28.0) * 4.0 * shake
	var center := Vector2(size.x * 0.5 + wobble, size.y * 0.58)
	var body := Rect2(center + Vector2(-78, -20), Vector2(156, 92))
	draw_rect(body, Color("8A4B16"), true)
	draw_rect(body.grow(-6), Color("C47A2C"), true)
	draw_rect(Rect2(body.position + Vector2(68, 8), Vector2(18, body.size.y - 16)), Color("F5C542"), true)
	var lid_h := lerpf(36.0, 8.0, open_amount)
	var lid := Rect2(body.position + Vector2(0, -lid_h - lerpf(0.0, 28.0, open_amount)), Vector2(body.size.x, lid_h + 8.0))
	draw_rect(lid, Color("A86420"), true)
	draw_rect(Rect2(lid.position + Vector2(body.size.x * 0.5 - 8.0, lid.size.y - 6.0), Vector2(16, 10)), Color("FFE38A"), true)
	if open_amount > 0.45:
		var glow := Color("FFE38A")
		glow.a = (open_amount - 0.45) * 0.8
		draw_circle(center + Vector2(0, -36), 28.0 + open_amount * 10.0, glow)
		if prize >= 0.0:
			var font := ThemeDB.fallback_font
			if font == null:
				return
			var label := "Empty"
			if prize > 0.0:
				label = "%sx" % _amount(prize)
			var font_size := 36
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, center + Vector2(-text_size.x * 0.5, -28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1A1208"))


func _amount(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value
