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
const _DISPLAY := preload("res://assets/fonts/Fraunces.ttf")

# Type scale — the only font sizes a screen may use (style guide §2).
const T_MICRO := 12  # badges, folio, tape numerals
const T_CAPTION := 14  # sub-lines, hints, kickers, pills
const T_BODY := 16  # body copy, row labels
const T_VALUE := 18  # row values, buttons, section headers
const T_NAME := 21  # card / item names
const T_TITLE := 28  # screen titles
const T_HERO := 46  # day card, wordmark base

# Variable-font weights. Fredoka runs 300–700 and its default instance is Light, so
# every face below names its weight — never use the bare file.
const W_BODY := 450
const W_MEDIUM := 550
const W_BOLD := 650
const W_DISPLAY := 700

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
const SCRIM := Color(0, 0, 0, 0.5)  # the dim behind a full-screen menu
const LINEN := Color("c9b48c")  # undyed linen — cloth stand-in when none is known
const NONE := Color(0, 0, 0, 0)  # "no colour" (e.g. no pin / no stitch)
const RIM_DARK := Color("8a6a2a")  # dark brass (chains, rims)
const BRASS_LIGHT := Color("e8ce86")  # brass catching the light (gold-leaf edge)
const STEEL := Color("bcc3c9")  # polished blade / pin shaft
const STEEL_DARK := Color("70797f")  # steel in shadow, blade outlines
const TAPE := Color("f2c94c")  # tape-measure yellow
const PATCH := Color("3d6b4a")  # embroidered patch green

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

static var _faces: Dictionary = {}
static var _theme: Theme

# --- Type ------------------------------------------------------------------


## One cached instance of a variable font: `axes` maps an OpenType axis name ("wght",
## "wdth", "SOFT", "opsz") to its value; `spacing` is extra px between glyphs.
static func _face(key: String, base: Font, axes: Dictionary, spacing: int = 0) -> FontVariation:
	if _faces.has(key):
		return _faces[key]
	var ts := TextServerManager.get_primary_interface()
	var coords := {}
	for axis: String in axes:
		coords[ts.name_to_tag(axis)] = axes[axis]
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = coords
	fv.spacing_glyph = spacing
	_faces[key] = fv
	return fv


## Body copy, row labels — the default face everywhere.
static func font_body() -> FontVariation:
	return _face("body", _FONT, {"wght": W_BODY})


## Row values, card names, buttons.
static func font_medium() -> FontVariation:
	return _face("medium", _FONT, {"wght": W_MEDIUM})


## Headers, money, key terms, pills.
static func font_bold() -> FontVariation:
	return _face("bold", _FONT, {"wght": W_BOLD})


## Tracked, slightly condensed — kickers and small-caps style labels (set the text
## in capitals).
static func font_caps() -> FontVariation:
	return _face("caps", _FONT, {"wght": 600, "wdth": 90}, 2)


## The display serif (Fraunces, soft) — wordmark, screen titles, day card. Never for
## body, rows, values or prompts.
static func font_display() -> FontVariation:
	return _face("display", _DISPLAY, {"wght": W_DISPLAY, "SOFT": 100, "opsz": 72, "WONK": 0})


## Kept for callers from before the type scale: the real bold cut.
static func bold_font() -> FontVariation:
	return font_bold()


## The project-wide base theme (body face + default size). UI hangs it on the root
## window so every Control — menus, title screen, day card — inherits it.
static func base_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font_body()
		_theme.default_font_size = T_VALUE
	return _theme


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
			pat = AtelierFrame.Pattern.RULES
			shp = AtelierFrame.Shape.SPIRAL
			radii = Vector4i(8, 8, 20, 20)
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
	frame.setup(accent, WALNUT, pat, shp, radii)
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


## The dim behind a full-screen menu, ready to add as the first child.
static func scrim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


