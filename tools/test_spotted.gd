extends SceneTree

## Headless test for "best suit spotted". Boots main.tscn, then:
## - a Party order taken in the Autumn Gala's run-up is tagged for it, due by the gala;
## - a flawless, on-trend suit collected in time wins: the morning after, the paper leads
##   with it and reputation rises by the event's spotted_bonus;
## - at the Guild Review a rough suit loses: the rival leads the paper, no bonus;
## - the tallies survive a save round-trip.
##   godot --headless --path . --script res://tools/test_spotted.gd

const JACKET := 2  # Enums.GarmentType.JACKET
const PARTY := 3  # Enums.Occasion.PARTY
const BUSINESS := 2  # Enums.Occasion.BUSINESS
const GALA := "event_autumn_gala"  # day 6, Party, 3-day run-up
const GUILD := "event_guild_review"  # day 10, Business, 3-day run-up

var _failures: Array[String] = []
var _news: Node
var _rep: Node
var _bus: Node
var _shift: Node
var _orders: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	root.add_child(load("res://main.tscn").instantiate())
	await process_frame
	await process_frame
	_news = root.get_node_or_null("News")
	_rep = root.get_node_or_null("Reputation")
	_bus = root.get_node_or_null("EventBus")
	_shift = root.get_node_or_null("Shift")
	_orders = root.get_node_or_null("Orders")

	_shift.day = 2
	_check(_news.event_for(PARTY, 2) == null, "day 2 is before the gala's run-up")
	_check(_news.event_for(BUSINESS, 4) == null, "business isn't the gala's occasion")
	_shift.day = 4
	var ev: Resource = _news.event_for(PARTY, 4)
	_check(ev != null and ev.id == GALA, "a party order on day 4 is for the gala")

	var win: Resource = _order("Mr Ashby", PARTY, 1.0)
	_check(win.event_id == GALA, "the order is tagged for the gala")
	_check(win.due_day <= 6, "and due by the gala (day %d)" % win.due_day)
	var rough: Resource = _order("Mr Crump", PARTY, 0.5)
	_check(not _news.judge(rough)["ok"], "a rough suit isn't fine enough")
	_check(_news.judge(win)["ok"], "a flawless on-trend suit makes the cut")

	_shift.day = 5
	_bus.order_fulfilled.emit(win, 300)
	_bus.order_fulfilled.emit(rough, 100)
	var snap: Dictionary = _news.spotted_snapshot()
	_check(int(snap[GALA]["entered"]) == 2, "both entries counted")
	_check(str(snap[GALA]["best"]["name"]) == "Mr Ashby", "the flawless suit is the best")
	_news.restore_spotted({})
	_news.restore_spotted(snap)

	_shift.day = 7
	var before: int = _rep.points
	_bus.shift_started.emit(12.0)
	var lead: Resource = _news.current_edition[0]
	_check(lead.id == "spotted_" + GALA, "the morning after, the spotted story leads")
	_check("Mr Ashby" in lead.body, "it names the client: %s" % lead.headline)
	_check(_rep.points - before == ev.spotted_bonus, "reputation +%d" % ev.spotted_bonus)
	before = _rep.points
	_bus.shift_started.emit(12.0)
	_check(_rep.points == before, "reloading the same morning doesn't pay twice")

	_shift.day = 8
	var meh: Resource = _order("Ms Vane", BUSINESS, 0.6)
	_check(meh.event_id == GUILD, "a business order on day 8 is for the guild review")
	_bus.order_fulfilled.emit(meh, 100)
	_shift.day = 11
	before = _rep.points
	_bus.shift_started.emit(12.0)
	lead = _news.current_edition[0]
	_check(lead.id == "spotted_" + GUILD, "the rival story leads after the review")
	_check("Pinch & Pleat" in lead.headline, "the rival gets the glory: %s" % lead.headline)
	_check(_rep.points == before, "no bonus when the rival wins")

	_finish()


## A one-jacket order in the running trend's pattern, made at `quality`.
func _order(who: String, occasion: int, quality: float) -> Resource:
	var trend: Resource = _news.current_fashion
	var pat: int = trend.fashion_pattern if trend != null and trend.fashion_pattern >= 0 else 0
	var fab: int = trend.fashion_fabric if trend != null and trend.fashion_fabric >= 0 else 0
	var design := {JACKET: {"fabric": fab, "pattern": pat, "color": 0, "style_idx": 0}}
	var order: Resource = _orders.create_order(
		who, design, 300, Color.WHITE, 0, Color.BLACK, {"occasion": occasion}
	)
	order.fill_part(JACKET, 1.0, quality)
	return order


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   - %s" % label)
	else:
		print("  FAIL - %s" % label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS - best suit spotted")
	else:
		print("FAILED %d check(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
