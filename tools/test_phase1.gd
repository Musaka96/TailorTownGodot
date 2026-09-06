extends SceneTree

## Headless smoke test for the Phase 1 carry/shelf loop. Drives the gameplay
## methods directly (no input/render needed) and asserts state transitions:
##   godot --headless --path . --script res://tools/test_phase1.gd
## Exit code is non-zero on any failed assertion.

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	# Let a couple of frames pass so every _ready()/@onready has resolved.
	await process_frame
	await process_frame

	var player: Node = main.find_child("Player", true, false)
	var shelf: Node = main.find_child("Shelf", true, false)
	var rolls := _find_rolls(main)

	_check(player != null, "player present")
	_check(shelf != null, "shelf present")
	_check(rolls.size() >= 2, "at least 2 rolls in room (got %d)" % rolls.size())
	if player == null or shelf == null or rolls.size() < 2:
		_finish()
		return

	var carry = player.get("carry")
	_check(carry != null, "player has a carry slot")
	if carry == null:
		_finish()
		return

	var roll_a: Node = rolls[0]
	var roll_b: Node = rolls[1]

	# 1) Pick up a roll.
	_check(player.carry.is_empty(), "hands start empty")
	roll_a.interact(player)
	_check(not player.carry.is_empty(), "carrying after pick up")
	_check(player.carry.get_held() == roll_a, "carrying the roll we picked")

	# 2) Can't pick up a second roll while full.
	roll_b.interact(player)
	_check(player.carry.get_held() == roll_a, "second pickup refused while full")

	# 3) Place it on the shelf.
	shelf.interact(player)
	_check(player.carry.is_empty(), "hands empty after placing")
	_check(shelf.stored.size() == 1, "shelf holds 1 (got %d)" % shelf.stored.size())
	_check(shelf.stored[0] == roll_a, "shelf stored the right roll")

	# 4) Take it back out via the shelf API.
	shelf.take(0, player)
	_check(not player.carry.is_empty(), "carrying after taking from shelf")
	_check(shelf.stored.size() == 0, "shelf empty after take")

	_finish()


func _find_rolls(node: Node) -> Array:
	var out: Array = []
	if node.has_method("attach_to") and node.has_method("get_interaction_prompt"):
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
		print("test_phase1: ALL PASS")
		quit(0)
	else:
		print("test_phase1: %d FAILURE(S)" % _failures.size())
		quit(1)
