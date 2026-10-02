extends Control

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.style_title(%Title, 32)
	UiTheme.style_muted(%Tag)
	UiTheme.style_muted(%LevelCaption)
	%NameLabel.add_theme_font_size_override("font_size", 26)
	%CreditsLabel.add_theme_font_size_override("font_size", 34)
	%CreditsLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	%BackButton.text = "Log out"
	%BackButton.pressed.connect(_logout)
	%PlayButton.text = "Games"
	%PlayButton.theme_type_variation = "PrimaryButton"
	%PlayButton.pressed.connect(AppState.go_slots)
	resized.connect(_fit)
	_style_bar()
	_fit()
	_load()
	UiMotion.fade_in(%Column)
	UiMotion.bind_tree(self)


func _logout() -> void:
	ApiClient.logout()
	AppState.go_login()


func _style_bar() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0E1626")
	background.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.COL_GOLD
	fill.set_corner_radius_all(8)
	%LevelBar.add_theme_stylebox_override("background", background)
	%LevelBar.add_theme_stylebox_override("fill", fill)
	%LevelBar.max_value = 1.0
	%LevelBar.show_percentage = false


func _fit() -> void:
	ScreenLayout.fit_column(_column, 520.0)


func _load() -> void:
	var profile_response: Dictionary = await ApiClient.get_player_profile()
	if not is_inside_tree():
		return
	if not profile_response.ok:
		%Tag.text = str(profile_response.error)
		return
	var profile: Dictionary = profile_response.data.get("profile", {})
	var wallet_response: Dictionary = await ApiClient.get_wallet()
	if not is_inside_tree():
		return
	var balance := int(profile.get("credits", 0))
	if wallet_response.ok:
		balance = int(wallet_response.data.get("balance", balance))
	var player_name := str(profile.get("displayName", profile.get("username", "Player")))
	%AvatarLabel.text = _initials(player_name)
	%NameLabel.text = player_name
	%Tag.text = str(profile.get("username", "Player"))
	%CreditsLabel.text = "%d" % balance
	%SpinsLabel.text = "Total spins\n%d" % int(profile.get("spins", 0))
	%WinsLabel.text = "Total wins\n%d" % int(profile.get("wins", 0))
	%LossesLabel.text = "Total losses\n%d" % int(profile.get("losses", 0))
	var level := int(profile.get("level", 1))
	var experience := int(profile.get("experience", 0))
	%LevelCaption.text = "Level %d" % level
	%LevelBar.value = float(experience % GameConfig.SPINS_PER_LEVEL) / float(GameConfig.SPINS_PER_LEVEL)
	var history_response: Dictionary = await ApiClient.get_spin_history()
	if not is_inside_tree():
		return
	if history_response.ok:
		_fill_history(history_response.data.get("spins", []))
	else:
		%Tag.text = str(history_response.error)


func _fill_history(history: Array) -> void:
	var box: VBoxContainer = %HistoryBox
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	if history.is_empty():
		var empty := Label.new()
		empty.text = "No spins yet. Play Lucky Dollar and the results will show up here."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(empty)
		box.add_child(empty)
		return
	for entry in history:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s   %s   Bet %d   Win %d" % [
			_short_time(str(entry.get("createdAt", ""))),
			str(entry.get("gameName", "")),
			int(entry.get("betAmount", entry.get("bet", 0))),
			int(entry.get("winAmount", entry.get("payout", 0))),
		]
		box.add_child(row)


func _short_time(value: String) -> String:
	if value.contains("T"):
		return value.split("T")[1].substr(0, 8)
	return value


func _initials(player_name: String) -> String:
	var parts := player_name.split(" ", false)
	if parts.size() >= 2:
		return (str(parts[0]).substr(0, 1) + str(parts[1]).substr(0, 1)).to_upper()
	if parts.is_empty():
		return "DM"
	return str(parts[0]).substr(0, 1).to_upper()
