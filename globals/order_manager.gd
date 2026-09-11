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
## Deadline range, in in-game days.
const DAYS_MIN := 1
const DAYS_MAX := 5
## Fallback if Config has no seconds_per_day (real seconds per in-game day).
const SECONDS_PER_DAY_DEFAULT := 120.0

var active: Array[SuitOrder] = []

var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if active.is_empty():
		return
	var per_day := _seconds_per_day()
	for order in active:
		order.days_left = maxf(order.days_left - delta / per_day, 0.0)
		if order.days_left <= 0.0 and not order.due_fired:
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
	order.deadline_days = _rng.randi_range(DAYS_MIN, DAYS_MAX)
	order.days_left = float(order.deadline_days)
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


## The customer arrived and the order is READY: pay out and clear it.
func collect(order: SuitOrder) -> int:
	if not active.has(order):
		return 0
	var payout := order.payout()
	GameState.earn(payout)
	active.erase(order)
	EventBus.order_fulfilled.emit(order, payout)
	return payout


## The deadline passed with the order unfinished: it is lost, no payment.
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
					"days_left": order.days_left,
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
		order.days_left = float(d.get("days_left", 3.0))
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
		NAMES[_rng.randi() % NAMES.size()], design, _rng.randi_range(150, 450), skin
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


func _seconds_per_day() -> float:
	if Config.data != null and Config.data.seconds_per_day > 0.0:
		return Config.data.seconds_per_day
	return SECONDS_PER_DAY_DEFAULT
