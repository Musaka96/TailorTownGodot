class_name Enums

## Central enums + display-name helpers for TailorTown.
## Access as `Enums.Fabric.WORSTED_WOOL`, `Enums.fabric_name(f)`, etc.

# --- Items & crafting ---
enum GarmentType { SHIRT, PANTS, JACKET }
enum ItemKind { MATERIAL_BOLT, FABRIC_PART, GARMENT_PIECE, SUIT }
enum Stage { FABRIC_PART, CONFIGURED, CUT, SEWN }
enum Size { S, M, L, XL }

# --- Material rolls ---
enum Fabric { WORSTED_WOOL, FLANNEL, TWEED, MOHAIR_BLEND, LINEN }
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
}

# --- Bespoke brief: what the customer needs a suit for ---
enum Occasion { WEDDING, FUNERAL, BUSINESS, PARTY }
enum Style { OLDSCHOOL, CLASSIC, MODERN, FASHION }

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
	return "?"
