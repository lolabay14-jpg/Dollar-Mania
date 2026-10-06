extends Control

var _busy := false

@onready var _column: MarginContainer = %Column


func _ready() -> void:
	UiTheme.apply(self)
	$Background.color = UiTheme.COL_BG
	# Atmosphere only — keep decorative artwork text from dominating the form.
	ArcadeBackdrop.mount_photo(self, GameArt.screen_path("splash"), 0.64, 0.08)
	UiTheme.mood(self, "calm")
	%Title.visible = false
	_style_card()
	_style_copy()
	_style_fields()
	_style_button()
	UiTheme.style_muted(%ErrorLabel)
	%ErrorLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Username.placeholder_text = "Username or email"
	%Password.placeholder_text = "Password"
	%Password.secret = true
	%LoginButton.pressed.connect(_submit)
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
	# enter() animates MarginContainer theme margins — always pass %Column, not the card panel.
	UiMotion.enter(%Column, SceneTransition.slide)
	%Username.grab_focus()


func _style_card() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.14, 0.88)
	box.border_color = Color(UiTheme.COL_GOLD, 0.42)
	box.set_border_width_all(1)
	box.set_corner_radius_all(22)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 28
	box.shadow_offset = Vector2(0, 12)
	%Card.add_theme_stylebox_override("panel", box)
	%Card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Card.custom_minimum_size = Vector2(0, 0)


func _style_copy() -> void:
	%Welcome.text = "Welcome back"
	%Welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Welcome.add_theme_font_size_override("font_size", 28)
	%Welcome.add_theme_color_override("font_color", Color("FFF8E6"))
	var hint := %Hint
	hint.text = "Sign in with your player or admin account"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiTheme.COL_MUTED)


func _style_fields() -> void:
	for field in [%Username, %Password]:
		field.custom_minimum_size = Vector2(0, 54)
		field.add_theme_font_size_override("font_size", 17)
		field.add_theme_color_override("font_color", UiTheme.COL_TEXT)
		field.add_theme_color_override("font_placeholder_color", Color(UiTheme.COL_MUTED, 0.9))
		field.add_theme_color_override("caret_color", UiTheme.COL_GOLD)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.07, 0.1, 0.16, 0.96)
		normal.border_color = Color(0.42, 0.5, 0.66, 0.45)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(14)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		var focus := normal.duplicate() as StyleBoxFlat
		focus.border_color = Color(UiTheme.COL_GOLD, 0.95)
		focus.set_border_width_all(2)
		focus.shadow_color = Color(UiTheme.COL_GOLD, 0.22)
		focus.shadow_size = 10
		field.add_theme_stylebox_override("normal", normal)
		field.add_theme_stylebox_override("focus", focus)
		field.add_theme_stylebox_override("read_only", normal)


