extends Control

@onready var _column: MarginContainer = %Column

var _game_id := ""
var _slug := ""
var _name := "Game"
var _difficulty := ""
var _category := ""
var _description := ""
var _balance := -1.0
var _shown_balance := -1.0
var _quick := false
var _replay := false
var _scratch_mode := false
var _scratch_done := false
var _held: Dictionary = {}
var _low: Control
var _ask: Control
var _ask_amount: LineEdit
var _ask_note: Label
var _delta: Label
var _scratch_buttons: Array[Button] = []
var _min := 1
var _max := 1
var _bet := 1
var _choice: Variant = null
var _busy := false

var _shell: VBoxContainer
var _board_panel: PanelContainer
var _board_inset: MarginContainer
var _controls: VBoxContainer
var _play_row: HBoxContainer
var _dock: PanelContainer
var _layout := "stack"
var _card_grid: GridContainer
var _choice_grid: GridContainer
var _title: Label
var _credits: Label
var _meta: Label
var _limits: Label
var _back: Button
var _board: VBoxContainer
var _bet_label: Label
var _play: Button
var _status: Label
var _result: Label
var _reels: Array = []
var _wheel: WheelFace
var _coin_label: Label
var _coin_disc: Control
var _choice_buttons: Array[Button] = []
var _choice_values: Array = []
var _cell_labels: Array[Label] = []
var _burst_fill: ColorRect


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "game", UiTheme.game_accent(_slug))
	_build_shell()
	resized.connect(_fit)
	_fit()
	_load_game()


func _fit() -> void:
	var view := size
	var column_width := minf(maxf(view.x - 8.0, 280.0), 760.0)
	ScreenLayout.fit_column(_column, column_width)
	if _back:
		_back.text = "Back to Games" if view.x >= 640.0 else "Games"
	if _title:
		_title.add_theme_font_size_override("font_size", 24 if view.x < 520.0 else 30)
	_apply_layout()
	if _board_inset:
		var pad := 10 if view.x < 520.0 else 16
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			_board_inset.add_theme_constant_override(side, pad)
	_layout_board()
	_place_dock()


func _load_game() -> void:
	var cached := _cached_game()
	if not cached.is_empty():
		_apply_game(cached)
	else:
		_apply_game(AppState.selected_game)
	if _game_id == "":
		_game_id = _slug
	if ApiClient.balance_cache >= 0.0:
		_set_balance(ApiClient.balance_cache, false)
	_show_heading()
	_build_board()
	_layout_board()
	_refresh_bet()
	_play.disabled = _game_id == ""
	_status.text = "Ready" if _game_id != "" else "This game is not available."
	_refresh_live()
	await get_tree().process_frame
	if is_inside_tree():
		UiMotion.settle(_column)


func _cached_game() -> Dictionary:
	for game in ApiClient.games_cache:
		if game is Dictionary and _is_selected(game):
			return game
	return {}


func _refresh_live() -> void:
	var wallet: Dictionary = await ApiClient.get_wallet()
	if is_inside_tree() and wallet.ok:
		_set_balance(float(wallet.data.get("balance", _balance)), false)


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
	_category = str(game.get("category", _category_for(_slug)))
	_description = str(game.get("description", ""))
	_min = maxi(int(game.get("minimumBet", game.get("min_bet", 1))), 1)
	_max = maxi(int(game.get("maximumBet", game.get("max_bet", _min))), _min)
	_bet = _min
	UiTheme.mood(self, "game", UiTheme.game_accent(_slug))


