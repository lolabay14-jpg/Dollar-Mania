extends Control

var _overview: Dictionary = {}
var _admins: Array = []
var _players: Array = []
var _transactions: Array = []
var _games: Array = []
var _activity: Array = []
var _page: VBoxContainer
var _results: VBoxContainer
var _column: MarginContainer
var _feedback: Label
var _treasury: Label
var _dialog: Control
var _busy := false
var _loaded := false
var _section := "overview"
var _query := ""
var _painting := false
var _layout_bucket := -1

const _SECTIONS := [
	["overview", "Overview"],
	["credits", "Credits"],
	["admins", "Admins"],
	["players", "Players"],
	["games", "Games"],
	["modes", "Modes"],
	["transactions", "Transactions"],
	["activity", "Activity"],
	["settings", "Settings"],
]


func _ready() -> void:
	if ApiClient.role() != "SUPER_ADMIN":
		AppState.go_login()
		return
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "calm")
	_build()
	resized.connect(_fit)
	_fit()
	_reload()


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_column = MarginContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_column)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	_column.add_child(root)

	var bar := _card()
	root.add_child(bar)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	bar.add_child(_pad(header, 20))
	var title := Label.new()
	title.text = "Super Admin"
	UiTheme.style_title(title, 30)
	header.add_child(title)
	var about := Label.new()
	about.text = "Issue and redeem credits. Balances update only after the server confirms."
	UiTheme.style_muted(about)
	header.add_child(about)
	_treasury = Label.new()
	_treasury.text = "System Credit Control"
	_treasury.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_treasury.add_theme_font_size_override("font_size", 22)
	_treasury.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	header.add_child(_treasury)
	var logout := _button("Logout", "DangerButton")
	logout.pressed.connect(func() -> void:
		ApiClient.logout()
		AppState.go_login()
	)
	header.add_child(logout)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_feedback)

	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 16)
	root.add_child(_page)
	_page.add_child(_muted("Loading system overview..."))


func _fit() -> void:
	if _column:
		ScreenLayout.fit_column(_column, 1100.0)
	if _painting or not _loaded:
		return
	var bucket := 2 if size.x >= 720.0 else (1 if size.x >= 640.0 else 0)
	if bucket == _layout_bucket:
		return
	_layout_bucket = bucket
	_paint()


func _reload() -> void:
	var overview: Dictionary = await ApiClient.admin_overview()
	var staff: Dictionary = await ApiClient.admin_staff()
	var players: Dictionary = await ApiClient.admin_users()
	var transactions: Dictionary = await ApiClient.admin_transactions()
	var games: Dictionary = await ApiClient.admin_games()
	var activity: Dictionary = await ApiClient.admin_activity()
	if not is_inside_tree():
		return
	if not overview.ok or not staff.ok or not players.ok or not transactions.ok:
		if _feedback.text == "":
			_feedback.text = str(overview.get("error", staff.get("error", "The dashboard could not be loaded.")))
			_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_overview = overview.get("data", {})
	_admins = staff.get("data", {}).get("admins", [])
	_players = players.get("data", {}).get("users", [])
	_transactions = transactions.get("data", {}).get("transactions", [])
	_games = games.get("data", {}).get("games", []) if games.ok else []
	_activity = activity.get("data", {}).get("activity", []) if activity.ok else []
	_loaded = true
	_paint()


func _paint() -> void:
	if _painting:
		return
	_painting = true
	for child in _page.get_children():
		child.queue_free()
	_treasury.text = "System Credit Control"
	_page.add_child(_nav())
	match _section:
		"credits":
			_paint_credits()
		"admins":
			_paint_people("ADMIN")
		"players":
			_paint_people("PLAYER")
		"games":
			_paint_games()
		"modes":
			_paint_modes()
		"transactions":
			_paint_transactions()
		"activity":
			_paint_activity()
		"settings":
			_paint_settings()
		_:
			_paint_overview()
	UiMotion.bind_tree(_page)
	UiMotion.fade_in(_page)
	_layout_bucket = 2 if size.x >= 720.0 else (1 if size.x >= 640.0 else 0)
	_painting = false


