class_name CustomerWait
extends Node

## A customer who called for a suit that isn't ready, kept waiting at the counter. Added to
## the Customer by the manager (CustomerWait.begin) and takes over their interaction while
## it lasts. A patience meter drains overhead:
##   - speak to them (interact): the bubble offers an apology — a regular lets it pass, a
##     stranger may agree to call tomorrow, an event that won't wait is simply lost — and,
##     with the coffee machine in, a coffee that buys time and goodwill;
##   - finish the suit while they wait and it turns into an ordinary collection;
##   - leave them standing until it runs out and they walk out, which costs extra standing.

const METER_HEIGHT := 2.55  # metres over the feet the meter floats at

var order: SuitOrder
## Extra chance a stranger forgives the delay: a coffee in their hand helps.
var goodwill := 0.0

var _cust: Customer
var _left := 0.0
var _total := 1.0
var _drain := 1.0
var _meter: PatienceMeter


## Keep `cust` waiting for `for_order`. Returns the component.
static func begin(cust: Customer, for_order: SuitOrder) -> CustomerWait:
	var wait := CustomerWait.new()
	wait.name = "CustomerWait"
	wait.order = for_order
	wait._cust = cust
	cust.add_child(wait)
	return wait


## Could this order's customer call again tomorrow instead? Not twice, and never when
## tomorrow is past the city event the suit is for.
static func can_reschedule(for_order: SuitOrder) -> bool:
	if for_order == null or for_order.late or not Orders.active.has(for_order):
		return false
	if for_order.event_id != "" and News != null:
		var held: int = News.event_day(for_order.event_id)
		var today: int = Shift.day if Shift != null else 1
		if held > 0 and today + 1 > held:
			return false
	return true


## The player apologises for `for_order`. Returns what came of it:
##   "regular"  a regular — tomorrow, and no hard feelings (no standing lost)
##   "moved"    agreed to call again tomorrow (the usual late penalty)
##   "event"    it was for an event that can't wait — the order is lost (softened)
##   "lost"     won't come back — the order is lost (softened)
## `extra` is added to a stranger's chance of agreeing.
static func apologise(for_order: SuitOrder, extra := 0.0) -> String:
	if for_order == null or not Orders.active.has(for_order):
		return "lost"
	if can_reschedule(for_order):
		if Clientele != null and Clientele.loyalty(for_order.customer_name) > 0:
			Orders.grant_grace(for_order, false)
			return "regular"
		var chance: float = Config.data.reschedule_chance if Config.data != null else 0.6
		if randf() < chance + extra:
			Orders.grant_grace(for_order)
			return "moved"
	var for_event := for_order.event_id != "" and not for_order.late
	for_order.apologised = true
	Orders.expire(for_order)
	return "event" if for_event else "lost"


func _ready() -> void:
	var cfg := Config.data
	_total = cfg.collector_patience_s if cfg != null else 45.0
	if Clientele != null and Clientele.loyalty(order.customer_name) > 0:
		_total *= cfg.regular_patience_mult if cfg != null else 1.5
	_left = _total
	_meter = PatienceMeter.new()
	WorldAnchor.pin(_cust, _meter, METER_HEIGHT)
	_cust.collect_order = order
	_cust.takeover = self
	(_cust.get_node("Interactable") as Interactable).set_enabled(true)
	UI.toast('%s: "I\'m here for order #%d. Is it ready?"' % [order.customer_name, order.id])
	Sfx.play("menu_open")


func _process(delta: float) -> void:
	if Orders.is_ready(order):
		_end()
		_cust.offer_collection(order)  # finished while they waited
		return
	if UI != null and UI.customer_request.visible:
		return  # being spoken to: the clock is kind
	_left -= delta * _drain
	_meter.value = value()
	if _left <= 0.0:
		_walk_out()


## 0..1 of the wait left.
func value() -> float:
	return clampf(_left / maxf(_total, 0.001), 0.0, 1.0)


## A coffee of `quality` (0..1) in their hand: the wait starts over and runs slower, and
## they are readier to forgive.
func soothe(quality: float) -> void:
	var cfg := Config.data
	_left = _total
	_drain = cfg.coffee_patience_drain if cfg != null else 0.5
	goodwill = (cfg.coffee_goodwill if cfg != null else 0.2) * clampf(quality, 0.0, 1.0)
	_meter.soothed = true
	_meter.value = 1.0


# --- Interaction (the Customer forwards these while we hold `takeover`) ----


func get_interaction_prompt(_actor) -> String:
	return "Speak to %s — order #%d isn't ready" % [order.customer_name, order.id]


func interact(actor) -> void:
	UI.open_customer_wait(_cust, actor, self)


## The player owns up (chosen in the bubble).
func say_sorry() -> void:
	var who := order.customer_name
	var outcome := CustomerWait.apologise(order, goodwill)
	var mood := "wave"
	match outcome:
		"regular":
			UI.toast('%s: "For you? Of course. I\'ll look in tomorrow."' % who)
		"moved":
			UI.toast('%s: "Hm. Tomorrow, then — but I shan\'t pay full price."' % who)
		"event":
			mood = "sad"
			UI.toast('%s: "It was for the event! Tomorrow is no use to me."' % who)
		_:
			mood = "sad"
			UI.toast('%s: "I\'ll take my custom elsewhere, thank you."' % who)
	Sfx.play("happy" if mood == "wave" else "unhappy")
	_end()
	_cust.collect_order = null
	_cust.finish_and_leave(mood)


## Left standing too long: the order is lost, and word gets round.
func _walk_out() -> void:
	UI.toast('%s: "Nobody even spoke to me. Good day!"' % order.customer_name)
	Sfx.play("unhappy")
	order.ignored = true
	Orders.expire(order)
	_end()
	_cust.collect_order = null
	_cust.finish_and_leave("sad")


func _end() -> void:
	set_process(false)
	if _cust.takeover == self:
		_cust.takeover = null
	if _meter != null and is_instance_valid(_meter):
		_meter.get_parent().queue_free()  # the WorldAnchor holding it
	_meter = null
	queue_free()
