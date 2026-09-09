class_name MaterialFactory

## Builds a runtime MaterialType from a fabric + colour + pattern + length chosen
## in the phone's custom-order maker. Not saved to disk — it lives only as long
## as the roll it becomes.

# Colour options: [display name, cloth colour]. The first SUIT_COLOR_COUNT are deep
# suiting colours (jacket / trousers); the rest are pale shirting colours. colors_for()
# hands each part the right slice; indices stay global so orders/matching are unchanged.
const SUIT_COLOR_COUNT := 10
const COLORS := [
	["Navy", Color("1b2a4a")],
	["Charcoal", Color("36393f")],
	["Light Grey", Color("9a9ea6")],
	["Black", Color("17181c")],
	["Tan", Color("c8b48a")],
	["Brown", Color("5a4633")],
	["Blue", Color("3a4a63")],
	["Burgundy", Color("5c1f2a")],
	["Olive", Color("5c5a35")],
	["Forest", Color("2f4a39")],
	["White", Color("f2f0e8")],
	["Sky Blue", Color("bcd0e4")],
	["Pink", Color("e6c6cc")],
	["Lavender", Color("d0c8e2")],
	["Ecru", Color("e9e1cf")],
	["Mint", Color("cfe1d4")],
	["Butter", Color("ece1b6")],
	["Pale Grey", Color("d5d8dc")],
]

# Typical weight per fabric (GSM), for display.
const FABRIC_GSM := {
	Enums.Fabric.WORSTED_WOOL: 250,
	Enums.Fabric.FLANNEL: 320,
	Enums.Fabric.TWEED: 340,
	Enums.Fabric.MOHAIR_BLEND: 230,
	Enums.Fabric.LINEN: 200,
	Enums.Fabric.COTTON: 120,
	Enums.Fabric.POPLIN: 115,
	Enums.Fabric.OXFORD_CLOTH: 150,
}


static func color_count() -> int:
	return COLORS.size()


## Global colour indices a garment type may use: pale shirtings for the shirt, deep
## suitings for the jacket and trousers (the first is that part's default).
static func colors_for(part: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if part == Enums.GarmentType.SHIRT:
		for i in range(SUIT_COLOR_COUNT, COLORS.size()):
			out.append(i)
	else:
		for i in SUIT_COLOR_COUNT:
			out.append(i)
	return out


static func color_name(index: int) -> String:
	return COLORS[posmod(index, COLORS.size())][0]


static func color_value(index: int) -> Color:
	return COLORS[posmod(index, COLORS.size())][1]


static func make(
	fabric: Enums.Fabric, pattern: Enums.Pattern, color_index: int, length: float
) -> MaterialType:
	var mat := MaterialType.new()
	var cloth: Color = color_value(color_index)
	mat.fabric = fabric
	mat.pattern = pattern
	mat.cloth_color = cloth
	# Chalky accent for stripes/checks that reads against the cloth colour.
	mat.pattern_color = cloth.lerp(Color(0.95, 0.95, 0.92), 0.6)
	mat.weight_gsm = int(FABRIC_GSM.get(fabric, 250))
	mat.super_number = 0
	mat.price_per_meter = Pricing.per_meter(fabric, pattern)
	mat.roll_length_m = length
	mat.display_name = _name(color_index, fabric, pattern)
	mat.id = StringName("custom_%d_%d_%d" % [fabric, pattern, color_index])
	return mat


static func _name(color_index: int, fabric: Enums.Fabric, pattern: Enums.Pattern) -> String:
	var parts := [color_name(color_index)]
	if pattern != Enums.Pattern.SOLID:
		parts.append(Enums.pattern_name(pattern))
	parts.append(Enums.fabric_name(fabric))
	return " ".join(parts)
