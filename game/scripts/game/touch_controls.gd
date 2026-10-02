extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply(self)
	_bind(%LeftButton, "move_left")
	_bind(%RightButton, "move_right")
	_bind(%UpButton, "move_up")
	_bind(%DownButton, "move_down")
	for button in [%LeftButton, %RightButton, %UpButton, %DownButton]:
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(72, 72)
	refresh_visibility()
	get_viewport().size_changed.connect(refresh_visibility)


func refresh_visibility() -> void:
	visible = GameInput.prefers_touch_controls()


func _bind(button: BaseButton, action: String) -> void:
	button.button_down.connect(Input.action_press.bind(action))
	button.button_up.connect(Input.action_release.bind(action))
	button.mouse_exited.connect(Input.action_release.bind(action))
