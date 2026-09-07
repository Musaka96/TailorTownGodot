class_name Worktable
extends Node3D

## Where cut cloth pieces go next. For now it just receives/holds one piece and
## lets you take it back; configuring/cutting garments comes in later phases.

var _piece: Node = null

@onready var _slot: Node3D = $Slot


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held is FabricPiece:
		return "Place piece" if _piece == null else "Table full"
	if held != null:
		return "Bring a cut cloth piece"
	if _piece != null:
		return "Take piece"
	return "Worktable"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held is FabricPiece:
		if _piece != null:
			return  # occupied
		var piece: Node = actor.carry.release()
		piece.place_on(_slot)
		_piece = piece
	elif held != null:
		return  # carrying something that isn't a piece
	elif _piece != null:
		var piece := _piece
		_piece = null
		actor.carry.take_item(piece)
