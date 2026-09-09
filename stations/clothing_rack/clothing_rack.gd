class_name ClothingRack
extends Node3D

## Storage for finished garment parts AND whole suits. Hang a GarmentPiece or a
## Suit on a free hook; empty-handed with things stored, open the browse menu to
## inspect and take one out.

var stored: Array[Node] = []
var _slots: Array[Node3D] = []

@onready var _slots_root: Node3D = $Slots


func _ready() -> void:
	for child in _slots_root.get_children():
		if child is Marker3D:
			_slots.append(child)


func capacity() -> int:
	return _slots.size()


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece or held is Suit:
		return "Hang up" if stored.size() < _slots.size() else "Rack full"
	if held != null:
		return "Rack holds garments and suits"
	if stored.size() > 0:
		return "Browse rack  (%d)" % stored.size()
	return "Clothing rack"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece or held is Suit:
		if stored.size() >= _slots.size():
			return
		var piece: Node = actor.carry.release()
		piece.place_on(_slots[stored.size()])
		stored.append(piece)
		EventBus.item_stored.emit(piece, self)
	elif held != null:
		return
	elif stored.size() > 0:
		UI.open_rack_menu(self, actor)


## Take the stored item at `index` into your hands. Returns false (and changes
## nothing) if your hands are full or the index is invalid.
func take(index: int, actor) -> bool:
	if not actor.carry.is_empty():
		return false
	if index < 0 or index >= stored.size():
		return false
	var piece: Node = stored[index]
	stored.remove_at(index)
	actor.carry.take_item(piece)
	EventBus.item_taken.emit(piece, self)
	_reflow()
	return true


func _reflow() -> void:
	for i in stored.size():
		stored[i].place_on(_slots[i])


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	var items: Array = []
	for piece in stored:
		items.append(SaveCodec.item_to(piece))
	return {"pieces": items}


func load_state(data: Dictionary) -> void:
	for piece in stored:
		piece.queue_free()
	stored.clear()
	for d: Dictionary in data.get("pieces", []):
		if stored.size() >= _slots.size():
			break
		var piece: Node = SaveCodec.item_from(d)
		if piece == null:
			continue
		add_child(piece)
		piece.place_on(_slots[stored.size()])
		stored.append(piece)
