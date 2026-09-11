class_name Shelf
extends Node3D

## Storage station. Carrying a roll → place it in the next free slot. Empty-handed
## with rolls stored → open the browse menu to inspect and take one out.
##
## The shelf model (RolneIzdeljene.glb) ships with a stand plus display roll meshes
## (roll1, roll2, …). Those start hidden; storing a bolt keeps the real MaterialRoll
## node internally (hidden) and lights up the next display mesh in the bolt's fabric.
## Taking the bolt back hides its display mesh again.

const FABRIC_PIECE_SCENE := preload("res://entities/items/fabric_piece.tscn")

var stored: Array[Node] = []  # MaterialRoll nodes, index-aligned to _roll_meshes
var _roll_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_collect_roll_meshes()
	_refresh_display()


## Gather the model's display roll meshes (roll1, roll2, …) in order, then hide them.
func _collect_roll_meshes() -> void:
	var i := 1
	while true:
		var node := find_child("roll%d" % i, true, false)
		if node == null:
			break
		var mesh := node as MeshInstance3D
		if mesh == null:
			var found := node.find_children("*", "MeshInstance3D", true, false)
			mesh = found[0] if not found.is_empty() else null
		if mesh != null:
			_roll_meshes.append(mesh)
		i += 1


func capacity() -> int:
	return _roll_meshes.size()


func get_interaction_prompt(actor) -> String:
	var held: Node = actor.carry.get_held()
	if held != null:
		if not (held is MaterialRoll):
			return "Shelf holds material rolls"
		return "Place roll" if stored.size() < capacity() else "Shelf full"
	if stored.size() > 0:
		return "Browse shelf (%d)" % stored.size()
	return "Shelf (empty)"


func interact(actor) -> void:
	var held: Node = actor.carry.get_held()
	if held != null:
		# The shelf only holds material rolls (cut pieces go to the worktable).
		if not (held is MaterialRoll):
			return
		if stored.size() >= capacity():
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
	roll.visible = true
	actor.carry.take_item(roll)
	EventBus.item_taken.emit(roll, self)
	_refresh_display()
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
	_refresh_display()
	return true


## Park the real bolt inside the shelf (hidden, not pickable) and record it.
func _store(roll: Node) -> void:
	if roll.get_parent() == null:
		add_child(roll)
	elif roll.get_parent() != self:
		roll.reparent(self)
	roll.visible = false
	if roll.has_method("set_pickable"):
		roll.set_pickable(false)
	stored.append(roll)
	_refresh_display()


## Show one display mesh per stored bolt (tinted to its fabric); hide the rest.
func _refresh_display() -> void:
	for i in _roll_meshes.size():
		var mesh := _roll_meshes[i]
		if i < stored.size():
			mesh.visible = true
			# Triplanar: the imported roll meshes aren't UV-unwrapped for the weave.
			mesh.material_override = ClothMaterial.build_triplanar(stored[i].material)
		else:
			mesh.visible = false
			mesh.material_override = null


# --- Save / load -----------------------------------------------------------


func save_state() -> Dictionary:
	var items: Array = []
	for roll in stored:
		items.append(SaveCodec.item_to(roll))
	return {"rolls": items}


func load_state(data: Dictionary) -> void:
	for roll in stored:
		roll.queue_free()
	stored.clear()
	for d: Dictionary in data.get("rolls", []):
		if stored.size() >= capacity():
			break
		var roll: Node = SaveCodec.item_from(d)
		if roll == null:
			continue
		_store(roll)
