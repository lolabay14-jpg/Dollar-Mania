class_name ScratchTile
extends Button

var _symbol: SymbolView


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


func refresh() -> void:
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
