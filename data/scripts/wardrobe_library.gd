class_name WardrobeLibrary
extends Resource

## The editable character wardrobe asset. Holds the lists of swappable, Rig_Medium-
## skinned parts (hairstyles, suit tops, bottoms) plus the skin- and hair-colour
## palettes customers are dressed from. Edit data/wardrobe/default_wardrobe.tres in
## the inspector to change looks: drop a new .glb into a part's `model`, set its
## `roles`, or add a colour to a palette — no code change. Regenerate the shipped
## default with tools/build_wardrobe.gd. Everything reaches this through the Wardrobe
## facade, which loads the .tres (falling back to make_default() if it is missing).

const _CHAR := "res://assets/characters/CHARTGEN2.glb"  # the single-breasted base
const _DOUBLE := "res://assets/characters/suit_doublebreasted.glb"
# Street clothes; until a file exists its outfit borrows the base model's meshes.
const _OVERSHIRT := "res://assets/characters/street_overshirt.glb"
const _OVERCOAT := "res://assets/characters/street_overcoat.glb"
const DEFAULT_SKIN := Color(0.86, 0.72, 0.60)
const DEFAULT_HAIR := Color(0.14, 0.11, 0.09)

## Heads — the face mesh (role "head"); customers pick one at random. Index 0 is the
## base model's baked head (kept in the rig), so set_head(0) needs no swap.
@export var heads: Array[WardrobePart] = []
## Hairstyles — customers pick one at random (role "hair").
@export var hairs: Array[WardrobePart] = []
## Suit tops, indexed to Enums jacket styles (a top owns the jacket, shirt, buttons,
## pocket square and tie meshes: each jacket model ships the pieces cut to fit it).
@export var tops: Array[WardrobePart] = []
## Suit bottoms, indexed to Enums pants styles (role "pants").
@export var bottoms: Array[WardrobePart] = []
## Shoe models (role "shoes"). Index 0 is the base model's pair, the one worn with
## every suit (in the wearer's own leather); street outfits bring their own.
@export var shoes: Array[WardrobePart] = []
## Street clothes customers walk in wearing, before a suit is made.
@export var street_outfits: Array[StreetOutfit] = []
## Skin tones customers spawn with.
@export var skin_colors: PackedColorArray = PackedColorArray()
## Natural hair colours customers spawn with.
@export var hair_colors: PackedColorArray = PackedColorArray()


func head(index: int) -> WardrobePart:
	return _at(heads, index)


func head_count() -> int:
	return heads.size()


func hair(index: int) -> WardrobePart:
	return _at(hairs, index)


func top(index: int) -> WardrobePart:
	return _at(tops, index)


func bottom(index: int) -> WardrobePart:
	return _at(bottoms, index)


func hair_count() -> int:
	return hairs.size()


func shoe(index: int) -> WardrobePart:
	return _at(shoes, index)


## The street outfit at `index` (clamped), or null when there are none.
func street_outfit(index: int) -> StreetOutfit:
	if street_outfits.is_empty():
		return null
	return street_outfits[clampi(index, 0, street_outfits.size() - 1)]


## A random street outfit index fitting `want` (0 if none fit, -1 if there are none).
func random_street_index(want: int, rng: RandomNumberGenerator) -> int:
	if street_outfits.is_empty():
		return -1
	var matching: Array[int] = []
	for i in street_outfits.size():
		if street_outfits[i] != null and street_outfits[i].fits(want):
			matching.append(i)
	if matching.is_empty():
		return 0
	return matching[rng.randi() % matching.size()]


func random_street_outfit(want: int, rng: RandomNumberGenerator) -> StreetOutfit:
	return street_outfit(random_street_index(want, rng))


func skin(index: int) -> Color:
	return _color(skin_colors, index, DEFAULT_SKIN)


func hair_color(index: int) -> Color:
	return _color(hair_colors, index, DEFAULT_HAIR)


## A random index into `list` among the parts that fit `want` (ANY parts always fit).
## Returns 0 if none match (so there is always a valid look), -1 if the list is empty.
func random_index(list: Array, want: int, rng: RandomNumberGenerator) -> int:
	if list.is_empty():
		return -1
	var matching: Array[int] = []
	for i in list.size():
		var part := list[i] as WardrobePart
		if part != null and part.fits(want):
			matching.append(i)
	if matching.is_empty():
		return 0
	return matching[rng.randi() % matching.size()]


