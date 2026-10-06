extends Control

var _games: Array = []
var _filter := "ALL"
var _tab := "games"
var _profile_sub := "account"
var _filters: HBoxContainer
var _filter_scroller: ScrollContainer
var _game_list: VBoxContainer
var _carousel: GameCarousel
var _opening := false
var _header_user: Label
var _games_title: Label
var _cat_dragging := false
var _cat_axis_locked := false
var _cat_horizontal := false
var _cat_drag_from := Vector2.ZERO
var _cat_scroll_from := 0
var _cat_page_scroll := 0
var _main_tabs: HBoxContainer
var _games_panel: VBoxContainer
var _credits_panel: VBoxContainer
var _profile_panel: VBoxContainer
var _account_panel: VBoxContainer
var _security_panel: VBoxContainer
var _profile_sub_tabs: HBoxContainer
var _credits_balance_label: Label
var _request_status_label: Label
var _request_history: VBoxContainer
var _request_amount: LineEdit
var _request_note: LineEdit
var _request_feedback: Label
var _request_busy := false
var _balance := 0
var _pw_current: LineEdit
var _pw_new: LineEdit
var _pw_confirm: LineEdit
var _pw_feedback: Label
var _pw_busy := false

@onready var _column: MarginContainer = %Column
@onready var _spins_label: Label = %SpinsLabel
@onready var _wins_label: Label = %WinsLabel
@onready var _losses_label: Label = %LossesLabel


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	# Soft atmosphere only — mute sharp promotional text so cards own the lobby.
	ArcadeBackdrop.mount_photo(self, GameArt.screen_path("dashboard"), 0.62, 0.12)
	UiTheme.mood(self, "lobby")
	UiTheme.style_title(%Title, 32)
	%Title.text = "Dollar Mania"
	var profile := $Scroll/Column/Content/ProfileCard as PanelContainer
	UiTheme.paint_glass(profile)
	UiTheme.style_muted(%Tag)
	UiTheme.style_muted(%LevelCaption)
	%NameLabel.add_theme_font_size_override("font_size", 26)
	_style_wallet()
	var header := $Scroll/Column/Content/Header as HBoxContainer
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
	var content := $Scroll/Column/Content
	var bar := PanelContainer.new()
	bar.name = "HeaderBar"
	UiTheme.paint_glass(bar)
	content.add_child(bar)
	content.move_child(bar, 0)
	header.reparent(bar)
	%BackButton.text = "Logout"
	%BackButton.pressed.connect(_logout)
	%PlayButton.visible = false
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
	var page := $Scroll as ScrollContainer
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ScreenLayout.fit_column(_column, 1180.0)
	_fit_credit_number()


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
			_set_credit_number(int(wallet_response.data.get("balance", 0)))
	else:
		_apply_profile(profile_response, wallet_response)
	var requests_response: Dictionary = await ApiClient.my_credit_requests()
	if is_inside_tree() and requests_response.ok:
		var requests: Array = requests_response.data.get("requests", [])
		_apply_request_status(requests)
		_fill_request_history(requests)
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
		if _games.is_empty():
			push_warning("Player lobby received 0 games from API.")
		_render_filters()
		_render_games()
	elif _game_list != null and _game_list.get_child_count() == 0:
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
	_set_credit_number(balance)
	_spins_label.text = "%d\nSpins" % int(profile.get("spins", 0))
	_wins_label.text = "%d\nWins" % int(profile.get("wins", 0))
	_losses_label.text = "%d\nLosses" % int(profile.get("losses", 0))
	var level := int(profile.get("level", 1))
	var experience := int(profile.get("experience", 0))
	%LevelCaption.text = "Level %d" % level
	%LevelBar.value = float(experience % GameConfig.SPINS_PER_LEVEL) / float(GameConfig.SPINS_PER_LEVEL)


