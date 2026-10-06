class_name GameBanner
extends Control

## Painted banner for an existing Dollar Mania game.
## Art is drawn from the game slug and category so it stays sharp on phones.

var _slug := ""
var _category := ""
var _accent := Color("F5C542")
var _symbol: SymbolView
var _art: TextureRect
var _cast: Array[SymbolView] = []

const _SYMBOLS := {
	"lucky-dollar": "dollar",
	"golden-fortune": "star",
	"dollar-rush": "bonus",
	"scratch-mania": "coin",
	"lucky-spin": "seven",
	"coin-flip": "dollar",
	"treasure-box": "diamond",
	"cash-match": "star",
	"diamond-drop": "diamond",
	"bonus-burst": "bonus",
	"jackpot-wheel": "seven",
	"higher-card": "diamond",
	"fruit-spin": "cherry",
	"lucky-wheel": "star",
	"prize-spinner": "diamond",
	"fishing": "blue",
	"diamond-spin": "diamond",
	"mystery-box": "gold",
	"target-blast": "star",
	"aeroplane-rush": "bonus",
	"bottle-blast": "seven",
	"dice": "star",
	"lucky-number": "seven",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if custom_minimum_size.y < 8.0:
		custom_minimum_size = Vector2(0, 156)
	_ensure_hero()
	resized.connect(_on_resized)
	_rebuild_cast()
	_place_symbol()


func set_game(slug: String, category: String, accent: Color) -> void:
	_slug = slug
	_category = category.to_upper()
	_accent = accent
	_ensure_hero()
	_ensure_art()
	var photo := GameArt.banner(slug)
	_art.texture = photo
	_art.visible = photo != null
	_fit_photo()
	_symbol.visible = photo == null and _category != "CARDS"
	if photo != null:
		for view in _cast:
			view.visible = false
	else:
		_symbol.set_symbol(str(_SYMBOLS.get(slug, "coin")))
		_rebuild_cast()
	queue_redraw()


func _ensure_art() -> void:
	if _art != null:
		return
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 0
	_art.offset_top = 0
	_art.offset_right = 0
	_art.offset_bottom = 0
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	move_child(_art, 0)


func _ensure_hero() -> void:
	if _symbol != null:
		return
	_symbol = SymbolView.new()
	_symbol.custom_minimum_size = Vector2(84, 84)
	_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_symbol)


func _cast_ids() -> PackedStringArray:
	match _slug:
		"fruit-spin", "lucky-spin", "jackpot-wheel":
			return PackedStringArray(["cherry", "lemon", "orange", "melon", "grapes", "seven"])
		"lucky-wheel":
			return PackedStringArray(["coin", "star", "diamond", "seven", "dollar"])
		"prize-spinner":
			return PackedStringArray(["star", "diamond", "seven", "bonus"])
		"fishing":
			return PackedStringArray(["blue", "jade", "gold", "diamond"])
		"diamond-spin":
			return PackedStringArray(["diamond", "ruby", "jade", "gold"])
		"mystery-box":
			return PackedStringArray(["gold", "diamond", "star"])
		"target-blast":
			return PackedStringArray(["star", "seven", "bonus"])
		"dice":
			return PackedStringArray(["star", "coin", "diamond"])
		"lucky-number":
			return PackedStringArray(["seven", "star", "coin"])
		"lucky-dollar", "golden-fortune":
			return PackedStringArray(["coin", "dollar", "star", "diamond", "seven"])
		"scratch-mania":
			return PackedStringArray(["coin", "star", "diamond", "seven"])
		"coin-flip":
			return PackedStringArray(["dollar"])
		"higher-card":
			return PackedStringArray()
		"cash-match", "diamond-drop":
			return PackedStringArray(["star", "diamond", "seven", "coin"])
		"treasure-box":
			return PackedStringArray(["diamond", "gold", "star"])
		"bonus-burst":
			return PackedStringArray(["bonus", "star", "coin"])
		"dollar-rush":
			return PackedStringArray(["bonus", "star", "coin"])
		_:
			return PackedStringArray(["coin", "star", "diamond"])


func _rebuild_cast() -> void:
	for view in _cast:
		if is_instance_valid(view):
			view.queue_free()
	_cast.clear()
	if not is_inside_tree():
		return
	var span := 48.0 if custom_minimum_size.y < 190.0 else 58.0
	for symbol_id in _cast_ids():
		var view := SymbolView.new()
		view.custom_minimum_size = Vector2(span, span)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_symbol(symbol_id)
		add_child(view)
		_cast.append(view)
	_place_symbol()


func set_banner_height(height: float) -> void:
	if _art == null or not _art.visible:
		custom_minimum_size = Vector2(0, height)
	queue_redraw()


