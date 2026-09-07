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

# Cloth a finished suit consumes per part (metres), for quoting a bespoke order.
const PART_METERS := {
	Enums.GarmentType.JACKET: 2.0,
	Enums.GarmentType.PANTS: 1.4,
	Enums.GarmentType.SHIRT: 1.6,
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
