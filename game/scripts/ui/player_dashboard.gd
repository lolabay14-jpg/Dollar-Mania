extends Control

var _games: Array = []
var _filter := "ALL"
var _filters: HFlowContainer
var _game_list: GridContainer
var _feature_card: GameCard
var _feature_index := 0
var _feature_timer: Timer
var _feature_paused := false
var _opening := false
var _header_user: Label
var _header_wallet: Label
var _games_title: Label

@onready var _column: MarginContainer = %Column
@onready var _spins_label: Label = %SpinsLabel
@onready var _wins_label: Label = %WinsLabel
@onready var _losses_label: Label = %LossesLabel


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "lobby")
	UiTheme.style_title(%Title, 32)
	%Title.text = "Dollar Mania"
	var profile := $Scroll/Column/Content/ProfileCard as PanelContainer
	UiTheme.paint_glass(profile)
	UiTheme.style_muted(%Tag)
	UiTheme.style_muted(%LevelCaption)
	%NameLabel.add_theme_font_size_override("font_size", 26)
	UiTheme.paint_card($Scroll/Column/Content/BalanceCard as PanelContainer, UiTheme.COL_GOLD)
	%CreditsLabel.add_theme_font_size_override("font_size", 28)
	%CreditsLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	var header := $Scroll/Column/Content/Header as HBoxContainer
	var profile_button := Button.new()
	profile_button.text = "Profile"
	profile_button.custom_minimum_size = Vector2(112, 48)
	profile_button.pressed.connect(_show_profile)
	header.add_child(profile_button)
	header.move_child(profile_button, %BackButton.get_index())
	var brand := VBoxContainer.new()
	brand.name = "Brand"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 0)
	header.add_child(brand)
	header.move_child(brand, 0)
	%Title.reparent(brand)
	_header_user = Label.new()
	_header_user.text = "Player"
	UiTheme.style_muted(_header_user)
	brand.add_child(_header_user)
	_header_wallet = Label.new()
	_header_wallet.text = "💰 —"
	_header_wallet.add_theme_font_size_override("font_size", 22)
	_header_wallet.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	header.add_child(_header_wallet)
	header.move_child(_header_wallet, profile_button.get_index())
	var content := $Scroll/Column/Content
	var bar := PanelContainer.new()
	bar.name = "HeaderBar"
	UiTheme.paint_glass(bar)
	content.add_child(bar)
	content.move_child(bar, 0)
	header.reparent(bar)
	UiTheme.style_muted($Scroll/Column/Content/BalanceCard/BalanceBox/CreditsCaption)
	var request_status := Label.new()
	request_status.name = "RequestStatus"
	request_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(request_status)
	%CreditsLabel.get_parent().add_child(request_status)
	%BackButton.text = "Logout"
	%BackButton.pressed.connect(_logout)
	%PlayButton.text = "Game library"
	%PlayButton.theme_type_variation = "PrimaryButton"
	%PlayButton.pressed.connect(AppState.go_slots)
	var history_title := $Scroll/Column/Content/HistoryTitle as Label
	history_title.text = "Recent games"
	UiTheme.style_title(history_title, 22)
	_mount_lobby()
	resized.connect(_fit)
	_style_bar()
	_style_stats()
	_fit()
	_load()
	UiMotion.bind_tree(self)
	UiMotion.enter(%Column, 0)


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
	ScreenLayout.fit_column(_column, 1180.0)
	if _game_list:
		var columns := 1
		if size.x >= 1100.0:
			columns = 3
		elif size.x >= 720.0:
			columns = 2
		_game_list.columns = columns


func _load() -> void:
	var profile_response: Dictionary = await ApiClient.get_player_profile()
	if not is_inside_tree():
		return
	var wallet_response: Dictionary = await ApiClient.get_wallet()
	if not is_inside_tree():
		return
	if not profile_response.ok:
		%Tag.text = "Could not load your profile."
		push_error("Player profile failed. HTTP %d. %s" % [int(profile_response.get("status", 0)), str(profile_response.get("error", ""))])
		if wallet_response.ok:
			var fallback := int(wallet_response.data.get("balance", 0))
			var credits_text := "💰 %d Credits" % fallback
			%CreditsLabel.text = credits_text
			if _header_wallet:
				_header_wallet.text = credits_text
	else:
		_apply_profile(profile_response, wallet_response)
	var requests_response: Dictionary = await ApiClient.my_credit_requests()
	if is_inside_tree() and requests_response.ok:
		var requests: Array = requests_response.data.get("requests", [])
		var status_label := %CreditsLabel.get_parent().get_node_or_null("RequestStatus") as Label
		if status_label and not requests.is_empty() and requests[0] is Dictionary:
			var latest: Dictionary = requests[0]
			status_label.text = "Credit request: %s  ·  %s" % [str(latest.get("status", "")), str(int(latest.get("amount", 0)))]
	var history_response: Dictionary = await ApiClient.get_spin_history()
	if not is_inside_tree():
		return
	if history_response.ok:
		_fill_history(history_response.data.get("spins", []))
	else:
		push_error("Spin history failed. HTTP %d. %s" % [int(history_response.get("status", 0)), str(history_response.get("error", ""))])
	var games_response: Dictionary = await ApiClient.reload_slot_games()
	if not is_inside_tree():
		return
	if games_response.ok:
		var games_value: Variant = games_response.data.get("games", [])
		_games = games_value if games_value is Array else []
		_render_filters()
		_render_feature()
		_render_games()
	elif _game_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Games could not be loaded."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(empty)
		_game_list.add_child(empty)
		var retry := Button.new()
		retry.text = "Try again"
		retry.theme_type_variation = "PrimaryButton"
		retry.custom_minimum_size = Vector2(0, 48)
		retry.pressed.connect(_load)
		_game_list.add_child(retry)
		push_error("Game list failed. HTTP %d. %s" % [int(games_response.get("status", 0)), str(games_response.get("error", ""))])


