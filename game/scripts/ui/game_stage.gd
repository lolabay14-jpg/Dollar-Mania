extends Control

@onready var _column: MarginContainer = %Column

var _game_id := ""
var _slug := ""
var _name := "Game"
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
var _leaving := false
var _retry := false
var _unavailable := false
var _balance_tween: Tween
var _block_overlay: Control

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
var _banner: GameBanner = null
var _credits: Label
var _meta: Label
var _limits: Label
var _back: Button
var _board: VBoxContainer
var _bet_label: Label
var _play: Button
var _status: Label
var _result: Label
var _result_kicker: Label
var _result_panel: PanelContainer
var _reels: Array = []
var _wheel: WheelFace
var _pond: FishShooter
var _sky: SkyRush
var _bottles: BottleGallery
var _gallery: TargetGallery
var _chest: MysteryChest
var _coin_label: Label
var _coin_disc: Control
var _player_card: PlayingCard
var _house_card: PlayingCard
var _cell_faces: Array[SymbolView] = []
var _choice_buttons: Array[Button] = []
var _choice_values: Array = []
var _cell_labels: Array[Label] = []
var _burst_fill: ColorRect
var _dice: Array = []
var _number_label: Label


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	# Atmosphere only — mute promotional background text during gameplay.
	ArcadeBackdrop.mount_photo(self, GameArt.screen_path("gameplay"), 0.66, 0.1)
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
	_status.text = "Loading game..."
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
	_status.text = _hint() if _game_id != "" else "This game is not available."
	UiMotion.bind_tree(_board)
	_refresh_live()
	await _enforce_access()


func _enforce_access() -> void:
	if _leaving:
		return
	var response: Dictionary = await ApiClient.reload_slot_games()
	if not is_inside_tree() or _leaving:
		return
	if not response.ok:
		return
	var games_value: Variant = response.data.get("games", [])
	if not games_value is Array:
		return
	for item in games_value:
		if not item is Dictionary:
			continue
		if not _is_selected(item):
			continue
		_apply_game(item)
		_show_heading()
		if item.has("enabled") and not bool(item.get("enabled", true)):
			_show_unavailable()
		return


func _show_unavailable() -> void:
	_unavailable = true
	_busy = true
	if _play:
		_play.disabled = true
		_play.text = "Unavailable"
	_set_choices_disabled(true)
	_status.text = "This game is currently unavailable for your account."
	_status.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	if _block_overlay and is_instance_valid(_block_overlay):
		_block_overlay.queue_free()
	_block_overlay = PanelContainer.new()
	_block_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_block_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	style.set_corner_radius_all(18)
	_block_overlay.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_block_overlay.add_child(_pad_block(box, 24))
	var title := Label.new()
	title.text = "GAME UNAVAILABLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("FFB4BE"))
	box.add_child(title)
	var body := Label.new()
	body.text = "This game is currently unavailable for your account."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color("C5D0E4"))
	box.add_child(body)
	var back := Button.new()
	back.text = "Back to Games"
	back.theme_type_variation = "PrimaryButton"
	back.custom_minimum_size = Vector2(0, 52)
	back.pressed.connect(_leave)
	box.add_child(back)
	if _board_panel:
		_board_panel.add_child(_block_overlay)
	elif _shell:
		_shell.add_child(_block_overlay)


func _pad_block(child: Control, margin: int) -> MarginContainer:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", margin)
	wrap.add_theme_constant_override("margin_right", margin)
	wrap.add_theme_constant_override("margin_top", margin)
	wrap.add_theme_constant_override("margin_bottom", margin)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(child)
	return wrap


func _cached_game() -> Dictionary:
	for game in ApiClient.games_cache:
		if game is Dictionary and _is_selected(game):
			return game
	return {}


