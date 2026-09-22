extends SceneTree

## Headless test for customer taste (SuitTaste, BriefDirector, Clientele memory):
## quiet dislikes always leave a suit and are revealed at the mirror; regulars bring back
## their dislike and refuse a suit they already have; the town remark counts only suits
## collected on an earlier day; the cash guard drops a dislike you couldn't serve; the
## opening-week nudge only ever lands on an affordable brief the shelf can't serve; and
## brief_feasible accounts for dislikes. See docs/CUSTOMERS.md, "Taste".
##   godot --headless --path . --script res://tools/test_suit_taste.gd

const JACKET := 2
const PANTS := 1
const SHIRT := 0
const ORDER_SCRIPT := "res://data/scripts/suit_order.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const TASTE_SCRIPT := "res://data/scripts/suit_taste.gd"
const DIRECTOR_SCRIPT := "res://entities/customer/brief_director.gd"

var _failures: Array[String] = []
var _taste: GDScript
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	_taste = load(TASTE_SCRIPT)
	_rng.seed = 7
	root.get_node("Reputation").points = 0
	root.get_node("Clientele").reset()
	_quiet_always_leaves_room()
	_mirror_reveals()
	_regulars()
	_town()
	_cash_guard()
	_nudge()
	_feasible()
	_finish()


## Every brief, every tier, many rolls: a quiet dislike never leaves them nothing.
func _quiet_always_leaves_room() -> void:
	var rolled := 0
	var empty := 0
	for tier in 5:
		for o in 4:
			for s in 4:
				for _i in 30:
					var p = _pref(o, s)
					p.quiet_dislike = _taste.roll_quiet(p, _rng, tier)
					if p.quiet_dislike.is_empty():
						continue
					rolled += 1
					if _taste.options(p).is_empty() or _taste.fabrics(p).is_empty():
						empty += 1
	_check(rolled > 1000, "quiet dislikes roll for every brief (%d)" % rolled)
	_check(empty == 0, "a quiet dislike always leaves a suit (%d left none)" % empty)


func _mirror_reveals() -> void:
	var p = _pref(2, 1)  # Business · Classic: navy, charcoal or light grey
	p.quiet_dislike = {"kind": "color", "value": 0}
	var navy := _design(0, 0)
	var r: Dictionary = p.evaluate(navy)
	_check(not bool(r["suitable"]), "a quiet 'no navy' refuses a navy suit")
	_check(str(r["reasons"][0]).begins_with("Navy again"), "and says why (%s)" % r["reasons"][0])
	_check(p.quiet_known, "the quiet dislike is known once said")
	_check(p.taste_short().contains("No navy"), "the design screen shows it after")
	_check(bool(p.evaluate(_design(1, 0))["suitable"]), "charcoal still suits them")
	p.owned_suits = [[1, 0]]
	var again: Dictionary = p.evaluate(_design(1, 0))
	_check(not bool(again["suitable"]), "a suit they already have from you is refused")
	_check(str(again["reasons"][0]) == _taste.OWNED_LINE, "with the 'something new' line")


func _regulars() -> void:
	var clientele: Node = root.get_node("Clientele")
	var shift: Node = root.get_node("Shift")
	shift.reset_to(2)
	var cust := _customer("Ms. Byrne", _pref(2, 1))
	var byrne: Resource = cust.get("preference")
	byrne.set("quiet_dislike", {"kind": "pattern", "value": 1})  # no pinstripe
	byrne.set("quiet_known", true)
	clientele.note_customer(cust)
	var order := _order("Ms. Byrne", _design(1, 0))
	root.get_node("EventBus").order_fulfilled.emit(order, 250)
	_check(clientele.wardrobe("Ms. Byrne") == [[1, 0]], "a collected suit joins their wardrobe")
	var kept: Dictionary = clientele.kept_dislike("Ms. Byrne")
	_check(kept.get("kind") == "pattern" and bool(kept.get("known")), "their dislike is kept")
	# A later visit, a new brief: the director brings both back.
	shift.reset_to(5)
	var director: RefCounted = load(DIRECTOR_SCRIPT).new()
	var back = _pref(2, 1)
	back.display_name = "Ms. Byrne"
	director.shape(back, _rng, "Ms. Byrne", true)
	_check(back.quiet_dislike.get("value") == 1 and back.quiet_known, "a regular's dislike returns")
	_check(back.owned_suits == [[1, 0]], "and so do their past suits")
	_check(not [1, 0] in _taste.options(back), "charcoal plain is no longer an option")
	# Old saves (the people dictionary on its own) still load.
	var saved: Dictionary = clientele.save_state()
	clientele.restore(saved["people"])
	_check(clientele.is_known("Ms. Byrne"), "an old-format save restores")
	clientele.restore(JSON.parse_string(JSON.stringify(saved)))
	_check(clientele.wardrobe("Ms. Byrne") == [[1, 0]], "the wardrobe survives JSON as ints")
	cust.free()


