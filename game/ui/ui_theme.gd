class_name UiTheme
extends RefCounted

const COL_BG := Color("070B14")
const COL_CARD := Color("121A2C")
const COL_CARD_BORDER := Color("31425F")
const COL_GOLD := Color("F5C542")
const COL_GOLD_DARK := Color("C8962E")
const COL_GOLD_SOFT := Color("FFE38A")
const COL_INK := Color("141008")
const COL_TEXT := Color("F4F7FB")
const COL_MUTED := Color("9AA6BD")
const COL_GREEN := Color("3DDC97")
const COL_BLUE := Color("7EB6FF")
const COL_PURPLE := Color("8B7CFF")
const COL_DANGER := Color("FF8A9A")
const COL_DANGER_BG := Color("3A1E28")

static var _theme: Theme


static func apply(control: Control) -> void:
	control.theme = theme()


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func style_title(label: Label, size: int = 34) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COL_GOLD)


static func style_muted(label: Label) -> void:
	label.add_theme_color_override("font_color", COL_MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func game_accent(slug: String) -> Color:
	match slug:
		"golden-fortune":
			return COL_GOLD_SOFT
		"dollar-rush":
			return COL_GREEN
		"scratch-mania":
			return Color("D7C4A3")
		"lucky-spin":
			return Color("7DFFC3")
		"coin-flip":
			return COL_GOLD
		"treasure-box":
			return Color("E2B15C")
		"cash-match":
			return COL_BLUE
		"diamond-drop":
			return Color("8EE7FF")
		"bonus-burst":
			return Color("FFB45A")
		"jackpot-wheel":
			return Color("FFE38A")
		"higher-card":
			return Color("7EB6FF")
		"fruit-spin":
			return Color("3DDC97")
		"lucky-wheel":
			return COL_GOLD
		"prize-spinner":
			return Color("8B7CFF")
		"fishing":
			return Color("3EC6E0")
		"diamond-spin":
			return Color("8B7CFF")
		"mystery-box":
			return Color("E2B15C")
		"target-blast":
			return Color("FF7A59")
		"aeroplane-rush":
			return Color("7EB6FF")
		"bottle-blast":
			return Color("C9A6FF")
		"dice":
			return Color("E8EEF8")
		"lucky-number":
			return Color("7EB6FF")
		_:
			return COL_GOLD


static func paint_glass(panel: PanelContainer, invalid := false) -> void:
	var border := COL_DANGER if invalid else Color(COL_GOLD, 0.38)
	# Keep glass translucent so full-screen backgrounds remain visible.
	var box := _flat(Color(0.06, 0.09, 0.16, 0.72), border, 22, 1, 18, 16)
	box.shadow_color = Color(0, 0, 0, 0.32)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", box)


static func paint_card(panel: PanelContainer, accent: Color, hot := false) -> void:
	var border := accent if hot else Color(accent, 0.45)
	var box := _flat(Color(0.07, 0.1, 0.17, 0.92), border, 18, 2 if hot else 1, 0, 0)
	box.shadow_color = Color(accent, 0.32 if hot else 0.14)
	box.shadow_size = 18 if hot else 8
	box.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", box)


static func mood(root: Node, mood_name: String, tint: Color = COL_GOLD) -> void:
	var dust := root.get_node_or_null("Dust")
	if dust and dust.has_method("set_mood"):
		dust.set_mood(mood_name, tint)


static func _build() -> Theme:
	var built := Theme.new()
	built.default_font_size = 18

	var card := _flat(COL_CARD, Color(COL_GOLD, 0.22), 18, 1, 16, 14)
	card.shadow_color = Color(0, 0, 0, 0.32)
	card.shadow_size = 12
	card.shadow_offset = Vector2(0, 6)
	var button := _flat(Color("1B2740"), COL_CARD_BORDER, 14, 1, 16, 16)
	var button_hover := _flat(Color("243352"), COL_GOLD_DARK, 14, 1, 16, 16)
	var button_pressed := _flat(Color("121A2C"), COL_GOLD, 14, 1, 16, 16)
	var primary := _flat(COL_GOLD, COL_GOLD_SOFT, 14, 1, 16, 16)
	primary.shadow_color = Color(COL_GOLD, 0.28)
	primary.shadow_size = 10
	var primary_hover := _flat(COL_GOLD_SOFT, COL_GOLD_SOFT, 14, 1, 16, 16)
	var primary_pressed := _flat(COL_GOLD_DARK, COL_GOLD_DARK, 14, 1, 16, 16)
	var danger := _flat(COL_DANGER_BG, Color("6E3140"), 12, 1, 16, 16)
	var danger_hover := _flat(Color("4C2632"), COL_DANGER, 12, 1, 16, 16)
	var selected := _flat(Color("2A2412"), COL_GOLD, 12, 2, 16, 16)
	var field := _flat(Color("0E1626"), COL_CARD_BORDER, 12, 1, 14, 16)
	var empty := StyleBoxEmpty.new()

	built.set_color("font_color", "Label", COL_TEXT)
	built.set_stylebox("panel", "PanelContainer", card)

	_set_button(built, "Button", button, button_hover, button_pressed, COL_TEXT, COL_TEXT)
	built.set_type_variation("PrimaryButton", "Button")
	_set_button(built, "PrimaryButton", primary, primary_hover, primary_pressed, COL_INK, COL_INK)
	built.set_type_variation("DangerButton", "Button")
	_set_button(built, "DangerButton", danger, danger_hover, danger, COL_DANGER, COL_TEXT)
	built.set_type_variation("SelectedButton", "Button")
	_set_button(built, "SelectedButton", selected, selected, selected, COL_GOLD, COL_GOLD)
	var link := StyleBoxEmpty.new()
	link.content_margin_left = 8
	link.content_margin_right = 8
	link.content_margin_top = 8
	link.content_margin_bottom = 8
	built.set_type_variation("TextLink", "Button")
	_set_button(built, "TextLink", link, link, link, COL_GOLD_SOFT, COL_GOLD)

	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		built.set_stylebox(style_name, "CheckBox", empty)
	built.set_color("font_color", "CheckBox", COL_TEXT)
	built.set_color("font_hover_color", "CheckBox", COL_GOLD)
	built.set_color("font_pressed_color", "CheckBox", COL_GOLD)

	built.set_font_size("font_size", "Button", 18)
	built.set_font_size("font_size", "LineEdit", 18)
	built.set_font_size("font_size", "CheckBox", 18)
	built.set_stylebox("normal", "LineEdit", field)
	built.set_stylebox("focus", "LineEdit", _flat(Color("0E1626"), COL_GOLD, 12, 2, 14, 16))
	built.set_stylebox("read_only", "LineEdit", field)
	built.set_color("font_color", "LineEdit", COL_TEXT)
	built.set_color("font_placeholder_color", "LineEdit", COL_MUTED)
	built.set_color("caret_color", "LineEdit", COL_GOLD)
	built.set_color("font_selected_color", "LineEdit", COL_INK)
	built.set_color("selection_color", "LineEdit", COL_GOLD)

	built.set_constant("separation", "VBoxContainer", 12)
	built.set_constant("separation", "HBoxContainer", 10)
	return built


static func _set_button(
	built: Theme,
	type_name: String,
	normal: StyleBox,
	hover: StyleBox,
	pressed: StyleBox,
	font_color: Color,
	pressed_color: Color
) -> void:
	built.set_stylebox("normal", type_name, normal)
	built.set_stylebox("hover", type_name, hover)
	built.set_stylebox("pressed", type_name, pressed)
	built.set_stylebox("focus", type_name, hover)
	built.set_stylebox("disabled", type_name, _flat(Color("1A2233"), Color("2A3348"), 12, 1, 16, 16))
	built.set_color("font_color", type_name, font_color)
	built.set_color("font_hover_color", type_name, pressed_color)
	built.set_color("font_pressed_color", type_name, pressed_color)
	built.set_color("font_focus_color", type_name, pressed_color)
	built.set_color("font_disabled_color", type_name, COL_MUTED)


static func _flat(
	bg: Color,
	border: Color,
	radius: int,
	border_width: int,
	margin_x: int,
	margin_y: int
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box
