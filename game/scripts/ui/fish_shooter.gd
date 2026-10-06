class_name FishShooter
extends Control

## Arcade fish shooter. The server still decides the round prize.
## Hits reveal that prize; misses never invent a payout.

signal finished

const _KINDS := {
	"small": {"speed": 74.0, "hp": 1, "radius": 16.0, "color": Color("5EB0E8")},
	"fast": {"speed": 148.0, "hp": 1, "radius": 13.0, "color": Color("3DDC97")},
	"golden": {"speed": 62.0, "hp": 2, "radius": 21.0, "color": Color("F5C542")},
	"rare": {"speed": 98.0, "hp": 1, "radius": 18.0, "color": Color("C9A6FF")},
	"large": {"speed": 44.0, "hp": 3, "radius": 28.0, "color": Color("E08A5A")},
}

var _phase := "idle"
var _closed := false
var _time := 0.0
var _left := 14.0
var _round := 14.0
var _aim := -PI * 0.5
var _cooldown := 0.0
var _recoil := 0.0
var _holding := false
var _pointer := Vector2.ZERO
var _fish: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _prize_kind := ""
var _prize_name := ""
var _win := 0.0
var _bet := 0
var _credits := 0.0
var _score := 0
var _shown_reward := 0.0
var _prize_hit := false
var _rescued := false
var _count_n := 3
var _count_t := 0.0
var _finale := 0.0
var _spawn := 0.0
var _font: Font
var _shoot: Button
var _next_id := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = ThemeDB.fallback_font
	_shoot = Button.new()
	_shoot.text = "Shoot"
	_shoot.theme_type_variation = "PrimaryButton"
	_shoot.custom_minimum_size = Vector2(108, 52)
	_shoot.focus_mode = Control.FOCUS_NONE
	_shoot.pressed.connect(_shoot_pressed)
	_shoot.button_down.connect(func() -> void: _holding = true)
	_shoot.button_up.connect(func() -> void: _holding = false)
	add_child(_shoot)
	resized.connect(_place_controls)
	_seed_bubbles()
	show_idle()


func show_idle() -> void:
	_phase = "idle"
	_holding = false
	_closed = false
	_clear_combat()
	_fill_school(false)
	set_process(true)
	_place_controls()
	queue_redraw()


func show_loading() -> void:
	_phase = "loading"
	_holding = false
	_closed = false
	if _fish.is_empty():
		_fill_school(false)
	set_process(true)
	_place_controls()
	queue_redraw()