func _apply_request_status(requests: Array) -> void:
	var text := "No credit requests yet."
	if not requests.is_empty() and requests[0] is Dictionary:
		var latest: Dictionary = requests[0]
		text = "Latest: %s  ·  %s credits" % [str(latest.get("status", "")), str(int(latest.get("amount", 0)))]
	var wallet_status: Label = null
	if _games_panel:
		var balance := _games_panel.get_node_or_null("BalanceCard/BalanceBox/RequestStatus") as Label
		wallet_status = balance
	if wallet_status == null:
		wallet_status = get_node_or_null("Scroll/Column/Content/BalanceCard/BalanceBox/RequestStatus") as Label
	if wallet_status:
		wallet_status.text = text
	if _request_status_label:
		_request_status_label.text = text


func _fill_history(history: Array) -> void:
	var box: VBoxContainer = %HistoryBox
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	if history.is_empty():
		var empty := Label.new()
		empty.text = "No spins yet. Play a game and results will show up here."
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
	_main_tabs = HBoxContainer.new()
	_main_tabs.name = "MainTabs"
	_main_tabs.add_theme_constant_override("separation", 0)
	_main_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_main_tabs)
	content.move_child(_main_tabs, content.get_node("BalanceCard").get_index() + 1)
	_build_main_tabs()

	_games_panel = VBoxContainer.new()
	_games_panel.name = "GamesPanel"
	_games_panel.add_theme_constant_override("separation", 12)
	_games_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_games_panel)

	_credits_panel = VBoxContainer.new()
	_credits_panel.name = "CreditsPanel"
	_credits_panel.add_theme_constant_override("separation", 12)
	_credits_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_credits_panel)

	_profile_panel = VBoxContainer.new()
	_profile_panel.name = "ProfilePanel"
	_profile_panel.add_theme_constant_override("separation", 12)
	_profile_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_profile_panel)

	# Games tab content
	var balance := content.get_node("BalanceCard") as Control
	balance.reparent(_games_panel)
	_mount_hero_banner(_games_panel)
	_games_title = Label.new()
	_games_title.text = "Games"
	UiTheme.style_title(_games_title, 28)
	_games_panel.add_child(_games_title)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 0)
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_games_panel.add_child(_filters)
	_game_list = VBoxContainer.new()
	_game_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_game_list.clip_contents = true
	_game_list.add_theme_constant_override("separation", 12)
	_games_panel.add_child(_game_list)
	_games_panel.clip_contents = false
	_filters.clip_contents = true
	var history_title := content.get_node("HistoryTitle") as Control
	var history_box := content.get_node("HistoryBox") as Control
	history_title.reparent(_games_panel)
	history_box.reparent(_games_panel)

	# Credit Requests tab
	_build_credits_tab()

	# Profile tab
	_build_profile_tab()

	# Hide leftover scene nodes that now live in Profile
	%PlayButton.visible = false
	_show_tab("games")


func _build_main_tabs() -> void:
	for child in _main_tabs.get_children():
		_main_tabs.remove_child(child)
		child.free()
	var shell := _tab_shell()
	_main_tabs.add_child(shell)
	var row := shell.get_child(0) as HBoxContainer
	for item in [["games", "Games"], ["credits", "Credit Requests"], ["profile", "Profile"]]:
		var button := Button.new()
		button.text = str(item[1])
		button.set_meta("tab", str(item[0]))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tab_button(button, str(item[0]) == _tab)
		button.pressed.connect(_show_tab.bind(str(item[0])))
		row.add_child(button)