func _nav() -> Control:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2 if size.x < 720.0 else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for item in _SECTIONS:
		var section := str(item[0])
		var button := _button(str(item[1]), "PrimaryButton" if section == _section else "")
		button.pressed.connect(_select.bind(section))
		grid.add_child(button)
	return grid


func _select(section: String) -> void:
	if _busy or section == _section:
		return
	_section = section
	_paint()


func _paint_overview() -> void:
	_page.add_child(_heading("Overview"))
	var grid := GridContainer.new()
	grid.columns = 1 if size.x < 640.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_page.add_child(grid)
	var admins := int(_overview.get("totalAdmins", _admins.size()))
	var active_admins := int(_overview.get("activeAdmins", 0))
	var players := int(_overview.get("totalPlayers", _players.size()))
	var active_players := int(_overview.get("activePlayers", 0))
	var player_credits := _credits_of(_overview.get("playerCredits", 0))
	var admin_credits := _credits_of(_overview.get("allocatedCredits", 0))
	var games := int(_overview.get("totalGames", _games.size()))
	var active_games := int(_overview.get("activeGames", 0))
	grid.add_child(_stat("Admins", "%s active" % _grouped(active_admins), "%s total" % _grouped(admins)))
	grid.add_child(_stat("Players", "%s active" % _grouped(active_players), "%s total" % _grouped(players)))
	grid.add_child(_stat("Player credits", _grouped(player_credits), "In player wallets"))
	grid.add_child(_stat("Admin credits", _grouped(admin_credits), "In admin wallets"))
	grid.add_child(_stat("Credits in circulation", _grouped(player_credits + admin_credits), "Player and admin wallets"))
	grid.add_child(_stat("Games", "%s active" % _grouped(active_games), "%s in the catalog" % _grouped(games)))
	grid.add_child(_stat("Game sessions", _grouped(int(_overview.get("totalSessions", 0))), "Recorded sessions"))
	grid.add_child(_stat("Spins", _grouped(int(_overview.get("totalSpins", 0))), "Recorded plays"))
	_page.add_child(_heading("Recent transactions"))
	_add_transaction_cards(_transactions, 6)


func _paint_credits() -> void:
	var manage := _card()
	_page.add_child(manage)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	manage.add_child(_pad(box, 18))
	box.add_child(_heading("Credit management"))
	box.add_child(_muted("Recharge issues new credits. Redeem removes them from that account. Super Admin does not spend a wallet."))
	var search := LineEdit.new()
	search.placeholder_text = "Search by email"
	search.text = _query
	search.custom_minimum_size = Vector2(0, 52)
	box.add_child(search)
	var find := _button("Find account", "PrimaryButton")
	find.pressed.connect(func() -> void:
		_query = search.text
		_search(search.text)
	)
	box.add_child(find)


func _paint_people(role: String) -> void:
	var title := "Admins" if role == "ADMIN" else "Players"
	_page.add_child(_heading(title))
	if role == "ADMIN":
		var create := _button("Create admin", "PrimaryButton")
		create.pressed.connect(_create_admin_dialog)
		_page.add_child(create)
	var search := LineEdit.new()
	search.placeholder_text = "Search name, username, or email"
	search.text = _query
	search.custom_minimum_size = Vector2(0, 52)
	search.text_changed.connect(_on_query)
	_page.add_child(search)
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 12)
	_page.add_child(_results)
	_fill_people(role)


func _paint_modes() -> void:
	_page.add_child(_heading("Game modes"))
	_page.add_child(_muted("Each player has one mode. It stays separate from their role."))
	var search := LineEdit.new()
	search.placeholder_text = "Search players"
	search.text = _query
	search.custom_minimum_size = Vector2(0, 52)
	search.text_changed.connect(_on_query)
	_page.add_child(search)
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 12)
	_page.add_child(_results)
	_fill_people("MODE")


func _paint_games() -> void:
	_page.add_child(_heading("Games"))
	_page.add_child(_muted("Availability applies to every player. Difficulty shown here is the value stored for that game."))
	if _games.is_empty():
		_page.add_child(_muted("No games were returned."))
		return
	for game in _games:
		if game is Dictionary:
			_page.add_child(_game_card(game))


func _paint_transactions() -> void:
	_page.add_child(_heading("Transactions"))
	_add_transaction_cards(_transactions, 40)


