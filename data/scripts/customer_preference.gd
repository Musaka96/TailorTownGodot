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
	"Ms. Whitcombe",
	"Mr. Abara",
	"Ms. Laurent",
	"Mr. Fitzgerald",
	"Dr. Moreau",
	"Ms. Kowalski",
	"Mr. Tanaka",
	"Ms. Oyelaran",
	"Mr. Bellamy",
	"Ms. Castellanos",
	"Mr. Lindqvist",
	"Dr. Achebe",
	"Ms. Harrington",
	"Mr. Pemberton",
	"Ms. Duarte",
	"Mr. Novak",
	"Ms. Quigley",
	"Mr. Sandoval",
	"Dr. Whitlock",
	"Ms. Farrow",
]

@export var display_name: String = "Customer"
@export var occasion: Enums.Occasion = Enums.Occasion.BUSINESS
@export var style: Enums.Style = Enums.Style.CLASSIC
## Most they'll pay for the whole suit.
@export var budget: int = 400
## > 0 when this is a returning regular (their loyalty level, 1..5).
@export var regular_level: int = 0


## A random shopper's brief: an occasion, a style, and a budget for the shop's current
## reputation tier. `regular` (a name from Clientele) makes it a returning regular,
## whose loyalty raises the budget; otherwise the name avoids known regulars.
static func random_pref(rng: RandomNumberGenerator, regular := "") -> CustomerPreference:
	var p := CustomerPreference.new()
	p.display_name = regular if regular != "" else _fresh_name(rng)
	p.occasion = rng.randi() % Enums.Occasion.size()
	p.style = rng.randi() % Enums.Style.size()
	p.budget = Pricing.random_budget(rng)
	if regular != "" and Clientele != null:
		p.regular_level = Clientele.loyalty(regular)
		p.budget = int(round(p.budget * Clientele.budget_mult(regular) / 5.0)) * 5
	return p


static func _fresh_name(rng: RandomNumberGenerator) -> String:
	for _i in 12:
		var nm: String = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
		if Clientele == null or not Clientele.is_known(nm):
			return nm
	return FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]


## "Mr. Okafor" or "Mr. Okafor ★2" for a regular.
func title() -> String:
	return display_name + ("  ★%d" % regular_level if regular_level > 0 else "")


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
