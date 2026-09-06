class_name MaterialType
extends Resource

## A specific purchasable bolt of suiting cloth (fabric + colour + pattern).
## Authored as a `.tres` in res://data/materials/ — content, not code.

@export var id: StringName
@export var display_name: String

@export var fabric: Enums.Fabric = Enums.Fabric.WORSTED_WOOL
@export var pattern: Enums.Pattern = Enums.Pattern.SOLID

## Dominant cloth colour (used to tint the greybox roll and menu swatch).
@export var cloth_color: Color = Color(0.5, 0.5, 0.5)
## Secondary colour for stripes/checks (pattern art comes later).
@export var pattern_color: Color = Color(0.9, 0.9, 0.9)

@export var weight_gsm: int = 250        ## fabric weight; higher = heavier/winter
@export var super_number: int = 0        ## Super 100s/120s/… ; 0 = not applicable
@export var price_per_meter: int = 25    ## purchase cost per metre
@export var roll_length_m: float = 20.0  ## length of cloth on a full bolt


## One-line description for menus/tooltips, e.g.
## "Worsted Wool · Pinstripe · Super 120s · 250 g".
func summary() -> String:
	var parts := [Enums.fabric_name(fabric), Enums.pattern_name(pattern)]
	if super_number > 0:
		parts.append("Super %ds" % super_number)
	parts.append("%d g" % weight_gsm)
	return " · ".join(parts)
