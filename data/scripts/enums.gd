class_name Enums

## Central enums + display-name helpers for TailorTown.
## Access as `Enums.Fabric.WORSTED_WOOL`, `Enums.fabric_name(f)`, etc.

# --- Items & crafting ---
enum GarmentType { SHIRT, PANTS, JACKET }
enum ItemKind { MATERIAL_BOLT, FABRIC_PART, GARMENT_PIECE, SUIT }
enum Stage { FABRIC_PART, CONFIGURED, CUT, SEWN }

# --- Material rolls ---
enum Fabric { WORSTED_WOOL, FLANNEL, TWEED, MOHAIR_BLEND, LINEN }
enum Pattern {
	SOLID, PINSTRIPE, HERRINGBONE, HOUNDSTOOTH, WINDOWPANE,
	GLEN_CHECK, BIRDSEYE, SHARKSKIN, NAILHEAD,
}

# --- Garment styling (used from Phase 3+) ---
enum JacketStyle { SINGLE_BREASTED, DOUBLE_BREASTED }
enum Lapel { NOTCH, PEAK, SHAWL }
enum PantsStyle { FLAT_FRONT, PLEATED }
enum PantsLength { LONG, SHORT }
enum Fit { SHORT, REGULAR, LONG }  # jacket length S / R / L


static func fabric_name(f: Fabric) -> String:
	match f:
		Fabric.WORSTED_WOOL: return "Worsted Wool"
		Fabric.FLANNEL: return "Flannel"
		Fabric.TWEED: return "Tweed"
		Fabric.MOHAIR_BLEND: return "Mohair Blend"
		Fabric.LINEN: return "Linen"
	return "?"


static func pattern_name(p: Pattern) -> String:
	match p:
		Pattern.SOLID: return "Solid"
		Pattern.PINSTRIPE: return "Pinstripe"
		Pattern.HERRINGBONE: return "Herringbone"
		Pattern.HOUNDSTOOTH: return "Houndstooth"
		Pattern.WINDOWPANE: return "Windowpane"
		Pattern.GLEN_CHECK: return "Glen Check"
		Pattern.BIRDSEYE: return "Birdseye"
		Pattern.SHARKSKIN: return "Sharkskin"
		Pattern.NAILHEAD: return "Nailhead"
	return "?"
