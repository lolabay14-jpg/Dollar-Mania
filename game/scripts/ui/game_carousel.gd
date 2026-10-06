class_name GameCarousel
extends VBoxContainer

## One master horizontal game slider. Gestures are scoped to the card track only.

signal play_pressed(game: Dictionary)

const AXIS_THRESHOLD := 10.0

var _scroller: ScrollContainer
var _row: HBoxContainer
var _fade_left: ColorRect
var _fade_right: ColorRect
var _shell: Control
var _scrub: Control
var _track: ColorRect
var _thumb: Panel
var _card_size := Vector2(280, 200)
var _gap := 18
var _tween: Tween
var _dragging := false
var _axis_locked := false
var _horizontal := false
var _drag_from := Vector2.ZERO
var _scroll_from := 0
var _page_scroll := 0
var _page: ScrollContainer
var _scrub_dragging := false
var _scrub_from_x := 0.0
var _scrub_scroll_from := 0
var _syncing_scrub := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = false
	add_theme_constant_override("separation", 12)


func setup(games: Array, card_size: Vector2, title := "Games", subtitle := "") -> void:
	_card_size = card_size
	if _scroller == null or _row == null or not is_instance_valid(_scroller):
		for child in get_children():
			remove_child(child)
			child.free()
		_build_header(title, subtitle)
		_build_track()
		_build_scrubber()
	else:
		_update_header(title, subtitle)
		_shell.custom_minimum_size = Vector2(0, _card_size.y)
		_scroller.custom_minimum_size = Vector2(0, _card_size.y)
		_row.custom_minimum_size.y = _card_size.y
	_fill(games)
	call_deferred("_refresh_chrome")
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _update_header(title: String, subtitle: String) -> void:
	if get_child_count() == 0:
		return
	var header := get_child(0)
	if header == null:
		return
	for child in header.get_children():
		if child is VBoxContainer:
			var copy := child as VBoxContainer
			if copy.get_child_count() > 0 and copy.get_child(0) is Label:
				(copy.get_child(0) as Label).text = title
			if subtitle != "" and copy.get_child_count() > 1 and copy.get_child(1) is Label:
				(copy.get_child(1) as Label).text = subtitle
			elif subtitle != "" and copy.get_child_count() == 1:
				var sub := Label.new()
				sub.text = subtitle
				UiTheme.style_muted(sub)
				copy.add_child(sub)
			break


func _build_header(title: String, subtitle: String) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	add_child(header)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 2)
	header.add_child(copy)
	var title_label := Label.new()
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.style_title(title_label, 22)
	copy.add_child(title_label)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.style_muted(sub)
		copy.add_child(sub)


func _build_track() -> void:
	_shell = Control.new()
	_shell.name = "TrackShell"
	_shell.custom_minimum_size = Vector2(0, _card_size.y)
	_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_shell.clip_contents = true
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shell)
	_scroller = ScrollContainer.new()
	_scroller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroller.custom_minimum_size = Vector2(0, _card_size.y)
	_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroller.clip_contents = true
	_scroller.follow_focus = false
	_scroller.mouse_filter = Control.MOUSE_FILTER_STOP
	_shell.add_child(_scroller)
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", _gap)
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.custom_minimum_size = Vector2(0, _card_size.y)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroller.add_child(_row)
	_lock_row_flags()
	_scroller.resized.connect(_lock_row_flags)
	_row.resized.connect(_lock_row_flags)
	# Gesture handling is scoped strictly to the card track shell.
	_shell.gui_input.connect(_on_track_input)
	_scroller.gui_input.connect(_on_track_input)
	_scroller.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _refresh_chrome())
	_fade_left = _edge_fade(true)
	_fade_right = _edge_fade(false)
	_shell.add_child(_fade_left)
	_shell.add_child(_fade_right)


func _build_scrubber() -> void:
	_scrub = Control.new()
	_scrub.name = "Scrubber"
	_scrub.custom_minimum_size = Vector2(0, 28)
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrub)
	_track = ColorRect.new()
	_track.color = Color(0.16, 0.2, 0.3, 0.9)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrub.add_child(_track)
	_thumb = Panel.new()
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.custom_minimum_size = Vector2(54, 14)
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = Color(UiTheme.COL_GOLD, 0.95)
	thumb_style.border_color = Color(UiTheme.COL_GOLD_SOFT, 0.9)
	thumb_style.set_border_width_all(1)
	thumb_style.set_corner_radius_all(8)
	thumb_style.shadow_color = Color(UiTheme.COL_GOLD, 0.35)
	thumb_style.shadow_size = 8
	_thumb.add_theme_stylebox_override("panel", thumb_style)
	_scrub.add_child(_thumb)
	_scrub.resized.connect(_layout_scrubber)
	_scrub.gui_input.connect(_on_scrub_input)
	_layout_scrubber()


