extends SceneTree

## Headless test for "the customer calls and the suit isn't ready": the apology outcomes
## (a stranger moved to tomorrow / lost, a regular who lets it pass, an event suit that
## can't wait, no second chances), and a real collector at the counter — left standing
## until he walks out, and one whose suit is finished while he waits.
##   godot --headless --path . --script res://tools/test_pickup.gd
## Exit code is non-zero on any failed assertion.

const JACKET := 2  # Enums.GarmentType.JACKET
const COLLECT := 3  # Customer.Mode.COLLECT

var _failures: Array[String] = []
var _orders: Node
var _rep: Node
var _cfg: Resource
var _wait: GDScript  # CustomerWait, loaded once the autoloads exist


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	_orders = root.get_node("Orders")
	_rep = root.get_node("Reputation")
	_cfg = root.get_node("Config").data
	_wait = load("res://entities/customer/customer_wait.gd")
	var ui: Node = root.get_node("UI")
	if ui.newspaper != null:
		ui.newspaper.close()
	_rep.points = 100

	_apologies()
	_coffee_on_the_bill()
	await _left_standing()
	await _finished_in_time()
	_finish()


## A customer welcomed with a coffee adds a small thank-you to the bill.
func _coffee_on_the_bill() -> void:
	var plain := _order("Mr. Plain")
	var treated := _order("Mr. Treated")
	treated.coffee = 1.0
	for order: Resource in [plain, treated]:
		order.fill_part(JACKET, 0.7, 0.7)  # decent work: no tip of its own
	var extra: int = treated.payout_breakdown()["tip"] - plain.payout_breakdown()["tip"]
	_check(extra == roundi(300 * _cfg.coffee_tip_share), "a welcome coffee tips on the bill")
	_orders.active.erase(plain)
	_orders.active.erase(treated)


func _order(who: String) -> Resource:
	var suit := {"fabric": 0, "pattern": 0, "color": 0, "style_idx": 0}
	return _orders.create_order(who, {JACKET: suit}, 300, Color.WHITE)


func _apologies() -> void:
	var today: int = root.get_node("Shift").day
	# A stranger who agrees: tomorrow, late, the usual late penalty.
	_cfg.reschedule_chance = 1.0
	var order := _order("Mr. Stranger")
	var before: int = _rep.points
	_check(_wait.apologise(order) == "moved", "a stranger can be moved to tomorrow")
	_check(order.late and order.due_day == today + 1, "moved: late, due tomorrow")
	_check(_rep.points == before - _cfg.late_rep_loss, "moved: the usual late penalty")
	# ...but only once.
	before = _rep.points
	_check(_wait.apologise(order) == "lost", "no second chance on a late order")
	_check(not _orders.active.has(order), "lost: the order is gone")
	_check(_rep.points == before - _cfg.apologised_rep_loss, "lost after an apology: softened")

	# A stranger who won't.
	_cfg.reschedule_chance = 0.0
	order = _order("Ms. Huff")
	_check(_wait.apologise(order) == "lost", "a stranger may refuse")

	# A regular lets it pass, whatever the odds.
	var clientele: Node = root.get_node("Clientele")
	var first := _order("Mr. Regular")
	first.fill_part(JACKET, 1.0, 1.0)
	root.get_node("EventBus").order_fulfilled.emit(first, 0)
	_orders.active.erase(first)
	_check(clientele.loyalty("Mr. Regular") > 0, "(setup) Mr. Regular is a regular")
	order = _order("Mr. Regular")
	before = _rep.points
	_check(_wait.apologise(order) == "regular", "a regular always agrees")
	_check(order.late and _rep.points == before, "regular: tomorrow, and no standing lost")

	# A suit for an event held today can't wait until tomorrow.
	_cfg.reschedule_chance = 1.0
	order = _order("Lady Gala")
	order.event_id = "event_autumn_gala"
	root.get_node("Shift").day = root.get_node("News").event_day(order.event_id)
	_check(not _wait.can_reschedule(order), "an event suit can't move past the event")
	_check(_wait.apologise(order) == "event", "event: the order is lost")
	root.get_node("Shift").day = today
	_cfg.reschedule_chance = 0.6


## Nobody speaks to him: the meter runs out, he walks, and it costs more than a no-show.
func _left_standing() -> void:
	_cfg.collector_patience_s = 1.0
	var order := _order("Mr. Ignored")
	var before: int = _rep.points
	var cust := await _send_collector(order)
	_check(cust != null and cust.takeover != null, "not ready: he waits at the counter")
	await create_timer(2.0).timeout
	_check(not _orders.active.has(order), "left standing: the order is lost")
	var loss: int = _cfg.expired_rep_loss + _cfg.ignored_rep_loss
	_check(_rep.points == before - loss, "left standing: it costs extra standing")


## The suit is finished while he waits: the wait turns into an ordinary collection.
func _finished_in_time() -> void:
	_cfg.collector_patience_s = 60.0
	var order := _order("Mr. Patient")
	var cust := await _send_collector(order)
	_check(cust != null and cust.takeover.value() > 0.9, "a fresh wait starts full")
	# A coffee in his hand: the wait starts over, and he's readier to forgive.
	cust.takeover.soothe(1.0)
	_check(cust.takeover.goodwill > 0.0, "a coffee buys goodwill")
	_check(is_equal_approx(cust.takeover.value(), 1.0), "and the wait starts over")
	_orders.debug_make_ready(order)
	await process_frame
	await process_frame
	var ready: bool = _orders.is_ready(order)
	_check(not ready or cust.get("_mode") == COLLECT, "finished while waiting: he collects")
	_check(ready, "(setup) the order was made ready")


## Send `order`'s customer in and wait (up to 30 s) until he reaches the counter.
func _send_collector(order: Resource) -> Node:
	var manager: Node = get_first_node_in_group("customer_manager")
	manager.debug_send_collector(order)
	for _i in 300:
		await create_timer(0.1).timeout
		for cust in get_nodes_in_group("customer"):
			if cust.collect_order == order and cust.takeover != null:
				return cust
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_pickup: ALL PASS")
		quit(0)
	else:
		print("test_pickup: %d FAILURE(S)" % _failures.size())
		quit(1)