func play_round(presentation: Dictionary, bet: int, win_amount: float, credits: float) -> void:
	_closed = false
	_bet = bet
	_win = maxf(win_amount, 0.0)
	_credits = maxf(credits, 0.0)
	_score = 0
	_shown_reward = 0.0
	_prize_hit = false
	_rescued = false
	_left = float(presentation.get("duration", 14))
	_round = _left
	_prize_name = str(presentation.get("name", "Fish"))
	_prize_kind = _kind_for(str(presentation.get("fish", "none")))
	_clear_combat()
	_fill_school(true)
	_count_n = 3
	_count_t = 0.42
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
	_drift_bubbles(delta)
	match _phase:
		"idle", "loading":
			_swim(delta)
		"countdown":
			_swim(delta)
			_count_t -= delta
			if _count_t <= 0.0:
				_count_n -= 1
				_count_t = 0.42
				if _count_n <= 0:
					_phase = "play"
					_place_controls()
		"play":
			if _holding and _cooldown <= 0.0:
				_fire()
			_simulate(delta)
			if _left <= 0.0:
				_begin_finale()
		"finale":
			_simulate(delta)
			_finale -= delta
			if not _prize_hit and _prize_kind != "" and _win > 0.0:
				_guide_prize()
			if _finale <= 0.0:
				if not _prize_hit and _prize_kind != "" and _win > 0.0:
					_reveal_prize()
					_finale = 0.45
					return
				_complete()
				return
	_step_fx(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	var aimed := false
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
	if pressed:
		_shoot_pressed()
	accept_event()


func _shoot_pressed() -> void:
	if _phase != "play":
		return
	_fire()


func _kind_for(fish_id: String) -> String:
	match fish_id:
		"small":
			return "small"
		"blue":
			return "fast"
		"golden":
			return "golden"
		"legend":
			return "rare"
		_:
			return ""


func _seed_bubbles() -> void:
	_bubbles.clear()
	for index in 14:
		_bubbles.append({
			"x": 0.04 + float(index) * 0.07,
			"y": randf(),
			"r": 1.5 + float(index % 4),
			"s": 10.0 + float(index) * 1.6,
		})


func _clear_combat() -> void:
	_shots.clear()
	_fx.clear()
	_pops.clear()
	_fish.clear()


func _fill_school(include_prize: bool) -> void:
	_fish.clear()
	var kinds: Array[String] = ["small", "small", "fast", "large", "rare"]
	if include_prize and _prize_kind != "" and not kinds.has(_prize_kind):
		kinds.append(_prize_kind)
	var prize_placed := false
	for index in kinds.size():
		var kind := kinds[index]
		var prize := include_prize and not prize_placed and kind == _prize_kind and _win > 0.0
		if prize:
			prize_placed = true
		_fish.append(_make_fish(kind, prize, index))
	if include_prize and _prize_kind != "" and _win > 0.0 and not prize_placed:
		_fish.append(_make_fish(_prize_kind, true, 3))


func _make_fish(kind: String, prize: bool, slot: int) -> Dictionary:
	var spec: Dictionary = _KINDS[kind]
	var radius := float(spec["radius"])
	var y := _lane_y(slot)
	var even_slot := slot % 2 == 0
	var dir := 1.0
	if even_slot:
		dir = -1.0
	_next_id += 1
	return {
		"id": _next_id,
		"kind": kind,
		"lane": slot,
		"pos": Vector2(randf_range(24.0, maxf(size.x - 24.0, 80.0)), y),
		"dir": dir,
		"speed": float(spec["speed"]) * randf_range(0.92, 1.08),
		"radius": radius,
		"hp": int(spec["hp"]),
		"max_hp": int(spec["hp"]),
		"color": spec["color"],
		"prize": prize,
		"alive": true,
		"flash": 0.0,
		"collapse": 0.0,
		"bob": randf() * TAU,
	}


func _lane_y(slot: int) -> float:
	var top := 78.0
	var bottom := maxf(size.y - 128.0, top + 40.0)
	var span := bottom - top
	return top + fposmod(float(slot) * 0.18, 1.0) * span


func _aim_at(point: Vector2) -> void:
	_pointer = point
	var cannon := _cannon_pos()
	var delta := point - cannon
	if delta.length() < 8.0:
		return
	var angle := delta.angle()
	_aim = clampf(angle, -PI + 0.35, -0.35)


func _fire() -> void:
	if (_phase != "play" and _phase != "finale") or _cooldown > 0.0 or _shots.size() >= 8:
		return
	_cooldown = 0.22
	_recoil = 1.0
	_next_id += 1
	var origin := _cannon_pos() + Vector2(cos(_aim), sin(_aim)) * 28.0
	_shots.append({
		"pos": origin,
		"vel": Vector2(cos(_aim), sin(_aim)) * 460.0,
		"life": 1.8,
	})
	_burst(origin, Color("D7F6FF"), 4)


func _simulate(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_swim(delta)
	var expired: Array[int] = []
	for index in _shots.size():
		var shot: Dictionary = _shots[index]
		shot["pos"] = shot["pos"] + shot["vel"] * delta
		shot["life"] = float(shot["life"]) - delta
		var pos: Vector2 = shot["pos"]
		if float(shot["life"]) <= 0.0 or pos.y < 36.0 or pos.x < -20.0 or pos.x > size.x + 20.0:
			expired.append(index)
			continue
		if _hit_shot(pos):
			expired.append(index)
	for index in range(expired.size() - 1, -1, -1):
		_shots.remove_at(expired[index])
	_spawn += delta
	if _phase == "play" and _spawn > 1.35 and _alive_count() < 6:
		_spawn = 0.0
		var filler: Array[String] = ["small", "fast", "large"]
		_fish.append(_make_fish(filler[_fish.size() % filler.size()], false, _fish.size()))


func _swim(delta: float) -> void:
	var width := maxf(size.x, 120.0)
	for fish in _fish:
		if not bool(fish["alive"]):
			fish["collapse"] = minf(float(fish["collapse"]) + delta * 3.2, 1.0)
			continue
		var pos: Vector2 = fish["pos"]
		var kind := str(fish.get("kind", "small"))
		var speed := float(fish["speed"])
		if kind == "rare":
			speed *= 0.55 + absf(sin(_time * 2.4 + float(fish["bob"])))
		pos.x += float(fish["dir"]) * speed * delta
		var lane_y := _lane_y(int(fish.get("lane", 0)))
		fish["base_y"] = lane_y
		var weave := 8.0
		var bob_speed := 1.6
		if kind == "fast":
			weave = 16.0
			bob_speed = 3.1
		elif kind == "large":
			weave = 4.0
			bob_speed = 0.75
		elif kind == "golden":
			weave = 11.0
			bob_speed = 1.05
		elif kind == "rare":
			weave = 13.0
			bob_speed = 2.2
		pos.y = lane_y + sin(_time * bob_speed + float(fish["bob"])) * weave
		var radius := float(fish["radius"])
		if pos.x > width + radius + 8.0:
			fish["dir"] = -1.0
			pos.x = width + radius
		elif pos.x < -radius - 8.0:
			fish["dir"] = 1.0
			pos.x = -radius
		fish["pos"] = pos
		fish["flash"] = maxf(float(fish["flash"]) - delta * 4.0, 0.0)


func _hit_shot(pos: Vector2) -> bool:
	var closest := -1
	var closest_d := 9999.0
	for index in _fish.size():
		var fish: Dictionary = _fish[index]
		if not bool(fish["alive"]):
			continue
		var fish_pos: Vector2 = fish["pos"]
		var reach := float(fish["radius"]) + 8.0
		var distance := fish_pos.distance_to(pos)
		if distance <= reach and distance < closest_d:
			closest = index
			closest_d = distance
	if closest < 0:
		return false
	_damage(_fish[closest], pos)
	return true


func _damage(fish: Dictionary, at: Vector2) -> void:
	fish["hp"] = int(fish["hp"]) - 1
	fish["flash"] = 1.0
	var ink: Color = fish["color"]
	_burst(at, ink, 6)
	if int(fish["hp"]) > 0:
		_popup(at, "Hit", Color("E7F4FF"))
		return
	fish["alive"] = false
	var points := _points_for(str(fish.get("kind", "small")))
	_score += points
	if bool(fish["prize"]) and not _prize_hit:
		_prize_hit = true
		_shown_reward = _win
		_popup(at, "+%s" % _amount(_win), Color("FFE38A"))
	else:
		_popup(at, "+%d" % points, Color("D7F6FF"))


func _guide_prize() -> void:
	for fish in _fish:
		if not bool(fish["prize"]) or not bool(fish["alive"]):
			continue
		var pos: Vector2 = fish["pos"]
		pos.x = lerpf(pos.x, size.x * 0.5, 0.08)
		pos.y = lerpf(pos.y, size.y * 0.42, 0.08)
		fish["hp"] = mini(int(fish["hp"]), 1)
		fish["pos"] = pos
		fish["base_y"] = pos.y
		if _cooldown <= 0.0 and _shots.is_empty():
			_aim = (pos - _cannon_pos()).angle()
			_cooldown = 0.0
			_fire()
		return
	if _rescued or _prize_hit or _prize_kind == "" or _win <= 0.0:
		return
	_rescued = true
	var rescue := _make_fish(_prize_kind, true, 2)
	var rescue_pos := Vector2(size.x * 0.5, size.y * 0.4)
	rescue["pos"] = rescue_pos
	rescue["base_y"] = rescue_pos.y
	_fish.append(rescue)


func _points_for(kind: String) -> int:
	match kind:
		"fast":
			return 20
		"golden":
			return 50
		"rare":
			return 40
		"large":
			return 30
		_:
			return 10


func _begin_finale() -> void:
	if _phase == "finale":
		return
	_phase = "finale"
	_holding = false
	var short_close := _prize_hit or _prize_kind == "" or _win <= 0.0
	if short_close:
		_finale = 0.85
	else:
		_finale = 1.35
	_place_controls()


func _complete() -> void:
	if _closed:
		return
	_closed = true
	_phase = "done"
	_holding = false
	set_process(false)
	_shots.clear()
	_place_controls()
	queue_redraw()
	finished.emit()


func _reveal_prize() -> void:
	for fish in _fish:
		if bool(fish.get("prize", false)) and bool(fish.get("alive", false)):
			fish["hp"] = 1
			var at: Vector2 = fish["pos"]
			_damage(fish, at)
			return
	if _prize_kind == "":
		return
	var rescue := _make_fish(_prize_kind, true, 2)
	var at := Vector2(size.x * 0.5, size.y * 0.42)
	rescue["pos"] = at
	rescue["hp"] = 1
	_fish.append(rescue)
	_damage(rescue, at)


func _alive_count() -> int:
	var count := 0
	for fish in _fish:
		if bool(fish["alive"]):
			count += 1
	return count


func _burst(at: Vector2, color: Color, count: int) -> void:
	var room := 20 - _fx.size()
	for index in mini(count, room):
		var angle := randf() * TAU
		_fx.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(30.0, 90.0),
			"life": 0.35,
			"color": color,
		})


