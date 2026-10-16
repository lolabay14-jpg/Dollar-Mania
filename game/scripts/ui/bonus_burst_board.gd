class_name BonusBurstBoard
extends Control

## Timed burst round. The server already chose how many bursts count.
## Taps reveal that result. Decoys never add a payout.

signal finished

var _phase := "idle"
var _closed := false
var _paused := false
var _left := 6.0
var _goal := 0
var _got := 0
var _orbs: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _font: Font
var _catch: Button
var _chain_at := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_catch = Button.new()
	_catch.text = "Catch"
	_catch.theme_type_variation = "PrimaryButton"
	_catch.custom_minimum_size = Vector2(120, 52)
	_catch.focus_mode = Control.FOCUS_NONE
	_catch.pressed.connect(_catch_nearest)
	add_child(_catch)
	resized.connect(_place_controls)
	show_idle()


func show_idle() -> void:
	_phase = "idle"
	_paused = false
	_closed = false
	_orbs.clear()
	_fx.clear()
	_pops.clear()
	_got = 0
	_goal = 0
	set_process(false)
	_place_controls()
	queue_redraw()


func set_paused(paused: bool) -> void:
	_paused = paused
	if _catch:
		_catch.disabled = paused or _phase != "play"
	queue_redraw()


func round_score() -> int:
	return _got


func play_round(count: int, seconds: float) -> void:
	_closed = false
	_goal = maxi(count, 0)
	_got = 0
	_chain_at = -1.0
	_left = maxf(seconds, 4.0)
	_orbs.clear()
	_fx.clear()
	_pops.clear()
	_spawn()
	_phase = "play"
	set_process(true)
	_place_controls()
	await finished


func _exit_tree() -> void:
	_complete()


func _process(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.034)
	if _paused:
		queue_redraw()
		return
	if _phase != "play":
		return
	_left = maxf(_left - delta, 0.0)
	_drift(delta)
	_step_fx(delta)
	if _left <= 0.0:
		_collect_remaining()
		_complete()
		return
	queue_redraw()


func _drift(delta: float) -> void:
	for orb in _orbs:
		if not bool(orb["alive"]):
			continue
		var vel: Vector2 = orb["vel"]
		if vel.length() < 0.04:
			vel = Vector2(0.09, 0.06)
		var pos: Vector2 = orb["pos"] + vel * delta
		if pos.x < 0.16 or pos.x > 0.84:
			vel.x = -vel.x
			pos.x = clampf(pos.x, 0.16, 0.84)
		if pos.y < 0.22 or pos.y > 0.7:
			vel.y = -vel.y
			pos.y = clampf(pos.y, 0.22, 0.7)
		orb["pos"] = pos
		orb["vel"] = vel
		orb["pulse"] = float(orb["pulse"]) + delta * 3.0


func _gui_input(event: InputEvent) -> void:
	if _paused or _phase != "play":
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
			_catch_nearest()
			accept_event()
		return
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		point = mouse.position
		pressed = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		point = touch.position
		pressed = true
	else:
		return
	if _catch and _catch.get_global_rect().has_point(get_global_transform() * point):
		return
	if pressed:
		_tap(point)
		accept_event()


func _spawn() -> void:
	var extras := 4
	var total := _goal + extras
	for index in total:
		var column := index % 3
		var row := int(float(index) / 3.0)
		_orbs.append({
			"good": index < _goal,
			"pos": Vector2(0.22 + float(column) * 0.28, 0.28 + float(row) * 0.2),
			"alive": true,
			"radius": 26.0,
			"pulse": randf() * TAU,
			"vel": Vector2(randf_range(-0.16, 0.16), randf_range(-0.12, 0.12)),
		})


func _tap(point: Vector2) -> void:
	var best := -1
	var best_distance := 9999.0
	for index in _orbs.size():
		var orb: Dictionary = _orbs[index]
		if not bool(orb["alive"]):
			continue
		var at := _orb_pos(orb)
		var distance := at.distance_to(point)
		var reach := float(orb["radius"]) + 12.0
		if distance <= reach and distance < best_distance:
			best = index
			best_distance = distance
	if best < 0:
		return
	_take(_orbs[best])


func _catch_nearest() -> void:
	if _paused or _phase != "play":
		return
	var best := -1
	var best_distance := 9999.0
	var center := size * Vector2(0.5, 0.42)
	for index in _orbs.size():
		var orb: Dictionary = _orbs[index]
		if not bool(orb["alive"]):
			continue
		var distance := _orb_pos(orb).distance_to(center)
		if distance < best_distance:
			best = index
			best_distance = distance
	if best < 0:
		return
	_take(_orbs[best])


func _take(orb: Dictionary) -> void:
	if not bool(orb["alive"]):
		return
	orb["alive"] = false
	var at := _orb_pos(orb)
	if bool(orb["good"]):
		_got += 1
		var now := Time.get_ticks_msec() / 1000.0
		if _chain_at >= 0.0 and now - _chain_at < 0.45:
			_popup(at + Vector2(0, -22), "Chain", Color("D9FFE8"))
		_chain_at = now
		_popup(at, "+1", Color("FFE38A"))
		_burst(at, Color("F5C542"), 8)
	else:
		_popup(at, "Decoy", Color("FFB4BE"))
		_burst(at, Color("FF8A9A"), 5)
	if _got >= _goal:
		_complete()


