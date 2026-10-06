class_name SkyRush
extends Control

## Arcade flight. Coin values are shares of the server prize.

signal finished

var _phase := "idle"
var _closed := false
var _time := 0.0
var _left := 12.0
var _duration := 12.0
var _plane_y := 0.5
var _target_y := 0.5
var _coins: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _bet := 0
var _credits := 0.0
var _score := 0
var _shown_reward := 0.0
var _count_n := 3
var _count_t := 0.0
var _finale := 0.0
var _flushed := false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_seed_clouds()
	show_idle()


func show_idle() -> void:
	_phase = "idle"
	_closed = false
	set_process(true)
	queue_redraw()


func show_loading() -> void:
	show_idle()
	_phase = "loading"


func play_round(presentation: Dictionary, bet: int, _win_amount: float, credits: float) -> void:
	_closed = false
	_flushed = false
	_bet = bet
	_credits = maxf(credits, 0.0)
	_score = 0
	_shown_reward = 0.0
	_duration = float(presentation.get("duration", 12))
	_left = _duration
	_coins.clear()
	_hazards.clear()
	_fx.clear()
	_pops.clear()
	_queue.clear()
	var raw_coins: Variant = presentation.get("coins", [])
	if raw_coins is Array:
		for entry in raw_coins:
			if entry is Dictionary:
				var coin: Dictionary = entry
				var copy: Dictionary = coin.duplicate(true)
				copy["kind"] = "coin"
				_queue.append(copy)
	var raw_hazards: Variant = presentation.get("obstacles", [])
	if raw_hazards is Array:
		for entry in raw_hazards:
			if entry is Dictionary:
				var hazard: Dictionary = entry
				var copy: Dictionary = hazard.duplicate(true)
				copy["kind"] = "cloud"
				copy["points"] = 0
				_queue.append(copy)
	_count_n = 3
	_count_t = 0.4
	_phase = "countdown"
	_plane_y = 0.48
	_target_y = 0.48
	set_process(true)
	queue_redraw()
	await finished


func _exit_tree() -> void:
	_complete()