## A palette token at another alpha — for washes, watermarks and chalk dust. Menus
## use this instead of writing a Color() literal (style guide §2).
static func tint(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, alpha)


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
	lbl.add_theme_font_override("font", font_bold())
	lbl.add_theme_font_size_override("font_size", T_VALUE)
	lbl.add_theme_color_override("font_color", text_accent(accent))
	return lbl


## An accent made safe to set text in: brass is too pale to read on cream, so light
## accents are darkened; the dark ones (forest, burgundy, walnut) pass through.
static func text_accent(accent: Color) -> Color:
	return accent.darkened(0.3) if accent.get_luminance() > 0.35 else accent


# --- Prompts & readability -------------------------------------------------


## A single rounded key-cap (e.g. "E", "W/S", "Esc").
static func keycap(key: String) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WALNUT
	sb.set_corner_radius_all(6)
	sb.content_margin_left = S1 + 2
	sb.content_margin_right = S1 + 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", sb)
	cap.custom_minimum_size = Vector2(22, 0)
	# Don't let the cap stretch to the row height — keep it a compact key.
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = key
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", bold_font())
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CHALK)
	cap.add_child(lbl)
	return cap


## The menu's key prompts as a row of little brass pills (key-cap + verb), e.g.
## Style.hint_bar([["W/S", "Select"], ["E", "Order"], ["Esc", "Close"]]). Same button
## language as the tutorial's coach marks.
static func hint_bar(pairs: Array) -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", S2)
	row.add_theme_constant_override("v_separation", S1)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	wrap.add_child(row)
	for pair in pairs:
		row.add_child(key_pill(pair[0], pair[1]))
	return wrap


## A theme for form controls (buttons, dropdowns, sliders, toggles) so settings-style
## screens match the atelier paper instead of Godot's default dark grey.
static func form_theme() -> Theme:
	var t := Theme.new()
	var normal := _form_box(CARD, CREAM_DARK)
	var hover := _form_box(CARD_SELECTED, BRASS)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("focus", cls, _form_box(NONE, BRASS))
		t.set_stylebox("pressed", cls, _form_box(BRASS, WALNUT))
		t.set_stylebox("disabled", cls, _form_box(PAPER, CREAM_DARK))
		for role in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			t.set_color(role, cls, INK)
	var popup := _form_box(CREAM, BRASS)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _form_box(BRASS, BRASS))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", WALNUT)
	var track := StyleBoxFlat.new()
	track.bg_color = CREAM_DARK
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = BRASS
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	for cls in ["Label", "CheckButton"]:
		t.set_color("font_color", cls, INK)
	return t


static func _form_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = S2
	sb.content_margin_right = S2
	sb.content_margin_top = S1
	sb.content_margin_bottom = S1
	return sb


## One brass pill: a walnut key-cap and a short verb.
static func key_pill(key: String, verb: String) -> Control:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRASS
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = WALNUT
	sb.content_margin_left = S1 + 1
	sb.content_margin_right = S2 + 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.shadow_color = SHADOW
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 2)
	pill.add_theme_stylebox_override("panel", sb)
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", S1 + 2)
	pill.add_child(entry)
	entry.add_child(keycap(key))
	var lbl := Label.new()
	lbl.text = verb
	lbl.add_theme_font_override("font", bold_font())
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", WALNUT)
	entry.add_child(lbl)
	return pill


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


## When an order is due, as one consistent colour everywhere: red = today, amber =
## tomorrow, green = later. `days_ceil` is SuitOrder.days_left_ceil() (1 = today).
static func due_color(days_ceil: int) -> Color:
	if days_ceil <= 1:
		return CLAY
	if days_ceil == 2:
		return AMBER
	return FOREST


## "Today" / "Tomorrow" / "3 days" for the same count.
static func due_text(days_ceil: int) -> String:
	if days_ceil <= 1:
		return "Today"
	if days_ceil == 2:
		return "Tomorrow"
	return "%d days" % days_ceil


## Fill colour by fraction remaining (forest → amber → clay); never colour alone.
static func fill_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return FOREST
	if fraction >= 0.25:
		return AMBER
	return CLAY
