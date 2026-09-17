extends SceneTree

## Headless test for the customer director (globals/front_desk.gd, docs/CUSTOMERS.md):
## workload estimate, daily plan by stage, the opening bell, swamped / booked holds,
## realistic due days, appointments, rival referrals, honest declines, picky payouts, the
## calendar, and the shop serving one customer at a time (entities/customer/*).
##   godot --headless --path . --script res://tools/test_front_desk.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const CUST_SCENE := "res://entities/customer/customer.tscn"

var _failures: Array[String] = []
var _desk: Node
var _orders: Node
var _shift: Node
var _clock: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	_desk = root.get_node("FrontDesk")
	_orders = root.get_node("Orders")
	_shift = root.get_node("Shift")
	_clock = root.get_node("DayNight")
	root.get_node("Reputation").points = 0
	root.get_node("GameState").money = 500
	_orders.active.clear()
	_desk.reset()
	_shift.day = 1
	_clock.set("_elapsed", 0.0)

	_workload()
	_due_days()
	_holds()
	_saying_no()
	_picky()
	await _one_at_a_time()
	_finish()


func _suit() -> Dictionary:
	return {
		JACKET: {"fabric": 0, "pattern": 0, "color": 0},
		PANTS: {"fabric": 0, "pattern": 0, "color": 0},
		SHIRT: {"fabric": 5, "pattern": 0, "color": 0},
	}


func _workload() -> void:
	_check(is_zero_approx(_desk.load_factor()), "an empty order book is idle")
	_check(_desk.stage() == 0, "day 1 at tier 0 is the opening week")
	_check(_desk.planned_walk_ins() == 1, "opening week plans one walk-in a day")
	_desk.plan_day()
	var first: float = _desk.get("_plan")[0]
	var bell: Vector2 = _desk.OPENING_BELL
	_check(
		first >= bell.x and first <= bell.y,
		"an empty book at opening rings the bell early (%.1f%% into the shift)" % (first * 100.0)
	)
	_orders.create_order("A", _suit(), 250, Color.WHITE)
	_orders.create_order("B", _suit(), 250, Color.WHITE)
	var lf: float = _desk.load_factor()
	_check(lf > 0.8 and lf < 1.0, "two suits queued ≈ two shifts of work (%.2f)" % lf)
	_orders.create_order("C", _suit(), 250, Color.WHITE)
	_check(_desk.load_factor() >= 1.0, "three suits queued = swamped")
	_check(_desk.planned_walk_ins() == 0, "no walk-ins planned while swamped")
	_check(_desk.next_arrival().is_empty(), "nobody walks in while swamped")


func _due_days() -> void:
	_orders.active.clear()
	var due: int = _desk.suggest_due_day(3)
	_check(due == 3, "an idle opening week gives a relaxed due day (day %d)" % due)
	_check(_desk.suggest_due_day(3, true) == 2, "rush orders are due tomorrow")
	_orders.create_order("A", _suit(), 250, Color.WHITE)
	_orders.create_order("B", _suit(), 250, Color.WHITE)
	var busy: int = _desk.suggest_due_day(3)
	_check(busy > due, "a busy book pushes the due day out (day %d)" % busy)
	_orders.active.clear()


func _holds() -> void:
	_desk.plan_day()
	_desk.booked = true
	_clock.set("_elapsed", 1000.0)  # end of shift: any plan is due
	_check(_desk.next_arrival().is_empty(), "the Fully Booked sign holds walk-ins")
	var pref = load(PREF_SCRIPT).new()
	pref.display_name = "Ms. Booked"
	var cust: Node = load(CUST_SCENE).instantiate()
	root.add_child(cust)
	cust.preference = pref
	var day: int = _desk.book_appointment(cust)
	_check(day >= 2, "an appointment is booked for a later day (day %d)" % day)
	_shift.day = day
	_desk.plan_day()
	var arrival: Dictionary = _desk.next_arrival()
	_check(arrival.get("kind", "") == "appointment", "appointments come even when booked")
	_check(_desk.appointments.is_empty(), "the appointment is used up")
	_desk.booked = false
	var two: Array = []
	for i in 3:
		two.append(_desk.book_appointment(cust))
	_check(two[0] == two[1] and two[2] > two[1], "at most two fittings are booked per day")
	var cal: Array = _desk.calendar(5)
	_check(cal.size() == 5 and int(cal[0]["day"]) == _shift.day, "calendar lists the next days")
	_desk.appointments.clear()
	cust.queue_free()
	_shift.day = 1


func _saying_no() -> void:
	var rep: Node = root.get_node("Reputation")
	var cust: Node = load(CUST_SCENE).instantiate()
	root.add_child(cust)
	var pref = load(PREF_SCRIPT).new()
	pref.display_name = "Mr. Tight"
	pref.budget = 40  # nothing suitable costs this little
	cust.preference = pref
	_check(not _desk.brief_feasible(pref), "a tiny budget is an impossible brief")
	var before: int = rep.points
	_check(_desk.decline(cust) == 2 and rep.points == before + 2, "honest decline: +2 rep")
	pref.budget = 900
	_check(_desk.brief_feasible(pref), "a normal brief is doable")
	_check(_desk.decline(cust) == 0, "a plain no costs nothing")
	before = rep.points
	_desk.refer_to_rival(cust)
	_check(_desk.rival_goodwill == 1 and rep.points == before + 1, "referral: goodwill + rep")
	cust.queue_free()


func _picky() -> void:
	var order = load("res://data/scripts/suit_order.gd").new()
	order.price = 400
	order.design = {JACKET: {}}
	order.fill_part(JACKET, 0.7, 1.0)
	_check(order.payout() == 400, "0.7 work pays in full normally")
	order.picky = true
	_check(order.payout() < 400, "a picky client pays less for 0.7 work (%d)" % order.payout())
	order.filled.clear()
	order.fill_part(JACKET, 1.0, 1.0)
	_check(
		order.payout() == 600, "perfect work for a picky client: double tip (%d)" % order.payout()
	)


## The shop serves one customer at a time: nobody new is let in, and the fitting mirror
## can never be double-booked.
func _one_at_a_time() -> void:
	var mgr: Node = get_first_node_in_group("customer_manager")
	if mgr == null:
		_check(false, "main.tscn has a customer manager")
		return
	mgr.debug_clear_customers()
	await process_frame
	mgr.debug_call_shopper()
	mgr.debug_call_shopper()
	var shoppers: Array = _shoppers(mgr)
	_check(shoppers.size() == 1, "a second shopper is never sent in while one is served")
	if shoppers.is_empty():
		return
	var first: Node = shoppers[0]
	first.offer_greeting()
	first.begin_fitting()  # on their way to the mirror
	var second: Node = load(CUST_SCENE).instantiate()
	mgr.add_child(second)
	second.manager = mgr
	second.offer_greeting()
	second.begin_fitting()
	_check(mgr.get("_fitting") == first, "the mirror stays with whoever got there first")
	_check(second.serving, "the turned-away customer goes back to waiting")
	mgr.debug_clear_customers()


## Every customer in the world carrying a brief (i.e. a shopper, not street dressing).
func _shoppers(mgr: Node) -> Array:
	var out: Array = []
	for child in mgr.get_children():
		if child.get("preference") != null:
			out.append(child)
	return out


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_front_desk: ALL PASS")
		quit(0)
	else:
		print("test_front_desk: %d FAILURE(S)" % _failures.size())
		quit(1)
