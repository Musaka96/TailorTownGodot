class_name CustomerPreference
extends Resource

## What a walk-in customer needs: an occasion and an aesthetic style (plus a
## budget). The player has to figure out a suit that fits the brief — suitability
## is judged by the configurable DressCode rulebook (Catalog.dress_code), not by a
## fixed colour/pattern the customer names outright. Generated at runtime by the
## CustomerManager.

## How many customers voice a colour, and of those, how many as a like.
const TASTE_CHANCE := 0.6
const LIKE_SHARE := 0.5
## How many voiced tastes are about the shirt rather than the suit.
const SHIRT_TASTE := 0.35
## The colours nearly everyone makes by default: a dislike lands on one of them more
## often than not (navy, charcoal; the white shirt).
const USUAL_SUIT := [0, 1]
const USUAL_SHIRT := [10]
const USUAL_DISLIKE := 0.7
## What they say about a colour, by kind; one is picked per customer by their name.
const SAY_SUIT_LIKE := [
	"I've always fancied a %s suit.",
	"%s, if you can manage it.",
	"Something in %s. My brother has one.",
]
const SAY_SUIT_DISLIKE := [
	"Anything but %s.",
	"No %s. I've three already.",
	"Not %s. I look like a bus conductor in it.",
]
const SAY_SHIRT_LIKE := ["A %s shirt, I thought.", "Could the shirt be %s?"]
const SAY_SHIRT_DISLIKE := ["No %s shirts. I wear them all week.", "Not a %s shirt, please."]

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
## Needs it tomorrow and pays extra for it (FrontDesk.RUSH_BONUS).
@export var rush := false
## Hard to please: full pay only for near-perfect work, but double tips.
@export var picky := false
## How they came in: "" walk-in, "appointment", "referral" (sent by the rival tailor).
@export var arrival := ""
## A colour they ask for (global MaterialFactory index), or -1. Not required: they
## take a suit without it, but they tip for it (Config liked_tip_share).
@export var likes_color := -1
## A colour they won't wear whatever the occasion allows, or -1. A suit or shirt in it
## is refused. Suit colours (below SUIT_COLOR_COUNT) mean the jacket and trousers;
## shirtings mean the shirt.
@export var dislikes_color := -1
## A dislike they keep to themselves until you show it at the mirror (SuitTaste): a
## colour, pattern or cloth, or {}. `quiet_known` once they've told you.
@export var quiet_dislike: Dictionary = {}
@export var quiet_known := false
## > 0 when `dislikes_color` is the colour they've seen too much of about town (how many
## of your suits in it are being worn), not a taste of their own.
@export var town_worn := 0
## A regular's past suits from you as [colour, pattern]; they want something new.
@export var owned_suits: Array = []

## How many times they have been shown a design; seeds which line they say.
var _asks := 0


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


## Give them a colour to voice, or none. Call it once the brief is final (after any
## event or season has changed the occasion), since it picks from what the brief allows:
## a like is always a colour the dress code takes, and a dislike always leaves another.
func roll_taste(rng: RandomNumberGenerator) -> void:
	likes_color = -1
	dislikes_color = -1
	if rng.randf() >= TASTE_CHANCE:
		return
	var shirt := rng.randf() < SHIRT_TASTE
	var pool := _taste_pool(shirt)
	if pool.is_empty():
		return
	var usual: Array = USUAL_SHIRT if shirt else USUAL_SUIT
	if rng.randf() < LIKE_SHARE or pool.size() < 2:
		# A like steers away from the usual, when the brief leaves any room to.
		var fresh := pool.filter(func(c: int) -> bool: return not c in usual)
		var from: Array = fresh if not fresh.is_empty() else pool
		likes_color = int(from[rng.randi() % from.size()])
		return
	var common := pool.filter(func(c: int) -> bool: return c in usual)
	var from: Array = common if not common.is_empty() and rng.randf() < USUAL_DISLIKE else pool
	dislikes_color = int(from[rng.randi() % from.size()])


