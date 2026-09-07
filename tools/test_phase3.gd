extends SceneTree

## Headless test for the worktable result plumbing: a successful cut turns the
## fabric piece into a configured GarmentPiece; a ruined cut wastes it.
##   godot --headless --path . --script res://tools/test_phase3.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var worktable: Node = main.find_child("Worktable", true, false)
	if worktable == null:
		_check(false, "worktable present")
		_finish()
		return

	# Success: fabric piece -> garment part.
	_place_fabric(worktable, 2.0)
	worktable.finish_cut(true, 2, 3, "Double-Breasted", 0.78)  # Jacket, XL
	var part: Node = worktable._item
	_check(part != null, "cut produced a part")
	_check(part != null and part.get("length_m") == null, "part is a garment piece (not fabric)")
	_check(part != null and part.get("garment_type") == 2, "type carried through (jacket)")
	_check(part != null and part.get("size") == 3, "size carried through (XL)")
	_check(part != null and absf(part.get("quality") - 0.78) < 0.01, "quality carried through")

	# Edge: finish_cut with no fabric piece on the table is ignored.
	worktable.finish_cut(true, 0, 0, "Classic", 1.0)
	_check(worktable._item == part, "finish_cut ignored when table has no fabric piece")

	# Ruin: wastes the piece, table ends empty.
	if part != null:
		part.queue_free()
	worktable._item = null
	_place_fabric(worktable, 1.5)
	worktable.finish_cut(false, 0, 1, "Classic", 0.0)
	_check(worktable._item == null, "ruined cut wastes the piece")

	_finish()


func _place_fabric(worktable: Node, length: float) -> void:
	var piece: Node = load("res://entities/items/fabric_piece.tscn").instantiate()
	piece.material = load("res://data/materials/navy_worsted_solid.tres")
	piece.length_m = length
	worktable.get_node("Slot").add_child(piece)
	worktable._item = piece


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_phase3: ALL PASS")
		quit(0)
	else:
		print("test_phase3: %d FAILURE(S)" % _failures.size())
		quit(1)
