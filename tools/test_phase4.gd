extends SceneTree

## Headless test for the sewing machine + config: sewing turns a CUT piece into
## a SEWN piece (quality = cut × sew), a ruined seam wastes it, and starting
## money comes from the config asset.
##   godot --headless --path . --script res://tools/test_phase4.gd

# Enum ints (class_name globals aren't available in a --script main loop):
const CUT := 2
const SEWN := 3

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var machine: Node = main.find_child("SewingMachine", true, false)
	var cfg: Node = get_root().get_node("Config")
	var gs: Node = get_root().get_node("GameState")
	if machine == null or cfg == null:
		_check(false, "sewing machine + config present")
		_finish()
		return

	# Config drives starting money.
	_check(gs.money == cfg.data.starting_money, "money = config starting_money (%d)" % gs.money)

	# Success: CUT (q 0.8) sewn at 0.9 -> SEWN, q 0.72.
	_place_cut(machine, 0.8)
	machine.finish_sew(true, 0.9)
	var part: Node = machine._item
	_check(part != null and part.stage == SEWN, "piece is now SEWN")
	_check(part != null and absf(part.quality - 0.72) < 0.01,
		"quality = cut × sew (%.2f)" % part.quality)

	# Edge: sewing an already-SEWN piece is a no-op.
	machine.finish_sew(true, 0.5)
	_check(machine._item == part and part.stage == SEWN, "re-sew of a sewn piece ignored")

	# Ruin wastes the piece.
	if part != null:
		part.queue_free()
	machine._item = null
	_place_cut(machine, 1.0)
	machine.finish_sew(false, 0.0)
	_check(machine._item == null, "ruined seam wastes the piece")

	_finish()


func _place_cut(machine: Node, quality: float) -> void:
	var piece: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	piece.material = load("res://data/materials/navy_worsted_solid.tres")
	piece.garment_type = 0
	piece.size = 1
	piece.stage = CUT
	piece.quality = quality
	machine.get_node("Slot").add_child(piece)
	machine._item = piece


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_phase4: ALL PASS")
		quit(0)
	else:
		print("test_phase4: %d FAILURE(S)" % _failures.size())
		quit(1)
