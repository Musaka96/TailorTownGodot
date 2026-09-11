class_name Worktable
extends Node3D

## Turns a cut cloth piece into a garment part: place a FabricPiece, configure
## type/size/style, then cut it to shape in the minigame. Success leaves a
## GarmentPiece on the table to take; ruin wastes the cloth.

const GARMENT_PIECE_SCENE := preload("res://entities/items/garment_piece.tscn")

var _item: Node = null

@onready var _slot: Node3D = $Slot


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if _is_piece(held):
		return "Place piece" if _item == null else "Table busy"
	if held != null:
		return "Bring a cut cloth piece"
	if _item is FabricPiece:
		return "Cut to shape"
	if _item is GarmentPiece:
		return "Take %s" % Enums.garment_type_name(_item.garment_type)
	return "Worktable"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if _is_piece(held):
		if _item != null:
			return  # busy
		var piece: Node = actor.carry.release()
		piece.place_on(_slot)
		_item = piece
	elif held != null:
		return  # wrong item in hand
	elif _item is FabricPiece:
		UI.open_worktable(self, actor, _item)
	elif _item is GarmentPiece:
		var part := _item
		_item = null
		actor.carry.take_item(part)


## Called by the worktable screen once the cutting minigame resolves.
func finish_cut(success: bool, type: int, size: int, style: String, quality: float) -> void:
	if not (_item is FabricPiece):
		return
	if not success:
		# A ruined cut wastes the cloth — but during the tutorial keep it on the table so
		# the player can just try the cut again instead of being stranded with nothing.
		if Tutorial != null and Tutorial.is_active():
			return
		_item.queue_free()
		_item = null
		return
	var mat: MaterialType = _item.material
	_item.queue_free()
	_item = null
	var part: Node = GARMENT_PIECE_SCENE.instantiate()
	part.material = mat
	part.garment_type = type
	part.size = size
	part.style = style
	part.quality = quality
	_slot.add_child(part)
	part.transform = Transform3D.IDENTITY
	_item = part
	EventBus.piece_cut.emit(part)


func _is_piece(node: Node) -> bool:
	return node is FabricPiece or node is GarmentPiece


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	return {"item": SaveCodec.item_to(_item) if _item != null else {}}


func load_state(data: Dictionary) -> void:
	if _item != null:
		_item.queue_free()
		_item = null
	var d: Dictionary = data.get("item", {})
	if d.is_empty():
		return
	var node: Node = SaveCodec.item_from(d)
	if node == null:
		return
	_slot.add_child(node)
	node.place_on(_slot)
	_item = node
