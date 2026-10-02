extends Control

var _selected_player_id := ""
var _selected: Dictionary = {}
var _requests: VBoxContainer
var _email_input: LineEdit
var _search_button: Button
var _match: PanelContainer
var _match_label: Label
var _confirm: Control
var _confirm_copy: Label
var _pending_add := true
var _pending_amount := 0
var _searching := false
var _applying := false
var _control_player: Dictionary = {}
var _control_busy := false
var _profiles: Array = []
var _profile_choice := "DEFAULT"
var _control_email: LineEdit
var _control_search: Button
var _control_status: Label
var _control_card: Label
var _controls_box: VBoxContainer
var _game_picker: OptionButton
var _profile_buttons: Array[Button] = []
var _parameter_box: VBoxContainer
var _parameter_inputs: Dictionary = {}
var _profile_current: Label
var _profile_confirm: VBoxContainer
var _profile_confirm_copy: Label
var _save_profile_button: Button
var _reset_profile_button: Button

@onready var _column: MarginContainer = %Column
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _activity_list: VBoxContainer = %ActivityList
@onready var _amount_input: LineEdit = %AmountInput
@onready var _feedback_label: Label = %FeedbackLabel


func _ready() -> void:
	UiTheme.apply(self)
	_style()
	%LogoutButton.pressed.connect(_logout)
	%AddButton.pressed.connect(_on_add)
	%RemoveButton.pressed.connect(_on_remove)
	_amount_input.placeholder_text = "Credit amount"
	_amount_input.max_length = 7
	resized.connect(_fit)
	_fit()
	_ensure_search()
	_ensure_game_controls()
	_ensure_requests()
	_build_confirm()
	_load()


func _style() -> void:
	UiTheme.mood(self, "calm")
	$Background.color = UiTheme.COL_BG
	%AddButton.theme_type_variation = "PrimaryButton"
	%RemoveButton.theme_type_variation = "DangerButton"
	UiTheme.style_title(%ScreenTitle, 30)
	%AdminName.add_theme_font_size_override("font_size", 24)
	UiTheme.style_muted(%AdminMeta)
	UiTheme.style_muted(%StatsLabel)
	UiTheme.style_muted(%PlayersTitle)
	UiTheme.style_muted(%ActivityTitle)
	UiTheme.style_muted(%SelectionLabel)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _fit() -> void:
	ScreenLayout.fit_column(_column, 640.0)


func _logout() -> void:
	ApiClient.logout()
	AppState.go_login()


func _load() -> void:
	%AdminName.text = ApiClient.username() if ApiClient.username() != "" else "Admin"
	%AdminMeta.text = "Platform Admin"
	var users_response: Dictionary = await ApiClient.admin_users()
	if not is_inside_tree():
		return
	if not users_response.ok:
		_set_feedback(str(users_response.error), true)
		%StatsLabel.text = "Could not load players."
		return
	var data: Dictionary = users_response.data
	%StatsLabel.text = "%d players  ·  %d credits in play" % [
		int(data.get("totalPlayers", 0)),
		int(data.get("totalCredits", 0)),
	]
	_rebuild_players(data.get("users", []))
	_show_match()
	var activity_response: Dictionary = await ApiClient.admin_transactions()
	if not is_inside_tree():
		return
	if activity_response.ok:
		_rebuild_activity(activity_response.data.get("transactions", []))
	var requests_response: Dictionary = await ApiClient.admin_credit_requests()
	if is_inside_tree() and requests_response.ok:
		_rebuild_requests(requests_response.data.get("requests", []))
	_update_selection_label()


