extends SceneTree

## Headless test: every bench game can be walked away from mid-run. For each host (the
## worktable's cut, the sewing machine's seam, the pressing and coffee bench) it starts
## the game on a real station, sends one of the leave inputs through the viewport, and
## checks the host closed, input is unlocked, the pause menu did not open, the job is as
## it was before the game started and the game never reported `finished`. Also checks the
## worktable's config step still closes on Esc, and the "customer waiting" hint line.
##   godot --headless --path . --script res://tools/test_bench_leave.gd

const JACKET := 2
const RUN_FRAMES := 10  # let a game run a moment before leaving it

var _failures: Array[String] = []
var _finished := 0
## Loaded in _run(), not here: their scripts need the autoloads, which a member
## initializer of a top-level --script runs ahead of.
var _factory: GDScript
var _coffee_scene: PackedScene


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	_factory = load("res://data/scripts/material_factory.gd")
	_coffee_scene = load("res://stations/coffee_machine/coffee_machine.tscn")
	var ui: Node = root.get_node("UI")
	await _test_worktable(ui)
	await _test_sewing(ui)
	await _test_press(ui)
	await _test_coffee(ui)
	await _test_guest_cup(ui)
	_test_hint(ui)
	_test_control()
	_finish()


# --- Hosts -------------------------------------------------------------------


func _test_worktable(ui: Node) -> void:
	var state := root.get_node("GameState")
	var wt: Node3D = load("res://stations/worktable/worktable.tscn").instantiate()
	root.add_child(wt)
	var cloth: Node3D = load("res://entities/items/fabric_piece.tscn").instantiate()
	cloth.material = _factory.make(1, 0, 0, 3.0)
	cloth.length_m = 3.0
	wt.get_node("Slot").add_child(cloth)
	wt.set("_item", cloth)
	var screen: Control = ui.worktable_screen

	# The config step: Esc closes it, as it always has.
	screen.open(wt, null, cloth)
	await process_frame
	_key(KEY_ESCAPE)
	_check(not screen.visible, "worktable: Esc on the config step still closes it")
	_check(not state.input_locked and not state.is_paused, "worktable: …unlocked, not paused")
	_check(wt.held_item() == cloth, "worktable: …with the cloth left on the table")

	# Mid-cut: Esc leaves the bench.
	state.focus = 2
	screen.open(wt, null, cloth)
	screen.call("_start_cutting")
	var game: Control = screen.get("_minigame")
	_check(game != null and game.visible, "worktable: the cut is up")
	var hint: Label = screen.get("_leave_hint")
	_check(hint.is_visible_in_tree(), "worktable: the leave hint shows over the cut")
	_watch(game)
	await _frames(RUN_FRAMES)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not screen.visible, "worktable: Esc mid-cut closes the bench")
	_check(not state.input_locked, "worktable: input unlocked")
	_unpause(state, "worktable")
	_check(
		wt.held_item() == cloth and is_instance_valid(cloth) and cloth.length_m == 3.0,
		"worktable: the cloth stays on the table, uncut"
	)
	_check(state.focus == 2, "worktable: the coffee focus the cut took is handed back")
	_check(_finished == 0, "worktable: the cut never reported finished")

	# And the cut can be started again after leaving.
	screen.open(wt, null, cloth)
	screen.call("_start_cutting")
	_check(
		game.visible and not game.call("is_settled"), "worktable: a new cut starts after leaving"
	)
	screen.call("_on_cut_left")
	state.focus = 0
	wt.free()


func _test_sewing(ui: Node) -> void:
	var state := root.get_node("GameState")
	var machine: Node3D = load("res://stations/sewing_machine/sewing_machine.tscn").instantiate()
	root.add_child(machine)
	var piece := _garment(0.8)
	machine.get_node("Slot").add_child(piece)
	machine.set("_item", piece)
	var screen: Control = ui.sewing_screen
	screen.open(machine, null, piece)
	var game: Control = screen.get("_minigame")
	_watch(game)
	await _frames(RUN_FRAMES)
	_joy(JOY_BUTTON_B)  # ui_cancel on a gamepad
	await _frames(3)
	_check(not screen.visible, "sewing: gamepad B mid-seam closes the bench")
	_check(not state.input_locked, "sewing: input unlocked")
	_unpause(state, "sewing")
	_check(machine.held_item() == piece, "sewing: the piece stays on the machine")
	_check(
		piece.stage == 2 and is_equal_approx(piece.quality, 0.8),  # Enums.Stage.CUT
		"sewing: …still cut, not sewn, quality untouched"
	)
	_check(_finished == 0, "sewing: the seam never reported finished")
	machine.free()