func _build_shell() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(box)
	_shell = box

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	_back = Button.new()
	_back.text = "Games"
	_back.custom_minimum_size = Vector2(96, 48)
	_back.pressed.connect(AppState.go_slots)
	header.add_child(_back)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_title(_title, 30)
	header.add_child(_title)

	_credits = Label.new()
	_credits.text = "💰 Credits"
	_delta = Label.new()
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits.add_theme_font_size_override("font_size", 20)
	_credits.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	header.add_child(_credits)
	var credit_box := VBoxContainer.new()
	header.remove_child(_credits)
	credit_box.add_child(_credits)
	_delta.add_theme_font_size_override("font_size", 16)
	_delta.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	credit_box.add_child(_delta)
	var credit_row := HBoxContainer.new()
	credit_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(credit_row)
	credit_row.add_child(credit_box)

	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_meta)
	box.add_child(_meta)

	var panel := PanelContainer.new()
	UiTheme.paint_glass(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	_board_panel = panel
	var inset := MarginContainer.new()
	_board_inset = inset
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(side, 16)
	panel.add_child(inset)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 12)
	_board.alignment = BoxContainer.ALIGNMENT_CENTER
	inset.add_child(_board)

	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_controls)
	var bets := HBoxContainer.new()
	bets.alignment = BoxContainer.ALIGNMENT_CENTER
	bets.add_theme_constant_override("separation", 8)
	_controls.add_child(bets)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(56, 52)
	minus.pressed.connect(_change_bet.bind(-1))
	bets.add_child(minus)
	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(96, 52)
	_bet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bet_label.add_theme_font_size_override("font_size", 20)
	bets.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 52)
	plus.pressed.connect(_change_bet.bind(1))
	bets.add_child(plus)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	_controls.add_child(chips)
	for label in ["Min", "Mid", "Max"]:
		var chip := Button.new()
		chip.text = label
		chip.custom_minimum_size = Vector2(0, 48)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_quick_bet.bind(label))
		chips.add_child(chip)
	var quick := Button.new()
	quick.text = "Quick"
	quick.toggle_mode = true
	quick.custom_minimum_size = Vector2(0, 48)
	quick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.toggled.connect(func(on: bool) -> void: _quick = on)
	chips.add_child(quick)
	_limits = Label.new()
	_limits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_limits)
	_controls.add_child(_limits)

	_play = Button.new()
	_play.theme_type_variation = "PrimaryButton"
	_play.custom_minimum_size = Vector2(0, 56)
	_play.pressed.connect(_on_play)
	_controls.add_child(_play)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(_status)
	_controls.add_child(_status)

	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 32)
	_result.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_controls.add_child(_result)
	_build_overlays()
	UiMotion.bind_tree(box)


func _show_heading() -> void:
	_title.text = _name
	var bits: PackedStringArray = []
	if _category != "":
		bits.append(_category)
	if _difficulty != "":
		bits.append(_difficulty)
	if _description != "":
		bits.append(_description)
	_meta.text = "  ·  ".join(bits)


func _build_board() -> void:
	for child in _board.get_children():
		child.queue_free()
	_reels.clear()
	_choice_buttons.clear()
	_choice_values.clear()
	_cell_labels.clear()
	_wheel = null
	_coin_label = null
	_coin_disc = null
	_burst_fill = null
	_scratch_buttons.clear()
	_card_grid = null
	_choice_grid = null
	_scratch_mode = false
	_scratch_done = false
	_choice = null
	match _slug:
		"lucky-dollar":
			_build_reels(3)
		"golden-fortune":
			_build_reels(5)
		"dollar-rush":
			_build_choices(["Lane 1", "Lane 2", "Lane 3"], [0, 1, 2])
		"scratch-mania":
			_build_cards(6, "?", true)
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
	var face := _reel_face(count)
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
	_choice_grid = grid
	_board.add_child(grid)
	for index in labels.size():
		var button := Button.new()
		button.text = str(labels[index])
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(0, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_choice.bind(values[index]))
		grid.add_child(button)
		_choice_buttons.append(button)
		_choice_values.append(values[index])
	UiMotion.bind_tree(grid)


func _build_cards(count: int, hidden: String, scratch := false) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_card_grid = grid
	_board.add_child(grid)
	for index in count:
		if scratch:
			var button := Button.new()
			button.text = hidden
			button.add_theme_font_size_override("font_size", 32)
			button.custom_minimum_size = Vector2(0, 112)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = true
			button.pressed.connect(_scratch_at.bind(index))
			grid.add_child(button)
			_scratch_buttons.append(button)
		else:
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(0, 104)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiTheme.paint_card(panel, UiTheme.game_accent(_slug))
			var label := Label.new()
			label.text = hidden
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_color", UiTheme.COL_TEXT)
			panel.add_child(label)
			grid.add_child(panel)
			_cell_labels.append(label)


func _build_wheel(diameter: float) -> void:
	_wheel = WheelFace.new()
	_wheel.custom_minimum_size = Vector2(diameter, diameter)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.add_child(_wheel)


