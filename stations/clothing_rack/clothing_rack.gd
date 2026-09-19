class_name ClothingRack
extends Node3D

## Storage for finished garment parts AND whole suits, and where a suit comes together.
## Hang a GarmentPiece or a Suit on a free hook; empty-handed with things stored, open the
## browse menu to inspect and take one out.
##
## Sewn parts made for the same order gather on this rack: the second part for an order
## joins the first on its hook as one GarmentSet, under a ticket saying what's still to
## come, and the last part to join turns the set into the finished Suit, which makes the
## order ready for its customer. Each rack keeps its own — parts on different racks never
## gather together. A set can be taken apart from the menu; its parts then stay apart on
## this rack until they're taken off it.

var stored: Array[Node] = []
var _slots: Array[Node3D] = []
var _base_slots := 0
## Parts taken apart here, which mustn't gather again until they've left the rack.
var _loose := {}
var _sway := RackSway.new()

@onready var _slots_root: Node3D = $Slots


func _ready() -> void:
	for child in _slots_root.get_children():
		if child is Marker3D:
			_slots.append(child)
	_base_slots = _slots.size()
	_sway.hooks = _slots_root
	add_child(_sway)
	_apply_extra_hooks()
	if Upgrades != null:
		Upgrades.changed.connect(_apply_extra_hooks)


## The Extra Hooks upgrade adds slots by extending the rail's spacing past the last hook.
func _apply_extra_hooks() -> void:
	var want := _base_slots + (Upgrades.extra_rack_slots() if Upgrades != null else 0)
	while _slots.size() < want and _slots.size() >= 2:
		var step: Vector3 = _slots[-1].position - _slots[-2].position
		var hook := Marker3D.new()
		hook.position = _slots[-1].position + step
		_slots_root.add_child(hook)
		_slots.append(hook)


func capacity() -> int:
	return _slots.size()


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece or held is Suit:
		if _group_for(held) != null:
			return "Hang with order #%d" % int(held.order_id)
		return "Hang up" if stored.size() < _slots.size() else "Rack full"
	if held != null:
		return "Rack holds garments and suits"
	if stored.size() > 0:
		return "Browse rack  (%d)" % stored.size()
	return "Clothing rack"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece or held is Suit:
		if can_hang(held):
			hang(actor.carry.release())
	elif held != null:
		return
	elif stored.size() > 0:
		UI.open_rack_menu(self, actor)


## Whether `item` fits: a free hook, or a part that joins its order's set.
func can_hang(item: Node) -> bool:
	return stored.size() < _slots.size() or _group_for(item) != null


## Hang a garment part or a suit. A sewn part joins whatever this rack already holds for its
## order — gathering onto one hook — and the last part to join turns the set into the
## finished suit. Returns false (and takes nothing) when there's no room.
func hang(item: Node) -> bool:
	var group := _group_for(item)
	if group == null and stored.size() >= _slots.size():
		return false
	if item.get_parent() == null:
		add_child(item)
	if group == null:
		item.place_on(_slots[stored.size()])
		stored.append(item)
	elif group is GarmentSet:
		group.add(item)
		Sfx.play("cloth_rustle", -4.0)
	else:
		_gather(group, item)
	EventBus.item_stored.emit(item, self)
	_sway.kick(stored.find(group if group != null else item))
	_finish_complete()
	return true


## Take the stored item at `index` into your hands. Returns false (and changes nothing) if
## your hands are full, the index is invalid, or it's a set (take that apart first).
func take(index: int, actor) -> bool:
	if not actor.carry.is_empty():
		return false
	if index < 0 or index >= stored.size() or stored[index] is GarmentSet:
		return false
	var piece: Node = stored[index]
	stored.remove_at(index)
	_loose.erase(piece)
	actor.carry.take_item(piece)
	EventBus.item_taken.emit(piece, self)
	_reflow()
	_sway.kick(mini(index, stored.size() - 1), 0.7)
	return true


## Take the set at `index` apart: each part goes back on a hook of its own, where the set
## was, and stays apart — it won't gather again on this rack until it has been taken off.
## False (and nothing moves) when there aren't enough free hooks.
func take_apart(index: int) -> bool:
	if index < 0 or index >= stored.size() or not (stored[index] is GarmentSet):
		return false
	var bundle: GarmentSet = stored[index]
	if bundle.pieces.size() - 1 > _slots.size() - stored.size():
		return false
	var parts := bundle.release_all()
	stored.remove_at(index)
	for k in parts.size():
		stored.insert(index + k, parts[k])
		_loose[parts[k]] = true
	_reflow()
	bundle.queue_free()
	return true


