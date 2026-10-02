class_name GameInput
extends RefCounted

## Desktop reads the keyboard. Touch buttons call Input.action_press on these
## same actions, so a later virtual joystick can replace the d-pad without
## changing the player script.

static func ensure_actions() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("pause_game", [KEY_ESCAPE, KEY_P])


static func get_move_vector() -> Vector2:
	ensure_actions()
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction


static func release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.has_action(action):
			Input.action_release(action)


static func prefers_touch_controls() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	return DisplayServer.is_touchscreen_available()


static func _bind(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_get_events(action).is_empty():
		return
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)
