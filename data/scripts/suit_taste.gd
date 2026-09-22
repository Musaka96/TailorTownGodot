class_name SuitTaste

## What a customer will and won't wear, beyond the dress code. Static helpers shared by
## CustomerPreference (the mirror's verdict), BriefDirector (shaping a walk-in's brief)
## and FrontDesk (can the shop make this at all?). See docs/CUSTOMERS.md, "Taste".
##
## A dislike is { kind: "color" | "pattern" | "fabric", value: int }. A quiet one is kept
## to themselves until the player shows it at the mirror; a stated one is said at the
## counter (CustomerPreference.dislikes_color). Every dislike leaves at least one suit.

const KIND_WEIGHTS := {"color": 0.55, "pattern": 0.3, "fabric": 0.15}
## The answers nearly everyone reaches for first. A quiet dislike leans on them.
const SAFE_COLORS := [0, 1]  # navy, charcoal
const SAFE_PATTERN := 0  # plain
## What they say when a quiet dislike is shown to them, by kind then value ("_" = any).
const LINES := {
	"color":
	{
		0: "Navy again? Half my wardrobe is navy.",
		1: "Not charcoal. I look like a filing cabinet.",
		2: "Light grey shows every drop of soup.",
		3: "Black? Nobody's died.",
		5: "Brown. My father wore brown.",
		"_": "Not %s. Never suited me.",
	},
	"pattern":
	{
		0: "Plain? I'd fall asleep in it.",
		1: "No pinstripe. I'm not a banker.",
		3: "Houndstooth makes my eyes water.",
		"_": "Not %s. Too busy on me.",
	},
	"fabric":
	{
		0: "Worsted. Like a school blazer.",
		1: "Flannel itches. Something else.",
		2: "Tweed? I'd cook.",
		3: "Mohair sheds on the car seats.",
		4: "Linen creases if you look at it.",
		"_": "Not %s.",
	},
}
const OWNED_LINE := "I've got that one from you already. Something new."
const TOWN_LINE := "I keep seeing your %s about town. Something else."
const TOWN_LINE_MANY := "Half the street's in your %s now. Something else."
const TOWN_MANY := 4


static func rule_of(pref: CustomerPreference) -> DressRule:
	if Catalog.dress_code == null:
		return null
	return Catalog.dress_code.rule_for(pref.occasion, pref.style)


## Jacket colours the brief allows (all suitings when the rule doesn't say).
static func brief_colors(pref: CustomerPreference) -> Array:
	var rule := rule_of(pref)
	if rule != null and not rule.allowed_colors.is_empty():
		return rule.allowed_colors.duplicate()
	return Array(MaterialFactory.colors_for(Enums.GarmentType.JACKET))


## Jacket patterns the brief allows; plain drops out when it must have a pattern.
static func brief_patterns(pref: CustomerPreference) -> Array:
	var rule := rule_of(pref)
	var out: Array = Array(Enums.patterns_for(Enums.GarmentType.JACKET))
	if rule != null and not rule.allowed_patterns.is_empty():
		out = rule.allowed_patterns.duplicate()
	if rule != null and rule.require_pattern:
		out.erase(Enums.Pattern.SOLID)
	return out


## Suit cloths the brief allows that a supplier you can buy from sells, less a cloth
## they won't wear. `supplied_only` false also counts cloth you couldn't reorder.
static func fabrics(pref: CustomerPreference, supplied_only := true) -> Array:
	var rule := rule_of(pref)
	var allowed: Array = Array(Enums.fabrics_for(Enums.GarmentType.JACKET))
	if rule != null and not rule.allowed_fabrics.is_empty():
		allowed = rule.allowed_fabrics.duplicate()
	var supplied := {}
	for v in Upgrades.unlocked_vendors():
		for f in v.get("fabrics", []):
			supplied[int(f)] = true
	var out: Array = []
	for f in allowed:
		if supplied_only and not supplied.has(int(f)):
			continue
		if not _is(pref.quiet_dislike, "fabric", int(f)):
			out.append(int(f))
	return out


