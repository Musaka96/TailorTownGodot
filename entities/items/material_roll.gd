class_name MaterialRoll
extends Node3D

## A physical bolt of cloth in the world. Carries a MaterialType (what it is) plus
## its own remaining length (how much is left). Can be picked up, carried, and
## stored on a shelf.

@export var material: MaterialType
## Metres of cloth left on this bolt; -1 means "full" (resolved from material).
@export var remaining_length_m: float = -1.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if remaining_length_m < 0.0 and material != null:
		remaining_length_m = material.roll_length_m
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	if material == null:
		return "Pick up roll"
	return "Pick up %s" % material.display_name


## Cut up to `length` metres off this bolt; returns how much was actually cut
## (capped at what's left). Never goes negative.
func cut(length: float) -> float:
	var amount := minf(maxf(length, 0.0), remaining_length_m)
	remaining_length_m -= amount
	return amount


func is_empty() -> bool:
	return remaining_length_m <= 0.05


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


## Parent under a hold point / shelf slot and sit at its origin.
func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)


## Alias used by stations for readability.
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = material.cloth_color if material else Color(0.6, 0.6, 0.6)
	_mesh.material_override = mat