func _refresh_live() -> void:
	var wallet: Dictionary = await ApiClient.get_wallet()
	if is_inside_tree() and wallet.ok:
		_set_balance(float(wallet.data.get("balance", _balance)), false)
	elif is_inside_tree() and _balance < 0.0:
		_status.text = "Unable to load your balance.\nPlease try again."


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
	_category = str(game.get("category", _category_for(_slug)))
	_description = str(game.get("description", ""))
	_min = maxi(int(game.get("minimumBet", game.get("min_bet", 1))), 1)
	_max = maxi(int(game.get("maximumBet", game.get("max_bet", _min))), _min)
	_bet = _min
	_paint_stage()


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
	_back.pressed.connect(_leave)
	header.add_child(_back)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_title(_title, 30)
	header.add_child(_title)

	# Lobby card artwork stays in the lobby only — gameplay uses Neon Casino backdrop.
	_banner = null

	_credits = Label.new()
	_credits.text = "Credits"
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_credits.add_theme_font_size_override("font_size", 18)
	_credits.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_delta = Label.new()
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delta.add_theme_font_size_override("font_size", 13)
	_delta.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	var credit_box := VBoxContainer.new()
	credit_box.add_theme_constant_override("separation", 0)
	credit_box.add_child(_credits)
	credit_box.add_child(_delta)
	var wallet_chip := PanelContainer.new()
	wallet_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("141E32")
	chip_style.border_color = Color("31425F")
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(12)
	chip_style.content_margin_left = 14
	chip_style.content_margin_right = 14
	chip_style.content_margin_top = 8
	chip_style.content_margin_bottom = 8
	wallet_chip.add_theme_stylebox_override("panel", chip_style)
	wallet_chip.add_child(credit_box)
	header.add_child(wallet_chip)

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

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color("10182A")
	result_style.border_color = Color("31425F")
	result_style.set_border_width_all(1)
	result_style.set_corner_radius_all(16)
	result_style.content_margin_left = 20
	result_style.content_margin_right = 20
	result_style.content_margin_top = 16
	result_style.content_margin_bottom = 16
	_result_panel.add_theme_stylebox_override("panel", result_style)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 6)
	_result_panel.add_child(result_box)
	_result_kicker = Label.new()
	_result_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_kicker.add_theme_font_size_override("font_size", 22)
	result_box.add_child(_result_kicker)
	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 28)
	_result.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	result_box.add_child(_result)
	_controls.add_child(_result_panel)
	_build_overlays()
	UiMotion.bind_tree(box)
	UiMotion.bind_fields(box)


func _show_heading() -> void:
	_title.text = _name
	var bits: PackedStringArray = []
	if _category != "":
		bits.append(_category)
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
	_pond = null
	_sky = null
	_bottles = null
	_gallery = null
	_chest = null
	_coin_label = null
	_coin_disc = null
	_player_card = null
	_house_card = null
	_cell_faces.clear()
	_burst_fill = null
	_scratch_buttons.clear()
	_card_grid = null
	_choice_grid = null
	_scratch_mode = false
	_scratch_done = false
	_choice = null
	_dice.clear()
	_number_label = null
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
			_build_wheel(240, "wheel")
		"jackpot-wheel":
			_build_wheel(300, "jackpot")
		"fruit-spin":
			_build_wheel(280, "fruit")
		"diamond-spin":
			_build_wheel(280, "diamond")
		"lucky-wheel":
			_build_wheel(280, "lucky")
		"prize-spinner":
			_build_wheel(260, "spinner")
		"fishing":
			_build_fishing()
		"target-blast":
			_build_targets()
		"aeroplane-rush":
			_build_sky()
		"bottle-blast":
			_build_bottles()
		"mystery-box":
			_build_mystery()
		"dice":
			_build_dice()
		"lucky-number":
			_build_lucky_number()
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
		"higher-card":
			_build_higher_card()
		_:
			var note := Label.new()
			note.text = "This table is ready when the arcade opens it."
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UiTheme.style_muted(note)
			_board.add_child(note)


func _build_reels(count: int) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("070B14")
	frame_style.border_color = Color("C8962E")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(18)
	frame_style.content_margin_left = 16
	frame_style.content_margin_right = 16
	frame_style.content_margin_top = 16
	frame_style.content_margin_bottom = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	_board.add_child(frame)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	frame.add_child(row)
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
			var button := ScratchTile.new()
			button.text = hidden
			button.custom_minimum_size = Vector2(0, 128)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = true
			button.pressed.connect(_scratch_at.bind(index))
			grid.add_child(button)
			_scratch_buttons.append(button)
		else:
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(0, 120)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiTheme.paint_card(panel, UiTheme.game_accent(_slug))
			var face := SymbolView.new()
			face.custom_minimum_size = Vector2(0, 72)
			face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			face.visible = false
			panel.add_child(face)
			_cell_faces.append(face)
			var label := Label.new()
			label.text = hidden
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", UiTheme.COL_TEXT)
			panel.add_child(label)
			grid.add_child(panel)
			_cell_labels.append(label)


func _build_wheel(diameter: float, style: String) -> void:
	_wheel = WheelFace.new()
	_wheel.style = style
	_wheel.custom_minimum_size = Vector2(diameter, diameter)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if style == "fruit":
		_wheel.segments = [0, 1, 0, 2, 1, 4, 2, 0, 8, 3]
		_wheel.symbols = ["cherry", "lemon", "orange", "melon", "grapes", "berry", "diamond", "star", "seven", "coin"]
	elif style == "diamond":
		_wheel.segments = [0, 2, 0, 4, 1, 8, 0, 3, 12, 2]
		_wheel.symbols = ["ruby", "sapphire", "emerald", "diamond", "amethyst", "crystal", "gold", "jade", "seven", "star"]
	elif style == "lucky":
		_wheel.segments = [0, 2, 0, 5, 1, 0, 10, 3, 0, 20]
		_wheel.symbols = ["coin", "star", "coin", "diamond", "coin", "star", "seven", "coin", "star", "diamond"]
	elif style == "spinner":
		_wheel.segments = [0, 1, 3, 0, 2, 8, 0, 4]
		_wheel.symbols = ["coin", "star", "diamond", "coin", "seven", "bonus", "star", "dollar"]
	_board.add_child(_wheel)