func _collect_remaining() -> void:
	for orb in _orbs:
		if bool(orb["good"]) and bool(orb["alive"]):
			orb["alive"] = false
			_got += 1
			_burst(_orb_pos(orb), Color("F5C542"), 4)


func _complete() -> void:
	if _closed:
		return
	_closed = true
	_phase = "done"
	_paused = false
	set_process(false)
	_place_controls()
	queue_redraw()
	finished.emit()


func _orb_pos(orb: Dictionary) -> Vector2:
	var anchor: Vector2 = orb["pos"]
	return Vector2(anchor.x * size.x, anchor.y * size.y)


func _burst(at: Vector2, color: Color, count: int) -> void:
	var room := 18 - _fx.size()
	for _index in mini(count, room):
		var angle := randf() * TAU
		_fx.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(24.0, 80.0),
			"life": 0.35,
			"color": color,
		})


func _popup(at: Vector2, text: String, color: Color) -> void:
	if _pops.size() > 5:
		_pops.pop_front()
	_pops.append({"pos": at, "text": text, "life": 0.6, "color": color})


func _step_fx(delta: float) -> void:
	for index in range(_fx.size() - 1, -1, -1):
		var bit: Dictionary = _fx[index]
		bit["life"] = float(bit["life"]) - delta
		bit["pos"] = bit["pos"] + bit["vel"] * delta
		if float(bit["life"]) <= 0.0:
			_fx.remove_at(index)
	for index in range(_pops.size() - 1, -1, -1):
		var pop: Dictionary = _pops[index]
		pop["life"] = float(pop["life"]) - delta
		pop["pos"] = pop["pos"] + Vector2(0, -22.0 * delta)
		if float(pop["life"]) <= 0.0:
			_pops.remove_at(index)


func _place_controls() -> void:
	if _catch == null:
		return
	_catch.position = Vector2(maxf((size.x - 140.0) * 0.5, 8.0), maxf(size.y - 64.0, 8.0))
	_catch.visible = _phase == "play"
	_catch.disabled = _paused or _phase != "play"


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 16.0 or rect.size.y < 16.0:
		return
	draw_rect(rect, Color("140E08"), true)
	draw_rect(Rect2(10, 52, size.x - 20, maxf(size.y - 128.0, 40.0)), Color("24180C"), true)
	for orb in _orbs:
		if not bool(orb["alive"]):
			continue
		var at := _orb_pos(orb)
		var pulse := 1.0 + sin(_left * 6.0 + float(orb["pulse"])) * 0.06
		var radius := float(orb["radius"]) * pulse
		draw_circle(at, radius + 8.0, Color(1.0, 0.78, 0.35, 0.16))
		draw_circle(at, radius, Color("E2A33A"))
		draw_circle(at + Vector2(-6, -6), radius * 0.28, Color(1, 1, 1, 0.35))
	for bit in _fx:
		var alpha := clampf(float(bit["life"]) / 0.35, 0.0, 1.0)
		var color: Color = bit["color"]
		color.a = alpha
		draw_circle(bit["pos"], 3.0, color)
	_draw_hud()
	for pop in _pops:
		_draw_popup(pop)
	if _paused:
		_draw_center("Paused", "Resume to continue")
	elif _phase == "idle":
		_draw_center("", "Bursts appear when the round starts")
	elif _phase == "done":
		_draw_center("Round over", "Collected  %d" % _got)
	elif _phase == "play" and _left <= 3.0:
		_draw_center(str(int(ceil(_left))), "Final seconds")


func _draw_hud() -> void:
	if _font == null:
		return
	draw_rect(Rect2(0, 0, size.x, 44), Color(0.05, 0.03, 0.02, 0.82), true)
	var time_label := "--"
	if _phase == "play":
		time_label = "%ds" % int(ceil(_left))
	draw_string(_font, Vector2(16, 28), "TIME  %s" % time_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("FFE38A"))
	var score := "COLLECTED  %d" % _got
	var score_size := _font.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(_font, Vector2(size.x - score_size.x - 16.0, 28), score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("3DDC97"))


func _draw_center(primary: String, caption: String) -> void:
	if _font == null:
		return
	if primary != "":
		var text_size := _font.get_string_size(primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 42)
		draw_string(_font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.46), primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("FFF8E6"))
	var caption_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(_font, Vector2((size.x - caption_size.x) * 0.5, size.y * 0.56), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("FFE0B0"))


func _draw_popup(pop: Dictionary) -> void:
	if _font == null:
		return
	var alpha := clampf(float(pop["life"]) / 0.6, 0.0, 1.0)
	var color: Color = pop["color"]
	color.a = alpha
	var at: Vector2 = pop["pos"]
	draw_string(_font, at, str(pop["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