func _rebuild_players(users: Array) -> void:
	_clear(_player_list)
	if users.is_empty():
		var empty := Label.new()
		empty.text = "No players yet."
		UiTheme.style_muted(empty)
		_player_list.add_child(empty)
		if _selected.is_empty():
			_selected_player_id = ""
		return
	var still_selected := false
	for player in users:
		if not player is Dictionary:
			continue
		var summary := _user_from(player)
		var player_id := str(summary.get("id", ""))
		if player_id == _selected_player_id:
			still_selected = true
			_selected = summary
		var button := Button.new()
		var label_name := str(summary.get("displayName", summary.get("username", "Player")))
		button.text = "%s    %d credits" % [label_name, int(summary.get("balance", 0))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("player_id", player_id)
		button.theme_type_variation = "SelectedButton" if player_id == _selected_player_id else "Button"
		button.pressed.connect(_select_user.bind(summary))
		_player_list.add_child(button)


func _rebuild_activity(transactions: Array) -> void:
	_clear(_activity_list)
	if transactions.is_empty():
		var empty := Label.new()
		empty.text = "No credit activity yet."
		UiTheme.style_muted(empty)
		_activity_list.add_child(empty)
		return
	for transaction in transactions:
		if not transaction is Dictionary:
			continue
		var amount := int(transaction.get("amount", 0))
		var sign := "+" if amount > 0 else ""
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var player_name := str(transaction.get("displayName", transaction.get("username", "Player")))
		row.text = "%s   %s   %s%d   %s" % [
			_short_time(str(transaction.get("createdAt", ""))),
			player_name,
			sign,
			amount,
			str(transaction.get("description", "")),
		]
		_activity_list.add_child(row)


func _ensure_requests() -> void:
	var content := _player_list.get_parent()
	var title := Label.new()
	title.text = "Credit requests"
	UiTheme.style_muted(title)
	var index := %ActivityTitle.get_index()
	content.add_child(title)
	content.move_child(title, index)
	_requests = VBoxContainer.new()
	_requests.add_theme_constant_override("separation", 8)
	content.add_child(_requests)
	content.move_child(_requests, index + 1)


func _rebuild_requests(requests: Array) -> void:
	_clear(_requests)
	var pending := 0
	for item in requests:
		if not item is Dictionary or str(item.get("status", "")) != "PENDING":
			continue
		pending += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s    %s credits" % [str(item.get("username", "Player")), str(int(item.get("amount", 0)))]
		row.add_child(label)
		var request_id := str(item.get("id", ""))
		var approve := Button.new()
		approve.text = "Approve"
		approve.theme_type_variation = "PrimaryButton"
		approve.pressed.connect(_review_request.bind(request_id, "approve"))
		row.add_child(approve)
		var reject := Button.new()
		reject.text = "Reject"
		reject.pressed.connect(_review_request.bind(request_id, "reject"))
		row.add_child(reject)
		_requests.add_child(row)
	if pending == 0:
		var empty := Label.new()
		empty.text = "No pending credit requests."
		UiTheme.style_muted(empty)
		_requests.add_child(empty)


func _review_request(request_id: String, action: String) -> void:
	var response: Dictionary = await ApiClient.admin_review_request(request_id, action)
	if not is_inside_tree():
		return
	if not response.ok:
		_set_feedback(str(response.error), true)
		return
	_set_feedback("Credit request %s." % action, false)
	await _load()


func _ensure_search() -> void:
	var content := _player_list.get_parent()
	var index := %PlayersTitle.get_index()
	var title := Label.new()
	title.text = "Search User by Email"
	UiTheme.style_muted(title)
	content.add_child(title)
	content.move_child(title, index)
	_email_input = LineEdit.new()
	_email_input.placeholder_text = "name@email.com"
	_email_input.custom_minimum_size = Vector2(0, 48)
	_email_input.text_submitted.connect(func(_text: String) -> void: _search_email())
	content.add_child(_email_input)
	content.move_child(_email_input, index + 1)
	_search_button = Button.new()
	_search_button.text = "Search"
	_search_button.theme_type_variation = "PrimaryButton"
	_search_button.custom_minimum_size = Vector2(0, 48)
	_search_button.pressed.connect(_search_email)
	content.add_child(_search_button)
	content.move_child(_search_button, index + 2)
	_match = PanelContainer.new()
	_match.visible = false
	UiTheme.paint_glass(_match)
	content.add_child(_match)
	content.move_child(_match, index + 3)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 14)
	_match.add_child(inset)
	_match_label = Label.new()
	_match_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_match_label.add_theme_font_size_override("font_size", 18)
	inset.add_child(_match_label)


