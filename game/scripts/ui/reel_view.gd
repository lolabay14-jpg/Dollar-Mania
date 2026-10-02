class_name ReelView
extends PanelContainer

var _faces: Array[SymbolView] = []
var _box: VBoxContainer


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	for _index in 3:
		var face := SymbolView.new()
		face.custom_minimum_size = Vector2(78, 74)
		face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_child(face)
		_faces.append(face)


func set_face_size(face_size: Vector2) -> void:
	for face in _faces:
		face.custom_minimum_size = face_size


func show_column(symbol_ids: Array) -> void:
	for index in mini(3, symbol_ids.size()):
		_faces[index].set_symbol(str(symbol_ids[index]))
		_faces[index].set_winning(false)


func show_random(rules: Dictionary) -> void:
	var column: Array = []
	for _index in 3:
		column.append(SlotMachine.random_symbol(rules))
	show_column(column)


func highlight(winning_rows: Array) -> void:
	for index in _faces.size():
		_faces[index].set_winning(winning_rows.has(index))


func bounce() -> void:
	var tween := create_tween()
	tween.tween_method(_set_offset, 10.0, 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_offset(value: float) -> void:
	for face in _faces:
		face.set_nudge(value)