func _on_resized() -> void:
	_fit_photo()
	_place_symbol()


func _fit_photo() -> void:
	if _art == null or _art.texture == null or not _art.visible:
		return
	var tex_size := _art.texture.get_size()
	if tex_size.x < 1.0 or tex_size.y < 1.0:
		return
	var width := size.x
	if width < 32.0:
		return
	var height := width * tex_size.y / tex_size.x
	custom_minimum_size = Vector2(0, clampf(height, 168.0, 280.0))


func _place_symbol() -> void:
	if _symbol == null:
		return
	var photo := _art != null and _art.visible
	_symbol.visible = not photo and _category != "CARDS"
	var hero := 96.0 if custom_minimum_size.y >= 190.0 else 84.0
	_symbol.custom_minimum_size = Vector2(hero, hero)
	_symbol.position = Vector2(maxf(size.x - hero - 18.0, 12.0), maxf((size.y - hero) * 0.5, 8.0))
	var span := 48.0 if custom_minimum_size.y < 190.0 else 58.0
	var x := 16.0
	var y := maxf((size.y - span) * 0.5, 10.0)
	var limit := maxf(_symbol.position.x - 12.0, x)
	for view in _cast:
		if x + span > limit:
			view.visible = false
			continue
		view.visible = not photo and x + span <= limit
		view.position = Vector2(x, y)
		x += span + 8.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	if _art != null and _art.visible and _art.texture != null:
		draw_rect(rect, Color("10182C"), true)
		return
	draw_rect(rect, Color("10182C"), true)
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(_accent, 0.28)
	wash.border_color = Color(_accent, 0.45)
	wash.set_border_width_all(0)
	wash.set_corner_radius_all(0)
	draw_style_box(wash, rect)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.42)), Color(1, 1, 1, 0.04), true)
	draw_circle(Vector2(rect.size.x * 0.2, rect.size.y * 0.7), rect.size.y * 0.62, Color(_accent, 0.16))
	if _category == "CARDS" or _cast.is_empty():
		_draw_motif(rect)


func _draw_motif(rect: Rect2) -> void:
	var ink := Color(_accent, 0.55)
	var origin := rect.position + Vector2(28, rect.size.y * 0.5)
	match _category:
		"SCRATCH":
			var ticket := Rect2(origin + Vector2(0, -28), Vector2(108, 56))
			draw_rect(ticket, Color(_accent, 0.18), true)
			draw_line(ticket.position + Vector2(8, 28), ticket.end + Vector2(-8, -28), ink, 2.0)
		"SPIN":
			draw_arc(origin + Vector2(36, 0), 30.0, 0, TAU, 24, ink, 3.0)
			draw_line(origin + Vector2(36, 0), origin + Vector2(36, -26), ink, 3.0)
		"MATCH":
			draw_rect(Rect2(origin, Vector2(34, 46)), Color(_accent, 0.2), true)
			draw_rect(Rect2(origin + Vector2(22, -8), Vector2(34, 46)), Color(_accent, 0.28), true)
		"REACTION":
			for lane in 3:
				draw_line(origin + Vector2(0, lane * 16 - 16), origin + Vector2(92, lane * 16 - 16), ink, 3.0)
		"BONUS":
			draw_circle(origin + Vector2(36, 0), 18.0, Color(_accent, 0.35))
			draw_circle(origin + Vector2(36, 0), 30.0, Color(_accent, 0.2))
		"CARDS":
			var back := Rect2(origin + Vector2(8, -46), Vector2(64, 92))
			var face := Rect2(origin + Vector2(36, -36), Vector2(64, 92))
			draw_rect(back, Color("1B2740"), true)
			var pattern := Color("7EB6FF")
			pattern.a = 0.35
			draw_rect(back.grow(-6.0), pattern, true)
			draw_rect(face, Color("F4F7FB"), true)
			draw_circle(face.get_center(), 10.0, Color("E23B45"))
			draw_line(face.position + Vector2(10, 16), face.position + Vector2(22, 16), Color("E23B45"), 2.0)
		"CHOICE":
			if _slug == "coin-flip":
				draw_circle(origin + Vector2(34, 0), 26.0, Color(_accent, 0.28))
				draw_arc(origin + Vector2(34, 0), 26.0, 0, TAU, 24, ink, 2.0)
			else:
				draw_rect(Rect2(origin + Vector2(8, -24), Vector2(52, 48)), Color(_accent, 0.24), true)
		_:
			for reel in 3:
				var reel_rect := Rect2(origin + Vector2(reel * 28, -30), Vector2(22, 60))
				draw_rect(reel_rect, Color(_accent, 0.2), true)
				draw_line(reel_rect.position + Vector2(0, 30), reel_rect.position + Vector2(22, 30), ink, 2.0)
