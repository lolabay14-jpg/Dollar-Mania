extends Control

const ICONS := {
	"lucky-dollar": "dollar",
	"golden-fortune": "star",
	"dollar-rush": "bonus",
	"scratch-mania": "coin",
	"lucky-spin": "seven",
	"coin-flip": "dollar",
	"treasure-box": "diamond",
	"cash-match": "star",
	"diamond-drop": "diamond",
	"bonus-burst": "bonus",
	"jackpot-wheel": "seven",
}

@onready var _column: MarginContainer = %Column
@onready var _list: GridContainer = %GameList

var _opening := false
var _games: Array = []
var _filter := "ALL"
var _filters: HFlowContainer
var _quick: HBoxContainer


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "lobby", UiTheme.COL_GOLD)
	UiTheme.style_title(%Title, 34)
	UiTheme.style_muted(%Subtitle)
	%BackButton.pressed.connect(AppState.go_player)
	_build_filters()
	resized.connect(_fit)
	_fit()
	_load_games()


func _fit() -> void:
	var view := size
	if view.x < 8.0:
		return
	var width := minf(view.x - 28.0, 1180.0)
	var side := maxf((view.x - width) * 0.5, 14.0)
	_column.add_theme_constant_override("margin_left", int(side))
	_column.add_theme_constant_override("margin_right", int(side))
	_column.add_theme_constant_override("margin_top", 20)
	_column.add_theme_constant_override("margin_bottom", 28)
	var columns := 1
	if width >= 980.0:
		columns = 4
	elif width >= 720.0:
		columns = 3
	elif width >= 460.0:
		columns = 2
	_list.columns = columns


func _load_games() -> void:
	for child in _list.get_children():
		child.queue_free()
	%Subtitle.text = "Loading games..."
	var response: Dictionary = await ApiClient.get_slot_games()
	if not is_inside_tree():
		return
	if not response.ok:
		%Subtitle.text = str(response.error)
		return
	var games: Array = response.data.get("games", [])
	if games.is_empty():
		%Subtitle.text = "No games are active right now."
		return
	%Subtitle.text = "Virtual credits only. Every active game is open."
	_games = games
	_render_games()
	await get_tree().process_frame
	if is_inside_tree():
		UiMotion.settle(%Column)


func _build_filters() -> void:
	var content := _list.get_parent()
	_filters = HFlowContainer.new()
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filters.add_theme_constant_override("h_separation", 8)
	_filters.add_theme_constant_override("v_separation", 8)
	content.add_child(_filters)
	content.move_child(_filters, _list.get_index())
	for label in ["All", "Easy", "Medium", "Hard", "Slots", "Spin", "Scratch"]:
		var button := Button.new()
		button.text = label
		button.toggle_mode = true
		button.button_pressed = label == "All"
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_set_filter.bind(label.to_upper()))
		_filters.add_child(button)
	var quick_title := Label.new()
	quick_title.text = "Quick Play"
	quick_title.add_theme_font_size_override("font_size", 18)
	quick_title.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	content.add_child(quick_title)
	content.move_child(quick_title, _list.get_index())
	_quick = HBoxContainer.new()
	_quick.add_theme_constant_override("separation", 8)
	content.add_child(_quick)
	content.move_child(_quick, _list.get_index())


func _set_filter(name: String) -> void:
	_filter = name
	for child in _filters.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal(child.text.to_upper() == name)
	_render_games()


func _render_games() -> void:
	for child in _list.get_children():
		child.queue_free()
	for child in _quick.get_children():
		child.queue_free()
	var shown := 0
	for game in _games:
		if not game is Dictionary:
			continue
		if str(game.get("slug", "")) in ["lucky-dollar", "scratch-mania", "lucky-spin"]:
			_quick.add_child(_make_quick(game))
		if not _matches(game):
			continue
		var card := _make_card(game)
		card.modulate.a = 0.0
		_list.add_child(card)
		var tween := card.create_tween()
		tween.tween_interval(minf(float(shown) * 0.03, 0.24))
		tween.tween_property(card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		shown += 1
	if shown == 0:
		%Subtitle.text = "No games match this filter."
	else:
		%Subtitle.text = "Virtual credits only. Every active game is open."
	UiMotion.bind_tree(_list)


func _matches(game: Dictionary) -> bool:
	var difficulty := str(game.get("difficulty", "")).to_upper()
	var category := str(game.get("category", "")).to_upper()
	match _filter:
		"EASY", "MEDIUM", "HARD":
			return difficulty == _filter
		"SLOTS", "SPIN", "SCRATCH":
			return category == _filter
		_:
			return true


func _make_quick(game: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(game.get("name", "Play"))
	button.theme_type_variation = "PrimaryButton"
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_open_game.bind(game, button))
	return button


func _make_card(game: Dictionary) -> PanelContainer:
	var slug := str(game.get("slug", ""))
	var accent := UiTheme.game_accent(slug)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(220, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.paint_card(card, accent)
	card.mouse_entered.connect(func() -> void:
		if not _opening:
			UiTheme.paint_card(card, accent, true)
	)
	card.mouse_exited.connect(func() -> void:
		if not _opening:
			UiTheme.paint_card(card, accent, false)
	)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(0, 96)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(accent, 0.16)
	wash.set_corner_radius_all(14)
	art.add_theme_stylebox_override("panel", wash)
	box.add_child(art)
	var art_center := CenterContainer.new()
	art.add_child(art_center)
	var face := SymbolView.new()
	face.custom_minimum_size = Vector2(72, 72)
	face.set_symbol(str(ICONS.get(slug, "coin")))
	art_center.add_child(face)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	box.add_child(heading)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	heading.add_child(titles)

	var title := Label.new()
	title.text = str(game.get("name", "Game"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", accent)
	titles.add_child(title)

	var difficulty := Label.new()
	var category := str(game.get("category", ""))
	difficulty.text = "%s  ·  %s" % [category, str(game.get("difficulty", ""))] if category != "" else str(game.get("difficulty", ""))
	UiTheme.style_muted(difficulty)
	titles.add_child(difficulty)

	var blurb := Label.new()
	blurb.text = str(game.get("description", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(blurb)
	box.add_child(blurb)

	var limits := Label.new()
	limits.text = "Min Bet: %s    Max Bet: %s" % [_whole(game.get("minimumBet", 0)), _whole(game.get("maximumBet", 0))]
	box.add_child(limits)

	var play := Button.new()
	play.text = "Play"
	play.theme_type_variation = "PrimaryButton"
	play.custom_minimum_size = Vector2(0, 46)
	play.pressed.connect(_open_game.bind(game, card))
	box.add_child(play)
	return card


func _open_game(game: Dictionary, card: Control) -> void:
	if _opening:
		return
	_opening = true
	card.pivot_offset = card.size * 0.5
	card.modulate = Color(0.82, 0.78, 0.66)
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(0.98, 0.98), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(card, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not is_inside_tree():
		return
	AppState.selected_game = {
		"id": str(game.get("id", "")),
		"slug": str(game.get("slug", "")),
		"name": str(game.get("name", "")),
		"difficulty": str(game.get("difficulty", "")),
		"category": str(game.get("category", "")),
		"description": str(game.get("description", "")),
		"min_bet": int(game.get("minimumBet", 1)),
		"max_bet": int(game.get("maximumBet", 1)),
	}
	AppState.selected_slot_id = str(game.get("slug", ""))
	AppState.go_machine()


func _whole(value: Variant) -> String:
	return str(int(round(float(value))))
