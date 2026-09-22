class_name SuitOrder
extends Resource

## A confirmed bespoke order: the customer approved this design at the mirror and
## agreed a price and a deadline (1–5 days). It lists every piece the suit needs
## and tracks each one as it is checked off — a made piece is matched against the
## order and, if close enough, fills that slot. Once every piece is done the order
## is READY and waits for the customer to return on their deadline day to collect
## and pay. Matching is forgiving: payout scales with match and craft quality.

## Lifecycle: OPEN (pieces still being made — each is checked off as it is sewn) →
## (all pieces made) still OPEN, now awaiting assembly at the mannequin → READY (the
## suit has been assembled and tagged with this order's number, awaiting the customer
## to return and collect it in person). Fulfilled/expired orders leave the list.
enum State { OPEN, READY }

## Colour counts as matched when the delivered cloth is this close (RGB distance).
const COLOR_TOLERANCE := 0.14

## Human-facing order number (#1, #2, …). Stamped on the pieces and the assembled suit
## so the returning customer's suit can be told apart from everyone else's.
@export var id: int = 0
@export var customer_name: String = "Customer"
## GarmentType(int) -> { fabric, color, pattern, style_idx } (from the suit builder).
@export var design: Dictionary = {}
## Agreed price (the ceiling; actual payout scales by match and quality).
@export var price: int = 0
## Skin tone + hairstyle + hair colour, so the one who returns to collect matches.
@export var skin: Color = Color(0.87, 0.72, 0.60)
@export var hair_index: int = 0
@export var hair_color: Color = Color(0.14, 0.11, 0.09)
## Shop days promised, and the shop day (Shift.day) the customer returns to collect.
@export var deadline_days: int = 3
@export var due_day: int = 4
## When during the due day's shift (0..1 of the shift) the customer walks in.
@export var arrive_at: float = 0.4
## The suit wasn't ready on the due day; the customer gave one grace day (pays less).
@export var late := false
## A rush order (due tomorrow; the rush premium is already in `price`).
@export var rush := false
## A picky client: full pay only for near-perfect work, but double tips.
@export var picky := false
## Made in the colour they asked for (CustomerPreference.likes_color): a bigger tip.
@export var liked := false
## The city event (NewsEvent id) this suit is meant to be worn at, "" if none. Set when
## the order is taken during an event's run-up for its occasion; the due day is capped
## at the event, and the collected suit is judged for the paper's "best suit spotted".
@export var event_id := ""

var state: int = State.OPEN
## GarmentType(int) -> { score: float, quality: float } for each checked-off piece.
var filled: Dictionary = {}
## Set once the deadline fires so the manager only sends the customer back once.
## 0..1 — how good the coffee they were welcomed with was (0 = none offered). A small
## thank-you on the bill at collection (GameConfig.coffee_tip_share).
var coffee := 0.0
var due_fired := false
## How a lost order was lost, for the standing it costs: the player apologised in person
## (softer), or left the customer standing until they walked out (harsher). Not saved.
var apologised := false
var ignored := false


## The garment types this order needs, in a stable display order.
func required_types() -> Array:
	var out: Array = []
	for t in [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]:
		if design.has(t):
			out.append(t)
	return out


func needs_part(garment_type: int) -> bool:
	return design.has(garment_type) and not filled.has(garment_type)


func is_part_done(garment_type: int) -> bool:
	return filled.has(garment_type)


func is_complete() -> bool:
	for t in required_types():
		if not filled.has(t):
			return false
	return not required_types().is_empty()


## Check a made piece off this order's slot for `garment_type`.
func fill_part(garment_type: int, score: float, quality: float) -> void:
	filled[garment_type] = {"score": score, "quality": quality}


## Shop days until the customer comes, counting today as 1 (1 = today, 2 = tomorrow).
func days_left_ceil() -> int:
	var today: int = Shift.day if Shift != null else 1
	return maxi(1, due_day - today + 1)


## Describe the ordered jacket for the compact HUD ticket, e.g. "Navy Pinstripe".
func describe() -> String:
	return part_summary(Enums.GarmentType.JACKET)


