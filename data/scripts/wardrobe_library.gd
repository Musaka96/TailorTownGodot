class_name WardrobeLibrary
extends Resource

## The editable character wardrobe asset. Holds the lists of swappable, Rig_Medium-
## skinned parts (hairstyles, suit tops, bottoms) plus the skin- and hair-colour
## palettes customers are dressed from. Edit data/wardrobe/default_wardrobe.tres in
## the inspector to change looks: drop a new .glb into a part's `model`, set its
## `roles`, or add a colour to a palette — no code change. Regenerate the shipped
## default with tools/build_wardrobe.gd. Everything reaches this through the Wardrobe
## facade, which loads the .tres (falling back to make_default() if it is missing).

const _CHAR := "res://IMPORT/CHARTGEN1.glb"
const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_HAIR := Color(0.14, 0.11, 0.09)

## Hairstyles — customers pick one at random (role "hair").
@export var hairs: Array[WardrobePart] = []
## Suit tops, indexed to Enums jacket styles (a top owns the jacket AND shirt mesh).
@export var tops: Array[WardrobePart] = []
## Suit bottoms, indexed to Enums pants styles (role "pants").
@export var bottoms: Array[WardrobePart] = []
## Casual look worn on arrival, before a suit is made.
@export var street_top: WardrobePart
@export var street_bottom: WardrobePart
## Skin tones customers spawn with.
@export var skin_colors: PackedColorArray = PackedColorArray()
## Natural hair colours customers spawn with.
@export var hair_colors: PackedColorArray = PackedColorArray()


func hair(index: int) -> WardrobePart:
	return _at(hairs, index)


func top(index: int) -> WardrobePart:
	return _at(tops, index)


func bottom(index: int) -> WardrobePart:
	return _at(bottoms, index)


func hair_count() -> int:
	return hairs.size()


func skin(index: int) -> Color:
	return _color(skin_colors, index, DEFAULT_SKIN)


func hair_color(index: int) -> Color:
	return _color(hair_colors, index, DEFAULT_HAIR)


func random_skin(rng: RandomNumberGenerator) -> Color:
	if skin_colors.is_empty():
		return DEFAULT_SKIN
	return skin_colors[rng.randi() % skin_colors.size()]


func random_hair_color(rng: RandomNumberGenerator) -> Color:
	if hair_colors.is_empty():
		return DEFAULT_HAIR
	return hair_colors[rng.randi() % hair_colors.size()]


func _at(list: Array, index: int) -> WardrobePart:
	if list.is_empty():
		return null
	return list[clampi(index, 0, list.size() - 1)]


func _color(arr: PackedColorArray, index: int, fallback: Color) -> Color:
	if arr.is_empty():
		return fallback
	return arr[clampi(index, 0, arr.size() - 1)]


## Build the shipped default library in code — the source for build_wardrobe.gd and
## the fallback the Wardrobe facade uses if the .tres asset is ever missing.
static func make_default() -> WardrobeLibrary:
	var lib := WardrobeLibrary.new()
	var model := load(_CHAR) as PackedScene
	var suit_roles := {"jacket": "jacket", "shirt": "shirt"}
	var pants_roles := {"pants": "legs"}
	lib.hairs.append(WardrobePart.make("Default", model, {"hair": "Hair"}))
	lib.tops.append(WardrobePart.make("Single-Breasted", model, suit_roles.duplicate()))
	lib.bottoms.append(WardrobePart.make("Flat Front", model, pants_roles.duplicate()))
	lib.street_top = WardrobePart.make("Casual Top", model, suit_roles.duplicate())
	lib.street_bottom = WardrobePart.make("Casual Bottom", model, pants_roles.duplicate())
	lib.skin_colors = PackedColorArray(
		[
			Color(0.87, 0.72, 0.60),
			Color(0.80, 0.62, 0.48),
			Color(0.93, 0.81, 0.69),
			Color(0.66, 0.48, 0.35),
			Color(0.55, 0.38, 0.27),
		]
	)
	lib.hair_colors = PackedColorArray(
		[
			Color(0.10, 0.08, 0.07),  # black
			Color(0.28, 0.18, 0.10),  # dark brown
			Color(0.45, 0.30, 0.16),  # brown
			Color(0.72, 0.55, 0.30),  # blond
			Color(0.55, 0.20, 0.10),  # auburn
			Color(0.60, 0.60, 0.62),  # grey
		]
	)
	return lib
