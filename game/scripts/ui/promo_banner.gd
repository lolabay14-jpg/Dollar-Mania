extends PanelContainer

## Drop a Texture2D into banner_texture later. Until then this draws a local placeholder.

@export var banner_texture: Texture2D
@export var kicker := "Virtual floor"
@export var headline := "Spin. Play. Win."
@export var subline := "Placeholder banner. Replace it with your own image."

@onready var _art: TextureRect = %Art


func _ready() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1A2438")
	frame.border_color = UiTheme.COL_GOLD_DARK
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(18)
	frame.content_margin_left = 16
	frame.content_margin_right = 16
	frame.content_margin_top = 14
	frame.content_margin_bottom = 14
	add_theme_stylebox_override("panel", frame)
	%Kicker.text = kicker
	%Headline.text = headline
	%Subline.text = subline
	UiTheme.style_muted(%Kicker)
	%Headline.add_theme_font_size_override("font_size", 22)
	%Headline.add_theme_color_override("font_color", UiTheme.COL_GOLD_SOFT)
	UiTheme.style_muted(%Subline)
	_apply_texture()


func _apply_texture() -> void:
	if _art == null:
		return
	_art.texture = banner_texture
	_art.visible = banner_texture != null


func _draw() -> void:
	if banner_texture != null:
		return
	var rect := Rect2(Vector2(size.x - 132, 18), Vector2(96, 96))
	draw_circle(rect.get_center(), 34, Color(UiTheme.COL_GOLD, 0.16))
	draw_circle(rect.get_center(), 24, UiTheme.COL_GOLD)
	var font := ThemeDB.fallback_font
	var text := "$"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(font, rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.COL_INK)