func _build_coin() -> void:
	var center := CenterContainer.new()
	_board.add_child(center)
	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(168, 168)
	UiTheme.paint_card(disc, UiTheme.COL_GOLD)
	center.add_child(disc)
	_coin_disc = disc
	_coin_label = Label.new()
	_coin_label.text = "?"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 48)
	_coin_label.add_theme_color_override("font_color", UiTheme.COL_INK)
	disc.add_child(_coin_label)
	_build_choices(["Heads", "Tails"], ["HEADS", "TAILS"])


func _build_burst() -> void:
	var label := Label.new()
	label.text = "Collect the burst"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_board.add_child(label)
	_cell_labels.append(label)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(0, 18)
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
	if _limits:
		_limits.text = "Min %s    Max %s    %s" % [_amount(_min), _amount(_max), _difficulty]
	if _play == null:
		return
	if _replay:
		_play.text = "Play Again"
	else:
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
	if _scratch_mode:
		_reveal_scratch()
		return
	if _busy or _game_id == "":
		return
	if _needs_choice() and _choice == null:
		_status.text = "Make a selection first."
		_status.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	if _balance >= 0.0 and _balance < float(_bet):
		_show_low_credits()
		return
	_busy = true
	_replay = false
	_play.disabled = true
	_set_choices_disabled(true)
	_result.text = ""
	_delta.text = ""
	_status.text = "Placing bet..."
	_status.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var request_id := "play-%s-%s" % [str(Time.get_ticks_msec()), str(randi() % 1000000)]
	var sent: Variant = _choice if _needs_choice() else null
	var response: Dictionary = await ApiClient.spin(_game_id, _bet, sent, request_id)
	if not is_inside_tree():
		return
	if not response.ok:
		var message := str(response.error)
		if message == "Insufficient credits":
			_busy = false
			_play.disabled = false
			_set_choices_disabled(false)
			_show_low_credits()
			return
		_finish_turn(message, true)
		return
	_held = response.data
	await _animate(response.data)
	if not is_inside_tree():
		return
	_show_result(response.data)
	_replay = true
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
			await _play_scratch(presentation)
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
	var spinning := true
	while spinning:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var delta := clampf(get_process_delta_time(), 0.0, 0.034)
		elapsed += delta
		spinning = false
		for index in _reels.size():
			var stop_at := (0.22 + float(index) * 0.07) if _quick else (0.42 + float(index) * 0.13)
			if elapsed < stop_at:
				spinning = true
				var pace := clampf(elapsed / stop_at, 0.0, 1.0)
				var speed := sin(pace * PI) * (1680.0 if _quick else 980.0)
				_reels[index].advance(maxf(speed, 240.0) * delta, rules)
			elif not stopped[index]:
				var column: Array = grid[index] if index < grid.size() and grid[index] is Array else ["coin", "dollar", "star"]
				_reels[index].land(column)
				stopped[index] = true
	await get_tree().create_timer(0.16).timeout
	if not is_inside_tree():
		return
	var highlights: Array = data.get("highlights", [])
	for index in _reels.size():
		_reels[index].highlight([1] if _has_int(highlights, index) else [])