func _build_sky() -> void:
	_sky = SkyRush.new()
	_sky.custom_minimum_size = Vector2(280, 460)
	_sky.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_sky)


func _build_bottles() -> void:
	_bottles = BottleGallery.new()
	_bottles.custom_minimum_size = Vector2(280, 460)
	_bottles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_bottles)


func _build_fishing() -> void:
	_pond = FishShooter.new()
	_pond.custom_minimum_size = Vector2(280, 460)
	_pond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_pond)


func _build_targets() -> void:
	_gallery = TargetGallery.new()
	_gallery.custom_minimum_size = Vector2(280, 460)
	_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_gallery)


func _build_mystery() -> void:
	_chest = MysteryChest.new()
	_chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_chest)


func _build_dice() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_board.add_child(row)
	for face in [1, 6]:
		var die := DieFace.new()
		die.custom_minimum_size = Vector2(120, 120)
		die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		die.set_face(face)
		row.add_child(die)
		_dice.append(die)


func _build_lucky_number() -> void:
	_number_label = Label.new()
	_number_label.text = "Pick 1–10"
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.add_theme_font_size_override("font_size", 42)
	_number_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	_board.add_child(_number_label)
	var labels: Array = []
	var values: Array = []
	for number in range(1, 11):
		labels.append(str(number))
		values.append(number)
	_build_choices(labels, values)
	if _choice_grid:
		_choice_grid.columns = 5
	for button in _choice_buttons:
		button.custom_minimum_size.y = 64


func _build_coin() -> void:
	var center := CenterContainer.new()
	_board.add_child(center)
	var disc := CoinFace.new()
	disc.custom_minimum_size = Vector2(180, 180)
	disc.set_side("edge")
	center.add_child(disc)
	_coin_disc = disc
	_build_choices(["Heads", "Tails"], ["HEADS", "TAILS"])


func _build_higher_card() -> void:
	var table := PanelContainer.new()
	UiTheme.paint_card(table, Color("3DDC97"))
	_board.add_child(table)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	var table_pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		table_pad.add_theme_constant_override(side, 20)
	table.add_child(table_pad)
	table_pad.add_child(box)
	var house_caption := Label.new()
	house_caption.text = "House"
	house_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(house_caption)
	box.add_child(house_caption)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	_house_card = PlayingCard.new()
	_house_card.show_back()
	_house_card.rotation_degrees = -6.0
	row.add_child(_house_card)
	var versus := Label.new()
	versus.text = "VS"
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_title(versus, 22)
	row.add_child(versus)
	_player_card = PlayingCard.new()
	_player_card.show_back()
	_player_card.rotation_degrees = 6.0
	row.add_child(_player_card)
	var yours := Label.new()
	yours.text = "Your hand"
	yours.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(yours)
	box.add_child(yours)


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
		if selected:
			UiMotion.pulse_selected(_choice_buttons[index])


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
		_limits.text = "Min %s    Max %s" % [_amount(_min), _amount(_max)]
	if _play == null:
		return
	if _replay:
		_play.text = "Play Again"
	elif _retry:
		_play.text = "Retry"
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
		"higher-card":
			return "Draw"
		"fishing":
			return "Start"
		"target-blast", "aeroplane-rush", "bottle-blast":
			return "Start"
		"mystery-box":
			return "Open"
		"diamond-spin":
			return "Spin"
		"dice":
			return "Roll"
		"lucky-number":
			return "Play"
		_:
			return "Spin"


func _needs_choice() -> bool:
	return _slug == "dollar-rush" or _slug == "coin-flip" or _slug == "treasure-box" or _slug == "lucky-number"


