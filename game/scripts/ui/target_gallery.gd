class_name TargetGallery
extends Control

## Arcade target gallery. Credit prizes come from the server round.
## Target points are the shares of that prize, not a second payout.

signal finished

var _phase := "idle"
var _closed := false
var _time := 0.0
var _left := 12.0
var _duration := 12.0
var _scores_cleared := false
var _had_scores := false
var _aim := -PI * 0.5
var _cooldown := 0.0
var _recoil := 0.0
var _holding := false
var _targets: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _script: Array = []
var _bet := 0
var _win := 0.0
var _credits := 0.0
var _score := 0
var _combo := 0
var _best_combo := 0
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
	_shoot.pressed.connect(_fire)
	_shoot.button_down.connect(func() -> void: _holding = true)
	_shoot.button_up.connect(func() -> void: _holding = false)
	add_child(_shoot)
	resized.connect(_place_controls)
	show_idle()


func show_idle() -> void:
	_phase = "idle"
	_holding = false
	_closed = false
	_targets.clear()
	_shots.clear()
	_spawn_decoys()
	set_process(true)
	_place_controls()
	queue_redraw()


func show_loading() -> void:
	show_idle()
	_phase = "loading"


func play_round(presentation: Dictionary, bet: int, win_amount: float, credits: float) -> void:
	_closed = false
	_bet = bet
	_win = maxf(win_amount, 0.0)
	_credits = maxf(credits, 0.0)
	_score = 0
	_combo = 0
	_best_combo = 0
	_shown_reward = 0.0
	_scores_cleared = false
	_had_scores = false
	_flushed = false
	_duration = float(presentation.get("duration", 12))
	_left = _duration
	_script = []
	var raw_targets: Variant = presentation.get("targets", [])
	if raw_targets is Array:
		var rows: Array = raw_targets
		_script.assign(rows)
	_queue.clear()
	for index in _script.size():
		if _script[index] is Dictionary:
			var entry: Dictionary = _script[index]
			if int(entry.get("points", 0)) > 0:
				_had_scores = true
			var copy: Dictionary = entry.duplicate(true)
			_queue.append(copy)
	_targets.clear()
	_shots.clear()
	_fx.clear()
	_pops.clear()
	_spawn_decoys()
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
		"idle", "loading":
			_move_targets(delta)
		"countdown":
			_move_targets(delta)
			_count_t -= delta
			if _count_t <= 0.0:
				_count_n -= 1
				_count_t = 0.4
				if _count_n <= 0:
					_phase = "play"
					_place_controls()
		"play":
			_left = maxf(_left - delta, 0.0)
			_release_script()
			if _holding and _cooldown <= 0.0:
				_fire()
			_move_targets(delta)
			_move_shots(delta)
			if _left <= 0.0 or _scores_cleared:
				_begin_finale()
		"finale":
			_move_targets(delta)
			_move_shots(delta)
			_lock_remaining()
			_finale -= delta
			if _finale <= 0.0:
				if not _flushed and _pending_points() > 0:
					_flushed = true
					_flush_scores()
					_finale = 0.4
					return
				_complete()
				return
	_step_fx(delta)
	queue_redraw()


func _pending_points() -> int:
	var total := 0
	for target in _targets:
		if bool(target["alive"]):
			total += int(target["points"])
	for entry in _queue:
		total += int(entry.get("points", 0))
	return total


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
		var motion := event as InputEventMouseMotion
		point = motion.position
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
		_try_direct_hit(point)
		_fire()
	accept_event()


func _spawn_decoys() -> void:
	for index in 3:
		var decoy_size := "medium"
		if index != 1:
			decoy_size = "small"
		_targets.append(_make_target(decoy_size, 0, false, 0.2 + float(index) * 0.3))


func _release_script() -> void:
	var elapsed := _duration - _left
	var keep: Array[Dictionary] = []
	for entry in _queue:
		if float(entry.get("delay", 0.0)) <= elapsed:
			var size_name := str(entry.get("size", "medium"))
			_targets.append(_make_target(size_name, int(entry.get("points", 0)), bool(entry.get("bonus", false)), randf()))
		else:
			keep.append(entry)
	_queue = keep


