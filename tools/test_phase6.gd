extends SceneTree

## Headless test for the storefront/customer/order systems: a customer spawns
## inside, can be seated at the mirror, an approved design creates an order, and a
## matching packaged suit fulfils it (paying the shop). Edge: a suit with no
## matching order is handed back to the player.
##   godot --headless --path . --script res://tools/test_phase6.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const SEWN := 3  # Enums.Stage.SEWN

var _main: Node
var _player: Node
var _failures: Array[String] = []
# Loaded lazily (not a preload const) so it doesn't compile MaterialFactory /
# Pricing before the autoloads they depend on (Config) are registered.
var _mf = null


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	for _i in 8:
		await process_frame

	_player = _main.find_child("Player", true, false)
	var mirror: Node = _main.find_child("Mirror", true, false)
	# The always-present starting customer was removed; spawn one via the manager.
	var mgr := get_first_node_in_group("customer_manager")
	if mgr != null:
		mgr.spawn_tutorial_customer()
		await process_frame
	var customer: Node = _main.find_child("Customer", true, false)
	if _player == null or mirror == null or customer == null:
		_check(false, "player + mirror + spawned customer present")
		_finish()
		return

	var pref = customer.get("preference")
	_check(pref != null, "spawned customer has a brief (occasion/style/budget)")
	_check(mirror.get("customer") == null, "mirror starts with no customer")

	# --- Seat the customer at the mirror ---
	customer.offer_mirror()
	_check(mirror.get("customer") == customer, "offer_mirror seats them at the mirror")

	# --- A design that fits the dress-code brief is accepted ---
	pref.budget = 1000  # take budget out of the equation; test the rule logic
	var design := _suitable_design(pref)
	var reaction: Dictionary = pref.evaluate(design)
	_check(reaction["suitable"], "a design that fits the brief is accepted")
	# --- A design that breaks the brief is rejected ---
	var bad := _breaking_design(pref)
	_check(not pref.evaluate(bad)["suitable"], "a design that breaks the brief is rejected")
	var quote: int = reaction["quote"]

	var orders: Node = root.get_node("Orders")
	var game: Node = root.get_node("GameState")

	# --- Approve a design: a numbered order is created with a 1-5 day deadline ---
	var order = orders.create_order(pref.display_name, design, quote, Color.WHITE)
	_check(order.id > 0, "order gets a number (#%d)" % order.id)
	_check(orders.active.size() == 1, "approving a design creates an order")
	_check(order.deadline_days >= 1 and order.deadline_days <= 5, "order gets a 1-5 day deadline")

	# --- Pieces check off the order as they're sewn, stamped with the order number ---
	var jacket_piece := _piece_from(design, JACKET, 0.9)
	var filled_by = orders.register_piece(jacket_piece)
	_check(filled_by == order and order.is_part_done(JACKET), "a sewn jacket checks off the order")
	_check(int(jacket_piece.order_id) == order.id, "the sewn piece is stamped with the order number")

	# A piece that breaks the brief matches no open slot — it's a spare (order 0).
	var bad_shirt := _piece_from(design, SHIRT, 0.9)
	bad_shirt.material = _mismatch_material(design[SHIRT])
	_check(orders.register_piece(bad_shirt) == null, "a mismatched piece matches no order")
	_check(
		int(bad_shirt.order_id) == 0 and not order.is_part_done(SHIRT),
		"the mismatched piece is a spare, order slot still open"
	)

	# Finish the rest: all pieces made, but the order is NOT ready until it's assembled.
	orders.register_piece(_piece_from(design, SHIRT, 0.9))
	orders.register_piece(_piece_from(design, PANTS, 0.9))
	_check(order.is_complete(), "all pieces made completes the order's checklist")
	_check(not orders.is_ready(order), "pieces made is NOT yet READY (needs assembly)")

	# --- Assemble at the mannequin → the order goes READY for pickup ---
	var suit := _suit_from(design, 0.9)
	suit.order_id = order.id  # the mannequin stamps this from the pieces' order number
	_check(orders.assemble(order.id) == order, "assembling marks the order READY")
	_check(orders.is_ready(order), "an assembled order is READY (awaiting collection)")

	# --- Delivery: the customer only takes the suit with their order number ---
	var money_before: int = game.money
	customer.offer_collection(order)
	var wrong := _suit_from(design, 0.9)  # untagged (order 0)
	_player.carry.take_item(wrong)
	customer.interact(_player)
	_check(
		not orders.active.is_empty() and game.money == money_before,
		"the wrong suit is refused (no payment, order still open)"
	)
	var w: Node = _player.carry.release()
	if w != null:
		w.queue_free()

	# The right suit hands over: paid and the order clears.
	_player.carry.take_item(suit)
	customer.interact(_player)
	_check(orders.active.is_empty(), "delivering the matching suit clears the order")
	_check(
		game.money > money_before, "shop was paid on delivery (%d -> %d)" % [money_before, game.money]
	)

	_finish()


