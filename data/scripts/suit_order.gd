class_name SuitOrder
extends Resource

## A confirmed bespoke order: the customer approved this design at the mirror and
## agreed a price. It sits in the OrderManager's list (shown on the HUD) until a
## packaged suit fulfils it. Matching is forgiving — a delivered suit pays out in
## proportion to how well it matches the agreed design and its craft quality.

# Colour counts as matched when the delivered cloth is this close (RGB distance).
const COLOR_TOLERANCE := 0.14

@export var customer_name: String = "Customer"
## GarmentType -> { fabric, color, pattern, style_idx } (from the suit builder).
@export var design: Dictionary = {}
## Agreed price (the ceiling; actual payout scales by match and quality).
@export var price: int = 0


## Describe the ordered jacket for the HUD, e.g. "Navy Pinstripe Worsted Wool".
func describe() -> String:
	var jacket: Dictionary = design.get(Enums.GarmentType.JACKET, {})
	if jacket.is_empty():
		return "Bespoke suit"
	var parts := [MaterialFactory.color_name(int(jacket.get("color", 0)))]
	var pat := int(jacket.get("pattern", 0))
	if pat != Enums.Pattern.SOLID:
		parts.append(Enums.pattern_name(pat))
	parts.append(Enums.fabric_name(int(jacket.get("fabric", 0))))
	return " ".join(parts)


## 0..1 — how well `suit` matches this order across its three parts.
func match_fraction(suit: Node) -> float:
	if suit == null or not (suit.get("parts") is Dictionary):
		return 0.0
	var parts: Dictionary = suit.parts
	var total := 0.0
	for t in [Enums.GarmentType.JACKET, Enums.GarmentType.SHIRT, Enums.GarmentType.PANTS]:
		total += _part_match(t, parts.get(t, {}))
	return total / 3.0


func _part_match(garment_type: int, part: Dictionary) -> float:
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


func _color_close(a: Color, b: Color) -> bool:
	var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return d.length() <= COLOR_TOLERANCE
