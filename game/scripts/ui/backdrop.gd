class_name ArcadeBackdrop
extends Control

## Soft particle dust. Full-screen photos use blur-fill + sharp contain artwork.

var mood := "calm"
var tint := Color("F5C542")
var _time := 0.0
var _frame := 0.0
var _count := 12
var _speed := 0.12


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := get_parent().get_node_or_null("Background") as CanvasItem
	if background:
		background.material = null
	set_mood(mood, tint)


func set_mood(next_mood: String, next_tint: Color = tint) -> void:
	mood = next_mood
	tint = next_tint
	match mood:
		"cinematic":
			_count = 20
			_speed = 0.15
		"lobby":
			_count = 16
			_speed = 0.2
		"hub":
			_count = 14
			_speed = 0.14
		"game":
			_count = 18
			_speed = 0.24
		_:
			_count = 12
			_speed = 0.11
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
		var sparkle := Color(tint, 0.04 + float(index % 3) * 0.01)
		draw_circle(point, 8.0 + float(index % 4) * 7.0, sparkle)
		if font == null:
			continue
		var glyph := str(glyphs[index % glyphs.size()])
		var font_size := 16 + (index % 3) * 8
		var alpha := 0.08 + float(index % 4) * 0.02
		if mood == "cinematic" and index % 5 == 0:
			font_size = 34
			alpha = 0.16
		elif mood == "calm":
			alpha *= 0.75
		var ink := tint
		ink.a = alpha
		draw_string(font, point, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Option B: blurred full-screen cover fill + sharp contained artwork (no crop on main art).
## sharp_alpha < 1 softens promotional text in the sharp layer (lobby atmosphere).
static func mount_photo(host: Control, path: String, shade: float, sharp_alpha := 1.0) -> void:
	var existing := host.get_node_or_null("PhotoLayer")
	if existing:
		host.remove_child(existing)
		existing.free()
	var texture := GameArt.texture(path)
	if texture == null:
		push_warning("ArcadeBackdrop missing photo: %s" % path)
		return
	var layer := Control.new()
	layer.name = "PhotoLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	host.add_child(layer)
	var background := host.get_node_or_null("Background") as CanvasItem
	if background:
		background.material = null
		if background is ColorRect:
			(background as ColorRect).color = Color(0.03, 0.04, 0.08, 1.0)
		background.modulate = Color.WHITE
		host.move_child(layer, background.get_index() + 1)
	else:
		host.move_child(layer, 0)

	# Layer 1 — full-screen cover fill (may crop); blurred + darkened.
	var blur_fill := TextureRect.new()
	blur_fill.name = "BlurFill"
	blur_fill.texture = texture
	blur_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blur_fill.stretch_mode = TextureRect.STRETCH_SCALE
	blur_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_fill.material = _blur_material()
	blur_fill.modulate = Color(0.55, 0.58, 0.7, 1.0)
	layer.add_child(blur_fill)

	var fill_dim := ColorRect.new()
	fill_dim.name = "FillDim"
	fill_dim.color = Color(0.02, 0.03, 0.07, clampf(shade * 0.55 + 0.28, 0.35, 0.82))
	fill_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fill_dim)

	# Layer 2 — sharp contained artwork (entire image visible, never cropped/stretched).
	var sharp := TextureRect.new()
	sharp.name = "Photo"
	sharp.texture = texture
	sharp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp.stretch_mode = TextureRect.STRETCH_SCALE
	sharp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var alpha := clampf(sharp_alpha, 0.0, 1.0)
	sharp.modulate = Color(1, 1, 1, alpha)
	sharp.visible = alpha > 0.02
	layer.add_child(sharp)

	var veil := ColorRect.new()
	veil.name = "Veil"
	# Extra veil when sharp art is muted so lobby text does not dominate cards.
	var veil_a := clampf(shade * 0.35 + (1.0 - alpha) * 0.28, 0.08, 0.72)
	veil.color = Color(0.02, 0.03, 0.07, veil_a)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)

	var wash := TextureRect.new()
	wash.name = "Wash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.texture = _screen_wash()
	layer.add_child(wash)

	var fit := func() -> void:
		_fit_cover(blur_fill, texture, layer.size)
		_fit_contain(sharp, texture, layer.size)
	layer.resized.connect(fit)
	host.resized.connect(fit)
	fit.call()


static func _blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float blur_amount : hint_range(0.0, 8.0) = 3.2;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 c = texture(TEXTURE, UV) * 0.20;
	c += texture(TEXTURE, UV + vec2( px.x, 0.0)) * 0.12;
	c += texture(TEXTURE, UV + vec2(-px.x, 0.0)) * 0.12;
	c += texture(TEXTURE, UV + vec2(0.0,  px.y)) * 0.12;
	c += texture(TEXTURE, UV + vec2(0.0, -px.y)) * 0.12;
	c += texture(TEXTURE, UV + vec2( px.x,  px.y)) * 0.08;
	c += texture(TEXTURE, UV + vec2(-px.x,  px.y)) * 0.08;
	c += texture(TEXTURE, UV + vec2( px.x, -px.y)) * 0.08;
	c += texture(TEXTURE, UV + vec2(-px.x, -px.y)) * 0.08;
	COLOR = c;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_amount", 3.4)
	return material


## Cover-fit for the blurred fill layer only.
static func _fit_cover(image: TextureRect, texture: Texture2D, area: Vector2) -> void:
	if texture == null or area.x <= 1.0 or area.y <= 1.0:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale := maxf(area.x / tex_size.x, area.y / tex_size.y)
	var drawn := tex_size * scale
	var origin := Vector2(-(drawn.x - area.x) * 0.5, -(drawn.y - area.y) * 0.5)
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	image.position = origin
	image.size = drawn


## Contain-fit for the sharp artwork: entire image visible, centered, never distorted.
static func _fit_contain(image: TextureRect, texture: Texture2D, area: Vector2) -> void:
	if texture == null or area.x <= 1.0 or area.y <= 1.0:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale := minf(area.x / tex_size.x, area.y / tex_size.y)
	var drawn := tex_size * scale
	var origin := (area - drawn) * 0.5
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	image.position = origin
	image.size = drawn


static func _screen_wash() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.02, 0.03, 0.07, 0.18),
		Color(0.02, 0.03, 0.07, 0.0),
		Color(0.02, 0.03, 0.07, 0.22),
		Color(0.02, 0.03, 0.07, 0.62),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.66, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	return texture
