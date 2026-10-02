class_name ScreenLayout
extends RefCounted

## Keeps one Godot project readable on desktop, web, and phones.
## The layout size follows the window's logical short side so tap targets
## stay large on high-density screens and comfortable on a monitor.

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


static func _apply_scale() -> void:
	var window := _window()
	if window == null:
		return
	var size := Vector2(DisplayServer.window_get_size())
	if size.x < 8.0 or size.y < 8.0:
		return
	var os_scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	var logical := size / os_scale
	var design_short := clampf(minf(logical.x, logical.y), MIN_DESIGN_SHORT, MAX_DESIGN_SHORT)
	var design := Vector2.ZERO
	if size.x >= size.y:
		design = Vector2(design_short * (size.x / size.y), design_short)
	else:
		design = Vector2(design_short, design_short * (size.y / size.x))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(maxi(int(design.x), 1), maxi(int(design.y), 1))


static func fit_column(column: MarginContainer, max_width: float) -> void:
	var view := column.get_viewport_rect().size
	var side := maxf((view.x - max_width) * 0.5, 16.0)
	column.custom_minimum_size.x = view.x
	var used_top := column.get_theme_constant("margin_top")
	var used_bottom := column.get_theme_constant("margin_bottom")
	var content_height := maxf(column.get_combined_minimum_size().y - float(used_top + used_bottom), 0.0)
	var top := maxf((view.y - content_height) * 0.5, 18.0)
	column.add_theme_constant_override("margin_left", int(side))
	column.add_theme_constant_override("margin_right", int(side))
	column.add_theme_constant_override("margin_top", int(top))
	column.add_theme_constant_override("margin_bottom", 24)


static func _window() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root
