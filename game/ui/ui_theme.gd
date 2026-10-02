class_name UiTheme
extends RefCounted

const COL_BG := Color("0B1220")
const COL_CARD := Color("162033")
const COL_CARD_BORDER := Color("2C3C58")
const COL_GOLD := Color("F5C542")
const COL_GOLD_DARK := Color("C8962E")
const COL_GOLD_SOFT := Color("FFE38A")
const COL_INK := Color("141008")
const COL_TEXT := Color("F4F7FB")
const COL_MUTED := Color("9AA6BD")
const COL_GREEN := Color("3DDC97")
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


static func _build() -> Theme:
	var built := Theme.new()
	built.default_font_size = 17

	var card := _flat(COL_CARD, COL_CARD_BORDER, 16, 1, 16, 14)
	var button := _flat(Color("1B2740"), COL_CARD_BORDER, 12, 1, 14, 12)
	var button_hover := _flat(Color("243352"), COL_GOLD_DARK, 12, 1, 14, 12)
	var button_pressed := _flat(Color("121A2C"), COL_GOLD, 12, 1, 14, 12)
	var primary := _flat(COL_GOLD, COL_GOLD, 12, 1, 14, 12)
	var primary_hover := _flat(COL_GOLD_SOFT, COL_GOLD_SOFT, 12, 1, 14, 12)
	var primary_pressed := _flat(COL_GOLD_DARK, COL_GOLD_DARK, 12, 1, 14, 12)
	var danger := _flat(COL_DANGER_BG, Color("6E3140"), 12, 1, 14, 12)
	var danger_hover := _flat(Color("4C2632"), COL_DANGER, 12, 1, 14, 12)
	var selected := _flat(Color("2A2412"), COL_GOLD, 12, 2, 14, 12)
	var field := _flat(Color("0E1626"), COL_CARD_BORDER, 12, 1, 12, 12)
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

	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		built.set_stylebox(style_name, "CheckBox", empty)
	built.set_color("font_color", "CheckBox", COL_TEXT)
	built.set_color("font_hover_color", "CheckBox", COL_GOLD)
	built.set_color("font_pressed_color", "CheckBox", COL_GOLD)

	built.set_stylebox("normal", "LineEdit", field)
	built.set_stylebox("focus", "LineEdit", _flat(Color("0E1626"), COL_GOLD, 12, 2, 12, 12))
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
	built.set_stylebox("disabled", type_name, _flat(Color("1A2233"), Color("2A3348"), 12, 1, 14, 12))
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
