extends SceneTree

## Headless smoke test for the save system. Boots main.tscn, fills the shop
## (shelves, rack, mannequin, worktable, a loose delivery, the player's hands) plus
## the run-level state (money/day/reputation/orders), then checks that:
##   1. SaveCodec round-trips every carryable item and MaterialType,
##   2. SaveManager.capture() reflects the live shop,
##   3. store_var/get_var to disk preserves it all.
##   godot --headless --path . --script res://tools/test_save.gd

const SHIRT := 0
const JACKET := 2
const SIZE_M := 1
const STAGE_SEWN := 3

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene_res: PackedScene = load("res://main.tscn")
	var main: Node = scene_res.instantiate()
	root.add_child(main)
	# --script boots don't load the main scene, so current_scene is null; set it so
	# SaveManager.capture() (which reads get_tree().current_scene) sees our shop.
	current_scene = main
	await process_frame
	await process_frame

	var sm: Node = root.get_node_or_null("SaveManager")
	var gs: Node = root.get_node_or_null("GameState")
	var orders: Node = root.get_node_or_null("Orders")
	var scene: Node = main
	if sm == null or gs == null or orders == null:
		_check(false, "autoloads present")
		_finish()
		return

	_test_codec()

	# --- Fill the shop -----------------------------------------------------
	var shelf: Node = scene.find_children("*", "Shelf", true, false)[0]
	var rack: Node = scene.find_children("*", "ClothingRack", true, false)[0]
	var mannequin: Node = scene.find_children("*", "Mannequin", true, false)[0]
	var worktable: Node = scene.find_children("*", "Worktable", true, false)[0]
	var carry: Node = scene.find_children("*", "CarrySlot", true, false)[0]

	shelf.load_state({"rolls": [_roll(0, 1, 0, 20.0, 7.5), _roll(2, 0, 4, 20.0, 20.0)]})
	rack.load_state({"pieces": [_garment(SHIRT, 0.9)]})
	mannequin.load_state({"dressed": {JACKET: _garment(JACKET, 0.8)}, "order": [JACKET]})
	worktable.load_state({"item": _fabric(1, 0, 2, 1.5)})

	var held: Node = SaveCodec.item_from(_suit(0.75))
	scene.add_child(held)
	carry.take_item(held)

	var room: Node = scene.get_node_or_null("ShopRoom")
	var loose: Node = SaveCodec.item_from(_roll(3, 0, 5, 20.0, 12.0))
	room.add_child(loose)
	loose.global_position = Vector3(1, 0.2, 2)

	orders.restore([_order()])

	gs.money = 1234
	root.get_node("Reputation").points = 77
	root.get_node("Shift").day = 5

	await process_frame

	# --- Capture -----------------------------------------------------------
	var snap: Dictionary = sm.capture("unit-test")
	_check(int(snap["money"]) == 1234, "money captured")
	_check(int(snap["day"]) == 5, "day captured")
	_check(int(snap["reputation"]) == 77, "reputation captured")
	_check(snap["orders"].size() == 1, "one order captured")
	_check(str(snap["orders"][0]["customer_name"]) == "Mr. Test", "order name captured")
	_check(str(snap["carry"].get("kind", "")) == "suit", "held suit captured")
	# The fresh shop already has an authored starting roll, so our added delivery
	# makes at least two loose items.
	_check(snap["loose"].size() >= 2, "loose deliveries captured (%d)" % snap["loose"].size())

	var shelf_path := str(scene.get_path_to(shelf))
	var shelf_data: Dictionary = snap["stations"].get(shelf_path, {})
	_check(shelf_data.get("rolls", []).size() == 2, "two rolls on the shelf captured")
	if shelf_data.get("rolls", []).size() == 2:
		_check(abs(float(shelf_data["rolls"][0]["remaining"]) - 7.5) < 0.01, "roll length captured")

	# --- Disk round trip ---------------------------------------------------
	var path := "user://saves/slot_unittest.sav"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_var(snap, false)
	w.close()
	var r := FileAccess.open(path, FileAccess.READ)
	var back: Variant = r.get_var(false)
	r.close()
	_check(back is Dictionary, "save file reads back as a dictionary")
	if back is Dictionary:
		_check(int(back["money"]) == 1234, "money survives disk")
		_check(back["stations"][shelf_path]["rolls"].size() == 2, "shelf survives disk")
		_check(str(back["carry"]["kind"]) == "suit", "held item survives disk")
		_check(int(back["orders"][0]["design"].keys()[0]) == JACKET, "order int-keys survive disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# --- End-to-end restore into a fresh scene -----------------------------
	main.queue_free()
	await process_frame
	var scene2: Node = scene_res.instantiate()
	root.add_child(scene2)
	current_scene = scene2
	await process_frame
	await process_frame

	orders.restore(back["orders"])
	sm._restore_stations(scene2, back["stations"])
	sm._restore_carry(scene2, back["carry"])
	sm._restore_loose(scene2, back["loose"])
	await process_frame

	var shelf2: Node = scene2.find_children("*", "Shelf", true, false)[0]
	var rack2: Node = scene2.find_children("*", "ClothingRack", true, false)[0]
	var mann2: Node = scene2.find_children("*", "Mannequin", true, false)[0]
	var work2: Node = scene2.find_children("*", "Worktable", true, false)[0]
	var carry2: Node = scene2.find_children("*", "CarrySlot", true, false)[0]
	_check(shelf2.stored.size() == 2, "restored 2 rolls onto the shelf")
	_check(rack2.stored.size() == 1, "restored 1 part onto the rack")
	_check(carry2.get_held() != null and carry2.get_held() is Suit, "restored the held suit")
	_check(work2.save_state().get("item", {}).size() > 0, "restored the worktable piece")
	_check(mann2.save_state()["dressed"].has(JACKET), "restored the mannequin's jacket")
	_check(orders.active.size() == 1, "restored the order book")

	_finish()


# --- Codec round trip ------------------------------------------------------


func _test_codec() -> void:
	var samples := [
		_roll(0, 1, 0, 20.0, 6.0),
		_garment(JACKET, 0.6),
		_fabric(1, 0, 2, 2.0),
		_suit(0.9),
	]
	for d: Dictionary in samples:
		var node: Node = SaveCodec.item_from(d)
		_check(node != null, "codec builds %s" % d["kind"])
		if node == null:
			continue
		var again: Dictionary = SaveCodec.item_to(node)
		_check(str(again.get("kind", "")) == str(d["kind"]), "codec round-trips %s kind" % d["kind"])
		node.free()


# --- Builders --------------------------------------------------------------


# A literal material dict (same shape as SaveCodec.mat_to). Built by hand rather
# than via MaterialFactory so this tool script doesn't statically pull in the
# Pricing/Config chain, which a bare --script boot can't compile.
func _mat(fabric: int, pattern: int, color: int, length: float) -> Dictionary:
	return {
		"id": "test_%d_%d_%d" % [fabric, pattern, color],
		"display_name": "Test Cloth",
		"fabric": fabric,
		"pattern": pattern,
		"cloth_color": Color(0.2, 0.3, 0.4),
		"pattern_color": Color(0.9, 0.9, 0.9),
		"weight_gsm": 250,
		"super_number": 0,
		"price_per_meter": 25,
		"roll_length_m": length,
	}


func _roll(fabric: int, pattern: int, color: int, length: float, remaining: float) -> Dictionary:
	return {"kind": "roll", "material": _mat(fabric, pattern, color, length), "remaining": remaining}


func _fabric(fabric: int, pattern: int, color: int, length: float) -> Dictionary:
	return {"kind": "fabric", "material": _mat(fabric, pattern, color, 20.0), "length": length}


func _garment(garment_type: int, quality: float) -> Dictionary:
	return {
		"kind": "garment",
		"material": _mat(0, 0, 0, 20.0),
		"garment_type": garment_type,
		"size": SIZE_M,
		"style": "Classic",
		"quality": quality,
		"stage": STAGE_SEWN,
	}


func _suit(quality: float) -> Dictionary:
	var part := {
		"material": _mat(0, 0, 0, 20.0),
		"quality": quality,
		"size": SIZE_M,
		"style": "Classic",
	}
	return {
		"kind": "suit",
		"quality": quality,
		"primary_color": Color(0.2, 0.2, 0.24),
		"parts": {JACKET: part},
	}


func _order() -> Dictionary:
	return {
		"customer_name": "Mr. Test",
		"design": {JACKET: {"fabric": 0, "pattern": 1, "color": 0, "style_idx": 0}},
		"price": 300,
		"skin": Color(0.87, 0.72, 0.6),
		"hair_index": 0,
		"hair_color": Color(0.14, 0.11, 0.09),
		"deadline_days": 3,
		"days_left": 2.0,
		"state": 0,
		"filled": {},
	}


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   - %s" % label)
	else:
		_failures.append(label)
		print("  FAIL - %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS - save system")
		quit(0)
	else:
		print("FAILED %d checks" % _failures.size())
		quit(1)
