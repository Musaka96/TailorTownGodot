extends Node

## Autoloaded as "Orders". Tracks confirmed bespoke orders through their whole
## life: created at the mirror → pieces checked off as they are made → READY once
## every piece is done → collected and paid when the customer returns on the
## deadline day (or expired if the deadline passes unfinished).
##
## Kept decoupled: the suit-builder calls create_order(); the mannequin calls
## submit() when a suit is packaged, and each piece is matched against the open
## orders; the CustomerManager listens for order_due to send the customer back,
## then calls collect() or expire(). The HUD reacts to EventBus signals.

## A made piece must match an order's slot at least this well to be checked off —
## below it, the piece isn't wasted on the wrong order (the suit is handed back).
const PIECE_MIN := 0.34
## Fallback deadline range in shop days (Config.deadline_min/max_days win).
const DAYS_MIN := 1
const DAYS_MAX := 4
## When during the due day's shift (fraction of the shift) the customer may walk in.
const ARRIVE_MIN := 0.15
const ARRIVE_MAX := 0.6

var active: Array[SuitOrder] = []

var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Deadlines count SHOP days: on an order's due day, once the shift reaches the
## order's arrival time, the customer is sent back (order_due). Nothing ticks while the
## shop is closed or the tutorial is running.
func _process(_delta: float) -> void:
	if active.is_empty() or Shift == null or DayNight == null:
		return
	if not Shift.is_open() or not DayNight.running:
		return
	if Tutorial != null and Tutorial.is_active():
		return
	var today: int = Shift.day
	var progress: float = DayNight.progress()
	for order in active:
		if order.due_fired:
			continue
		if order.due_day < today or (order.due_day == today and progress >= order.arrive_at):
			order.due_fired = true
			EventBus.order_due.emit(order)


func create_order(
	customer_name: String,
	design: Dictionary,
	price: int,
	skin: Color,
	hair_index := 0,
	hair_color := Color(0.14, 0.11, 0.09),
	flags := {}
) -> SuitOrder:
	var order := SuitOrder.new()
	order.id = _next_id
	_next_id += 1
	order.customer_name = customer_name
	order.design = design.duplicate(true)
	order.price = price
	order.skin = skin
	order.hair_index = hair_index
	order.hair_color = hair_color
	order.rush = bool(flags.get("rush", false))
	order.picky = bool(flags.get("picky", false))
	if FrontDesk != null:
		# A due day the shop can realistically meet (rush orders: tomorrow).
		order.due_day = FrontDesk.suggest_due_day(order.required_types().size(), order.rush)
	else:
		var lo: int = Config.data.deadline_min_days if Config.data != null else DAYS_MIN
		var hi: int = Config.data.deadline_max_days if Config.data != null else DAYS_MAX
		order.due_day = _today() + _rng.randi_range(lo, maxi(lo, hi))
	_tag_event(order, int(flags.get("occasion", -1)))
	order.deadline_days = order.due_day - _today()
	order.arrive_at = _rng.randf_range(ARRIVE_MIN, ARRIVE_MAX)
	active.append(order)
	EventBus.order_created.emit(order)
	return order


## An order taken in a city event's run-up for that event's occasion is for the event:
## tag it and make sure it's due by the event day (it's no use to them afterwards).
func _tag_event(order: SuitOrder, occasion: int) -> void:
	if occasion < 0 or News == null:
		return
	var ev: NewsEvent = News.event_for(occasion, _today())
	if ev == null or ev.event_day <= _today():
		return
	order.event_id = ev.id
	order.due_day = mini(order.due_day, ev.event_day)


## Check a freshly-sewn piece off the first open order that still needs a matching
## piece, stamping the piece with that order's number. Returns the order it filled (or
## null if the piece fits no open order — a spare/speculative piece).
func register_piece(piece: Node) -> SuitOrder:
	if piece == null:
		return null
	var part := {"material": piece.get("material"), "quality": float(piece.quality)}
	var order := _first_open_for(int(piece.garment_type), part)
	if order == null:
		return null
	piece.set("order_id", order.id)
	_fill(order, int(piece.get("garment_type")), part)
	return order


## Check a piece made *for* a particular order (the apprentice's work) off that order,
## if it still needs one; otherwise it falls back to the first order it fits.
func register_piece_for(piece: Node, order: SuitOrder) -> SuitOrder:
	var t := int(piece.get("garment_type"))
	if order != null and order.state == SuitOrder.State.OPEN and order.needs_part(t):
		var part := {"material": piece.get("material"), "quality": float(piece.quality)}
		piece.set("order_id", order.id)
		_fill(order, t, part)
		return order
	return register_piece(piece)