func _on_play() -> void:
	if _scratch_mode:
		_reveal_scratch()
		return
	if _busy or _unavailable or _game_id == "":
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
	_retry = false
	_play.disabled = true
	_play.modulate = Color(1.0, 0.96, 0.86)
	_set_choices_disabled(true)
	_result.text = ""
	_delta.text = ""
	if _result_panel:
		_result_panel.visible = false
		_result_panel.scale = Vector2.ONE
		_result_panel.modulate.a = 1.0
	_status.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	if _slug == "fishing" and _pond:
		_pond.show_loading()
		_status.text = "Diving..."
	elif _slug == "target-blast" and _gallery:
		_gallery.show_loading()
		_status.text = "Arming..."
	elif _slug == "aeroplane-rush" and _sky:
		_sky.show_loading()
		_status.text = "Boarding..."
	elif _slug == "bottle-blast" and _bottles:
		_bottles.show_loading()
		_status.text = "Setting bottles..."
	else:
		_status.text = "Placing bet..."
		_pulse_board()
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
			_play.modulate = Color.WHITE
			_set_choices_disabled(false)
			_rest_arcade()
			_show_low_credits()
			return
		if message.to_lower().contains("unavailable") or int(response.get("status", 0)) == 403:
			_show_unavailable()
			return
		_finish_turn(_friendly_error(message), true)
		return
	_held = response.data
	await _animate(response.data)
	if not is_inside_tree() or _leaving:
		return
	_show_result(response.data)
	_replay = true
	_finish_turn(str(response.data.get("title", "Ready")), false)


func _exit_tree() -> void:
	_busy = true
	_scratch_done = true
	if _balance_tween and _balance_tween.is_valid():
		_balance_tween.kill()


func _leave() -> void:
	_leaving = true
	_busy = true
	_scratch_done = true
	if _balance_tween and _balance_tween.is_valid():
		_balance_tween.kill()
	AppState.go_player()


func _friendly_error(message: String) -> String:
	var text := message.strip_edges()
	if text == "" or text.contains("HTTP") or text.contains("timed") or text.contains("not ready"):
		return "Unable to complete this action.\nPlease try again."
	return text


func _finish_turn(message: String, failed: bool) -> void:
	_busy = false
	_retry = failed
	_play.disabled = _game_id == ""
	_play.modulate = Color.WHITE
	_set_choices_disabled(false)
	if failed:
		_rest_arcade()
	_status.text = message
	_status.add_theme_color_override("font_color", UiTheme.COL_DANGER if failed else UiTheme.COL_TEXT)
	if failed:
		_present_result("Unable to play", message, UiTheme.COL_DANGER)
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
		"wheel", "jackpot", "fruit", "lucky", "spinner", "diamond":
			await _animate_wheel(presentation)
		"fishing":
			await _animate_fishing(presentation)
		"targets":
			await _animate_targets(presentation)
		"flight":
			await _animate_flight(presentation)
		"bottles":
			await _animate_bottles(presentation)
		"mystery":
			await _animate_mystery(presentation)
		"dice":
			await _animate_dice(presentation)
		"number":
			await _animate_number(presentation)
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
		"cards":
			await _animate_cards(presentation)


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
	_wheel.symbols = presentation.get("symbols", [])
	_wheel.style = str(presentation.get("kind", _wheel.style))
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
		var nudge := create_tween()
		nudge.tween_property(_wheel, "pointer_drop", 10.0, 0.08)
		nudge.tween_property(_wheel, "pointer_drop", 0.0, 0.14)
		await nudge.finished


func _animate_fishing(presentation: Dictionary) -> void:
	if _pond == null:
		return
	_status.text = "Fish incoming"
	await _pond.play_round(presentation, _bet, float(_held.get("winAmount", 0)), maxf(_balance, 0.0))
	if is_inside_tree():
		_status.text = str(presentation.get("name", "Round complete"))


func _animate_flight(presentation: Dictionary) -> void:
	if _sky == null:
		return
	_status.text = "Wheels up"
	await _sky.play_round(presentation, _bet, float(_held.get("winAmount", 0)), maxf(_balance, 0.0))
	if is_inside_tree():
		_status.text = "Flight complete"


func _animate_bottles(presentation: Dictionary) -> void:
	if _bottles == null:
		return
	_status.text = "Bottles live"
	await _bottles.play_round(presentation, _bet, float(_held.get("winAmount", 0)), maxf(_balance, 0.0))
	if is_inside_tree():
		_status.text = "Round complete"


func _animate_targets(presentation: Dictionary) -> void:
	if _gallery == null:
		return
	_status.text = "Targets live"
	await _gallery.play_round(presentation, _bet, float(_held.get("winAmount", 0)), maxf(_balance, 0.0))
	if is_inside_tree():
		_status.text = "Round complete"


func _animate_mystery(presentation: Dictionary) -> void:
	if _chest == null:
		return
	_chest.prize = -1.0
	_chest.open_amount = 0.0
	_chest.shake = 0.7
	_status.text = "The box is shaking"
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_chest, "open_amount", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_inside_tree():
		return
	_chest.prize = float(presentation.get("prize", 0))
	_status.text = "Empty box" if _chest.prize <= 0.0 else "Prize revealed"
	await get_tree().create_timer(0.35).timeout


