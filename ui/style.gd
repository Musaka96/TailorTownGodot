class_name Style

## Savile Row atelier UI kit — the single source of truth for colour, spacing,
## frames and prompts. Warm walnut + cream paper, brass hardware, forest/burgundy
## accents, chalk marks. Shared by every in-game screen so they read as one shop.
## See docs/UI_STYLE_GUIDE.md; the [CHECK] rules there are enforced by
## tools/check_ui.gd. Menus must pull values from here — never hard-code colours,
## radii or spacing in a menu script.

## Per-menu skins (see the table in docs/UI_STYLE_GUIDE.md §5). Each maps to a
## paper colour, accent, background pattern, silhouette (corner radii) and shape.
enum MenuSkin { ORDER, BOOK, SHELF, MIRROR, WORK, ORDERS }

const _FONT := preload("res://assets/fonts/Fredoka.ttf")

# Palette
const CREAM := Color("f4ead2")  # panel paper (default)
const CREAM_DARK := Color("e7d8b8")  # grooves / soft borders
const PAPER := Color("efe3c8")  # kraft pattern-paper (warmer surfaces)
const PAPER_COOL := Color("eceadd")  # cool cream (fabric shelf)
const PAPER_MIRROR := Color("eef0ea")  # pale silvery paper (fitting room)
const MAT := Color("e8dcc0")  # cutting-mat tan (workbench)
const CORK := Color("d8bd8f")  # corkboard tan (orders board)
const CARD := Color("fbf5e6")  # list card
const CARD_SELECTED := Color("fffaf0")
const INK := Color("4a3826")  # primary text (walnut)
const WALNUT := Color("4a3826")  # dark wood / outlines (alias of INK)
const INK_SOFT := Color("8a745a")  # secondary text
const BROWN := Color("6b4f34")  # outlines
const BRASS := Color("c9a24a")  # primary accent — hardware, highlights
const FOREST := Color("2f5d3e")  # positive / good
const BURGUNDY := Color("7a3b3b")  # rich accent / reading
const CHALK := Color("eef2f4")  # chalk marks / light text on dark
const LEAF := Color("7cbf6b")  # legacy accent (pre-atelier menus)
const AMBER := Color("e6a63c")  # warning
const CLAY := Color("d76b5a")  # low / danger
const SHADOW := Color(0, 0, 0, 0.28)

# Per-menu skin accents (single source; mirrors the table in the style guide).
const ACC_ORDER := BRASS  # phone order pad
const ACC_BOOK := BURGUNDY  # handbook
const ACC_SHELF := FOREST  # bolt shelf
const ACC_MIRROR := BRASS  # fitting room
const ACC_WORK := WALNUT  # workbench
const ACC_ORDERS := BURGUNDY  # orders board

# Spacing (8px grid)
const S1 := 4
const S2 := 8
const S3 := 16
const S4 := 24

# Fixed frame presets (panels must not stretch — see style guide §3).
const FRAME_SMALL := Vector2(560, 360)
const FRAME_WIDE := Vector2(820, 520)
const FRAME_TALL := Vector2(640, 560)

static var _bold: FontVariation


## A real bold weight — Fredoka has no bold face, so embolden the base font.
static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = _FONT
		_bold.variation_embolden = 0.4
	return _bold


# --- Panels ----------------------------------------------------------------