func _apply_profile(profile_response: Dictionary, wallet_response: Dictionary) -> void:
	var profile_value: Variant = profile_response.data.get("profile", {})
	if not profile_value is Dictionary:
		%Tag.text = "Could not load your profile."
		return
	var profile: Dictionary = profile_value
	var balance := int(profile.get("credits", 0))
	if wallet_response.ok:
		balance = int(wallet_response.data.get("balance", balance))
	var player_name := str(profile.get("displayName", profile.get("username", "Player")))
	%AvatarLabel.text = _initials(player_name)
	%NameLabel.text = player_name
	%Tag.text = str(profile.get("username", "Player"))
	if _header_user:
		_header_user.text = player_name
	var credits_text := "💰 %d Credits" % balance
	%CreditsLabel.text = credits_text
	if _header_wallet:
		_header_wallet.text = credits_text
	_spins_label.text = "%d\nSpins" % int(profile.get("spins", 0))
	_wins_label.text = "%d\nWins" % int(profile.get("wins", 0))
	_losses_label.text = "%d\nLosses" % int(profile.get("losses", 0))
	var level := int(profile.get("level", 1))
	var experience := int(profile.get("experience", 0))
	%LevelCaption.text = "Level %d" % level
	%LevelBar.value = float(experience % GameConfig.SPINS_PER_LEVEL) / float(GameConfig.SPINS_PER_LEVEL)


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


func _mount_lobby() -> void:
	var content := $Scroll/Column/Content
	var history := content.get_node("HistoryTitle")
	var profile_title := Label.new()
	profile_title.text = "Profile"
	UiTheme.style_title(profile_title, 22)
	content.add_child(profile_title)
	content.move_child(profile_title, content.get_node("ProfileCard").get_index())
	var feature_title := Label.new()
	feature_title.text = "Featured"
	UiTheme.style_title(feature_title, 22)
	content.add_child(feature_title)
	content.move_child(feature_title, history.get_index())
	_feature_card = GameCard.new()
	_feature_card.visible = false
	_feature_card.play_pressed.connect(_open_game)
	_feature_card.mouse_entered.connect(func() -> void: _feature_paused = true)
	_feature_card.mouse_exited.connect(func() -> void: _feature_paused = false)
	content.add_child(_feature_card)
	content.move_child(_feature_card, history.get_index())
	_feature_timer = Timer.new()
	_feature_timer.wait_time = 6.0
	_feature_timer.autostart = true
	_feature_timer.timeout.connect(_advance_feature)
	add_child(_feature_timer)
	var category_title := Label.new()
	category_title.text = "Categories"
	UiTheme.style_title(category_title, 22)
	content.add_child(category_title)
	content.move_child(category_title, history.get_index())
	_filters = HFlowContainer.new()
	_filters.add_theme_constant_override("h_separation", 8)
	_filters.add_theme_constant_override("v_separation", 8)
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_filters)
	content.move_child(_filters, history.get_index())
	_games_title = Label.new()
	_games_title.text = "Games"
	UiTheme.style_title(_games_title, 22)
	content.add_child(_games_title)
	content.move_child(_games_title, history.get_index())
	_game_list = GridContainer.new()
	_game_list.columns = 1
	_game_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_list.add_theme_constant_override("h_separation", 16)
	_game_list.add_theme_constant_override("v_separation", 16)
	content.add_child(_game_list)
	content.move_child(_game_list, history.get_index())


