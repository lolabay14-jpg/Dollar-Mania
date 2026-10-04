extends Control

@onready var _column: MarginContainer = %Column
@onready var _list: GridContainer = %GameList

var _opening := false
var _games: Array = []
var _filter := "ALL"
var _filters: HFlowContainer
var _lead: Label
var _featured: GameCard
var _popular_title: Label
var _popular: GridContainer
var _more_title: Label
var _feature_index := 0
var _feature_timer: Timer
var _feature_paused := false


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "hub", UiTheme.COL_BLUE)
	UiTheme.style_title(%Title, 36)
	%Title.text = "Games"
	%Subtitle.text = "Choose a game and start playing."
	UiTheme.style_muted(%Subtitle)
	%BackButton.text = "Lobby"
	%BackButton.pressed.connect(AppState.go_player)
	var content := _list.get_parent() as VBoxContainer
	content.add_theme_constant_override("separation", 20)
	_lead = Label.new()
	_lead.text = "Play. Spin. Win."
	_lead.add_theme_font_size_override("font_size", 20)
	_lead.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	content.add_child(_lead)
	content.move_child(_lead, %Subtitle.get_index())
	_build_filters()
	_featured = GameCard.new()
	_featured.visible = false
	_featured.play_pressed.connect(_launch)
	_featured.mouse_entered.connect(func() -> void: _feature_paused = true)
	_featured.mouse_exited.connect(func() -> void: _feature_paused = false)
	content.add_child(_featured)
	content.move_child(_featured, _list.get_index())
	_popular_title = _section_title("Popular games")
	content.add_child(_popular_title)
	content.move_child(_popular_title, _list.get_index())
	_popular = _make_grid()
	content.add_child(_popular)
	content.move_child(_popular, _list.get_index())
	_more_title = _section_title("More games")
	content.add_child(_more_title)
	content.move_child(_more_title, _list.get_index())
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 16)
	_feature_timer = Timer.new()
	_feature_timer.wait_time = 6.0
	_feature_timer.timeout.connect(_advance_feature)
	add_child(_feature_timer)
	resized.connect(_fit)
	_fit()
	_load_games()


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	return label


func _make_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	return grid


func _fit() -> void:
	var view := size
	if view.x < 8.0:
		return
	var edges := ScreenLayout.edge_margins(view)
	var inner := maxf(view.x - edges.x - edges.z, 240.0)
	var width := minf(inner, 1180.0)
	var extra := maxf(view.x - width - edges.x - edges.z, 0.0) * 0.5
	_column.add_theme_constant_override("margin_left", int(edges.x + extra))
	_column.add_theme_constant_override("margin_right", int(edges.z + extra))
	_column.add_theme_constant_override("margin_top", int(maxf(edges.y, 16.0)))
	_column.add_theme_constant_override("margin_bottom", int(edges.w))
	var columns := 1
	if width >= 1000.0:
		columns = 3
	elif width >= 640.0:
		columns = 2
	_list.columns = columns
	if _popular:
		_popular.columns = columns


func _load_games() -> void:
	for child in _list.get_children():
		child.queue_free()
	%Subtitle.text = "Loading games..."
	var response: Dictionary = await ApiClient.reload_slot_games()
	if not is_inside_tree():
		return
	if not response.ok:
		%Subtitle.text = "Games could not be loaded."
		push_error("Game list failed. HTTP %d. %s" % [int(response.get("status", 0)), str(response.get("error", ""))])
		return
	var games_value: Variant = response.data.get("games", [])
	var games: Array = games_value if games_value is Array else []
	if games.is_empty():
		%Subtitle.text = "No games are active right now."
		return
	%Subtitle.text = "Choose a game and start playing."
	_games = games
	_feature_index = 0
	_render_games()
	_feature_timer.start()
	await get_tree().process_frame
	if is_inside_tree():
		UiMotion.fade_in(%Column)


func _build_filters() -> void:
	var content := _list.get_parent()
	_filters = HFlowContainer.new()
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filters.add_theme_constant_override("h_separation", 8)
	_filters.add_theme_constant_override("v_separation", 8)
	content.add_child(_filters)
	content.move_child(_filters, _list.get_index())
	for item in [["ALL", "All"], ["SPIN", "Spin"], ["SLOTS", "Slots"], ["ARCADE", "Arcade"], ["CARDS", "Cards"], ["SPECIAL", "Special"]]:
		var button := Button.new()
		button.text = str(item[1])
		button.set_meta("group", str(item[0]))
		button.toggle_mode = true
		button.button_pressed = str(item[0]) == "ALL"
		button.custom_minimum_size = Vector2(96, 44)
		button.theme_type_variation = "SelectedButton" if str(item[0]) == "ALL" else "Button"
		button.pressed.connect(_set_filter.bind(str(item[0])))
		_filters.add_child(button)
	UiMotion.bind_tree(_filters)