## Whether the part at `index` was taken apart from a set here (and so hangs alone).
func is_loose(index: int) -> bool:
	return index >= 0 and index < stored.size() and _loose.has(stored[index])


## Room for a set at `index` to be taken apart: one free hook per part beyond the first.
func can_take_apart(index: int) -> bool:
	if index < 0 or index >= stored.size() or not (stored[index] is GarmentSet):
		return false
	return stored[index].pieces.size() - 1 <= _slots.size() - stored.size()


# --- Gathering -----------------------------------------------------------------


## What this rack already holds for `item`'s order that it can join: that order's set, or
## a lone sewn part for it of another kind. Null for suits, unsewn parts, parts made for no
## order, and when the only match hangs apart after being taken off a set.
func _group_for(item: Node) -> Node:
	if not (item is GarmentPiece) or item.stage != Enums.Stage.SEWN or int(item.order_id) <= 0:
		return null
	var kind := int(item.garment_type)
	for hung in stored:
		if hung is GarmentSet:
			if hung.order_id == item.order_id and not hung.has_type(kind):
				return hung
		elif _joins(hung, item):
			return hung
	return null


## A lone part `hung` that `item` can gather with: same order, another kind, sewn, not
## taken apart here.
func _joins(hung: Node, item: Node) -> bool:
	return (
		hung is GarmentPiece
		and hung != item
		and not _loose.has(hung)
		and hung.stage == Enums.Stage.SEWN
		and int(hung.order_id) == int(item.order_id)
		and int(hung.garment_type) != int(item.garment_type)
	)


## A second part for an order joins the lone one on its hook: both move onto one hanger.
func _gather(single: Node, item: Node) -> void:
	var at := stored.find(single)
	var bundle := GarmentSet.new()
	bundle.order_id = int(single.order_id)
	bundle.place_on(_slots[at])
	stored[at] = bundle
	bundle.add(single)
	bundle.add(item)
	Sfx.play("cloth_rustle", -4.0)


## Any set whose order now has every part turns into the finished suit on the same hook, and
## that order is ready for its customer.
func _finish_complete() -> void:
	for i in stored.size():
		var hung: Node = stored[i]
		if hung is GarmentSet and hung.is_complete():
			stored[i] = _make_suit(hung, i)


func _make_suit(bundle: GarmentSet, hook: int) -> Node:
	var parts := bundle.release_all()
	var suit: Node = Suit.from_pieces(parts, bundle.order_id)
	for part in parts:
		part.queue_free()
	bundle.queue_free()
	add_child(suit)
	suit.place_on(_slots[hook])
	EventBus.suit_packaged.emit(suit)
	if Orders != null:
		Orders.assemble(suit.order_id)
	return suit


func _reflow() -> void:
	for i in stored.size():
		stored[i].place_on(_slots[i])


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	var items: Array = []
	for hung in stored:
		if hung is GarmentSet:
			var parts: Array = []
			for part in hung.pieces:
				parts.append(SaveCodec.item_to(part))
			items.append({"kind": "set", "order_id": hung.order_id, "pieces": parts})
			continue
		var d := SaveCodec.item_to(hung)
		if _loose.has(hung):
			d["loose"] = true
		items.append(d)
	return {"pieces": items}


func load_state(data: Dictionary) -> void:
	for hung in stored:
		hung.queue_free()
	stored.clear()
	_loose.clear()
	for d: Dictionary in data.get("pieces", []):
		if stored.size() >= _slots.size():
			break
		var hung := _restore(d)
		if hung != null:
			stored.append(hung)


## Rebuild one hung entry (an item, or a set of them) on the next hook.
func _restore(d: Dictionary) -> Node:
	var hook := _slots[stored.size()]
	if str(d.get("kind", "")) == "set":
		var bundle := GarmentSet.new()
		bundle.order_id = int(d.get("order_id", 0))
		bundle.place_on(hook)
		for pd: Dictionary in d.get("pieces", []):
			var part := SaveCodec.item_from(pd)
			if part != null:
				bundle.add(part)
		return bundle
	var piece := SaveCodec.item_from(d)
	if piece == null:
		return null
	add_child(piece)
	piece.place_on(hook)
	if bool(d.get("loose", false)):
		_loose[piece] = true
	return piece