func _animate_rush(presentation: Dictionary) -> void:
	var winning := int(presentation.get("winningLane", -1))
	_status.text = "3"
	await get_tree().create_timer(0.22).timeout
	if not is_inside_tree():
		return
	_status.text = "2"
	await get_tree().create_timer(0.22).timeout
	if not is_inside_tree():
		return
	_status.text = "1"
	for step in 4:
		for index in _choice_buttons.size():
			var lit: bool = step % 2 == 0
			_choice_buttons[index].modulate = Color(1.12, 1.05, 0.72) if lit else Color.WHITE
		await get_tree().create_timer(0.06).timeout
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
	_wheel.winner = -1
	_wheel.spin_angle = 0.0
	var count := maxi(segments.size(), 1)
	var index := clampi(int(presentation.get("index", 0)), 0, count - 1)
	var sweep := TAU / float(count)
	var spins := 2.0 if _quick else (4.0 if str(presentation.get("kind", "")) == "jackpot" else 3.0)
	var target := -PI / 2.0 - sweep * (float(index) + 0.5) - TAU * spins
	var tween := create_tween()
	var duration := 0.55 if _quick else (1.45 if str(presentation.get("kind", "")) == "jackpot" else 1.05)
	tween.tween_property(_wheel, "spin_angle", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_inside_tree():
		_wheel.winner = index
		_status.text = "Segment  %s" % _wheel._label(segments[index] if index < segments.size() else 0)


func _animate_coin(presentation: Dictionary) -> void:
	if _coin_label == null:
		return
	if _coin_disc:
		_coin_disc.pivot_offset = _coin_disc.custom_minimum_size * 0.5
	for step in 4:
		if _coin_disc:
			var flip := create_tween()
			flip.tween_property(_coin_disc, "scale:x", 0.08, 0.05)
			await flip.finished
		_coin_label.text = "H" if step % 2 == 0 else "T"
		if _coin_disc:
			var back := create_tween()
			back.tween_property(_coin_disc, "scale:x", 1.0, 0.05)
			await back.finished
		if not is_inside_tree():
			return
	var face := str(presentation.get("face", ""))
	_coin_label.text = "H" if face == "HEADS" else "T"
	var won: bool = bool(presentation.get("won", false))
	_coin_label.add_theme_color_override("font_color", UiTheme.COL_GREEN if won else UiTheme.COL_DANGER)
	_status.text = "Heads" if face == "HEADS" else "Tails"


func _animate_boxes(presentation: Dictionary) -> void:
	var rewards: Array = presentation.get("rewards", [])
	var chosen := int(presentation.get("index", -1))
	for index in _choice_buttons.size():
		await get_tree().create_timer(0.07).timeout
		if not is_inside_tree():
			return
		var multiplier := float(rewards[index]) if index < rewards.size() else 0.0
		_choice_buttons[index].text = "%sx" % _amount(multiplier)
		if index == chosen:
			_choice_buttons[index].theme_type_variation = "PrimaryButton"


func _reveal_cells(raw: Variant, uppercase: bool, matched: Variant = []) -> void:
	var values: Array = raw if raw is Array else []
	var hits: Array = matched if matched is Array else []
	for index in _cell_labels.size():
		await get_tree().create_timer(0.07).timeout
		if not is_inside_tree():
			return
		var text := str(values[index]) if index < values.size() else ""
		_cell_labels[index].text = _mark(text) if not uppercase else _mark(text)
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
		_cell_labels[index].text = _mark(text)
		_cell_labels[index].modulate.a = 0.0
		if index < combo:
			_cell_labels[index].add_theme_color_override("font_color", UiTheme.COL_GOLD)
		var tween := _cell_labels[index].create_tween()
		tween.tween_property(_cell_labels[index], "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree():
			return
	_status.text = "Combo  %d" % combo


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
	var ticks := mini(seconds, 4)
	for second in ticks:
		label.text = "0:%02d" % (ticks - second)
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
	label.text = "Collected  %d" % count
	label.add_theme_color_override("font_color", UiTheme.COL_GOLD if count > 0 else UiTheme.COL_MUTED)


func _show_result(data: Dictionary) -> void:
	var win := float(data.get("winAmount", 0))
	var next := float(data.get("balance", _balance))
	_set_balance(next, true)
	if win > 0.0:
		_result.text = "WIN\n+%s Credits" % _amount(win)
		_result.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		_delta.text = "+%s Credits" % _amount(win)
		_delta.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		var tween := create_tween()
		_result.modulate = Color(1.25, 1.12, 0.7)
		tween.tween_property(_result, "modulate", Color.WHITE, 0.28)
	else:
		_result.text = "LOSS\n-%s Credits" % _amount(_bet)
		_result.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		_delta.text = "-%s Credits" % _amount(_bet)
		_delta.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _set_balance(next: float, animate: bool) -> void:
	var start := _shown_balance if _shown_balance >= 0.0 else next
	_balance = next
	ApiClient.balance_cache = next
	if not animate or is_equal_approx(start, next):
		_shown_balance = next
		_credits.text = "💰 %s Credits" % _amount(next)
		return
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_shown_balance = value
		_credits.text = "💰 %s Credits" % _amount(value)
	, start, next, 0.35)


func _quick_bet(label: String) -> void:
	if _busy:
		return
	var mid := clampi(int(round(float(_min + _max) * 0.5)), _min, _max)
	if label == "Max":
		_bet = _max
	elif label == "Mid":
		_bet = mid
	else:
		_bet = _min
	_refresh_bet()


func _category_for(slug: String) -> String:
	match slug:
		"lucky-dollar", "golden-fortune":
			return "SLOTS"
		"dollar-rush":
			return "REACTION"
		"scratch-mania":
			return "SCRATCH"
		"lucky-spin", "jackpot-wheel":
			return "SPIN"
		"coin-flip", "treasure-box":
			return "CHOICE"
		"cash-match", "diamond-drop":
			return "MATCH"
		"bonus-burst":
			return "BONUS"
		_:
			return ""


func _play_scratch(presentation: Dictionary) -> void:
	var cells: Array = presentation.get("cells", []) if presentation.get("cells", []) is Array else []
	_scratch_done = false
	_scratch_mode = true
	for index in _scratch_buttons.size():
		_scratch_buttons[index].text = "?"
		_scratch_buttons[index].disabled = false
		_scratch_buttons[index].set_meta("prize", str(cells[index]) if index < cells.size() else "")
		_scratch_buttons[index].set_meta("open", false)
	_status.text = "Scratch the card"
	_play.disabled = false
	_play.text = "Reveal"
	while not _scratch_done and is_inside_tree():
		await get_tree().process_frame
	_scratch_mode = false


func _scratch_at(index: int) -> void:
	if not _scratch_mode or index >= _scratch_buttons.size():
		return
	var button := _scratch_buttons[index]
	if bool(button.get_meta("open", false)):
		return
	button.set_meta("open", true)
	button.text = _mark(str(button.get_meta("prize", "")))
	button.disabled = true
	var closed := 0
	for other in _scratch_buttons:
		if not bool(other.get_meta("open", false)):
			closed += 1
	_status.text = "Scratch  %d left" % closed
	if closed == 0:
		_scratch_done = true


func _reveal_scratch() -> void:
	for button in _scratch_buttons:
		button.set_meta("open", true)
		button.text = _mark(str(button.get_meta("prize", "")))
		button.disabled = true
	_scratch_done = true


func _show_low_credits() -> void:
	if _low:
		_low.visible = true
	_status.text = "Not enough credits"


func _show_ask() -> void:
	if _low:
		_low.visible = false
	if _ask:
		_ask.visible = true
		_ask_amount.text = str(maxi(_min * 10, 50))
		_ask_note.text = ""


func _send_request() -> void:
	var amount := int(_ask_amount.text)
	if amount <= 0:
		_ask_note.text = "Enter an amount."
		return
	_ask_note.text = "Sending..."
	var response: Dictionary = await ApiClient.request_credits(amount)
	if not is_inside_tree():
		return
	if response.ok:
		_ask_note.text = "Request sent. An admin will review it."
	else:
		_ask_note.text = str(response.error)


func _build_overlays() -> void:
	_low = _overlay_panel()
	var low_box := _low.get_meta("box") as VBoxContainer
	var low_title := Label.new()
	low_title.text = "Not Enough Credits"
	UiTheme.style_title(low_title, 28)
	low_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	low_box.add_child(low_title)
	var low_copy := Label.new()
	low_copy.text = "Your current balance is too low to play this game."
	low_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	low_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	low_box.add_child(low_copy)
	var low_meta := Label.new()
	low_meta.name = "Meta"
	low_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	low_box.add_child(low_meta)
	var ask := Button.new()
	ask.text = "Ask Admin for Credits"
	ask.theme_type_variation = "PrimaryButton"
	ask.custom_minimum_size = Vector2(0, 48)
	ask.pressed.connect(_show_ask)
	low_box.add_child(ask)
	var back := Button.new()
	back.text = "Back to Games"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(AppState.go_slots)
	low_box.add_child(back)
	_low.visibility_changed.connect(func() -> void:
		if _low.visible:
			low_meta.text = "Current Credits: %s\nMinimum Bet: %s" % [_amount(maxf(_balance, 0.0)), _amount(_min)]
	)

	_ask = _overlay_panel()
	var ask_box := _ask.get_meta("box") as VBoxContainer
	var ask_title := Label.new()
	ask_title.text = "Send a credit request to the administrator?"
	ask_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_box.add_child(ask_title)
	_ask_amount = LineEdit.new()
	_ask_amount.placeholder_text = "Amount"
	_ask_amount.custom_minimum_size = Vector2(0, 48)
	ask_box.add_child(_ask_amount)
	_ask_note = Label.new()
	_ask_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_box.add_child(_ask_note)
	var send := Button.new()
	send.text = "Send Request"
	send.theme_type_variation = "PrimaryButton"
	send.custom_minimum_size = Vector2(0, 48)
	send.pressed.connect(_send_request)
	ask_box.add_child(send)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 48)
	cancel.pressed.connect(func() -> void: _ask.visible = false)
	ask_box.add_child(cancel)


