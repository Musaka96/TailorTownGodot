class_name WardrobePart
extends Resource

## One swappable, Rig_Medium-skinned wardrobe item: a hairstyle, a suit top, or a
## bottom. `model` is the source model (a .glb imports as a PackedScene) and `roles`
## maps each logical slot role -> the name of the MeshInstance3D inside that model,
## e.g. a top maps {"jacket": "jacket", "shirt": "shirt"}. At runtime the CharacterRig
## pulls those meshes out of the model and reparents them onto the shared skeleton
## (see CharacterRig._attach_from) — because every part is skinned to the same
## Rig_Medium, the animations drive it with no retargeting.

## Shown in menus / the inspector so parts are easy to tell apart.
@export var display_name: String = ""
## The source model. Drag a .glb (skinned to Rig_Medium) in from the FileSystem dock.
@export var model: PackedScene
## Role -> mesh node name inside `model` (e.g. {"jacket": "jacket", "shirt": "shirt"}).
@export var roles: Dictionary = {}
## Who this part suits: ANY (unisex, the default), MALE or FEMALE. Customers are only
## given parts whose gender is ANY or matches their own.
@export var gender: Enums.Gender = Enums.Gender.ANY


static func make(
	name: String, part_model: PackedScene, part_roles: Dictionary, part_gender := Enums.Gender.ANY
) -> WardrobePart:
	var part := WardrobePart.new()
	part.display_name = name
	part.model = part_model
	part.roles = part_roles
	part.gender = part_gender
	return part


## True when this part may be worn by a character of `want` (ANY parts fit everyone).
func fits(want: int) -> bool:
	return gender == Enums.Gender.ANY or want == Enums.Gender.ANY or int(gender) == want
