extends SceneTree

## Headless test for the economy (docs/ECONOMY.md): cloth + craft quotes, payout bands
## and tips, the late grace day, bolt pricing (supplier / bulk / market day), the cloth
## account safety net, shop-day deadlines, and regular customers' loyalty budgets.
##   godot --headless --path . --script res://tools/test_economy.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const ORDER_SCRIPT := "res://data/scripts/suit_order.gd"

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var pricing = load("res://data/scripts/pricing.gd")
	var state: Node = root.get_node("GameState")
	var orders: Node = root.get_node("Orders")
	var shift: Node = root.get_node("Shift")
	var rep: Node = root.get_node("Reputation")
	var clientele: Node = root.get_node("Clientele")
	rep.points = 0

	_quotes(pricing)
	_payouts(pricing)
	_bolts(pricing, shift)
	_account(state)
	_deadlines(orders, shift)
	_regulars(clientele)
	_finish()


## Worsted jacket + pants, cotton shirt, all solid (size M) at tier 0:
## cloth = (20*2.0 + 20*1.4 + 12*1.6) * 1.1 = 95.92 → 96; craft = 90+50+40 = 180.
func _quotes(pricing) -> void:
	var design := {
		JACKET: {"fabric": 0, "pattern": 0, "color": 0},
		PANTS: {"fabric": 0, "pattern": 0, "color": 0},
		SHIRT: {"fabric": 5, "pattern": 0, "color": 0},
	}
	var q: Dictionary = pricing.quote_breakdown(design, 0)
	_check(int(q["cloth"]) == 96, "cloth share = list metres + 10%% handling (%d)" % q["cloth"])
	_check(int(q["craft"]) == 180, "craft fee at tier 0 = 180 (%d)" % q["craft"])
	_check(int(q["total"]) == 276, "quote = cloth + craft (%d)" % q["total"])
	var top: Dictionary = pricing.quote_breakdown(design, 4)
	_check(int(top["craft"]) == 315, "craft fee scales with reputation (tier 4 = 315)")
	var mohair := design.duplicate(true)
	mohair[JACKET]["fabric"] = 3  # Savile Silk only (+20%)
	var qm: Dictionary = pricing.quote_breakdown(mohair, 0)
	_check(int(qm["cloth"]) > int(q["cloth"]), "premium fabric carries its supplier's premium")


func _payouts(pricing) -> void:
	_check(is_equal_approx(pricing.pay_share(0.6), 1.0), "good-enough (0.6) pays in full")
	_check(pricing.pay_share(0.5) < 1.0 and pricing.pay_share(0.5) > 0.6, "0.5 pays partly")
	_check(pricing.pay_share(0.2) < 0.6, "poor work pays little")
	_check(is_zero_approx(pricing.tip_share(0.85)), "no tip below the excellent band")
	_check(is_equal_approx(pricing.tip_share(1.0), 0.25), "perfect work tips 25%")
	var order = load(ORDER_SCRIPT).new()
	order.price = 300
	order.design = {JACKET: {}}
	order.fill_part(JACKET, 1.0, 1.0)
	_check(order.payout() == 375, "perfect order pays price + 25%% tip (%d)" % order.payout())
	order.late = true
	_check(order.payout() == 225, "late order pays 75%%, no tip (%d)" % order.payout())


func _bolts(pricing, shift: Node) -> void:
	var mat: MaterialType = load("res://data/scripts/material_factory.gd").make(0, 0, 0, 1.0)
	shift.day = 1
	_check(pricing.roll_price(mat, 4.0, 0) == 80, "4 m from Harrow = $80")
	_check(pricing.roll_price(mat, 4.0, 1) == 88, "premium mill +10% = $88")
	_check(pricing.roll_price(mat, 10.0, 0) == 180, "10 m bulk −10% = $180")
	_check(pricing.roll_price(mat, 20.0, 0) == 320, "20 m bulk −20% = $320")
	shift.day = 5
	_check(pricing.is_market_day(), "day 5 is market day")
	_check(pricing.roll_price(mat, 4.0, 0) == 60, "market day −25% = $60")
	shift.day = 1


func _account(state: Node) -> void:
	state.money = 10
	state.account_owed = 0
	_check(state.can_use_account(100), "broke: a small bolt can go on account")
	_check(not state.can_use_account(500), "account is capped")
	_check(state.buy_on_account(100) and state.account_owed == 100, "bolt put on account")
	_check(not state.can_use_account(50), "only one open account at a time")
	state.earn(300)
	_check(state.settle_account() == 100 and state.account_owed == 0, "settled from earnings")
	_check(state.money == 210, "wallet after settling = 210")


func _deadlines(orders: Node, shift: Node) -> void:
	shift.day = 3
	var design := {JACKET: {"fabric": 0, "pattern": 0, "color": 0}}
	var order = orders.create_order("Test Person", design, 200, Color.WHITE)
	_check(order.due_day >= 4 and order.due_day <= 7, "due day is 1-4 shop days ahead")
	shift.day = order.due_day
	_check(order.days_left_ceil() == 1, "on the due day the ticket reads 'today'")
	_check(orders.grant_grace(order), "first missed pickup grants a grace day")
	_check(order.late and order.due_day == shift.day + 1, "grace moves the due day to tomorrow")
	_check(not orders.grant_grace(order), "no second grace day")
	orders.expire(order)
	_check(not orders.active.has(order), "expired order leaves the book")
	shift.day = 1


func _regulars(clientele: Node) -> void:
	clientele.reset()
	var cust: Node = load("res://entities/customer/customer.tscn").instantiate()
	root.add_child(cust)
	var pref_script = load("res://data/scripts/customer_preference.gd")
	var pref = pref_script.new()
	pref.display_name = "Ms. Regular"
	cust.preference = pref
	clientele.note_customer(cust)
	_check(not clientele.has_regulars(), "a first-time customer isn't a regular yet")
	var order = load(ORDER_SCRIPT).new()
	order.customer_name = "Ms. Regular"
	root.get_node("EventBus").order_fulfilled.emit(order, 100)
	_check(clientele.has_regulars() and clientele.loyalty("Ms. Regular") == 1, "loyalty +1")
	_check(is_equal_approx(clientele.budget_mult("Ms. Regular"), 1.1), "loyal budget ×1.1")
	_check(clientele.pick_regular() == "", "but not again the day they collected")
	root.get_node("Shift").day += 1
	_check(clientele.pick_regular() == "Ms. Regular", "the regular can walk back in")
	root.get_node("Shift").day -= 1
	var rng := RandomNumberGenerator.new()
	var p = pref_script.random_pref(rng, "Ms. Regular")
	_check(p.regular_level == 1 and p.title().contains("★"), "regular shows a loyalty star")
	cust.queue_free()
	clientele.reset()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_economy: ALL PASS")
		quit(0)
	else:
		print("test_economy: %d FAILURE(S)" % _failures.size())
		quit(1)