func _layout_scrubber() -> void:
	if _scrub == null or _track == null or _thumb == null:
		return
	var w := _scrub.size.x
	var h := _scrub.size.y
	_track.position = Vector2(0, (h - 4.0) * 0.5)
	_track.size = Vector2(w, 4.0)
	_update_thumb_from_scroll()


func _update_thumb_from_scroll() -> void:
	if _scrub == null or _thumb == null or _scroller == null or _syncing_scrub:
		return
	var max_scroll := _max_scroll()
	var track_w := maxf(_scrub.size.x, 1.0)
	var thumb_w := clampf(track_w * 0.22, 44.0, 72.0)
	if max_scroll <= 0:
		thumb_w = track_w
	_thumb.size = Vector2(thumb_w, 14.0)
	var travel := maxf(track_w - thumb_w, 0.0)
	var ratio := 0.0 if max_scroll <= 0 else clampf(float(_scroller.scroll_horizontal) / float(max_scroll), 0.0, 1.0)
	_thumb.position = Vector2(travel * ratio, (_scrub.size.y - 14.0) * 0.5)
	_scrub.visible = true
	_scrub.modulate = Color(1, 1, 1, 1.0 if max_scroll > 4 else 0.45)


func _on_scrub_input(event: InputEvent) -> void:
	if _scrub == null or _scroller == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_begin_scrub(mouse.position.x)
		else:
			_end_scrub()
		accept_event()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_scrub(touch.position.x)
		else:
			_end_scrub()
		accept_event()
		return
	if event is InputEventMouseMotion and _scrub_dragging:
		var motion := event as InputEventMouseMotion
		_drag_scrub_to(motion.position.x)
		accept_event()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and _scrub_dragging:
		var drag := event as InputEventScreenDrag
		_drag_scrub_to(drag.position.x)
		accept_event()
		get_viewport().set_input_as_handled()


func _begin_scrub(local_x: float) -> void:
	_scrub_dragging = true
	_scrub_from_x = local_x
	if _tween:
		_tween.kill()
	# Tap outside the thumb jumps; tap on thumb keeps relative drag.
	var on_thumb := Rect2(_thumb.position, _thumb.size).grow(6.0).has_point(Vector2(local_x, _scrub.size.y * 0.5))
	if not on_thumb:
		_jump_scrub_to(local_x)
	_scrub_scroll_from = _scroller.scroll_horizontal
	_scrub_from_x = local_x


func _end_scrub() -> void:
	if _scrub_dragging:
		_scrub_dragging = false
		_snap_nearest()
	_refresh_chrome()


func _jump_scrub_to(local_x: float) -> void:
	var max_scroll := _max_scroll()
	if max_scroll <= 0 or _scrub == null:
		return
	var thumb_w := _thumb.size.x
	var travel := maxf(_scrub.size.x - thumb_w, 1.0)
	var ratio := clampf((local_x - thumb_w * 0.5) / travel, 0.0, 1.0)
	_syncing_scrub = true
	_scroller.scroll_horizontal = int(ratio * float(max_scroll))
	_syncing_scrub = false
	_refresh_chrome()


func _drag_scrub_to(local_x: float) -> void:
	var max_scroll := _max_scroll()
	if max_scroll <= 0 or _scrub == null:
		return
	var travel := maxf(_scrub.size.x - _thumb.size.x, 1.0)
	var delta_scroll := int(((local_x - _scrub_from_x) / travel) * float(max_scroll))
	_syncing_scrub = true
	_scroller.scroll_horizontal = clampi(_scrub_scroll_from + delta_scroll, 0, max_scroll)
	_syncing_scrub = false
	_refresh_chrome()


func _edge_fade(left: bool) -> ColorRect:
	var fade := ColorRect.new()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.04, 0.06, 0.1, 0.55)
	fade.visible = false
	if left:
		fade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		fade.offset_right = 28.0
	else:
		fade.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		fade.offset_left = -28.0
	return fade


func _lock_row_flags() -> void:
	if _row == null:
		return
	_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.size.y = _card_size.y
	_row.custom_minimum_size.y = _card_size.y


func _fill(games: Array) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.free()
	var count := 0
	for game in games:
		if not game is Dictionary:
			continue
		var slot := Control.new()
		slot.custom_minimum_size = _card_size
		slot.size = _card_size
		slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.clip_contents = true
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_row.add_child(slot)
		var card := GameCard.new()
		slot.add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.configure(game, false, true, "", _card_size)
		card.play_pressed.connect(func(selected: Dictionary) -> void: play_pressed.emit(selected))
		# Forward only track-local gestures that begin on a card.
		slot.gui_input.connect(_on_track_input)
		card.gui_input.connect(_on_track_input)
		count += 1
	var width := 0.0 if count == 0 else float(count) * _card_size.x + float(maxi(count - 1, 0)) * float(_gap)
	_row.custom_minimum_size = Vector2(width, _card_size.y)
	_lock_row_flags()
	_scroller.scroll_horizontal = 0
	_refresh_chrome()