func _make_target(size_name: String, points: int, bonus: bool, seed: float) -> Dictionary:
	var radius := 22.0
	var color := Color("7EB6FF")
	match size_name:
		"small":
			radius = 16.0
			color = Color("F4F7FB")
		"large":
			radius = 34.0
			color = Color("E23B45")
		"bonus":
			radius = 26.0
			color = Color("F5C542")
		_:
			radius = 24.0
			color = Color("7EB6FF")
	if bonus:
		radius = 28.0
		color = Color("F5C542")
	var y := randf_range(96.0, maxf(size.y - 160.0, 120.0))
	var from_left := seed < 0.5
	var start_x := size.x + radius
	if from_left:
		start_x = -radius - 10.0
	var direction := -1.0
	if from_left:
		direction = 1.0
	var pace := 1.0
	if size_name == "small":
		pace = 1.25
	elif size_name == "large":
		pace = 0.8
	var life := 5.5
	if points > 0:
		life = 4.2
	return {
		"pos": Vector2(start_x, y),
		"dir": direction,
		"speed": randf_range(70.0, 130.0) * pace,
		"radius": radius,
		"points": points,
		"bonus": bonus,
		"color": color,
		"alive": true,
		"life": life,
		"flash": 0.0,
		"bob": seed * TAU,
	}


func _aim_at(point: Vector2) -> void:
	var delta := point - _blaster_pos()
	if delta.length() < 8.0:
		return
	_aim = clampf(delta.angle(), -PI + 0.28, -0.28)


func _fire() -> void:
	if (_phase != "play" and _phase != "finale") or _cooldown > 0.0 or _shots.size() >= 8:
		return
	_cooldown = 0.2
	_recoil = 1.0
	var origin := _blaster_pos() + Vector2(cos(_aim), sin(_aim)) * 26.0
	_shots.append({
		"pos": origin,
		"vel": Vector2(cos(_aim), sin(_aim)) * 520.0,
		"life": 1.7,
	})
	_burst(origin, Color("FFE38A"), 3)


func _try_direct_hit(point: Vector2) -> void:
	for target in _targets:
		if not bool(target["alive"]):
			continue
		var pos: Vector2 = target["pos"]
		if pos.distance_to(point) <= float(target["radius"]) + 6.0:
			_strike(target, pos)
			return


func _move_targets(delta: float) -> void:
	var width := maxf(size.x, 80.0)
	for target in _targets:
		if not bool(target["alive"]):
			continue
		var pos: Vector2 = target["pos"]
		pos.x += float(target["dir"]) * float(target["speed"]) * delta
		pos.y += sin(_time * 2.0 + float(target["bob"])) * 18.0 * delta
		pos.y = clampf(pos.y, 88.0, maxf(size.y - 150.0, 100.0))
		var radius := float(target["radius"])
		if pos.x > width + radius:
			target["dir"] = -1.0
		elif pos.x < -radius:
			target["dir"] = 1.0
		target["pos"] = pos
		target["flash"] = maxf(float(target["flash"]) - delta * 4.0, 0.0)
		if _phase == "play":
			target["life"] = float(target["life"]) - delta
			if float(target["life"]) <= 0.0:
				target["alive"] = false
				if int(target["points"]) > 0:
					_combo = 0
					_popup(pos, "Miss", Color("FF8A9A"))


func _move_shots(delta: float) -> void:
	var expired: Array[int] = []
	for index in _shots.size():
		var shot: Dictionary = _shots[index]
		shot["pos"] = shot["pos"] + shot["vel"] * delta
		shot["life"] = float(shot["life"]) - delta
		var pos: Vector2 = shot["pos"]
		if float(shot["life"]) <= 0.0 or pos.y < 70.0 or pos.x < -10.0 or pos.x > size.x + 10.0:
			expired.append(index)
			if _phase == "play":
				_combo = 0
			continue
		if _strike_at(pos):
			expired.append(index)
	for index in range(expired.size() - 1, -1, -1):
		_shots.remove_at(expired[index])


