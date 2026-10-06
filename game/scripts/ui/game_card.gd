class_name GameCard
extends PanelContainer

## Premium lobby card. Artwork is the focus; copy and Play sit on a dark gradient.

signal play_pressed(game: Dictionary)

const POPULAR := ["fruit-spin", "diamond-spin", "lucky-dollar", "fishing", "scratch-mania", "coin-flip", "target-blast", "lucky-wheel", "mystery-box", "aeroplane-rush", "bottle-blast"]

var _game: Dictionary = {}
var _art: TextureRect
var _play: Button
var _accent := Color("F5C542")
var _wired := false
var _motion: Tween
var _featured := false
var _opened := false
var _available := true
var _card_size := Vector2(280, 210)
var _press_pos := Vector2.ZERO
var _pressing := false


static func group_of(game: Dictionary) -> String:
	match str(game.get("category", "")).to_upper():
		"SPIN":
			return "SPIN"
		"SLOTS":
			return "SLOTS"
		"CARDS":
			return "CARDS"
		"FISHING", "REACTION":
			return "ARCADE"
		"BONUS":
			return "SPECIAL"
		"SCRATCH", "CHOICE", "MATCH":
			return "SPECIAL"
		_:
			return "ARCADE"


static func is_popular(game: Dictionary) -> bool:
	return str(game.get("slug", "")) in POPULAR


static func _group_label(game: Dictionary) -> String:
	var slug := str(game.get("slug", ""))
	match slug:
		"fruit-spin", "diamond-spin", "lucky-dollar", "golden-fortune":
			return "Slots"
		"lucky-wheel", "lucky-spin", "jackpot-wheel", "bonus-burst", "prize-spinner":
			return "Spin & Wheel"
		"coin-flip", "treasure-box", "cash-match", "mystery-box", "diamond-drop":
			return "Arcade"
		"fishing", "target-blast", "aeroplane-rush", "bottle-blast", "dollar-rush":
			return "Action & Skill"
		"scratch-mania", "higher-card", "dice", "lucky-number":
			return "Casual"
	match str(game.get("category", "")).to_upper():
		"SPIN":
			return "Spin & Wheel"
		"SLOTS":
			return "Slots"
		"CARDS":
			return "Casual"
		"BONUS":
			return "Spin & Wheel"
		"FISHING", "REACTION":
			return "Action & Skill"
		"SCRATCH", "CHOICE", "MATCH":
			return "Arcade"
		_:
			return str(game.get("category", "Game")).capitalize()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func configure(game: Dictionary, featured := false, show_play := true, extra := "", card_size := Vector2.ZERO) -> void:
	_game = game
	_featured = featured
	_opened = false
	_available = true
	if game.has("enabled"):
		_available = bool(game.get("enabled", true))
	scale = Vector2.ONE
	if _motion:
		_motion.kill()
	var slug := str(game.get("slug", ""))
	_accent = UiTheme.game_accent(slug)
	if card_size.x > 0.0 and card_size.y > 0.0:
		_card_size = card_size
	elif custom_minimum_size.x > 0.0:
		_card_size = Vector2(custom_minimum_size.x, maxf(custom_minimum_size.y, 190.0))
	else:
		_card_size = Vector2(380.0 if featured else 340.0, 286.0 if featured else 260.0)
	custom_minimum_size = _card_size
	size = _card_size
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	_paint_shell()
	for child in get_children():
		remove_child(child)
		child.free()
	var layer := Control.new()
	layer.name = "ArtLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	add_child(layer)
	var base := ColorRect.new()
	base.color = Color(0.05, 0.07, 0.12, 1.0)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(base)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := GameArt.path_for(slug)
	_art.texture = GameArt.banner(slug)
	layer.add_child(_art)
	if _art.texture == null:
		push_warning("GameCard missing art for %s (%s) path=%s" % [str(game.get("name", slug)), slug, art_path])
		base.color = Color(_accent, 0.45)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.04, 0.09, 0.12 if _available else 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	var gradient := TextureRect.new()
	gradient.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	gradient.offset_top = -200.0
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gradient.stretch_mode = TextureRect.STRETCH_SCALE
	gradient.texture = _make_gradient()
	layer.add_child(gradient)
	var copy := VBoxContainer.new()
	copy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	copy.offset_left = 16.0
	copy.offset_right = -16.0
	copy.offset_top = -176.0
	copy.offset_bottom = -14.0
	copy.add_theme_constant_override("separation", 7)
	copy.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(copy)
	var chip := Label.new()
	chip.text = _group_label(game).to_upper()
	chip.add_theme_font_size_override("font_size", 12)
	chip.add_theme_color_override("font_color", Color(_accent.lightened(0.25)))
	copy.add_child(chip)
	var title := Label.new()
	title.text = str(game.get("name", "Game"))
	title.add_theme_font_size_override("font_size", 26 if featured else 23)
	title.add_theme_color_override("font_color", Color("FFF8E6"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var meta := Label.new()
	meta.text = str(game.get("difficulty", "")).capitalize()
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color("B8C3D8"))
	copy.add_child(meta)
	if not _available:
		var lock := Label.new()
		lock.text = "Unavailable"
		lock.add_theme_font_size_override("font_size", 12)
		lock.add_theme_color_override("font_color", Color("FFB4BE"))
		copy.add_child(lock)
	elif extra != "":
		var extra_label := Label.new()
		extra_label.text = extra
		extra_label.add_theme_font_size_override("font_size", 11)
		extra_label.add_theme_color_override("font_color", Color("C5D0E4"))
		extra_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		extra_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		copy.add_child(extra_label)
	if show_play:
		_play = Button.new()
		_play.text = "Play" if _available else "Locked"
		_play.disabled = not _available
		_play.custom_minimum_size = Vector2(0, 50)
		_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_play.add_theme_font_size_override("font_size", 16)
		_play.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_play(_play)
		if _available:
			_play.pressed.connect(_press_play)
		copy.add_child(_play)
	modulate = Color.WHITE if _available else Color(0.82, 0.82, 0.86, 1.0)
	if not _wired:
		_wired = true
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))
		gui_input.connect(_touch_card)


