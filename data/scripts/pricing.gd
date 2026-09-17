class_name Pricing

## All money math lives here (see docs/ECONOMY.md).
##
## Cloth: per-metre price by fabric + pattern, × the supplier's price multiplier, with
## bulk discounts for long bolts and a market-day discount every few days.
## Suits (Option B, "cloth + craft"): the customer pays for the cloth the parts need
## (+ the tailor's handling margin, + the premium of the supplier that stocks it) plus a
## craft fee per part scaled by reputation. Waste is the tailor's own cost, so measuring
## and ordering carefully keeps the whole fee. Tunables: res://data/game_config.tres.

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


# --- Cloth ordering ----------------------------------------------------------


## Price of a bolt of `mat`, `length` metres long, from supplier `vendor` (index into
## Upgrades.VENDORS): per-metre × supplier multiplier × bulk × market-day discounts.
static func roll_price(mat: MaterialType, length: float, vendor := 0) -> int:
	var pm := mat.price_per_meter if mat.price_per_meter > 0 else per_meter(mat.fabric, mat.pattern)
	var total := pm * length * vendor_mult(vendor) * (1.0 - bulk_discount(length))
	total *= 1.0 - market_discount()
	return int(round(total))


## Supplier price multiplier (premium mills charge more per metre).
static func vendor_mult(vendor: int) -> float:
	if vendor < 0 or vendor >= Upgrades.VENDORS.size():
		return 1.0
	return float(Upgrades.VENDORS[vendor].get("price_mult", 1.0))


## Per-metre discount for a bolt of `length` metres.
static func bulk_discount(length: float) -> float:
	var c := Config.data
	if length >= 20.0 - 0.001:
		return c.bulk_20m_discount if c != null else 0.2
	if length >= 10.0 - 0.001:
		return c.bulk_10m_discount if c != null else 0.1
	return 0.0


## Today's market-day discount (0 on ordinary days).
static func market_discount() -> float:
	return (
		(Config.data.market_discount if Config.data != null else 0.25) if is_market_day() else 0.0
	)


static func is_market_day(day := -1) -> bool:
	var every: int = Config.data.market_day_every if Config.data != null else 5
	if day < 0:
		day = Shift.day if Shift != null else 1
	return every > 0 and day % every == 0


# --- Suit price (cloth + craft) --------------------------------------------------


## What we charge a customer for a designed suit. `design` maps GarmentType ->
## { fabric, pattern, ... }. See quote_breakdown().
static func suit_quote(design: Dictionary, tier := -1) -> int:
	return int(quote_breakdown(design, tier)["total"])


## { cloth, craft, total } for a design at reputation `tier` (-1 = the shop's current).
## Cloth = list price of the metres each part needs (size M) × the premium of the
## cheapest supplier that stocks the fabric × (1 + handling). Craft = per-part fee ×
## the tier multiplier.
static func quote_breakdown(design: Dictionary, tier := -1) -> Dictionary:
	if tier < 0:
		tier = Reputation.tier() if Reputation != null else 0
	var handling: float = Config.data.cloth_handling if Config.data != null else 0.1
	var cloth := 0.0
	var craft := 0.0
	for t in design:
		var c: Dictionary = design[t]
		var metres := part_meters(int(t))
		var fabric := int(c.get("fabric", 0))
		cloth += per_meter(fabric, int(c.get("pattern", 0))) * metres * fabric_premium(fabric)
		craft += craft_fee(int(t))
	cloth *= 1.0 + handling
	craft *= craft_mult(tier)
	var total := int(round(cloth + craft))
	return {"cloth": int(round(cloth)), "craft": int(round(craft)), "total": total}


## Base craft fee for one part (size M).
static func craft_fee(garment_type: int) -> int:
	var c := Config.data
	match garment_type:
		Enums.GarmentType.JACKET:
			return c.craft_fee_jacket if c != null else 90
		Enums.GarmentType.PANTS:
			return c.craft_fee_pants if c != null else 50
	return c.craft_fee_shirt if c != null else 40


static func craft_mult(tier: int) -> float:
	var c := Config.data
	if c == null or c.craft_mult_by_tier.is_empty():
		return 1.0
	return c.craft_mult_by_tier[clampi(tier, 0, c.craft_mult_by_tier.size() - 1)]


## Price multiplier of the lowest-tier supplier that stocks `fabric` (1.0 for basics).
static func fabric_premium(fabric: int) -> float:
	for i in Upgrades.VENDORS.size():
		if fabric in Upgrades.VENDORS[i]["fabrics"]:
			return vendor_mult(i)
	return 1.0


# --- Payout ------------------------------------------------------------------


## Share of the agreed price paid for a finished order with this match×quality `score`:
## full pay across a wide "good enough" band, easing down below it.
static func pay_share(score: float) -> float:
	var c := Config.data
	var full: float = c.full_pay_at if c != null else 0.6
	var low: float = c.low_pay_at if c != null else 0.4
	if score >= full:
		return 1.0
	if score >= low:
		return lerpf(0.6, 1.0, (score - low) / maxf(full - low, 0.001))
	return 0.6 * clampf(score / maxf(low, 0.001), 0.0, 1.0)


## Tip share (0..tip_max) for excellent work.
static func tip_share(score: float) -> float:
	var c := Config.data
	var from: float = c.tip_from if c != null else 0.9
	var top: float = c.tip_max if c != null else 0.25
	if score < from:
		return 0.0
	return top * clampf((score - from) / maxf(1.0 - from, 0.001), 0.0, 1.0)


## A customer's budget at reputation `tier` (before any loyalty bonus).
static func random_budget(rng: RandomNumberGenerator, tier := -1) -> int:
	if tier < 0:
		tier = Reputation.tier() if Reputation != null else 0
	var c := Config.data
	if c == null or c.budget_min_by_tier.is_empty():
		return int(round(rng.randf_range(300, 450)))
	var i := clampi(tier, 0, mini(c.budget_min_by_tier.size(), c.budget_max_by_tier.size()) - 1)
	return int(round(rng.randf_range(c.budget_min_by_tier[i], c.budget_max_by_tier[i]) / 5.0)) * 5
