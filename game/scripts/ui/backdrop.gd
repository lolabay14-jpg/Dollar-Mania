class_name ArcadeBackdrop
extends Control

## One draw pass of slow coins, sparks, and light. Clicks pass through.

const _SHADER := preload("res://game/ui/arcade_bg.gdshader")

var mood := "calm"
var tint := Color("F5C542")
var _time := 0.0
var _frame := 0.0
var _count := 12
var _speed := 0.12
var _shader: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader = ShaderMaterial.new()
	_shader.shader = _SHADER
	var background := get_parent().get_node_or_null("Background")
	if background is CanvasItem:
		background.material = _shader
	set_mood(mood, tint)


func set_mood(next_mood: String, next_tint: Color = tint) -> void:
	mood = next_mood
	tint = next_tint
	match mood:
		"cinematic":
			_count = 20
			_speed = 0.15
			_paint(Color("070B14"), Color("1A1030"), tint, 0.36, 0.1)
		"lobby":
			_count = 16
			_speed = 0.2
			_paint(Color("071018"), Color("102033"), Color("3DDC97"), 0.22, 0.14)
		"game":
			_count = 18
			_speed = 0.24
			_paint(Color("070B16"), Color("160E24"), tint, 0.3, 0.18)
		_:
			_count = 12
			_speed = 0.11
			_paint(Color("070B16"), Color("12182C"), Color("8B7CFF"), 0.16, 0.08)
	queue_redraw()


func _process(delta: float) -> void:
	_frame += delta
	if _frame < 0.05:
		return
	_time += _frame
	_frame = 0.0
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var glyphs := ["$", "*", "+", "o"]
	for index in _count:
		var phase := _time * _speed + float(index) * 1.37
		var x := fposmod(0.06 + float(index) * 0.137 + sin(phase) * 0.035, 1.0) * size.x
		var y := fposmod(0.04 + float(index) * 0.113 - _time * _speed * 0.05, 1.0) * size.y
		var point := Vector2(x, y)
		var sparkle := Color(tint, 0.045 + float(index % 3) * 0.012)
		draw_circle(point, 8.0 + float(index % 4) * 7.0, sparkle)
		if font == null:
			continue
		var glyph := str(glyphs[index % glyphs.size()])
		var font_size := 16 + (index % 3) * 8
		var alpha := 0.1 + float(index % 4) * 0.025
		if mood == "cinematic" and index % 5 == 0:
			font_size = 34
			alpha = 0.2
		elif mood == "calm":
			alpha *= 0.75
		var ink := tint
		ink.a = alpha
		draw_string(font, point, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var streak_y := size.y * (0.18 + sin(_time * 0.12) * 0.02)
	draw_line(Vector2(0, streak_y), Vector2(size.x, streak_y + 18.0), Color(0.55, 0.65, 1.0, 0.045), 2.0)


func _paint(top: Color, bottom: Color, glow: Color, strength: float, scale: float) -> void:
	if _shader == null:
		return
	_shader.set_shader_parameter("color_top", top)
	_shader.set_shader_parameter("color_bottom", bottom)
	_shader.set_shader_parameter("glow_color", glow)
	_shader.set_shader_parameter("glow_strength", strength)
	_shader.set_shader_parameter("time_scale", scale)
