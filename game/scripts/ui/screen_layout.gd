class_name ScreenLayout
extends RefCounted

## One layout size for desktop, web, and phones.
## Phones are measured in density-independent pixels so controls stay
## finger-sized. Desktop keeps the existing comfortable window size.

const MIN_DESIGN_SHORT := 360.0
const MAX_DESIGN_SHORT := 800.0

static var _installed := false
static var _applying := false


static func install() -> void:
	apply()
	if _installed:
		return
	_installed = true
	var window := _window()
	if window and not window.size_changed.is_connected(apply):
		window.size_changed.connect(apply)


static func apply() -> void:
	if _applying or DisplayServer.get_name() == "headless":
		return
	_applying = true
	_apply_scale()
	_applying = false


static func design_size(window_px: Vector2, dpi: float, os_scale: float, mobile: bool) -> Vector2i:
	var size := Vector2(maxf(window_px.x, 1.0), maxf(window_px.y, 1.0))
	var short_px := minf(size.x, size.y)
	var safe_dpi := dpi if dpi >= 48.0 else (160.0 if mobile else 96.0)
	var short_inches := short_px / safe_dpi
	var handheld := mobile or (safe_dpi >= 200.0 and short_inches <= 5.6)
	var design_short: float
	if handheld:
		var density := safe_dpi / 160.0
		var logical_short := short_px / maxf(density, 0.5)
		if logical_short > 560.0 and short_px >= 900.0 and density < 1.35:
			logical_short = 448.0 if short_px < 1700.0 else 640.0
		design_short = clampf(logical_short, 320.0, 640.0)
	else:
		var logical := size / maxf(os_scale, 1.0)
		design_short = clampf(minf(logical.x, logical.y), MIN_DESIGN_SHORT, MAX_DESIGN_SHORT)
	var aspect := maxf(size.x, size.y) / short_px
	var design := Vector2(design_short, design_short * aspect)
	if size.x >= size.y:
		design = Vector2(design_short * aspect, design_short)
	return Vector2i(maxi(int(round(design.x)), 1), maxi(int(round(design.y)), 1))


static func fit_column(column: MarginContainer, max_width: float) -> void:
	var view := column.get_viewport_rect().size
	if view.x < 8.0 or view.y < 8.0:
		view = column.get_parent_control().size if column.get_parent_control() else view
	var inset := safe_insets()
	var gutter := 12.0 if view.x < 520.0 else 16.0
	var side := maxf((view.x - max_width) * 0.5, gutter)
	column.custom_minimum_size.x = view.x
	var used_top := column.get_theme_constant("margin_top")
	var used_bottom := column.get_theme_constant("margin_bottom")
	var content_height := maxf(column.get_combined_minimum_size().y - float(used_top + used_bottom), 0.0)
	var centered := maxf((view.y - content_height) * 0.5, 18.0)
	var top := 12.0 if view.x < 520.0 and content_height + 24.0 > view.y else centered
	column.add_theme_constant_override("margin_left", int(maxf(side, inset.x + 8.0)))
	column.add_theme_constant_override("margin_right", int(maxf(side, inset.z + 8.0)))
	column.add_theme_constant_override("margin_top", int(maxf(top, inset.y + 8.0)))
	column.add_theme_constant_override("margin_bottom", int(maxf(20.0, inset.w + 12.0)))


static func edge_margins(view: Vector2) -> Vector4:
	var inset := safe_insets()
	var gutter := 12.0 if view.x < 520.0 else 16.0
	return Vector4(
		maxf(gutter, inset.x + 8.0),
		maxf(12.0, inset.y + 8.0),
		maxf(gutter, inset.z + 8.0),
		maxf(18.0, inset.w + 10.0)
	)


static func safe_insets() -> Vector4:
	var window := _window()
	var win := Vector2(DisplayServer.window_get_size())
	if window == null or win.x < 8.0 or win.y < 8.0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x < 8 or safe.size.y < 8:
		return Vector4.ZERO
	var view := window.get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return Vector4.ZERO
	var scale := Vector2(view.x / win.x, view.y / win.y)
	return Vector4(
		maxf(safe.position.x, 0) * scale.x,
		maxf(safe.position.y, 0) * scale.y,
		maxf(win.x - safe.end.x, 0.0) * scale.x,
		maxf(win.y - safe.end.y, 0.0) * scale.y
	)


static func _apply_scale() -> void:
	var window := _window()
	if window == null:
		return
	var size := Vector2(DisplayServer.window_get_size())
	if size.x < 8.0 or size.y < 8.0:
		return
	var design := design_size(size, float(DisplayServer.screen_get_dpi()), float(DisplayServer.screen_get_scale()), OS.has_feature("mobile"))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = 1.0
	window.content_scale_size = design


static func _window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root
