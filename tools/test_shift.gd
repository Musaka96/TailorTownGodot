extends SceneTree

## Headless smoke test for the shift / end-of-day flow: the shop starts open on day
## 1, closes when the bell rings (spawning the door prompt), and locking up plays the
## transition and rolls into day 2 with the shop open again.
##   godot --headless --path . --script res://tools/test_shift.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame

	var shift: Node = root.get_node("Shift")
	_check(shift.is_open(), "shop starts open")
	_check(shift.day == 1, "starts on day 1")
	_check(_find_door() == null, "no door prompt while open")

	# Ring the closing bell.
	root.get_node("EventBus").shift_ended.emit()
	await process_frame
	_check(not shift.is_open(), "shop closes when the shift ends")
	_check(_find_door() != null, "door 'lock up' prompt spawns at close")

	# Lock up at the door; the transition then rolls into the next day.
	shift.close_shop()
	await create_timer(4.0).timeout
	_check(shift.day == 2, "locking up advances to day 2")
	_check(shift.is_open(), "the new day opens the shop again")
	_check(_find_door() == null, "door prompt cleared for the new day")
	_check(not root.get_node("GameState").input_locked, "input unlocked after the transition")

	_finish()


func _find_door() -> Node:
	if current_scene == null:
		return null
	var shift: Node = root.get_node("Shift")
	for n in current_scene.find_children("*", "Interactable", true, false):
		if n.target == shift:
			return n
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_shift: ALL PASS")
		quit(0)
	else:
		print("test_shift: %d FAILURE(S)" % _failures.size())
		quit(1)
