extends SceneTree

## Headless test for the pressing and coffee minigames and the stations behind them.
## Plumbing: what a clean / singed / scorched press does to a piece, what a perfect / good /
## weak / spilt cup is worth with and without the Espresso Machine, and that the espresso
## can't be bought before the coffee machine. Play-throughs: a small bot drives each game
## through the real input actions to a finish — a careful press, a press left to burn, a
## cup poured to the line, one poured over the rim, and a full espresso.
##   godot --headless --fixed-fps 60 --path . --script res://tools/test_comfort_games.gd

const ACTIONS := ["cut", "move_left", "move_right"]
const FRAME_CAP := 60 * 40

var _failures: Array[String] = []
var _result := []
var _piece_scene: PackedScene = load("res://entities/items/garment_piece.tscn")


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	_test_press_plumbing()
	_test_coffee_plumbing()
	await _test_press_games()
	await _test_coffee_games()
	_finish()


# --- Plumbing ----------------------------------------------------------------


func _test_press_plumbing() -> void:
	var upgrades := root.get_node("Upgrades")
	upgrades.debug_set("shop_iron", true)
	var board: Node3D = load("res://stations/ironing_board/ironing_board.tscn").instantiate()
	root.add_child(board)
	var cases := [[true, 1.0, 0.58], [true, 0.5, 0.54], [true, 0.0, 0.5], [false, 0.0, 0.45]]
	for case: Array in cases:
		var piece: Node = _piece_scene.instantiate()
		root.add_child(piece)
		piece.quality = 0.5
		board.set("_piece_on_board", piece)
		board.finish_press(case[0], case[1])
		var ok: bool = is_equal_approx(piece.quality, case[2]) and piece.pressed
		_check(ok, "press %s/%.1f → quality %.2f, pressed" % [case[0], case[1], piece.quality])
		piece.free()
	var fine: Node = _piece_scene.instantiate()
	root.add_child(fine)
	fine.quality = 0.97
	board.set("_piece_on_board", fine)
	board.finish_press(true, 1.0)
	_check(is_equal_approx(fine.quality, 1.0), "a press never takes a piece past 100%")
	board.finish_press(true, 1.0)  # nothing on the board any more: must not blow up
	fine.free()
	board.free()


func _test_coffee_plumbing() -> void:
	var upgrades := root.get_node("Upgrades")
	var state := root.get_node("GameState")
	state.money = 100000
	_check(not upgrades.can_buy("shop_espresso"), "no espresso machine before the coffee machine")
	upgrades.debug_set("shop_coffee", true)
	var machine: Node3D = load("res://stations/coffee_machine/coffee_machine.tscn").instantiate()
	root.add_child(machine)
	_check(machine.get("_cups") == 2, "two cups a day")
	var kit: Node3D = machine.get_node("Espresso")
	_check(not kit.visible, "the espresso kit is hidden until owned")
	for case: Array in [[true, 1.0, 4], [true, 0.7, 3], [true, 0.3, 2], [false, 0.0, 0]]:
		state.focus = 0
		machine.finish_coffee(case[0], case[1])
		_check(state.focus == case[2], "instant cup %.1f → %d jobs" % [case[1], state.focus])
	upgrades.debug_set("shop_espresso", true)
	_check(kit.visible, "the espresso kit shows once owned")
	for case: Array in [[true, 1.0, 6], [true, 0.7, 5], [true, 0.3, 3], [false, 0.0, 0]]:
		state.focus = 0
		machine.finish_coffee(case[0], case[1])
		_check(state.focus == case[2], "espresso %.1f → %d jobs" % [case[1], state.focus])
	_check(machine.call("_cups_per_day") == 3, "the espresso machine makes a third cup")
	state.focus = 0
	upgrades.debug_set("shop_espresso", false)
	machine.free()


# --- Play-throughs -----------------------------------------------------------


func _test_press_games() -> void:
	var careful: Node = await _play("res://ui/press_minigame.gd", _bot_press_careful, true)
	_check(_result == [true, 1.0], "a careful press finishes clean: %s" % [_result])
	_check(careful.coach_flags().get("pressed", false), "the press game reports its flags")
	careful.free()
	var burnt: Node = await _play("res://ui/press_minigame.gd", _bot_press_burn, true)
	_check(_result == [false, 0.0], "an iron left sitting scorches the press: %s" % [_result])
	_check(burnt.get("_mistakes") == 3, "…after three scorches")
	burnt.free()


func _test_coffee_games() -> void:
	var cup: Node = await _play("res://ui/coffee_pour_minigame.gd", _bot_coffee, false)
	_check(
		_result.size() == 2 and _result[0] and _result[1] >= 0.7,
		"a cup to the line: %s" % [_result]
	)
	cup.free()
	var spilt: Node = await _play("res://ui/coffee_pour_minigame.gd", _bot_hold, false)
	_check(_result == [false, 0.0], "a cup poured over the rim is spilt: %s" % [_result])
	spilt.free()
	var shot: Node = await _play("res://ui/espresso_minigame.gd", _bot_coffee, false)
	_check(_result.size() == 2 and _result[0] and _result[1] >= 0.7, "an espresso: %s" % [_result])
	_check(shot.get("_grades").size() == 3, "…in three beats")
	shot.free()


## Run one game under `bot` (called every frame with the game) until it finishes.
func _play(path: String, bot: Callable, press: bool) -> Node:
	_result = []
	var game: Control = load(path).new()
	root.add_child(game)
	game.connect("finished", func(ok: bool, q: float) -> void: _result = [ok, q])
	if press:
		game.start_piece(2, "Jacket · M", null)
	else:
		game.start_cup("A cup")
	var frames := 0
	while _result.is_empty() and frames < FRAME_CAP:
		frames += 1
		if game.get("_state") == 0:
			bot.call(game)
		await process_frame
	for action: String in ACTIONS:
		Input.action_release(action)
	return game


## Go to the nearest wrinkle with the iron up, press it flat, move on.
func _bot_press_careful(game: Node) -> void:
	var iron: float = game.get("_iron")
	var at: PackedFloat32Array = game.get("_at")
	var flat: PackedFloat32Array = game.get("_flat")
	var target := -1.0
	for i in at.size():
		if flat[i] < 1.0 and (target < 0.0 or absf(at[i] - iron) < absf(target - iron)):
			target = at[i]
	# Brake early (the iron coasts a little) and keep pressing while the plate still covers it.
	var reach := 0.07 if Input.is_action_pressed("cut") else 0.04
	var there := target < 0.0 or absf(target - iron) < reach
	_hold("cut", there and game.get("_armed"))
	_hold("move_left", not there and target < iron)
	_hold("move_right", not there and target > iron)


## Sit the iron on the cloth and never move it (letting go only to re-arm after a scorch).
func _bot_press_burn(game: Node) -> void:
	_hold("cut", game.get("_armed") or Input.is_action_pressed("cut") and game.get("_pressing"))


## Grind: stop the needle on the mark. Tamp and pour: hold until the mark, then let go.
func _bot_coffee(game: Node) -> void:
	var level: float = game.get("_level")
	var mark: float = game.get("_mark")
	if game.get("_pause") > 0.0 or not game.get("_armed") and not game.get("_holding"):
		_hold("cut", false)
	elif game.call("_kind") == 0:
		_hold("cut", absf(level - mark) < 0.03)
	else:
		_hold("cut", level < mark - 0.01)


func _bot_hold(game: Node) -> void:
	_hold("cut", game.get("_armed"))


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("test_comfort_games: ALL PASS")
	else:
		print("test_comfort_games: %d FAILURE(S)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
