extends Control

@onready var _column: MarginContainer = %Column

var _game_id := ""
var _slug := ""
var _name := "Game"
var _difficulty := ""
var _description := ""
var _min := 1
var _max := 1
var _bet := 1
var _choice: Variant = null
var _busy := false

var _title: Label
var _credits: Label
var _meta: Label
var _board: VBoxContainer
var _bet_label: Label
var _play: Button
var _status: Label
var _result: Label
var _reels: Array = []
var _wheel: WheelFace
var _coin_label: Label
var _choice_buttons: Array[Button] = []
var _choice_values: Array = []
var _cell_labels: Array[Label] = []
var _burst_fill: ColorRect


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	_build_shell()
	resized.connect(_fit)
	_fit()
	_load_game()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 760.0)


func _load_game() -> void:
	_status.text = "Loading game..."
	_play.disabled = true
	var listing: Dictionary = await ApiClient.get_slot_games()
	if not is_inside_tree():
		return
	if listing.ok:
		for game in listing.data.get("games", []):
			if game is Dictionary and _is_selected(game):
				_apply_game(game)
				break
	if _game_id == "":
		_apply_game(AppState.selected_game)
	if _game_id == "":
		_game_id = _slug
	var wallet: Dictionary = await ApiClient.get_wallet()
	if not is_inside_tree():
		return
	if wallet.ok:
		_credits.text = "Credits  %s" % _amount(wallet.data.get("balance", 0))
	_show_heading()
	_build_board()
	_refresh_bet()
	if _game_id == "":
		_status.text = "This game is not available."
		_play.disabled = true
	elif not listing.ok and _slug == "":
		_status.text = str(listing.error)
		_play.disabled = true
	else:
		_status.text = "Ready"
		_play.disabled = false
	await get_tree().process_frame
	if is_inside_tree():
		UiMotion.settle(_column)


func _is_selected(game: Dictionary) -> bool:
	var slug := str(game.get("slug", ""))
	var game_id := str(game.get("id", ""))
	var wanted_slug := str(AppState.selected_game.get("slug", AppState.selected_slot_id))
	var wanted_id := str(AppState.selected_game.get("id", ""))
	if wanted_id != "" and game_id == wanted_id:
		return true
	return wanted_slug != "" and slug == wanted_slug


func _apply_game(game: Dictionary) -> void:
	_game_id = str(game.get("id", ""))
	_slug = str(game.get("slug", AppState.selected_slot_id))
	_name = str(game.get("name", "Game"))
	_difficulty = str(game.get("difficulty", ""))
	_description = str(game.get("description", ""))
	_min = maxi(int(game.get("minimumBet", game.get("min_bet", 1))), 1)
	_max = maxi(int(game.get("maximumBet", game.get("max_bet", _min))), _min)
	_bet = _min


func _build_shell() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	var back := Button.new()
	back.text = "Games"
	back.custom_minimum_size = Vector2(96, 48)
	back.pressed.connect(AppState.go_slots)
	header.add_child(back)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_title(_title, 30)
	header.add_child(_title)

	_credits = Label.new()
	_credits.text = "Credits"
	_credits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits.add_theme_font_size_override("font_size", 20)
	_credits.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	header.add_child(_credits)

	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_meta)
	box.add_child(_meta)

	var panel := PanelContainer.new()
	box.add_child(panel)
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 16)
	panel.add_child(inset)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 12)
	_board.alignment = BoxContainer.ALIGNMENT_CENTER
	inset.add_child(_board)

	var bets := HBoxContainer.new()
	bets.alignment = BoxContainer.ALIGNMENT_CENTER
	bets.add_theme_constant_override("separation", 10)
	box.add_child(bets)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(52, 48)
	minus.pressed.connect(_change_bet.bind(-1))
	bets.add_child(minus)
	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(180, 0)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bet_label.add_theme_font_size_override("font_size", 20)
	bets.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(52, 48)
	plus.pressed.connect(_change_bet.bind(1))
	bets.add_child(plus)

	_play = Button.new()
	_play.theme_type_variation = "PrimaryButton"
	_play.custom_minimum_size = Vector2(0, 52)
	_play.pressed.connect(_on_play)
	box.add_child(_play)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_status)
	box.add_child(_status)

	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 28)
	_result.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	box.add_child(_result)
	UiMotion.bind_tree(box)


func _show_heading() -> void:
	_title.text = _name
	var detail := _description
	if _difficulty != "":
		detail = "%s   ·   %s" % [_difficulty, _description] if _description != "" else _difficulty
	_meta.text = detail


