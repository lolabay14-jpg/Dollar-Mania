extends CanvasLayer

signal resume_pressed
signal restart_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	UiTheme.apply(%Card)
	%Dim.color = Color(0, 0, 0, 0.62)
	%Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_title(%Title, 32)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Note)
	%Note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%ResumeButton.theme_type_variation = "PrimaryButton"
	%ResumeButton.pressed.connect(func() -> void: resume_pressed.emit())
	%RestartButton.pressed.connect(func() -> void: restart_pressed.emit())
	%MenuButton.pressed.connect(AppState.go_start)
	visible = false


func open() -> void:
	visible = true
	%Message.text = ""


func close() -> void:
	visible = false


func show_message(text: String) -> void:
	%Message.text = text
	%Message.add_theme_color_override("font_color", UiTheme.COL_DANGER)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_game"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
