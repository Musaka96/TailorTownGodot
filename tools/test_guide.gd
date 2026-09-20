extends SceneTree

## Headless test for the Guide (the post-tutorial goal chain). Boots grandpa's shop, then:
## - a fresh chain starts at `uncover`, and nothing done at Mr. Hemming's counts;
## - meeting a step's conditions moves on to the next;
## - a step that is already done when it is reached is passed over;
## - save_state/restore round-trips, and restore({}) starts again from the first goal;
## - the chain ends with the gala, handed over in time or missed.
##   godot --headless --path . --script res://tools/test_guide.gd

const JACKET := 2  # Enums.GarmentType.JACKET
const PARTY := 3  # Enums.Occasion.PARTY
const BUSINESS := 2  # Enums.Occasion.BUSINESS
const GALA := "event_autumn_gala"

var _failures: Array[String] = []
var _guide: Node
var _news: Node
var _rep: Node
var _bus: Node
var _shift: Node
var _orders: Node
var _reno: Node
var _places: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	root.add_child(load("res://scenes/world/grandpa/main_grandpa.tscn").instantiate())
	await process_frame
	await process_frame
	_guide = root.get_node_or_null("Guide")
	_news = root.get_node_or_null("News")
	_rep = root.get_node_or_null("Reputation")
	_bus = root.get_node_or_null("EventBus")
	_shift = root.get_node_or_null("Shift")
	_orders = root.get_node_or_null("Orders")
	_reno = root.get_node_or_null("Renovation")
	_places = root.get_node_or_null("Locations")
	if _guide == null:
		_check(false, "the Guide autoload exists")
		_finish()
		return
	_guide.next_delay = 0.0  # no lingering between goals in a test

	# Nothing done at Mr. Hemming's counts.
	_places.current = &"hemming"
	_guide.restore({})
	_bus.shift_started.emit(9.0)
	_order("Mr Lesson", BUSINESS)
	_check((_guide.save_state()["flags"] as Dictionary).is_empty(), "Hemming's sets no flags")
	_orders.clear()

	# A fresh chain at grandpa's starts with the dust sheets.
	_places.current = &"grandpa"
	_reno.reset()
	_news.restore_season({})
	_rep.points = 0
	_guide.restore({})
	_check(_guide.current_id() == "uncover", "a fresh chain starts at uncover")
	_reno.clear_spot("front_sheets")
	_reno.clear_spot("front_sheets")
	_check(_guide.current_id() == "uncover", "two sheets off of three isn't done")
	_reno.clear_spot("front_sheets")
	_check(_guide.current_id() == "first_order", "sheets off: on to the first order")

	_bus.shift_started.emit(9.0)
	_check(_guide.current_id() == "first_order", "the sign alone isn't an order")
	var first: Resource = _order("Mr Early", BUSINESS, false)
	_check(_guide.current_id() == "first_suit", "an order taken: on to the suit")

	# Out of order: the front room is tidied before the first suit is handed over...
	for id: String in ["front_sweep", "front_boards"]:
		for i in 3:
			_reno.clear_spot(id)
	_check(_guide.current_id() == "first_suit", "tidying early doesn't jump the queue")
	_bus.order_ready.emit(first)
	_check(_guide.current_id() == "first_suit", "ready on the rack isn't handed over")
	_bus.order_fulfilled.emit(first, 100)
	# ...so `tidy` is passed over without being shown.
	_check(_guide.current_id() == "builders", "tidy was already done: passed over")

	root.get_node("GameState").money = 5000
	_check(_reno.order("front_window"), "the builders take the job")
	_check(_guide.current_id() == "fashion", "builders rung: on to the fashion column")

	_news.ensure_edition()
	var plain: Resource = _order("Mr Plain", BUSINESS, false)
	_bus.order_fulfilled.emit(plain, 100)
	_check(_guide.current_id() == "fashion", "a suit off the trend doesn't count")
	var smart: Resource = _order("Mr Smart", BUSINESS)
	_check(_news.fashion_matches(smart.design), "the test suit follows the trend")
	_bus.order_fulfilled.emit(smart, 100)
	_check(_guide.current_id() == "name", "a suit in the trend: on to making a name")

	_rep.points = 40
	_check(_guide.current_id() == "name", "known and three suits out, but no paper yet")

	# Save round-trip; and a reset starts over, stopping where a flag was the only proof.
	var saved: Dictionary = _guide.save_state()
	_check(str(saved["step"]) == "name", "the save names the step")
	_check(int(saved["suits"]) == 3, "and counts the suits (%d)" % int(saved["suits"]))
	_guide.restore({})
	_check(_guide.current_id() == "fashion", "restore({}) restarts and skips what is done")
	_guide.restore(saved)
	_check(_guide.current_id() == "name", "restore puts the step back")
	_check((_guide.save_state()["flags"] as Dictionary).has("fashion"), "and the flags")

	_shift.day = 5
	_bus.shift_started.emit(9.0)
	_check(_news.season_open(), "the season opens the next morning")
	_check(_guide.current_id() == "gala", "and the gala is the goal")
	var at_gala: Dictionary = _guide.save_state()

	# Handed over in time: the chain is finished.
	var gown: Resource = _order("Mr Ashby", PARTY)
	_check(gown.event_id == GALA, "a party order in the run-up is for the gala")
	_check(_guide.current_id() == "gala", "taking the order isn't the end of it")
	_bus.order_fulfilled.emit(gown, 300)
	_check(_guide.is_finished(), "handed over in time: the chain is finished")
	_check(_guide.current_id() == "", "and there is no goal left")
	var done: Dictionary = _guide.save_state()
	_guide.restore(done)
	_check(_guide.is_finished(), "finished survives a save")

	# The other ending: the gala day passes without a suit there.
	_guide.restore(at_gala)
	_check(_guide.current_id() == "gala", "back before the gala")
	_shift.day = _news.event_day(GALA)
	_guide.refresh()
	_check(not _guide.is_finished(), "the gala day itself is still in time")
	_shift.day = _news.event_day(GALA) + 1
	_guide.refresh()
	_check(_guide.is_finished(), "the day after, the chain is finished")

	_finish()


## A one-jacket order, in the running trend's cloth or (on_trend false) well away from it.
func _order(who: String, occasion: int, on_trend := true) -> Resource:
	var trend: Resource = _news.current_fashion
	var pat: int = trend.fashion_pattern if trend != null and trend.fashion_pattern >= 0 else 0
	var fab: int = trend.fashion_fabric if trend != null and trend.fashion_fabric >= 0 else 0
	if not on_trend:
		pat += 1
		fab += 1
	var design := {JACKET: {"fabric": fab, "pattern": pat, "color": 0, "style_idx": 0}}
	return _orders.create_order(
		who, design, 300, Color.WHITE, 0, Color.BLACK, {"occasion": occasion}
	)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   - %s" % label)
	else:
		print("  FAIL - %s" % label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS - guide")
	else:
		print("FAILED %d check(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
