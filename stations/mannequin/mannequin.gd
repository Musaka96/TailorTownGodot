class_name Mannequin
extends Node3D

## Dress it with a sewn shirt, pants and jacket, then package them into a
## complete Suit. Empty-handed with an incomplete set, take the last piece back.

const SUIT_SCENE := preload("res://entities/items/suit.tscn")

var _dressed := {}          # GarmentType(int) -> GarmentPiece
var _order: Array[int] = [] # placement order, for take-back

@onready var _slots := {
	Enums.GarmentType.SHIRT: $ShirtSlot,
	Enums.GarmentType.PANTS: $PantsSlot,
	Enums.GarmentType.JACKET: $JacketSlot,
}


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		if held.stage != Enums.Stage.SEWN:
			return "Sew this piece first"
		var t: int = held.garment_type
		if _dressed.has(t):
			return "%s already on" % Enums.garment_type_name(t)
		return "Put on %s" % Enums.garment_type_name(t)
	if held != null:
		return "Dress with a sewn piece"
	if _is_complete():
		return "Package the suit!"
	if _order.size() > 0:
		return "Take last piece  (need %s)" % _missing_text()
	return "Mannequin — needs shirt, pants, jacket"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		if held.stage != Enums.Stage.SEWN:
			return
		var t: int = held.garment_type
		if _dressed.has(t):
			return
		var piece: Node = actor.carry.release()
		piece.place_on(_slots[t])
		_dressed[t] = piece
		_order.append(t)
	elif held != null:
		return
	elif _is_complete():
		_package(actor)
	elif _order.size() > 0:
		var t: int = _order.pop_back()
		var piece: Node = _dressed[t]
		_dressed.erase(t)
		actor.carry.take_item(piece)


func _is_complete() -> bool:
	return (_dressed.has(Enums.GarmentType.SHIRT)
		and _dressed.has(Enums.GarmentType.PANTS)
		and _dressed.has(Enums.GarmentType.JACKET))


func _missing_text() -> String:
	var missing: Array[String] = []
	for t in [Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS, Enums.GarmentType.JACKET]:
		if not _dressed.has(t):
			missing.append(Enums.garment_type_name(t))
	return ", ".join(missing)


func _package(actor) -> void:
	var suit: Node = SUIT_SCENE.instantiate()
	suit.parts = {}
	var quality_sum := 0.0
	for t in _dressed.keys():
		var piece = _dressed[t]
		suit.parts[t] = {
			"material": piece.material, "quality": piece.quality,
			"size": piece.size, "style": piece.style,
		}
		quality_sum += piece.quality
	suit.quality = quality_sum / 3.0
	var jacket = _dressed[Enums.GarmentType.JACKET]
	if jacket.material != null:
		suit.primary_color = jacket.material.cloth_color

	for t in _dressed.keys():
		_dressed[t].queue_free()
	_dressed.clear()
	_order.clear()

	add_child(suit)
	actor.carry.take_item(suit)
	EventBus.suit_packaged.emit(suit)