func _tab_shell() -> PanelContainer:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.94)
	style.border_color = Color(UiTheme.COL_GOLD, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	shell.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(row)
	return shell


func _style_tab_button(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	if selected:
		normal.bg_color = Color(0.22, 0.16, 0.06, 0.98)
		normal.border_color = Color(UiTheme.COL_GOLD, 0.95)
		normal.set_border_width_all(1)
		normal.shadow_color = Color(UiTheme.COL_GOLD, 0.35)
		normal.shadow_size = 8
		button.add_theme_color_override("font_color", Color("FFF4D0"))
	else:
		normal.bg_color = Color(0.08, 0.1, 0.16, 0.0)
		normal.set_border_width_all(0)
		button.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 0.85))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.14, 0.08, 0.75) if selected else Color(0.12, 0.14, 0.2, 0.55)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_font_size_override("font_size", 14)
	button.set_pressed_no_signal(selected)


func _show_tab(tab: String) -> void:
	_tab = tab
	_refresh_main_tab_styles()
	if _games_panel:
		_games_panel.visible = tab == "games"
	if _credits_panel:
		_credits_panel.visible = tab == "credits"
	if _profile_panel:
		_profile_panel.visible = tab == "profile"
	if tab == "profile":
		_show_profile_sub(_profile_sub)
	($Scroll as ScrollContainer).scroll_vertical = 0
	var active: Control = _games_panel if tab == "games" else (_credits_panel if tab == "credits" else _profile_panel)
	if active:
		UiMotion.fade_in(active)


func _refresh_main_tab_styles() -> void:
	if _main_tabs == null or _main_tabs.get_child_count() == 0:
		return
	var shell := _main_tabs.get_child(0)
	if shell.get_child_count() == 0:
		return
	var row := shell.get_child(0)
	for child in row.get_children():
		if child is Button and (child as Button).has_meta("tab"):
			var button := child as Button
			_style_tab_button(button, str(button.get_meta("tab")) == _tab)


func _build_credits_tab() -> void:
	var card := PanelContainer.new()
	card.name = "RequestCard"
	UiTheme.paint_glass(card)
	_credits_panel.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(_inset(box, 16))
	var title := Label.new()
	title.text = "Credit Requests"
	UiTheme.style_title(title, 22)
	box.add_child(title)
	var copy := Label.new()
	copy.text = "Request virtual credits from an admin. You cannot change your own balance."
	UiTheme.style_muted(copy)
	box.add_child(copy)
	_credits_balance_label = Label.new()
	_credits_balance_label.text = "Current Credits: 0"
	_credits_balance_label.add_theme_font_size_override("font_size", 20)
	_credits_balance_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	box.add_child(_credits_balance_label)
	_request_status_label = Label.new()
	_request_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_request_status_label)
	box.add_child(_request_status_label)
	_request_amount = LineEdit.new()
	_request_amount.placeholder_text = "Requested Amount"
	_request_amount.custom_minimum_size = Vector2(0, 48)
	box.add_child(_request_amount)
	_request_note = LineEdit.new()
	_request_note.placeholder_text = "Optional Note"
	_request_note.custom_minimum_size = Vector2(0, 48)
	box.add_child(_request_note)
	var send := Button.new()
	send.text = "Request Credits"
	send.theme_type_variation = "PrimaryButton"
	send.custom_minimum_size = Vector2(0, 48)
	send.pressed.connect(_submit_credit_request)
	box.add_child(send)
	_request_feedback = Label.new()
	_request_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_request_feedback)
	box.add_child(_request_feedback)
	var history_title := Label.new()
	history_title.text = "Request History · Pending / Approved / Rejected"
	history_title.add_theme_font_size_override("font_size", 16)
	history_title.add_theme_color_override("font_color", Color("E7C56A"))
	box.add_child(history_title)
	_request_history = VBoxContainer.new()
	_request_history.add_theme_constant_override("separation", 8)
	box.add_child(_request_history)