## Atelier panel base for a menu, tinted by its skin accent (§5). Paper fill with
## an accent border; pair with an AtelierFrame overlay for the stitching + ticks.
static func skin_base(accent: Color, paper: Color = CREAM, radius: int = 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.set_content_margin_all(S3)
	sb.shadow_color = SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


## The one call a menu makes to get its whole surface: paper colour, silhouette
## (per-corner radii), margins, and an AtelierFrame overlay with the skin's
## background pattern + shape accent. Returns the frame (reused on repeat calls).
static func apply_skin(panel_node: PanelContainer, skin: int) -> AtelierFrame:
	var paper := CREAM
	var accent := BRASS
	var pat := AtelierFrame.Pattern.NONE
	var shp := AtelierFrame.Shape.NONE
	var radii := Vector4i(20, 20, 20, 20)  # top-left, top-right, bottom-right, bottom-left
	var pad_left := S3
	match skin:
		MenuSkin.ORDER:
			accent = BRASS
			pat = AtelierFrame.Pattern.PINSTRIPE
			shp = AtelierFrame.Shape.CLIP
		MenuSkin.BOOK:
			paper = PAPER
			accent = BURGUNDY
			pat = AtelierFrame.Pattern.RULES
			shp = AtelierFrame.Shape.BOOK
			radii = Vector4i(6, 18, 18, 6)
			pad_left = S4
		MenuSkin.SHELF:
			paper = PAPER_COOL
			accent = FOREST
			pat = AtelierFrame.Pattern.HERRINGBONE
			shp = AtelierFrame.Shape.FOLD
		MenuSkin.MIRROR:
			paper = PAPER_MIRROR
			accent = BRASS
			radii = Vector4i(44, 44, 12, 12)
		MenuSkin.WORK:
			paper = MAT
			accent = WALNUT
			pat = AtelierFrame.Pattern.GRID
			shp = AtelierFrame.Shape.TAPE
			radii = Vector4i(8, 8, 8, 8)
		MenuSkin.ORDERS:
			paper = CORK
			accent = BURGUNDY
			pat = AtelierFrame.Pattern.CORK
			shp = AtelierFrame.Shape.PIN
			radii = Vector4i(6, 6, 6, 6)

	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.corner_radius_top_left = radii.x
	sb.corner_radius_top_right = radii.y
	sb.corner_radius_bottom_right = radii.z
	sb.corner_radius_bottom_left = radii.w
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.content_margin_left = pad_left
	sb.content_margin_right = S3
	sb.content_margin_top = S3
	sb.content_margin_bottom = S3
	sb.shadow_color = SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	panel_node.add_theme_stylebox_override("panel", sb)

	var frame := panel_node.get_node_or_null("Frame") as AtelierFrame
	if frame == null:
		frame = AtelierFrame.new()
		frame.name = "Frame"
		panel_node.add_child(frame)
	frame.setup(accent, WALNUT, pat, shp)
	return frame


static func panel(
	bg: Color = CREAM, radius: int = 20, border: int = 4, border_col: Color = CREAM_DARK
) -> StyleBoxFlat:
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
	bg: Color = CARD, radius: int = 14, border: int = 0, border_col: Color = LEAF
) -> StyleBoxFlat:
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


# --- Text ------------------------------------------------------------------


## Bold screen title (26pt walnut by default).
static func title_label(text: String, accent: Color = WALNUT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", bold_font())
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", accent)
	return lbl


## Bold section header in the skin accent (18pt).
static func header(text: String, accent: Color = BRASS) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", bold_font())
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", accent)
	return lbl


# --- Prompts & readability -------------------------------------------------


## A single rounded key-cap (e.g. "E", "W/S", "Esc").
static func keycap(key: String) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WALNUT
	sb.set_corner_radius_all(6)
	sb.content_margin_left = S1 + 2
	sb.content_margin_right = S1 + 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", sb)
	cap.custom_minimum_size = Vector2(22, 0)
	var lbl := Label.new()
	lbl.text = key
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", bold_font())
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CHALK)
	cap.add_child(lbl)
	return cap


## A readability bar of key-cap + verb pairs, e.g.
## Style.hint_bar([["W/S", "Select"], ["E", "Order"], ["Esc", "Close"]]).
static func hint_bar(pairs: Array) -> Control:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.09, 0.82)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = S3
	sb.content_margin_right = S3
	sb.content_margin_top = S2
	sb.content_margin_bottom = S2
	wrap.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", S3)
	wrap.add_child(row)
	for pair in pairs:
		var key: String = pair[0]
		var verb: String = pair[1]
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", S1 + 2)
		entry.add_child(keycap(key))
		var lbl := Label.new()
		lbl.text = verb
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", CHALK)
		entry.add_child(lbl)
		row.add_child(entry)
	return wrap


## Info / status text on a translucent bar so it stays legible over the 3D scene.
static func info_badge(text: String, tint: Color = WALNUT) -> Control:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.14)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = S2
	sb.content_margin_right = S2
	sb.content_margin_top = S1
	sb.content_margin_bottom = S1
	wrap.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", INK)
	wrap.add_child(lbl)
	return wrap


## Fill colour by fraction remaining (forest → amber → clay); never colour alone.
static func fill_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return FOREST
	if fraction >= 0.25:
		return AMBER
	return CLAY
