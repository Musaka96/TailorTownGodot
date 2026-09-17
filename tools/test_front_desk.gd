extends SceneTree

## Headless test for the customer director (globals/front_desk.gd, docs/CUSTOMERS.md):
## workload estimate, daily plan by stage, swamped / booked holds, realistic due days,
## appointments, rival referrals, honest declines, picky payouts and the calendar.
##   godot --headless --path . --script res://tools/test_front_desk.gd

const SHIRT := 0
const PANTS := 1
const JACKET := 2
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"

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
	var cust: Node = load("res://entities/customer/customer.tscn").instantiate()
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
	var cust: Node = load("res://entities/customer/customer.tscn").instantiate()
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
	_check(order.payout() == 600, "perfect work for a picky client: double tip (%d)" % order.payout())


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