func _search_email() -> void:
	if _searching:
		return
	var email := _email_input.text.strip_edges()
	if email.is_empty() or not email.contains("@") or not email.contains("."):
		_set_feedback("Enter a valid email.", true)
		return
	_searching = true
	_search_button.disabled = true
	var response: Dictionary = await ApiClient.admin_search_user(email)
	_searching = false
	if not is_inside_tree():
		return
	_search_button.disabled = false
	if not response.ok:
		_set_feedback(str(response.error), true)
		return
	var user: Dictionary = response.data.get("user", {})
	if user.is_empty():
		_set_feedback("No user found with that email.", true)
		return
	_select_user(_user_from(user))
	_set_feedback("User found.", false)


func _select_user(user: Dictionary) -> void:
	_selected = user
	_selected_player_id = str(user.get("id", ""))
	for child in _player_list.get_children():
		if not child is Button:
			continue
		var button := child as Button
		button.theme_type_variation = "SelectedButton" if str(button.get_meta("player_id")) == _selected_player_id else "Button"
	_show_match()
	_update_selection_label()


func _show_match() -> void:
	if _match == null:
		return
	if _selected.is_empty():
		_match.visible = false
		return
	_match.visible = true
	_match_label.text = "Username: %s\nEmail: %s\nRole: %s\nCredits: %d" % [
		str(_selected.get("username", "")),
		str(_selected.get("email", "")),
		str(_selected.get("role", "")),
		int(_selected.get("balance", 0)),
	]


func _user_from(player: Dictionary) -> Dictionary:
	var username := str(player.get("username", "Player"))
	return {
		"id": str(player.get("id", "")),
		"username": username,
		"email": str(player.get("email", "")),
		"role": str(player.get("role", "")),
		"balance": int(player.get("balance", 0)),
		"displayName": str(player.get("displayName", username)),
	}


func _update_selection_label() -> void:
	if _selected.is_empty():
		%SelectionLabel.text = "Search for a user by email."
		return
	%SelectionLabel.text = "Selected: %s  ·  %s" % [
		str(_selected.get("username", "")),
		str(_selected.get("email", "")),
	]


func _on_add() -> void:
	_apply_change(true)


func _on_remove() -> void:
	_apply_change(false)


func _apply_change(adding: bool) -> void:
	if _applying:
		return
	var amount := _parse_amount()
	if amount < 0:
		_set_feedback("Enter a whole number greater than 0.", true)
		return
	if _selected_player_id == "" or _selected.is_empty():
		_set_feedback("Search for a user by email.", true)
		return
	_pending_add = adding
	_pending_amount = amount
	var verb := "Add" if adding else "Remove"
	_confirm_copy.text = "%s %d credits for this user?\n\nUsername: %s\nEmail: %s\nRole: %s\nCurrent Credits: %d" % [
		verb,
		amount,
		str(_selected.get("username", "")),
		str(_selected.get("email", "")),
		str(_selected.get("role", "")),
		int(_selected.get("balance", 0)),
	]
	_confirm.visible = true


func _confirm_change() -> void:
	if _applying or _selected_player_id == "":
		return
	_applying = true
	_confirm.visible = false
	%AddButton.disabled = true
	%RemoveButton.disabled = true
	var adding := _pending_add
	var amount := _pending_amount
	var action := "add" if adding else "remove"
	var response: Dictionary = await ApiClient.admin_adjust_credits(_selected_player_id, amount, action)
	if not is_inside_tree():
		return
	%AddButton.disabled = false
	%RemoveButton.disabled = false
	_applying = false
	if not response.ok:
		_set_feedback(str(response.error), true)
		return
	_selected["balance"] = int(response.data.get("balance", _selected.get("balance", 0)))
	_show_match()
	_amount_input.text = ""
	var verb := "Added" if adding else "Removed"
	_set_feedback("%s %d credits for %s." % [verb, amount, str(_selected.get("username", "user"))], false)
	await _load()


func _build_confirm() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	UiTheme.paint_glass(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 16)
	box.add_child(inset)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inset.add_child(inner)
	var heading := Label.new()
	heading.text = "Confirm credit change"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_title(heading, 24)
	inner.add_child(heading)
	_confirm_copy = Label.new()
	_confirm_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_confirm_copy)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.theme_type_variation = "PrimaryButton"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.pressed.connect(_confirm_change)
	inner.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.pressed.connect(func() -> void: _confirm.visible = false)
	inner.add_child(cancel)
	_confirm = dim


