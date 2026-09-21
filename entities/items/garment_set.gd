class_name GarmentSet
extends Node3D

## Parts made for the same order, gathered on one hanger on a clothing rack. Hang a sewn
## part on a rack that already holds another part for its order and the two gather here
## (ClothingRack.hang), under a paper ticket naming the order and what's still to come.
## When the last part joins, the rack turns the set into a finished Suit.
##
## A set lives on its rack: it isn't carried. Take it apart from the rack menu to get a
## piece back out. Built in code — there is no scene for it.

## How the parts layer on the one hanger: shirt at the back, trousers, jacket in front.
const LAYER := {
	Enums.GarmentType.SHIRT: Vector3(0.0, 0.0, HangingModel.LAYER[Enums.GarmentType.SHIRT]),
	Enums.GarmentType.PANTS: Vector3(0.0, 0.0, HangingModel.LAYER[Enums.GarmentType.PANTS]),
	Enums.GarmentType.JACKET: Vector3.ZERO,
}
## Where the paper ticket hangs, from the hook: above the rail and toward the room (the
## hanger's +x, see ClothingRack.HOOK_TURN), so the rail never hides it.
const TICKET_AT := Vector3(0.22, 0.42, 0.0)

## The order every part on this hanger was made for.
var order_id := 0
var pieces: Array[Node] = []

var _anchors := {}
var _ticket: Label3D


func _init() -> void:
	name = "GarmentSet"
	for t: int in LAYER:
		var anchor := Node3D.new()
		anchor.position = LAYER[t]
		anchor.set_meta(GarmentPiece.HOOK_META, false)  # the parts share the set's hanger
		add_child(anchor)
		_anchors[t] = anchor
	# One hanger for the lot, with its trouser bar at the trousers' layer.
	add_child(HangingModel.make_hanger(LAYER[Enums.GarmentType.PANTS].z))
	_ticket = Label3D.new()
	_ticket.position = TICKET_AT
	_ticket.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Drawn solid (cut out, not blended): the outline pass repaints the screen from a copy
	# taken before see-through objects draw, so a blended label would vanish under it.
	_ticket.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_ticket.font = Style.bold_font()
	_ticket.font_size = 52
	_ticket.pixel_size = 0.003
	_ticket.outline_size = 16
	_ticket.modulate = Style.CREAM
	_ticket.outline_modulate = Style.WALNUT
	add_child(_ticket)


func _ready() -> void:
	refresh.call_deferred()  # after a load the order book may only just have been restored


## Put the set on a rack hook (like any hung item).
func place_on(marker: Node3D) -> void:
	if get_parent() == null:
		marker.add_child(self)
	else:
		reparent(marker)
	transform = Transform3D.IDENTITY


## Hang `piece` on this hanger. The rack only offers parts for this set's order, of a kind
## the set doesn't have yet.
func add(piece: Node) -> void:
	pieces.append(piece)
	var anchor: Node3D = _anchors[int(piece.garment_type)]
	if piece.get_parent() == null:
		anchor.add_child(piece)
	piece.place_on(anchor)
	refresh()


func has_type(garment_type: int) -> bool:
	for piece in pieces:
		if int(piece.garment_type) == garment_type:
			return true
	return false


## The parts this set's order is still waiting for (garment types). Empty once they're all
## here — or if the order has gone from the books, when nothing more is coming.
func missing() -> Array:
	var order := _order()
	var out: Array = []
	if order != null:
		for t in order.required_types():
			if not has_type(t):
				out.append(t)
	return out


## Every part the order needs is on this hanger.
func is_complete() -> bool:
	return _order() != null and missing().is_empty()


## Let go of every part (to take the set apart). The set is left empty; the caller rehangs
## the parts and frees it.
func release_all() -> Array[Node]:
	var out := pieces.duplicate()
	pieces.clear()
	return out


func average_quality() -> float:
	var total := 0.0
	for piece in pieces:
		total += float(piece.quality)
	return total / maxf(pieces.size(), 1.0)


## Who the order is for ("" if it has gone from the books).
func customer_name() -> String:
	var order := _order()
	return order.customer_name if order != null else ""


## The ticket: the order number and what it's still waiting for.
func refresh() -> void:
	if _ticket == null:
		return
	var left := missing()
	var names: Array[String] = []
	for t in left:
		names.append(Enums.garment_type_name(t).to_lower())
	if order_id <= 0:
		_ticket.text = "spares"
	elif _order() == null:
		_ticket.text = "#%d" % order_id
	elif names.is_empty():
		_ticket.text = "#%d  ·  complete" % order_id
	else:
		_ticket.text = "#%d  ·  %s left" % [order_id, ", ".join(names)]


## The order this set is for (a SuitOrder), or null. Reached through the tree and left
## untyped, so this script also compiles in headless tool runs, where autoload names don't
## resolve (SuitOrder itself reads the Shift autoload).
func _order() -> Resource:
	var orders := get_node_or_null("/root/Orders")
	return orders.by_id(order_id) if orders != null else null
