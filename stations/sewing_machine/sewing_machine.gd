class_name SewingMachine
extends Node3D

## Sews a cut garment piece into a finished (SEWN) piece via the sewing minigame.
## Place a CUT GarmentPiece, sew it, then take the finished part.

var _item: Node = null

@onready var _slot: Node3D = $Slot


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		return "Place piece" if _item == null else "Machine busy"
	if held != null:
		return "Bring a cut garment piece"
	if _item is GarmentPiece:
		if _item.stage == Enums.Stage.CUT:
			return "Sew seam"
		return "Take %s" % Enums.garment_type_name(_item.garment_type)
	return "Sewing machine"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is GarmentPiece:
		if _item != null:
			return
		var piece: Node = actor.carry.release()
		piece.place_on(_slot)
		_item = piece
	elif held != null:
		return
	elif _item is GarmentPiece:
		if _item.stage == Enums.Stage.CUT:
			UI.open_sewing(self, actor, _item)
		else:
			var part := _item
			_item = null
			actor.carry.take_item(part)


## Called by the sewing screen when the minigame resolves.
func finish_sew(success: bool, quality: float) -> void:
	if not (_item is GarmentPiece) or _item.stage != Enums.Stage.CUT:
		return
	if not success:
		_item.queue_free()  # ruined seam wastes the piece
		_item = null
		return
	# Final quality combines the cut and sew performance.
	_item.quality = clampf(_item.quality * quality, 0.05, 1.0)
	_item.stage = Enums.Stage.SEWN
