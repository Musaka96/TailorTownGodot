class_name ClothingRack
extends Node3D

## Storage for finished garment parts. Hang a GarmentPiece on a free hook;
## empty-handed, take the most recently hung one back.

@onready var _slots_root: Node3D = $Slots

var _slots: Array[Node3D] = []
var stored: Array[Node] = []


func _ready() -> void:
	for child in _slots_root.get_children():
		if child is Marker3D:
			_slots.append(child)


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		return "Hang part" if stored.size() < _slots.size() else "Rack full"
	if held != null:
		return "Rack holds garment parts"
	if stored.size() > 0:
		return "Take part  (%d)" % stored.size()
	return "Clothing rack"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		if stored.size() >= _slots.size():
			return
		var piece: Node = actor.carry.release()
		piece.place_on(_slots[stored.size()])
		stored.append(piece)
	elif held != null:
		return
	elif stored.size() > 0:
		var piece: Node = stored.pop_back()
		actor.carry.take_item(piece)
		_reflow()


func _reflow() -> void:
	for i in stored.size():
		stored[i].place_on(_slots[i])
