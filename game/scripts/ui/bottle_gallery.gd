class_name BottleGallery
extends Control

## Arcade bottle launcher. Bottle points are shares of the server prize.

signal finished

var _phase := "idle"
var _closed := false
var _time := 0.0
var _left := 12.0
var _duration := 12.0
var _aim := -PI * 0.5
var _cooldown := 0.0
var _recoil := 0.0
var _holding := false
var _bottles: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _bet := 0
var _credits := 0.0
var _score := 0
var _combo := 0
var _shown_reward := 0.0
var _count_n := 3
var _count_t := 0.0
var _finale := 0.0
var _flushed := false
var _font: Font
var _shoot: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_shoot = Button.new()
	_shoot.text = "Blast"
	_shoot.theme_type_variation = "PrimaryButton"
	_shoot.custom_minimum_size = Vector2(108, 52)
	_shoot.focus_mode = Control.FOCUS_NONE
	_shoot.pressed.connect(_pressed_shoot)
	add_child(_shoot)
	resized.connect(_place_controls)
	show_idle()


func show_idle() -> void:
	_phase = "idle"
	_holding = false
	_closed = false
	set_process(true)
	_place_controls()
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
	_combo = 0
	_shown_reward = 0.0
	_duration = float(presentation.get("duration", 12))
	_left = _duration
	_bottles.clear()
	_shots.clear()
	_fx.clear()
	_pops.clear()
	_queue.clear()
	var raw: Variant = presentation.get("bottles", [])
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				var bottle: Dictionary = entry
				_queue.append(bottle.duplicate(true))
	_count_n = 3
	_count_t = 0.4
	_phase = "countdown"
	set_process(true)
	_place_controls()
	await finished


func _exit_tree() -> void:
	_complete()


