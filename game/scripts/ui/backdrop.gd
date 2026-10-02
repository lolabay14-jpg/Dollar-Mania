extends Control

## Slow gold dust behind menus. Mouse clicks pass through.

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for index in 16:
		var phase := _time * 0.22 + float(index) * 0.7
		var x := (0.5 + sin(phase * 0.8) * 0.48) * size.x
		var y := (0.5 + cos(phase * 0.55 + float(index)) * 0.48) * size.y
		var radius := 16.0 + float(index % 4) * 12.0
		var tint := UiTheme.COL_GOLD
		tint.a = 0.035 + float(index % 3) * 0.018
		draw_circle(Vector2(x, y), radius, tint)
