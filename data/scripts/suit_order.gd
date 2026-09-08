class_name SuitOrder
extends Resource

## A confirmed bespoke order: the customer approved this design at the mirror and
## agreed a price and a deadline (1–5 days). It lists every piece the suit needs
## and tracks each one as it is checked off — a made piece is matched against the
## order and, if close enough, fills that slot. Once every piece is done the order
## is READY and waits for the customer to return on their deadline day to collect
## and pay. Matching is forgiving: payout scales with match and craft quality.

## Lifecycle: OPEN (pieces still being made) → READY (all pieces done, awaiting
## collection). Fulfilled and expired orders are removed from the list entirely.
enum State { OPEN, READY }

## Colour counts as matched when the delivered cloth is this close (RGB distance).
const COLOR_TOLERANCE := 0.14

@export var customer_name: String = "Customer"
## GarmentType(int) -> { fabric, color, pattern, style_idx } (from the suit builder).
@export var design: Dictionary = {}
## Agreed price (the ceiling; actual payout scales by match and quality).
@export var price: int = 0
## Skin tone + hairstyle of the customer, so the one who returns to collect matches.
@export var skin: Color = Color(0.87, 0.72, 0.60)
@export var hair_index: int = 0
## Total days promised (1–5) and how many real-time days remain.
@export var deadline_days: int = 3
@export var days_left: float = 3.0

var state: int = State.OPEN
## GarmentType(int) -> { score: float, quality: float } for each checked-off piece.
var filled: Dictionary = {}
## Set once the deadline fires so the manager only sends the customer back once.
var due_fired := false


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


func days_left_ceil() -> int:
	return maxi(1, int(ceil(days_left)))


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
		int(spec.get("fabric", 0)),
		int(spec.get("pattern", 0)),
		int(spec.get("color", 0)),
		1.0
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


## Final payout once collected: price scaled by average match and craft quality.
func payout() -> int:
	var types := required_types()
	if types.is_empty():
		return 0
	var score_sum := 0.0
	var quality_sum := 0.0
	for t in types:
		var f: Dictionary = filled.get(t, {})
		score_sum += float(f.get("score", 0.0))
		quality_sum += float(f.get("quality", 0.0))
	var avg_score := score_sum / types.size()
	var avg_quality := quality_sum / types.size()
	return int(round(price * avg_score * avg_quality))


func _color_close(a: Color, b: Color) -> bool:
	var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return d.length() <= COLOR_TOLERANCE
