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
## Colourways: a small closed palette per piece (outer layer, inner layer, trousers).
## A colourway index (in_colour) picks one colour from each, so two people in the same
## outfit rarely match. Keep the outfit's own cloth colour FIRST in each list, so
## colourway 0 is the outfit as authored. An empty list leaves that piece as it is.
@export var outer_colors: PackedColorArray = PackedColorArray()
@export var inner_colors: PackedColorArray = PackedColorArray()
@export var pants_colors: PackedColorArray = PackedColorArray()

## Recoloured copies of this outfit by colourway index (built on first use, then shared).
var _dyed: Dictionary = {}


## True when this outfit may be worn by a character of `want`.
func fits(want: int) -> bool:
	return gender == Enums.Gender.ANY or want == Enums.Gender.ANY or int(gender) == want


## How many colourways the palettes make (every outer x inner x trousers mix; 1 when
## there are no palettes).
func colourway_count() -> int:
	return (
		maxi(1, outer_colors.size()) * maxi(1, inner_colors.size()) * maxi(1, pants_colors.size())
	)


## The colourway a named customer wears in this outfit: the same one every visit, even
## before they are a regular (a stable hash of the name, salted apart from their face).
func colourway_for(display_name: String) -> int:
	var h := 5381
	var text := display_name + "/street"
	for i in text.length():
		h = (h * 33 + text.unicode_at(i)) % 2147483647
	return h % colourway_count()


## This outfit dyed in colourway `index` (any int; wrapped into range): a copy whose
## outer, inner and trouser cloths take one colour each from the palettes. The models,
## shoes and weaves are shared; only the cloths are duplicated. Colourway 0 and an
## outfit with no palettes return the outfit itself.
func in_colour(index: int) -> StreetOutfit:
	var i := posmod(index, colourway_count())
	if i == 0:
		return self
	if _dyed.has(i):
		return _dyed[i]
	# The index read as mixed-radix digits: outer, then inner, then trousers.
	var n_out := maxi(1, outer_colors.size())
	var n_in := maxi(1, inner_colors.size())
	var dyed := duplicate(false) as StreetOutfit
	dyed.outer_mat = _dye(outer_mat, outer_colors, i % n_out)
	var rest := floori(float(i) / n_out)
	dyed.inner_mat = _dye(inner_mat, inner_colors, rest % n_in)
	dyed.pants_mat = _dye(pants_mat, pants_colors, floori(float(rest) / n_in))
	_dyed[i] = dyed
	return dyed


## `mat` in palette colour `pick` (the cloth itself when the palette is empty).
static func _dye(mat: MaterialType, palette: PackedColorArray, pick: int) -> MaterialType:
	if mat == null or palette.is_empty():
		return mat
	var copy := mat.duplicate(false) as MaterialType
	copy.cloth_color = palette[pick % palette.size()]
	return copy


## A plain cloth for make_default(): one fabric, a solid weave, one colour.
static func cloth(id: StringName, label: String, fabric: int, color: Color) -> MaterialType:
	var mat := MaterialType.new()
	mat.id = id
	mat.display_name = label
	mat.fabric = fabric as Enums.Fabric
	mat.pattern = Enums.Pattern.SOLID
	mat.cloth_color = color
	return mat
