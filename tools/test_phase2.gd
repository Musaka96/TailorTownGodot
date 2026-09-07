extends SceneTree

## Headless smoke test for Phase 2: economy, ordering delivery, cutting, and the
## worktable — plus the edge cases (hands full, unaffordable, roll consumed).
##   godot --headless --path . --script res://tools/test_phase2.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var shelf: Node = main.find_child("Shelf", true, false)
	var worktable: Node = main.find_child("Worktable", true, false)
	var phone: Node = main.find_child("Phone", true, false)
	var rolls := _find_rolls(main)
	if player == null or shelf == null or worktable == null or phone == null or rolls.is_empty():
		_check(false, "all stations + a roll present")
		_finish()
		return

	# Autoloads aren't global identifiers inside a --script main loop; fetch it.
	var gs: Node = get_root().get_node("GameState")

	# --- Economy ---
	gs.money = 500
	_check(gs.can_afford(200), "can afford 200 of 500")
	_check(not gs.can_afford(9999), "cannot afford 9999")
	_check(gs.spend(150), "spend 150 succeeds")
	_check(gs.money == 350, "balance is 350 (got %d)" % gs.money)
	_check(not gs.spend(99999), "overspend refused")
	_check(gs.money == 350, "balance unchanged after refused spend")

	# --- Delivery ---
	var before := _find_rolls(main).size()
	phone.deliver_roll(rolls[0].material, 12.0)
	await process_frame
	_check(_find_rolls(main).size() == before + 1, "delivery spawned a roll")

	# --- Cutting (put a roll on the shelf first) ---
	rolls[0].interact(player)
	shelf.interact(player)
	_check(shelf.stored.size() >= 1, "roll placed on shelf")
	_check(player.carry.is_empty(), "hands empty after placing")

	var rem_before: float = shelf.stored[0].remaining_length_m
	_check(shelf.cut_piece(0, 2.0, player), "cut a 2m piece")
	var piece: Node = player.carry.get_held()
	_check(piece != null and piece.get("length_m") != null, "carrying a fabric piece")
	_check(absf(piece.length_m - 2.0) < 0.01, "piece is 2.0 m (got %.2f)" % piece.length_m)
	# The roll on the shelf lost 2m (unless it was consumed to empty and removed).
	if shelf.stored.size() >= 1:
		var lost: float = rem_before - shelf.stored[0].remaining_length_m
		_check(absf(lost - 2.0) < 0.01, "roll lost 2m")

	# --- Edge: cut / take with hands full ---
	_check(not shelf.cut_piece(0, 1.0, player), "cut refused while carrying")
	_check(not shelf.take(0, player), "take refused while carrying")

	# --- Worktable place + take back ---
	worktable.interact(player)
	_check(player.carry.is_empty(), "piece placed on worktable")
	worktable.interact(player)
	_check(not player.carry.is_empty(), "piece taken back from worktable")

	_finish()


func _find_rolls(node: Node) -> Array:
	var out: Array = []
	if node.has_method("cut") and node.has_method("attach_to"):
		out.append(node)
	for child in node.get_children():
		out += _find_rolls(child)
	return out


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_phase2: ALL PASS")
		quit(0)
	else:
		print("test_phase2: %d FAILURE(S)" % _failures.size())
		quit(1)
