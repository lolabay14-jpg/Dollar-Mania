extends Control

const NAV := [
	["overview", "Overview"],
	["players", "Players"],
	["requests", "Credit Requests"],
	["games", "Games"],
	["activity", "Game Activity"],
	["transactions", "Transactions"],
	["settings", "Profile"],
]

var _section := "overview"
var _token := 0
var _players: Array = []
var _games: Array = []
var _transactions: Array = []
var _requests: Array = []
var _own_requests: Array = []
var _activity: Array = []
var _plays: Array = []
var _overview: Dictionary = {}
var _loaded := false
var _overview_ok := false
var _users_ok := false
var _games_ok := false
var _section_label: Label
var _welcome: Label
var _alerts: Button
var _busy := false
var _page: VBoxContainer
var _nav: HFlowContainer
var _column: MarginContainer
var _feedback: Label
var _title: Label
var _dialog: Control
var _search_email: LineEdit
var _detail_player: Dictionary = {}
var _layout := -1
var _fund_amount: LineEdit
var _fund_note: LineEdit
var _fund_feedback: Label
var _fund_busy := false
var _pending_count := 0
var _notify_panel: Control
var _poll: Timer

func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	ArcadeBackdrop.mount_photo(self, GameArt.screen_path("dashboard"), 0.72, 0.14)
	UiTheme.mood(self, "hub")
	_build_shell()
	_poll = Timer.new()
	_poll.wait_time = 12.0
	_poll.autostart = true
	_poll.timeout.connect(_poll_requests)
	add_child(_poll)
	resized.connect(_fit)
	_fit()
	_show_section("overview")
	_load_all()


func _build_shell() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "DashboardScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_column = MarginContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_column)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 24)
	_column.add_child(root)

	var bar := PanelContainer.new()
	_paint_surface(bar, "header")
	root.add_child(bar)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	bar.add_child(_pad(header, 24))
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
	header.add_child(identity)
	identity.add_child(_avatar(_admin_name()))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 4)
	identity.add_child(titles)
	_title = Label.new()
	_title.text = "Admin Dashboard"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	titles.add_child(_title)
	_welcome = Label.new()
	_welcome.text = "Welcome back, %s" % _admin_name()
	_welcome.add_theme_font_size_override("font_size", 18)
	_welcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_welcome)
	var about := Label.new()
	about.text = "Manage players, credits, games, and activity from one place."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(about)
	titles.add_child(about)
	_section_label = Label.new()
	_section_label.text = "Dashboard"
	_section_label.add_theme_font_size_override("font_size", 14)
	UiTheme.style_muted(_section_label)
	titles.add_child(_section_label)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	header.add_child(actions)
	_alerts = _compact_button("Notifications", "")
	_alerts.pressed.connect(_open_notifications)
	actions.add_child(_alerts)
	var profile := _compact_button("Profile", "")
	profile.pressed.connect(_show_section.bind("settings"))
	actions.add_child(profile)
	var logout := _compact_button("Logout", "DangerButton")
	logout.pressed.connect(_logout)
	actions.add_child(logout)

	_nav = HFlowContainer.new()
	_nav.add_theme_constant_override("h_separation", 8)
	_nav.add_theme_constant_override("v_separation", 8)
	_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_nav)
	for item in NAV:
		var button := _button(str(item[1]), "")
		button.custom_minimum_size = Vector2(148, 48)
		button.set_meta("section", str(item[0]))
		button.pressed.connect(_show_section.bind(str(item[0])))
		_nav.add_child(button)
	var nav_logout := _button("Logout", "DangerButton")
	nav_logout.custom_minimum_size = Vector2(148, 48)
	nav_logout.pressed.connect(_logout)
	_nav.add_child(nav_logout)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_feedback)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 24)
	root.add_child(_page)


func _fit() -> void:
	if _column == null:
		return
	ScreenLayout.fit_column(_column, 1180.0)
	var columns := 2 if size.x >= 1180.0 else (1 if size.x >= 860.0 else 0)
	if columns == _layout or _page == null or _page.get_child_count() == 0:
		_layout = columns
		return
	_layout = columns
	if _section == "overview" or _section == "players" or _section == "games":
		_paint_section()


func _logout() -> void:
	ApiClient.logout()
	AppState.go_login()


func _load_all() -> void:
	var token := _token
	var overview_response: Dictionary = await ApiClient.admin_overview()
	var users_response: Dictionary = await ApiClient.admin_users()
	var games_response: Dictionary = await ApiClient.admin_games()
	var transactions_response: Dictionary = await ApiClient.admin_transactions()
	var requests_response: Dictionary = await ApiClient.admin_credit_requests()
	var own_requests_response: Dictionary = await ApiClient.admin_own_credit_requests()
	var activity_response: Dictionary = await ApiClient.admin_activity()
	var plays_response: Dictionary = await ApiClient.admin_plays()
	if not is_inside_tree():
		return
	if token != _token and _section == "detail":
		_loaded = true
		_store_dashboard(overview_response, users_response, games_response, transactions_response, requests_response, activity_response, plays_response)
		if own_requests_response.ok:
			_own_requests = own_requests_response.data.get("requests", [])
		return
	_loaded = true
	_store_dashboard(overview_response, users_response, games_response, transactions_response, requests_response, activity_response, plays_response)
	if own_requests_response.ok:
		_own_requests = own_requests_response.data.get("requests", [])
	else:
		_own_requests = []
	if not overview_response.ok and not users_response.ok:
		push_error("Admin dashboard failed. HTTP %d. %s" % [int(overview_response.get("status", 0)), str(overview_response.get("error", ""))])
		_set_feedback("The dashboard could not be loaded.", true)
	elif _feedback.text.begins_with("The dashboard"):
		_set_feedback("", false)
	if _section == "detail" and not _detail_player.is_empty():
		_open_player(_detail_player)
	elif _section != "create" and _section != "settings" and _section != "detail":
		_paint_section()
	_refresh_alerts()


func _store_dashboard(
	overview_response: Dictionary,
	users_response: Dictionary,
	games_response: Dictionary,
	transactions_response: Dictionary,
	requests_response: Dictionary,
	activity_response: Dictionary,
	plays_response: Dictionary
) -> void:
	_overview_ok = overview_response.ok
	_users_ok = users_response.ok
	_games_ok = games_response.ok
	if overview_response.ok:
		_overview = overview_response.data
	if users_response.ok:
		var users_value: Variant = users_response.data.get("users", [])
		_players = users_value if users_value is Array else []
	if games_response.ok:
		var games_value: Variant = games_response.data.get("games", [])
		_games = games_value if games_value is Array else []
	if transactions_response.ok:
		_transactions = transactions_response.data.get("transactions", [])
	if requests_response.ok:
		var rows: Variant = requests_response.data.get("requests", [])
		_requests = rows if rows is Array else []
		_pending_count = int(requests_response.data.get("pendingCount", _count_pending_local()))
	else:
		_requests = []
	if overview_response.ok:
		_pending_count = int(_overview.get("pendingPlayerRequests", _pending_count))
	if activity_response.ok:
		_activity = activity_response.data.get("activity", [])
	if plays_response.ok:
		_plays = plays_response.data.get("plays", [])


