class_name Shelf
extends Node3D

## Storage station. Carrying a roll → place it in the next free slot. Empty-handed
## with rolls stored → open the browse menu to inspect and take one out.

const FABRIC_PIECE_SCENE := preload("res://entities/items/fabric_piece.tscn")

var stored: Array[Node] = []   # MaterialRoll nodes, index-aligned to _slots
var _slots: Array[Node3D] = []

@onready var _slots_root: Node3D = $Slots


func _ready() -> void:
	for child in _slots_root.get_children():
		if child is Marker3D:
			_slots.append(child)


func capacity() -> int:
	return _slots.size()


func get_interaction_prompt(actor) -> String:
	if not actor.carry.is_empty():
		return "Place roll" if stored.size() < _slots.size() else "Shelf full"
	if stored.size() > 0:
		return "Browse shelf (%d)" % stored.size()
	return "Shelf (empty)"


func interact(actor) -> void:
	if not actor.carry.is_empty():
		if stored.size() >= _slots.size():
			return
		var roll: Node = actor.carry.release()
		_store(roll)
		EventBus.item_stored.emit(roll, self)
	elif stored.size() > 0:
		UI.open_shelf_menu(self, actor)


## Take a whole bolt into your hands. Returns false (and changes nothing) if your
## hands are already full or the index is invalid.
func take(index: int, actor) -> bool:
	if not actor.carry.is_empty():
		return false
	if index < 0 or index >= stored.size():
		return false
	var roll: Node = stored[index]
	stored.remove_at(index)
	actor.carry.take_item(roll)
	EventBus.item_taken.emit(roll, self)
	_reflow()
	return true


## Cut `length` metres off the bolt at `index` into a carried FabricPiece.
## Returns false if hands are full, the index is invalid, or nothing was cut.
func cut_piece(index: int, length: float, actor) -> bool:
	if not actor.carry.is_empty():
		return false
	if index < 0 or index >= stored.size():
		return false
	var roll: Node = stored[index]
	var amount: float = roll.cut(length)
	if amount <= 0.0:
		return false
	var piece: Node = FABRIC_PIECE_SCENE.instantiate()
	piece.material = roll.material
	piece.length_m = amount
	add_child(piece)
	actor.carry.take_item(piece)
	EventBus.cloth_cut.emit(piece, roll)
	if roll.is_empty():
		stored.remove_at(index)
		roll.queue_free()
		_reflow()
	return true


func _store(roll: Node) -> void:
	roll.place_on(_slots[stored.size()])
	stored.append(roll)


## Re-seat remaining rolls into the first slots after one is removed.
func _reflow() -> void:
	for i in stored.size():
		stored[i].place_on(_slots[i])
