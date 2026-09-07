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
}


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