## Assemble the order with this number: mark it READY (the suit has been built at the
## mannequin) so the customer can return to collect it. Returns the order, or null if
## the id isn't an open order whose pieces are all made.
func assemble(order_id: int) -> SuitOrder:
	if order_id <= 0:
		return null
	for order in active:
		if order.id == order_id and order.state == SuitOrder.State.OPEN and order.is_complete():
			order.state = SuitOrder.State.READY
			EventBus.order_ready.emit(order)
			return order
	return null


## The open order with this number, or null.
func by_id(order_id: int) -> SuitOrder:
	for order in active:
		if order.id == order_id:
			return order
	return null


## The customer arrived and the order is READY: pay out (any cloth bought on account is
## settled from it first) and clear it.
func collect(order: SuitOrder) -> int:
	if not active.has(order):
		return 0
	var bill := order.payout_breakdown()
	var payout := int(bill["total"])
	GameState.earn(payout)
	var settled := GameState.settle_account()
	if UI != null:
		var note := "Order #%d paid: $%d" % [order.id, payout]
		if int(bill["tip"]) > 0:
			note += "  (incl. $%d tip — beautiful work!)" % int(bill["tip"])
		elif order.late:
			note += "  (late: part pay)"
		if settled > 0:
			note += "  · $%d cloth account settled" % settled
		UI.toast(note)
	active.erase(order)
	EventBus.order_fulfilled.emit(order, payout)
	return payout


## The customer came on the due day but the suit wasn't ready. The first time they
## kindly come back tomorrow (the order will pay less); returns false if the grace day
## was already used (the caller should expire() it).
## `penalise` false skips the standing it normally costs (a regular lets it pass).
func grant_grace(order: SuitOrder, penalise := true) -> bool:
	if not can_reschedule(order):
		return false
	order.late = true
	order.due_day = _today() + 1
	order.arrive_at = _rng.randf_range(ARRIVE_MIN, ARRIVE_MAX)
	order.due_fired = false
	if penalise:
		EventBus.order_late.emit(order)
	return true


## Could this order's customer call again tomorrow instead? Not twice, and never when
## tomorrow is past the city event the suit is for.
func can_reschedule(order: SuitOrder) -> bool:
	if not active.has(order) or order.late:
		return false
	if order.event_id != "" and News != null:
		var held: int = News.event_day(order.event_id)
		if held > 0 and _today() + 1 > held:
			return false
	return true


## The player apologises to a customer whose suit isn't ready. Returns what came of it:
##   "regular"  a regular — tomorrow, and no hard feelings (no standing lost)
##   "moved"    agreed to call again tomorrow (the usual late penalty)
##   "event"    it was for an event that can't wait — the order is lost (softened)
##   "lost"     won't come back — the order is lost (softened)
## `goodwill` is added to the stranger's chance (a coffee in their hand helps).
func apologise(order: SuitOrder, goodwill := 0.0) -> String:
	if order == null or not active.has(order):
		return "lost"
	if can_reschedule(order):
		if Clientele != null and Clientele.loyalty(order.customer_name) > 0:
			grant_grace(order, false)
			return "regular"
		var chance: float = Config.data.reschedule_chance if Config.data != null else 0.6
		if _rng.randf() < chance + goodwill:
			grant_grace(order)
			return "moved"
	var for_event := order.event_id != "" and not order.late
	order.apologised = true
	expire(order)
	return "event" if for_event else "lost"


## The customer was left standing until they walked out: the order is lost, and it stings.
func walk_out(order: SuitOrder) -> void:
	if order == null:
		return
	order.ignored = true
	expire(order)


## The deadline (and grace day) passed with the order unfinished: it is lost, no payment.
func expire(order: SuitOrder) -> void:
	if not active.has(order):
		return
	active.erase(order)
	EventBus.order_expired.emit(order)


## Empty the order book (new game / before a load) and tell the views.
func clear() -> void:
	active.clear()
	EventBus.orders_cleared.emit()


func is_ready(order: SuitOrder) -> bool:
	return order != null and order.state == SuitOrder.State.READY


# --- Save / load -----------------------------------------------------------


## Snapshot the open order book for a save file.
func save_state() -> Array:
	var out: Array = []
	for order in active:
		(
			out
			. append(
				{
					"id": order.id,
					"customer_name": order.customer_name,
					"design": order.design.duplicate(true),
					"price": order.price,
					"skin": order.skin,
					"hair_index": order.hair_index,
					"hair_color": order.hair_color,
					"deadline_days": order.deadline_days,
					"due_day": order.due_day,
					"arrive_at": order.arrive_at,
					"late": order.late,
					"rush": order.rush,
					"picky": order.picky,
					"event_id": order.event_id,
					"state": order.state,
					"filled": order.filled.duplicate(true),
				}
			)
		)
	return out