func _style_button() -> void:
	%LoginButton.text = "Login"
	%LoginButton.custom_minimum_size = Vector2(0, 56)
	%LoginButton.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(UiTheme.COL_GOLD, 0.96)
	normal.border_color = Color(UiTheme.COL_GOLD_SOFT, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	normal.shadow_color = Color(UiTheme.COL_GOLD, 0.35)
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(UiTheme.COL_GOLD.lightened(0.1), 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(UiTheme.COL_GOLD_DARK, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.28, 0.3, 0.36, 0.9)
	disabled.border_color = Color(0.4, 0.42, 0.48, 0.6)
	disabled.shadow_size = 0
	%LoginButton.add_theme_stylebox_override("normal", normal)
	%LoginButton.add_theme_stylebox_override("hover", hover)
	%LoginButton.add_theme_stylebox_override("pressed", pressed)
	%LoginButton.add_theme_stylebox_override("focus", hover)
	%LoginButton.add_theme_stylebox_override("disabled", disabled)
	%LoginButton.add_theme_color_override("font_color", UiTheme.COL_INK)
	%LoginButton.add_theme_color_override("font_hover_color", UiTheme.COL_INK)
	%LoginButton.add_theme_color_override("font_pressed_color", UiTheme.COL_INK)
	%LoginButton.add_theme_color_override("font_disabled_color", Color(0.75, 0.76, 0.8))
	%LoginButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not %LoginButton.button_down.is_connected(_press_login):
		%LoginButton.button_down.connect(_press_login)
	if not %LoginButton.button_up.is_connected(_release_login):
		%LoginButton.button_up.connect(_release_login)


func _press_login() -> void:
	%LoginButton.pivot_offset = %LoginButton.size * 0.5
	var tween := create_tween()
	tween.tween_property(%LoginButton, "scale", Vector2(0.98, 0.98), 0.08).set_trans(Tween.TRANS_CUBIC)


func _release_login() -> void:
	%LoginButton.pivot_offset = %LoginButton.size * 0.5
	var tween := create_tween()
	tween.tween_property(%LoginButton, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_CUBIC)


func _fit() -> void:
	# Comfortable card width on desktop; full usable width on phones with side gutters.
	var max_width := 400.0 if size.x >= 900.0 else (420.0 if size.x >= 720.0 else 460.0)
	ScreenLayout.fit_column(_column, max_width)
	var scroll := $Scroll as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := $Scroll/Column/Content as VBoxContainer
	var top := %TopSpacer
	var bottom := %BottomSpacer
	if content and top and bottom:
		top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Stretch the content to the viewport so spacers can vertically center the card.
		var top_m := float(_column.get_theme_constant("margin_top"))
		var bottom_m := float(_column.get_theme_constant("margin_bottom"))
		var view_h := maxf(size.y - top_m - bottom_m, 0.0)
		content.custom_minimum_size.y = view_h
		# Slightly more space above → card sits a touch below true center.
		top.size_flags_stretch_ratio = 1.15
		bottom.size_flags_stretch_ratio = 1.0
		top.custom_minimum_size.y = 20.0
		bottom.custom_minimum_size.y = 16.0
	%Card.custom_minimum_size.x = 0.0


func _submit() -> void:
	if _busy:
		return
	var username_value := str(%Username.text).strip_edges()
	var password := str(%Password.text)
	if username_value == "" or password == "":
		_show_error("Enter your username or email and password.")
		return
	_busy = true
	%LoginButton.disabled = true
	%LoginButton.text = "Signing in..."
	_show_error("")
	var response: Dictionary = await ApiClient.login(username_value, password)
	if not is_inside_tree():
		return
	if not response.ok:
		_busy = false
		%LoginButton.disabled = false
		%LoginButton.text = "Login"
		_show_error(str(response.error))
		return
	%Password.text = ""
	var me: Dictionary = await ApiClient.get_current_user()
	if not is_inside_tree():
		return
	if not me.ok:
		push_error("Login session check failed. HTTP status %d. Response: %s" % [
			int(me.get("status", 0)),
			str(me.get("body", me.get("error", ""))),
		])
		ApiClient.logout()
		_busy = false
		%LoginButton.disabled = false
		%LoginButton.text = "Login"
		_show_error(str(me.error))
		return
	if ApiClient.role() == "SUPER_ADMIN":
		AppState.go_super_admin()
	elif ApiClient.role() == "ADMIN":
		AppState.go_admin()
	elif ApiClient.role() == "PLAYER":
		AppState.go_player()
	else:
		push_error("Login failed. HTTP status %d. Role '%s' cannot open a dashboard." % [
			int(me.get("status", 200)),
			ApiClient.role(),
		])
		ApiClient.logout()
		_busy = false
		%LoginButton.disabled = false
		%LoginButton.text = "Login"
		_show_error("This account cannot sign in.")


func _show_error(message: String) -> void:
	%ErrorLabel.text = message
	%ErrorLabel.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	# Keep the premium card chrome; only tint the border when invalid.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.14, 0.88)
	box.border_color = Color(UiTheme.COL_DANGER, 0.75) if message != "" else Color(UiTheme.COL_GOLD, 0.42)
	box.set_border_width_all(1)
	box.set_corner_radius_all(22)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 28
	box.shadow_offset = Vector2(0, 12)
	%Card.add_theme_stylebox_override("panel", box)