func _build_board() -> void:
	for child in _board.get_children():
		child.queue_free()
	_reels.clear()
	_choice_buttons.clear()
	_choice_values.clear()
	_cell_labels.clear()
	_wheel = null
	_coin_label = null
	_burst_fill = null
	_choice = null
	match _slug:
		"lucky-dollar":
			_build_reels(3)
		"golden-fortune":
			_build_reels(5)
		"dollar-rush":
			_build_choices(["Lane 1", "Lane 2", "Lane 3"], [0, 1, 2])
		"scratch-mania":
			_build_cards(6, "—")
		"lucky-spin":
			_build_wheel(240)
		"jackpot-wheel":
			_build_wheel(300)
		"coin-flip":
			_build_coin()
		"treasure-box":
			_build_choices(["Box 1", "Box 2", "Box 3", "Box 4"], [0, 1, 2, 3])
		"cash-match":
			_build_cards(6, "—")
		"diamond-drop":
			_build_cards(6, "·")
		"bonus-burst":
			_build_burst()
		_:
			var note := Label.new()
			note.text = "This table is ready when the arcade opens it."
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UiTheme.style_muted(note)
			_board.add_child(note)


func _build_reels(count: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_board.add_child(row)
	var face := Vector2(84, 78) if count <= 3 else Vector2(56, 64)
	for _index in count:
		var reel := ReelView.new()
		reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(reel)
		reel.set_face_size(face)
		reel.show_column(["coin", "dollar", "star"])
		_reels.append(reel)


func _build_choices(labels: Array, values: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2 if labels.size() > 3 else labels.size()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_board.add_child(grid)
	for index in labels.size():
		var button := Button.new()
		button.text = str(labels[index])
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_choice.bind(values[index]))
		grid.add_child(button)
		_choice_buttons.append(button)
		_choice_values.append(values[index])
	UiMotion.bind_tree(grid)


func _build_cards(count: int, hidden: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_board.add_child(grid)
	for _index in count:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(88, 76)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = hidden
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 20)
		panel.add_child(label)
		grid.add_child(panel)
		_cell_labels.append(label)


func _build_wheel(diameter: float) -> void:
	var pointer := Label.new()
	pointer.text = "▼"
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.add_theme_font_size_override("font_size", 22)
	pointer.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_board.add_child(pointer)
	_wheel = WheelFace.new()
	_wheel.custom_minimum_size = Vector2(diameter, diameter)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.add_child(_wheel)


func _build_coin() -> void:
	_coin_label = Label.new()
	_coin_label.text = "CALL IT"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 36)
	_coin_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_board.add_child(_coin_label)
	_build_choices(["Heads", "Tails"], ["HEADS", "TAILS"])


func _build_burst() -> void:
	var label := Label.new()
	label.text = "Collect the burst"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	_board.add_child(label)
	_cell_labels.append(label)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.color = Color("243352")
	_board.add_child(bar)
	_burst_fill = ColorRect.new()
	_burst_fill.color = UiTheme.COL_GOLD
	_burst_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_fill.anchor_right = 0.0
	bar.add_child(_burst_fill)


func _select_choice(value: Variant) -> void:
	if _busy:
		return
	_choice = value
	for index in _choice_buttons.size():
		var selected: bool = _choice_values[index] == value
		_choice_buttons[index].theme_type_variation = "SelectedButton" if selected else "Button"


func _change_bet(direction: int) -> void:
	if _busy:
		return
	_bet = clampi(_bet + direction * _step(), _min, _max)
	_refresh_bet()


func _step() -> int:
	if _max >= 500:
		return 10
	if _max >= 200:
		return 5
	return 1


func _refresh_bet() -> void:
	_bet_label.text = "Bet  %s" % _amount(_bet)
	if _play == null:
		return
	_play.text = "%s   ·   %s" % [_action_name(), _amount(_bet)]


func _action_name() -> String:
	match _slug:
		"scratch-mania":
			return "Scratch"
		"coin-flip":
			return "Flip"
		"treasure-box":
			return "Open"
		"cash-match":
			return "Deal"
		"diamond-drop":
			return "Drop"
		"bonus-burst":
			return "Start"
		"dollar-rush":
			return "Rush"
		_:
			return "Spin"


func _needs_choice() -> bool:
	return _slug == "dollar-rush" or _slug == "coin-flip" or _slug == "treasure-box"


func _on_play() -> void:
	if _busy or _game_id == "":
		return
	if _needs_choice() and _choice == null:
		_status.text = "Make a selection first."
		_status.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_busy = true
	_play.disabled = true
	_set_choices_disabled(true)
	_result.text = ""
	_status.text = "Placing bet..."
	_status.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var request_id := "play-%s-%s" % [str(Time.get_ticks_msec()), str(randi() % 1000000)]
	var sent: Variant = _choice if _needs_choice() else null
	var response: Dictionary = await ApiClient.spin(_game_id, _bet, sent, request_id)
	if not is_inside_tree():
		return
	if not response.ok:
		_finish_turn(str(response.error), true)
		return
	await _animate(response.data)
	if not is_inside_tree():
		return
	_show_result(response.data)
	_finish_turn(str(response.data.get("title", "Ready")), false)