func _overlay_panel() -> Control:
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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	dim.set_meta("box", box)
	return dim


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


func _layout_board() -> void:
	if _choice_grid and is_instance_valid(_choice_grid):
		var count := _choice_grid.get_child_count()
		if size.x < 520.0:
			_choice_grid.columns = 1 if count <= 3 else 2
		else:
			_choice_grid.columns = 2 if count > 3 else maxi(count, 1)
	if _card_grid and is_instance_valid(_card_grid):
		_card_grid.columns = 2 if size.x < 520.0 else 3
	if not _reels.is_empty():
		var face := _reel_face(_reels.size())
		for reel in _reels:
			if reel is ReelView:
				reel.set_face_size(face)
	if _wheel:
		var diameter := _wheel_diameter()
		_wheel.custom_minimum_size = Vector2(diameter, diameter)


func _apply_layout() -> void:
	if _shell == null or _board_panel == null or _controls == null:
		return
	var mode := "stack"
	if size.y > size.x and size.x < 560.0 and size.x > 8.0:
		mode = "dock"
	elif size.x > size.y + 60.0 and size.y < 620.0 and size.x >= 700.0:
		mode = "split"
	if mode == _layout:
		return
	_return_controls()
	_layout = mode
	if mode == "dock":
		_dock = PanelContainer.new()
		_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_dock.mouse_filter = Control.MOUSE_FILTER_STOP
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color(0.03, 0.05, 0.09, 0.96)
		bar.border_color = Color(UiTheme.COL_GOLD, 0.28)
		bar.set_border_width_all(1)
		bar.content_margin_left = 12
		bar.content_margin_right = 12
		bar.content_margin_top = 10
		bar.content_margin_bottom = 12
		_dock.add_theme_stylebox_override("panel", bar)
		add_child(_dock)
		_controls.reparent(_dock)
	elif mode == "split":
		_play_row = HBoxContainer.new()
		_play_row.add_theme_constant_override("separation", 14)
		_play_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var at := _board_panel.get_index()
		_shell.add_child(_play_row)
		_shell.move_child(_play_row, at)
		_board_panel.reparent(_play_row)
		_controls.reparent(_play_row)
		_board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_board_panel.size_flags_stretch_ratio = 1.35
		_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls.size_flags_stretch_ratio = 0.9
		_controls.custom_minimum_size.x = 210