func _strike_at(pos: Vector2) -> bool:
	var best := -1
	var best_d := 9999.0
	for index in _targets.size():
		var target: Dictionary = _targets[index]
		if not bool(target["alive"]):
			continue
		var target_pos: Vector2 = target["pos"]
		var distance := target_pos.distance_to(pos)
		if distance <= float(target["radius"]) + 6.0 and distance < best_d:
			best = index
			best_d = distance
	if best < 0:
		return false
	_strike(_targets[best], pos)
	return true


func _strike(target: Dictionary, at: Vector2) -> void:
	if not bool(target["alive"]):
		return
	target["alive"] = false
	target["flash"] = 1.0
	var ink: Color = target["color"]
	_burst(at, ink, 8)
	var points := int(target["points"])
	if points <= 0:
		_combo = 0
		_popup(at, "Miss", Color("FFB4BE"))
		return
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_score += points
	var share := float(points * _bet)
	_shown_reward += share
	var popup_color := Color("D9FFE8")
	if bool(target["bonus"]):
		popup_color = Color("FFE38A")
	_popup(at, "+%s" % _amount(share), popup_color)
	if _had_scores and _pending_points() <= 0:
		_scores_cleared = true


func _lock_remaining() -> void:
	if _cooldown > 0.0:
		return
	for target in _targets:
		if bool(target["alive"]) and int(target["points"]) > 0:
			var pos: Vector2 = target["pos"]
			_aim = (pos - _blaster_pos()).angle()
			_cooldown = 0.0
			_fire()
			return


func _flush_scores() -> void:
	for target in _targets:
		if bool(target["alive"]) and int(target["points"]) > 0:
			var pos: Vector2 = target["pos"]
			_strike(target, pos)


func _begin_finale() -> void:
	if _phase == "finale":
		return
	_phase = "finale"
	_holding = false
	for entry in _queue:
		_targets.append(_make_target(str(entry.get("size", "medium")), int(entry.get("points", 0)), bool(entry.get("bonus", false)), randf()))
	_queue.clear()
	if _pending_points() <= 0:
		_finale = 0.45
	else:
		_finale = 0.7 + float(_pending_points()) * 0.28
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
	for index in mini(count, 20 - _fx.size()):
		var angle := randf() * TAU
		_fx.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(40.0, 110.0),
			"life": 0.32,
			"color": color,
		})


func _popup(at: Vector2, text: String, color: Color) -> void:
	if _pops.size() > 6:
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
		pop["pos"] = pop["pos"] + Vector2(0, -26.0 * delta)
		if float(pop["life"]) <= 0.0:
			_pops.remove_at(index)


func _blaster_pos() -> Vector2:
	return Vector2(size.x * 0.42, size.y - 72.0) + Vector2(cos(_aim), sin(_aim)) * -_recoil * 6.0


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
	draw_rect(rect, Color("1A1020"), true)
	draw_rect(Rect2(0, 64, size.x, size.y - 64), Color("2A1430"), true)
	draw_rect(Rect2(10, 74, size.x - 20, size.y - 160), Color("120C18"), true)
	for lamp in 4:
		var x := 28.0 + float(lamp) * (size.x - 40.0) / 3.0
		draw_circle(Vector2(x, 78), 8.0, Color("FFE38A"))
		draw_circle(Vector2(x, 78), 22.0, Color(1, 0.85, 0.4, 0.08))
	for target in _targets:
		if bool(target["alive"]) or float(target["flash"]) > 0.0:
			_draw_target(target)
	for shot in _shots:
		var pos: Vector2 = shot["pos"]
		draw_circle(pos, 6.0, Color("FFF4C8"))
		draw_circle(pos, 3.0, Color("FF8A3A"))
	for bit in _fx:
		var alpha := clampf(float(bit["life"]) / 0.32, 0.0, 1.0)
		var color: Color = bit["color"]
		color.a = alpha
		draw_circle(bit["pos"], 2.5 + alpha * 3.0, color)
	_draw_blaster()
	_draw_hud()
	for pop in _pops:
		_draw_pop(pop)
	if _phase == "countdown":
		_center(str(maxi(_count_n, 1)), "Hit the targets")
	elif _phase == "loading":
		_center("Ready", "Arming the gallery")
	elif _phase == "idle":
		_center("", "Aim and blast the targets")