func _process(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.034)
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_recoil = maxf(_recoil - delta * 6.0, 0.0)
	match _phase:
		"countdown":
			_count_t -= delta
			if _count_t <= 0.0:
				_count_n -= 1
				_count_t = 0.4
				if _count_n <= 0:
					_phase = "play"
					_place_controls()
		"play":
			_left = maxf(_left - delta, 0.0)
			if _holding and _cooldown <= 0.0:
				_fire()
			_release()
			_move(delta)
			if _left <= 0.0 or (_queue.is_empty() and _pending_points() <= 0 and not _bottles.is_empty()):
				_begin_finale()
		"finale":
			_move(delta)
			_lock_remaining()
			_finale -= delta
			if _finale <= 0.0:
				if not _flushed and _pending_points() > 0:
					_flushed = true
					_flush()
					_finale = 0.4
				else:
					_complete()
					return
	_step_fx(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var aimed := false
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		point = mouse.position
		pressed = mouse.pressed
		aimed = true
	elif event is InputEventMouseMotion:
		point = (event as InputEventMouseMotion).position
		aimed = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		point = touch.position
		pressed = touch.pressed
		aimed = true
	elif event is InputEventScreenDrag:
		point = (event as InputEventScreenDrag).position
		aimed = true
	else:
		return
	if _shoot and _shoot.get_global_rect().has_point(get_global_transform() * point):
		return
	if aimed:
		_aim_at(point)
	if pressed and _phase == "play":
		_pressed_shoot()
	accept_event()


func _pressed_shoot() -> void:
	if _phase != "play":
		return
	_fire()


func _release() -> void:
	var elapsed := _duration - _left
	var keep: Array[Dictionary] = []
	for entry in _queue:
		if float(entry.get("delay", 0.0)) <= elapsed:
			_bottles.append(_make(entry))
		else:
			keep.append(entry)
	_queue = keep


func _make(entry: Dictionary) -> Dictionary:
	var kind := str(entry.get("type", "normal"))
	var radius := 16.0
	var speed := 90.0
	var color := Color("7EE7FF")
	if kind == "fast":
		radius = 13.0
		speed = 150.0
		color = Color("3DDC97")
	elif kind == "golden":
		radius = 20.0
		speed = 70.0
		color = Color("F5C542")
	elif kind == "bonus":
		radius = 22.0
		speed = 80.0
		color = Color("C9A6FF")
	var from_left := randf() < 0.5
	var start_x := size.x + radius
	var direction := -1.0
	if from_left:
		start_x = -radius
		direction = 1.0
	return {
		"pos": Vector2(start_x, randf_range(100.0, maxf(size.y - 170.0, 140.0))),
		"dir": direction,
		"speed": speed,
		"radius": radius,
		"points": int(entry.get("points", 0)),
		"kind": kind,
		"color": color,
		"alive": true,
		"spin": randf() * TAU,
	}


func _aim_at(point: Vector2) -> void:
	var delta := point - _launcher_pos()
	if delta.length() < 8.0:
		return
	_aim = clampf(delta.angle(), -PI + 0.3, -0.3)


func _fire() -> void:
	if (_phase != "play" and _phase != "finale") or _cooldown > 0.0 or _shots.size() >= 8:
		return
	_cooldown = 0.22
	_recoil = 1.0
	var origin := _launcher_pos() + Vector2(cos(_aim), sin(_aim)) * 26.0
	_shots.append({
		"pos": origin,
		"vel": Vector2(cos(_aim), sin(_aim)) * 520.0,
		"life": 1.7,
	})
	_burst(origin, Color("D7F6FF"), 3)


func _move(delta: float) -> void:
	var width := maxf(size.x, 80.0)
	for bottle in _bottles:
		if not bool(bottle["alive"]):
			continue
		var pos: Vector2 = bottle["pos"]
		pos.x += float(bottle["dir"]) * float(bottle["speed"]) * delta
		pos.y += sin(_time * 2.0 + float(bottle["spin"])) * 12.0 * delta
		pos.y = clampf(pos.y, 96.0, maxf(size.y - 150.0, 120.0))
		var radius := float(bottle["radius"])
		if pos.x > width + radius:
			bottle["dir"] = -1.0
		elif pos.x < -radius:
			bottle["dir"] = 1.0
		bottle["pos"] = pos
		bottle["spin"] = float(bottle["spin"]) + delta * 2.0
	var expired: Array[int] = []
	for index in _shots.size():
		var shot: Dictionary = _shots[index]
		shot["pos"] = shot["pos"] + shot["vel"] * delta
		shot["life"] = float(shot["life"]) - delta
		var pos: Vector2 = shot["pos"]
		if float(shot["life"]) <= 0.0 or pos.y < 48.0 or pos.x < -20.0 or pos.x > size.x + 20.0:
			expired.append(index)
			continue
		if _hit(pos):
			expired.append(index)
	for index in range(expired.size() - 1, -1, -1):
		_shots.remove_at(expired[index])


func _hit(pos: Vector2) -> bool:
	var best := -1
	var best_d := 9999.0
	for index in _bottles.size():
		var bottle: Dictionary = _bottles[index]
		if not bool(bottle["alive"]):
			continue
		var bottle_pos: Vector2 = bottle["pos"]
		var distance := bottle_pos.distance_to(pos)
		if distance <= float(bottle["radius"]) + 8.0 and distance < best_d:
			best = index
			best_d = distance
	if best < 0:
		return false
	_break(_bottles[best], pos)
	return true


func _break(bottle: Dictionary, at: Vector2) -> void:
	if not bool(bottle["alive"]):
		return
	bottle["alive"] = false
	var ink: Color = bottle["color"]
	_burst(at, ink, 8)
	var points := int(bottle["points"])
	if points <= 0:
		_combo = 0
		_popup(at, "Empty", Color("D7F6FF"))
		return
	_combo += 1
	_score += points
	var share := float(points * _bet)
	_shown_reward += share
	var label := "+%s" % _amount(share)
	if _combo > 1:
		label = "x%d  %s" % [_combo, label]
	_popup(at, label, Color("FFE38A"))


func _pending_points() -> int:
	var total := 0
	for bottle in _bottles:
		if bool(bottle["alive"]):
			total += int(bottle["points"])
	for entry in _queue:
		total += int(entry.get("points", 0))
	return total


func _lock_remaining() -> void:
	if _cooldown > 0.0:
		return
	for bottle in _bottles:
		if bool(bottle["alive"]) and int(bottle["points"]) > 0:
			var pos: Vector2 = bottle["pos"]
			_aim = (pos - _launcher_pos()).angle()
			_cooldown = 0.0
			_fire()
			return


func _flush() -> void:
	for entry in _queue:
		if int(entry.get("points", 0)) > 0:
			var made := _make(entry)
			_bottles.append(made)
	_queue.clear()
	for bottle in _bottles:
		if bool(bottle["alive"]) and int(bottle["points"]) > 0:
			var pos: Vector2 = bottle["pos"]
			_break(bottle, pos)


func _begin_finale() -> void:
	if _phase == "finale":
		return
	_phase = "finale"
	_holding = false
	for entry in _queue:
		_bottles.append(_make(entry))
	_queue.clear()
	if _pending_points() <= 0:
		_finale = 0.45
	else:
		_finale = 1.1
	_place_controls()


func _complete() -> void:
	if _closed:
		return
	_closed = true
	_phase = "done"
	_holding = false
	set_process(false)
	_place_controls()
	queue_redraw()
	finished.emit()


func _burst(at: Vector2, color: Color, count: int) -> void:
	for index in mini(count, 18 - _fx.size()):
		var angle := randf() * TAU
		_fx.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(30.0, 90.0),
			"life": 0.32,
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


func _launcher_pos() -> Vector2:
	return Vector2(size.x * 0.5, size.y - 74.0) + Vector2(cos(_aim), sin(_aim)) * -_recoil * 6.0


func _place_controls() -> void:
	if _shoot == null:
		return
	_shoot.position = Vector2(maxf(size.x - 124.0, 8.0), maxf(size.y - 62.0, 8.0))
	_shoot.visible = _phase == "play"
	_shoot.disabled = _phase != "play"


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 16.0 or rect.size.y < 16.0:
		return
	draw_rect(rect, Color("1A1030"), true)
	draw_rect(Rect2(0, size.y - 48.0, size.x, 48.0), Color("2A1848"), true)
	for bottle in _bottles:
		if bool(bottle["alive"]):
			_draw_bottle(bottle)
	for shot in _shots:
		var pos: Vector2 = shot["pos"]
		draw_circle(pos, 6.0, Color("E9FBFF"))
	for bit in _fx:
		var alpha := clampf(float(bit["life"]) / 0.32, 0.0, 1.0)
		var color: Color = bit["color"]
		color.a = alpha
		draw_circle(bit["pos"], 3.0 + alpha * 2.0, color)
	_draw_launcher()
	_draw_hud()
	for pop in _pops:
		_draw_popup(pop)
	if _phase == "countdown":
		_draw_center(str(maxi(_count_n, 1)), "Aim and blast")
	elif _phase == "loading":
		_draw_center("Setting bottles", "Get ready")
	elif _phase == "idle":
		_draw_center("", "Drag to aim, tap to blast")
	elif _phase == "play" and _left <= 3.0:
		_draw_center(str(int(ceil(_left))), "Final seconds")


func _draw_bottle(bottle: Dictionary) -> void:
	var pos: Vector2 = bottle["pos"]
	var radius := float(bottle["radius"])
	var color: Color = bottle["color"]
	var spin := float(bottle["spin"])
	var neck := Vector2(sin(spin) * 4.0, -radius * 0.9)
	draw_rect(Rect2(pos + neck + Vector2(-4, -10), Vector2(8, 12)), color.lightened(0.2), true)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-radius * 0.45, -radius * 0.2),
		pos + Vector2(radius * 0.45, -radius * 0.2),
		pos + Vector2(radius * 0.62, radius * 0.8),
		pos + Vector2(-radius * 0.62, radius * 0.8),
	]), color)
	draw_circle(pos + Vector2(-radius * 0.15, -radius * 0.05), 3.0, Color(1, 1, 1, 0.45))