func _return_controls() -> void:
	if _controls.get_parent() != _shell:
		var at := _meta.get_index() + 1
		if _play_row and is_instance_valid(_play_row) and _play_row.get_parent() == _shell:
			at = _play_row.get_index()
		if _board_panel.get_parent() != _shell:
			_board_panel.reparent(_shell)
		_shell.move_child(_board_panel, mini(at, _shell.get_child_count() - 1))
		_controls.reparent(_shell)
		_shell.move_child(_controls, mini(_board_panel.get_index() + 1, _shell.get_child_count() - 1))
	_controls.custom_minimum_size.x = 0
	_board_panel.size_flags_stretch_ratio = 1.0
	if _play_row and is_instance_valid(_play_row):
		_play_row.queue_free()
	_play_row = null
	if _dock and is_instance_valid(_dock):
		_dock.queue_free()
	_dock = null
	var scroll := get_node_or_null("Scroll") as Control
	if scroll:
		scroll.offset_bottom = 0
		scroll.offset_left = 0
		scroll.offset_right = 0
		scroll.offset_top = 0


func _place_dock() -> void:
	var scroll := get_node_or_null("Scroll") as Control
	if _layout != "dock" or _dock == null or scroll == null:
		return
	var inset := ScreenLayout.safe_insets()
	var height := _controls.get_combined_minimum_size().y + 24.0 + inset.w
	_dock.offset_bottom = -inset.w
	_dock.offset_top = -height
	_dock.offset_left = inset.x
	_dock.offset_right = -inset.z
	scroll.offset_bottom = -height
	scroll.offset_left = 0
	scroll.offset_right = 0
	scroll.offset_top = 0