func _ensure_game_controls() -> void:
	var content := _player_list.get_parent()
	var index := %ActivityTitle.get_index()
	var title := Label.new()
	title.text = "Admin Game Controls"
	UiTheme.style_muted(title)
	content.add_child(title)
	content.move_child(title, index)
	var card := PanelContainer.new()
	UiTheme.paint_glass(card)
	content.add_child(card)
	content.move_child(card, index + 1)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 14)
	card.add_child(inset)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inset.add_child(box)
	var search_label := Label.new()
	search_label.text = "Search Player by Email"
	UiTheme.style_muted(search_label)
	box.add_child(search_label)
	_control_email = LineEdit.new()
	_control_email.placeholder_text = "player@email.com"
	_control_email.custom_minimum_size = Vector2(0, 48)
	_control_email.text_submitted.connect(func(_text: String) -> void: _search_control_player())
	box.add_child(_control_email)
	_control_search = Button.new()
	_control_search.text = "Search"
	_control_search.theme_type_variation = "PrimaryButton"
	_control_search.custom_minimum_size = Vector2(0, 48)
	_control_search.pressed.connect(_search_control_player)
	box.add_child(_control_search)
	_control_status = Label.new()
	_control_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_control_status)
	_control_card = Label.new()
	_control_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_control_card.add_theme_font_size_override("font_size", 18)
	_control_card.visible = false
	box.add_child(_control_card)
	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 10)
	_controls_box.visible = false
	box.add_child(_controls_box)
	_game_picker = OptionButton.new()
	_game_picker.custom_minimum_size = Vector2(0, 48)
	_game_picker.item_selected.connect(func(_item: int) -> void: _show_profile_editor())
	_controls_box.add_child(_game_picker)
	_profile_current = Label.new()
	_profile_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_current.text = "Select a game."
	_controls_box.add_child(_profile_current)
	var levels := HFlowContainer.new()
	levels.add_theme_constant_override("h_separation", 8)
	levels.add_theme_constant_override("v_separation", 8)
	_controls_box.add_child(levels)
	for level in ["EASY", "MEDIUM", "HARD", "DEFAULT"]:
		var button := Button.new()
		button.text = level
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_choose_profile.bind(level))
		levels.add_child(button)
		_profile_buttons.append(button)
	_parameter_box = VBoxContainer.new()
	_parameter_box.add_theme_constant_override("separation", 8)
	_controls_box.add_child(_parameter_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_controls_box.add_child(actions)
	_save_profile_button = Button.new()
	_save_profile_button.text = "Save Profile"
	_save_profile_button.theme_type_variation = "PrimaryButton"
	_save_profile_button.custom_minimum_size = Vector2(0, 48)
	_save_profile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_profile_button.disabled = true
	_save_profile_button.pressed.connect(_ask_save_profile)
	actions.add_child(_save_profile_button)
	_reset_profile_button = Button.new()
	_reset_profile_button.text = "Reset"
	_reset_profile_button.custom_minimum_size = Vector2(0, 48)
	_reset_profile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_profile_button.disabled = true
	_reset_profile_button.pressed.connect(_ask_reset_profile)
	actions.add_child(_reset_profile_button)
	_profile_confirm = VBoxContainer.new()
	_profile_confirm.visible = false
	_profile_confirm.add_theme_constant_override("separation", 8)
	_controls_box.add_child(_profile_confirm)
	_profile_confirm_copy = Label.new()
	_profile_confirm_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_confirm.add_child(_profile_confirm_copy)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	_profile_confirm.add_child(confirm_row)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.theme_type_variation = "PrimaryButton"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm_profile)
	confirm_row.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _profile_confirm.visible = false)
	confirm_row.add_child(cancel)


