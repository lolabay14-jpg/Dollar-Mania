extends Control

var _selected_player_id := ""

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
	_load()


func _style() -> void:
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
	var activity_response: Dictionary = await ApiClient.admin_transactions()
	if not is_inside_tree():
		return
	if activity_response.ok:
		_rebuild_activity(activity_response.data.get("transactions", []))
	_update_selection_label()


func _rebuild_players(users: Array) -> void:
	_clear(_player_list)
	if users.is_empty():
		var empty := Label.new()
		empty.text = "No players yet."
		UiTheme.style_muted(empty)
		_player_list.add_child(empty)
		_selected_player_id = ""
		return
	var still_selected := false
	for player in users:
		if not player is Dictionary:
			continue
		var player_id := str(player.get("id", ""))
		if player_id == _selected_player_id:
			still_selected = true
		var button := Button.new()
		var label_name := str(player.get("displayName", player.get("username", "Player")))
		button.text = "%s    %d credits" % [label_name, int(player.get("balance", 0))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("player_id", player_id)
		button.set_meta("player_name", label_name)
		button.set_meta("balance", int(player.get("balance", 0)))
		button.theme_type_variation = "SelectedButton" if player_id == _selected_player_id else "Button"
		button.pressed.connect(_select_player.bind(player_id))
		_player_list.add_child(button)
	if not still_selected:
		var first := users[0] as Dictionary
		_selected_player_id = str(first.get("id", ""))
		for child in _player_list.get_children():
			if child is Button and str(child.get_meta("player_id")) == _selected_player_id:
				child.theme_type_variation = "SelectedButton"


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


func _select_player(player_id: String) -> void:
	_selected_player_id = player_id
	_feedback_label.text = ""
	for child in _player_list.get_children():
		if not child is Button:
			continue
		var button := child as Button
		var id := str(button.get_meta("player_id"))
		button.theme_type_variation = "SelectedButton" if id == _selected_player_id else "Button"
	_update_selection_label()


func _update_selection_label() -> void:
	for child in _player_list.get_children():
		if not child is Button:
			continue
		var button := child as Button
		if str(button.get_meta("player_id")) != _selected_player_id:
			continue
		%SelectionLabel.text = "Selected: %s  ·  %d credits" % [
			str(button.get_meta("player_name")),
			int(button.get_meta("balance")),
		]
		return
	%SelectionLabel.text = "Select a player."


func _on_add() -> void:
	_apply_change(true)


func _on_remove() -> void:
	_apply_change(false)


func _apply_change(adding: bool) -> void:
	var amount := _parse_amount()
	if amount < 0:
		_set_feedback("Enter a whole number greater than 0.", true)
		return
	if _selected_player_id == "":
		_set_feedback("Select a player.", true)
		return
	%AddButton.disabled = true
	%RemoveButton.disabled = true
	var action := "add" if adding else "remove"
	var response: Dictionary = await ApiClient.admin_adjust_credits(_selected_player_id, amount, action)
	if not is_inside_tree():
		return
	%AddButton.disabled = false
	%RemoveButton.disabled = false
	if not response.ok:
		_set_feedback(str(response.error), true)
		return
	_amount_input.text = ""
	var verb := "Added" if adding else "Removed"
	_set_feedback("%s %d credits." % [verb, amount], false)
	_load()


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