func _find_page() -> ScrollContainer:
	if _page != null and is_instance_valid(_page):
		return _page
	var node: Node = self
	while node:
		if node is ScrollContainer and node != _scroller:
			_page = node as ScrollContainer
			return _page
		node = node.get_parent()
	return null


func _event_point(event: InputEvent) -> Vector2:
	# Prefer global mouse coords; touch/drag positions from gui_input are control-local,
	# so accumulate using relative deltas after the initial press.
	if event is InputEventMouse:
		return (event as InputEventMouse).global_position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO


func _begin_track_drag(point: Vector2) -> void:
	_dragging = true
	_axis_locked = false
	_horizontal = false
	_drag_from = point
	_scroll_from = _scroller.scroll_horizontal
	var page := _find_page()
	if page:
		_page_scroll = page.scroll_vertical
	if _tween:
		_tween.kill()


func _end_track_drag() -> void:
	if _dragging and _horizontal:
		_snap_nearest()
	_dragging = false
	_axis_locked = false
	_horizontal = false
	_refresh_chrome()


func _apply_track_drag(point: Vector2, relative: Vector2) -> void:
	if not _dragging:
		return
	if not _axis_locked:
		if absf(relative.x) < 1.5 and absf(relative.y) < 1.5:
			return
		if not has_meta("_drag_accum"):
			set_meta("_drag_accum", Vector2.ZERO)
		var accum: Vector2 = get_meta("_drag_accum")
		accum += relative
		set_meta("_drag_accum", accum)
		if absf(accum.x) < AXIS_THRESHOLD and absf(accum.y) < AXIS_THRESHOLD:
			return
		_axis_locked = true
		_horizontal = absf(accum.x) > absf(accum.y)
		if not _horizontal:
			# Vertical intent: release carousel claim so the page can scroll.
			_dragging = false
			_axis_locked = false
			_horizontal = false
			if has_meta("_drag_accum"):
				remove_meta("_drag_accum")
			if has_meta("_h_delta"):
				remove_meta("_h_delta")
			return
	if _horizontal:
		if not has_meta("_h_delta"):
			set_meta("_h_delta", 0.0)
		var h_delta: float = get_meta("_h_delta")
		h_delta += relative.x
		set_meta("_h_delta", h_delta)
		_scroller.scroll_horizontal = clampi(int(_scroll_from - h_delta), 0, _max_scroll())
		var page := _find_page()
		if page:
			page.scroll_vertical = _page_scroll
		_refresh_chrome()
		accept_event()
		get_viewport().set_input_as_handled()


func _on_track_input(event: InputEvent) -> void:
	if _scroller == null or _shell == null:
		return
	# Mouse wheel over the track only → horizontal browse.
	if event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		if wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var dir := -1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_scroller.scroll_horizontal = clampi(_scroller.scroll_horizontal + dir * int((_card_size.x + _gap) * 0.45), 0, _max_scroll())
			_refresh_chrome()
			accept_event()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			# gui_input only fires for hits on the track/cards — never the rest of the page.
			set_meta("_drag_accum", Vector2.ZERO)
			set_meta("_h_delta", 0.0)
			_begin_track_drag(_event_point(mouse))
			# Do not accept yet — wait for axis decision so vertical page scroll still works.
		else:
			if has_meta("_drag_accum"):
				remove_meta("_drag_accum")
			if has_meta("_h_delta"):
				remove_meta("_h_delta")
			_end_track_drag()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			set_meta("_drag_accum", Vector2.ZERO)
			set_meta("_h_delta", 0.0)
			_begin_track_drag(_event_point(touch))
		else:
			if has_meta("_drag_accum"):
				remove_meta("_drag_accum")
			if has_meta("_h_delta"):
				remove_meta("_h_delta")
			_end_track_drag()
		return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_apply_track_drag(_event_point(motion), motion.relative)
		return
	if event is InputEventScreenDrag and _dragging:
		var drag := event as InputEventScreenDrag
		_apply_track_drag(_event_point(drag), drag.relative)


func _snap_nearest() -> void:
	var step := _card_size.x + float(_gap)
	if step <= 1.0:
		return
	var index := int(round(float(_scroller.scroll_horizontal) / step))
	_animate_to(clampi(int(float(index) * step), 0, _max_scroll()))


func _animate_to(target: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_scroller, "scroll_horizontal", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_refresh_chrome)


func _max_scroll() -> int:
	if _scroller == null or _row == null:
		return 0
	return maxi(int(_row.get_combined_minimum_size().x - _scroller.size.x), 0)


func _refresh_chrome() -> void:
	if _scroller == null:
		return
	var max_scroll := _max_scroll()
	var can_scroll := max_scroll > 4
	if _fade_left:
		_fade_left.visible = can_scroll and _scroller.scroll_horizontal > 4
	if _fade_right:
		_fade_right.visible = can_scroll and _scroller.scroll_horizontal < max_scroll - 4
	_update_thumb_from_scroll()


func _on_resized() -> void:
	_lock_row_flags()
	_layout_scrubber()
	_refresh_chrome()