func _finish_turn(message: String, failed: bool) -> void:
	_busy = false
	_play.disabled = _game_id == ""
	_set_choices_disabled(false)
	_status.text = message
	_status.add_theme_color_override("font_color", UiTheme.COL_DANGER if failed else UiTheme.COL_TEXT)
	_refresh_bet()


func _set_choices_disabled(disabled: bool) -> void:
	for button in _choice_buttons:
		button.disabled = disabled


func _animate(data: Dictionary) -> void:
	var presentation: Dictionary = data.get("presentation", {}) if data.get("presentation", {}) is Dictionary else {}
	var kind := str(presentation.get("kind", ""))
	if kind == "reels" or _slug == "lucky-dollar" or _slug == "golden-fortune":
		if kind == "reels" or not presentation.is_empty():
			await _animate_reels(data)
			return
	match kind:
		"rush":
			await _animate_rush(presentation)
		"scratch":
			await _reveal_cells(presentation.get("cells", []), true)
		"wheel", "jackpot":
			await _animate_wheel(presentation)
		"coin":
			await _animate_coin(presentation)
		"boxes":
			await _animate_boxes(presentation)
		"match":
			await _reveal_cells(presentation.get("cards", []), false, presentation.get("matched", []))
		"drop":
			await _animate_drop(presentation)
		"burst":
			await _animate_burst(presentation)


func _animate_reels(data: Dictionary) -> void:
	var grid := _map_grid(data.get("grid", []))
	var rules := SlotCatalog.get_game("lucky-dollar")
	var stopped: Array = []
	stopped.resize(_reels.size())
	stopped.fill(false)
	var elapsed := 0.0
	while stopped.has(false):
		await get_tree().create_timer(0.06).timeout
		if not is_inside_tree():
			return
		elapsed += 0.06
		for index in _reels.size():
			if elapsed < 0.7 + float(index) * 0.28:
				_reels[index].show_random(rules)
			elif not stopped[index]:
				var column: Array = grid[index] if index < grid.size() and grid[index] is Array else ["coin", "dollar", "star"]
				_reels[index].show_column(column)
				_reels[index].bounce()
				stopped[index] = true
	var highlights: Array = data.get("highlights", [])
	for index in _reels.size():
		_reels[index].highlight([1] if _has_int(highlights, index) else [])


func _animate_rush(presentation: Dictionary) -> void:
	var winning := int(presentation.get("winningLane", -1))
	for step in 7:
		for index in _choice_buttons.size():
			var lit: bool = step % 2 == 0
			_choice_buttons[index].modulate = Color(1.12, 1.05, 0.72) if lit else Color.WHITE
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree():
			return
	for index in _choice_buttons.size():
		_choice_buttons[index].modulate = Color.WHITE
		if index == winning:
			_choice_buttons[index].theme_type_variation = "PrimaryButton"


