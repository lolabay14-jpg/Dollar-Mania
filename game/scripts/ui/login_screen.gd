extends Control

var _busy := false

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.mood(self, "calm")
	UiTheme.style_title(%Title, 34)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%Welcome)
	%Welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.paint_glass(%Card)
	UiTheme.style_muted(%ErrorLabel)
	%ErrorLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%LoginButton.theme_type_variation = "PrimaryButton"
	%SignupButton.theme_type_variation = "TextLink"
	%Username.placeholder_text = "Username"
	%Password.placeholder_text = "Password"
	%Password.secret = true
	%LoginButton.pressed.connect(_submit)
	%SignupButton.pressed.connect(AppState.go_signup)
	%Username.text_submitted.connect(func(_text: String) -> void: %Password.grab_focus())
	%Password.text_submitted.connect(func(_text: String) -> void: _submit())
	resized.connect(_fit)
	_fit()
	if AppState.login_notice != "":
		%ErrorLabel.text = AppState.login_notice
		%ErrorLabel.add_theme_color_override("font_color", UiTheme.COL_GREEN)
		AppState.login_notice = ""
	UiMotion.bind_fields(self)
	UiMotion.bind_tree(self)
	UiMotion.enter(%Column, SceneTransition.slide)
	%Username.grab_focus()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 460.0)


func _submit() -> void:
	if _busy:
		return
	var username_value := str(%Username.text).strip_edges()
	var password := str(%Password.text)
	if username_value == "" or password == "":
		_show_error("Enter your username and password.")
		return
	_busy = true
	%LoginButton.disabled = true
	%SignupButton.disabled = true
	%LoginButton.text = "Signing in..."
	_show_error("")
	var response: Dictionary = await ApiClient.login(username_value, password)
	if not is_inside_tree():
		return
	if not response.ok:
		_busy = false
		%LoginButton.disabled = false
		%SignupButton.disabled = false
		%LoginButton.text = "Login"
		_show_error(str(response.error))
		return
	%Password.text = ""
	var me: Dictionary = await ApiClient.get_current_user()
	if not is_inside_tree():
		return
	if not me.ok:
		ApiClient.logout()
		_busy = false
		%LoginButton.disabled = false
		%SignupButton.disabled = false
		%LoginButton.text = "Login"
		_show_error(str(me.error))
		return
	if ApiClient.role() == "ADMIN":
		AppState.go_admin()
	elif ApiClient.role() == "PLAYER":
		AppState.go_player()
	else:
		ApiClient.logout()
		_busy = false
		%LoginButton.disabled = false
		%SignupButton.disabled = false
		%LoginButton.text = "Login"
		_show_error("This account cannot sign in.")


func _show_error(message: String) -> void:
	%ErrorLabel.text = message
	%ErrorLabel.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	UiTheme.paint_glass(%Card, message != "")
