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
	var day_night: Node = root.get_node("DayNight")
	var sign: Node = current_scene.find_child("DoorSign", true, false)
	_check(shift.is_open(), "a direct boot starts open")
	_check(shift.day == 1, "starts on day 1")
	_check(sign != null, "the door sign stands in the shop")
	if sign == null:
		_finish()
		return
	_check(
		"close early" in sign.get_interaction_prompt(null), "open: the sign offers closing early"
	)

	# Ring the closing bell.
	root.get_node("EventBus").shift_ended.emit()
	await process_frame
	_check(not shift.is_open() and shift.is_after_hours(), "shop closes when the shift ends")
	_check("finish day 1" in sign.get_interaction_prompt(null), "after hours: the sign locks up")

	# Flip the sign; the transition then dawns the next morning — shut until it's flipped.
	sign.interact(null)
	await create_timer(4.0).timeout
	_check(shift.day == 2, "locking up advances to day 2")
	_check(shift.phase == 0 and not shift.is_open(), "the new day dawns closed (morning)")
	_check(not day_night.running, "the clock waits for the sign")
	var paper: Control = root.get_node("UI").newspaper
	_check(not paper.visible, "the morning is the player's own — no paper at dawn")
	_check("open the shop" in sign.get_interaction_prompt(null), "morning: the sign opens the shop")

	sign.interact(null)
	await process_frame
	_check(shift.is_open() and day_night.running, "flipping the sign opens the shop")

	# The boy comes round a while into the day, not the moment the sign turns.
	_check(not paper.visible, "…and the paper is not waiting on the mat for it")
	day_night.start_shift(0.2)  # wind the morning on past the delivery round
	await create_timer(1.2).timeout
	_check(paper.visible, "the paper arrives once the shop has been open a while")
	paper.close()
	_check(not root.get_node("GameState").input_locked, "input unlocked once it's folded away")

	# Closing early asks first, then finishes the day on the second flip.
	sign.interact(null)
	await process_frame
	_check(shift.is_open() and shift.day == 2, "the first flip only asks")
	_check("Flip again" in sign.get_interaction_prompt(null), "and the prompt says to confirm")
	sign.interact(null)
	await create_timer(4.0).timeout
	paper.close()
	_check(shift.day == 3 and shift.phase == 0, "the second flip closes early: day 3 dawns")

	_finish()


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
