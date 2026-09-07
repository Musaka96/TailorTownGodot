class_name Suit
extends Node3D

## A packaged, complete suit (shirt + pants + jacket) assembled at the mannequin.
## Carryable; `parts` holds each piece's material/quality/size/style for the
## selling phase, and `quality` is their average.

@export var quality: float = 1.0
@export var primary_color: Color = Color(0.2, 0.2, 0.24)

## GarmentType(int) -> { material, quality, size, style }
var parts := {}

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	return "Pick up finished suit  (Q %d%%)" % roundi(quality * 100.0)


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
	# Use the jacket's cloth if this suit was assembled from parts; otherwise fall
	# back to a flat primary colour (e.g. placed test suits with no parts).
	var jacket_mat: MaterialType = null
	if parts.has(Enums.GarmentType.JACKET):
		jacket_mat = parts[Enums.GarmentType.JACKET].get("material")
	if jacket_mat != null:
		_mesh.material_override = ClothMaterial.build(jacket_mat, 2.5)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = primary_color
		_mesh.material_override = mat
