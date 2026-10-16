class_name ScratchTile
extends Button

signal cleared

var _symbol: SymbolView
var _wear := 0.0
var _scratching := false
var _last := Vector2.ZERO
var _marks: Array[Vector2] = []


func _ready() -> void:
	custom_minimum_size = Vector2(108, 128)
	clip_contents = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	_symbol = SymbolView.new()
	_symbol.visible = false
	_symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	_symbol.offset_left = 8
	_symbol.offset_top = 8
	_symbol.offset_right = -8
	_symbol.offset_bottom = -8
	_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_symbol)


func reset_foil() -> void:
	_wear = 0.0
	_scratching = false
	_marks.clear()
	set_meta("open", false)
	refresh()


func force_open() -> void:
	if bool(get_meta("open", false)):
		refresh()
		return
	cleared.emit()


func refresh() -> void:
	if _symbol == null:
		queue_redraw()
		return
	var open := bool(get_meta("open", false))
	_symbol.visible = open
	if open:
		_symbol.set_symbol(str(get_meta("prize", "coin")))
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if rect.size.x < 8.0:
		return
	var ticket := StyleBoxFlat.new()
	ticket.bg_color = Color("F3E2B8") if not bool(get_meta("open", false)) else Color("1A2438")
	ticket.border_color = Color("C8962E")
	ticket.set_border_width_all(2)
	ticket.set_corner_radius_all(16)
	draw_style_box(ticket, rect)
	if bool(get_meta("open", false)):
		return
	var foil := Rect2(rect.position + Vector2(12, 28), rect.size - Vector2(24, 44))
	draw_rect(foil, Color("C9B48A"), true)
	for mark in _marks:
		draw_circle(mark, 10.0, Color("1A2438"))
	for row in 4:
		draw_line(
			foil.position + Vector2(6, 10 + row * 14),
			foil.position + Vector2(foil.size.x - 6, 10 + row * 14),
			Color("8A7350"),
			2.0
		)
	var font := ThemeDB.fallback_font
	var caption := "Scratch"
	var font_size := 18
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2((size.x - text_size.x) * 0.5, size.y - 16.0),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("5C4520")
	)


func _gui_input(event: InputEvent) -> void:
	if bool(get_meta("open", false)):
		return
	var point := Vector2.ZERO
	var pressed := false
	var moved := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		_scratching = mouse.pressed
		_last = mouse.position
		point = mouse.position
		pressed = mouse.pressed
	elif event is InputEventMouseMotion and _scratching:
		point = (event as InputEventMouseMotion).position
		moved = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_scratching = touch.pressed
		_last = touch.position
		point = touch.position
		pressed = touch.pressed
	elif event is InputEventScreenDrag and _scratching:
		point = (event as InputEventScreenDrag).position
		moved = true
	else:
		return
	if pressed:
		_marks.append(point)
		_wear += 8.0
	if moved:
		var step := point.distance_to(_last)
		_wear += step
		_last = point
		if _marks.size() < 28:
			_marks.append(point)
	accept_event()
	queue_redraw()
	if _wear >= 120.0:
		force_open()