## Rebuild the order book from a save and refresh the board. Any order already
## past its deadline re-fires order_due (its due_fired stays false), so the
## returning-customer flow resumes cleanly after loading.
func restore(saved: Array) -> void:
	clear()
	_next_id = 1
	for d: Dictionary in saved:
		var order := SuitOrder.new()
		order.id = int(d.get("id", _next_id))
		_next_id = maxi(_next_id, order.id + 1)
		order.customer_name = str(d.get("customer_name", "Customer"))
		order.design = (d.get("design", {}) as Dictionary).duplicate(true)
		order.price = int(d.get("price", 0))
		order.skin = d.get("skin", Color(0.87, 0.72, 0.60))
		order.hair_index = int(d.get("hair_index", 0))
		order.hair_color = d.get("hair_color", Color(0.14, 0.11, 0.09))
		order.deadline_days = int(d.get("deadline_days", 3))
		# Older saves stored a real-time countdown; map it onto shop days.
		var fallback := _today() + maxi(0, int(ceil(float(d.get("days_left", 1.0)))) - 1)
		order.due_day = int(d.get("due_day", fallback))
		order.arrive_at = float(d.get("arrive_at", 0.4))
		order.late = bool(d.get("late", false))
		order.rush = bool(d.get("rush", false))
		order.picky = bool(d.get("picky", false))
		order.event_id = str(d.get("event_id", ""))
		order.state = int(d.get("state", SuitOrder.State.OPEN))
		order.filled = (d.get("filled", {}) as Dictionary).duplicate(true)
		active.append(order)
		EventBus.order_created.emit(order)
		if order.state == SuitOrder.State.READY:
			EventBus.order_ready.emit(order)


# --- Debug helpers (used by the F3 debug menu) -----------------------------


## Create a random valid order (a full jacket/shirt/pants brief).
func debug_add_random() -> SuitOrder:
	const NAMES := ["Mr. Rossi", "Ms. Byrne", "Dr. Vance", "Mr. Okafor", "Ms. Ito", "Mr. Kane"]
	var design := {}
	for t in [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]:
		var fabs := Enums.fabrics_for(t)
		var pats := Enums.patterns_for(t)
		var cols := MaterialFactory.colors_for(t)
		design[t] = {
			"fabric": fabs[_rng.randi() % fabs.size()],
			"pattern": pats[_rng.randi() % pats.size()],
			"color": cols[_rng.randi() % cols.size()],
			"style_idx": 0,
		}
	var skin := Color(
		0.7 + _rng.randf() * 0.2, 0.6 + _rng.randf() * 0.15, 0.5 + _rng.randf() * 0.15
	)
	return create_order(
		NAMES[_rng.randi() % NAMES.size()], design, Pricing.suit_quote(design), skin
	)


## Instantly finish and pay out an order (fills every piece at full quality).
func debug_complete(order: SuitOrder) -> void:
	if order == null or not active.has(order):
		return
	for t in order.required_types():
		if not order.is_part_done(t):
			order.fill_part(t, 1.0, 1.0)
			EventBus.order_part_filled.emit(order, t)
	order.state = SuitOrder.State.READY
	EventBus.order_ready.emit(order)
	collect(order)


## Mark an order READY without paying it out (every missing piece filled at full quality),
## so its suit can be handed over by hand.
func debug_make_ready(order: SuitOrder) -> void:
	if order == null or not active.has(order):
		return
	for t in order.required_types():
		if not order.is_part_done(t):
			order.fill_part(t, 1.0, 1.0)
			EventBus.order_part_filled.emit(order, t)
	if order.state != SuitOrder.State.READY:
		order.state = SuitOrder.State.READY
		EventBus.order_ready.emit(order)


## The first order nobody is on their way to collect yet — or a fresh random one.
func debug_pickup_candidate() -> SuitOrder:
	for order in active:
		if not order.due_fired:
			return order
	return debug_add_random()


func debug_complete_first() -> void:
	if not active.is_empty():
		debug_complete(active[0])


func debug_complete_all() -> void:
	for order in active.duplicate():
		debug_complete(order)


func debug_expire_first() -> void:
	if not active.is_empty():
		expire(active[0])


# --- Internals -------------------------------------------------------------


func _fill(order: SuitOrder, garment_type: int, part: Dictionary) -> void:
	var score := order.part_match(garment_type, part)
	var quality := clampf(float(part.get("quality", 1.0)), 0.0, 1.0)
	order.fill_part(garment_type, score, quality)
	EventBus.order_part_filled.emit(order, garment_type)
	# All pieces made — but NOT ready yet: the player must assemble them into a suit at
	# the mannequin, which is what flips the order to READY (see assemble()).
	if order.is_complete():
		EventBus.order_pieces_ready.emit(order)


## First open order (FIFO) that still needs this garment type and is matched well.
func _first_open_for(garment_type: int, part: Dictionary) -> SuitOrder:
	for order in active:
		if order.state != SuitOrder.State.OPEN:
			continue
		if order.needs_part(garment_type) and order.part_match(garment_type, part) >= PIECE_MIN:
			return order
	return null


func _today() -> int:
	return Shift.day if Shift != null else 1