## Every [colour, pattern] suit this customer would say yes to: the brief's, less their
## dislikes (stated or quiet) and anything they already bought from you.
static func options(pref: CustomerPreference) -> Array:
	var out: Array = []
	for c in brief_colors(pref):
		if int(c) == pref.dislikes_color or _is(pref.quiet_dislike, "color", int(c)):
			continue
		for p in brief_patterns(pref):
			if _is(pref.quiet_dislike, "pattern", int(p)):
				continue
			if [int(c), int(p)] in pref.owned_suits:
				continue
			out.append([int(c), int(p)])
	return out


## Would the brief still leave them a suit (and a shirt) with this dislike added?
static func leaves_room(pref: CustomerPreference, dislike: Dictionary) -> bool:
	if dislike.get("kind", "") == "color" and int(dislike["value"]) >= _suit_colors():
		var shirts := DressCode.shirt_colors(pref.occasion, pref.style)
		return shirts.is_empty() or shirts.any(func(c: int) -> bool: return c != dislike["value"])
	var saved := pref.quiet_dislike
	pref.quiet_dislike = dislike
	var ok := not options(pref).is_empty() and not fabrics(pref).is_empty()
	pref.quiet_dislike = saved
	return ok


## A quiet dislike for this brief, or {} when none fits. Leans on the safe answers by
## GameConfig.safe_lean_by_tier; cloth only from cloth_dislike_from_tier.
static func roll_quiet(
	pref: CustomerPreference, rng: RandomNumberGenerator, tier: int
) -> Dictionary:
	var lean := _tier_value(Config.data.safe_lean_by_tier if Config.data != null else [], tier, 1.0)
	var cloth_from: int = Config.data.cloth_dislike_from_tier if Config.data != null else 1
	var pools := {
		"color": brief_colors(pref),
		"pattern": brief_patterns(pref),
		"fabric": fabrics(pref) if tier >= cloth_from else [],
	}
	var kinds: Array = []
	for k: String in KIND_WEIGHTS:
		if (pools[k] as Array).size() > 1:
			kinds.append({"v": k, "w": float(KIND_WEIGHTS[k])})
	if kinds.is_empty():
		return {}
	var kind: String = _weighted(rng, kinds)
	var values: Array = []
	for v in pools[kind]:
		var safe: bool = (
			(kind == "color" and int(v) in SAFE_COLORS)
			or (kind == "pattern" and int(v) == SAFE_PATTERN)
			or (kind == "fabric" and int(v) == Enums.Fabric.WORSTED_WOOL)
		)
		values.append({"v": int(v), "w": lean if safe else 1.0})
	var dislike := {"kind": kind, "value": int(_weighted(rng, values))}
	return dislike if leaves_room(pref, dislike) else {}


## Does this design break the dislike? Colour, pattern and cloth are the suit's (jacket
## or trousers); a shirting colour is the shirt's.
static func hits(dislike: Dictionary, design: Dictionary) -> bool:
	if dislike.is_empty():
		return false
	var kind: String = dislike.get("kind", "")
	var value := int(dislike.get("value", -1))
	var key: String = {"color": "color", "pattern": "pattern", "fabric": "fabric"}.get(kind, "")
	var parts := [Enums.GarmentType.JACKET, Enums.GarmentType.PANTS]
	if kind == "color" and value >= _suit_colors():
		parts = [Enums.GarmentType.SHIRT]
	for t in parts:
		var spec: Dictionary = design.get(t, {})
		if not spec.is_empty() and int(spec.get(key, -1)) == value:
			return true
	return false


## The jacket's colour and pattern are one they already bought from you.
static func owns(owned: Array, design: Dictionary) -> bool:
	var jacket: Dictionary = design.get(Enums.GarmentType.JACKET, {})
	if jacket.is_empty():
		return false
	return [int(jacket.get("color", -1)), int(jacket.get("pattern", -1))] in owned


## What they say when the design breaks their quiet dislike.
static func line(dislike: Dictionary) -> String:
	var by_value: Dictionary = LINES.get(dislike.get("kind", ""), {})
	var value := int(dislike.get("value", -1))
	if by_value.has(value):
		return by_value[value]
	return str(by_value.get("_", "Not that.")) % word(dislike)