func _search_control_player() -> void:
	if _control_busy:
		return
	var email := _control_email.text.strip_edges()
	if email.is_empty() or not email.contains("@") or not email.contains("."):
		_set_control_status("Enter a valid email.", true)
		return
	_set_control_busy(true, "Searching...")
	var response: Dictionary = await ApiClient.admin_find_player(email)
	if not is_inside_tree():
		return
	if not response.ok:
		_set_control_busy(false)
		if int(response.get("status", 0)) == 404:
			_clear_control_player()
			_set_control_status("Player not found", true)
		else:
			_set_control_status(str(response.get("error", "Request failed.")), true)
		return
	var player: Dictionary = response.data.get("player", {})
	if str(player.get("role", "")) != "PLAYER":
		_set_control_busy(false)
		_set_control_status(str(response.get("error", "Admin accounts cannot be used for game controls.")), true)
		return
	_control_player = player
	_show_control_player()
	_set_control_status("Loading settings...", false)
	var loaded := await _load_control_profiles(true)
	if not is_inside_tree():
		return
	_set_control_busy(false)
	if loaded:
		_controls_box.visible = true
		_show_profile_editor()
		_set_control_status("", false)


func _load_control_profiles(select_first: bool) -> bool:
	var player_id := str(_control_player.get("id", ""))
	if player_id == "":
		return false
	var previous := ""
	if not select_first and _game_picker.selected >= 0 and _game_picker.item_count > 0:
		previous = str(_game_picker.get_item_metadata(_game_picker.selected))
	var response: Dictionary = await ApiClient.admin_game_profiles(player_id)
	if not is_inside_tree():
		return false
	if str(_control_player.get("id", "")) != player_id:
		return false
	if not response.ok:
		_set_control_status(str(response.get("error", "Request failed.")), true)
		return false
	_profiles = response.data.get("profiles", [])
	_game_picker.set_block_signals(true)
	_game_picker.clear()
	var select_index := 0
	for index in _profiles.size():
		var entry: Dictionary = _profiles[index]
		_game_picker.add_item(str(entry.get("gameName", "Game")))
		_game_picker.set_item_metadata(index, str(entry.get("gameId", "")))
		if str(entry.get("gameId", "")) == previous:
			select_index = index
	if not _profiles.is_empty():
		_game_picker.select(select_index)
	_game_picker.set_block_signals(false)
	return true


func _show_control_player() -> void:
	_control_card.visible = true
	_control_card.text = "Username: %s\nEmail: %s\nCurrent credits: %s\nPlayer status: %s" % [
		str(_control_player.get("username", "")),
		str(_control_player.get("email", "")),
		str(_control_player.get("credits", 0)),
		str(_control_player.get("status", "")),
	]


func _clear_control_player() -> void:
	_control_player = {}
	_profiles = []
	_control_card.visible = false
	_controls_box.visible = false
	if _game_picker:
		_game_picker.clear()


func _set_control_busy(busy: bool, message := "") -> void:
	_control_busy = busy
	_control_search.disabled = busy
	_control_search.text = "Searching..." if message == "Searching..." else "Search"
	_control_email.editable = not busy
	if busy:
		_game_picker.disabled = true
		_save_profile_button.disabled = true
		_reset_profile_button.disabled = true
		for button in _profile_buttons:
			button.disabled = true
	if message != "":
		_set_control_status(message, false)


func _set_control_status(text: String, is_error: bool) -> void:
	_control_status.text = text
	_control_status.add_theme_color_override(
		"font_color",
		UiTheme.COL_DANGER if is_error else UiTheme.COL_MUTED
	)


func _current_profile() -> Dictionary:
	if _game_picker == null or _game_picker.selected < 0:
		return {}
	var game_id := str(_game_picker.get_item_metadata(_game_picker.selected))
	for entry in _profiles:
		if entry is Dictionary and str(entry.get("gameId", "")) == game_id:
			return entry
	return {}


func _choose_profile(level: String) -> void:
	_profile_choice = level
	for button in _profile_buttons:
		button.set_pressed_no_signal(button.text == level)
	for key in _parameter_inputs:
		var spin: SpinBox = _parameter_inputs[key]
		spin.editable = level != "DEFAULT"


