extends SceneTree

## Headless regression test for the game-session lifecycle: repeated save → load (in the
## same run, and via the main menu) must not stack duplicate HUD order tickets, and
## leaving the game must shut the tutorial down.
##   godot --headless --path . --script res://tools/test_session.gd

## A private slot, so the test never touches the player's own saves.
const SLOT := "test_session"

var _failures: Array[String] = []
var _n := 0
var _sm: Node
var _ui: Node


func _initialize() -> void:
	process_frame.connect(_frame)


func _frame() -> void:
	_n += 1
	match _n:
		3:
			_sm = root.get_node("SaveManager")
			_ui = root.get_node("UI")
			_sm.new_game()
		30:
			_check(root.get_node("Tutorial")._layer != null, "new game offers the tutorial")
			root.get_node("Tutorial").abort()
			root.get_node("Orders").debug_add_random()
			_check(_tickets() == 1, "one order → one ticket")
			_check(_sm.save_to(SLOT, "session test"), "saved")
			_sm.load_from(SLOT)
		70:
			_check(_orders() == 1 and _tickets() == 1, "after a reload: still one ticket")
			_sm.load_from(SLOT)
		110:
			_check(_orders() == 1 and _tickets() == 1, "after a second reload: still one ticket")
			root.get_node("Tutorial").offer()
			_sm.to_menu()
		130:
			var tut: Node = root.get_node("Tutorial")
			_check(not tut.is_active() and not tut._layer.visible, "main menu: tutorial is shut down")
			_sm.load_from(SLOT)
		170:
			_check(_orders() == 1 and _tickets() == 1, "menu → load: still one ticket")
			_finish()


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves_tools/slot_%s.sav" % SLOT))
	if _failures.is_empty():
		print("test_session: ALL PASS")
		quit(0)
	else:
		print("test_session: %d FAILURE(S)" % _failures.size())
		quit(1)
