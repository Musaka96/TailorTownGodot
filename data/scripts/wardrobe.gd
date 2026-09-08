class_name Wardrobe

## The character wardrobe: the library of swappable, Rig_Medium-skinned meshes the
## CharacterRig can pull in at runtime — hairstyles, suit tops (jacket + shirt) and
## bottoms (trousers). Each entry names a source .glb and maps roles → the mesh
## node inside it. Every mesh must be skinned to the same Rig_Medium skeleton so it
## deforms with the shared animations (see CharacterRig._attach_from).
##
## To ADD an option: import the .glb (skinned to Rig_Medium) and append an entry to
## the relevant list below. Tops are indexed to Enums jacket styles, bottoms to
## pants styles, so list them in that order. Everything currently points at
## CHARTGEN1 (the base model) until dedicated hair/style/street glbs are imported.

const CHAR := "res://IMPORT/CHARTGEN1.glb"


## Hairstyles (role "hair"). One entry per look; customers pick one at random.
static func hairs() -> Array:
	return [
		{"name": "Default", "glb": CHAR, "roles": {"hair": "Hair"}},
	]


## Suit tops, indexed to Enums.JacketStyle. A top owns both the jacket and the
## shirt mesh (changing the jacket style changes the shirt with it).
static func tops() -> Array:
	return [
		{"name": "Single-Breasted", "glb": CHAR, "roles": {"jacket": "jacket", "shirt": "shirt"}},
	]


## Suit bottoms, indexed to Enums pants styles (role "pants").
static func bottoms() -> Array:
	return [
		{"name": "Flat Front", "glb": CHAR, "roles": {"pants": "legs"}},
	]


## Street (casual) outfit worn on arrival. Until real street models are imported
## these reuse the base meshes and are told apart by their casual materials.
static func street_top() -> Dictionary:
	return {"name": "Casual Top", "glb": CHAR, "roles": {"jacket": "jacket", "shirt": "shirt"}}


static func street_bottom() -> Dictionary:
	return {"name": "Casual Bottom", "glb": CHAR, "roles": {"pants": "legs"}}


# --- Safe lookups (clamp to the available options) -------------------------


static func hair(index: int) -> Dictionary:
	return _at(hairs(), index)


static func top(style: int) -> Dictionary:
	return _at(tops(), style)


static func bottom(style: int) -> Dictionary:
	return _at(bottoms(), style)


static func hair_count() -> int:
	return hairs().size()


static func _at(list: Array, index: int) -> Dictionary:
	if list.is_empty():
		return {}
	return list[clampi(index, 0, list.size() - 1)]