## The colours the brief takes for the suit (the jacket's rule) or the shirt.
func _taste_pool(shirt: bool) -> Array:
	var pool: Array = []
	if shirt:
		pool = DressCode.shirt_colors(occasion, style).duplicate()
		if pool.is_empty():
			pool = Array(MaterialFactory.colors_for(Enums.GarmentType.SHIRT))
	else:
		var rule: DressRule = (
			Catalog.dress_code.rule_for(occasion, style) if Catalog.dress_code != null else null
		)
		if rule != null:
			pool = rule.allowed_colors.duplicate()
		if pool.is_empty():
			pool = Array(MaterialFactory.colors_for(Enums.GarmentType.JACKET))
	return pool


## Whether a colour index is a shirting (else a suiting).
static func is_shirting(color: int) -> bool:
	return color >= MaterialFactory.SUIT_COLOR_COUNT


## What they say about colour at the counter, or "".
func taste_line() -> String:
	if town_worn > 0 and dislikes_color >= 0:
		return SuitTaste.town_line(dislikes_color, town_worn)
	var color := likes_color if likes_color >= 0 else dislikes_color
	if color < 0:
		return ""
	var shirt := is_shirting(color)
	var says: Array = SAY_SUIT_LIKE
	if likes_color >= 0:
		says = SAY_SHIRT_LIKE if shirt else SAY_SUIT_LIKE
	else:
		says = SAY_SHIRT_DISLIKE if shirt else SAY_SUIT_DISLIKE
	var line: String = says[absi(display_name.hash()) % says.size()]
	var word := MaterialFactory.color_name(color).to_lower()
	line = line % word
	return line.substr(0, 1).to_upper() + line.substr(1)


## The taste in a few words for the design screen: "Would like burgundy", "No navy
## shirt", plus a quiet dislike once they've told you and a regular's past suits.
func taste_short() -> String:
	var parts := PackedStringArray()
	var color := likes_color if likes_color >= 0 else dislikes_color
	if color >= 0:
		var word := MaterialFactory.color_name(color).to_lower()
		var what := " shirt" if is_shirting(color) else ""
		parts.append(("Would like %s%s" if likes_color >= 0 else "No %s%s") % [word, what])
		if likes_color >= 0 and dislikes_color >= 0:
			parts.append("No " + MaterialFactory.color_name(dislikes_color).to_lower())
	if quiet_known and not quiet_dislike.is_empty():
		var no := SuitTaste.short(quiet_dislike)
		parts.append(no.substr(0, 1).to_upper() + no.substr(1))
	if not owned_suits.is_empty():
		var had := PackedStringArray()
		for o: Array in owned_suits:
			var c := SuitTaste.word({"kind": "color", "value": o[0]})
			had.append(c + " " + SuitTaste.word({"kind": "pattern", "value": o[1]}))
		parts.append("Has " + ", ".join(had))
	return " · ".join(parts)


## Their dislike broken by this design: what they say, or "".
func taste_reason(design: Dictionary) -> String:
	if dislikes_color < 0:
		return ""
	var parts: Array = [Enums.GarmentType.SHIRT]
	if not is_shirting(dislikes_color):
		parts = [Enums.GarmentType.JACKET, Enums.GarmentType.PANTS]
	for t: int in parts:
		var spec: Dictionary = design.get(t, {})
		if int(spec.get("color", -1)) == dislikes_color:
			return "not %s. I did say." % MaterialFactory.color_name(dislikes_color).to_lower()
	return ""


## Whether the design gives them the colour they asked for.
func likes_met(design: Dictionary) -> bool:
	if likes_color < 0:
		return false
	var part := Enums.GarmentType.SHIRT if is_shirting(likes_color) else Enums.GarmentType.JACKET
	var spec: Dictionary = design.get(part, {})
	return int(spec.get("color", -1)) == likes_color


static func _fresh_name(rng: RandomNumberGenerator) -> String:
	for _i in 12:
		var nm: String = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
		if Clientele == null or not Clientele.is_known(nm):
			return nm
	return FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]


## "Mr. Okafor" or "Mr. Okafor ★2" for a regular.
func title() -> String:
	return display_name + ("  ★%d" % regular_level if regular_level > 0 else "")


