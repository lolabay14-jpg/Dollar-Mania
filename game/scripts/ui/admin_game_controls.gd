extends VBoxContainer

var _player: Dictionary = {}
var _profiles: Array = []
var _profile_choice := "DEFAULT"
var _busy := false
var _game_picker: OptionButton
var _profile_buttons: Array[Button] = []
var _parameter_box: VBoxContainer
var _parameter_inputs: Dictionary = {}
var _profile_current: Label
var _status: Label
var _save_button: Button
var _reset_button: Button
var _confirm: VBoxContainer
var _confirm_copy: Label


func setup(player: Dictionary) -> void:
	_player = player
	add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Game controls"
	UiTheme.style_title(title, 22)
	add_child(title)
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "%s  ·  %s" % [str(player.get("username", "")), str(player.get("email", ""))]
	UiTheme.style_muted(summary)
	add_child(summary)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_game_picker = OptionButton.new()
	_game_picker.custom_minimum_size = Vector2(0, 48)
	_game_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_picker.item_selected.connect(func(_index: int) -> void: _show_editor())
	add_child(_game_picker)
	_profile_current = Label.new()
	_profile_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_current.text = "Loading game settings..."
	add_child(_profile_current)
	var levels := HFlowContainer.new()
	levels.add_theme_constant_override("h_separation", 8)
	levels.add_theme_constant_override("v_separation", 8)
	add_child(levels)
	for level in ["EASY", "MEDIUM", "HARD", "DEFAULT"]:
		var button := Button.new()
		button.text = level
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(120, 48)
		button.pressed.connect(_choose_profile.bind(level))
		levels.add_child(button)
		_profile_buttons.append(button)
	_parameter_box = VBoxContainer.new()
	_parameter_box.add_theme_constant_override("separation", 8)
	add_child(_parameter_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	_save_button = Button.new()
	_save_button.text = "Save Profile"
	_save_button.theme_type_variation = "PrimaryButton"
	_save_button.custom_minimum_size = Vector2(0, 48)
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.disabled = true
	_save_button.pressed.connect(_ask_save)
	actions.add_child(_save_button)
	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.custom_minimum_size = Vector2(0, 48)
	_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_button.disabled = true
	_reset_button.pressed.connect(_ask_reset)
	actions.add_child(_reset_button)
	_confirm = VBoxContainer.new()
	_confirm.visible = false
	_confirm.add_theme_constant_override("separation", 8)
	add_child(_confirm)
	_confirm_copy = Label.new()
	_confirm_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.add_child(_confirm_copy)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	_confirm.add_child(confirm_row)
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
	cancel.pressed.connect(func() -> void: _confirm.visible = false)
	confirm_row.add_child(cancel)
	_load_profiles(true)


func _load_profiles(select_first: bool) -> void:
	var player_id := str(_player.get("id", ""))
	if player_id == "":
		return
	var previous := ""
	if not select_first and _game_picker.selected >= 0:
		previous = str(_game_picker.get_item_metadata(_game_picker.selected))
	_set_busy(true, "Loading settings...")
	var response: Dictionary = await ApiClient.admin_game_profiles(player_id)
	if not is_inside_tree() or str(_player.get("id", "")) != player_id:
		return
	_set_busy(false)
	if not response.ok:
		_set_status(str(response.get("error", "Could not load game settings.")), true)
		return
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
	_show_editor()
	_set_status("", false)


func _current_profile() -> Dictionary:
	if _game_picker.selected < 0:
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


func _show_editor() -> void:
	var entry := _current_profile()
	_clear(_parameter_box)
	_parameter_inputs.clear()
	_confirm.visible = false
	if entry.is_empty():
		_profile_current.text = "No games are available for this player."
		_save_button.disabled = true
		_reset_button.disabled = true
		for button in _profile_buttons:
			button.disabled = true
			button.set_pressed_no_signal(false)
		return
	var assigned := str(entry.get("assignedProfile", "DEFAULT"))
	_choose_profile(assigned)
	for button in _profile_buttons:
		button.disabled = _busy
	_save_button.disabled = _busy
	_reset_button.disabled = _busy or assigned == "DEFAULT"
	var lines := "Current profile: %s" % assigned
	if assigned == "DEFAULT":
		lines += "\nThis game follows the mode assigned to this player."
	else:
		lines += "\nThis game uses its own profile instead of the player's mode."
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
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		spin.custom_minimum_size = Vector2(140, 48)
		spin.editable = assigned != "DEFAULT" and not _busy
		row.add_child(spin)
		_parameter_box.add_child(row)
		_parameter_inputs[key] = spin
		lines += "\n%s: %s" % [str(definition.get("label", key)), _format_param(spin.value, step)]
	_profile_current.text = lines


func _ask_save() -> void:
	var entry := _current_profile()
	if entry.is_empty() or _busy:
		return
	_confirm.set_meta("reset", false)
	_confirm_copy.text = "Set %s to %s for %s?" % [
		str(entry.get("gameName", "this game")),
		_profile_choice,
		str(_player.get("username", "")),
	]
	_confirm.visible = true


func _ask_reset() -> void:
	var entry := _current_profile()
	if entry.is_empty() or _busy:
		return
	_confirm.set_meta("reset", true)
	_confirm_copy.text = "Reset %s to DEFAULT for %s?" % [
		str(entry.get("gameName", "this game")),
		str(_player.get("username", "")),
	]
	_confirm.visible = true


func _confirm_profile() -> void:
	if _busy:
		return
	var entry := _current_profile()
	var player_id := str(_player.get("id", ""))
	if entry.is_empty() or player_id == "":
		return
	_confirm.visible = false
	_set_busy(true, "Saving...")
	var resetting := bool(_confirm.get_meta("reset", false))
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
	if not is_inside_tree() or str(_player.get("id", "")) != player_id:
		return
	if not response.ok:
		_set_busy(false)
		_set_status(str(response.get("error", "Could not save the profile.")), true)
		_show_editor()
		return
	await _load_profiles(false)
	if is_inside_tree():
		_set_status("Saved for %s." % str(_player.get("username", "player")), false)


func _set_busy(busy: bool, message := "") -> void:
	_busy = busy
	_game_picker.disabled = busy
	_save_button.disabled = busy
	_reset_button.disabled = busy
	for button in _profile_buttons:
		button.disabled = busy
	if message != "":
		_set_status(message, false)


func _set_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.COL_DANGER if is_error else UiTheme.COL_GREEN)


func _format_param(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(value)))
	return "%0.2f" % value


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()