func _show_section(section: String) -> void:
	_section = section
	_token += 1
	_detail_player = {}
	_close_notifications()
	if section == "requests":
		_paint_section()
		_refresh_request_lists()
		return
	_paint_section()


func _paint_section() -> void:
	_clear(_page)
	_style_nav()
	if _section_label:
		_section_label.text = _section_title(_section)
	match _section:
		"overview":
			_render_overview()
		"players":
			_render_players()
			_render_create()
		"games":
			_render_games()
		"transactions":
			_render_transactions()
		"requests":
			_render_requests()
			_render_fund()
		"activity":
			_render_activity()
		"settings":
			_render_settings()
	UiMotion.fade_in(_page)
	UiMotion.bind_tree(_page)
	UiMotion.bind_fields(_page)
	_layout = 3 if size.x >= 980.0 else (2 if size.x >= 680.0 else 1)


func _section_title(section: String) -> String:
	for item in NAV:
		if str(item[0]) == section:
			return str(item[1])
	if section == "detail":
		return "Player"
	return "Admin"


func _style_nav() -> void:
	for child in _nav.get_children():
		if not child is Button:
			continue
		var button := child as Button
		if not button.has_meta("section"):
			continue
		var selected := str(button.get_meta("section")) == _section
		button.theme_type_variation = "SelectedButton" if selected else "Button"


func _render_overview() -> void:
	if not _loaded:
		var loading := _section_box("Dashboard", "", "")
		loading.add_child(_empty_state("Loading dashboard", "Fetching players, credits, and activity."))
		loading.add_child(_skeleton_row())
		return
	if not _overview_ok:
		var failed := _section_box("Dashboard", "", "")
		failed.add_child(_empty_state("Unable to load dashboard data", "The overview could not be loaded."))
		failed.add_child(_retry_button())
		return
	var grid := _kpi_grid()
	_page.add_child(grid)
	var active := int(_overview.get("activePlayers", _count_active()))
	var credits := int(_overview.get("playerCredits", _sum_credits()))
	var players := int(_overview.get("totalPlayers", _players.size()))
	var games := int(_overview.get("totalGames", _games.size()))
	var spins := int(_overview.get("totalSpins", 0))
	var inactive := maxi(players - active, 0)
	grid.add_child(_stat_card("P", "Players", _grouped(players), "%d inactive accounts" % inactive))
	grid.add_child(_stat_card("A", "Active", _grouped(active), "Currently active players"))
	grid.add_child(_stat_card("C", "Credits", _grouped(credits), "Combined virtual balance"))
	var mine := int(_overview.get("myBalance", 0))
	grid.add_child(_stat_card("Y", "Your credits", _grouped(mine), "Available to recharge players"))
	grid.add_child(_stat_card("S", "Played", _grouped(spins), "Recorded spins"))
	grid.add_child(_stat_card("G", "Catalog", _grouped(games), "Games available"))
	var pending := int(_overview.get("pendingPlayerRequests", _pending_count))
	if pending <= 0:
		pending = _count_pending_local()
	_pending_count = pending
	grid.add_child(_stat_card("R", "Requests", _grouped(pending), "Player credit requests pending"))
	var active_games := 0
	for game in _games:
		if game is Dictionary and bool(game.get("isActive", false)):
			active_games += 1
	var manage := _section_box("Game management", "Manage games", "games")
	manage.add_child(_detail_line("Games available", "%d / %d" % [active_games, _games.size()]))
	manage.add_child(_detail_line("Game mode", "Assigned on each player"))
	var players_box := _section_box("Recent players", "View all", "players")
	players_box.add_child(_search_bar())
	if not _users_ok:
		players_box.add_child(_empty_state("Unable to load players", "Please try again."))
		players_box.add_child(_retry_button())
	elif _players.is_empty():
		players_box.add_child(_empty_state("No recent players", "There are currently no players to display."))
	else:
		var shown := 0
		for player in _players:
			if shown >= 6 or not player is Dictionary:
				continue
			players_box.add_child(_player_row(player, size.x >= 860.0))
			shown += 1
	var activity_box := _section_box("Recent activity", "View all", "activity")
	var activity_value: Variant = _overview.get("recentActivity", _activity)
	var activity: Array = activity_value if activity_value is Array else []
	activity_box.add_child(_activity_list(activity.slice(0, 6)))
	var plays_box := _section_box("Games played", "View all", "activity")
	var plays_value: Variant = _overview.get("recentPlays", _plays)
	var plays: Array = plays_value if plays_value is Array else []
	plays_box.add_child(_play_list(plays.slice(0, 6)))


func _render_players() -> void:
	var box := _section_box("Players", "", "")
	box.add_child(_search_bar())
	if not _loaded:
		box.add_child(_empty_state("Loading players", "Fetching player accounts."))
		return
	if not _users_ok:
		box.add_child(_empty_state("Unable to load players", "Please try again."))
		box.add_child(_retry_button())
		return
	if _players.is_empty():
		box.add_child(_empty_state("No players found", "Create a player to see them listed here."))
		return
	var wide := size.x >= 860.0
	for player in _players:
		if player is Dictionary:
			box.add_child(_player_row(player, wide))