func _animate_dice(presentation: Dictionary) -> void:
	var faces: Array = presentation.get("dice", []) if presentation.get("dice", []) is Array else []
	for step in 8:
		for index in _dice.size():
			var die: DieFace = _dice[index]
			die.set_face(1 + (step + index) % 6)
		await get_tree().create_timer(0.07).timeout
		if not is_inside_tree():
			return
	for index in _dice.size():
		var value := int(faces[index]) if index < faces.size() else 1
		var die: DieFace = _dice[index]
		die.set_face(value)
	await get_tree().create_timer(0.2).timeout


func _animate_number(presentation: Dictionary) -> void:
	if _number_label == null:
		return
	var draw := clampi(int(presentation.get("draw", 1)), 1, 10)
	for step in 8:
		_number_label.text = str(1 + (step % 10))
		await get_tree().create_timer(0.06).timeout
		if not is_inside_tree():
			return
	_number_label.text = str(draw)
	await get_tree().create_timer(0.2).timeout


func _animate_coin(presentation: Dictionary) -> void:
	if _coin_disc == null:
		return
	if _coin_disc:
		_coin_disc.pivot_offset = _coin_disc.custom_minimum_size * 0.5
	for step in 4:
		if _coin_disc and _coin_disc.has_method("set_side"):
			var side := "heads"
			if step % 2 == 0:
				side = "edge"
			_coin_disc.set_side(side)
			var flip := create_tween()
			flip.tween_property(_coin_disc, "scale:x", 0.08, 0.05)
			await flip.finished
			if not is_inside_tree():
				return
			var back := create_tween()
			back.tween_property(_coin_disc, "scale:x", 1.0, 0.05)
			await back.finished
		if not is_inside_tree():
			return
	var face := str(presentation.get("face", ""))
	if _coin_disc and _coin_disc.has_method("set_side"):
		_coin_disc.set_side(face)
	var won: bool = bool(presentation.get("won", false))
	if _coin_disc:
		_coin_disc.modulate = Color("D9FFE8") if won else Color("FFD5DC")
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
		if index < _cell_faces.size():
			_cell_faces[index].visible = text != ""
			_cell_faces[index].set_symbol(_symbol_id(text))
			_cell_faces[index].set_winning(_has_int(hits, index))
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
		if index < _cell_faces.size():
			_cell_faces[index].visible = text != ""
			_cell_faces[index].set_symbol(_symbol_id(text))
			_cell_faces[index].set_winning(index < combo)
		_cell_labels[index].modulate.a = 0.0
		if index < combo:
			_cell_labels[index].add_theme_color_override("font_color", UiTheme.COL_GOLD)
		var tween := _cell_labels[index].create_tween()
		tween.tween_property(_cell_labels[index], "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree():
			return
	_status.text = "Combo  %d" % combo


func _animate_cards(presentation: Dictionary) -> void:
	if _player_card == null or _house_card == null:
		return
	_player_card.modulate.a = 0.0
	_house_card.modulate.a = 0.0
	var enter := create_tween()
	enter.set_parallel(true)
	enter.tween_property(_house_card, "modulate:a", 1.0, 0.16)
	enter.tween_property(_player_card, "modulate:a", 1.0, 0.16)
	await enter.finished
	if not is_inside_tree():
		return
	var house_value: Variant = presentation.get("house", {})
	var player_value: Variant = presentation.get("player", {})
	if house_value is Dictionary:
		var house: Dictionary = house_value
		await _house_card.reveal_card(str(house.get("rank", "?")), str(house.get("suit", "spades")))
	if not is_inside_tree():
		return
	if player_value is Dictionary:
		var player: Dictionary = player_value
		await _player_card.reveal_card(str(player.get("rank", "?")), str(player.get("suit", "hearts")))


func _symbol_id(value: String) -> String:
	match value.to_lower():
		"$", "dollar":
			return "dollar"
		"*", "star":
			return "star"
		"#", "diamond":
			return "diamond"
		"7", "seven":
			return "seven"
		"o", "coin":
			return "coin"
		"+", "bonus":
			return "bonus"
		"ruby", "gold", "jade", "blue":
			return value.to_lower()
		_:
			return "coin"


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
	var outcome := ""
	var presentation_value: Variant = data.get("presentation", {})
	if presentation_value is Dictionary:
		outcome = str(presentation_value.get("outcome", ""))
	if outcome == "push":
		_present_result("Push", "Stake returned", UiTheme.COL_GOLD)
		_delta.text = "Stake returned"
		_delta.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	elif win > 0.0:
		var won_title := "You won"
		var won_detail := "+%s Credits" % _amount(win)
		if outcome == "" and presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "fishing":
			won_title = "Nice shot"
			won_detail = "%s\n+%s Credits" % [str(presentation_value.get("name", "Fish")), _amount(win)]
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "targets":
			won_title = "Targets hit"
			won_detail = "+%s Credits" % _amount(win)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "flight":
			won_title = "Smooth flight"
			won_detail = "+%s Credits" % _amount(win)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "bottles":
			won_title = "Bottles smashed"
			won_detail = "+%s Credits" % _amount(win)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "mystery":
			won_title = "Box opened"
			won_detail = "+%s Credits" % _amount(win)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "dice":
			won_title = "Rolled"
			won_detail = "%s\n+%s Credits" % [str(data.get("title", "Dice")), _amount(win)]
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "number":
			won_title = "Number hit"
			won_detail = "%s\n+%s Credits" % [str(data.get("title", "Number")), _amount(win)]
		_present_result(won_title, won_detail, UiTheme.COL_GREEN)
		_delta.text = "+%s Credits" % _amount(win)
		_delta.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		if _player_card:
			_player_card.set_highlight(true)
	else:
		var lost_title := "Try again"
		var lost_detail := "-%s Credits" % _amount(_bet)
		if presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "fishing":
			lost_title = "Got away"
			lost_detail = "%s\n-%s Credits" % [str(presentation_value.get("name", "No catch")), _amount(_bet)]
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "targets":
			lost_title = "No hit"
			lost_detail = "-%s Credits" % _amount(_bet)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "flight":
			lost_title = "Empty sky"
			lost_detail = "-%s Credits" % _amount(_bet)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "bottles":
			lost_title = "No break"
			lost_detail = "-%s Credits" % _amount(_bet)
		elif presentation_value is Dictionary and str(presentation_value.get("kind", "")) == "mystery":
			lost_title = "Empty box"
			lost_detail = "-%s Credits" % _amount(_bet)
		_present_result(lost_title, lost_detail, UiTheme.COL_MUTED)
		_delta.text = "-%s Credits" % _amount(_bet)
		_delta.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		if _house_card:
			_house_card.set_highlight(true)


func _present_result(title: String, detail: String, color: Color) -> void:
	if _result_kicker:
		_result_kicker.text = title
		_result_kicker.add_theme_color_override("font_color", color)
	_result.text = detail
	_result.add_theme_color_override("font_color", color)
	if _result_panel == null:
		return
	_result_panel.visible = true
	_result_panel.pivot_offset = _result_panel.size * 0.5
	UiMotion.pop_in(_result_panel)
	if color == UiTheme.COL_GREEN and _credits:
		UiMotion.pulse_selected(_credits)


func _set_balance(next: float, animate: bool) -> void:
	var start := _shown_balance if _shown_balance >= 0.0 else next
	_balance = next
	ApiClient.balance_cache = next
	if not animate or is_equal_approx(start, next):
		_shown_balance = next
		_credits.text = "%s Credits" % _amount(next)
		return
	if _balance_tween and _balance_tween.is_valid():
		_balance_tween.kill()
	var tween := create_tween()
	_balance_tween = tween
	var delta := next - start
	tween.tween_method(func(value: float) -> void:
		_shown_balance = value
		_credits.text = "%s Credits" % _amount(value)
	, start, next, 0.35)
	if not is_zero_approx(delta):
		var shown := _amount(absf(delta))
		UiMotion.float_delta(self, _credits, ("+%s" if delta > 0.0 else "-%s") % shown, delta > 0.0)


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


func _paint_stage() -> void:
	var accent := UiTheme.game_accent(_slug)
	var background := get_node_or_null("Background") as ColorRect
	if background:
		background.color = Color(accent.r * 0.14 + 0.03, accent.g * 0.1 + 0.03, accent.b * 0.16 + 0.04, 1.0)
	UiTheme.mood(self, "game", accent)
	# Keep the shared Neon Casino environment as the gameplay backdrop.
	# Atmosphere only — mute promotional background text during gameplay.
	ArcadeBackdrop.mount_photo(self, GameArt.screen_path("gameplay"), 0.66, 0.1)


func _hint() -> String:
	match _slug:
		"fishing":
			return "Aim the cannon and shoot the glowing fish."
		"target-blast":
			return "Hit the targets before they fade."
		"aeroplane-rush":
			return "Drag the plane and collect the coins."
		"bottle-blast":
			return "Aim the launcher and break the bottles."
		"scratch-mania":
			return "Scratch the foil to reveal the symbols."
		"coin-flip":
			return "Call heads or tails, then flip."
		"treasure-box":
			return "Choose a chest."
		"mystery-box":
			return "Open the sealed chest."
		"diamond-spin":
			return "Spin the crystal wheel."
		"fruit-spin":
			return "Spin the fruit wheel."
		"dollar-rush":
			return "Pick a lane before the rush."
		"cash-match":
			return "Reveal the cards and match the symbols."
		"diamond-drop":
			return "Watch the gems fall into a combo."
		"bonus-burst":
			return "Collect the burst before time runs out."
		"higher-card":
			return "Draw higher than the house."
		"dice":
			return "Roll for sevens and doubles."
		"lucky-number":
			return "Pick a number from 1 to 10."
		_:
			return "Ready"


func _pulse_board() -> void:
	if _board_panel == null:
		return
	_board_panel.pivot_offset = _board_panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(_board_panel, "scale", Vector2(0.985, 0.985), 0.08)
	tween.tween_property(_board_panel, "scale", Vector2.ONE, 0.14)


func _rest_arcade() -> void:
	if _pond and is_instance_valid(_pond):
		_pond.show_idle()
	if _gallery and is_instance_valid(_gallery):
		_gallery.show_idle()
	if _sky and is_instance_valid(_sky):
		_sky.show_idle()
	if _bottles and is_instance_valid(_bottles):
		_bottles.show_idle()


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
		"higher-card":
			return "CARDS"
		"fruit-spin", "lucky-wheel", "prize-spinner", "diamond-spin":
			return "SPIN"
		"fishing":
			return "FISHING"
		"target-blast", "aeroplane-rush", "bottle-blast":
			return "REACTION"
		"mystery-box":
			return "CHOICE"
		"dice":
			return "CHOICE"
		"lucky-number":
			return "MATCH"
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
	UiMotion.pulse_selected(button)
	if button.has_method("refresh"):
		button.refresh()
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
		if button.has_method("refresh"):
			button.refresh()
	_scratch_done = true


func _show_low_credits() -> void:
	if _low:
		_low.visible = true
		UiMotion.pop_in(_low)
	_status.text = "Not enough credits"


func _show_ask() -> void:
	if _low:
		_low.visible = false
	if _ask:
		_ask.visible = true
		UiMotion.pop_in(_ask)
		_ask_amount.text = str(maxi(_min * 10, 50))
		_ask_note.text = ""


func _send_request() -> void:
	var amount := int(_ask_amount.text)
	if amount <= 0:
		_ask_note.text = "Enter an amount."
		_ask_note.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		_ask_amount.modulate = Color(1.0, 0.86, 0.88)
		UiMotion.reveal(_ask_note)
		return
	_ask_amount.modulate = Color.WHITE
	_ask_note.text = "Sending..."
	var message := ""
	if _ask:
		var note_field := _ask.find_child("RequestNote", true, false) as LineEdit
		if note_field:
			message = note_field.text
	var response: Dictionary = await ApiClient.request_credits(amount, message)
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
	ask.text = "Request Credits"
	ask.theme_type_variation = "PrimaryButton"
	ask.custom_minimum_size = Vector2(0, 48)
	ask.pressed.connect(_show_ask)
	low_box.add_child(ask)
	var back := Button.new()
	back.text = "Back to Games"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_leave)
	low_box.add_child(back)
	_low.visibility_changed.connect(func() -> void:
		if _low.visible:
			low_meta.text = "AVAILABLE CREDITS\n%s\n\nREQUIRED\n%s" % [_amount(maxf(_balance, 0.0)), _amount(_min)]
	)

	_ask = _overlay_panel()
	var ask_box := _ask.get_meta("box") as VBoxContainer
	var ask_title := Label.new()
	ask_title.text = "Send a credit request to the administrator?"
	ask_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_box.add_child(ask_title)
	_ask_amount = LineEdit.new()
	_ask_amount.placeholder_text = "Requested amount"
	_ask_amount.custom_minimum_size = Vector2(0, 48)
	ask_box.add_child(_ask_amount)
	var ask_message := LineEdit.new()
	ask_message.name = "RequestNote"
	ask_message.placeholder_text = "Optional note"
	ask_message.custom_minimum_size = Vector2(0, 48)
	ask_box.add_child(ask_message)
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
	var play_height := clampf(size.y - 230.0, 380.0, 620.0)
	if _pond:
		_pond.custom_minimum_size = Vector2(0, play_height)
	if _gallery:
		_gallery.custom_minimum_size = Vector2(0, play_height)
	if _sky:
		_sky.custom_minimum_size = Vector2(0, play_height)
	if _bottles:
		_bottles.custom_minimum_size = Vector2(0, play_height)
	var card_w := clampf(size.x * 0.34, 112.0, 150.0)
	if _player_card:
		_player_card.custom_minimum_size = Vector2(card_w, card_w * 1.42)
	if _house_card:
		_house_card.custom_minimum_size = Vector2(card_w, card_w * 1.42)


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
	var cap := 300.0
	if _slug == "jackpot-wheel" or _slug == "diamond-spin":
		cap = 360.0
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
	var symbols: Array = []
	var style := "wheel"
	var winner := -1
	var pointer_drop := 0.0:
		set(value):
			pointer_drop = value
			queue_redraw()
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
			var color := _segment_color(index, style)
			if index == winner:
				color = Color("3DDC97")
			draw_colored_polygon(points, color)
			draw_line(center, center + Vector2(cos(start), sin(start)) * radius, Color(0, 0, 0, 0.45), 2.0)
			var fruit_at := center + Vector2(cos(start + sweep * 0.5), sin(start + sweep * 0.5)) * radius * 0.38
			draw_circle(fruit_at, maxf(radius * 0.09, 7.0), _fruit_color(index, symbols))
			draw_arc(fruit_at, maxf(radius * 0.09, 7.0), 0.0, TAU, 12, Color(1, 1, 1, 0.28), 1.5, true)
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
		var hub := radius * (0.22 if style == "spinner" else 0.16)
		draw_circle(center, hub, Color("121A2C"))
		draw_circle(center, hub * 0.62, Color("F5C542") if style != "spinner" else Color("8B7CFF"))
		var tip := center + Vector2(0, -radius + 6.0 + pointer_drop)
		var left := center + Vector2(-14, -radius - 16.0)
		var right := center + Vector2(14, -radius - 16.0)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color("FFF8E6"))

	func _segment_color(index: int, wheel_style: String) -> Color:
		var palette: Array[Color] = [Color("C43848"), Color("18243A"), Color("E08A20"), Color("1E3A2A"), Color("5A3D8A"), Color("8A1E32")]
		if wheel_style == "lucky":
			palette = [Color("1A2744"), Color("C8962E"), Color("142033"), Color("8A6A20"), Color("10182A"), Color("E0A82E")]
		elif wheel_style == "spinner":
			palette = [Color("161028"), Color("2A2150"), Color("10182A"), Color("3A2A68")]
		elif wheel_style == "fruit":
			palette = [Color("3A1820"), Color("2A2408"), Color("2A1A0C"), Color("102418"), Color("1A1230"), Color("2C1218")]
		elif wheel_style == "diamond":
			palette = [Color("14102A"), Color("102433"), Color("1A1040"), Color("0E2438"), Color("241438"), Color("102030")]
		return palette[index % palette.size()]


	func _fruit_color(index: int, marks: Array) -> Color:
		var symbol := str(marks[index]) if index < marks.size() else ""
		match symbol:
			"cherry", "berry":
				return Color("E23B45")
			"lemon":
				return Color("F2D24B")
			"orange":
				return Color("F08A24")
			"melon":
				return Color("3DDC97")
			"grapes":
				return Color("7A4AD0")
			"diamond", "seven", "crystal", "sapphire":
				return Color("8EE7FF")
			"ruby":
				return Color("E23B55")
			"emerald", "jade":
				return Color("3DDC97")
			"amethyst":
				return Color("B388FF")
			"star", "dollar", "bonus":
				return Color("F5C542")
			_:
				return Color("E0A82E")


	func _label(value: Variant) -> String:
		var amount := float(value)
		if is_equal_approx(amount, round(amount)):
			return str(int(round(amount)))
		return "%.1f" % amount