func _show_profile_editor() -> void:
	var entry := _current_profile()
	_clear(_parameter_box)
	_parameter_inputs.clear()
	_profile_confirm.visible = false
	if entry.is_empty():
		_profile_current.text = "Select a game."
		_save_profile_button.disabled = true
		_reset_profile_button.disabled = true
		for button in _profile_buttons:
			button.disabled = true
			button.set_pressed_no_signal(false)
		return
	var assigned := str(entry.get("assignedProfile", "DEFAULT"))
	_choose_profile(assigned)
	for button in _profile_buttons:
		button.disabled = false
	_save_profile_button.disabled = false
	_reset_profile_button.disabled = assigned == "DEFAULT"
	var lines := "Current profile: %s\nGame difficulty: %s" % [assigned, str(entry.get("gameDifficulty", ""))]
	if assigned == "DEFAULT":
		lines += "\nThis player uses the game's standard difficulty and rewards."
	var parameters: Dictionary = entry.get("parameters", {})
	for definition in entry.get("parameterDefs", []):
		if not definition is Dictionary:
			continue
		var key := str(definition.get("key", ""))
		var step := float(definition.get("step", 1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = str(definition.get("label", key))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = float(definition.get("min", 0))
		spin.max_value = float(definition.get("max", 1))
		spin.step = step
		spin.rounded = step >= 1.0
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.value = float(parameters.get(key, definition.get("defaultValue", 0)))
		spin.custom_minimum_size = Vector2(150, 40)
		spin.editable = assigned != "DEFAULT"
		row.add_child(spin)
		_parameter_box.add_child(row)
		_parameter_inputs[key] = spin
		lines += "\n%s: %s" % [str(definition.get("label", key)), _format_param(spin.value, step)]
	_profile_current.text = lines


func _ask_save_profile() -> void:
	var entry := _current_profile()
	if entry.is_empty() or _control_player.is_empty() or _control_busy:
		_set_control_status("Search for a player by email.", true)
		return
	_profile_confirm.set_meta("reset", false)
	_profile_confirm_copy.text = "Set %s to %s for %s (%s)?" % [
		str(entry.get("gameName", "this game")),
		_profile_choice,
		str(_control_player.get("username", "")),
		str(_control_player.get("email", "")),
	]
	_profile_confirm.visible = true


func _ask_reset_profile() -> void:
	var entry := _current_profile()
	if entry.is_empty() or _control_player.is_empty() or _control_busy:
		return
	_profile_confirm.set_meta("reset", true)
	_profile_confirm_copy.text = "Reset %s to DEFAULT for %s (%s)?" % [
		str(entry.get("gameName", "this game")),
		str(_control_player.get("username", "")),
		str(_control_player.get("email", "")),
	]
	_profile_confirm.visible = true


func _confirm_profile() -> void:
	if _control_busy:
		return
	var entry := _current_profile()
	var player_id := str(_control_player.get("id", ""))
	if entry.is_empty() or player_id == "":
		return
	_profile_confirm.visible = false
	_set_control_busy(true, "Saving...")
	var resetting := bool(_profile_confirm.get_meta("reset", false))
	var level := "DEFAULT" if resetting else _profile_choice
	var parameters := {}
	if level != "DEFAULT":
		for key in _parameter_inputs:
			var spin: SpinBox = _parameter_inputs[key]
			parameters[key] = float(int(round(spin.value))) if spin.step >= 1.0 else snapped(spin.value, spin.step)
	var response: Dictionary = await ApiClient.admin_set_game_profile(
		player_id,
		str(entry.get("gameId", "")),
		level,
		parameters
	)
	if not is_inside_tree():
		return
	if str(_control_player.get("id", "")) != player_id:
		_set_control_busy(false)
		return
	if not response.ok:
		_set_control_busy(false)
		_set_control_status(str(response.get("error", "Request failed.")), true)
		_show_profile_editor()
		return
	var loaded := await _load_control_profiles(false)
	if not is_inside_tree():
		return
	_set_control_busy(false)
	_show_profile_editor()
	if loaded:
		_set_control_status("Saved for %s." % str(_control_player.get("username", "player")), false)


func _format_param(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(value)))
	return "%0.2f" % value


func _parse_amount() -> int:
	var text := _amount_input.text.strip_edges()
	if text.is_empty() or not text.is_valid_int():
		return -1
	return int(text)


func _set_feedback(text: String, is_error: bool) -> void:
	_feedback_label.text = text
	_feedback_label.add_theme_color_override("font_color", UiTheme.COL_DANGER if is_error else UiTheme.COL_GREEN)


func _short_time(value: String) -> String:
	if value.contains("T"):
		return value.split("T")[1].substr(0, 8)
	return value


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