func _reel_face(count: int) -> Vector2:
	var usable := minf(size.x, 760.0)
	if _layout == "split":
		usable = minf(size.x * 0.56, 520.0)
	usable -= 48.0
	if usable < 160.0:
		usable = maxf(size.x - 28.0, 160.0)
	var gap := 8.0 * float(maxi(count - 1, 0))
	var minimum := 48.0 if count >= 5 else 72.0
	var face_w := clampf((usable - gap) / float(maxi(count, 1)), minimum, 120.0)
	return Vector2(face_w, clampf(face_w * 0.96, minimum, 116.0))


func _wheel_diameter() -> float:
	var cap := 360.0 if _slug == "jackpot-wheel" else 300.0
	var room := minf(size.x, size.y) - 36.0
	if _layout == "split":
		room = minf(size.x * 0.5, size.y - 28.0)
	elif _layout == "dock":
		room = size.x - 36.0
	return clampf(room, 180.0, cap)


func _mark(symbol: String) -> String:
	match symbol.to_lower():
		"coin", "dollar", "$":
			return "$"
		"star":
			return "★"
		"diamond":
			return "◆"
		"seven":
			return "7"
		"bonus":
			return "B"
		"ruby":
			return "R"
		"gold":
			return "G"
		"jade":
			return "J"
		"blue":
			return "U"
		"heads":
			return "H"
		"tails":
			return "T"
		_:
			if symbol.length() <= 2:
				return symbol.to_upper()
			return symbol.substr(0, 1).to_upper()


func _amount(value: Variant) -> String:
	var amount := float(value)
	if is_equal_approx(amount, round(amount)):
		return str(int(round(amount)))
	return "%.2f" % amount


class WheelFace extends Control:
	var segments: Array = [0, 1, 2, 5, 0, 10]
	var winner := -1
	var spin_angle := 0.0:
		set(value):
			spin_angle = value
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		if radius < 8.0:
			return
		var count := maxi(segments.size(), 1)
		var sweep := TAU / float(count)
		var font := get_theme_default_font()
		var font_size := clampi(int(radius / 7.0), 16, 28)
		draw_circle(center, radius + 10.0, Color("070B14"))
		for index in count:
			var start := spin_angle + sweep * float(index)
			var points := PackedVector2Array()
			points.append(center)
			for step in 10:
				var angle := start + sweep * float(step) / 9.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			var color := Color("F5C542") if index % 2 == 0 else Color("18243A")
			if float(segments[index]) >= 10.0:
				color = Color("FFE38A")
			if index == winner:
				color = Color("3DDC97")
			draw_colored_polygon(points, color)
			if font != null:
				var mid := start + sweep * 0.5
				var text := _label(segments[index])
				var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var at := center + Vector2(cos(mid), sin(mid)) * radius * 0.66
				draw_circle(at, font_size * 0.72, Color(0, 0, 0, 0.28))
				var pos := at - Vector2(text_size.x * 0.5, -font.get_ascent(font_size) * 0.32)
				var ink := Color("141008") if color.r > 0.7 or index == winner else Color("F4F7FB")
				draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_arc(center, radius + 6.0, 0.0, TAU, 80, Color("F5C542"), 6.0, true)
		draw_circle(center, 10.0, Color("F5C542"))
		var tip := center + Vector2(0, -radius + 6.0)
		var left := center + Vector2(-14, -radius - 16.0)
		var right := center + Vector2(14, -radius - 16.0)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color("FFF8E6"))

	func _label(value: Variant) -> String:
		var amount := float(value)
		if is_equal_approx(amount, round(amount)):
			return str(int(round(amount)))
		return "%.1f" % amount