func _build_profile_tab() -> void:
	var content := $Scroll/Column/Content
	_profile_sub_tabs = HBoxContainer.new()
	_profile_sub_tabs.add_theme_constant_override("separation", 0)
	_profile_sub_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_panel.add_child(_profile_sub_tabs)
	var shell := _tab_shell()
	_profile_sub_tabs.add_child(shell)
	var row := shell.get_child(0) as HBoxContainer
	for item in [["account", "Account"], ["security", "Security"]]:
		var button := Button.new()
		button.text = str(item[1])
		button.set_meta("sub", str(item[0]))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tab_button(button, str(item[0]) == _profile_sub)
		button.pressed.connect(_show_profile_sub.bind(str(item[0])))
		row.add_child(button)

	_account_panel = VBoxContainer.new()
	_account_panel.add_theme_constant_override("separation", 12)
	_profile_panel.add_child(_account_panel)
	var profile := content.get_node("ProfileCard") as Control
	profile.reparent(_account_panel)
	var stats := content.get_node("Stats") as Control
	var level_caption := content.get_node("LevelCaption") as Control
	var level_bar := content.get_node("LevelBar") as Control
	stats.reparent(_account_panel)
	level_caption.reparent(_account_panel)
	level_bar.reparent(_account_panel)
	var logout := Button.new()
	logout.text = "Logout"
	logout.theme_type_variation = "DangerButton"
	logout.custom_minimum_size = Vector2(0, 48)
	logout.pressed.connect(_logout)
	_account_panel.add_child(logout)

	_security_panel = VBoxContainer.new()
	_security_panel.add_theme_constant_override("separation", 12)
	_profile_panel.add_child(_security_panel)
	var card := PanelContainer.new()
	card.name = "PasswordCard"
	UiTheme.paint_glass(card)
	_security_panel.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(_inset(box, 16))
	var title := Label.new()
	title.text = "Security"
	UiTheme.style_title(title, 20)
	box.add_child(title)
	var copy := Label.new()
	copy.text = "Change the password for your own account only."
	UiTheme.style_muted(copy)
	box.add_child(copy)
	_pw_current = LineEdit.new()
	_pw_current.placeholder_text = "Current Password"
	_pw_current.secret = true
	_pw_current.custom_minimum_size = Vector2(0, 48)
	box.add_child(_pw_current)
	_pw_new = LineEdit.new()
	_pw_new.placeholder_text = "New Password (min 4 characters)"
	_pw_new.secret = true
	_pw_new.custom_minimum_size = Vector2(0, 48)
	box.add_child(_pw_new)
	_pw_confirm = LineEdit.new()
	_pw_confirm.placeholder_text = "Confirm New Password"
	_pw_confirm.secret = true
	_pw_confirm.custom_minimum_size = Vector2(0, 48)
	box.add_child(_pw_confirm)
	var submit := Button.new()
	submit.text = "Change Password"
	submit.theme_type_variation = "PrimaryButton"
	submit.custom_minimum_size = Vector2(0, 48)
	submit.pressed.connect(_submit_password_change)
	box.add_child(submit)
	_pw_feedback = Label.new()
	_pw_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_pw_feedback)
	box.add_child(_pw_feedback)


func _show_profile_sub(sub: String) -> void:
	_profile_sub = sub
	if _profile_sub_tabs and _profile_sub_tabs.get_child_count() > 0:
		var shell := _profile_sub_tabs.get_child(0)
		if shell.get_child_count() > 0:
			for child in shell.get_child(0).get_children():
				if child is Button and (child as Button).has_meta("sub"):
					var button := child as Button
					_style_tab_button(button, str(button.get_meta("sub")) == sub)
	if _account_panel:
		_account_panel.visible = sub == "account"
	if _security_panel:
		_security_panel.visible = sub == "security"


