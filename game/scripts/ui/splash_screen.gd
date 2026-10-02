extends Control

var _progress := 0.0
var _loading := true
var _clock := 0.0

@onready var _column: MarginContainer = %Column
@onready var _fill: Panel = %Fill
@onready var _track: Control = %Track


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "cinematic")
	UiTheme.style_title(%Title, 48)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Tagline)
	%Tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%StatusLabel)
	%StatusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%LoadingLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%PercentLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%PercentLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	var banner := $Scroll/Column/Content/Banner
	banner.visible = false
	_style_logo()
	_style_track()
	resized.connect(_fit)
	_fit()
	_intro()
	_run_loading()


func _process(delta: float) -> void:
	_clock += delta
	var wave := 0.5 + 0.5 * sin(_clock * 2.4)
	%Title.add_theme_color_override("font_color", UiTheme.COL_GOLD.lerp(UiTheme.COL_GOLD_SOFT, wave))
	if not _loading:
		return
	_apply_bar()
	_apply_status()


func _style_logo() -> void:
	var logo: PanelContainer = $Scroll/Column/Content/Hero/LogoCenter/Logo
	var coin := StyleBoxFlat.new()
	coin.bg_color = UiTheme.COL_GOLD
	coin.border_color = UiTheme.COL_GOLD_SOFT
	coin.set_border_width_all(2)
	coin.set_corner_radius_all(30)
	coin.shadow_color = Color(UiTheme.COL_GOLD, 0.45)
	coin.shadow_size = 18
	logo.add_theme_stylebox_override("panel", coin)
	var mark: Label = logo.get_node("LogoMark")
	mark.add_theme_font_size_override("font_size", 40)
	mark.add_theme_color_override("font_color", UiTheme.COL_INK)


func _style_track() -> void:
	var track := $Scroll/Column/Content/Track/TrackBg as Panel
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("12182A")
	groove.set_corner_radius_all(8)
	track.add_theme_stylebox_override("panel", groove)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.COL_GOLD
	fill.set_corner_radius_all(8)
	fill.shadow_color = Color(UiTheme.COL_GOLD, 0.4)
	fill.shadow_size = 8
	_fill.add_theme_stylebox_override("panel", fill)


func _intro() -> void:
	$Background.modulate.a = 0.0
	$Dust.modulate.a = 0.0
	%Hero.modulate.a = 0.0
	%Hero.scale = Vector2(0.9, 0.9)
	%Tagline.modulate.a = 0.0
	for node in [%StatusLabel, %Track, %PercentLabel, %LoadingLabel]:
		node.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	%Hero.pivot_offset = %Hero.size * 0.5
	var logo: Control = $Scroll/Column/Content/Hero/LogoCenter/Logo
	logo.pivot_offset = logo.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Background, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property($Dust, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%Hero, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.12)
	tween.tween_property(%Hero, "scale", Vector2.ONE, 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	tween.tween_property(%Tagline, "modulate:a", 1.0, 0.35).set_delay(0.32)
	tween.tween_property(%StatusLabel, "modulate:a", 1.0, 0.3).set_delay(0.42)
	tween.tween_property(%Track, "modulate:a", 1.0, 0.3).set_delay(0.42)
	tween.tween_property(%PercentLabel, "modulate:a", 1.0, 0.3).set_delay(0.48)
	tween.tween_property(%LoadingLabel, "modulate:a", 1.0, 0.3).set_delay(0.48)
	await tween.finished
	if not is_inside_tree():
		return
	var pulse := create_tween().set_loops()
	pulse.tween_property(logo, "scale", Vector2(1.05, 1.05), 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(logo, "scale", Vector2.ONE, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _run_loading() -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 1.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_loading = false
	_set_progress(1.0)
	_apply_bar()
	_apply_status()
	await get_tree().create_timer(0.28).timeout
	AppState.go_login()


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)


func _apply_bar() -> void:
	_fill.anchor_left = 0.0
	_fill.anchor_top = 0.0
	_fill.anchor_bottom = 1.0
	_fill.anchor_right = 0.0
	_fill.offset_left = 0.0
	_fill.offset_top = 0.0
	_fill.offset_bottom = 0.0
	_fill.offset_right = _track.size.x * _progress
	%PercentLabel.text = "%d%%" % int(round(_progress * 100.0))


func _apply_status() -> void:
	%LoadingLabel.text = "Loading..."
	if _progress < 0.34:
		%StatusLabel.text = "Setting the floor"
	elif _progress < 0.7:
		%StatusLabel.text = "Preparing the games"
	elif _progress < 1.0:
		%StatusLabel.text = "Opening the lobby"
	else:
		%StatusLabel.text = "Ready"


func _fit() -> void:
	ScreenLayout.fit_column(_column, 520.0)
	%Title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_title(%Title, 34 if size.x < 520.0 else 48)
	_apply_bar()
