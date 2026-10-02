extends Control

var _progress := 0.0
var _loading := true

@onready var _column: MarginContainer = %Column
@onready var _fill: ColorRect = %Fill
@onready var _track: Control = %Track


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.style_title(%Title, 42)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Tagline)
	%Tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%StatusLabel)
	%StatusLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%LoadingLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%PercentLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%PercentLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_fill.color = UiTheme.COL_GOLD
	_style_logo()
	resized.connect(_fit)
	_fit()
	_intro()
	_run_loading()


func _process(_delta: float) -> void:
	if not _loading:
		return
	_apply_bar()
	_apply_status()


func _style_logo() -> void:
	var logo: PanelContainer = $Scroll/Column/Content/Hero/LogoCenter/Logo
	var coin := StyleBoxFlat.new()
	coin.bg_color = UiTheme.COL_GOLD
	coin.set_corner_radius_all(28)
	logo.add_theme_stylebox_override("panel", coin)
	var mark: Label = logo.get_node("LogoMark")
	mark.add_theme_font_size_override("font_size", 40)
	mark.add_theme_color_override("font_color", UiTheme.COL_INK)


func _intro() -> void:
	var hero: Control = %Hero
	await get_tree().process_frame
	if not is_inside_tree():
		return
	hero.pivot_offset = hero.size * 0.5
	hero.scale = Vector2(0.86, 0.86)
	hero.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hero, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hero, "modulate:a", 1.0, 0.4)


func _run_loading() -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_loading = false
	_set_progress(1.0)
	_apply_bar()
	_apply_status()
	await get_tree().create_timer(0.4).timeout
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
	if _progress < 0.22:
		%StatusLabel.text = "Initialize game"
	elif _progress < 0.62:
		%StatusLabel.text = "Load resources"
	elif _progress < 1.0:
		%StatusLabel.text = "Prepare games"
	else:
		%StatusLabel.text = "Ready"


func _fit() -> void:
	ScreenLayout.fit_column(_column, 520.0)
	_apply_bar()
