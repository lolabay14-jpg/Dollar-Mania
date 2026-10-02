extends Control

var _busy := false

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	UiTheme.style_title(%Title, 36)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_muted(%ErrorLabel)
	%ErrorLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%CreateButton.theme_type_variation = "PrimaryButton"
	%Username.placeholder_text = "Username"
	%Email.placeholder_text = "Email"
	%Password.placeholder_text = "Password"
	%ConfirmPassword.placeholder_text = "Confirm Password"
	%Password.secret = true
	%ConfirmPassword.secret = true
	%CreateButton.pressed.connect(_submit)
	%LoginButton.pressed.connect(AppState.go_login)
	%Username.text_submitted.connect(func(_text: String) -> void: %Email.grab_focus())
	%Email.text_submitted.connect(func(_text: String) -> void: %Password.grab_focus())
	%Password.text_submitted.connect(func(_text: String) -> void: %ConfirmPassword.grab_focus())
	%ConfirmPassword.text_submitted.connect(func(_text: String) -> void: _submit())
	resized.connect(_fit)
	_fit()
	UiMotion.fade_in(%Column)
	UiMotion.bind_tree(self)
	%Username.grab_focus()


func _fit() -> void:
	ScreenLayout.fit_column(_column, 460.0)


func _submit() -> void:
	if _busy:
		return
	var username_value := str(%Username.text).strip_edges()
	var email := str(%Email.text).strip_edges()
	var password := str(%Password.text)
	var confirm_password := str(%ConfirmPassword.text)
	var problem := _validate(username_value, email, password, confirm_password)
	if problem != "":
		_show_error(problem)
		return
	_busy = true
	%CreateButton.disabled = true
	%LoginButton.disabled = true
	%CreateButton.text = "Creating account..."
	_show_error("")
	var response: Dictionary = await ApiClient.register(username_value, email, password, confirm_password)
	if not is_inside_tree():
		return
	_busy = false
	%CreateButton.disabled = false
	%LoginButton.disabled = false
	%CreateButton.text = "Create Account"
	if not response.ok:
		_show_error(str(response.error))
		return
	%Password.text = ""
	%ConfirmPassword.text = ""
	AppState.login_notice = "Account created. Sign in to continue."
	AppState.go_login()


func _validate(username_value: String, email: String, password: String, confirm_password: String) -> String:
	if username_value == "":
		return "Username is required."
	if email == "":
		return "Email is required."
	if not email.contains("@") or not email.contains("."):
		return "Enter a valid email."
	if password == "":
		return "Password is required."
	if confirm_password == "":
		return "Confirm your password."
	if password != confirm_password:
		return "Passwords do not match."
	if password.length() < 8:
		return "Password must be at least 8 characters."
	return ""


func _show_error(message: String) -> void:
	%ErrorLabel.text = message
	%ErrorLabel.add_theme_color_override("font_color", UiTheme.COL_DANGER)