func _process(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.034)
	_time += delta
	_drift_clouds(delta)
	_plane_y = lerpf(_plane_y, _target_y, clampf(delta * 8.0, 0.0, 1.0))
	match _phase:
		"countdown":
			_count_t -= delta
			if _count_t <= 0.0:
				_count_n -= 1
				_count_t = 0.4
				if _count_n <= 0:
					_phase = "play"
		"play":
			_left = maxf(_left - delta, 0.0)
			_release(delta)
			_slide(delta)
			if _left <= 0.0 or _pending_points() <= 0:
				_begin_finale()
		"finale":
			_slide(delta)
			_finale -= delta
			if _finale <= 0.0:
				if not _flushed and _pending_points() > 0:
					_flushed = true
					_collect_remaining()
					_finale = 0.45
				else:
					_complete()
					return
	_step_fx(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var aimed := false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask != 0:
			point = motion.position
			aimed = true
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			point = mouse.position
			aimed = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			point = touch.position
			aimed = true
	elif event is InputEventScreenDrag:
		point = (event as InputEventScreenDrag).position
		aimed = true
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_UP or key.keycode == KEY_W:
			_target_y = clampf(_target_y - 0.16, 0.22, 0.78)
		elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
			_target_y = clampf(_target_y + 0.16, 0.22, 0.78)
		accept_event()
		return
	if aimed:
		_target_y = clampf(point.y / maxf(size.y, 1.0), 0.22, 0.78)
		accept_event()


func _seed_clouds() -> void:
	_clouds.clear()
	for index in 8:
		_clouds.append({
			"x": randf(),
			"y": 0.12 + float(index % 4) * 0.18,
			"s": 18.0 + float(index % 3) * 10.0,
			"v": 12.0 + float(index),
		})


func _drift_clouds(delta: float) -> void:
	for cloud in _clouds:
		cloud["x"] = float(cloud["x"]) - delta * float(cloud["v"]) / maxf(size.x, 1.0)
		if float(cloud["x"]) < -0.1:
			cloud["x"] = 1.08


func _release(delta: float) -> void:
	var elapsed := _duration - _left
	var keep: Array[Dictionary] = []
	for entry in _queue:
		if float(entry.get("delay", 0.0)) <= elapsed:
			_spawn(entry)
		else:
			keep.append(entry)
	_queue = keep
	if delta < 0.0:
		return


func _spawn(entry: Dictionary) -> void:
	var lane := clampi(int(entry.get("lane", 1)), 0, 2)
	var kind := str(entry.get("kind", "coin"))
	var speed := 150.0
	if kind != "coin":
		speed = 120.0
	_coins.append({
		"kind": kind,
		"pos": Vector2(size.x + 30.0, _lane_y(lane)),
		"points": int(entry.get("points", 0)),
		"alive": true,
		"speed": speed,
	})


func _lane_y(lane: int) -> float:
	var top := 110.0
	var bottom := maxf(size.y - 70.0, top + 40.0)
	return top + (float(lane) + 0.5) / 3.0 * (bottom - top)


func _slide(delta: float) -> void:
	var plane := _plane_pos()
	for item in _coins:
		if not bool(item["alive"]):
			continue
		var pos: Vector2 = item["pos"]
		pos.x -= float(item["speed"]) * delta
		item["pos"] = pos
		if pos.x < -40.0:
			item["alive"] = false
			if str(item["kind"]) == "cloud":
				_popup(pos, "Clear", Color("D7F6FF"))
			elif int(item["points"]) > 0 and _phase == "play":
				_popup(pos, "Missed", Color("FFB4BE"))
			continue
		if pos.distance_to(plane) <= 28.0:
			_take(item, pos)


func _take(item: Dictionary, at: Vector2) -> void:
	if not bool(item["alive"]):
		return
	item["alive"] = false
	if str(item["kind"]) == "cloud":
		_popup(at, "Bump", Color("FFE38A"))
		_burst(at, Color("E7EEF8"), 5)
		return
	var points := int(item["points"])
	if points <= 0:
		_popup(at, "Empty", Color("D7F6FF"))
		return
	_score += points
	var share := float(points * _bet)
	_shown_reward += share
	_popup(at, "+%s" % _amount(share), Color("FFE38A"))
	_burst(at, Color("F5C542"), 6)


func _pending_points() -> int:
	var total := 0
	for item in _coins:
		if bool(item["alive"]) and str(item["kind"]) == "coin":
			total += int(item["points"])
	for entry in _queue:
		if str(entry.get("kind", "")) == "coin":
			total += int(entry.get("points", 0))
	return total


func _collect_remaining() -> void:
	for entry in _queue:
		if str(entry.get("kind", "")) == "coin" and int(entry.get("points", 0)) > 0:
			_spawn(entry)
			var last: Dictionary = _coins[_coins.size() - 1]
			_take(last, _plane_pos())
	_queue.clear()
	for item in _coins:
		if bool(item["alive"]) and str(item["kind"]) == "coin" and int(item["points"]) > 0:
			_take(item, item["pos"])


func _begin_finale() -> void:
	if _phase == "finale":
		return
	_phase = "finale"
	for entry in _queue:
		_spawn(entry)
	_queue.clear()
	if _pending_points() <= 0:
		_finale = 0.4
	else:
		_finale = 0.9


func _complete() -> void:
	if _closed:
		return
	_closed = true
	_phase = "done"
	set_process(false)
	queue_redraw()
	finished.emit()


func _burst(at: Vector2, color: Color, count: int) -> void:
	for index in mini(count, 16 - _fx.size()):
		var angle := randf() * TAU
		_fx.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(20.0, 70.0),
			"life": 0.3,
			"color": color,
		})


func _popup(at: Vector2, text: String, color: Color) -> void:
	if _pops.size() > 5:
		_pops.pop_front()
	_pops.append({"pos": at, "text": text, "life": 0.65, "color": color})


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
		pop["pos"] = pop["pos"] + Vector2(0, -24.0 * delta)
		if float(pop["life"]) <= 0.0:
			_pops.remove_at(index)


