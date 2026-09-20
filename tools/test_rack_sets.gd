extends SceneTree

## Headless test: sewn parts for the same order gather on a clothing rack into one set,
## the last part turns it into the finished suit (and the order Ready), sets can be taken
## apart (and those parts stay apart), racks never gather across each other, a set fits on
## a full rack, and sets survive a save and load. Item kinds are checked by class name, not
## `is`, so this script doesn't compile the item scripts in (headless tool runs can't
## resolve the autoloads some of them read).
##   godot --headless --path . --script res://tools/test_rack_sets.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const SEWN := 3
const CLOTH := "res://data/materials/navy_worsted_solid.tres"
const RACK := "res://stations/clothing_rack/clothing_rack.tscn"

var _main: Node
var _player: Node
var _orders: Node
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	for _i in 4:
		await process_frame
	_player = _main.find_child("Player", true, false)
	_orders = root.get_node("Orders")
	_orders.active.clear()
	var rack: Node = _main.find_child("ClothingRack", true, false)
	_gathering(rack)
	_taking_apart(rack)
	_separate_racks(rack)
	_full_rack(rack)
	_save_and_load(rack)
	_spares(rack)
	_finish()


## Jacket alone → jacket + shirt gather under a ticket → pants join → a suit, order Ready.
func _gathering(rack: Node) -> void:
	var order: Resource = _order("Mr. Gather")
	_hang(rack, _part(JACKET, order))
	_check(rack.stored.size() == 1 and _is(rack.stored[0], "GarmentPiece"), "one part hangs alone")
	_hang(rack, _part(SHIRT, order))
	var gathered: Node = rack.stored[0]
	_check(
		rack.stored.size() == 1 and _is(gathered, "GarmentSet"),
		"a second part joins it on one hook"
	)
	_check(gathered.missing() == [PANTS], "the set knows the pants are still to come")
	_check("pants left" in (gathered.get("_ticket") as Label3D).text, "the ticket says so")
	_check(order.state == 0, "the order isn't ready yet")
	_hang(rack, _part(PANTS, order))
	_check(rack.stored.size() == 1 and _is(rack.stored[0], "Suit"), "the last part makes the suit")
	_check(int(rack.stored[0].order_id) == order.id, "the suit is stamped with its order")
	_check(order.state == 1, "and the order is ready for its customer")
	_clear(rack)


## A set taken apart spreads over hooks and stays apart; a new part hangs alone rather than
## regathering them; parts taken off and rehung gather again and finish the suit.
func _taking_apart(rack: Node) -> void:
	var order: Resource = _order("Ms. Apart")
	_hang(rack, _part(JACKET, order))
	_hang(rack, _part(SHIRT, order))
	_check(rack.take_apart(0), "a set can be taken apart")
	_check(rack.stored.size() == 2 and rack.is_loose(0) and rack.is_loose(1), "into loose parts")
	_hang(rack, _part(PANTS, order))
	_check(rack.stored.size() == 3, "a new part doesn't regather taken-apart ones")
	rack.take(0, _player)
	_check(not rack.is_loose(0) or rack.stored.size() == 2, "a part taken off is no longer loose")
	rack.interact(_player)
	_check(rack.stored.size() == 2, "rehung, it gathers with the lone pants")
	rack.take(0, _player)
	rack.interact(_player)
	_check(rack.stored.size() == 1 and _is(rack.stored[0], "Suit"), "and the last one finishes it")
	_check(order.state == 1, "the order is ready")
	_clear(rack)


## Two racks for one order: the parts never gather across them.
func _separate_racks(rack: Node) -> void:
	var other: Node = load(RACK).instantiate()
	_main.add_child(other)
	var order: Resource = _order("Mr. Twofold")
	_hang(rack, _part(JACKET, order))
	_hang(other, _part(SHIRT, order))
	_check(
		_is(rack.stored[0], "GarmentPiece") and _is(other.stored[0], "GarmentPiece"),
		"racks keep apart"
	)
	_clear(rack)
	other.queue_free()


