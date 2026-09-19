extends SceneTree

## Headless smoke test for reputation + newspapers. Boots main.tscn so the News and
## Reputation autoloads run their real signal wiring, then asserts the day-1 edition
## compiled, a fashion trend is set, and reputation moves the right way on a great
## (on-trend) order and on a missed deadline.
##   godot --headless --path . --script res://tools/test_news.gd
## Exit code is non-zero on any failed assertion.

const JACKET := 2  # Enums.GarmentType.JACKET
const PINSTRIPE := 1  # Enums.Pattern.PINSTRIPE

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var news: Node = root.get_node_or_null("News")
	var rep: Node = root.get_node_or_null("Reputation")
	var bus: Node = root.get_node_or_null("EventBus")
	_check(news != null and rep != null and bus != null, "News + Reputation + EventBus present")
	if news == null or rep == null or bus == null:
		_finish()
		return

	_check(not news.current_edition.is_empty(), "day-1 edition compiled")
	_check(news.current_fashion != null, "a fashion trend is set")
	_check(rep.points == 0 and rep.tier() == 0, "starts Unknown at 0 points")

	# A flawless pinstripe jacket: base + craft + delight + follow-the-trend bonus.
	var order: Resource = load("res://data/scripts/suit_order.gd").new()
	order.design = {JACKET: {"fabric": 0, "pattern": PINSTRIPE, "color": 0, "style_idx": 0}}
	order.price = 300
	order.fill_part(JACKET, 1.0, 1.0)
	_check(news.fashion_matches(order.design), "pinstripe order matches the trend")

	var before: int = rep.points
	bus.order_fulfilled.emit(order, order.payout())
	await process_frame
	_check(rep.points > before, "reputation rose on a great order")

	var mark: int = rep.points
	bus.order_expired.emit(order)
	await process_frame
	_check(rep.points < mark, "reputation fell on an expired order")

	await _every_day_has_a_paper(news)
	_finish()


## The paper never misses a morning (quiet-day fillers cover the gaps), and printing the
## same morning twice — the tutorial finishing, a mid-day load — keeps its stories.
func _every_day_has_a_paper(news: Node) -> void:
	var shift: Node = root.get_node("Shift")
	var first: int = news.current_edition.size()
	news.current_edition.clear()
	news.ensure_edition()
	_check(news.current_edition.size() == first, "day 1 reprints with the same stories")
	var empty_days: Array[int] = []
	for day in range(2, 15):
		shift.day = day
		news.ensure_edition()
		if news.current_edition.is_empty():
			empty_days.append(day)
		var fillers := 0
		for ev: Resource in news.current_edition:
			if str(ev.id).begins_with("filler_"):
				fillers += 1
		_check(fillers <= 1, "day %d runs at most one quiet-day piece" % day)
	_check(empty_days.is_empty(), "every day 2-14 has a paper (empty: %s)" % str(empty_days))
	shift.day = 1
	await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   - %s" % label)
	else:
		_failures.append(label)
		print("  FAIL - %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS - reputation + newspapers")
		quit(0)
	else:
		print("FAILED %d checks" % _failures.size())
		quit(1)