func _draw_target(target: Dictionary) -> void:
	var pos: Vector2 = target["pos"]
	var radius := float(target["radius"])
	var color: Color = target["color"]
	if float(target["flash"]) > 0.0:
		draw_circle(pos, radius + 10.0, Color(1, 1, 1, 0.35))
	draw_circle(pos, radius, color)
	draw_circle(pos, radius * 0.68, Color("F4F7FB"))
	draw_circle(pos, radius * 0.4, color.darkened(0.1))
	draw_circle(pos, radius * 0.16, Color("1A1020"))
	if bool(target["bonus"]):
		draw_arc(pos, radius + 4.0, 0, TAU, 24, Color("FFE38A"), 2.0, true)


func _draw_blaster() -> void:
	var origin := _blaster_pos()
	var tip := origin + Vector2(cos(_aim), sin(_aim)) * 34.0
	draw_line(origin, tip, Color("F5C542"), 7.0)
	draw_circle(origin, 14.0, Color("2A1A38"))
	draw_circle(origin, 6.0, Color("FFE38A"))
	var aim_end := origin + Vector2(cos(_aim), sin(_aim)) * 70.0
	draw_line(tip, aim_end, Color(1, 0.9, 0.6, 0.35), 2.0)


func _draw_hud() -> void:
	if _font == null:
		return
	draw_rect(Rect2(0, 0, size.x, 64), Color(0.08, 0.04, 0.1, 0.88), true)
	var col := size.x / 4.0
	var value_size := 18
	if size.x < 430.0:
		value_size = 16
	var timer_color := Color("FFF8E6")
	if _left <= 3.0 and _phase == "play":
		timer_color = Color("FF8A9A")
	var time_label := "--"
	if _phase == "play" or _phase == "finale":
		time_label = "%ds" % int(ceil(_left))
	_column_text(0.0, col, "CREDITS", _amount(_credits), Color("E7C56A"), Color("FFF8E6"), value_size)
	_column_text(col, col, "ENTRY", _amount(_bet), Color("9AA6BD"), Color("F4F7FB"), value_size)
	_column_text(col * 2.0, col, "TIME", time_label, Color("9AA6BD"), timer_color, value_size)
	var combo_label := "COMBO"
	if _combo > 0:
		combo_label = "x%d" % _combo
	_column_text(col * 3.0, col, combo_label, "+%s" % _amount(_shown_reward), Color("9AA6BD"), Color("F5C542"), value_size)


func _center(primary: String, caption: String) -> void:
	if _font == null:
		return
	if primary != "":
		var text_size := _font.get_string_size(primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 60)
		draw_string(_font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.46), primary, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("FFF8E6"))
	var caption_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(_font, Vector2((size.x - caption_size.x) * 0.5, size.y * 0.56), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("F4F7FB"))


func _draw_pop(pop: Dictionary) -> void:
	if _font == null:
		return
	var color: Color = pop["color"]
	color.a = clampf(float(pop["life"]) / 0.65, 0.0, 1.0)
	draw_string(_font, pop["pos"], str(pop["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)


func _column_text(x: float, width: float, caption: String, value: String, caption_color: Color, value_color: Color, value_size: int) -> void:
	draw_string(_font, Vector2(x + 8.0, 20), caption, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, 11, caption_color)
	draw_string(_font, Vector2(x + 8.0, 46), value, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, value_size, value_color)


func _amount(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.2f" % value