func _popup(at: Vector2, text: String, color: Color) -> void:
	if _pops.size() > 6:
		_pops.pop_front()
	_pops.append({"pos": at, "text": text, "life": 0.7, "color": color})


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
		pop["pos"] = pop["pos"] + Vector2(0, -28.0 * delta)
		if float(pop["life"]) <= 0.0:
			_pops.remove_at(index)


func _drift_bubbles(delta: float) -> void:
	for bubble in _bubbles:
		bubble["y"] = float(bubble["y"]) - delta * float(bubble["s"]) / maxf(size.y, 1.0)
		if float(bubble["y"]) < 0.08:
			bubble["y"] = 0.92


func _cannon_pos() -> Vector2:
	return Vector2(size.x * 0.5, size.y - 78.0) + Vector2(cos(_aim), sin(_aim)) * -_recoil * 8.0


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
	draw_rect(rect, Color("041826"), true)
	draw_rect(Rect2(0, 0, size.x, size.y * 0.38), Color("0B6284"), true)
	draw_rect(Rect2(0, size.y * 0.38, size.x, size.y * 0.34), Color("08445C"), true)
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("062E40"), true)
	draw_rect(Rect2(0, size.y - 42.0, size.x, 42.0), Color("0E4A3C"), true)
	for shaft in 3:
		var x := size.x * (0.22 + float(shaft) * 0.26)
		var glow := Color(0.75, 0.9, 1.0, 0.05)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0),
			Vector2(x + 36.0, 0),
			Vector2(x + 80.0, size.y),
			Vector2(x - 10.0, size.y),
		]), glow)
	_draw_distant()
	_draw_coral(false)
	for bubble in _bubbles:
		var at := Vector2(float(bubble["x"]) * size.x, float(bubble["y"]) * size.y)
		draw_circle(at, float(bubble["r"]), Color(1, 1, 1, 0.16))
	for fish in _fish:
		_draw_fish(fish)
	for shot in _shots:
		var pos: Vector2 = shot["pos"]
		draw_circle(pos, 7.0, Color("E9FBFF"))
		draw_circle(pos, 3.5, Color("7EE7FF"))
	for bit in _fx:
		var alpha := clampf(float(bit["life"]) / 0.35, 0.0, 1.0)
		var color: Color = bit["color"]
		color.a = alpha
		draw_circle(bit["pos"], 3.0 + alpha * 3.0, color)
	_draw_cannon()
	_draw_coral(true)
	_draw_hud()
	for pop in _pops:
		_draw_popup(pop)
	if _phase == "countdown":
		_draw_center(str(maxi(_count_n, 1)), "Aim the cannon")
	elif _phase == "loading":
		_draw_center("Diving", "Get ready")
	elif _phase == "idle":
		_draw_center("", "Aim and shoot the glowing fish")
	elif _phase == "play" and _left <= 3.0:
		_draw_center(str(int(ceil(_left))), "Final seconds")