func _render_filters() -> void:
	for child in _filters.get_children():
		_filters.remove_child(child)
		child.free()
	for item in [["ALL", "All"], ["SPIN", "Spin"], ["SLOTS", "Slots"], ["ARCADE", "Arcade"], ["CARDS", "Cards"], ["SPECIAL", "Special"]]:
		var button := Button.new()
		button.text = str(item[1])
		button.set_meta("category", str(item[0]))
		button.toggle_mode = true
		button.set_pressed_no_signal(str(item[0]) == _filter)
		button.custom_minimum_size = Vector2(96, 48)
		button.theme_type_variation = "SelectedButton" if str(item[0]) == _filter else "Button"
		button.pressed.connect(_set_filter.bind(str(item[0])))
		_filters.add_child(button)
	UiMotion.bind_tree(_filters)


func _set_filter(category: String) -> void:
	_filter = category
	for child in _filters.get_children():
		if not child is Button:
			continue
		var button := child as Button
		var selected := str(button.get_meta("category", "")) == category
		button.set_pressed_no_signal(selected)
		button.theme_type_variation = "SelectedButton" if selected else "Button"
		if selected:
			UiMotion.pulse_selected(button)
	_render_games()
	if _game_list:
		UiMotion.fade_in(_game_list)


func _render_games() -> void:
	for child in _game_list.get_children():
		_game_list.remove_child(child)
		child.free()
	if _games_title:
		_games_title.text = "Games  ·  %d" % _games.size()
	var shown := 0
	for game in _games:
		if not game is Dictionary:
			continue
		if _filter in ["SPIN", "SLOTS", "ARCADE", "CARDS", "SPECIAL"] and GameCard.group_of(game) != _filter:
			continue
		var card := GameCard.new()
		card.configure(game)
		card.play_pressed.connect(_open_game)
		UiMotion.bind_tree(card)
		card.modulate.a = 0.0
		_game_list.add_child(card)
		var tween := card.create_tween()
		tween.tween_interval(minf(float(shown) * 0.04, 0.24))
		tween.tween_property(card, "modulate:a", 1.0, 0.22)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "No games are available in this category."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(empty)
		_game_list.add_child(empty)


func _style_stats() -> void:
	var stats := $Scroll/Column/Content/Stats as HBoxContainer
	stats.add_theme_constant_override("separation", 10)
	var labels: Array[Label] = [_spins_label, _wins_label, _losses_label]
	for label in labels:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(96, 96)
		UiTheme.paint_card(card, UiTheme.COL_GOLD)
		var parent: Node = label.get_parent()
		var index: int = label.get_index()
		parent.remove_child(label)
		card.add_child(label)
		parent.add_child(card)
		parent.move_child(card, index)


func _show_profile() -> void:
	var scroll := $Scroll as ScrollContainer
	var profile := $Scroll/Column/Content/ProfileCard as Control
	var target := profile.global_position.y - scroll.global_position.y + float(scroll.scroll_vertical)
	scroll.scroll_vertical = int(maxf(target - 12.0, 0.0))


func _render_feature() -> void:
	if _feature_card == null or _games.is_empty():
		if _feature_card:
			_feature_card.visible = false
		return
	_feature_index = clampi(_feature_index, 0, _games.size() - 1)
	var game_value: Variant = _games[_feature_index]
	if not game_value is Dictionary:
		_feature_card.visible = false
		return
	var game: Dictionary = game_value
	_feature_card.visible = true
	_feature_card.configure(game, true)
	_feature_card.modulate.a = 1.0


func _advance_feature() -> void:
	if _feature_paused or _opening or _games.size() < 2 or _feature_card == null or not _feature_card.visible:
		return
	_feature_index = (_feature_index + 1) % _games.size()
	var tween := _feature_card.create_tween()
	tween.tween_property(_feature_card, "modulate:a", 0.0, 0.18)
	await tween.finished
	if not is_inside_tree() or _opening:
		return
	_render_feature()
	_feature_card.modulate.a = 0.0
	var fade := _feature_card.create_tween()
	fade.tween_property(_feature_card, "modulate:a", 1.0, 0.22)


func _open_game(game: Dictionary) -> void:
	if _opening:
		return
	_opening = true
	AppState.selected_game = {
		"id": str(game.get("id", "")),
		"slug": str(game.get("slug", "")),
		"name": str(game.get("name", "")),
		"category": str(game.get("category", "")),
		"description": str(game.get("description", "")),
		"min_bet": int(game.get("minimumBet", 1)),
		"max_bet": int(game.get("maximumBet", 1)),
	}
	AppState.selected_slot_id = str(game.get("slug", ""))
	AppState.go_machine()


func _initials(player_name: String) -> String:
	var parts := player_name.split(" ", false)
	if parts.size() >= 2:
		return (str(parts[0]).substr(0, 1) + str(parts[1]).substr(0, 1)).to_upper()
	if parts.is_empty():
		return "DM"
	return str(parts[0]).substr(0, 1).to_upper()