func _draw_launcher() -> void:
	var origin := _launcher_pos()
	var tip := origin + Vector2(cos(_aim), sin(_aim)) * 34.0
	draw_line(origin, tip, Color("F5C542"), 7.0)
	draw_circle(origin, 14.0, Color("2A1848"))
	draw_circle(origin, 6.0, Color("FFE38A"))
	var aim_end := origin + Vector2(cos(_aim), sin(_aim)) * 70.0
	draw_line(tip, aim_end, Color(1, 0.9, 0.6, 0.35), 2.0)
	if _recoil > 0.35:
		draw_circle(tip, 8.0, Color(1, 0.95, 0.7, 0.55))


func _draw_hud() -> void:
	if _font == null:
		return
	draw_rect(Rect2(0, 0, size.x, 58), Color(0.08, 0.04, 0.12, 0.82), true)
	var col := size.x / 4.0
	var time_label := "--"
	if _phase == "play" or _phase == "finale":
		time_label = "%ds" % int(ceil(_left))
	var combo_label := "SCORE"
	if _combo > 1:
		combo_label = "x%d" % _combo
	_column_text(0.0, col, "CREDITS", _amount(_credits), Color("E7C56A"))
	_column_text(col, col, "ENTRY", _amount(_bet), Color("F4F7FB"))
	_column_text(col * 2.0, col, "TIME", time_label, Color("FFE38A"))
	_column_text(col * 3.0, col, combo_label, str(_score), Color("3DDC97"))


func _draw_center(primary: String, caption: String) -> void:
	if _font == null:
		return
	if primary != "":
		var text_size := _font.get_string_size(primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(_font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.46), primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color("FFF8E6"))
	var caption_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(_font, Vector2((size.x - caption_size.x) * 0.5, size.y * 0.56), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("E7D8FF"))


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
