extends Control

@onready var _column: MarginContainer = %Column
@onready var _logo: PanelContainer = %Logo
@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _player_line: Label = %PlayerLine
@onready var _play_button: Button = %PlayButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	UiTheme.apply(self)
	_style()
	_play_button.pressed.connect(_on_play)
	%PlayerButton.pressed.connect(AppState.go_player)
	%AdminButton.pressed.connect(AppState.go_admin)
	resized.connect(_fit)
	_fit()
	_refresh()
	_play_button.grab_focus()


func _style() -> void:
	$Background.color = UiTheme.COL_BG
	_play_button.theme_type_variation = "PrimaryButton"
	UiTheme.style_title(_title, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(_tagline)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(_player_line)
	_player_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(_status_label)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Footer)

	var mark := StyleBoxFlat.new()
	mark.bg_color = UiTheme.COL_GOLD
	mark.set_corner_radius_all(36)
	_logo.add_theme_stylebox_override("panel", mark)
	_logo.custom_minimum_size = Vector2(76, 76)
	%LogoMark.add_theme_font_size_override("font_size", 36)
	%LogoMark.add_theme_color_override("font_color", UiTheme.COL_INK)
	%LogoMark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%LogoMark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	%LogoMark.custom_minimum_size = Vector2(76, 76)


func _fit() -> void:
	ScreenLayout.fit_column(_column, 460.0)


func _refresh() -> void:
	var player := CreditService.get_active_player()
	var balance := int(player.get("credits", 0))
	_player_line.text = "%s  ·  %d credits" % [str(player.get("name", "Player")), balance]
	_play_button.text = "Play"
	if CreditService.can_afford_game(CreditService.get_active_player_id()):
		_status_label.text = "A round costs %d credits." % GameConfig.GAME_CREDIT_COST
		_status_label.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	else:
		_status_label.text = "Not enough credits. A game costs %d credits." % GameConfig.GAME_CREDIT_COST
		_status_label.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _on_play() -> void:
	var error := AppState.try_start_game()
	if error != "":
		_status_label.text = error
		_status_label.add_theme_color_override("font_color", UiTheme.COL_DANGER)