## A material that fails to match `spec` on fabric, pattern and colour.
func _mismatch_material(spec: Dictionary):
	var fabric := (int(spec["fabric"]) + 1) % 5
	var pattern := (int(spec["pattern"]) + 1) % 9
	var color: int = (int(spec["color"]) + 3) % _factory().color_count()
	return _factory().make(fabric, pattern, color, 2.0)


func _factory():
	if _mf == null:
		_mf = load("res://data/scripts/material_factory.gd")
	return _mf


func _suitable_design(pref) -> Dictionary:
	var rule = root.get_node("Catalog").dress_code.rule_for(pref.occasion, pref.style)
	var color := int(rule.allowed_colors[0]) if not rule.allowed_colors.is_empty() else 0
	var pattern := int(rule.allowed_patterns[0]) if not rule.allowed_patterns.is_empty() else 0
	if rule.require_pattern and pattern == 0:
		for p in rule.allowed_patterns:
			if int(p) != 0:
				pattern = int(p)
				break
	var fabric := int(rule.allowed_fabrics[0]) if not rule.allowed_fabrics.is_empty() else 0
	# Jacket + matching trousers, plus a white solid cotton shirt (fine for any brief).
	var d := {}
	d[JACKET] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	d[PANTS] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	d[SHIRT] = {
		"fabric": Enums.Fabric.COTTON, "color": 10, "pattern": Enums.Pattern.SOLID, "style_idx": 0
	}
	return d


func _breaking_design(pref) -> Dictionary:
	var rule = root.get_node("Catalog").dress_code.rule_for(pref.occasion, pref.style)
	var bad_color := 0
	for c in range(10):
		if not (c in rule.allowed_colors):
			bad_color = c
			break
	return _all_parts(0, bad_color, 0)


func _all_parts(fabric: int, color: int, pattern: int) -> Dictionary:
	var d := {}
	for t in [JACKET, SHIRT, PANTS]:
		d[t] = {"fabric": fabric, "color": color, "pattern": pattern, "style_idx": 0}
	return d


## A single SEWN garment piece cut from the design's cloth for `garment_type`.
func _piece_from(design: Dictionary, garment_type: int, quality: float) -> Node:
	var g: Node = load("res://entities/items/garment_piece.tscn").instantiate()
	_main.add_child(g)
	var c: Dictionary = design[garment_type]
	g.material = _factory().make(c["fabric"], c["pattern"], c["color"], 2.0)
	g.garment_type = garment_type
	g.size = 1
	g.stage = SEWN
	g.quality = quality
	return g


func _suit_from(design: Dictionary, quality: float) -> Node:
	var suit: Node = load("res://entities/items/suit.tscn").instantiate()
	_main.add_child(suit)
	var parts := {}
	for t in design:
		var c: Dictionary = design[t]
		var mat = _factory().make(c["fabric"], c["pattern"], c["color"], 2.0)
		parts[t] = {"material": mat, "quality": quality, "size": 1, "style": "Classic"}
	suit.parts = parts
	suit.quality = quality
	return suit


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_phase6: ALL PASS")
		quit(0)
	else:
		print("test_phase6: %d FAILURE(S)" % _failures.size())
		quit(1)