## A full rack still takes a part that joins a set it already holds (no new hook needed).
func _full_rack(rack: Node) -> void:
	var order: Resource = _order("Mrs. Crowded")
	_hang(rack, _part(JACKET, order))
	_hang(rack, _part(SHIRT, order))
	while rack.stored.size() < rack.capacity():
		_hang(rack, _spare())
	var pants := _part(PANTS, order)
	_give(pants)
	_check(rack.can_hang(pants), "a full rack still takes a part for a set on it")
	rack.interact(_player)
	_check(_is(rack.stored[0], "Suit"), "and finishes the suit")
	_check(not rack.can_take_apart(1), "a spare isn't a set to take apart")
	_clear(rack)


## A set and a loose part survive a save and load.
func _save_and_load(rack: Node) -> void:
	var order: Resource = _order("Sir Saved")
	_hang(rack, _part(JACKET, order))
	_hang(rack, _part(SHIRT, order))
	var loose_order: Resource = _order("Lady Loose")
	_hang(rack, _part(JACKET, loose_order))
	_hang(rack, _part(SHIRT, loose_order))
	rack.take_apart(1)
	var saved: Dictionary = rack.save_state()
	var copy: Node = load(RACK).instantiate()
	_main.add_child(copy)
	copy.load_state(saved)
	_check(copy.stored.size() == 3 and _is(copy.stored[0], "GarmentSet"), "the set comes back")
	_check(copy.stored[0].pieces.size() == 2, "with both its parts")
	_check(copy.is_loose(1) and copy.is_loose(2), "and taken-apart parts stay apart")
	_clear(rack)
	copy.queue_free()


## A lost order's parts become spares, and the next order they suit takes them.
func _spares(rack: Node) -> void:
	_orders.active.clear()
	var lost: Resource = _order("Mr. Gone")
	_hang(rack, _part(JACKET, lost))
	_hang(rack, _part(PANTS, lost))
	_check(_is(rack.stored[0], "GarmentSet"), "(setup) two parts gathered for the order")
	_orders.expire(lost)
	_check(rack.stored.size() == 2, "the order is lost: its set comes apart")
	_check(int(rack.stored[0].order_id) == 0, "and the parts are spares, no order number")
	_check(not rack.is_loose(0), "free to gather again")
	var next: Resource = _order("Mrs. Next")
	_check(next.is_part_done(JACKET) and next.is_part_done(PANTS), "a new order takes them")
	_check(
		rack.stored.size() == 1 and int(rack.stored[0].order_id) == int(next.id),
		"and they gather under its number"
	)
	_hang(rack, _part(SHIRT, next))
	_check(_is(rack.stored[0], "Suit"), "one shirt later it is a suit")
	_clear(rack)


func _order(customer: String) -> Resource:
	var design := {
		JACKET: {"fabric": 0, "pattern": 0, "color": 0},
		PANTS: {"fabric": 0, "pattern": 0, "color": 0},
		SHIRT: {"fabric": 5, "pattern": 0, "color": 0},
	}
	return _orders.create_order(customer, design, 300, Color.WHITE)


## A sewn part made for `order`.
func _part(kind: int, order: Resource) -> Node:
	var piece := _spare(kind)
	_orders.register_piece_for(piece, order)
	return piece


## A sewn part made for no order.
func _spare(kind := SHIRT) -> Node:
	var g: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	g.material = load(CLOTH)
	g.garment_type = kind
	g.stage = SEWN
	g.quality = 0.9
	return g


func _hang(rack: Node, piece: Node) -> void:
	_give(piece)
	rack.interact(_player)


func _give(item: Node) -> void:
	_main.add_child(item)
	_player.carry.take_item(item)


func _clear(rack: Node) -> void:
	for hung in rack.stored:
		hung.queue_free()
	rack.stored.clear()
	(rack.get("_loose") as Dictionary).clear()
	var held: Node = _player.carry.release()
	if held != null:
		held.queue_free()


## `node` is an item of the class named `kind` (see the note at the top).
func _is(node: Node, kind: String) -> bool:
	var script: Script = node.get_script() if node != null else null
	return script != null and script.get_global_name() == kind


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_rack_sets: ALL PASS")
		quit(0)
	else:
		print("test_rack_sets: %d FAILURE(S)" % _failures.size())
		quit(1)
