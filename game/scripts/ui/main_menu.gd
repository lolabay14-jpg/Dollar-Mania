extends Control

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.style_title(%Title, 36)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Tagline)
	%Tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%PlayButton.theme_type_variation = "PrimaryButton"
	%PlayButton.pressed.connect(_on_play)
	%SlotsButton.pressed.connect(AppState.go_slots)
	%PlayerButton.pressed.connect(AppState.go_player)
	%AdminButton.pressed.connect(AppState.go_admin)
	%SettingsButton.pressed.connect(AppState.go_settings)
	CreditService.state_changed.connect(_refresh_profile)
	resized.connect(_fit)
	_fit()
	_refresh_profile()
	UiMotion.fade_in(%Column)
	UiMotion.bind_tree(self)
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