func _draw_distant() -> void:
	for index in 6:
		var span := size.x + 90.0
		var travel := fposmod(_time * (16.0 + float(index) * 5.0) + float(index) * 70.0, span) - 40.0
		var y := 96.0 + float(index) * 22.0
		var ink := Color(0.45, 0.72, 0.82, 0.22)
		var body := Vector2(travel, y + sin(_time * 0.8 + float(index)) * 6.0)
		draw_colored_polygon(PackedVector2Array([
			body + Vector2(14, 0),
			body + Vector2(-8, -6),
			body + Vector2(-16, 0),
			body + Vector2(-8, 6),
		]), ink)


func _draw_coral(front: bool) -> void:
	var bases: Array[float] = [0.16, 0.78]
	var color := Color("1E6A52")
	var alpha := 0.45
	var bulb := 22.0
	if front:
		bases = [0.08, 0.9]
		color = Color("C4526A")
		alpha = 0.9
		bulb = 16.0
	color.a = alpha
	for base_x in bases:
		var origin := Vector2(size.x * base_x, size.y - 18.0)
		draw_circle(origin + Vector2(0, -18), bulb, color)
		draw_circle(origin + Vector2(-14, -6), 10.0, color)
		draw_circle(origin + Vector2(12, -8), 12.0, color)


