extends Area2D

signal collected

var radius := 14.0
var _origin := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	input_pickable = false
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)


func setup(spawn_position: Vector2, body_radius: float) -> void:
	radius = body_radius
	position = spawn_position
	_origin = spawn_position
	var circle := CircleShape2D.new()
	circle.radius = radius
	$CollisionShape2D.shape = circle
	queue_redraw()


func keep_inside(bounds: Rect2) -> void:
	var limit := bounds.grow(-radius)
	if limit.size.x <= 0.0 or limit.size.y <= 0.0:
		return
	_origin.x = clampf(_origin.x, limit.position.x, limit.end.x)
	_origin.y = clampf(_origin.y, limit.position.y, limit.end.y)


func _process(delta: float) -> void:
	_time += delta
	position = _origin + Vector2(0.0, sin(_time * 3.0) * radius * 0.18)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, UiTheme.COL_GOLD)
	draw_circle(Vector2.ZERO, radius * 0.72, UiTheme.COL_GOLD_DARK)
	var font := ThemeDB.fallback_font
	var font_size := maxi(int(radius * 1.15), 10)
	var text := "$"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		UiTheme.COL_INK
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	collected.emit()
	queue_free()
