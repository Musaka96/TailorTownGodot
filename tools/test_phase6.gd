extends SceneTree

## Headless test for the storefront/customer/order systems: a customer spawns
## inside, can be seated at the mirror, an approved design creates an order, and a
## matching packaged suit fulfils it (paying the shop). Edge: a suit with no
## matching order is handed back to the player.
##   godot --headless --path . --script res://tools/test_phase6.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2

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

	# --- Per-piece: a suit matching only some pieces checks off just those ---
	# (run in isolation first — piece matching is FIFO across open orders.)
	var partial = orders.create_order("Partial", design, quote, Color.WHITE)
	var mixed := _suit_from(design, 0.9)
	var off = _mismatch_material(design[JACKET])
	mixed.parts[SHIRT]["material"] = off
	mixed.parts[PANTS]["material"] = off
	orders.submit(mixed, _player)
	_check(
		partial.is_part_done(JACKET) and not partial.is_part_done(SHIRT),
		"only the matching jacket is checked off"
	)
	_check(not partial.is_complete(), "an order with unmade pieces stays open")
	orders.expire(partial)

	# --- Approve a design: an order is created with a 1-5 day deadline ---
	var order = orders.create_order(pref.display_name, design, quote, Color.WHITE)
	_check(orders.active.size() == 1, "approving a design creates an order")
	_check(order.deadline_days >= 1 and order.deadline_days <= 5, "order gets a 1-5 day deadline")

	# --- A matching suit checks off every piece → order becomes READY ---
	var money_before: int = game.money
	var suit := _suit_from(design, 0.9)
	orders.submit(suit, _player)
	_check(order.is_complete(), "a matching suit checks off all three pieces")
	_check(orders.is_ready(order), "a fully-made order is READY (awaiting collection)")
	_check(game.money == money_before, "no payment until the customer collects")

	# --- The customer collects: the shop is paid and the order clears ---
	var payout: int = orders.collect(order)
	_check(payout > 0 and orders.active.is_empty(), "collecting pays out and clears the order")
	_check(game.money > money_before, "shop was paid (%d -> %d)" % [money_before, game.money])

	# --- Edge: a suit with no open order is handed to the player ---
	var stray := _suit_from(design, 0.9)
	orders.submit(stray, _player)
	_check(not _player.carry.is_empty(), "suit with no order is kept by the player")

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
	return _all_parts(fabric, color, pattern)


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