func _plane_pos() -> Vector2:
	return Vector2(78.0, _plane_y * size.y)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 16.0 or rect.size.y < 16.0:
		return
	draw_rect(rect, Color("163A66"), true)
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("1E6A4A"), true)
	for cloud in _clouds:
		var at := Vector2(float(cloud["x"]) * size.x, float(cloud["y"]) * size.y)
		draw_circle(at, float(cloud["s"]), Color(1, 1, 1, 0.16))
	for item in _coins:
		if not bool(item["alive"]):
			continue
		var pos: Vector2 = item["pos"]
		if str(item["kind"]) == "cloud":
			draw_circle(pos, 18.0, Color("F4F7FB"))
			draw_circle(pos + Vector2(12, 2), 12.0, Color("E7EEF8"))
		else:
			var ink := Color("F5C542")
			if int(item["points"]) <= 0:
				ink = Color("9AA6BD")
			draw_circle(pos, 12.0, ink)
			draw_circle(pos, 7.0, Color("FFE38A"))
	for bit in _fx:
		var alpha := clampf(float(bit["life"]) / 0.3, 0.0, 1.0)
		var color: Color = bit["color"]
		color.a = alpha
		draw_circle(bit["pos"], 3.0, color)
	_draw_plane()
	_draw_hud()
	for pop in _pops:
		_draw_popup(pop)
	if _phase == "countdown":
		_draw_center(str(maxi(_count_n, 1)), "Drag to climb")
	elif _phase == "loading":
		_draw_center("Boarding", "Get ready")
	elif _phase == "idle":
		_draw_center("", "Drag or use the arrow keys")
	elif _phase == "play" and _left <= 3.0:
		_draw_center(str(int(ceil(_left))), "Final seconds")


func _draw_plane() -> void:
	var origin := _plane_pos()
	var body := PackedVector2Array([
		origin + Vector2(28, 0),
		origin + Vector2(-16, -8),
		origin + Vector2(-8, 0),
		origin + Vector2(-16, 8),
	])
	draw_colored_polygon(body, Color("F4F7FB"))
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(-2, -2),
		origin + Vector2(8, -16),
		origin + Vector2(-10, -2),
	]), Color("7EB6FF"))
	draw_circle(origin + Vector2(6, -2), 3.0, Color("163A66"))


func _draw_hud() -> void:
	if _font == null:
		return
	draw_rect(Rect2(0, 0, size.x, 58), Color(0.04, 0.08, 0.16, 0.78), true)
	var col := size.x / 4.0
	var time_label := "--"
	if _phase == "play" or _phase == "finale":
		time_label = "%ds" % int(ceil(_left))
	_column_text(0.0, col, "CREDITS", _amount(_credits), Color("E7C56A"))
	_column_text(col, col, "ENTRY", _amount(_bet), Color("F4F7FB"))
	_column_text(col * 2.0, col, "TIME", time_label, Color("FFE38A"))
	_column_text(col * 3.0, col, "SCORE", str(_score), Color("3DDC97"))


func _draw_center(primary: String, caption: String) -> void:
	if _font == null:
		return
	if primary != "":
		var text_size := _font.get_string_size(primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(_font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.46), primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color("FFF8E6"))
	var caption_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(_font, Vector2((size.x - caption_size.x) * 0.5, size.y * 0.56), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("D7F6FF"))


func _draw_popup(pop: Dictionary) -> void:
	if _font == null:
		return
	var color: Color = pop["color"]
	color.a = clampf(float(pop["life"]) / 0.65, 0.0, 1.0)
	draw_string(_font, pop["pos"], str(pop["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


func _column_text(x: float, width: float, caption: String, value: String, value_color: Color) -> void:
	draw_string(_font, Vector2(x + 8.0, 18), caption, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, 11, Color("9AA6BD"))
	draw_string(_font, Vector2(x + 8.0, 42), value, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, 18, value_color)


func _amount(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.2f" % value
