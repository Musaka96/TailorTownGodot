class_name Wardrobe

## Facade over the editable wardrobe asset (data/wardrobe/default_wardrobe.tres, a
## WardrobeLibrary). Everything in the game reaches wardrobe data through here so no
## caller hard-codes the asset path. Add or change looks by editing the .tres in the
## inspector — hairstyles, suit tops/bottoms, and the skin/hair colour palettes all
## live there — or regenerate the default with tools/build_wardrobe.gd. No code
## change is needed to add a new hairstyle, suit style, skin tone or hair colour.

const LIBRARY_PATH := "res://data/wardrobe/default_wardrobe.tres"

static var _lib: WardrobeLibrary


## The loaded library (cached). Falls back to the in-code default if the asset is
## missing so the game never crashes on a fresh checkout without the .tres.
static func library() -> WardrobeLibrary:
	if _lib == null:
		_lib = load(LIBRARY_PATH) as WardrobeLibrary
	if _lib == null:
		_lib = WardrobeLibrary.make_default()
	return _lib


# --- Clothing parts --------------------------------------------------------


static func head(index: int) -> WardrobePart:
	return library().head(index)


static func head_count() -> int:
	return library().head_count()


static func hair(index: int) -> WardrobePart:
	return library().hair(index)


static func top(index: int) -> WardrobePart:
	return library().top(index)


static func bottom(index: int) -> WardrobePart:
	return library().bottom(index)


static func street_top() -> WardrobePart:
	return library().street_top


static func street_bottom() -> WardrobePart:
	return library().street_bottom


static func hair_count() -> int:
	return library().hair_count()


# --- Colour palettes -------------------------------------------------------


static func skin(index: int) -> Color:
	return library().skin(index)


static func skin_count() -> int:
	return library().skin_colors.size()


static func hair_color(index: int) -> Color:
	return library().hair_color(index)


static func hair_color_count() -> int:
	return library().hair_colors.size()


## Random combo index (a head and its matching hair share the same index) fitting the
## given gender. Head + hair are never mixed — only their colours vary.
static func random_head_index(gender: int, rng: RandomNumberGenerator) -> int:
	return library().random_head_index(gender, rng)


static func random_skin(rng: RandomNumberGenerator) -> Color:
	return library().random_skin(rng)


static func random_hair_color(rng: RandomNumberGenerator) -> Color:
	return library().random_hair_color(rng)
