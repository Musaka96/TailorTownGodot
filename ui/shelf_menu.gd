extends Control

## Scrollable list of the rolls on a shelf. Shows each roll's name, how much
## cloth is left, and its fabric/pattern. Scroll with W/S or ↑/↓, take with E,
## close with Esc. Locks gameplay input while open.

var _shelf = null
var _actor = null
var _index := 0

@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _list: VBoxContainer = $Panel/Margin/Box/List


func open(shelf, actor) -> void:
	_shelf = shelf
	_actor = actor
	_index = 0
	GameState.input_locked = true
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_shelf = null


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	var rolls: Array = _shelf.stored
	for i in rolls.size():
		var roll = rolls[i]
		var mat = roll.material
		var selected := i == _index
		var row := Label.new()
		row.text = "%s %s   —   %.1f / %.1f m   ·   %s" % [
			(">" if selected else "  "),
			mat.display_name,
			roll.remaining_length_m, mat.roll_length_m,
			mat.summary(),
		]
		row.modulate = Color(1, 1, 1) if selected else Color(0.7, 0.7, 0.72)
		_list.add_child(row)

	_title.text = "SHELF — %d rolls    ( W/S scroll · E take · Esc close )" % rolls.size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_move(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_move(-1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_take()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(delta: int) -> void:
	var n: int = _shelf.stored.size()
	if n == 0:
		return
	_index = (_index + delta + n) % n
	_rebuild()


func _take() -> void:
	if _shelf.stored.size() == 0:
		close()
		return
	_shelf.take(_index, _actor)
	if _shelf.stored.size() == 0:
		close()
	else:
		_index = min(_index, _shelf.stored.size() - 1)
		_rebuild()
