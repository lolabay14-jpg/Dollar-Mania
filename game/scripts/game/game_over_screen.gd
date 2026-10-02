extends Control

@onready var _column: MarginContainer = %Column
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	%PlayAgainButton.theme_type_variation = "PrimaryButton"
	UiTheme.style_title(%Title, 36)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%ScoreLabel.add_theme_font_size_override("font_size", 28)
	%ScoreLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label in [%UsedLabel, %RemainingLabel, _status_label]:
		UiTheme.style_muted(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%ScoreLabel.text = "Score  %d" % AppState.last_score
	%UsedLabel.text = "Credits used  %d" % AppState.last_credits_used
	%RemainingLabel.text = "Remaining  %d" % AppState.last_remaining_credits
	%PlayAgainButton.pressed.connect(_on_play_again)
	%MenuButton.pressed.connect(AppState.go_start)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 460.0)


func _on_play_again() -> void:
	var error := AppState.try_start_game()
	if error != "":
		_status_label.text = error
		_status_label.add_theme_color_override("font_color", UiTheme.COL_DANGER)
