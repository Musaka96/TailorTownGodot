class_name Style

## Animal-Crossing-inspired UI kit: a warm, muted palette + rounded style-box
## helpers on an 8px spacing grid. Flat (soft, minimal shadow), high-contrast
## text on cream. Shared by all in-game UI so screens read as one system.

# Palette
const CREAM := Color("f4ead2")       # panel background
const CREAM_DARK := Color("e7d8b8")  # panel border / grooves
const CARD := Color("fbf5e6")        # list card
const CARD_SELECTED := Color("fffaf0")
const INK := Color("4a3826")         # primary text (contrast on cream)
const INK_SOFT := Color("8a745a")    # secondary text
const BROWN := Color("6b4f34")       # outlines
const LEAF := Color("7cbf6b")        # accent / good
const AMBER := Color("e6a63c")       # warning
const CLAY := Color("d76b5a")        # low / danger
const SHADOW := Color(0, 0, 0, 0.28)

# Spacing (8px grid)
const S1 := 4
const S2 := 8
const S3 := 16
const S4 := 24


static func panel(
		bg: Color = CREAM, radius: int = 20, border: int = 4,
		border_col: Color = CREAM_DARK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.set_content_margin_all(S3)
	sb.shadow_color = SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func card(
		bg: Color = CARD, radius: int = 14, border: int = 0,
		border_col: Color = LEAF) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.set_content_margin_all(S2)
	return sb


static func bar(bg: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb


## Fill colour by fraction remaining (green → amber → red), never colour alone.
static func fill_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return LEAF
	if fraction >= 0.25:
		return AMBER
	return CLAY
