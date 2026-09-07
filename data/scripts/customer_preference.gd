class_name CustomerPreference
extends Resource

## What a walk-in customer needs: an occasion and an aesthetic style (plus a
## budget). The player has to figure out a suit that fits the brief — suitability
## is judged by the configurable DressCode rulebook (Catalog.dress_code), not by a
## fixed colour/pattern the customer names outright. Generated at runtime by the
## CustomerManager.

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
@export var occasion: Enums.Occasion = Enums.Occasion.BUSINESS
@export var style: Enums.Style = Enums.Style.CLASSIC
## Most they'll pay for the whole suit.
@export var budget: int = 400


## A random shopper's brief: an occasion, a style, and a comfortable budget.
static func random_pref(rng: RandomNumberGenerator) -> CustomerPreference:
	var p := CustomerPreference.new()
	p.display_name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	p.occasion = rng.randi() % Enums.Occasion.size()
	p.style = rng.randi() % Enums.Style.size()
	p.budget = int(round(rng.randf_range(320, 500)))
	return p


## Short brief, e.g. "Funeral · Classic".
func describe() -> String:
	return "%s · %s" % [Enums.occasion_name(occasion), Enums.style_name(style)]


## The dress-code hint shown to the player ("Sombre and plain…").
func hint() -> String:
	if Catalog.dress_code != null:
		return Catalog.dress_code.hint_for(occasion, style)
	return ""


## Judge a proposed design against the brief + budget (delegates to DressCode).
func evaluate(design: Dictionary) -> Dictionary:
	if Catalog.dress_code != null:
		return Catalog.dress_code.evaluate(occasion, style, design, budget)
	return {"suitable": false, "quote": Pricing.suit_quote(design), "reason": "…", "reasons": []}
