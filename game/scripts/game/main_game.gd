extends Node2D

const COIN_SCENE := preload("res://game/scenes/coin.tscn")

var _bounds := Rect2()
var _score := 0
var _time_left := GameConfig.ROUND_SECONDS
var _spawn_wait := 0.0
var _finished := false
var _ready_to_play := false
var _opening_spawned := false
var _player_radius := 18.0
var _coin_radius := 14.0

@onready var _player: CharacterBody2D = $Player
@onready var _coins: Node2D = $Coins
@onready var _pause_menu: CanvasLayer = $PauseLayer
@onready var _touch: Control = $HUD/Root/TouchControls
@onready var _score_label: Label = %ScoreLabel
@onready var _time_label: Label = %TimeLabel
@onready var _credits_label: Label = %CreditsLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	if not AppState.consume_paid_entry():
		var error := AppState.try_start_game()
		if error != "":
			AppState.go_player()
		return

	UiTheme.apply($HUD/Root)
	_time_label.add_theme_color_override("font_color", UiTheme.COL_GOLD)
	UiTheme.style_muted(_hint_label)
	_pause_menu.resume_pressed.connect(_set_paused.bind(false))
	_pause_menu.restart_pressed.connect(_on_restart)
	%PauseButton.pressed.connect(_set_paused.bind(true))
	%FinishButton.pressed.connect(_end_round)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_layout):
		viewport.size_changed.connect(_layout)
	_layout()
	_ready_to_play = true
	_refresh_hud()


func _process(delta: float) -> void:
	if not _ready_to_play or _finished:
		return
	_time_left -= delta
	_spawn_wait -= delta
	if _spawn_wait <= 0.0:
		_spawn_coin()
		_spawn_wait = GameConfig.COIN_SPAWN_INTERVAL
	_refresh_hud()
	if _time_left <= 0.0:
		_end_round()


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_play or _finished:
		return
	if event.is_action_pressed("pause_game"):
		_set_paused(true)
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.x < 10.0 or view.y < 10.0:
		return
	_touch.refresh_visibility()
	var top := 128.0
	var side := 18.0
	var bottom := 176.0 if _touch.visible else 20.0
	_bounds = Rect2(side, top, maxf(view.x - side * 2.0, 40.0), maxf(view.y - top - bottom, 40.0))
	var short_side := minf(_bounds.size.x, _bounds.size.y)
	_player_radius = clampf(short_side * 0.045, 14.0, 26.0)
	_coin_radius = clampf(short_side * 0.034, 11.0, 20.0)
	_player.play_bounds = _bounds
	_player.set_radius(_player_radius)
	if not _opening_spawned:
		_player.position = _bounds.get_center()
		_opening_spawned = true
		for _index in GameConfig.OPENING_COINS:
			_spawn_coin()
		_spawn_wait = GameConfig.COIN_SPAWN_INTERVAL
	else:
		_player.play_bounds = _bounds
		for coin in _coins.get_children():
			if coin.has_method("keep_inside"):
				coin.keep_inside(_bounds)
	_hint_label.visible = not _touch.visible
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	draw_rect(view, UiTheme.COL_BG, true)
	if _bounds.size.x < 10.0:
		return
	draw_rect(_bounds, Color("10192B"), true)
	var spacing := 48.0
	var grid := Color(0.18, 0.24, 0.36, 0.45)
	var x := _bounds.position.x
	while x <= _bounds.end.x:
		draw_line(Vector2(x, _bounds.position.y), Vector2(x, _bounds.end.y), grid, 1.0)
		x += spacing
	var y := _bounds.position.y
	while y <= _bounds.end.y:
		draw_line(Vector2(_bounds.position.x, y), Vector2(_bounds.end.x, y), grid, 1.0)
		y += spacing
	draw_rect(_bounds, Color("2C3C58"), false, 3.0)


func _spawn_coin() -> void:
	if _coins.get_child_count() >= GameConfig.MAX_COINS:
		return
	var coin := COIN_SCENE.instantiate()
	coin.collected.connect(_on_coin_collected)
	_coins.add_child(coin)
	coin.setup(_coin_position(), _coin_radius)


func _coin_position() -> Vector2:
	var limit := _bounds.grow(-_coin_radius)
	if limit.size.x <= 0.0 or limit.size.y <= 0.0:
		return _bounds.get_center()
	for _attempt in 8:
		var point := Vector2(
			randf_range(limit.position.x, limit.end.x),
			randf_range(limit.position.y, limit.end.y)
		)
		if point.distance_to(_player.position) > _player_radius * 4.0:
			return point
	return limit.get_center()


func _on_coin_collected() -> void:
	_score += GameConfig.POINTS_PER_COIN
	_refresh_hud()


func _refresh_hud() -> void:
	var balance := CreditService.get_balance(CreditService.get_active_player_id())
	_score_label.text = "Score  %d" % _score
	_credits_label.text = "Credits  %d" % balance
	_time_label.text = _format_time(_time_left)


func _format_time(seconds: float) -> String:
	var total := maxi(ceili(seconds), 0)
	return "%d:%02d" % [int(total / 60.0), total % 60]


func _set_paused(paused: bool) -> void:
	if _finished:
		return
	GameInput.release_movement()
	get_tree().paused = paused
	if paused:
		_pause_menu.open()
	else:
		_pause_menu.close()


func _on_restart() -> void:
	var error := AppState.try_start_game()
	if error != "":
		_pause_menu.show_message(error)


func _end_round() -> void:
	if _finished:
		return
	_finished = true
	get_tree().paused = false
	GameInput.release_movement()
	AppState.finish_game(_score)