func _animate_wheel(presentation: Dictionary) -> void:
	if _wheel == null:
		return
	var segments: Array = presentation.get("segments", [])
	_wheel.segments = segments
	_wheel.spin_angle = 0.0
	var count := maxi(segments.size(), 1)
	var index := clampi(int(presentation.get("index", 0)), 0, count - 1)
	var sweep := TAU / float(count)
	var spins := 7.0 if str(presentation.get("kind", "")) == "jackpot" else 5.0
	var target := -PI / 2.0 - sweep * (float(index) + 0.5) - TAU * spins
	var tween := create_tween()
	tween.tween_property(_wheel, "spin_angle", target, 2.2 + spins * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func _animate_coin(presentation: Dictionary) -> void:
	if _coin_label == null:
		return
	for step in 10:
		_coin_label.text = "HEADS" if step % 2 == 0 else "TAILS"
		await get_tree().create_timer(0.06 + float(step) * 0.012).timeout
		if not is_inside_tree():
			return
	var face := str(presentation.get("face", ""))
	_coin_label.text = face
	var won: bool = bool(presentation.get("won", false))
	_coin_label.add_theme_color_override("font_color", UiTheme.COL_GREEN if won else UiTheme.COL_DANGER)


func _animate_boxes(presentation: Dictionary) -> void:
	var rewards: Array = presentation.get("rewards", [])
	var chosen := int(presentation.get("index", -1))
	for index in _choice_buttons.size():
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
		var multiplier := float(rewards[index]) if index < rewards.size() else 0.0
		_choice_buttons[index].text = "Box %d\n%sx" % [index + 1, _amount(multiplier)]
		if index == chosen:
			_choice_buttons[index].theme_type_variation = "PrimaryButton"


func _reveal_cells(raw: Variant, uppercase: bool, matched: Variant = []) -> void:
	var values: Array = raw if raw is Array else []
	var hits: Array = matched if matched is Array else []
	for index in _cell_labels.size():
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
		var text := str(values[index]) if index < values.size() else ""
		_cell_labels[index].text = text.to_upper() if uppercase else text
		_cell_labels[index].modulate.a = 0.2
		var tween := _cell_labels[index].create_tween()
		tween.tween_property(_cell_labels[index], "modulate:a", 1.0, 0.16)
		if _has_int(hits, index):
			_cell_labels[index].add_theme_color_override("font_color", UiTheme.COL_GOLD)


func _animate_drop(presentation: Dictionary) -> void:
	var gems: Array = presentation.get("gems", [])
	var combo := int(presentation.get("combo", 0))
	for index in _cell_labels.size():
		var text := str(gems[index]) if index < gems.size() else ""
		_cell_labels[index].text = text
		_cell_labels[index].modulate.a = 0.0
		if index < combo:
			_cell_labels[index].add_theme_color_override("font_color", UiTheme.COL_GOLD)
		var tween := _cell_labels[index].create_tween()
		tween.tween_property(_cell_labels[index], "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(0.14).timeout
		if not is_inside_tree():
			return


func _animate_burst(presentation: Dictionary) -> void:
	var count := int(presentation.get("count", 0))
	var seconds := maxi(int(presentation.get("seconds", 6)), 1)
	if _cell_labels.is_empty():
		return
	var label := _cell_labels[0]
	if _burst_fill != null:
		_burst_fill.anchor_right = 0.0
		var bar_tween := create_tween()
		bar_tween.tween_property(_burst_fill, "anchor_right", 1.0, float(seconds) * 0.16).set_trans(Tween.TRANS_SINE)
	for second in seconds:
		label.text = "0:%02d" % (seconds - second)
		await get_tree().create_timer(0.16).timeout
		if not is_inside_tree():
			return
	label.text = "Collected  %d" % count
	label.add_theme_color_override("font_color", UiTheme.COL_GOLD if count > 0 else UiTheme.COL_MUTED)


func _show_result(data: Dictionary) -> void:
	var win := float(data.get("winAmount", 0))
	_credits.text = "Credits  %s" % _amount(data.get("balance", 0))
	if win > 0.0:
		_result.text = "Won  %s" % _amount(win)
		_result.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		var tween := create_tween()
		_result.modulate = Color(1.25, 1.12, 0.7)
		tween.tween_property(_result, "modulate", Color.WHITE, 0.35)
	else:
		_result.text = "No win"
		_result.add_theme_color_override("font_color", UiTheme.COL_MUTED)


func _map_grid(raw: Variant) -> Array:
	var grid: Array = []
	if not raw is Array:
		return grid
	for column in raw:
		var mapped: Array = []
		if column is Array:
			for symbol in column:
				mapped.append(str(symbol).to_lower())
		grid.append(mapped)
	return grid


func _has_int(values: Array, wanted: int) -> bool:
	for value in values:
		if int(value) == wanted:
			return true
	return false


func _amount(value: Variant) -> String:
	var amount := float(value)
	if is_equal_approx(amount, round(amount)):
		return str(int(round(amount)))
	return "%.2f" % amount


class WheelFace extends Control:
	var segments: Array = [0, 1, 2, 5, 0, 10]
	var spin_angle := 0.0:
		set(value):
			spin_angle = value
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		if radius < 8.0:
			return
		var count := maxi(segments.size(), 1)
		var sweep := TAU / float(count)
		var font := get_theme_default_font()
		var font_size := 15
		for index in count:
			var start := spin_angle + sweep * float(index)
			var points := PackedVector2Array()
			points.append(center)
			for step in 9:
				var angle := start + sweep * float(step) / 8.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			var color := Color("F5C542") if index % 2 == 0 else Color("1B2740")
			if float(segments[index]) >= 50.0:
				color = Color("FFE38A")
			draw_colored_polygon(points, color)
			if font != null:
				var mid := start + sweep * 0.5
				var text := _label(segments[index])
				var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var pos := center + Vector2(cos(mid), sin(mid)) * radius * 0.62 - text_size * 0.5
				var ink := Color("141008") if color.r > 0.7 else Color("F4F7FB")
				draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_arc(center, radius + 8.0, 0.0, TAU, 72, Color("F5C542"), 4.0, true)
		var tip := center + Vector2(0, -radius + 8.0)
		var left := center + Vector2(-11, -radius - 12.0)
		var right := center + Vector2(11, -radius - 12.0)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color("F5C542"))

	func _label(value: Variant) -> String:
		var amount := float(value)
		if is_equal_approx(amount, round(amount)):
			return str(int(round(amount)))
		return "%.1f" % amount