## What the special client types mean, for the greeting bubble (one per line). The
## at-a-glance badges themselves are ClientBadges.
func tags() -> PackedStringArray:
	var out := PackedStringArray()
	if arrival == "appointment":
		out.append("Here for the fitting you booked.")
	elif arrival == "referral":
		out.append("Sent over by %s." % FrontDesk.RIVAL_NAME)
	elif arrival == "pitch":
		out.append("Won over by your pitch on the street.")
	if rush:
		out.append(
			"Needs it tomorrow and pays %d%% extra for it." % roundi(FrontDesk.RUSH_BONUS * 100.0)
		)
	if picky:
		out.append("Full pay only for near-perfect work, but tips twice as well.")
	return out


## Short brief, e.g. "Funeral · Classic".
func describe() -> String:
	return "%s · %s" % [Enums.occasion_name(occasion), Enums.style_name(style)]


## The dress-code hint shown to the player ("Sombre and plain…").
func hint() -> String:
	if Catalog.dress_code != null:
		return Catalog.dress_code.hint_for(occasion, style)
	return ""


## Judge a proposed design against the brief + budget (DressCode), then against their
## own taste: a disliked colour is the first thing they mention. "liked" says whether the
## colour they asked for is in it. "notes" runs parallel to "reasons" (DressCode.evaluate
## has the shape), taste first; "said_happy" is what they say if they take it. Each call
## moves their voice on, so asking twice doesn't get the same line twice.
func evaluate(design: Dictionary) -> Dictionary:
	var voice := absi(display_name.hash()) + _asks
	_asks += 1
	var out := {"suitable": false, "quote": Pricing.suit_quote(design), "reason": "…"}
	out["reasons"] = [] as Array[String]
	out["notes"] = [] as Array[Dictionary]
	if Catalog.dress_code != null:
		out = Catalog.dress_code.evaluate(occasion, style, design, budget, voice)
	var reasons: Array[String] = out.get("reasons", [] as Array[String])
	var notes: Array[Dictionary] = out.get("notes", [] as Array[Dictionary])
	# Their own taste is the first thing they mention: a stated dislike, a suit they
	# already have from you, then a quiet dislike (which they only now say out loud).
	var taste := _taste_objections(design)
	if not taste.is_empty():
		var taste_reasons: Array[String] = []
		var taste_notes: Array[Dictionary] = []
		for t: Dictionary in taste:
			taste_reasons.append(t["reason"])
			taste_notes.append({"part": t["part"], "note": t["note"], "said": t["said"]})
		taste_reasons.append_array(reasons)
		taste_notes.append_array(notes)
		reasons = taste_reasons
		notes = taste_notes
		out["suitable"] = false
		out["reason"] = "Not quite: " + reasons[0]
	out["reasons"] = reasons
	out["notes"] = notes
	out["liked"] = likes_met(design)
	var liked := MaterialFactory.color_name(likes_color).to_lower() if out["liked"] else ""
	out["said_happy"] = CustomerLines.happy(occasion, voice, liked)
	return out


## The taste this design breaks, in the order they bring it up: each is the refusal
## sentence (`reason`), the notepad slot and shorthand, and what they say.
func _taste_objections(design: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dislike := taste_reason(design)
	if dislike != "":
		var word := MaterialFactory.color_name(dislikes_color).to_lower()
		var said := dislike.substr(0, 1).to_upper() + dislike.substr(1)
		var entry := {"reason": dislike, "part": "shirt" if is_shirting(dislikes_color) else "suit"}
		entry["note"] = "not %s — said so at the counter" % word
		if town_worn > 0:
			entry["part"] = "suit"
			entry["note"] = "town's full of your %s" % word
			said = SuitTaste.town_line(dislikes_color, town_worn)
		entry["said"] = said
		out.append(entry)
	if SuitTaste.owns(owned_suits, design):
		var owned := SuitTaste.OWNED_LINE
		out.append({"reason": owned, "part": "suit", "note": "has this one already", "said": owned})
	if SuitTaste.hits(quiet_dislike, design):
		quiet_known = true  # said now, and remembered on the design screen
		var said := SuitTaste.line(quiet_dislike)
		var shirt: bool = (
			quiet_dislike.get("kind", "") == "color"
			and is_shirting(int(quiet_dislike.get("value", -1)))
		)
		var note := SuitTaste.short(quiet_dislike) + " — won't wear it"
		out.append(
			{"reason": said, "part": "shirt" if shirt else "suit", "note": note, "said": said}
		)
	return out