func _render_filters() -> void:
	for child in _filters.get_children():
		_filters.remove_child(child)
		child.free()
	_filter_scroller = ScrollContainer.new()
	_filter_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_filter_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_filter_scroller.custom_minimum_size = Vector2(0, 64)
	_filter_scroller.clip_contents = true
	_filter_scroller.follow_focus = false
	_filter_scroller.mouse_filter = Control.MOUSE_FILTER_STOP
	_filters.add_child(_filter_scroller)
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.05, 0.07, 0.12, 0.9)
	shell_style.border_color = Color(0.45, 0.55, 0.75, 0.28)
	shell_style.set_border_width_all(1)
	shell_style.set_corner_radius_all(30)
	shell_style.content_margin_left = 8
	shell_style.content_margin_right = 8
	shell_style.content_margin_top = 8
	shell_style.content_margin_bottom = 8
	shell_style.shadow_color = Color(0, 0, 0, 0.35)
	shell_style.shadow_size = 12
	shell.add_theme_stylebox_override("panel", shell_style)
	_filter_scroller.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	shell.add_child(row)
	for item in [
		["ALL", "ALL"],
		["SLOTS", "SLOTS"],
		["SPIN", "SPIN & WHEEL"],
		["ARCADE", "ARCADE"],
		["ACTION", "ACTION & SKILL"],
		["CASUAL", "CASUAL"],
	]:
		var button := Button.new()
		button.text = str(item[1])
		button.set_meta("category", str(item[0]))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.set_pressed_no_signal(str(item[0]) == _filter)
		button.custom_minimum_size = Vector2(0, 48)
		_style_filter_button(button, str(item[0]) == _filter)
		button.pressed.connect(_set_filter.bind(str(item[0])))
		row.add_child(button)
	_filter_scroller.gui_input.connect(_on_category_input)
	UiMotion.bind_tree(_filters)


