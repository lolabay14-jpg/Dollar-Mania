class_name GameCard
extends PanelContainer

## Shared lobby card. Play uses the caller's existing game navigation.

signal play_pressed(game: Dictionary)

const POPULAR := ["fruit-spin", "lucky-dollar", "fishing", "scratch-mania", "coin-flip", "higher-card", "lucky-wheel", "prize-spinner"]

var _game: Dictionary = {}
var _banner: GameBanner
var _play: Button
var _accent := Color("F5C542")
var _wired := false
var _motion: Tween
var _featured := false
var _opened := false


static func group_of(game: Dictionary) -> String:
	match str(game.get("category", "")).to_upper():
		"SPIN":
			return "SPIN"
		"SLOTS":
			return "SLOTS"
		"CARDS":
			return "CARDS"
		"FISHING", "BONUS":
			return "SPECIAL"
		_:
			return "ARCADE"


static func is_popular(game: Dictionary) -> bool:
	return str(game.get("slug", "")) in POPULAR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(game: Dictionary, featured := false, show_play := true, extra := "") -> void:
	_game = game
	_featured = featured
	_opened = false
	scale = Vector2.ONE
	if _motion:
		_motion.kill()
	var slug := str(game.get("slug", ""))
	_accent = UiTheme.game_accent(slug)
	UiTheme.paint_card(self, _accent)
	for child in get_children():
		remove_child(child)
		child.free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	_banner = GameBanner.new()
	_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner.clip_contents = true
	_banner.set_banner_height(220.0 if featured else 156.0)
	box.add_child(_banner)
	_banner.set_game(slug, str(game.get("category", "")), _accent)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 8)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_inset(copy, 16))
	if featured:
		var kicker := Label.new()
		kicker.text = "Featured"
		kicker.add_theme_font_size_override("font_size", 13)
		kicker.add_theme_color_override("font_color", UiTheme.COL_GOLD)
		copy.add_child(kicker)
	var title := Label.new()
	title.text = str(game.get("name", "Game"))
	title.add_theme_font_size_override("font_size", 28 if featured else 20)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(title)
	var blurb := Label.new()
	blurb.text = str(game.get("description", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTheme.style_muted(blurb)
	copy.add_child(blurb)
	if extra != "":
		var extra_label := Label.new()
		extra_label.text = extra
		extra_label.add_theme_font_size_override("font_size", 14)
		extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(extra_label)
		copy.add_child(extra_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_child(actions)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(badges)
	var category := str(game.get("category", ""))
	if category != "":
		badges.add_child(_badge(category.capitalize(), UiTheme.COL_BLUE))
	if show_play:
		_play = Button.new()
		_play.text = "Play Now" if featured else "Play"
		_play.theme_type_variation = "PrimaryButton"
		_play.custom_minimum_size = Vector2(120 if featured else 96, 48)
		_play.add_theme_font_size_override("font_size", 16)
		_play.pressed.connect(_press_play)
		actions.add_child(_play)
	custom_minimum_size = Vector2(0, 0)
	if not _wired:
		_wired = true
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))
		gui_input.connect(_touch_card)


func _inset(child: Control, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, amount)
	margin.add_child(child)
	return margin


func _badge(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.16)
	box.border_color = Color(color, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return panel


func _hover(hot: bool) -> void:
	UiTheme.paint_card(self, _accent, hot)
	pivot_offset = size * 0.5
	if _banner:
		_banner.pivot_offset = _banner.size * 0.5
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.set_parallel(true)
	_motion.tween_property(self, "scale", Vector2(1.02, 1.02) if hot else Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _banner:
		_motion.tween_property(_banner, "scale", Vector2(1.05, 1.05) if hot else Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _touch_card(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		_nudge(Vector2(0.96, 0.96))
		return
	_nudge(Vector2.ONE)
	_open_now()


func _nudge(target: Vector2) -> void:
	pivot_offset = size * 0.5
	modulate = Color(1.06, 1.05, 0.98) if target.x < 1.0 else Color.WHITE
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "scale", target, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _press_play() -> void:
	_nudge(Vector2(0.96, 0.96))
	_open_now()


func _open_now() -> void:
	if _opened:
		return
	_opened = true
	if _play:
		_play.disabled = true
	play_pressed.emit(_game)