func _style_play(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(_accent, 0.95) if _available else Color(0.2, 0.22, 0.28, 0.9)
	normal.border_color = Color(_accent.lightened(0.2), 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(_accent, 0.35)
	normal.shadow_size = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(_accent.lightened(0.12), 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(_accent.darkened(0.12), 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", UiTheme.COL_INK if _available else Color(0.7, 0.72, 0.78))
	button.add_theme_color_override("font_hover_color", UiTheme.COL_INK)
	button.add_theme_color_override("font_pressed_color", UiTheme.COL_INK)
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.78))


func _paint_shell() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.09, 0.78)
	box.border_color = Color(_accent, 0.7 if _available else 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(20)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_color = Color(_accent, 0.28)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", box)


func _make_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.02, 0.04, 0.08, 0.0),
		Color(0.02, 0.04, 0.08, 0.72),
		Color(0.02, 0.04, 0.08, 0.96),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 180
	return texture


func _hover(hot: bool) -> void:
	if not _available:
		return
	_accent = UiTheme.game_accent(str(_game.get("slug", "")))
	_paint_shell()
	if _play:
		_style_play(_play)
	pivot_offset = size * 0.5
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "scale", Vector2(1.03, 1.03) if hot else Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _touch_card(event: InputEvent) -> void:
	if not _available:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_pressing = true
			_press_pos = mouse.position
			_nudge(Vector2(0.97, 0.97))
			return
		var moved := _pressing and _press_pos.distance_to(mouse.position) > 12.0
		_pressing = false
		_nudge(Vector2.ONE)
		# Ignore click-open after a horizontal drag so the carousel can swipe cleanly.
		if not moved:
			_open_now()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pressing = true
			_press_pos = touch.position
			_nudge(Vector2(0.97, 0.97))
		else:
			var moved_touch := _pressing and _press_pos.distance_to(touch.position) > 12.0
			_pressing = false
			_nudge(Vector2.ONE)
			if not moved_touch:
				_open_now()


func _nudge(target: Vector2) -> void:
	pivot_offset = size * 0.5
	modulate = Color(1.05, 1.04, 0.98) if target.x < 1.0 else (Color.WHITE if _available else Color(0.82, 0.82, 0.86, 1.0))
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "scale", target, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _press_play() -> void:
	_nudge(Vector2(0.97, 0.97))
	_open_now()


func _open_now() -> void:
	if _opened or not _available:
		return
	_opened = true
	if _play:
		_play.disabled = true
	play_pressed.emit(_game)
