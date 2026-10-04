extends Control

var _rules: Dictionary = {}
var _bet := 10
var _spinning := false
var _reels: Array = []

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	var game: Dictionary = AppState.selected_game
	var slug := str(game.get("slug", AppState.selected_slot_id))
	_rules = SlotCatalog.get_game(slug)
	if _rules.is_empty():
		_rules = SlotCatalog.lucky_dollar()
	if not game.is_empty():
		_rules["id"] = str(game.get("id", ""))
		_rules["name"] = str(game.get("name", _rules.get("name", "Lucky Dollar")))
		_rules["difficulty"] = str(game.get("difficulty", _rules.get("difficulty", "")))
		_rules["min_bet"] = int(game.get("min_bet", _rules.get("min_bet", 10)))
		_rules["max_bet"] = int(game.get("max_bet", _rules.get("max_bet", 40)))
	_bet = int(_rules["min_bet"])
	%SpinButton.theme_type_variation = "PrimaryButton"
	%BackButton.pressed.connect(AppState.go_slots)
	%SpinButton.pressed.connect(_on_spin)
	%BetDown.pressed.connect(_change_bet.bind(-1))
	%BetUp.pressed.connect(_change_bet.bind(1))
	resized.connect(_fit)
	_fit()
	_build_reels()
	_refresh_credits()
	_refresh_bet()
	%WinLabel.text = "Win  0"
	%StatusLabel.text = "Center line pays. The server decides the result."
	if str(_rules.get("id", "")) == "":
		%StatusLabel.text = "Open this game from Slot Games."
		%SpinButton.disabled = true
	UiTheme.style_title(%Title, 30)
	UiTheme.style_muted(%Difficulty)
	UiTheme.style_muted(%StatusLabel)
	%WinLabel.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	UiMotion.fade_in(%Column)
	UiMotion.bind_tree(self)
	%SpinButton.grab_focus()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 720.0)


func _build_reels() -> void:
	for child in %ReelRow.get_children():
		child.queue_free()
	_reels.clear()
	var script := load("res://game/scripts/ui/reel_view.gd")
	for _index in 3:
		var reel: PanelContainer = script.new()
		reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%ReelRow.add_child(reel)
		_reels.append(reel)
		reel.show_random(_rules)


func _change_bet(direction: int) -> void:
	if _spinning:
		return
	var step := int(_rules["bet_step"])
	var next := _bet + step * direction
	_bet = clampi(next, int(_rules["min_bet"]), int(_rules["max_bet"]))
	_refresh_bet()


func _on_spin() -> void:
	if _spinning:
		return
	var game_id := str(_rules.get("id", ""))
	if game_id == "":
		%StatusLabel.text = "Open this game from Slot Games."
		%StatusLabel.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	_spinning = true
	%SpinButton.disabled = true
	%SpinButton.text = "Spinning..."
	%StatusLabel.text = "Reels are spinning."
	%StatusLabel.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	%WinLabel.text = "Win  0"
	for reel in _reels:
		reel.highlight([])
	var response: Dictionary = await ApiClient.spin(game_id, _bet)
	if not is_inside_tree():
		return
	if not response.ok:
		_spinning = false
		%SpinButton.disabled = false
		_refresh_bet()
		%StatusLabel.text = str(response.error)
		%StatusLabel.add_theme_color_override("font_color", UiTheme.COL_DANGER)
		return
	var data: Dictionary = response.data
	await _animate(_map_grid(data.get("grid", [])))
	if not is_inside_tree():
		return
	var payout := int(data.get("winAmount", 0))
	%CreditsLabel.text = "Credits  %d" % int(data.get("balance", 0))
	if payout > 0:
		%WinLabel.text = "Win  %d" % payout
		%StatusLabel.text = str(data.get("title", "Win"))
		%StatusLabel.add_theme_color_override("font_color", UiTheme.COL_GREEN)
	else:
		%WinLabel.text = "Win  0"
		%StatusLabel.text = "No win. Spin again."
		%StatusLabel.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	var highlights: Array = data.get("highlights", [])
	for index in _reels.size():
		if _highlighted(highlights, index):
			_reels[index].highlight([1])
		else:
			_reels[index].highlight([])
	_spinning = false
	%SpinButton.disabled = false
	_refresh_bet()


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


func _highlighted(highlights: Array, index: int) -> bool:
	for value in highlights:
		if int(value) == index:
			return true
	return false


func _animate(grid: Array) -> void:
	var stop_times: Array = _rules["stop_times"]
	var stopped := [false, false, false]
	var elapsed := 0.0
	while stopped.has(false):
		await get_tree().create_timer(0.06).timeout
		if not is_inside_tree():
			return
		elapsed += 0.06
		for index in 3:
			if elapsed < float(stop_times[index]):
				_reels[index].show_random(_rules)
			elif not stopped[index]:
				_reels[index].show_column(grid[index])
				_reels[index].bounce()
				stopped[index] = true


func _refresh_credits() -> void:
	%Title.text = str(_rules.get("name", "Lucky Dollar"))
	%Difficulty.visible = false
	var wallet: Dictionary = await ApiClient.get_wallet()
	if not is_inside_tree():
		return
	if wallet.ok:
		%CreditsLabel.text = "Credits  %d" % int(wallet.data.get("balance", 0))
	else:
		%CreditsLabel.text = "Credits"


func _refresh_bet() -> void:
	%BetLabel.text = "Bet  %d" % _bet
	if not _spinning:
		%SpinButton.text = "Spin  ·  %d" % _bet
