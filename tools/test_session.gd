extends SceneTree

## Headless regression test for the game-session lifecycle: repeated save → load (in the
## same run, and via the main menu) must not stack duplicate HUD order tickets, and
## leaving the game must shut the tutorial down.
##   godot --headless --path . --script res://tools/test_session.gd
##
## Every scene change goes through the LoadingCurtain now — it falls, the scene swaps behind
## it, the shop settles, and it opens — so each step waits for that to play out rather than
## for a fixed number of frames.

## A private slot, so the test never touches the player's own saves.
const SLOT := "test_session"
## Longest any one wait may take before the test gives up on it.
const PATIENCE_MS := 10000

var _failures: Array[String] = []
var _sm: Node
var _ui: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_sm = root.get_node("SaveManager")
	_ui = root.get_node("UI")
	var tut: Node = root.get_node("Tutorial")

	_sm.new_game()
	await _until(func() -> bool: return tut._layer != null)
	_check(tut._layer != null, "new game offers the tutorial")
	tut.abort()
	root.get_node("Orders").debug_add_random()
	_check(_tickets() == 1, "one order → one ticket")
	_check(_sm.save_to(SLOT, "session test"), "saved")

	_sm.load_from(SLOT)
	await _through_curtain()
	_check(_orders() == 1 and _tickets() == 1, "after a reload: still one ticket")
	_sm.load_from(SLOT)
	await _through_curtain()
	_check(_orders() == 1 and _tickets() == 1, "after a second reload: still one ticket")

	tut.offer()
	_sm.to_menu()
	await _through_curtain()
	_check(not tut.is_active() and not tut._layer.visible, "main menu: tutorial is shut down")
	_sm.load_from(SLOT)
	await _through_curtain()
	_check(_orders() == 1 and _tickets() == 1, "menu → load: still one ticket")
	_finish()


## Wait out one scene change: the curtain comes down, the scene swaps behind it, and it
## goes back up.
func _through_curtain() -> void:
	await _until(func() -> bool: return _curtain_up())
	await _until(func() -> bool: return not _curtain_up())


func _curtain_up() -> bool:
	for child in _sm.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible:
			return true
	return false


## Wait until `done` holds, or give up after PATIENCE_MS (the check that follows then fails).
func _until(done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + PATIENCE_MS
	while not done.call() and Time.get_ticks_msec() < deadline:
		await process_frame


func _orders() -> int:
	return root.get_node("Orders").active.size()


func _tickets() -> int:
	return _ui.hud.get_node("OrdersPanel/Tickets").get_child_count()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://saves_tools/slot_%s.sav" % SLOT)
	)
	if _failures.is_empty():
		print("test_session: ALL PASS")
		quit(0)
	else:
		print("test_session: %d FAILURE(S)" % _failures.size())
		quit(1)
