class_name Enums

## Central enums + display-name helpers for TailorTown.
## Access as `Enums.Fabric.WORSTED_WOOL`, `Enums.fabric_name(f)`, etc.

# --- Items & crafting ---
enum GarmentType { SHIRT, PANTS, JACKET }
enum ItemKind { MATERIAL_BOLT, FABRIC_PART, GARMENT_PIECE, SUIT }
enum Stage { FABRIC_PART, CONFIGURED, CUT, SEWN }
enum Size { S, M, L, XL }

# --- Material rolls ---
# Suitings first (jacket/trousers), then light shirtings (cotton family) appended so
# existing indices are unchanged. Which fabrics a part may use comes from fabrics_for().
enum Fabric { WORSTED_WOOL, FLANNEL, TWEED, MOHAIR_BLEND, LINEN, COTTON, POPLIN, OXFORD_CLOTH }
# Suiting patterns first, then crisp shirting patterns appended. patterns_for() decides
# which a part may use.
enum Pattern {
	SOLID,
	PINSTRIPE,
	HERRINGBONE,
	HOUNDSTOOTH,
	WINDOWPANE,
	GLEN_CHECK,
	BIRDSEYE,
	SHARKSKIN,
	NAILHEAD,
	BENGAL_STRIPE,
	UNIVERSITY_STRIPE,
	GINGHAM,
	TATTERSALL,
	END_ON_END,
}

# --- Bespoke brief: what the customer needs a suit for ---
enum Occasion { WEDDING, FUNERAL, BUSINESS, PARTY }
enum Style { OLDSCHOOL, CLASSIC, MODERN, FASHION }

# --- Character identity ---
# Gender tag for wardrobe parts and characters. ANY = unisex (usable by either);
# a character is only ever MALE or FEMALE.
enum Gender { ANY, MALE, FEMALE }

# --- Garment styling (used from Phase 3+) ---
enum JacketStyle { SINGLE_BREASTED, DOUBLE_BREASTED }
enum Lapel { NOTCH, PEAK, SHAWL }
enum PantsStyle { FLAT_FRONT, PLEATED }
enum PantsLength { LONG, SHORT }
enum Fit { SHORT, REGULAR, LONG }  # jacket length S / R / L


static func fabric_name(f: Fabric) -> String:
	match f:
		Fabric.WORSTED_WOOL:
			return "Worsted Wool"
		Fabric.FLANNEL:
			return "Flannel"
		Fabric.TWEED:
			return "Tweed"
		Fabric.MOHAIR_BLEND:
			return "Mohair Blend"
		Fabric.LINEN:
			return "Linen"
		Fabric.COTTON:
			return "Cotton"
		Fabric.POPLIN:
			return "Poplin"
		Fabric.OXFORD_CLOTH:
			return "Oxford Cloth"
	return "?"


# Params are int (not the enum type) because class_name Style (the UI kit) would
# otherwise shadow the Style enum in these signatures.
static func occasion_name(o: int) -> String:
	match o:
		Occasion.WEDDING:
			return "Wedding"
		Occasion.FUNERAL:
			return "Funeral"
		Occasion.BUSINESS:
			return "Business"
		Occasion.PARTY:
			return "Party"
	return "?"


static func style_name(s: int) -> String:
	match s:
		Style.OLDSCHOOL:
			return "Old-School"
		Style.CLASSIC:
			return "Classic"
		Style.MODERN:
			return "Modern"
		Style.FASHION:
			return "Fashion"
	return "?"


static func gender_name(g: int) -> String:
	match g:
		Gender.ANY:
			return "Any"
		Gender.MALE:
			return "Male"
		Gender.FEMALE:
			return "Female"
	return "?"


static func garment_type_name(t: GarmentType) -> String:
	match t:
		GarmentType.SHIRT:
			return "Shirt"
		GarmentType.PANTS:
			return "Pants"
		GarmentType.JACKET:
			return "Jacket"
	return "?"


static func size_name(s: Size) -> String:
	match s:
		Size.S:
			return "S"
		Size.M:
			return "M"
		Size.L:
			return "L"
		Size.XL:
			return "XL"
	return "?"


## Style options per garment type (the first is the default).
static func styles_for(t: GarmentType) -> PackedStringArray:
	match t:
		GarmentType.SHIRT:
			return PackedStringArray(["Classic", "Slim"])
		GarmentType.PANTS:
			return PackedStringArray(["Flat Front", "Pleated", "Shorts"])
		GarmentType.JACKET:
			return PackedStringArray(["Single-Breasted", "Double-Breasted"])
	return PackedStringArray(["Classic"])


## Fabrics a garment type may be made from (the first is the default): light, crisp
## shirtings for the shirt; heavier suitings for the jacket and trousers. A shirt has
## no business being cut from tweed, so it simply isn't offered.
static func fabrics_for(t: GarmentType) -> PackedInt32Array:
	if t == GarmentType.SHIRT:
		return PackedInt32Array([Fabric.COTTON, Fabric.POPLIN, Fabric.OXFORD_CLOTH, Fabric.LINEN])
	return PackedInt32Array(
		[Fabric.WORSTED_WOOL, Fabric.FLANNEL, Fabric.TWEED, Fabric.MOHAIR_BLEND, Fabric.LINEN]
	)


## Patterns a garment type may use (the first is the default): shirting stripes and
## checks for the shirt; classic suiting weaves for the jacket and trousers.
static func patterns_for(t: GarmentType) -> PackedInt32Array:
	if t == GarmentType.SHIRT:
		return PackedInt32Array(
			[
				Pattern.SOLID,
				Pattern.BENGAL_STRIPE,
				Pattern.UNIVERSITY_STRIPE,
				Pattern.GINGHAM,
				Pattern.TATTERSALL,
				Pattern.END_ON_END,
			]
		)
	return PackedInt32Array(
		[
			Pattern.SOLID,
			Pattern.PINSTRIPE,
			Pattern.HERRINGBONE,
			Pattern.HOUNDSTOOTH,
			Pattern.WINDOWPANE,
			Pattern.GLEN_CHECK,
			Pattern.BIRDSEYE,
			Pattern.SHARKSKIN,
			Pattern.NAILHEAD,
		]
	)


static func pattern_name(p: Pattern) -> String:
	match p:
		Pattern.SOLID:
			return "Solid"
		Pattern.PINSTRIPE:
			return "Pinstripe"
		Pattern.HERRINGBONE:
			return "Herringbone"
		Pattern.HOUNDSTOOTH:
			return "Houndstooth"
		Pattern.WINDOWPANE:
			return "Windowpane"
		Pattern.GLEN_CHECK:
			return "Glen Check"
		Pattern.BIRDSEYE:
			return "Birdseye"
		Pattern.SHARKSKIN:
			return "Sharkskin"
		Pattern.NAILHEAD:
			return "Nailhead"
		Pattern.BENGAL_STRIPE:
			return "Bengal Stripe"
		Pattern.UNIVERSITY_STRIPE:
			return "University Stripe"
		Pattern.GINGHAM:
			return "Gingham"
		Pattern.TATTERSALL:
			return "Tattersall"
		Pattern.END_ON_END:
			return "End-on-End"
	return "?"
