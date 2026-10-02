class_name ReelView
extends Control

var face_size := Vector2(92, 88)
var _gap := 8
var _faces: Array[SymbolView] = []
var _ids: Array[String] = ["coin", "dollar", "star", "seven"]
var _offset := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index in 4:
		var face := SymbolView.new()
		add_child(face)
		_faces.append(face)
	set_face_size(face_size)


func set_face_size(next_size: Vector2) -> void:
	face_size = next_size
	custom_minimum_size = Vector2(face_size.x, face_size.y * 3.0 + _gap * 2.0)
	for face in _faces:
		face.custom_minimum_size = face_size
		face.size = face_size
	_place()


func show_column(symbol_ids: Array) -> void:
	_offset = 0.0
	_ids = ["coin"]
	for symbol_id in symbol_ids:
		_ids.append(str(symbol_id))
	while _ids.size() < 4:
		_ids.append("star")
	_ids = _ids.slice(0, 4)
	for face in _faces:
		face.set_winning(false)
	_place()


func show_random(rules: Dictionary) -> void:
	advance(face_size.y + _gap, rules)


func advance(distance: float, rules: Dictionary) -> void:
	_offset += distance
	var step := face_size.y + _gap
	while _offset >= step:
		_offset -= step
		_ids.pop_back()
		_ids.push_front(str(SlotMachine.random_symbol(rules)))
	_place()


func land(symbol_ids: Array) -> void:
	var incoming := _ids[0] if not _ids.is_empty() else "coin"
	_ids = [incoming]
	for symbol_id in symbol_ids:
		_ids.append(str(symbol_id))
	while _ids.size() < 4:
		_ids.append("star")
	_ids = _ids.slice(0, 4)
	var tween := create_tween()
	tween.tween_method(_apply_offset, _offset, 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func highlight(winning_rows: Array) -> void:
	for index in _faces.size():
		_faces[index].set_winning(winning_rows.has(index - 1))


func _apply_offset(value: float) -> void:
	_offset = value
	_place()


func _place() -> void:
	var step := face_size.y + _gap
	for index in _faces.size():
		var face := _faces[index]
		if index < _ids.size():
			face.set_symbol(_ids[index])
		face.position = Vector2(0, float(index - 1) * step + _offset)
		face.size = face_size