func _style_filter_button(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(22)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 11
	normal.content_margin_bottom = 11
	if selected:
		normal.bg_color = Color(0.2, 0.14, 0.05, 0.98)
		normal.border_color = Color(UiTheme.COL_GOLD, 0.95)
		normal.set_border_width_all(1)
		normal.shadow_color = Color(UiTheme.COL_GOLD, 0.45)
		normal.shadow_size = 14
		button.add_theme_color_override("font_color", Color("FFF4D0"))
		button.add_theme_color_override("font_hover_color", Color("FFF8E6"))
		button.add_theme_color_override("font_pressed_color", UiTheme.COL_GOLD)
	else:
		normal.bg_color = Color(0.1, 0.13, 0.2, 0.35)
		normal.border_color = Color(1, 1, 1, 0.06)
		normal.set_border_width_all(1)
		button.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94, 0.88))
		button.add_theme_color_override("font_hover_color", Color("FFF8E6"))
		button.add_theme_color_override("font_pressed_color", UiTheme.COL_GOLD_SOFT)
	var hover := normal.duplicate() as StyleBoxFlat
	if selected:
		hover.bg_color = Color(0.26, 0.18, 0.06, 1.0)
		hover.border_color = Color(UiTheme.COL_GOLD_SOFT, 1.0)
	else:
		hover.bg_color = Color(0.14, 0.18, 0.28, 0.72)
		hover.border_color = Color(UiTheme.COL_BLUE, 0.45)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.12, 0.05, 0.95) if selected else Color(0.12, 0.14, 0.22, 0.8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_font_size_override("font_size", 14)
	button.set_pressed_no_signal(selected)


func _on_category_input(event: InputEvent) -> void:
	if _filter_scroller == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_cat_dragging = true
			_cat_axis_locked = false
			_cat_horizontal = false
			_cat_drag_from = mouse.position
			_cat_scroll_from = _filter_scroller.scroll_horizontal
			var page := $Scroll as ScrollContainer
			_cat_page_scroll = page.scroll_vertical
		else:
			_cat_dragging = false
			_cat_axis_locked = false
		accept_event()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_cat_dragging = true
			_cat_axis_locked = false
			_cat_horizontal = false
			_cat_drag_from = touch.position
			_cat_scroll_from = _filter_scroller.scroll_horizontal
			_cat_page_scroll = ($Scroll as ScrollContainer).scroll_vertical
		else:
			_cat_dragging = false
			_cat_axis_locked = false
		accept_event()
		return
	if not _cat_dragging:
		return
	var pos := Vector2.ZERO
	var relative := Vector2.ZERO
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		pos = motion.position
		relative = motion.relative
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		pos = drag.position
		relative = drag.relative
	else:
		return
	if not _cat_axis_locked:
		if absf(relative.x) < 2.0 and absf(relative.y) < 2.0:
			return
		_cat_axis_locked = true
		_cat_horizontal = absf(relative.x) >= absf(relative.y) * 0.85
	if _cat_horizontal:
		var max_scroll := maxi(int(_filter_scroller.get_child(0).get_combined_minimum_size().x - _filter_scroller.size.x), 0)
		_filter_scroller.scroll_horizontal = clampi(int(_cat_scroll_from - (pos.x - _cat_drag_from.x)), 0, max_scroll)
		($Scroll as ScrollContainer).scroll_vertical = _cat_page_scroll
		accept_event()
		get_viewport().set_input_as_handled()


func _set_filter(category: String) -> void:
	_filter = category
	_style_filter_tree(_filters, category)
	_render_games()
	if _game_list:
		UiMotion.fade_in(_game_list)


func _style_filter_tree(node: Node, category: String) -> void:
	for child in node.get_children():
		if child is Button and (child as Button).has_meta("category"):
			var button := child as Button
			var selected := str(button.get_meta("category", "")) == category
			button.set_pressed_no_signal(selected)
			_style_filter_button(button, selected)
			if selected:
				UiMotion.pulse_selected(button)
		else:
			_style_filter_tree(child, category)


func _render_games() -> void:
	if _games_title:
		_games_title.text = "Games"
	var games := _filtered_games()
	for child in _game_list.get_children():
		if child == _carousel:
			continue
		_game_list.remove_child(child)
		child.free()
	if games.is_empty():
		if _carousel != null and is_instance_valid(_carousel):
			_game_list.remove_child(_carousel)
			_carousel.free()
			_carousel = null
		var empty := Label.new()
		empty.text = "No games are available in this category." if not _games.is_empty() else "No games loaded yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(empty)
		_game_list.add_child(empty)
		return
	if _carousel == null or not is_instance_valid(_carousel):
		_carousel = GameCarousel.new()
		_game_list.add_child(_carousel)
		if not _carousel.play_pressed.is_connected(_open_game):
			_carousel.play_pressed.connect(_open_game)
	_carousel.setup(games, _lobby_card_size(), "Game Library", _filter_subtitle())


func _filter_subtitle() -> String:
	match _filter:
		"SLOTS":
			return "Classic spin games"
		"SPIN":
			return "Spin-based arcade games"
		"ARCADE":
			return "Fast arcade games"
		"ACTION":
			return "Skill and reaction games"
		"CASUAL":
			return "Quick pick-up games"
		_:
			return "Swipe to browse every available game"


func _filtered_games() -> Array:
	var buckets := {
		"SLOTS": ["fruit-spin", "diamond-spin", "lucky-dollar", "golden-fortune"],
		"SPIN": ["lucky-wheel", "lucky-spin", "jackpot-wheel", "bonus-burst", "prize-spinner"],
		"ARCADE": ["coin-flip", "treasure-box", "cash-match", "mystery-box", "diamond-drop"],
		"ACTION": ["fishing", "target-blast", "aeroplane-rush", "bottle-blast", "dollar-rush"],
		"CASUAL": ["scratch-mania", "higher-card", "dice", "lucky-number"],
	}
	var order: Array = []
	for key in ["SLOTS", "SPIN", "ARCADE", "ACTION", "CASUAL"]:
		for slug in buckets[key]:
			if not order.has(slug):
				order.append(slug)
	var by_slug: Dictionary = {}
	for game in _games:
		if game is Dictionary:
			by_slug[str(game.get("slug", ""))] = game
	var selected: Array = []
	if _filter == "ALL":
		for slug in order:
			if by_slug.has(slug):
				selected.append(by_slug[slug])
		for game in _games:
			if not game is Dictionary:
				continue
			var slug := str(game.get("slug", ""))
			if not order.has(slug):
				selected.append(game)
		return selected
	var wanted: Array = buckets.get(_filter, [])
	for slug in wanted:
		if by_slug.has(slug):
			selected.append(by_slug[slug])
	return selected


func _style_stats() -> void:
	var parent_stats := _spins_label.get_parent() as HBoxContainer
	if parent_stats == null:
		return
	parent_stats.add_theme_constant_override("separation", 10)
	var labels: Array[Label] = [_spins_label, _wins_label, _losses_label]
	for label in labels:
		if label.get_parent() is PanelContainer:
			continue
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


func _submit_password_change() -> void:
	if _pw_busy or _pw_current == null:
		return
	var current := _pw_current.text
	var next := _pw_new.text
	var confirm := _pw_confirm.text
	if current == "":
		_pw_feedback.text = "Enter your current password."
		_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	if next.length() < 4:
		_pw_feedback.text = "New password must be at least 4 characters."
		_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	if next != confirm:
		_pw_feedback.text = "New password and confirmation do not match."
		_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_pw_busy = true
	_pw_feedback.text = "Updating password..."
	_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var response: Dictionary = await ApiClient.change_password(current, next, confirm)
	_pw_busy = false
	if not is_inside_tree():
		return
	if response.ok:
		_pw_current.text = ""
		_pw_new.text = ""
		_pw_confirm.text = ""
		_pw_feedback.text = "Password updated successfully."
		_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	else:
		_pw_feedback.text = str(response.error)
		_pw_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _style_wallet() -> void:
	var card := $Scroll/Column/Content/BalanceCard as PanelContainer
	var box := card.get_node("BalanceBox") as VBoxContainer
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10182C")
	style.border_color = Color("F5C542", 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color("F5C542", 0.2)
	style.shadow_size = 14
	card.add_theme_stylebox_override("panel", style)
	var caption := box.get_node("CreditsCaption") as Label
	caption.text = "AVAILABLE CREDITS"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("C5D0E4"))
	%CreditsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%CreditsLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	var virtual := Label.new()
	virtual.name = "VirtualNote"
	virtual.text = "Virtual play credits"
	virtual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	virtual.add_theme_font_size_override("font_size", 14)
	virtual.add_theme_color_override("font_color", Color("C5D0E4"))
	box.add_child(virtual)
	var request_status := Label.new()
	request_status.name = "RequestStatus"
	request_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(request_status)
	box.add_child(request_status)


func _set_credit_number(balance: int) -> void:
	_balance = balance
	%CreditsLabel.text = str(balance)
	if _credits_balance_label:
		_credits_balance_label.text = "Current Credits: %s" % str(balance)
	_fit_credit_number()


func _fit_credit_number() -> void:
	if %CreditsLabel == null:
		return
	var font_size := 46
	if size.x < 400.0:
		font_size = 40
	elif size.x >= 800.0:
		font_size = 52
	if %CreditsLabel.text.length() >= 6:
		font_size -= 8
	%CreditsLabel.add_theme_font_size_override("font_size", font_size)


func _mount_hero_banner(_host: Node) -> void:
	# Intentionally empty — keep lobby focus on category bar + large game carousel.
	pass


func _fill_request_history(requests: Array) -> void:
	if _request_history == null:
		return
	for child in _request_history.get_children():
		_request_history.remove_child(child)
		child.free()
	if requests.is_empty():
		var empty := Label.new()
		empty.text = "No credit requests yet."
		UiTheme.style_muted(empty)
		_request_history.add_child(empty)
		return
	for item in requests:
		if not item is Dictionary:
			continue
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var status := str(item.get("status", "PENDING"))
		var amount := int(item.get("amount", 0))
		var stamp := _short_date(str(item.get("createdAt", "")))
		var note := str(item.get("requestNote", ""))
		if note == "":
			row.text = "%s   ·   %d credits   ·   %s" % [status, amount, stamp]
		else:
			row.text = "%s   ·   %d credits   ·   %s\n%s" % [status, amount, stamp, note]
		match status:
			"APPROVED":
				row.add_theme_color_override("font_color", UiTheme.COL_GREEN)
			"REJECTED":
				row.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			_:
				row.add_theme_color_override("font_color", UiTheme.COL_GOLD)
		_request_history.add_child(row)


func _submit_credit_request() -> void:
	if _request_busy or _request_amount == null:
		return
	var amount := int(_request_amount.text.strip_edges())
	if amount <= 0:
		_request_feedback.text = "Enter a valid amount."
		_request_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_request_busy = true
	_request_feedback.text = "Sending request..."
	_request_feedback.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var note := ""
	if _request_note:
		note = _request_note.text.strip_edges()
	var response: Dictionary = await ApiClient.request_credits(amount, note)
	_request_busy = false
	if not is_inside_tree():
		return
	if response.ok:
		_request_feedback.text = "Request sent. An admin will review it."
		_request_feedback.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		_request_amount.text = ""
		if _request_note:
			_request_note.text = ""
		var refresh: Dictionary = await ApiClient.my_credit_requests()
		if is_inside_tree() and refresh.ok:
			var requests: Array = refresh.data.get("requests", [])
			_fill_request_history(requests)
			_apply_request_status(requests)
	else:
		_request_feedback.text = str(response.error)
		_request_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _lobby_card_size() -> Vector2:
	# Large hero-style cards: ~1 (+ peek) on phones, several big cards on desktop.
	var width := 340.0
	var height := 260.0
	if size.x >= 1280.0:
		width = 400.0
		height = 300.0
	elif size.x >= 1100.0:
		width = 380.0
		height = 286.0
	elif size.x >= 900.0:
		width = 360.0
		height = 274.0
	elif size.x >= 720.0:
		width = 348.0
		height = 266.0
	elif size.x < 380.0:
		width = maxf(size.x - 36.0, 300.0)
		height = 248.0
	elif size.x < 430.0:
		width = maxf(size.x - 40.0, 318.0)
		height = 254.0
	elif size.x < 560.0:
		width = maxf(size.x * 0.86, 330.0)
		height = 258.0
	return Vector2(width, height)


func _inset(child: Control, pad: float) -> MarginContainer:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", int(pad))
	wrap.add_theme_constant_override("margin_right", int(pad))
	wrap.add_theme_constant_override("margin_top", int(pad))
	wrap.add_theme_constant_override("margin_bottom", int(pad))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(child)
	return wrap


func _short_date(value: String) -> String:
	if value.contains("T"):
		return value.split("T")[0]
	return value


func _open_game(game: Dictionary) -> void:
	if _opening:
		return
	if game.has("enabled") and not bool(game.get("enabled", true)):
		if _request_feedback:
			_request_feedback.text = "%s is currently unavailable for your account." % str(game.get("name", "This game"))
			_request_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		_show_tab("credits")
		return
	var min_bet := int(game.get("minimumBet", 1))
	if _balance < min_bet:
		if _request_feedback:
			_request_feedback.text = "Not enough credits. Available %d · Required %d." % [_balance, min_bet]
			_request_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		if _request_amount and _request_amount.text.strip_edges() == "":
			_request_amount.text = str(maxi(min_bet * 10, 50))
		_show_tab("credits")
		return
	_opening = true
	AppState.selected_game = {
		"id": str(game.get("id", "")),
		"slug": str(game.get("slug", "")),
		"name": str(game.get("name", "")),
		"category": str(game.get("category", "")),
		"description": str(game.get("description", "")),
		"difficulty": str(game.get("difficulty", "")),
		"min_bet": min_bet,
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
