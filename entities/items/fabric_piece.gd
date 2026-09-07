class_name FabricPiece
extends Node3D

## A flat piece of cloth cut from a bolt — the thing you carry to the worktable.
## Same carry interface as MaterialRoll (attach_to / place_on / set_pickable) so
## the CarrySlot and stations treat them the same.

@export var material: MaterialType
@export var length_m: float = 1.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	var name := material.display_name if material else "cloth"
	return "Pick up %s piece (%.1f m)" % [name, length_m]


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)


func place_on(marker: Node3D) -> void:
	attach_to(marker)


func set_pickable(enabled: bool) -> void:
	if _interactable:
		_interactable.set_enabled(enabled)


func _sit_at(new_parent: Node3D) -> void:
	reparent(new_parent)
	transform = Transform3D.IDENTITY


func _apply_visual() -> void:
	if _mesh == null:
		return
	_mesh.material_override = ClothMaterial.build(material, 2.0)
