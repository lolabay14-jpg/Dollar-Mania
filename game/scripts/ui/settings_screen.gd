extends Control

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "calm")
	UiTheme.style_title(%Title, 32)
	UiTheme.style_muted(%Hint)
	%BackButton.pressed.connect(AppState.go_main)
	%SoundCheck.custom_minimum_size.y = 48
	%MusicCheck.custom_minimum_size.y = 48
	%SoundCheck.button_pressed = AppState.sound_enabled
	%MusicCheck.button_pressed = AppState.music_enabled
	%SoundCheck.toggled.connect(func(on: bool) -> void: AppState.sound_enabled = on)
	%MusicCheck.toggled.connect(func(on: bool) -> void: AppState.music_enabled = on)
	resized.connect(_fit)
	_fit()
	UiMotion.bind_tree(self)
	UiMotion.enter(%Column, 0)


func _fit() -> void:
	ScreenLayout.fit_column(_column, 480.0)
