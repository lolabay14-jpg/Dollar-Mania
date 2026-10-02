extends CharacterBody2D

var play_bounds := Rect2(0, 0, 100, 100)
var radius := 18.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	input_pickable = false
	add_to_group("player")
	z_index = 2


func set_radius(value: float) -> void:
	radius = value
	var circle := CircleShape2D.new()
	circle.radius = radius
	$CollisionShape2D.shape = circle
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var direction := GameInput.get_move_vector()
	var span := maxf(play_bounds.size.x, play_bounds.size.y)
	velocity = direction * span * GameConfig.MOVE_SPEED_RATIO
	move_and_slide()
	var limit := play_bounds.grow(-radius)
	if limit.size.x > 0.0 and limit.size.y > 0.0:
		position.x = clampf(position.x, limit.position.x, limit.end.x)
		position.y = clampf(position.y, limit.position.y, limit.end.y)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color("12384A"))
	draw_circle(Vector2.ZERO, radius * 0.82, UiTheme.COL_GREEN)
	draw_circle(Vector2(radius * 0.28, -radius * 0.1), radius * 0.26, Color("F4F7FB"))
	draw_circle(Vector2(radius * 0.36, -radius * 0.16), radius * 0.1, Color("12384A"))
