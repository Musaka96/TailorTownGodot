class_name CustomerPreference
extends Resource

## What a walk-in customer wants from their suit and how much they'll pay.
## Taste is expressed on the signature piece (the jacket): a preferred fabric,
## colour and pattern. The shirt and pants can be anything — only the jacket is
## judged when the customer decides whether they love a design. Budget caps the
## quoted price. Generated at runtime by the CustomerManager.

const FIRST_NAMES := [
	"Mr. Ellison",
	"Ms. Portobello",
	"Dr. Vance",
	"Mr. Okafor",
	"Ms. Ito",
	"Mr. Delgado",
	"Ms. Byrne",
	"Mr. Rossi",
	"Ms. Nadeem",
	"Mr. Halloran",
]

@export var display_name: String = "Customer"
## Jacket taste (indices match Enums / MaterialFactory palette).
@export var fabric: int = Enums.Fabric.WORSTED_WOOL
@export var color: int = 0
@export var pattern: int = Enums.Pattern.SOLID
## Most they'll pay for the whole suit.
@export var budget: int = 400


## A random shopper's brief. Budget is set so their own ideal is comfortably
## affordable, then padded a little so a good match isn't razor-thin on money.
static func random_pref(rng: RandomNumberGenerator) -> CustomerPreference:
	var p := CustomerPreference.new()
	p.display_name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	p.fabric = rng.randi() % 5
	p.color = rng.randi() % MaterialFactory.color_count()
	p.pattern = rng.randi() % 9
	# Quote an all-matching suit and give them 15–45% headroom over it.
	var ideal := {}
	for t in Pricing.PART_METERS:
		ideal[t] = {"fabric": p.fabric, "pattern": p.pattern}
	var base := Pricing.suit_quote(ideal)
	p.budget = int(round(base * rng.randf_range(1.15, 1.45)))
	return p


## Human-readable brief, e.g. "Navy Pinstripe Worsted Wool".
func describe() -> String:
	var parts := [MaterialFactory.color_name(color)]
	if pattern != Enums.Pattern.SOLID:
		parts.append(Enums.pattern_name(pattern))
	parts.append(Enums.fabric_name(fabric))
	return " ".join(parts)


## How closely a design's JACKET matches this taste, 0..1
## (fabric 0.4, colour 0.3, pattern 0.3).
func taste_score(design: Dictionary) -> float:
	var jacket: Dictionary = design.get(Enums.GarmentType.JACKET, {})
	if jacket.is_empty():
		return 0.0
	var score := 0.0
	if int(jacket.get("fabric", -1)) == fabric:
		score += 0.4
	if int(jacket.get("color", -1)) == color:
		score += 0.3
	if int(jacket.get("pattern", -1)) == pattern:
		score += 0.3
	return score


## Evaluate a proposed design: is it loved, is it affordable, and why not.
func evaluate(design: Dictionary) -> Dictionary:
	var score := taste_score(design)
	var quote := Pricing.suit_quote(design)
	var affordable := quote <= budget
	var likes_style := score >= 0.6
	var reason := ""
	if not likes_style:
		reason = "Not quite my style…"
	elif not affordable:
		reason = "A bit over my budget."
	else:
		reason = "I love it!"
	return {
		"liked": likes_style and affordable,
		"score": score,
		"quote": quote,
		"affordable": affordable,
		"reason": reason,
	}
