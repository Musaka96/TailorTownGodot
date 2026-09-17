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
	hair_color := Color(0.14, 0.11, 0.09)
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
	var lo: int = Config.data.deadline_min_days if Config.data != null else DAYS_MIN
	var hi: int = Config.data.deadline_max_days if Config.data != null else DAYS_MAX
	order.deadline_days = _rng.randi_range(lo, maxi(lo, hi))
	order.due_day = _today() + order.deadline_days
	order.arrive_at = _rng.randf_range(ARRIVE_MIN, ARRIVE_MAX)
	active.append(order)
	EventBus.order_created.emit(order)
	return order


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
func grant_grace(order: SuitOrder) -> bool:
	if not active.has(order) or order.late:
		return false
	order.late = true
	order.due_day = _today() + 1
	order.arrive_at = _rng.randf_range(ARRIVE_MIN, ARRIVE_MAX)
	order.due_fired = false
	EventBus.order_late.emit(order)
	return true


## The deadline (and grace day) passed with the order unfinished: it is lost, no payment.
func expire(order: SuitOrder) -> void:
	if not active.has(order):
		return
	active.erase(order)
	EventBus.order_expired.emit(order)


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
	active.clear()
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
