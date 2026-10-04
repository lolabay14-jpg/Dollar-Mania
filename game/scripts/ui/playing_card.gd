class_name PlayingCard
extends Control

var _rank := ""
var _suit := "hearts"
var _face_down := true
var _hot := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(124, 176)
	pivot_offset = custom_minimum_size * 0.5


func show_back() -> void:
	_face_down = true
	_hot = false
	queue_redraw()


func reveal_card(rank: String, suit: String) -> void:
	pivot_offset = custom_minimum_size * 0.5
	var close := create_tween()
	close.tween_property(self, "scale:x", 0.02, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close.finished
	if not is_inside_tree():
		return
	_rank = rank
	_suit = suit.to_lower()
	_face_down = false
	queue_redraw()
	var open := create_tween()
	open.tween_property(self, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await open.finished


func set_highlight(on: bool) -> void:
	_hot = on
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if rect.size.x < 16.0 or rect.size.y < 24.0:
		return
	var card := StyleBoxFlat.new()
	card.set_corner_radius_all(14)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 6)
	if _face_down:
		card.bg_color = Color("16325C")
		card.border_color = Color("F5C542")
		card.set_border_width_all(3)
		draw_style_box(card, rect)
		draw_rect(rect.grow(-14), Color("0E2244"), true)
		draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.22, 0, TAU, 24, Color("F5C542"), 4.0)
		return
	var red := _suit == "hearts" or _suit == "diamonds"
	card.bg_color = Color("F7F4EC")
	card.border_color = Color("3DDC97") if _hot else Color("D7CBB4")
	card.set_border_width_all(4 if _hot else 2)
	draw_style_box(card, rect)
	var ink := Color("C43848") if red else Color("1B2433")
	var font := ThemeDB.fallback_font
	var rank_size := clampi(int(rect.size.x * 0.28), 22, 36)
	draw_string(font, rect.position + Vector2(12, 14 + font.get_ascent(rank_size)), _rank, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, ink)
	_draw_suit(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.22, ink)
	_draw_suit(rect.position + Vector2(28, 58), 8.0, ink)


func _draw_suit(center: Vector2, radius: float, ink: Color) -> void:
	match _suit:
		"diamonds":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius * 0.72, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius * 0.72, 0),
			]), ink)
		"clubs":
			draw_circle(center + Vector2(-radius * 0.38, radius * 0.05), radius * 0.38, ink)
			draw_circle(center + Vector2(radius * 0.38, radius * 0.05), radius * 0.38, ink)
			draw_circle(center + Vector2(0, -radius * 0.32), radius * 0.38, ink)
			draw_rect(Rect2(center + Vector2(-radius * 0.12, radius * 0.1), Vector2(radius * 0.24, radius * 0.7)), ink)
		"spades":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, radius * 0.35),
				center + Vector2(0, radius * 0.15),
				center + Vector2(-radius, radius * 0.35),
			]), ink)
			draw_circle(center + Vector2(-radius * 0.28, radius * 0.28), radius * 0.28, ink)
			draw_circle(center + Vector2(radius * 0.28, radius * 0.28), radius * 0.28, ink)
			draw_rect(Rect2(center + Vector2(-radius * 0.1, radius * 0.2), Vector2(radius * 0.2, radius * 0.55)), ink)
		_:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, radius),
				center + Vector2(-radius, -radius * 0.15),
				center + Vector2(-radius * 0.25, -radius * 0.15),
				center + Vector2(0, -radius * 0.85),
				center + Vector2(radius * 0.25, -radius * 0.15),
				center + Vector2(radius, -radius * 0.15),
			]), ink)
