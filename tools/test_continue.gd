extends SceneTree

## Headless test for "Continue puts me back where I was". The playtest: on day 3 mid-day,
## out to the main menu, Continue — and it was the middle of day 2 (nothing had saved on
## day 3, and the newest save was an early-close "end of day 2" holding a mid-day clock).
## Now the game autosaves on leaving and at every dawn, and a save remembers which part
## of the day it was made in:
##   - leaving mid-day on day 3 and Continuing lands mid-day on day 3;
##   - a save made after the bell comes back after hours (clock stopped, shop shut);
##   - each new morning writes the autosave, so Continue never goes back a day;
##   - the autosave shows in the load lists.
##   godot --headless --path . --script res://tools/test_continue.gd

const PATIENCE_MS := 12000
const OPEN := 1  # Shift.Phase.OPEN
const AFTER_HOURS := 2  # Shift.Phase.AFTER_HOURS
const MORNING := 0  # Shift.Phase.MORNING

var _failures: Array[String] = []
var _sm: Node
var _shift: Node
var _clock: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_sm = root.get_node("SaveManager")
	_shift = root.get_node("Shift")
	_clock = root.get_node("DayNight")
	change_scene_to_file("res://scenes/world/grandpa/main_grandpa.tscn")
	await _until(func() -> bool: return get_first_node_in_group("player") != null)
	for _i in 10:
		await process_frame
	_check(_sm.can_save(), "(setup) grandpa's shop can be saved")

	# Day 3, mid-shift: leave for the main menu, then Continue.
	_shift.day = 3
	_clock.start_shift(0.45)
	await process_frame
	_sm.to_menu()
	await _through_curtain()
	_check(str(_sm.latest_slot()) == "auto", "leaving writes the autosave, and it's the newest")
	_check(int(_sm.info("auto").get("day", 0)) == 3, "the autosave is day 3")
	_sm.load_from(_sm.latest_slot())
	await _through_curtain()
	_check(_shift.day == 3, "Continue: back on day 3 (was day 2 in the playtest)")
	_check(_shift.phase == OPEN and _clock.running, "the shop is open and the clock runs")
	_check(absf(_clock.progress() - 0.45) < 0.05, "at the time it was left")

	# The bell rings: the end-of-day autosave comes back after hours, not mid-shift.
	_clock.running = false
	root.get_node("EventBus").shift_ended.emit()
	await process_frame
	_sm.load_from("auto")
	await _through_curtain()
	_check(_shift.day == 3 and _shift.phase == AFTER_HOURS, "after the bell: back after hours")
	_check(not _clock.running and not _shift.is_open(), "the clock is stopped and the shop shut")

	# Finish the day: the new morning autosaves at once.
	_shift.close_shop()
	await _until(func() -> bool: return _shift.day == 4)
	for _i in 5:
		await process_frame
	var auto: Dictionary = _sm.info("auto")
	_check(int(auto.get("day", 0)) == 4, "the next morning writes the autosave")
	var loads: Array = _sm.load_infos()
	var listed := loads.any(func(i: Dictionary) -> bool: return str(i.get("slot")) == "auto")
	_check(listed, "the autosave is in the load list")
	_finish()


func _through_curtain() -> void:
	await _until(func() -> bool: return _curtain_up())
	await _until(func() -> bool: return not _curtain_up())
	for _i in 5:
		await process_frame


func _curtain_up() -> bool:
	for child in _sm.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible:
			return true
	return false


func _until(done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + PATIENCE_MS
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_continue: ALL PASS")
		quit(0)
	else:
		print("test_continue: %d FAILURE(S)" % _failures.size())
		quit(1)