func _paint_activity() -> void:
	_page.add_child(_heading("Activity"))
	if _activity.is_empty():
		_page.add_child(_muted("No activity yet."))
		return
	var shown := 0
	for row in _activity:
		if not row is Dictionary or shown >= 40:
			continue
		shown += 1
		_page.add_child(_activity_card(row))


func _paint_settings() -> void:
	var card := _card()
	_page.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(_pad(box, 18))
	box.add_child(_heading("Account"))
	box.add_child(_detail("Username", ApiClient.username()))
	box.add_child(_detail("Role", "SUPER ADMIN"))
	box.add_child(_muted("Super Admin issues credits and does not use a personal wallet. Admin accounts spend their own balance. Players can only receive and play."))
	box.add_child(_muted("Game mode is assigned on each player. An admin cannot be promoted to Super Admin from this panel."))


func _on_query(value: String) -> void:
	_query = value
	if _results == null or not is_instance_valid(_results):
		return
	var role := "ADMIN" if _section == "admins" else ("MODE" if _section == "modes" else "PLAYER")
	_fill_people(role)


func _fill_people(role: String) -> void:
	if _results == null:
		return
	for child in _results.get_children():
		_results.remove_child(child)
		child.free()
	var source: Array = _admins if role == "ADMIN" else _players
	var shown := 0
	for user in source:
		if not user is Dictionary or not _matches(user):
			continue
		shown += 1
		if role == "MODE":
			_results.add_child(_mode_card(user))
		elif role == "PLAYER":
			_results.add_child(_player_card(user))
		else:
			_results.add_child(_account_card(user))
	if shown == 0:
		_results.add_child(_muted("No matching accounts."))
	UiMotion.bind_tree(_results)


func _matches(user: Dictionary) -> bool:
	var query := _query.strip_edges().to_lower()
	if query == "":
		return true
	var blob := "%s %s %s" % [
		str(user.get("displayName", "")),
		str(user.get("username", "")),
		str(user.get("email", "")),
	]
	return blob.to_lower().contains(query)


func _account_card(user: Dictionary) -> Control:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(_pad(box, 16))
	var name := str(user.get("displayName", ""))
	if name == "":
		name = str(user.get("username", "Account"))
	var title := Label.new()
	title.text = name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	box.add_child(title)
	box.add_child(_muted(str(user.get("email", ""))))
	var active := bool(user.get("isActive", true))
	box.add_child(_detail("Status", "Active" if active else "Inactive"))
	var credits := Label.new()
	credits.text = "Current credits\n%s" % _grouped(_credits_of(user.get("balance", 0)))
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.clip_text = false
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.add_theme_font_size_override("font_size", 22)
	credits.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	box.add_child(credits)
	var actions := GridContainer.new()
	actions.columns = 2 if size.x < 720.0 else 3
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	var give := _button("Recharge", "PrimaryButton")
	give.pressed.connect(_credit_dialog.bind(user, true))
	var remove := _button("Redeem", "")
	remove.pressed.connect(_credit_dialog.bind(user, false))
	var history := _button("History", "")
	history.pressed.connect(_show_history.bind(user))
	actions.add_child(give)
	actions.add_child(remove)
	actions.add_child(history)
	var access := _button("Deactivate" if active else "Activate", "DangerButton" if active else "")
	access.pressed.connect(_confirm_access.bind(user, not active))
	actions.add_child(access)
	return card


func _player_card(user: Dictionary) -> Control:
	var card := _card()
	card.clip_contents = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(_pad(box, 16))
	var name := str(user.get("displayName", ""))
	if name == "":
		name = str(user.get("username", "Player"))
	var title := Label.new()
	title.text = name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = false
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	box.add_child(title)
	var email := _muted(str(user.get("email", "")))
	email.add_theme_font_size_override("font_size", 16)
	box.add_child(email)
	var active := bool(user.get("isActive", true))
	var status := Label.new()
	status.text = "Active" if active else "Inactive"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = false
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", UiTheme.COL_GREEN if active else UiTheme.COL_DANGER)
	box.add_child(status)
	box.add_child(_credits_panel(user.get("balance", 0)))
	var mode := Label.new()
	mode.text = "Game mode\n%s" % str(user.get("gameMode", "")).capitalize()
	mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode.clip_text = false
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode.add_theme_font_size_override("font_size", 16)
	mode.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	box.add_child(mode)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	var give := _button("Recharge", "PrimaryButton")
	give.pressed.connect(_credit_dialog.bind(user, true))
	var remove := _button("Redeem", "")
	remove.pressed.connect(_credit_dialog.bind(user, false))
	var history := _button("History", "")
	history.pressed.connect(_show_history.bind(user))
	var access := _button("Deactivate" if active else "Activate", "DangerButton" if active else "")
	access.pressed.connect(_confirm_access.bind(user, not active))
	actions.add_child(give)
	actions.add_child(remove)
	actions.add_child(history)
	actions.add_child(access)
	return card