func _town() -> void:
	var clientele: Node = root.get_node("Clientele")
	var shift: Node = root.get_node("Shift")
	var bus: Node = root.get_node("EventBus")
	clientele.reset()
	shift.reset_to(3)
	for i in 3:
		bus.order_fulfilled.emit(_order("Navy %d" % i, _design(0, 0)), 250)
	var same_day: Dictionary = clientele.worn_about_town(3, 5)
	_check(same_day.is_empty(), "suits collected today aren't seen about town yet")
	_check(int(clientele.worn_about_town(4, 5).get(0, 0)) == 3, "the next day, 3 navy are seen")
	_check(clientele.worn_about_town(9, 5).is_empty(), "after the window they're forgotten")
	shift.reset_to(4)
	root.get_node("GameState").money = 2000
	var director: RefCounted = load(DIRECTOR_SCRIPT).new()
	var remarks := 0
	for _i in 200:
		var p = _pref(2, 1)
		director.shape(p, _rng, "", true)
		if p.town_worn > 0:
			remarks += 1
			if p.dislikes_color != 0 or not p.taste_line().contains("navy"):
				_failures.append("town remark isn't about navy")
	# 3 worn: (3 - 1) * 0.2 = 40% of those with no dislike of their own.
	_check(
		remarks > 30 and remarks < 110, "about 40%% of newcomers remark on navy (%d/200)" % remarks
	)
	clientele.reset()


func _cash_guard() -> void:
	var state: Node = root.get_node("GameState")
	var shift: Node = root.get_node("Shift")
	shift.reset_to(10)  # past opening week: no nudging here
	var director: RefCounted = load(DIRECTOR_SCRIPT).new()
	state.money = 0
	var broke := 0
	for _i in 300:
		var p = _pref(_rng.randi() % 4, _rng.randi() % 4)
		director.shape(p, _rng, "", true)
		if not p.quiet_dislike.is_empty():
			broke += 1
	_check(broke == 0, "no quiet dislike you couldn't serve when broke (%d)" % broke)
	state.money = 2000
	var flush := 0
	for _i in 300:
		var p = _pref(_rng.randi() % 4, _rng.randi() % 4)
		director.shape(p, _rng, "", true)
		if not p.quiet_dislike.is_empty():
			flush += 1
	_check(flush > 20, "with money in hand quiet dislikes appear (%d/300)" % flush)


func _nudge() -> void:
	var state: Node = root.get_node("GameState")
	var shift: Node = root.get_node("Shift")
	shift.reset_to(1)
	state.money = 500
	var director: RefCounted = load(DIRECTOR_SCRIPT).new()
	var stock := {"0:0:0": {"fabric": 0, "pattern": 0, "color": 0, "have": 8.0}}
	_check(director.call("_nudge_open"), "the nudge is open on day 1 at tier 0")
	var moved := 0
	for _i in 60:
		var p = _pref(2, 1)  # navy plain worsted on the shelf fits it
		director.call("_nudge", p, _rng, "", stock)
		if p.occasion == 2 and p.style == 1:
			continue
		moved += 1
		var cut: int = _taste.cheapest_cut(p)
		if _taste.shelf_serves(p, stock) or cut < 0 or cut > 400:
			_failures.append("a nudged brief the shelf serves or the till can't pay for")
	_check(moved > 40, "most shelf-served briefs get nudged when asked (%d/60)" % moved)
	state.money = 50
	var p = _pref(2, 1)
	director.call("_nudge", p, _rng, "", stock)
	_check(p.occasion == 2 and p.style == 1, "with no money to spare the brief stays")
	shift.reset_to(4)
	_check(not director.call("_nudge_open"), "no nudging after opening week")


func _feasible() -> void:
	var desk: Node = root.get_node("FrontDesk")
	var p = _pref(2, 1)
	p.budget = 1000
	_check(desk.brief_feasible(p), "a normal brief is feasible")
	p.budget = 100
	_check(not desk.brief_feasible(p), "not under a tiny budget")
	p.budget = 1000
	p.owned_suits = []
	for c in [0, 1, 2]:
		for pat in [0, 1, 7, 8]:
			p.owned_suits.append([c, pat])
	_check(not desk.brief_feasible(p), "not when they already own every suit the brief allows")


# --- Helpers -------------------------------------------------------------------


func _pref(occasion: int, style: int) -> Resource:
	var p: Resource = load(PREF_SCRIPT).new()
	p.display_name = "Mr. Test"
	p.occasion = occasion
	p.style = style
	p.budget = 1000
	return p


func _design(color: int, pattern: int) -> Dictionary:
	var suit := {"fabric": 0, "color": color, "pattern": pattern}
	return {
		JACKET: suit.duplicate(),
		PANTS: suit.duplicate(),
		SHIRT: {"fabric": 5, "color": 10, "pattern": 0},
	}


func _customer(who: String, pref: Resource) -> Node:
	var holder := GDScript.new()
	holder.source_code = (
		"extends Node\nvar preference\nvar skin_color := Color.WHITE\nvar head_index := 0\n"
		+ 'var hair_index := 0\nvar hair_color := Color.BLACK\nvar eye_color := "brown"\n'
		+ 'var glasses := ""\nvar gender := 1\n'
	)
	holder.reload()
	var cust := Node.new()
	cust.set_script(holder)
	pref.display_name = who
	cust.set("preference", pref)
	return cust


func _order(who: String, design: Dictionary) -> Resource:
	var o: Resource = load(ORDER_SCRIPT).new()
	o.customer_name = who
	o.design = design
	o.price = 250
	return o


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("SUIT TASTE: all checks passed")
		quit(0)
	else:
		for f in _failures:
			print("  - " + f)
		print("SUIT TASTE: %d failed" % _failures.size())
		quit(1)