## "no flannel", "no navy", "no pink shirt".
static func short(dislike: Dictionary) -> String:
	var what := word(dislike)
	if dislike.get("kind", "") == "color" and int(dislike.get("value", -1)) >= _suit_colors():
		what += " shirt"
	return "no " + what


static func word(dislike: Dictionary) -> String:
	var value := int(dislike.get("value", -1))
	match dislike.get("kind", ""):
		"color":
			return MaterialFactory.color_name(value).to_lower()
		"pattern":
			return "plain" if value == Enums.Pattern.SOLID else Enums.pattern_name(value).to_lower()
		"fabric":
			return Enums.fabric_name(value).to_lower()
	return "that"


static func town_line(color: int, worn: int) -> String:
	var said := TOWN_LINE_MANY if worn >= TOWN_MANY else TOWN_LINE
	return said % MaterialFactory.color_name(color).to_lower()


# --- Cloth and money -------------------------------------------------------------


## Metres of suiting one suit takes (jacket + trousers, size M), in whole metres as the
## phone sells it.
static func cut_metres() -> float:
	var need := Pricing.part_meters(Enums.GarmentType.JACKET)
	need += Pricing.part_meters(Enums.GarmentType.PANTS)
	return ceilf(need - 0.001)


## Cheapest suiting cut (one suit's worth) that would satisfy them, or -1 for none.
static func cheapest_cut(pref: CustomerPreference) -> int:
	var best := -1
	var pats := {}
	for o: Array in options(pref):
		pats[int(o[1])] = true
	var discount := 1.0 - Pricing.market_discount()
	for p: int in pats:
		for f: int in fabrics(pref):
			var cost := roundi(
				Pricing.per_meter(f, p) * cut_metres() * Pricing.fabric_premium(f) * discount
			)
			if best < 0 or cost < best:
				best = cost
	return best


## The cheapest whole-suit quote that would satisfy them, or -1 for none.
static func cheapest_quote(pref: CustomerPreference) -> int:
	var best := -1
	var shirts := DressCode.shirt_colors(pref.occasion, pref.style)
	var shirt_color := int(shirts[0]) if not shirts.is_empty() else _suit_colors()
	for o: Array in options(pref):
		for f: int in fabrics(pref):
			var suit := {"fabric": f, "pattern": int(o[1]), "color": int(o[0])}
			var design := {
				Enums.GarmentType.JACKET: suit,
				Enums.GarmentType.PANTS: suit,
				Enums.GarmentType.SHIRT:
				{"fabric": Enums.Fabric.COTTON, "pattern": 0, "color": shirt_color},
			}
			var quote := Pricing.suit_quote(design)
			if best < 0 or quote < best:
				best = quote
	return best


## Is there enough cloth on hand (ClothStock.stock entries) for a suit they'd take?
static func shelf_serves(pref: CustomerPreference, stock: Dictionary) -> bool:
	var need := Pricing.part_meters(Enums.GarmentType.JACKET)
	need += Pricing.part_meters(Enums.GarmentType.PANTS)
	var cloths := fabrics(pref, false)
	var wanted := options(pref)
	for entry: Dictionary in stock.values():
		if float(entry.get("have", 0.0)) + 0.001 < need:
			continue
		if not int(entry.get("fabric", -1)) in cloths:
			continue
		if [int(entry.get("color", -1)), int(entry.get("pattern", -1))] in wanted:
			return true
	return false


# --- Internals -------------------------------------------------------------------


static func _is(dislike: Dictionary, kind: String, value: int) -> bool:
	return dislike.get("kind", "") == kind and int(dislike.get("value", -1)) == value


static func _suit_colors() -> int:
	return MaterialFactory.SUIT_COLOR_COUNT


static func _tier_value(values: Array, tier: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return float(values[clampi(tier, 0, values.size() - 1)])


## Pick one of [{ v, w }] by weight.
static func _weighted(rng: RandomNumberGenerator, items: Array) -> Variant:
	var total := 0.0
	for it: Dictionary in items:
		total += float(it["w"])
	var roll := rng.randf() * total
	for it: Dictionary in items:
		roll -= float(it["w"])
		if roll <= 0.0:
			return it["v"]
	return items[-1]["v"]