func _credits_panel(balance: Variant) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0E1626")
	style.border_color = Color("3A4C6E")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(inner)
	var caption := Label.new()
	caption.text = "Current Credits"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.clip_text = false
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	inner.add_child(caption)
	var amount := Label.new()
	amount.text = _format_credits(balance)
	amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	amount.clip_text = false
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.custom_minimum_size = Vector2(0, 48)
	amount.add_theme_font_size_override("font_size", 36 if size.x < 720.0 else 42)
	amount.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	inner.add_child(amount)
	return panel


func _mode_card(user: Dictionary) -> Control:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(_pad(box, 16))
	var name := str(user.get("displayName", user.get("username", "Player")))
	box.add_child(_heading(name))
	box.add_child(_muted(str(user.get("email", ""))))
	var current := str(user.get("gameMode", "MEDIUM"))
	box.add_child(_detail("Current mode", current))
	var actions := GridContainer.new()
	actions.columns = 3
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	for mode in ["EASY", "MEDIUM", "HARD"]:
		var button := _button(mode.capitalize(), "PrimaryButton" if mode == current else "")
		button.disabled = mode == current or _busy
		button.pressed.connect(_set_mode.bind(user, mode))
		actions.add_child(button)
	return card


func _game_card(game: Dictionary) -> Control:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(_pad(box, 16))
	var title := Label.new()
	title.text = str(game.get("name", "Game"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var active := bool(game.get("isActive", false))
	box.add_child(_detail("Status", "Available" if active else "Unavailable"))
	box.add_child(_detail("Category", str(game.get("category", ""))))
	box.add_child(_detail("Difficulty", str(game.get("difficulty", ""))))
	box.add_child(_detail("Plays", _grouped(int(game.get("spins", 0)))))
	var toggle := _button("Disable" if active else "Enable", "DangerButton" if active else "PrimaryButton")
	toggle.pressed.connect(_confirm_game.bind(game, not active))
	box.add_child(toggle)
	return card


func _activity_card(row: Dictionary) -> Control:
	var card := _card()
	var line := Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var amount: Variant = row.get("amount", null)
	var amount_text := ""
	if amount != null and str(amount) != "":
		amount_text = "\nAmount %s" % _grouped(_credits_of(amount))
	var target := str(row.get("targetDisplayName", ""))
	if target == "":
		target = str(row.get("targetUsername", ""))
	line.text = "%s\n%s  →  %s\n%s%s" % [
		_when(row.get("createdAt", "")),
		str(row.get("adminUsername", "System")),
		target,
		str(row.get("action", "")),
		amount_text,
	]
	card.add_child(_pad(line, 14))
	return card


func _add_transaction_cards(rows: Array, limit: int) -> void:
	if rows.is_empty():
		_page.add_child(_muted("No transactions yet."))
		return
	var shown := 0
	for row in rows:
		if not row is Dictionary or shown >= limit:
			continue
		shown += 1
		var amount := _credits_of(row.get("amount", 0))
		var card := _card()
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "%s\n%s\n%s%s\n%s" % [
			_when(row.get("createdAt", "")),
			str(row.get("username", "Account")),
			"+" if amount > 0 else "",
			_grouped(amount),
			str(row.get("transactionType", "")),
		]
		card.add_child(_pad(line, 14))
		_page.add_child(card)


func _search(email: String) -> void:
	var response: Dictionary = await ApiClient.admin_search_user(email)
	if not is_inside_tree():
		return
	if not response.ok:
		_note(str(response.get("error", "That account could not be found.")), true)
		return
	var user: Dictionary = response.get("data", {}).get("user", {})
	if str(user.get("role", "")) == "SUPER_ADMIN":
		_note("Super Admin accounts cannot receive credits.", true)
		return
	_credit_dialog(user, true)


func _credit_dialog(user: Dictionary, adding: bool) -> void:
	if _busy or str(user.get("role", "")) == "SUPER_ADMIN":
		return
	var amount := LineEdit.new()
	amount.placeholder_text = "Amount"
	amount.custom_minimum_size = Vector2(0, 52)
	amount.max_length = 7
	var verb := "Recharge" if adding else "Redeem"
	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	amount.text_changed.connect(func(value: String) -> void:
		if value.is_valid_int() and int(value) > 0:
			notice.text = "You are about to %s %s credits." % ["recharge" if adding else "redeem", _grouped(int(value))]
		else:
			notice.text = ""
	)
	_open_dialog(verb, func(inner: VBoxContainer) -> void:
		inner.add_child(_muted(str(user.get("email", ""))))
		var current_credits := _format_credits(user.get("balance", 0)) if str(user.get("role", "")) == "PLAYER" else _grouped(_credits_of(user.get("balance", 0)))
		inner.add_child(_detail("Current Credits", current_credits))
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
		_submit_credits(user, int(text), adding, confirm)
	)


func _submit_credits(user: Dictionary, amount: int, adding: bool, confirm: Button) -> void:
	if _busy:
		return
	_busy = true
	var request_id := "credit-%d-%d" % [Time.get_ticks_msec(), randi() % 1000000]
	var response: Dictionary = await ApiClient.admin_adjust_credits(
		str(user.get("id", "")),
		amount,
		"add" if adding else "remove",
		"",
		request_id
	)
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		if is_instance_valid(confirm):
			confirm.disabled = false
			confirm.text = "Recharge" if adding else "Redeem"
		_note(_credit_error(response), true)
		return
	_close_dialog()
	var data: Dictionary = response.get("data", {})
	var target_balance: Variant = data.get("balance", user.get("balance", 0))
	_store_user_balance(user, target_balance)
	_paint()
	var name := str(user.get("displayName", user.get("username", "that account")))
	if bool(data.get("duplicate", false)):
		_note("That transfer was already recorded.", false)
	elif adding:
		_note("%s credits recharged to %s." % [_grouped(amount), name], false)
	else:
		_note("%s credits successfully redeemed." % _grouped(amount), false)
	await _reload()


func _create_admin_dialog() -> void:
	if _busy:
		return
	var username := LineEdit.new()
	username.placeholder_text = "Username"
	username.custom_minimum_size = Vector2(0, 52)
	var email := LineEdit.new()
	email.placeholder_text = "Email"
	email.custom_minimum_size = Vector2(0, 52)
	var password := LineEdit.new()
	password.placeholder_text = "Password"
	password.secret = true
	password.custom_minimum_size = Vector2(0, 52)
	var confirm_password := LineEdit.new()
	confirm_password.placeholder_text = "Confirm password"
	confirm_password.secret = true
	confirm_password.custom_minimum_size = Vector2(0, 52)
	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_open_dialog("Create admin", func(inner: VBoxContainer) -> void:
		inner.add_child(_muted("The new account is an admin with an empty wallet. Recharge it after it is created."))
		inner.add_child(username)
		inner.add_child(email)
		inner.add_child(password)
		inner.add_child(confirm_password)
		inner.add_child(notice)
	, "Create admin", func(confirm: Button) -> void:
		if _busy or confirm.disabled:
			return
		if username.text.strip_edges().length() < 3 or email.text.strip_edges() == "" or password.text.length() < 8:
			notice.text = "Enter a username, email, and a password of at least 8 characters."
			notice.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		if password.text != confirm_password.text:
			notice.text = "Passwords do not match."
			notice.add_theme_color_override("font_color", UiTheme.COL_DANGER)
			return
		confirm.disabled = true
		confirm.text = "Processing..."
		_submit_admin(username.text.strip_edges(), email.text.strip_edges(), password.text, confirm_password.text, confirm, notice)
	)


func _submit_admin(username: String, email: String, password: String, confirm_password: String, confirm: Button, notice: Label) -> void:
	_busy = true
	var response: Dictionary = await ApiClient.admin_create_admin(username, email, password, confirm_password)
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		if is_instance_valid(confirm):
			confirm.disabled = false
			confirm.text = "Create admin"
		if is_instance_valid(notice):
			notice.text = str(response.get("error", "The admin could not be created."))
			notice.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_close_dialog()
	_note("Admin %s created." % username, false)
	await _reload()


func _confirm_access(user: Dictionary, active: bool) -> void:
	if _busy:
		return
	var verb := "Activate" if active else "Deactivate"
	_open_dialog(verb, func(inner: VBoxContainer) -> void:
		inner.add_child(_muted("%s %s?" % [verb, str(user.get("email", ""))]))
	, verb, func(confirm: Button) -> void:
		if _busy or confirm.disabled:
			return
		confirm.disabled = true
		confirm.text = "Processing..."
		_apply_access(user, active, confirm)
	)


func _apply_access(user: Dictionary, active: bool, confirm: Button) -> void:
	_busy = true
	var response: Dictionary
	if str(user.get("role", "")) == "ADMIN":
		response = await ApiClient.admin_set_staff_active(str(user.get("id", "")), active)
	else:
		response = await ApiClient.admin_update_player(str(user.get("id", "")), {"isActive": active})
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		if is_instance_valid(confirm):
			confirm.disabled = false
			confirm.text = "Activate" if active else "Deactivate"
		_note(str(response.get("error", "The account could not be updated.")), true)
		return
	_close_dialog()
	_note("Account updated.", false)
	await _reload()


func _set_mode(user: Dictionary, mode: String) -> void:
	if _busy:
		return
	_busy = true
	var response: Dictionary = await ApiClient.admin_set_player_game_mode(str(user.get("id", "")), mode)
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		_note(str(response.get("error", "Game mode could not be changed.")), true)
		return
	_note("Game mode set to %s." % mode.capitalize(), false)
	await _reload()


func _confirm_game(game: Dictionary, active: bool) -> void:
	if _busy:
		return
	var verb := "Enable" if active else "Disable"
	_open_dialog(verb, func(inner: VBoxContainer) -> void:
		inner.add_child(_muted("%s %s for every player?" % [verb, str(game.get("name", "this game"))]))
	, verb, func(confirm: Button) -> void:
		if _busy or confirm.disabled:
			return
		confirm.disabled = true
		confirm.text = "Processing..."
		_apply_game(game, active, confirm)
	)


func _apply_game(game: Dictionary, active: bool, confirm: Button) -> void:
	_busy = true
	var response: Dictionary = await ApiClient.admin_set_game_active(str(game.get("id", "")), active)
	_busy = false
	if not is_inside_tree():
		return
	if not response.ok:
		if is_instance_valid(confirm):
			confirm.disabled = false
			confirm.text = "Enable" if active else "Disable"
		_note(str(response.get("error", "The game could not be updated.")), true)
		return
	_close_dialog()
	_note("%s is now %s." % [str(game.get("name", "Game")), "available" if active else "unavailable"], false)
	await _reload()


func _credits_of(value: Variant) -> int:
	if value == null:
		return 0
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
	return message if message != "" else "Transfer failed. Please try again."


func _format_credits(value: Variant) -> String:
	var amount := 0.0
	if value == null:
		amount = 0.0
	elif value is String:
		amount = float(value)
	else:
		amount = float(value)
	var negative := amount < -0.001
	var cents := int(round(absf(amount) * 100.0))
	var whole := int(cents / 100.0)
	var frac := cents % 100
	return "%s%s.%02d" % ["-" if negative else "", _grouped(whole), frac]


func _store_user_balance(user: Dictionary, balance: Variant) -> void:
	var user_id := str(user.get("id", ""))
	for index in _admins.size():
		var row: Variant = _admins[index]
		if row is Dictionary and str(row.get("id", "")) == user_id:
			row["balance"] = balance
			_admins[index] = row
	for index in _players.size():
		var row: Variant = _players[index]
		if row is Dictionary and str(row.get("id", "")) == user_id:
			row["balance"] = balance
			_players[index] = row


func _show_history(user: Dictionary) -> void:
	var player := str(user.get("role", "")) == "PLAYER"
	var response: Dictionary = await ApiClient.admin_player_history(str(user.get("id", ""))) if player else await ApiClient.admin_ledger(str(user.get("id", "")))
	if not is_inside_tree():
		return
	if not response.ok:
		_note(str(response.get("error", "History could not be loaded.")), true)
		return
	var data: Dictionary = response.get("data", {})
	var rows: Array = data.get("transactions", [])
	var spins: Array = data.get("spins", [])
	_open_dialog("History", func(inner: VBoxContainer) -> void:
		inner.add_child(_muted(str(user.get("email", ""))))
		if player:
			inner.add_child(_detail("Game mode", str(data.get("user", {}).get("gameMode", user.get("gameMode", "")))))
		inner.add_child(_heading("Transactions"))
		if rows.is_empty():
			inner.add_child(_muted("No transactions yet."))
		var shown := 0
		for row in rows:
			if not row is Dictionary or shown >= 8:
				continue
			shown += 1
			var amount := _credits_of(row.get("amount", 0))
			var line := Label.new()
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.text = "%s\n%s%s  ·  %s" % [
				_when(row.get("createdAt", "")),
				"+" if amount > 0 else "",
				_grouped(amount),
				str(row.get("transactionType", "")),
			]
			inner.add_child(line)
		if player:
			inner.add_child(_heading("Plays"))
			if spins.is_empty():
				inner.add_child(_muted("No plays yet."))
			shown = 0
			for spin in spins:
				if not spin is Dictionary or shown >= 8:
					continue
				shown += 1
				var play := Label.new()
				play.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				play.text = "%s\n%s  ·  bet %s  ·  win %s" % [
					_when(spin.get("createdAt", "")),
					str(spin.get("gameName", "Game")),
					_grouped(_credits_of(spin.get("betAmount", 0))),
					_grouped(_credits_of(spin.get("winAmount", 0))),
				]
				inner.add_child(play)
	, "", func(_confirm: Button) -> void:
		_close_dialog()
	)


func _open_dialog(title: String, fill: Callable, confirm_text: String, on_confirm: Callable) -> void:
	_close_dialog()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		frame.add_theme_constant_override(side, 16)
	dim.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := _card()
	panel.custom_minimum_size = Vector2(minf(size.x - 48.0, 460.0), 0)
	center.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	panel.add_child(_pad(inner, 20))
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_title(heading, 24)
	inner.add_child(heading)
	fill.call(inner)
	if confirm_text != "":
		var confirm := _button(confirm_text, "PrimaryButton")
		confirm.custom_minimum_size.y = 52
		confirm.pressed.connect(on_confirm.bind(confirm))
		inner.add_child(confirm)
	var cancel := _button("Close" if confirm_text == "" else "Cancel", "")
	cancel.custom_minimum_size.y = 52
	cancel.pressed.connect(_close_dialog)
	inner.add_child(cancel)
	_dialog = dim
	UiMotion.pop_in(panel)
	UiMotion.bind_tree(dim)


func _close_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _note(message: String, danger: bool) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", UiTheme.COL_DANGER if danger else UiTheme.COL_GREEN)


func _stat(label_text: String, value_text: String, note: String) -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(_pad(box, 16))
	var caption := Label.new()
	caption.text = label_text
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.clip_text = false
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_muted(caption)
	box.add_child(caption)
	var number := Label.new()
	number.text = value_text
	number.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	number.clip_text = false
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.add_theme_font_size_override("font_size", 22)
	number.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	box.add_child(number)
	var extra := Label.new()
	extra.text = note
	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra.clip_text = false
	extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_muted(extra)
	box.add_child(extra)
	return card


func _detail(caption: String, value: String) -> Label:
	var label := Label.new()
	label.text = "%s\n%s" % [caption, value]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	return label


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.COL_CARD
	style.border_color = UiTheme.COL_CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _pad(child: Control, margin: int) -> MarginContainer:
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, margin)
	inset.add_child(child)
	return inset


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_title(label, 22)
	return label


func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UiTheme.style_muted(label)
	return label


func _button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	if variation != "":
		button.theme_type_variation = variation
	UiMotion.bind_button(button)
	return button


func _grouped(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	return ("-" if negative else "") + grouped


func _when(value: Variant) -> String:
	var text := str(value)
	if text.length() >= 16:
		return text.substr(0, 16).replace("T", " ")
	return text
