extends Control

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "lobby")
	UiTheme.style_title(%Title, 40)
	%Title.text = "DOLLAR MANIA"
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Tagline)
	%Tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%CreditsLabel.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	%PlayButton.theme_type_variation = "PrimaryButton"
	%PlayButton.custom_minimum_size = Vector2(0, 60)
	%PlayButton.text = "Play"
	var avatar: PanelContainer = $Scroll/Column/Content/Profile/Avatar
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color("2A2412")
	chip.border_color = UiTheme.COL_GOLD
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(26)
	chip.content_margin_left = 6
	chip.content_margin_right = 6
	chip.content_margin_top = 8
	chip.content_margin_bottom = 8
	avatar.add_theme_stylebox_override("panel", chip)
	%PlayButton.pressed.connect(_on_play)
	%SlotsButton.pressed.connect(AppState.go_slots)
	%PlayerButton.pressed.connect(AppState.go_player)
	%AdminButton.pressed.connect(AppState.go_admin)
	%SettingsButton.pressed.connect(AppState.go_settings)
	CreditService.state_changed.connect(_refresh_profile)
	resized.connect(_fit)
	_fit()
	_refresh_profile()
	UiMotion.bind_tree(self)
	UiMotion.enter(%Column, 0)
	%PlayButton.grab_focus()


func _refresh_profile() -> void:
	var player := CreditService.get_active_player()
	%PlayerName.text = str(player.get("name", "Player"))
	%CreditsLabel.text = "%d credits" % int(player.get("credits", 0))
	%AvatarLabel.text = _initials(str(player.get("name", "A")))


func _on_play() -> void:
	AppState.selected_slot_id = "lucky-dollar"
	AppState.selected_game = {
		"slug": "lucky-dollar",
		"name": "Lucky Dollar",
		"difficulty": "EASY",
		"description": "Three reels and one payline.",
		"min_bet": 1,
		"max_bet": 100,
	}
	AppState.go_machine()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 480.0)


func _initials(player_name: String) -> String:
	var parts := player_name.split(" ", false)
	if parts.is_empty():
		return "DM"
	if parts.size() == 1:
		return str(parts[0]).substr(0, 1).to_upper()
	return (str(parts[0]).substr(0, 1) + str(parts[1]).substr(0, 1)).to_upper()