class DieFace:
	extends Control

	var face := 1


	func set_face(value: int) -> void:
		face = clampi(value, 1, 6)
		queue_redraw()


	func _draw() -> void:
		var body := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if body.size.x < 8.0:
			return
		draw_rect(body, Color("F4F7FB"), true)
		draw_rect(body, Color("C8962E"), false, 3.0)
		var ink := Color("141008")
		var spots := _spots(face)
		var radius := minf(body.size.x, body.size.y) * 0.08
		for spot in spots:
			draw_circle(body.position + Vector2(spot) * body.size, radius, ink)


	func _spots(value: int) -> Array:
		var mid := Vector2(0.5, 0.5)
		var left := 0.28
		var right := 0.72
		var top := 0.28
		var bottom := 0.72
		match value:
			1:
				return [mid]
			2:
				return [Vector2(left, top), Vector2(right, bottom)]
			3:
				return [Vector2(left, top), mid, Vector2(right, bottom)]
			4:
				return [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]
			5:
				return [Vector2(left, top), Vector2(right, top), mid, Vector2(left, bottom), Vector2(right, bottom)]
			_:
				return [Vector2(left, top), Vector2(right, top), Vector2(left, mid.y), Vector2(right, mid.y), Vector2(left, bottom), Vector2(right, bottom)]
