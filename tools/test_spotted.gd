extends SceneTree

## Headless test for "best suit spotted". Boots main.tscn, then:
## - no city events until the social season opens (reputation + suits handed over);
## - a Party order taken in the Autumn Gala's run-up is tagged for it, due by the gala;
## - the first gala is kind: a rough suit worn there still earns a mention (+mention_bonus);
## - a flawless, on-trend suit collected in time wins: the morning after, the paper leads
##   with it and reputation rises by the event's spotted_bonus;
## - at the Guild Review a rough suit loses: the rival leads the paper, no bonus;
## - the tallies survive a save round-trip.
##   godot --headless --path . --script res://tools/test_spotted.gd

const JACKET := 2  # Enums.GarmentType.JACKET
const PARTY := 3  # Enums.Occasion.PARTY
const BUSINESS := 2  # Enums.Occasion.BUSINESS
const GALA := "event_autumn_gala"  # season day 5, Party, 4-day run-up
const GUILD := "event_guild_review"  # season day 11, Business, 3-day run-up

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

	# Before the shop is on its feet there is no season: no events, nothing to tag.
	_shift.day = 4
	_check(not _news.season_open(), "a new shop has no social season yet")
	_check(_news.event_for(PARTY, 4) == null, "so a party order is just a party order")
	_check(_news.upcoming_events(1).is_empty(), "and the calendar is clear")
	_rep.points = 40
	for i in 3:
		_bus.order_fulfilled.emit(_order("Mr Early", BUSINESS, 0.9), 100)
	_shift.day = 5
	_bus.shift_started.emit(12.0)
	_check(_news.season_open(), "known on the street with three suits out: the season opens")
	_check(_news.event_day(GALA) == 9, "the gala is four days off (day %d)" % _news.event_day(GALA))
	var first: Resource = _news.current_edition[0]
	_check(first.id == GALA, "and it leads that morning's paper: %s" % first.headline)
	_check(_news.event_for(BUSINESS, 5) == null, "business isn't the gala's occasion")
	var ev: Resource = _news.event_for(PARTY, 5)
	_check(ev != null and ev.id == GALA, "a party order in the run-up is for the gala")

	# The first gala is kind: a rough suit worn there still earns a line in the paper.
	var rough: Resource = _order("Mr Crump", PARTY, 0.5)
	_check(rough.event_id == GALA, "the order is tagged for the gala")
	_check(rough.due_day <= 9, "and due by the gala (day %d)" % rough.due_day)
	_check(not _news.judge(rough)["ok"], "a rough suit isn't fine enough for the lead")
	_shift.day = 8
	_bus.order_fulfilled.emit(rough, 100)
	_shift.day = 10
	var before: int = _rep.points
	_bus.shift_started.emit(12.0)
	var lead: Resource = _news.current_edition[0]
	_check(lead.id == "spotted_" + GALA, "the morning after, society leads the paper")
	_check("Mr Crump" in lead.body, "the rough suit gets its mention: %s" % lead.headline)
	_check(_rep.points - before == ev.mention_bonus, "reputation +%d" % ev.mention_bonus)

	# The same gala again (a fresh season), this time with a flawless suit in the room.
	_news.restore_seen({})
	_news.restore_season({"start": 11, "suits": 3})
	_shift.day = 12
	_bus.shift_started.emit(12.0)
	var win: Resource = _order("Mr Ashby", PARTY, 1.0)
	_check(_news.judge(win)["ok"], "a flawless on-trend suit makes the cut")
	rough = _order("Mr Crump", PARTY, 0.5)
	_shift.day = 14
	_bus.order_fulfilled.emit(win, 300)
	_bus.order_fulfilled.emit(rough, 100)
	var snap: Dictionary = _news.spotted_snapshot()
	_check(int(snap[GALA]["entered"]) == 2, "both entries counted")
	_check(str(snap[GALA]["best"]["name"]) == "Mr Ashby", "the flawless suit is the best")
	var season: Dictionary = _news.season_snapshot()
	_news.restore_spotted({})
	_news.restore_season({})
	_news.restore_spotted(snap)
	_news.restore_season(season)

	_shift.day = 16
	before = _rep.points
	_bus.shift_started.emit(12.0)
	lead = _news.current_edition[0]
	_check(lead.id == "spotted_" + GALA, "the morning after, the spotted story leads")
	_check("Best Suit" in lead.headline, "it is the special one: %s" % lead.headline)
	_check("Mr Ashby" in lead.body, "and it names the client")
	_check(_rep.points - before == ev.spotted_bonus, "reputation +%d" % ev.spotted_bonus)
	before = _rep.points
	_bus.shift_started.emit(12.0)
	_check(_rep.points == before, "reloading the same morning doesn't pay twice")

	# The Guild Review is not kind: a middling suit there and the rival takes the page.
	_shift.day = 19
	var meh: Resource = _order("Ms Vane", BUSINESS, 0.6)
	_check(meh.event_id == GUILD, "a business order in its run-up is for the guild review")
	_bus.order_fulfilled.emit(meh, 100)
	_shift.day = _news.event_day(GUILD) + 1
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