func _draw_fish(fish: Dictionary) -> void:
	var collapse := float(fish["collapse"])
	if collapse >= 1.0:
		return
	var pos: Vector2 = fish["pos"]
	var radius := float(fish["radius"]) * (1.0 - collapse)
	var dir := float(fish["dir"])
	var color: Color = fish["color"]
	if float(fish["flash"]) > 0.0:
		color = color.lightened(0.45)
	if bool(fish["prize"]) and bool(fish["alive"]):
		var ring := Color("FFE38A")
		ring.a = 0.35 + sin(_time * 6.0) * 0.15
		draw_circle(pos, radius + 8.0, ring)
	var nose := Vector2(dir * radius, 0)
	var tail := Vector2(-dir * radius * 0.2, 0)
	draw_colored_polygon(PackedVector2Array([
		pos + nose,
		pos + tail + Vector2(0, -radius * 0.62),
		pos + Vector2(-dir * radius * 0.95, 0),
		pos + tail + Vector2(0, radius * 0.62),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-dir * radius * 0.7, -radius * 0.15),
		pos + Vector2(-dir * radius * 1.35, -radius * 0.55),
		pos + Vector2(-dir * radius * 1.35, radius * 0.55),
		pos + Vector2(-dir * radius * 0.7, radius * 0.15),
	]), color.darkened(0.15))
	draw_circle(pos + Vector2(dir * radius * 0.35, -radius * 0.18), maxf(radius * 0.12, 2.0), Color("102033"))


func _draw_cannon() -> void:
	var origin := _cannon_pos()
	var tip := origin + Vector2(cos(_aim), sin(_aim)) * 36.0
	draw_line(origin, tip, Color("D7F6FF"), 8.0)
	draw_circle(origin, 16.0, Color("14324A"))
	draw_circle(origin, 8.0, Color("7EE7FF"))
	var aim_end := origin + Vector2(cos(_aim), sin(_aim)) * 78.0
	draw_line(tip, aim_end, Color(0.85, 0.95, 1.0, 0.35), 2.0)
	draw_circle(aim_end, 4.0, Color(1, 1, 1, 0.45))
	if _recoil > 0.35:
		draw_circle(tip, 10.0 + _recoil * 6.0, Color(0.85, 0.96, 1.0, 0.55))


func _draw_hud() -> void:
	if _font == null:
		return
	draw_rect(Rect2(0, 0, size.x, 64), Color(0.02, 0.06, 0.1, 0.72), true)
	var col := size.x / 4.0
	var value_size := 18
	if size.x < 430.0:
		value_size = 16
	var timer_color := Color("F4F7FB")
	if _left <= 3.0 and _phase == "play":
		timer_color = Color("FFE38A")
	var time_label := "--"
	if _phase == "play" or _phase == "finale":
		time_label = "%ds" % int(ceil(_left))
	_column_text(0.0, col, "CREDITS", _amount(_credits), Color("E7C56A"), Color("FFF8E6"), value_size)
	_column_text(col, col, "ENTRY", _amount(_bet), Color("9AA6BD"), Color("F4F7FB"), value_size)
	_column_text(col * 2.0, col, "TIME", time_label, Color("9AA6BD"), timer_color, value_size)
	var score_text := str(_score)
	if _shown_reward > 0.0:
		score_text = "%d +%s" % [_score, _amount(_shown_reward)]
	_column_text(col * 3.0, col, "SCORE", score_text, Color("9AA6BD"), Color("3DDC97"), value_size)


func _draw_center(primary: String, caption: String) -> void:
	if _font == null:
		return
	if primary != "":
		var size_px := 64
		var text_size := _font.get_string_size(primary, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
		_font_draw(Vector2((size.x - text_size.x) * 0.5, size.y * 0.46), primary, size_px, Color("FFF8E6"))
	var caption_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	_font_draw(Vector2((size.x - caption_size.x) * 0.5, size.y * 0.56), caption, 18, Color("D7F6FF"))


func _draw_popup(pop: Dictionary) -> void:
	if _font == null:
		return
	var alpha := clampf(float(pop["life"]) / 0.7, 0.0, 1.0)
	var color: Color = pop["color"]
	color.a = alpha
	_font_draw(pop["pos"], str(pop["text"]), 20, color)


func _column_text(x: float, width: float, caption: String, value: String, caption_color: Color, value_color: Color, value_size: int) -> void:
	draw_string(_font, Vector2(x + 8.0, 20), caption, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, 11, caption_color)
	draw_string(_font, Vector2(x + 8.0, 46), value, HORIZONTAL_ALIGNMENT_LEFT, width - 12.0, value_size, value_color)


func _font_draw(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _amount(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.2f" % value