func _test_press(ui: Node) -> void:
	var state := root.get_node("GameState")
	root.get_node("Upgrades").debug_set("shop_iron", true)
	var board: Node3D = load("res://stations/ironing_board/ironing_board.tscn").instantiate()
	root.add_child(board)
	var piece := _garment(0.7)
	root.add_child(piece)
	board.set("_piece_on_board", piece)
	ui.open_pressing(board, piece)
	var host: Control = ui.bench_game
	var game: Control = host.get("_minigame")
	_watch(game)
	await _frames(RUN_FRAMES)
	_joy(JOY_BUTTON_START)  # "pause" on a gamepad
	await _frames(3)
	_check(not host.visible, "press: Start mid-press closes the bench")
	_check(not state.input_locked, "press: input unlocked")
	_unpause(state, "press")
	_check(not piece.pressed and is_equal_approx(piece.quality, 0.7), "press: piece unpressed")
	_check(board.get("_piece_on_board") == null, "press: the board lets go of the piece")
	_check(_finished == 0, "press: the press never reported finished")
	piece.free()
	board.free()


func _test_coffee(ui: Node) -> void:
	var state := root.get_node("GameState")
	root.get_node("Upgrades").debug_set("shop_coffee", true)
	var machine: Node3D = _coffee_scene.instantiate()
	root.add_child(machine)
	state.focus = 0
	var cups: int = machine.get("_cups")
	machine.interact(null)
	var host: Control = ui.bench_game
	_check(host.visible and machine.get("_cups") == cups - 1, "coffee: a cup is on the go")
	_watch(host.get("_minigame"))
	await _frames(RUN_FRAMES)
	_right_click()
	await _frames(3)
	_check(not host.visible, "coffee: a right click mid-pour closes the bench")
	_check(not state.input_locked, "coffee: input unlocked")
	_unpause(state, "coffee")
	_check(machine.get("_cups") == cups, "coffee: the cup goes back in the pot")
	_check(state.focus == 0, "coffee: no cup, no focus")
	_check(_finished == 0, "coffee: the cup never reported finished")
	machine.free()


func _test_guest_cup(ui: Node) -> void:
	var state := root.get_node("GameState")
	var machine: Node3D = _coffee_scene.instantiate()
	root.add_child(machine)
	var cups: int = machine.get("_cups")
	var served := []
	machine.serve_guest(func(q: float) -> void: served.append(q))
	_watch(ui.bench_game.get("_minigame"))
	await _frames(RUN_FRAMES)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not ui.bench_game.visible, "guest cup: Esc closes the bench")
	_unpause(state, "guest cup")
	_check(served.is_empty(), "guest cup: nothing is handed to the customer")
	_check(machine.get("_cups") == cups, "guest cup: the cup goes back in the pot")
	_check(not (machine.get("_guest_cup") as Callable).is_valid(), "guest cup: order dropped")
	_check(_finished == 0, "guest cup: the cup never reported finished")
	machine.free()


## The control: with no bench up, the same Esc does reach GameState and pause — so the
## "pause menu stayed shut" checks above are real.
func _test_control() -> void:
	var state := root.get_node("GameState")
	_key(KEY_ESCAPE)
	_check(state.is_paused, "control: Esc with no bench up opens the pause menu")
	state.is_paused = false


## The hint line under every bench game: plain, then "a customer is waiting" while a
## shopper waits to be greeted, and plain again once they are answered or gone.
func _test_hint(ui: Node) -> void:
	var bus := root.get_node("EventBus")
	var words: Dictionary = load("res://ui/bench_leave_hint.gd").get_script_constant_map()
	var leave: String = words["LEAVE"]
	var waiting: String = words["WAITING"]
	var hints: Array[Label] = []
	for host: Control in [ui.worktable_screen, ui.sewing_screen, ui.bench_game]:
		hints.append(host.get("_leave_hint"))
	_check(_all_text(hints, leave), "hint: 'Esc to leave the bench'")
	var cust := Node.new()
	root.add_child(cust)
	bus.customer_waiting.emit(cust)
	_check(_all_text(hints, waiting), "hint: a shopper waiting is mentioned")
	bus.customer_answered.emit("take", cust)
	_check(_all_text(hints, leave), "hint: …and dropped once answered")
	bus.customer_waiting.emit(cust)
	_check(_all_text(hints, waiting), "hint: waiting again")
	cust.free()
	_check(_all_text(hints, leave), "hint: …and dropped once they are gone")


# --- Helpers -------------------------------------------------------------------


func _garment(quality: float) -> Node3D:
	var piece: Node3D = load("res://entities/items/garment_piece.tscn").instantiate()
	piece.material = _factory.make(1, 0, 0, 3.0)
	piece.garment_type = JACKET
	piece.quality = quality
	return piece


func _watch(game: Object) -> void:
	_finished = 0
	if game != null and not game.is_connected("finished", _on_finished):
		game.connect("finished", _on_finished)


func _on_finished(_success: bool, _quality: float) -> void:
	_finished += 1


func _all_text(hints: Array[Label], text: String) -> bool:
	for hint in hints:
		if hint.text != text:
			return false
	return true


## The pause menu must not have opened on the same press (GameState reads "pause" too).
func _unpause(state: Node, what: String) -> void:
	_check(not state.is_paused, "%s: the pause menu stayed shut" % what)
	state.is_paused = false


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)


func _joy(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventJoypadButton
	up.pressed = false
	root.push_input(up)


func _right_click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.position = Vector2(40, 40)
	ev.global_position = ev.position
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("test_bench_leave: ALL PASS")
	else:
		print("test_bench_leave: %d FAILURE(S)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