## A short spec for one piece, e.g. "Navy Pinstripe Worsted Wool".
func part_summary(garment_type: int) -> String:
	var spec: Dictionary = design.get(garment_type, {})
	if spec.is_empty():
		return "—"
	var parts := [MaterialFactory.color_name(int(spec.get("color", 0)))]
	var pat := int(spec.get("pattern", 0))
	if pat != Enums.Pattern.SOLID:
		parts.append(Enums.pattern_name(pat))
	parts.append(Enums.fabric_name(int(spec.get("fabric", 0))))
	return " ".join(parts)


## The jacket's fabric as a MaterialType, for the compact ticket's swatch.
func jacket_material() -> MaterialType:
	return part_material(Enums.GarmentType.JACKET)


## The cloth for one piece as a MaterialType, for a swatch.
func part_material(garment_type: int) -> MaterialType:
	var spec: Dictionary = design.get(garment_type, {})
	if spec.is_empty():
		return null
	return MaterialFactory.make(
		int(spec.get("fabric", 0)), int(spec.get("pattern", 0)), int(spec.get("color", 0)), 1.0
	)


## 0..1 — how well a delivered piece (`part`) matches this order's spec for
## `garment_type` (fabric .4 / pattern .3 / colour .3).
func part_match(garment_type: int, part: Dictionary) -> float:
	if part.is_empty() or not design.has(garment_type):
		return 0.0
	var want: Dictionary = design[garment_type]
	var mat: MaterialType = part.get("material")
	if mat == null:
		return 0.0
	var score := 0.0
	if int(mat.fabric) == int(want.get("fabric", -1)):
		score += 0.4
	if int(mat.pattern) == int(want.get("pattern", -1)):
		score += 0.3
	var target := MaterialFactory.color_value(int(want.get("color", 0)))
	if _color_close(mat.cloth_color, target):
		score += 0.3
	return score


## Final payout once collected (see payout_breakdown()).
func payout() -> int:
	return int(payout_breakdown()["total"])


## { base, tip, total, score } — full price across the "good enough" band, a tip for
## excellent work, and the late-collection share if the grace day was used.
func payout_breakdown() -> Dictionary:
	var score := average_match() * average_quality()
	# A picky client judges as if the work were a notch worse — and tips twice as well.
	var judged := score - 0.2 if picky else score
	var base := price * Pricing.pay_share(judged)
	var work := price * Pricing.tip_share(score) * (2.0 if picky else 1.0)
	# Welcomed with a coffee: a small thank-you, however the suit turned out.
	var thanks: float = Config.data.coffee_tip_share if Config.data != null else 0.06
	var cup := price * thanks * coffee
	var colour := 0.0
	if liked:
		colour = price * (Config.data.liked_tip_share if Config.data != null else 0.08)
	if late:
		var share: float = Config.data.late_pay if Config.data != null else 0.75
		base *= share
		work = 0.0
		cup = 0.0
		colour = 0.0
	var b := int(round(base))
	# The tip's parts, rounded so they add up to the tip exactly (the pickup receipt lists them).
	var tw := int(round(work))
	var tc := int(round(cup))
	var tl := int(round(colour))
	var t := tw + tc + tl
	return {
		"base": b,
		"tip": t,
		"total": b + t,
		"score": score,
		"tip_work": tw,
		"tip_coffee": tc,
		"tip_liked": tl,
	}


## 0..1 — mean brief-match across the order's pieces (how right the cloth was).
func average_match() -> float:
	return _average("score")


## 0..1 — mean craft quality across the order's pieces (how well it was made).
func average_quality() -> float:
	return _average("quality")


func _average(field: String) -> float:
	var types := required_types()
	if types.is_empty():
		return 0.0
	var sum := 0.0
	for t in types:
		var f: Dictionary = filled.get(t, {})
		sum += float(f.get(field, 0.0))
	return sum / types.size()


func _color_close(a: Color, b: Color) -> bool:
	var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return d.length() <= COLOR_TOLERANCE