## Random combo index fitting `want` — heads[i] and hairs[i] are the same glb, so this
## one index drives both the head and its own hair. Combos disabled in the face profiles
## are skipped; if that leaves none, we ignore the filter so a customer always gets a head.
func random_head_index(want: int, rng: RandomNumberGenerator) -> int:
	if heads.is_empty():
		return -1
	var profiles := FaceProfiles.load_or_default()
	var matching: Array[int] = []
	for i in heads.size():
		var part := heads[i] as WardrobePart
		if part != null and part.fits(want) and profiles.is_enabled(i):
			matching.append(i)
	if matching.is_empty():
		return random_index(heads, want, rng)
	return matching[rng.randi() % matching.size()]


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
	var double := load(_DOUBLE) as PackedScene
	var suit_roles := {
		"jacket": "jacket",
		"shirt": "shirt",
		"buttons": "buttons",
		"square": "square",
		"tie": "tie",
	}
	var pants_roles := {"pants": "legs"}
	lib.heads.append(WardrobePart.make("Base", model, {"head": "head"}))
	lib.hairs.append(WardrobePart.make("Default", model, {"hair": "Hair"}))
	# Indexed to Enums.JacketStyle.
	lib.tops.append(WardrobePart.make("Single-Breasted", model, suit_roles.duplicate()))
	lib.tops.append(WardrobePart.make("Double-Breasted", double, suit_roles.duplicate()))
	# No tuxedo model yet: the single-breasted stands in, flagged so menus skip it.
	var tuxedo := WardrobePart.make("Tuxedo", model, suit_roles.duplicate())
	tuxedo.placeholder = true
	lib.tops.append(tuxedo)
	# One bottom for now: Pleated and Shorts clamp to it (see _at).
	lib.bottoms.append(WardrobePart.make("Flat Front", model, pants_roles.duplicate()))
	lib.shoes.append(WardrobePart.make("Base Shoes", model, {"shoes": "shoes"}))
	_add_street_outfits(lib, model)
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


## The street wardrobe: an olive overshirt over a white tee with cream chinos and white
## sneakers, and a camel overcoat over a black turtleneck with charcoal flannel trousers
## and chestnut shoes. Each glb holds jacket (outer), shirt (inner), legs and shoes.
static func _add_street_outfits(lib: WardrobeLibrary, base: PackedScene) -> void:
	var fab := Enums.Fabric
	var olive := StreetOutfit.cloth(
		&"street_olive_twill", "Olive Twill", fab.COTTON, Color("5b5e3a")
	)
	var tee := StreetOutfit.cloth(&"street_white_tee", "White Tee", fab.COTTON, Color("ecebe6"))
	var chino := StreetOutfit.cloth(
		&"street_cream_chino", "Cream Chino", fab.COTTON, Color("d9ccab")
	)
	var sneakers := {"color": "white", "finish": "calf"}
	var shirt_model := _load_or(_OVERSHIRT, base)
	lib.street_outfits.append(_street("Overshirt", shirt_model, olive, tee, chino, sneakers))
	var camel := StreetOutfit.cloth(
		&"street_camel_coat", "Camel Coat", fab.FLANNEL, Color("b08658")
	)
	var knit := StreetOutfit.cloth(
		&"street_black_knit", "Black Knit", fab.WORSTED_WOOL, Color("1c1c1f")
	)
	var charcoal := StreetOutfit.cloth(
		&"street_charcoal_flannel", "Charcoal Flannel", fab.FLANNEL, Color("3d3e42")
	)
	var brogues := {"color": "chestnut", "finish": "calf"}
	var coat_model := _load_or(_OVERCOAT, base)
	lib.street_outfits.append(_street("Overcoat", coat_model, camel, knit, charcoal, brogues))


static func _street(
	label: String,
	model: PackedScene,
	outer: MaterialType,
	inner: MaterialType,
	pants: MaterialType,
	shoe_dict: Dictionary,
) -> StreetOutfit:
	var outfit := StreetOutfit.new()
	outfit.display_name = label
	outfit.top = WardrobePart.make(label + " Top", model, {"jacket": "jacket", "shirt": "shirt"})
	outfit.bottom = WardrobePart.make(label + " Trousers", model, {"pants": "legs"})
	outfit.shoe_model = WardrobePart.make(label + " Shoes", model, {"shoes": "shoes"})
	outfit.outer_mat = outer
	outfit.inner_mat = inner
	outfit.pants_mat = pants
	outfit.shoes = shoe_dict
	return outfit


## The model at `path`, or `fallback` while that file does not exist yet.
static func _load_or(path: String, fallback: PackedScene) -> PackedScene:
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps != null:
			return ps
	return fallback