func _player_row(player: Dictionary, wide: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_surface(card, "cell")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(_pad(box, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var display_name := str(player.get("displayName", player.get("username", "Player")))
	row.add_child(_avatar(display_name))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 4)
	row.add_child(identity)
	var name := Label.new()
	name.text = str(player.get("username", "Player"))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", 18)
	identity.add_child(name)
	var email := Label.new()
	email.text = str(player.get("email", ""))
	email.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	email.add_theme_font_size_override("font_size", 14)
	UiTheme.style_muted(email)
	identity.add_child(email)
	var active := bool(player.get("isActive", true))
	var credit_box := VBoxContainer.new()
	credit_box.add_theme_constant_override("separation", 2)
	credit_box.custom_minimum_size.x = 96
	credit_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credit_box.alignment = BoxContainer.ALIGNMENT_END
	var amount := Label.new()
	amount.text = _grouped(int(player.get("balance", 0)))
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_font_size_override("font_size", 22)
	credit_box.add_child(amount)
	var credit_caption := Label.new()
	credit_caption.text = "Credits"
	credit_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit_caption.add_theme_font_size_override("font_size", 13)
	UiTheme.style_muted(credit_caption)
	credit_box.add_child(credit_caption)
	var mode := _mode_badge(str(player.get("gameMode", "MEDIUM")))
	if wide:
		row.add_child(_status_badge(active))
		row.add_child(mode)
		row.add_child(credit_box)
	else:
		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 12)
		meta.alignment = BoxContainer.ALIGNMENT_END
		box.add_child(meta)
		meta.add_child(_status_badge(active))
		meta.add_child(mode)
		meta.add_child(credit_box)
	box.add_child(_player_actions(player))
	return card


func _player_actions(player: Dictionary) -> HFlowContainer:
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view := _compact_button("View", "PrimaryButton")
	view.pressed.connect(_open_player.bind(player))
	actions.add_child(view)
	var edit := _compact_button("Edit", "")
	edit.pressed.connect(_edit_player.bind(player))
	actions.add_child(edit)
	var add := _compact_button("Recharge", "")
	add.pressed.connect(_credit_dialog.bind(player, true))
	actions.add_child(add)
	var remove := _compact_button("Redeem", "DangerButton")
	remove.pressed.connect(_credit_dialog.bind(player, false))
	actions.add_child(remove)
	var active := bool(player.get("isActive", true))
	var toggle := _compact_button("Deactivate" if active else "Activate", "")
	toggle.pressed.connect(_toggle_player.bind(player))
	actions.add_child(toggle)
	return actions


func _render_create() -> void:
	var box := _form_box()
	box.add_child(_muted("New accounts are always created as players. Virtual credits only."))
	var username := _field("Username")
	var email := _field("Email")
	var password := _field("Password", true)
	var confirm := _field("Confirm Password", true)
	var credits := _field("Starting credits")
	box.add_child(username)
	box.add_child(email)
	box.add_child(password)
	box.add_child(confirm)
	box.add_child(credits)
	var error := Label.new()
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	box.add_child(error)
	var submit := _button("Create Player", "PrimaryButton")
	submit.custom_minimum_size = Vector2(0, 52)
	submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(submit)
	username.text_submitted.connect(func(_text: String) -> void: email.grab_focus())
	email.text_submitted.connect(func(_text: String) -> void: password.grab_focus())
	password.text_submitted.connect(func(_text: String) -> void: confirm.grab_focus())
	confirm.text_submitted.connect(func(_text: String) -> void: credits.grab_focus())
	credits.text_submitted.connect(func(_text: String) -> void: _create_player(username, email, password, confirm, credits, error, submit))
	submit.pressed.connect(_create_player.bind(username, email, password, confirm, credits, error, submit))


func _create_player(
	username: LineEdit,
	email: LineEdit,
	password: LineEdit,
	confirm: LineEdit,
	credits: LineEdit,
	error: Label,
	submit: Button
) -> void:
	if _busy:
		return
	var problem := _validate_player(
		username.text.strip_edges(),
		email.text.strip_edges(),
		password.text,
		confirm.text,
		credits.text.strip_edges()
	)
	error.text = problem
	if problem != "":
		return
	_busy = true
	submit.disabled = true
	submit.text = "Creating..."
	var response: Dictionary = await ApiClient.admin_create_player(
		username.text.strip_edges(),
		email.text.strip_edges(),
		password.text,
		confirm.text,
		int(credits.text.strip_edges())
	)
	if not is_inside_tree():
		return
	_busy = false
	submit.disabled = false
	submit.text = "Create Player"
	if not response.ok:
		push_error("Create player failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		error.text = "The player could not be created. Check the username and email, then try again."
		return
	password.text = ""
	confirm.text = ""
	_set_feedback("Player %s created." % username.text.strip_edges(), false)
	username.text = ""
	email.text = ""
	credits.text = ""
	await _load_all()
	if is_inside_tree():
		_show_section("players")


func _validate_player(username: String, email: String, password: String, confirm: String, credits: String) -> String:
	if username == "":
		return "Username is required."
	if username.length() < 3:
		return "Username must be at least 3 characters."
	if not username.is_valid_identifier() and username.find(" ") != -1:
		return "Username can use letters, numbers, and underscores."
	if not _username_ok(username):
		return "Username can use letters, numbers, and underscores."
	if email == "":
		return "Email is required."
	if not email.contains("@") or not email.contains("."):
		return "Enter a valid email."
	if password == "":
		return "Password is required."
	if password.length() < 4:
		return "Password must be at least 4 characters."
	if confirm == "":
		return "Confirm your password."
	if password != confirm:
		return "Passwords do not match."
	if credits == "" or not credits.is_valid_int():
		return "Starting credits must be a whole number."
	if int(credits) <= 0:
		return "Starting credits must be greater than 0."
	return ""


func _username_ok(value: String) -> bool:
	if value == "":
		return false
	for index in value.length():
		var character := value.substr(index, 1)
		var code := character.unicode_at(0)
		var letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var digit := code >= 48 and code <= 57
		if not letter and not digit and character != "_":
			return false
	return true


func _render_games() -> void:
	if not _loaded:
		_page.add_child(_muted("Loading games..."))
		return
	if not _games_ok:
		_page.add_child(_muted("Games could not be loaded."))
		_page.add_child(_retry_button())
		return
	if _games.is_empty():
		_page.add_child(_muted("No games are in the catalog."))
		return
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2 if size.x >= 860.0 else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_page.add_child(grid)
	for game in _games:
		if game is Dictionary:
			grid.add_child(_game_card(game))


func _game_card(game: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_surface(card, "kpi")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var banner := GameBanner.new()
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.set_banner_height(108.0)
	box.add_child(banner)
	banner.set_game(str(game.get("slug", "")), str(game.get("category", "")), UiTheme.game_accent(str(game.get("slug", ""))))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 8)
	box.add_child(_pad(copy, 16))
	var title := Label.new()
	title.text = str(game.get("name", "Game"))
	title.add_theme_font_size_override("font_size", 22)
	copy.add_child(title)
	copy.add_child(_muted(str(game.get("category", ""))))
	copy.add_child(_muted(str(game.get("description", ""))))
	var active := "Active" if bool(game.get("isActive", true)) else "Inactive"
	copy.add_child(Label.new())
	var facts := copy.get_child(copy.get_child_count() - 1) as Label
	facts.text = "Bets %s–%s   ·   %s   ·   %s plays" % [
		str(int(game.get("minimumBet", 0))),
		str(int(game.get("maximumBet", 0))),
		active,
		str(int(game.get("spins", 0))),
	]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return card


func _render_transactions() -> void:
	var box := _section_box("Transactions", "", "")
	if not _loaded:
		box.add_child(_empty_state("Loading transactions", "Fetching credit history."))
		return
	box.add_child(_transaction_list(_transactions))


func _render_requests() -> void:
	if not _loaded:
		var loading := _section_box("Credit requests", "", "")
		loading.add_child(_empty_state("Loading credit requests", "Fetching pending requests."))
		return
	var pending := _count_pending_local()
	var summary := _section_box("Player credit requests", "", "")
	summary.add_child(_muted("%d pending · %d total" % [pending, _requests.size()]))
	if _requests.is_empty():
		summary.add_child(_empty_state("No pending credit requests", "Players have not requested credits."))
		return
	for item in _requests:
		if item is Dictionary:
			_request_card(item)


func _request_card(item: Dictionary) -> void:
	var box := _form_box()
	box.add_theme_constant_override("separation", 12)
	var status := str(item.get("status", ""))
	var title := Label.new()
	title.text = str(item.get("username", "Player"))
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	box.add_child(_muted(str(item.get("email", ""))))
	box.add_child(_muted("Current Credits: %s" % _grouped(int(item.get("balance", 0)))))
	box.add_child(_muted("Requested: %s" % _grouped(int(item.get("amount", 0)))))
	var note := str(item.get("requestNote", ""))
	if note != "":
		box.add_child(_muted("Note: %s" % note))
	box.add_child(_muted("Date: %s   ·   Status: %s" % [_date(str(item.get("createdAt", ""))), status]))
	if status == "PENDING":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var approve := _button("Approve", "PrimaryButton")
		approve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		approve.pressed.connect(_review_request.bind(str(item.get("id", "")), "approve"))
		row.add_child(approve)
		var reject := _button("Reject", "DangerButton")
		reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reject.pressed.connect(_review_request.bind(str(item.get("id", "")), "reject"))
		row.add_child(reject)


func _render_fund() -> void:
	var box := _form_box()
	box.add_theme_constant_override("separation", 12)
	var heading := Label.new()
	heading.text = "Request credits from Super Admin"
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	var mine := int(_overview.get("myBalance", 0))
	var balance := Label.new()
	balance.text = "Current credits: %s" % _grouped(mine)
	balance.add_theme_font_size_override("font_size", 24)
	balance.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	box.add_child(balance)
	box.add_child(_muted("You cannot approve your own request. Super Admin reviews these."))
	_fund_amount = LineEdit.new()
	_fund_amount.placeholder_text = "Requested amount"
	_fund_amount.custom_minimum_size = Vector2(0, 48)
	box.add_child(_fund_amount)
	_fund_note = LineEdit.new()
	_fund_note.placeholder_text = "Optional note"
	_fund_note.custom_minimum_size = Vector2(0, 48)
	box.add_child(_fund_note)
	var send := _button("Request Credits", "PrimaryButton")
	send.pressed.connect(_submit_admin_fund)
	box.add_child(send)
	_fund_feedback = Label.new()
	_fund_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_fund_feedback)
	box.add_child(_fund_feedback)
	var history := _section_box("Your request history", "", "")
	if _own_requests.is_empty():
		history.add_child(_empty_state("No requests yet", "Your super-admin credit requests will appear here."))
		return
	for item in _own_requests:
		if not item is Dictionary:
			continue
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s   ·   %s credits   ·   %s" % [
			str(item.get("status", "")),
			str(int(item.get("amount", 0))),
			_date(str(item.get("createdAt", ""))),
		]
		history.add_child(row)