func _set_filter(name: String) -> void:
	_filter = name
	for child in _filters.get_children():
		if child is Button:
			var button := child as Button
			var selected := str(button.get_meta("group", "")) == name
			button.set_pressed_no_signal(selected)
			button.theme_type_variation = "SelectedButton" if selected else "Button"
			if selected:
				UiMotion.pulse_selected(button)
	_render_games()
	if _list:
		UiMotion.fade_in(_list)


func _render_games() -> void:
	_clear_grid(_list)
	_clear_grid(_popular)
	var featured_games := _feature_pool()
	var show_sections := _filter == "ALL" and not featured_games.is_empty()
	_featured.visible = show_sections
	_popular_title.visible = show_sections
	_popular.visible = show_sections
	if show_sections:
		_show_feature(featured_games[_feature_index % featured_games.size()])
		var featured_slug := str(featured_games[_feature_index % featured_games.size()].get("slug", ""))
		var popular_count := 0
		var more_count := 0
		for game in _games:
			if not game is Dictionary:
				continue
			if str(game.get("slug", "")) == featured_slug:
				continue
			if GameCard.is_popular(game):
				_add_card(_popular, game, popular_count)
				popular_count += 1
			else:
				_add_card(_list, game, more_count)
				more_count += 1
		_popular_title.text = "Popular games"
		_more_title.text = "More games"
		_more_title.visible = more_count > 0
		_list.visible = more_count > 0
		%Subtitle.text = "Choose a game and start playing."
		return
	_more_title.visible = true
	_list.visible = true
	_more_title.text = _filter_title()
	var shown := 0
	for game in _games:
		if game is Dictionary and _matches(game):
			_add_card(_list, game, shown)
			shown += 1
	if shown == 0:
		%Subtitle.text = "No games match this filter."
		var empty := Label.new()
		empty.text = "Nothing is listed here yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_muted(empty)
		_list.add_child(empty)
	else:
		%Subtitle.text = "Choose a game and start playing."


func _filter_title() -> String:
	match _filter:
		"SPIN":
			return "Spin"
		"SLOTS":
			return "Slots"
		"ARCADE":
			return "Arcade"
		"CARDS":
			return "Cards"
		"SPECIAL":
			return "Special"
		_:
			return "Games"


func _feature_pool() -> Array:
	var pool: Array = []
	for game in _games:
		if game is Dictionary and GameCard.is_popular(game):
			pool.append(game)
	if pool.is_empty():
		for game in _games:
			if game is Dictionary:
				pool.append(game)
				break
	var ordered: Array = []
	for slug in ["fruit-spin", "lucky-wheel", "prize-spinner", "lucky-dollar", "fishing", "higher-card"]:
		for game in pool:
			if game is Dictionary and str(game.get("slug", "")) == slug:
				ordered.append(game)
	for game in pool:
		if game is Dictionary and not ordered.has(game):
			ordered.append(game)
	return ordered


func _show_feature(game: Dictionary) -> void:
	_featured.configure(game, true, true, "Min bet %s    Max bet %s" % [
		_whole(game.get("minimumBet", 0)),
		_whole(game.get("maximumBet", 0)),
	])
	UiMotion.bind_tree(_featured)
	_featured.visible = true


func _advance_feature() -> void:
	if _feature_paused or _filter != "ALL" or _opening:
		return
	var pool := _feature_pool()
	if pool.size() < 2:
		return
	_feature_index = (_feature_index + 1) % pool.size()
	_show_feature(pool[_feature_index])
	_featured.modulate.a = 0.0
	var tween := _featured.create_tween()
	tween.tween_property(_featured, "modulate:a", 1.0, 0.28)


func _matches(game: Dictionary) -> bool:
	match _filter:
		"SPIN", "SLOTS", "ARCADE", "CARDS", "SPECIAL":
			return GameCard.group_of(game) == _filter
		_:
			return true


func _add_card(grid: GridContainer, game: Dictionary, index: int) -> void:
	var card := _make_card(game)
	card.modulate.a = 0.0
	grid.add_child(card)
	var tween := card.create_tween()
	tween.tween_interval(minf(float(index) * 0.03, 0.24))
	tween.tween_property(card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _clear_grid(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()


func _make_card(game: Dictionary) -> PanelContainer:
	var card := GameCard.new()
	card.configure(game, false, true, "Min bet %s    Max bet %s" % [
		_whole(game.get("minimumBet", 0)),
		_whole(game.get("maximumBet", 0)),
	])
	card.play_pressed.connect(_launch)
	UiMotion.bind_tree(card)
	return card


func _launch(game: Dictionary) -> void:
	if _opening:
		return
	_opening = true
	_start_game(game)


func _start_game(game: Dictionary) -> void:
	AppState.selected_game = {
		"id": str(game.get("id", "")),
		"slug": str(game.get("slug", "")),
		"name": str(game.get("name", "")),
		"category": str(game.get("category", "")),
		"description": str(game.get("description", "")),
		"min_bet": int(game.get("minimumBet", 1)),
		"max_bet": int(game.get("maximumBet", 1)),
	}
	AppState.selected_slot_id = str(game.get("slug", ""))
	AppState.go_machine()


func _whole(value: Variant) -> String:
	return str(int(round(float(value))))
