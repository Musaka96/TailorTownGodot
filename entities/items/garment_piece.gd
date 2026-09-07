class_name GarmentPiece
extends Node3D

## A cut garment panel produced at the worktable: a specific garment type, size
## and style, cut from a material with a quality score from the cutting minigame.
## Next stop is the sewing machine (later phase). Carryable like the other items.

@export var material: MaterialType
@export var garment_type: Enums.GarmentType = Enums.GarmentType.SHIRT
@export var size: Enums.Size = Enums.Size.M
@export var style: String = "Classic"
@export var quality: float = 1.0
@export var stage: Enums.Stage = Enums.Stage.CUT

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	var st := "sewn" if stage == Enums.Stage.SEWN else "cut"
	return "Pick up %s (%s, %s)" % [
		Enums.garment_type_name(garment_type), Enums.size_name(size), st]


func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)


func place_on(marker: Node3D) -> void:
	attach_to(marker)


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


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
	mat.albedo_color = material.cloth_color if material else Color(0.7, 0.7, 0.7)
	_mesh.material_override = mat
