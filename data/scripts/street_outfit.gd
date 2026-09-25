class_name StreetOutfit
extends Resource

## One set of street clothes a customer walks in wearing: its own models (an outer
## layer and an inner layer on top, trousers, shoes, all skinned to Rig_Medium) and the
## cloth each piece is cut from. Listed in WardrobeLibrary.street_outfits; the rig wears
## it through CharacterRig.wear_street(outfit). A part with no model leaves the rig on
## the old flat-colour street look, so a half-authored outfit never breaks a customer.

## Shown in the inspector so outfits are easy to tell apart.
@export var display_name: String = ""
## Who wears it: ANY (the default), MALE or FEMALE (see WardrobePart.fits).
@export var gender: Enums.Gender = Enums.Gender.ANY
## Roles "jacket" (outer layer) and "shirt" (inner layer).
@export var top: WardrobePart
## Role "pants".
@export var bottom: WardrobePart
## Role "shoes": the shoe model (the base model's pair when null).
@export var shoe_model: WardrobePart
## Cloth of the outer layer, the inner layer and the trousers (ClothMaterial.build).
@export var outer_mat: MaterialType
@export var inner_mat: MaterialType
@export var pants_mat: MaterialType
## The shoes' leather: a ShoeMaterial dict {"color", "finish"}.
@export var shoes: Dictionary = {}


## True when this outfit may be worn by a character of `want`.
func fits(want: int) -> bool:
	return gender == Enums.Gender.ANY or want == Enums.Gender.ANY or int(gender) == want


## A plain cloth for make_default(): one fabric, a solid weave, one colour.
static func cloth(id: StringName, label: String, fabric: int, color: Color) -> MaterialType:
	var mat := MaterialType.new()
	mat.id = id
	mat.display_name = label
	mat.fabric = fabric as Enums.Fabric
	mat.pattern = Enums.Pattern.SOLID
	mat.cloth_color = color
	return mat
