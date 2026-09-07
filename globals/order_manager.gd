extends Node

## Autoloaded as "Orders". Tracks confirmed bespoke orders and pays out when a
## packaged suit is delivered against one.
##
## Kept decoupled: the mirror/suit-builder calls create_order() when a customer
## approves a design; the mannequin calls submit() when a suit is packaged. The
## HUD's orders panel listens to EventBus (order_created / order_fulfilled).

## A delivered suit must match at least this well to fulfil an order — below it,
## the suit is handed back to the player instead of burning the order for nothing.
const MIN_MATCH := 0.34

var active: Array[SuitOrder] = []


func create_order(customer_name: String, design: Dictionary, price: int) -> SuitOrder:
	var order := SuitOrder.new()
	order.customer_name = customer_name
	order.design = design.duplicate(true)
	order.price = price
	active.append(order)
	EventBus.order_created.emit(order)
	return order


## Deliver a freshly packaged suit. Pays out against the best-matching open order
## (price × match × craft quality) and consumes the suit; with no good match the
## suit is handed to the player to keep instead.
func submit(suit: Node, actor: Node) -> void:
	var order := _best_match(suit)
	var frac := order.match_fraction(suit) if order != null else 0.0
	if order == null or frac < MIN_MATCH:
		if actor != null and actor.carry != null:
			actor.carry.take_item(suit)
		return
	var quality := clampf(float(suit.get("quality")), 0.0, 1.0)
	var payout := int(round(order.price * frac * quality))
	GameState.earn(payout)
	active.erase(order)
	EventBus.order_fulfilled.emit(order, payout)
	suit.queue_free()


func _best_match(suit: Node) -> SuitOrder:
	var best: SuitOrder = null
	var best_frac := -1.0
	for order in active:
		var f := order.match_fraction(suit)
		if f > best_frac:
			best_frac = f
			best = order
	return best
