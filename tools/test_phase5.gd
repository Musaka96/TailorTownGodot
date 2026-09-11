extends SceneTree

## Headless test for the clothing rack + mannequin + suit assembly, with edge
## cases (unsewn piece rejected, duplicate type rejected).
##   godot --headless --path . --script res://tools/test_phase5.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const CUT := 2
const SEWN := 3

var _main: Node
var _player: Node
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame

	_player = _main.find_child("Player", true, false)
	var rack: Node = _main.find_child("ClothingRack", true, false)
	var mannequin: Node = _main.find_child("Mannequin", true, false)
	if _player == null or rack == null or mannequin == null:
		_check(false, "player + rack + mannequin present")
		_finish()
		return

	# --- Rack: hang and take back ---
	_give(_make(SHIRT, SEWN, 0.9))
	rack.interact(_player)
	_check(rack.stored.size() == 1 and _player.carry.is_empty(), "hung a part on the rack")
	# Empty-handed interact now opens the browse menu (a no-op headless); the menu calls
	# rack.take() to retrieve a piece, so exercise that path directly.
	rack.take(0, _player)
	_check(rack.stored.size() == 0 and not _player.carry.is_empty(), "took the part back")
	_drop()

	# --- Mannequin: dress shirt, pants, jacket ---
	_give(_make(SHIRT, SEWN, 0.9))
	mannequin.interact(_player)
	_check(_player.carry.is_empty(), "shirt goes on the mannequin")

	# Edge: a second shirt is refused (slot taken).
	_give(_make(SHIRT, SEWN, 1.0))
	mannequin.interact(_player)
	_check(not _player.carry.is_empty(), "duplicate type refused")
	_drop()

	# Edge: an unsewn (CUT) piece is refused.
	_give(_make(PANTS, CUT, 1.0))
	mannequin.interact(_player)
	_check(not _player.carry.is_empty(), "unsewn piece refused")
	_drop()

	_give(_make(PANTS, SEWN, 0.8))
	mannequin.interact(_player)
	_give(_make(JACKET, SEWN, 0.7))
	mannequin.interact(_player)
	_check(_player.carry.is_empty(), "pants + jacket go on")

	# --- Package the suit ---
	mannequin.interact(_player)
	var suit: Node = _player.carry.get_held()
	_check(suit != null and suit.get("quality") != null, "packaged a suit")
	_check(suit != null and absf(suit.quality - 0.8) < 0.01,
		"suit quality = avg (%.2f)" % suit.quality)
	_check(suit != null and suit.parts.size() == 3, "suit has all 3 parts")
	_check(mannequin._dressed.is_empty(), "mannequin cleared after packaging")

	_finish()


func _make(type: int, stage: int, quality: float) -> Node:
	var g: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	g.material = load("res://data/materials/navy_worsted_solid.tres")
	g.garment_type = type
	g.size = 1
	g.stage = stage
	g.quality = quality
	return g


func _give(item: Node) -> void:
	_main.add_child(item)
	_player.carry.take_item(item)


func _drop() -> void:
	var item: Node = _player.carry.release()
	if item:
		item.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_phase5: ALL PASS")
		quit(0)
	else:
		print("test_phase5: %d FAILURE(S)" % _failures.size())
		quit(1)