func _submit_admin_fund() -> void:
	if _fund_busy or _fund_amount == null:
		return
	var amount := int(_fund_amount.text.strip_edges())
	if amount <= 0:
		_fund_feedback.text = "Enter a valid amount."
		_fund_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_fund_busy = true
	_fund_feedback.text = "Sending..."
	_fund_feedback.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var note := ""
	if _fund_note:
		note = _fund_note.text.strip_edges()
	var response: Dictionary = await ApiClient.admin_request_credits(amount, note)
	_fund_busy = false
	if not is_inside_tree():
		return
	if response.ok:
		_fund_feedback.text = "Request sent to Super Admin."
		_fund_feedback.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		_fund_amount.text = ""
		if _fund_note:
			_fund_note.text = ""
		await _load_all()
		if _section == "requests":
			_paint_section()
	else:
		_fund_feedback.text = str(response.error)
		_fund_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _render_activity() -> void:
	if not _loaded:
		var loading := _section_box("Game activity", "", "")
		loading.add_child(_empty_state("Loading activity", "Fetching recent plays."))
		return
	var plays := _section_box("Games played", "", "")
	plays.add_child(_play_list(_plays))
	var activity := _section_box("Account activity", "", "")
	activity.add_child(_activity_list(_activity))


func _render_settings() -> void:
	var sub := "account"
	var shell := PanelContainer.new()
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
	_page.add_child(shell)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	shell.add_child(tabs)
	var account_host := _form_box()
	var security_host := _form_box()
	var account_panel := account_host.get_parent().get_parent() as CanvasItem
	var security_panel := security_host.get_parent().get_parent() as CanvasItem
	if security_panel:
		security_panel.visible = false
	var paint_tab := func(selected: String) -> void:
		for child in tabs.get_children():
			if child is Button:
				var button := child as Button
				var on := str(button.get_meta("sub", "")) == selected
				button.theme_type_variation = "SelectedButton" if on else ""
				button.set_pressed_no_signal(on)
		if account_panel:
			account_panel.visible = selected == "account"
		if security_panel:
			security_panel.visible = selected == "security"
	for item in [["account", "Account"], ["security", "Security"]]:
		var button := _button(str(item[1]), "SelectedButton" if str(item[0]) == sub else "")
		button.toggle_mode = true
		button.set_meta("sub", str(item[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: paint_tab.call(str(item[0])))
		tabs.add_child(button)
	account_host.add_child(_heading("Account"))
	account_host.add_child(_muted("Signed in as %s  ·  ADMIN" % ApiClient.username()))
	account_host.add_child(_muted("Players sign in with accounts you create. Credits are virtual and cannot be cashed out."))
	var sound := CheckBox.new()
	sound.text = "Sound"
	sound.button_pressed = AppState.sound_enabled
	sound.custom_minimum_size.y = 48
	sound.toggled.connect(func(on: bool) -> void: AppState.sound_enabled = on)
	account_host.add_child(sound)
	var music := CheckBox.new()
	music.text = "Music"
	music.button_pressed = AppState.music_enabled
	music.custom_minimum_size.y = 48
	music.toggled.connect(func(on: bool) -> void: AppState.music_enabled = on)
	account_host.add_child(music)
	var logout := _button("Logout", "DangerButton")
	logout.pressed.connect(_logout)
	account_host.add_child(logout)
	_mount_password_card(security_host)
	var games_box := _form_box()
	games_box.add_child(_muted("Loading game settings..."))
	var response: Dictionary = await ApiClient.admin_platform_settings()
	if not is_inside_tree() or _section != "settings":
		return
	for child in games_box.get_children():
		games_box.remove_child(child)
		child.free()
	if not response.ok:
		games_box.add_child(_empty_state("Unable to load game settings", "Try again in a moment."))
		return
	var heading := Label.new()
	heading.text = "Game availability"
	heading.add_theme_font_size_override("font_size", 20)
	games_box.add_child(heading)
	games_box.add_child(_muted("Game mode is assigned on each player's page. Players never see it."))
	var games_value: Variant = response.data.get("games", [])
	var games: Array = games_value if games_value is Array else []
	for game in games:
		if not game is Dictionary:
			continue
		var toggle := CheckBox.new()
		toggle.text = str(game.get("name", "Game"))
		toggle.button_pressed = bool(game.get("isActive", true))
		toggle.custom_minimum_size.y = 44
		var game_id := str(game.get("id", ""))
		toggle.toggled.connect(_set_game_active.bind(game_id, toggle))
		games_box.add_child(toggle)


func _mount_password_card(host: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Change Password"
	title.add_theme_font_size_override("font_size", 20)
	host.add_child(title)
	host.add_child(_muted("Change the password for your own authenticated account only."))
	var current := _field("Current Password", true)
	var next := _field("New Password (min 4 characters)", true)
	var confirm := _field("Confirm New Password", true)
	var feedback := _muted("")
	var submit := _button("Change Password", "PrimaryButton")
	host.add_child(current)
	host.add_child(next)
	host.add_child(confirm)
	host.add_child(submit)
	host.add_child(feedback)
	submit.pressed.connect(func() -> void:
		if current.text == "":
			feedback.text = "Enter your current password."
			feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		if next.text.length() < 4:
			feedback.text = "New password must be at least 4 characters."
			feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		if next.text != confirm.text:
			feedback.text = "New password and confirmation do not match."
			feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		feedback.text = "Updating password..."
		feedback.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		var response: Dictionary = await ApiClient.change_password(current.text, next.text, confirm.text)
		if not is_inside_tree():
			return
		if response.ok:
			current.text = ""
			next.text = ""
			confirm.text = ""
			feedback.text = "Password updated successfully."
			feedback.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		else:
			feedback.text = str(response.error)
			feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	)


func _set_game_active(active: bool, game_id: String, toggle: CheckBox) -> void:
	var response: Dictionary = await ApiClient.admin_set_game_active(game_id, active)
	if not is_inside_tree():
		return
	if not response.ok:
		push_error("Game availability failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		toggle.set_pressed_no_signal(not active)
		_set_feedback("The game could not be updated.", true)
		return
	for game in _games:
		if game is Dictionary and str(game.get("id", "")) == game_id:
			game["isActive"] = active
	_set_feedback("Game availability updated.", false)


func _open_player(player: Dictionary) -> void:
	_detail_player = player
	_section = "detail"
	_token += 1
	var token := _token
	_clear(_page)
	_style_nav()
	if _section_label:
		_section_label.text = str(player.get("username", "Player"))
	_page.add_child(_muted("Loading player..."))
	var response: Dictionary = await ApiClient.admin_player_history(str(player.get("id", "")))
	if not is_inside_tree() or token != _token:
		return
	_clear(_page)
	if not response.ok:
		push_error("Player history failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_page.add_child(_muted("This player could not be loaded."))
		var back := _button("Back to players", "")
		back.pressed.connect(_show_section.bind("players"))
		_page.add_child(back)
		return
	var user: Dictionary = response.data.get("user", player)
	_render_detail(user, response.data)
	UiMotion.fade_in(_page)
	UiMotion.bind_tree(_page)


func _render_detail(user: Dictionary, data: Dictionary) -> void:
	var back := _button("Back to players", "")
	back.pressed.connect(_show_section.bind("players"))
	_page.add_child(back)
	var box := _form_box()
	var name := Label.new()
	name.text = str(user.get("username", ""))
	UiTheme.style_title(name, 28)
	box.add_child(name)
	box.add_child(_detail_line("Email", str(user.get("email", ""))))
	box.add_child(_detail_line("Role", str(user.get("role", "PLAYER"))))
	box.add_child(_detail_line("Credits", str(int(user.get("balance", 0)))))
	box.add_child(_detail_line("Status", "Active" if bool(user.get("isActive", true)) else "Inactive"))
	box.add_child(_detail_line("Created", _date(str(user.get("createdAt", "")))))
	box.add_child(_player_actions(user))
	if str(user.get("role", "")) == "PLAYER":
		_render_mode_card(user)
		var controls := preload("res://game/scripts/ui/admin_game_controls.gd").new()
		_page.add_child(controls)
		controls.setup(user)
	var history := _section_box("Transaction history", "", "")
	history.add_child(_transaction_list(data.get("transactions", [])))
	var games := _section_box("Game history", "", "")
	games.add_child(_spin_list(data.get("spins", [])))
	var activity := _section_box("Recent activity", "", "")
	activity.add_child(_activity_list(data.get("activity", [])))


func _render_mode_card(user: Dictionary) -> void:
	var box := _form_box()
	var heading := Label.new()
	heading.text = "Player management"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	box.add_child(_detail_line("Player", str(user.get("email", ""))))
	box.add_child(_detail_line("Credits", str(int(user.get("balance", 0)))))
	var current := _detail_line("Game mode", _mode_label(str(user.get("gameMode", "MEDIUM"))))
	box.add_child(current)
	box.add_child(_muted("Change game mode"))
	var choice := {"mode": str(user.get("gameMode", "MEDIUM")).to_upper()}
	if str(choice["mode"]) != "EASY" and str(choice["mode"]) != "HARD":
		choice["mode"] = "MEDIUM"
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	box.add_child(modes)
	var buttons: Array[Button] = []
	for mode in ["EASY", "MEDIUM", "HARD"]:
		var button := _compact_button(_mode_label(mode), "SelectedButton" if mode == str(choice["mode"]) else "")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_choose_player_mode.bind(mode, choice, buttons))
		modes.add_child(button)
		buttons.append(button)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var save := _button("Save Changes", "PrimaryButton")
	save.custom_minimum_size.y = 52
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save_player_mode.bind(str(user.get("id", "")), choice, current, status, save))
	box.add_child(save)


func _choose_player_mode(mode: String, choice: Dictionary, buttons: Array[Button]) -> void:
	choice["mode"] = mode
	for button in buttons:
		var selected := button.text == _mode_label(mode)
		button.theme_type_variation = "SelectedButton" if selected else ""
		if selected:
			UiMotion.pulse_selected(button)


func _save_player_mode(user_id: String, choice: Dictionary, current: Label, status: Label, save: Button) -> void:
	save.disabled = true
	status.text = ""
	var mode := str(choice.get("mode", "MEDIUM"))
	var response: Dictionary = await ApiClient.admin_set_player_game_mode(user_id, mode)
	if not is_inside_tree():
		return
	save.disabled = false
	if not response.ok:
		push_error("Player game mode failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		status.text = "The game mode could not be saved."
		status.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	var saved: Dictionary = response.data.get("user", {})
	var saved_mode := str(saved.get("gameMode", mode))
	choice["mode"] = saved_mode
	current.text = "Game mode: %s" % _mode_label(saved_mode)
	status.text = "Game mode updated successfully."
	status.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	_remember_player_mode(user_id, saved_mode)


func _remember_player_mode(user_id: String, mode: String) -> void:
	if str(_detail_player.get("id", "")) == user_id:
		_detail_player["gameMode"] = mode
	for player in _players:
		if player is Dictionary and str(player.get("id", "")) == user_id:
			player["gameMode"] = mode


func _mode_label(mode: String) -> String:
	match mode.to_upper():
		"EASY":
			return "Easy"
		"HARD":
			return "Hard"
		_:
			return "Medium"


func _mode_badge(mode: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_surface(panel, "badge_mode")
	var label := Label.new()
	label.text = _mode_label(mode)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTheme.COL_BLUE)
	panel.add_child(label)
	return panel


func _search_players() -> void:
	if _search_email == null:
		return
	var email := _search_email.text.strip_edges()
	if email.is_empty() or not email.contains("@") or not email.contains("."):
		_set_feedback("Enter a valid email.", true)
		return
	_set_feedback("Searching players...", false)
	var response: Dictionary = await ApiClient.admin_search_user(email)
	if not is_inside_tree():
		return
	if not response.ok:
		push_error("Player search failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_set_feedback("Player search failed. Try again.", true)
		return
	var user: Dictionary = response.data.get("user", {})
	if user.is_empty():
		_set_feedback("No user found with that email.", true)
		return
	_set_feedback("Found %s." % str(user.get("username", "user")), false)
	var previous := _page.get_node_or_null("SearchMatch")
	if previous:
		_page.remove_child(previous)
		previous.free()
	var card := PanelContainer.new()
	card.name = "SearchMatch"
	_paint_surface(card, "section")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(_pad(box, 20))
	var title := Label.new()
	title.text = "Search result"
	UiTheme.style_muted(title)
	box.add_child(title)
	box.add_child(_detail_line("Username", str(user.get("username", ""))))
	box.add_child(_detail_line("Email", str(user.get("email", ""))))
	box.add_child(_detail_line("Role", str(user.get("role", ""))))
	box.add_child(_detail_line("Credits", str(int(user.get("balance", 0)))))
	if str(user.get("role", "")) == "PLAYER":
		box.add_child(_detail_line("Game mode", _mode_label(str(user.get("gameMode", "MEDIUM")))))
		box.add_child(_player_actions(user))
	else:
		box.add_child(_muted("Player actions are only available for player accounts."))
	_page.add_child(card)
	_page.move_child(card, 1)
	UiMotion.bind_tree(card)


func _edit_player(player: Dictionary) -> void:
	_close_dialog()
	var name_field := LineEdit.new()
	name_field.text = str(player.get("displayName", player.get("username", "")))
	name_field.placeholder_text = "Display name"
	name_field.custom_minimum_size = Vector2(280, 48)
	var error := Label.new()
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	_open_dialog("Edit player", func(inner: VBoxContainer) -> void:
		inner.add_child(_muted("Username and email stay the same. Role stays PLAYER."))
		inner.add_child(_detail_line("Username", str(player.get("username", ""))))
		inner.add_child(_detail_line("Email", str(player.get("email", ""))))
		inner.add_child(name_field)
		inner.add_child(error)
	, "Save", func() -> void:
		var display_name := name_field.text.strip_edges()
		if display_name == "":
			error.text = "Display name is required."
			return
		_close_dialog()
		_save_player(player, display_name)
	)


func _save_player(player: Dictionary, display_name: String) -> void:
	var response: Dictionary = await ApiClient.admin_update_player(str(player.get("id", "")), {"displayName": display_name})
	if not is_inside_tree():
		return
	if not response.ok:
		push_error("Player update failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_set_feedback("The player could not be updated.", true)
		return
	_set_feedback("Updated %s." % str(player.get("username", "player")), false)
	await _load_all()


func _credits_of(value: Variant) -> int:
	if value is String:
		return int(float(value))
	return int(value)


func _credit_error(response: Dictionary) -> String:
	var status := int(response.get("status", 0))
	if status == 401:
		return "Session expired. Please login again."
	if status == 0:
		return "Transfer failed. Please try again."
	var message := str(response.get("error", "Transfer failed. Please try again."))
	if message == "":
		return "Transfer failed. Please try again."
	return message


func _remember_credit(player: Dictionary, data: Dictionary) -> void:
	var next_target := _credits_of(data.get("balance", player.get("balance", 0)))
	var next_sender := _credits_of(data.get("senderBalance", _overview.get("myBalance", 0)))
	_overview["myBalance"] = next_sender
	var user_id := str(player.get("id", ""))
	for index in _players.size():
		var row: Variant = _players[index]
		if row is Dictionary and str(row.get("id", "")) == user_id:
			row["balance"] = next_target
			_players[index] = row
	if str(_detail_player.get("id", "")) == user_id:
		_detail_player["balance"] = next_target


func _credit_dialog(player: Dictionary, adding: bool) -> void:
	if str(player.get("role", "PLAYER")) != "PLAYER":
		_set_feedback("Credits can only be changed on player accounts.", true)
		return
	var amount := LineEdit.new()
	amount.placeholder_text = "Amount"
	amount.custom_minimum_size = Vector2(0, 52)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.max_length = 7
	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	var verb := "Recharge" if adding else "Redeem"
	var balance := Label.new()
	balance.text = "Current balance: %s" % _grouped(_credits_of(player.get("balance", 0)))
	balance.add_theme_font_size_override("font_size", 22)
	balance.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	amount.text_changed.connect(func(value: String) -> void:
		if value.is_valid_int() and int(value) > 0:
			notice.text = "You are about to %s %s credits." % ["recharge" if adding else "redeem", _grouped(int(value))]
		else:
			notice.text = ""
	)
	_open_dialog(verb, func(inner: VBoxContainer) -> void:
		inner.add_child(_muted(str(player.get("email", ""))))
		inner.add_child(balance)
		inner.add_child(_muted("Available to recharge: %s" % _grouped(_credits_of(_overview.get("myBalance", 0)))))
		inner.add_child(_muted("Amount"))
		inner.add_child(amount)
		inner.add_child(notice)
	, verb, func(confirm: Button) -> void:
		var text := amount.text.strip_edges()
		if text == "" or not text.is_valid_int() or int(text) <= 0:
			notice.text = "Invalid amount."
			notice.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		if _busy or confirm.disabled:
			return
		confirm.disabled = true
		confirm.text = "Processing..."
		_apply_credits(player, int(text), adding, confirm)
	)


func _apply_credits(player: Dictionary, amount: int, adding: bool, confirm: Button = null) -> void:
	if _busy:
		return
	_busy = true
	var action := "add" if adding else "remove"
	var request_id := "credit-%d-%d" % [Time.get_ticks_msec(), randi() % 1000000]
	var response: Dictionary = await ApiClient.admin_adjust_credits(str(player.get("id", "")), amount, action, "", request_id)
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		if is_instance_valid(confirm):
			confirm.disabled = false
			confirm.text = "Recharge" if adding else "Redeem"
		push_error("Credit update failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_set_feedback(_credit_error(response), true)
		return
	_close_dialog()
	var data: Dictionary = response.get("data", {})
	var name := str(player.get("displayName", player.get("username", "player")))
	if bool(data.get("duplicate", false)):
		_set_feedback("That transfer was already recorded.", false)
	elif adding:
		_set_feedback("%s credits recharged to %s." % [_grouped(amount), name], false)
	else:
		_set_feedback("%s credits successfully redeemed." % _grouped(amount), false)
	_remember_credit(player, data)
	_paint_section()
	await _load_all()


func _toggle_player(player: Dictionary) -> void:
	if str(player.get("role", "")) != "PLAYER":
		_set_feedback("Only player accounts can be activated here.", true)
		return
	var active := bool(player.get("isActive", true))
	var next := not active
	var verb := "Activate" if next else "Deactivate"
	_open_dialog("%s player" % verb, func(inner: VBoxContainer) -> void:
		inner.add_child(_muted("%s %s?" % [verb, str(player.get("username", "this player"))]))
	, verb, func() -> void:
		_close_dialog()
		_set_active(player, next)
	)


func _set_active(player: Dictionary, active: bool) -> void:
	var response: Dictionary = await ApiClient.admin_update_player(str(player.get("id", "")), {"isActive": active})
	if not is_inside_tree():
		return
	if not response.ok:
		push_error("Player status failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_set_feedback("The player status could not be changed.", true)
		return
	_set_feedback("%s is now %s." % [str(player.get("username", "Player")), "active" if active else "inactive"], false)
	await _load_all()


func _review_request(request_id: String, action: String) -> void:
	var response: Dictionary = await ApiClient.admin_review_request(request_id, action)
	if not is_inside_tree():
		return
	if not response.ok:
		push_error("Credit request review failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		_set_feedback("The credit request could not be updated.", true)
		return
	_set_feedback("Credit request %s." % ("approved" if action == "approve" else "rejected"), false)
	await _load_all()


func _open_dialog(title: String, fill: Callable, confirm_text: String, on_confirm: Callable) -> void:
	_close_dialog()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(size.x - 32.0, 460.0), 0)
	_paint_surface(panel, "section")
	center.add_child(panel)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 24)
	panel.add_child(inset)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inset.add_child(inner)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_title(heading, 24)
	inner.add_child(heading)
	fill.call(inner)
	var confirm := _button(confirm_text, "PrimaryButton")
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.pressed.connect(func() -> void:
		if on_confirm.get_argument_count() > 0:
			on_confirm.call(confirm)
		else:
			on_confirm.call()
	)
	inner.add_child(confirm)
	var cancel := _button("Cancel", "")
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.pressed.connect(_close_dialog)
	inner.add_child(cancel)
	_dialog = dim
	UiMotion.bind_tree(dim)
	UiMotion.bind_fields(dim)


func _close_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _transaction_list(rows: Array) -> Control:
	if rows.is_empty():
		return _empty_state("No transactions", "There are no credit transactions to display.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for row in rows:
		if not row is Dictionary:
			continue
		var amount: int = int(row.get("amount", 0))
		var sign := "+" if amount > 0 else ""
		var who := str(row.get("username", row.get("displayName", "Player")))
		box.add_child(_info_row(
			who,
			who,
			"%s%d  ·  %s" % [sign, amount, str(row.get("description", row.get("transactionType", "")))],
			_when(str(row.get("createdAt", "")))
		))
	return box


func _play_list(rows: Array) -> Control:
	if rows.is_empty():
		return _empty_state("No games played", "There are no recorded plays to display.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for row in rows:
		if not row is Dictionary:
			continue
		var who := str(row.get("username", "Player"))
		box.add_child(_info_row(
			who,
			who,
			"%s  ·  Bet %d  ·  Win %d" % [
				str(row.get("gameName", "Game")),
				int(row.get("betAmount", 0)),
				int(row.get("winAmount", 0)),
			],
			_when(str(row.get("createdAt", "")))
		))
	return box


func _spin_list(rows: Array) -> Control:
	if rows.is_empty():
		return _empty_state("No games played", "There are no recorded plays to display.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for row in rows:
		if not row is Dictionary:
			continue
		var game_name := str(row.get("gameName", "Game"))
		box.add_child(_info_row(
			game_name,
			game_name,
			"Bet %d  ·  Win %d" % [int(row.get("betAmount", 0)), int(row.get("winAmount", 0))],
			_when(str(row.get("createdAt", "")))
		))
	return box


func _activity_list(rows: Array) -> Control:
	if rows.is_empty():
		return _empty_state("No recent activity", "There is no account activity to display.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for row in rows:
		if not row is Dictionary:
			continue
		var who := str(row.get("targetUsername", "Player"))
		var amount_text := ""
		if row.get("amount") != null:
			var amount: int = int(row.get("amount"))
			amount_text = "  ·  %d" % amount
		var detail := "%s%s" % [str(row.get("description", "")), amount_text]
		if detail.strip_edges() == "":
			detail = str(row.get("action", ""))
		box.add_child(_info_row(who, who, detail, _when(str(row.get("createdAt", "")))))
	return box


func _stat_card(mark: String, caption: String, value: String, note: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 0)
	card.clip_contents = false
	_paint_surface(card, "kpi")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(_pad(box, 20))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(_icon_box(mark))
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.add_theme_font_size_override("font_size", 15)
	UiTheme.style_muted(label)
	top.add_child(label)
	var number := Label.new()
	number.text = value
	number.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	number.clip_text = false
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.add_theme_font_size_override("font_size", 28)
	number.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	box.add_child(number)
	var extra := Label.new()
	extra.text = note if note != "" else " "
	extra.add_theme_font_size_override("font_size", 14)
	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(extra)
	box.add_child(extra)
	card.modulate.a = 0.0
	card.tree_entered.connect(func() -> void:
		var tween := card.create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.22)
	, CONNECT_ONE_SHOT)
	return card


func _detail_line(caption: String, value: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s: %s" % [caption, value]
	label.add_theme_font_size_override("font_size", 18)
	return label


func _search_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	_paint_surface(panel, "cell")
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(_pad(stack, 12))
	var row: BoxContainer = (HBoxContainer.new() if size.x >= 700.0 else VBoxContainer.new())
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	_search_email = LineEdit.new()
	_search_email.placeholder_text = "Search player by email..."
	_search_email.custom_minimum_size = Vector2(160, 48)
	_search_email.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_email.text_submitted.connect(func(_text: String) -> void: _search_players())
	row.add_child(_search_email)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(buttons)
	var clear := _compact_button("Clear", "")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void:
		if _search_email:
			_search_email.text = ""
		_set_feedback("", false)
	)
	buttons.add_child(clear)
	var search_button := _compact_button("Find", "PrimaryButton")
	search_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_button.pressed.connect(_search_players)
	buttons.add_child(search_button)
	return panel


func _avatar(player_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(52, 52)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_surface(panel, "icon")
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(52, 52)
	panel.add_child(center)
	var label := Label.new()
	label.text = _initials(player_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	center.add_child(label)
	return panel


func _info_row(initials_source: String, title: String, detail: String, badge: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_surface(card, "cell")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(_pad(row, 16))
	row.add_child(_avatar(initials_source))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 18)
	text.add_child(heading)
	var sub := Label.new()
	sub.text = detail
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(sub)
	text.add_child(sub)
	if badge != "":
		if size.x < 700.0:
			sub.text = "%s\n%s" % [detail, badge]
		else:
			var meta := VBoxContainer.new()
			meta.add_theme_constant_override("separation", 2)
			meta.custom_minimum_size.x = 112
			meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var parts := badge.split(" ", false)
			var lines: PackedStringArray = parts.slice(0, 2) if parts.size() > 1 else PackedStringArray([badge])
			for line in lines:
				var mark := Label.new()
				mark.text = line
				mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				mark.autowrap_mode = TextServer.AUTOWRAP_OFF
				mark.add_theme_font_size_override("font_size", 13)
				UiTheme.style_muted(mark)
				meta.add_child(mark)
			row.add_child(meta)
	return card


func _skeleton_row() -> GridContainer:
	var grid := _kpi_grid()
	for _index in 4:
		grid.add_child(_stat_card("…", "Loading", "—", "Waiting for the server"))
	return grid


func _refresh_alerts() -> void:
	if _alerts == null:
		return
	_pending_count = maxi(_pending_count, 0)
	if _pending_count <= 0:
		_pending_count = _count_pending_local()
	_alerts.text = "Notifications" if _pending_count == 0 else "Notifications  %d" % _pending_count


func _count_pending_local() -> int:
	var pending := 0
	for item in _requests:
		if item is Dictionary and str(item.get("status", "")) == "PENDING":
			pending += 1
	return pending


func _poll_requests() -> void:
	if not is_inside_tree() or _busy:
		return
	var count_response: Dictionary = await ApiClient.admin_pending_credit_count()
	if not is_inside_tree():
		return
	if count_response.ok:
		_pending_count = int(count_response.data.get("pendingCount", 0))
		_refresh_alerts()
	if _section == "requests":
		await _refresh_request_lists()


func _refresh_request_lists() -> void:
	var requests_response: Dictionary = await ApiClient.admin_credit_requests()
	if not is_inside_tree():
		return
	if requests_response.ok:
		var rows: Variant = requests_response.data.get("requests", [])
		_requests = rows if rows is Array else []
		_pending_count = int(requests_response.data.get("pendingCount", _count_pending_local()))
	var own_response: Dictionary = await ApiClient.admin_own_credit_requests()
	if is_inside_tree() and own_response.ok:
		var own_rows: Variant = own_response.data.get("requests", [])
		_own_requests = own_rows if own_rows is Array else []
	_refresh_alerts()
	if _section == "requests":
		_paint_section()


func _open_notifications() -> void:
	_close_notifications()
	var response: Dictionary = await ApiClient.admin_credit_requests("PENDING")
	if not is_inside_tree():
		return
	var pending_rows: Array = []
	if response.ok:
		var rows: Variant = response.data.get("requests", [])
		pending_rows = rows if rows is Array else []
		_pending_count = int(response.data.get("pendingCount", pending_rows.size()))
		_refresh_alerts()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_notifications()
	)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(mini(size.x - 32.0, 420.0), 0)
	UiTheme.paint_glass(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(panel)
	_notify_panel = dim
	dim.set_meta("center", center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(_pad(box, 18))
	var title := Label.new()
	title.text = "Credit Requests"
	UiTheme.style_title(title, 22)
	box.add_child(title)
	if pending_rows.is_empty():
		box.add_child(_muted("No new credit requests"))
	else:
		for item in pending_rows:
			if not item is Dictionary:
				continue
			var line := Label.new()
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.text = "%s requested %s credits" % [
				str(item.get("username", "Player")),
				_grouped(int(item.get("amount", 0))),
			]
			box.add_child(line)
	var view := _button("View Requests", "PrimaryButton")
	view.pressed.connect(func() -> void:
		_close_notifications()
		_show_section("requests")
	)
	box.add_child(view)
	var close := _button("Close", "")
	close.pressed.connect(_close_notifications)
	box.add_child(close)


func _close_notifications() -> void:
	if _notify_panel == null:
		return
	var center: Node = _notify_panel.get_meta("center", null)
	if center and is_instance_valid(center):
		center.queue_free()
	if is_instance_valid(_notify_panel):
		_notify_panel.queue_free()
	_notify_panel = null


func _admin_name() -> String:
	var username := ApiClient.username()
	return username if username != "" else "Admin"


func _initials(player_name: String) -> String:
	var parts := player_name.split(" ", false)
	if parts.size() >= 2:
		return (str(parts[0]).substr(0, 1) + str(parts[1]).substr(0, 1)).to_upper()
	if parts.is_empty() or str(parts[0]) == "":
		return "AD"
	return str(parts[0]).substr(0, 2).to_upper()


func _grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			grouped = "," + grouped
		grouped = digits[index] + grouped
		count += 1
	return "-" + grouped if negative else grouped


func _pad(child: Control, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, amount)
	margin.add_child(child)
	return margin


func _paint_surface(panel: PanelContainer, kind: String) -> void:
	var bg := Color("141E32")
	var border := Color("31425F")
	var radius := 18
	var shadow := 6
	match kind:
		"header", "section":
			bg = Color("10182A")
			radius = 20
		"kpi":
			bg = Color("141E32")
			radius = 18
		"cell":
			bg = Color("0E1626")
			radius = 14
			shadow = 4
		"icon":
			bg = Color("1B2740")
			border = Color("3A4C6E")
			radius = 12
			shadow = 0
		"badge_on":
			bg = Color("143028")
			border = Color("2E6B52")
			radius = 10
			shadow = 0
		"badge_off":
			bg = Color("2A1E24")
			border = Color("6E3140")
			radius = 10
			shadow = 0
		"badge_mode":
			bg = Color("172438")
			border = Color("31486E")
			radius = 10
			shadow = 0
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	if shadow > 0:
		box.shadow_color = Color(0, 0, 0, 0.28)
		box.shadow_size = shadow
		box.shadow_offset = Vector2(0, 4)
	if kind.begins_with("badge"):
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 6
		box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)


func _kpi_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 4 if size.x >= 1180.0 else (2 if size.x >= 700.0 else 1)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	return grid


func _form_box() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_surface(panel, "section")
	_page.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(_pad(box, 24))
	return box


func _section_box(title: String, link: String, target: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_surface(panel, "section")
	_page.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	panel.add_child(_pad(inner, 20))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	inner.add_child(head)
	var heading := Label.new()
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	head.add_child(heading)
	if link != "" and target != "":
		var view := _compact_button(link, "")
		view.pressed.connect(_show_section.bind(target))
		head.add_child(view)
	return inner


func _icon_box(mark: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(44, 44)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_surface(panel, "icon")
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(44, 44)
	panel.add_child(center)
	var label := Label.new()
	label.text = mark
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiTheme.COL_BLUE)
	center.add_child(label)
	return panel


func _status_badge(active: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_surface(panel, "badge_on" if active else "badge_off")
	var label := Label.new()
	label.text = "●  Active" if active else "●  Inactive"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTheme.COL_GREEN if active else UiTheme.COL_DANGER)
	panel.add_child(label)
	return panel


func _empty_state(title: String, detail: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_icon_box("–"))
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)
	var copy := Label.new()
	copy.text = detail
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(copy)
	box.add_child(copy)
	return box


func _compact_button(text: String, variation: String) -> Button:
	var button := _button(text, variation)
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	if variation == "PrimaryButton":
		_paint_compact_primary(button)
	return button


func _paint_compact_primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = UiTheme.COL_GOLD_DARK if state == "pressed" else UiTheme.COL_GOLD
		box.border_color = UiTheme.COL_GOLD_SOFT
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", UiTheme.COL_INK)
	button.add_theme_color_override("font_hover_color", UiTheme.COL_INK)
	button.add_theme_color_override("font_pressed_color", UiTheme.COL_INK)
	button.add_theme_color_override("font_focus_color", UiTheme.COL_INK)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UiTheme.style_title(label, 22)
	return label


func _retry_button() -> Button:
	var retry := _button("Try again", "PrimaryButton")
	retry.custom_minimum_size = Vector2(160, 48)
	retry.pressed.connect(_load_all)
	return retry


func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(label)
	return label


func _button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	if variation != "":
		button.theme_type_variation = variation
	return button


func _field(placeholder: String, secret := false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 50)
	field.secret = secret
	return field


func _count_active() -> int:
	var count := 0
	for player in _players:
		if player is Dictionary and bool(player.get("isActive", false)):
			count += 1
	return count


func _sum_credits() -> int:
	var total := 0
	for player in _players:
		if player is Dictionary:
			total += int(player.get("balance", 0))
	return total


func _set_feedback(text: String, is_error: bool) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER if is_error else UiTheme.COL_GREEN)


func _date(value: String) -> String:
	if value.contains("T"):
		return value.split("T")[0]
	return value


func _when(value: String) -> String:
	if value.contains("T"):
		var parts := value.split("T")
		var clock := parts[1].substr(0, 5) if parts.size() > 1 else ""
		return "%s %s" % [parts[0], clock]
	return value


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
