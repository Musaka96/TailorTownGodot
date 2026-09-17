class_name Pricing

## Central pricing rules for ordering cloth. Price scales with length; fabric and
## pattern each add a per-metre cost. Keep all money math here so it stays
## consistent between premade and custom orders.

# Per-metre base cost by Enums.Fabric.
const FABRIC_BASE := {
	Enums.Fabric.WORSTED_WOOL: 20,
	Enums.Fabric.FLANNEL: 22,
	Enums.Fabric.TWEED: 18,
	Enums.Fabric.MOHAIR_BLEND: 30,
	Enums.Fabric.LINEN: 16,
	Enums.Fabric.COTTON: 12,
	Enums.Fabric.POPLIN: 16,
	Enums.Fabric.OXFORD_CLOTH: 18,
}

# Per-metre surcharge by Enums.Pattern (weaving a pattern costs more).
const PATTERN_SURCHARGE := {
	Enums.Pattern.SOLID: 0,
	Enums.Pattern.PINSTRIPE: 6,
	Enums.Pattern.HERRINGBONE: 5,
	Enums.Pattern.HOUNDSTOOTH: 6,
	Enums.Pattern.WINDOWPANE: 5,
	Enums.Pattern.GLEN_CHECK: 7,
	Enums.Pattern.BIRDSEYE: 6,
	Enums.Pattern.SHARKSKIN: 5,
	Enums.Pattern.NAILHEAD: 5,
	Enums.Pattern.BENGAL_STRIPE: 4,
	Enums.Pattern.UNIVERSITY_STRIPE: 4,
	Enums.Pattern.GINGHAM: 5,
	Enums.Pattern.TATTERSALL: 6,
	Enums.Pattern.END_ON_END: 3,
}

# Cloth each part consumes (metres, size M) — the worktable requires a piece at least this
# long, and bespoke quotes use it too.
const PART_METERS := {
	Enums.GarmentType.JACKET: 2.0,
	Enums.GarmentType.PANTS: 1.4,
	Enums.GarmentType.SHIRT: 1.6,
}
# Bigger sizes take more cloth (Enums.Size -> multiplier).
const SIZE_FACTOR := {
	Enums.Size.S: 0.9,
	Enums.Size.M: 1.0,
	Enums.Size.L: 1.1,
	Enums.Size.XL: 1.2,
}


## Metres of cloth a `garment_type` part of `size` needs, rounded UP to 0.1 m (the shelf's
## measuring step), so a piece cut to the displayed length always fits.
static func part_meters(garment_type: int, size: int = Enums.Size.M) -> float:
	var base: float = PART_METERS.get(garment_type, 1.6)
	var raw: float = base * float(SIZE_FACTOR.get(size, 1.0))
	return ceilf(raw * 10.0 - 0.001) / 10.0


static func per_meter(fabric: Enums.Fabric, pattern: Enums.Pattern) -> int:
	var cfg := Config.data
	var base := int(FABRIC_BASE.get(fabric, 20))
	var surcharge := int(PATTERN_SURCHARGE.get(pattern, 0))
	if cfg != null:
		if fabric < cfg.fabric_price_per_m.size():
			base = cfg.fabric_price_per_m[fabric]
		if pattern < cfg.pattern_surcharge_per_m.size():
			surcharge = cfg.pattern_surcharge_per_m[pattern]
	return base + surcharge


## Total price of a bolt: prefer the material's own per-metre price (premade),
## fall back to computing it (custom).
static func roll_price(mat: MaterialType, length: float) -> int:
	var pm := mat.price_per_meter if mat.price_per_meter > 0 else per_meter(mat.fabric, mat.pattern)
	return int(round(pm * length))


## What we charge a customer for a designed suit: cloth cost across all parts
## times the sell markup. `design` maps GarmentType -> { fabric, pattern, ... }.
static func suit_quote(design: Dictionary) -> int:
	var markup := 2.4
	if Config.data != null:
		markup = Config.data.sell_markup
	var cloth := 0.0
	for t in design:
		var c: Dictionary = design[t]
		var meters: float = PART_METERS.get(t, 1.6)
		cloth += per_meter(c["fabric"], c["pattern"]) * meters
	return int(round(cloth * markup))
