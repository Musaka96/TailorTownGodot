class_name RebindButton
extends Button

## A button that shows an action's current key and, when pressed, listens for the next
## key / mouse / pad press and rebinds the action to it (via the Settings autoload). Esc
## cancels. Self-contained so the Settings screen can just drop one per action.

var _action := ""
var _listening := false


func setup(action: String) -> void:
	_action = action
	custom_minimum_size = Vector2(120, 0)
	toggle_mode = false
	_refresh()
	pressed.connect(_begin)


func _begin() -> void:
	if _listening:
		return
	_listening = true
	text = "Press a key…"
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if event.is_action_pressed("ui_cancel"):
		_stop()
		get_viewport().set_input_as_handled()
		return
	var ok: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if not ok:
		return
	Settings.set_binding(_action, event)
	_stop()
	get_viewport().set_input_as_handled()


func _stop() -> void:
	_listening = false
	set_process_input(false)
	_refresh()


func _refresh() -> void:
	text = Settings.binding_text(_action)
