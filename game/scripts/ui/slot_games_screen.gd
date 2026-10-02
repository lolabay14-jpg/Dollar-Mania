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

const ACCENTS := {
	"lucky-dollar": Color("F5C542"),
	"golden-fortune": Color("FFE38A"),
	"dollar-rush": Color("FF8A9A"),
	"scratch-mania": Color("8EB7FF"),
	"lucky-spin": Color("3DDC97"),
	"coin-flip": Color("F5C542"),
	"treasure-box": Color("E2B15C"),
	"cash-match": Color("8FD0FF"),
	"diamond-drop": Color("7EE0FF"),
	"bonus-burst": Color("FFB45A"),
	"jackpot-wheel": Color("F5C542"),
}

@onready var _column: MarginContainer = %Column
@onready var _list: GridContainer = %GameList

var _opening := false


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.style_title(%Title, 34)
	UiTheme.style_muted(%Subtitle)
	%BackButton.pressed.connect(AppState.go_player)
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
	for game in games:
		if game is Dictionary:
			_list.add_child(_make_card(game))
	UiMotion.bind_tree(_list)
	await get_tree().process_frame
	if is_inside_tree():
		UiMotion.settle(%Column)


func _make_card(game: Dictionary) -> PanelContainer:
	var slug := str(game.get("slug", ""))
	var accent: Color = ACCENTS.get(slug, UiTheme.COL_GOLD)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(220, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func() -> void:
		if not _opening:
			card.modulate = Color(1.06, 1.04, 0.94)
	)
	card.mouse_exited.connect(func() -> void:
		if not _opening:
			card.modulate = Color.WHITE
	)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	box.add_child(heading)

	var face := SymbolView.new()
	face.custom_minimum_size = Vector2(64, 64)
	face.set_symbol(str(ICONS.get(slug, "coin")))
	heading.add_child(face)

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
	difficulty.text = str(game.get("difficulty", ""))
	UiTheme.style_muted(difficulty)
	titles.add_child(difficulty)

	var blurb := Label.new()
	blurb.text = str(game.get("description", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_muted(blurb)
	box.add_child(blurb)

	var limits := Label.new()
	limits.text = "Min %s    Max %s" % [_whole(game.get("minimumBet", 0)), _whole(game.get("maximumBet", 0))]
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
		"description": str(game.get("description", "")),
		"min_bet": int(game.get("minimumBet", 1)),
		"max_bet": int(game.get("maximumBet", 1)),
	}
	AppState.selected_slot_id = str(game.get("slug", ""))
	AppState.go_machine()


func _whole(value: Variant) -> String:
	return str(int(round(float(value))))
