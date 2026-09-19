class_name PartTabs
extends Control

## The fitting room's part switcher: a strip of drawn tabs — the whole suit, then each
## garment — instead of one more value row. The current tab is a brass label with a
## stitched underline; when the strip itself is the selected row it gains a brass running
## stitch and ‹ › chevrons, so A/D visibly belongs to it. Flat shapes from Style tokens,
## each glyph drawn in a 0..1 box and scaled to its tab.
##   PartTabs.make(parts, current, focused, ticks)
## `parts` are GarmentTypes; tab 0 is always the overview, so `current` is -1 for it (the
## suit builder's own convention) and `ticks` lists the parts that earn a ✓.

const HEIGHT := 78.0
const GAP := 6.0
const ICON := 34.0
const CHEVRON_W := 16.0

var parts: Array = []
var current := -1
var focused := false
var ticks: Array = []


static func make(
	tab_parts: Array, tab_current: int, tab_focused: bool, tab_ticks: Array
) -> PartTabs:
	var strip := PartTabs.new()
	strip.parts = tab_parts
	strip.current = tab_current
	strip.focused = tab_focused
	strip.ticks = tab_ticks
	return strip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The on-screen rect of the tab for `part` (-1 = overview) — the tutorial points at it.
func tab_rect(part_index: int) -> Rect2:
	var local := _tab_rect(part_index + 1)
	return Rect2(global_position + local.position, local.size)


func _draw() -> void:
	var count := parts.size() + 1
	for i in count:
		_draw_tab(i, _tab_rect(i))
	if focused:
		var mid := size.y * 0.5 - 8.0
		_chevron(Vector2(CHEVRON_W * 0.5, mid), -1.0)
		_chevron(Vector2(size.x - CHEVRON_W * 0.5, mid), 1.0)


func _tab_rect(i: int) -> Rect2:
	var count := parts.size() + 1
	var inner := size.x - CHEVRON_W * 2.0
	var w := (inner - GAP * float(count - 1)) / float(count)
	return Rect2(Vector2(CHEVRON_W + (w + GAP) * float(i), 0.0), Vector2(w, size.y - 8.0))


func _draw_tab(i: int, rect: Rect2) -> void:
	var on := i == current + 1
	var fill := Style.BRASS if on else Style.CARD
	var line := Style.WALNUT if on else Style.CREAM_DARK
	var poly := Craft.rounded(rect, 10.0)
	Craft.card(self, poly, fill, line, 2.0)
	if on and focused:
		Craft.stitch(self, poly, Style.WALNUT, 4.0, 1.2)
	var ink := Style.WALNUT if on else Style.INK_SOFT
	var icon_at := Vector2(rect.get_center().x - ICON * 0.5, rect.position.y + 7.0)
	_glyph(-1 if i == 0 else int(parts[i - 1]), Rect2(icon_at, Vector2(ICON, ICON)), ink, fill)
	var font := Style.font_bold() if on else Style.font_medium()
	var text := "Overview" if i == 0 else Enums.garment_type_name(int(parts[i - 1]))
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO).x
	var base := Vector2(rect.get_center().x - text_w * 0.5, rect.end.y - 9.0)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, ink)
	if on:
		# The stitched underline that marks "you are here", even when the cursor isn't.
		var y := rect.end.y + 5.0
		var x := rect.position.x + 10.0
		while x < rect.end.x - 10.0:
			draw_line(Vector2(x, y), Vector2(minf(x + 7.0, rect.end.x - 10.0), y), Style.BRASS, 2.0)
			x += 12.0
	if i > 0 and ticks.has(parts[i - 1]):
		var at := rect.position + Vector2(rect.size.x - 12.0, 12.0)
		draw_circle(at, 7.0, Style.FOREST)
		draw_polyline(
			PackedVector2Array(
				[at + Vector2(-3.5, 0), at + Vector2(-1, 2.8), at + Vector2(3.6, -2.6)]
			),
			Style.CHALK,
			1.8,
			true
		)


func _chevron(at: Vector2, dir: float) -> void:
	var pts := PackedVector2Array(
		[
			at + Vector2(-3.0 * dir, -7.0),
			at + Vector2(4.0 * dir, 0.0),
			at + Vector2(-3.0 * dir, 7.0)
		]
	)
	draw_polyline(pts, Style.text_accent(Style.BRASS), 2.5, true)


# --- Glyphs (0..1 box) -------------------------------------------------------


func _glyph(kind: int, box: Rect2, ink: Color, cut: Color) -> void:
	match kind:
		Enums.GarmentType.JACKET:
			_jacket(box, ink, cut)
		Enums.GarmentType.SHIRT:
			_shirt(box, ink, cut)
		Enums.GarmentType.PANTS:
			_pants(box, ink, cut)
		_:
			_figure(box, ink, cut)


func _poly(box: Rect2, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(box.position + p * box.size)
	draw_colored_polygon(out, col)


func _line(box: Rect2, a: Vector2, b: Vector2, col: Color, width := 1.5) -> void:
	draw_line(box.position + a * box.size, box.position + b * box.size, col, width, true)


func _dot(box: Rect2, at: Vector2, radius: float, col: Color) -> void:
	draw_circle(box.position + at * box.size, radius * box.size.x, col)


func _torso(box: Rect2, ink: Color, sleeve_end: float) -> void:
	var body := [
		Vector2(0.30, 0.12),
		Vector2(0.42, 0.06),
		Vector2(0.58, 0.06),
		Vector2(0.70, 0.12),
		Vector2(0.74, 0.94),
		Vector2(0.26, 0.94),
	]
	_poly(box, body, ink)
	for side: float in [-1.0, 1.0]:
		var sleeve := [
			Vector2(0.5 + 0.20 * side, 0.12),
			Vector2(0.5 + 0.46 * side, 0.30),
			Vector2(0.5 + 0.40 * side, sleeve_end),
			Vector2(0.5 + 0.27 * side, sleeve_end - 0.03),
			Vector2(0.5 + 0.24 * side, 0.40),
		]
		_poly(box, sleeve, ink)


## Long sleeves, a deep lapel V and two buttons.
func _jacket(box: Rect2, ink: Color, cut: Color) -> void:
	_torso(box, ink, 0.84)
	_line(box, Vector2(0.42, 0.06), Vector2(0.5, 0.52), cut, 2.0)
	_line(box, Vector2(0.58, 0.06), Vector2(0.5, 0.52), cut, 2.0)
	_line(box, Vector2(0.5, 0.52), Vector2(0.5, 0.94), cut)
	_dot(box, Vector2(0.56, 0.64), 0.035, cut)
	_dot(box, Vector2(0.56, 0.78), 0.035, cut)


## Short sleeves, a pointed collar and a buttoned placket.
func _shirt(box: Rect2, ink: Color, cut: Color) -> void:
	_torso(box, ink, 0.50)
	_poly(box, [Vector2(0.40, 0.06), Vector2(0.5, 0.24), Vector2(0.60, 0.06)], cut)
	_line(box, Vector2(0.5, 0.24), Vector2(0.5, 0.94), cut)
	for y: float in [0.40, 0.58, 0.76]:
		_dot(box, Vector2(0.5, y), 0.03, cut)


## A waistband and two tapering legs with a pressed crease.
func _pants(box: Rect2, ink: Color, cut: Color) -> void:
	_poly(
		box, [Vector2(0.22, 0.06), Vector2(0.78, 0.06), Vector2(0.78, 0.2), Vector2(0.22, 0.2)], ink
	)
	for side: float in [-1.0, 1.0]:
		var leg := [
			Vector2(0.5 + 0.28 * side, 0.2),
			Vector2(0.5, 0.2),
			Vector2(0.5, 0.34),
			Vector2(0.5 + 0.07 * side, 0.96),
			Vector2(0.5 + 0.27 * side, 0.96),
		]
		_poly(box, leg, ink)
		_line(box, Vector2(0.5 + 0.17 * side, 0.26), Vector2(0.5 + 0.17 * side, 0.92), cut, 1.0)
	_line(box, Vector2(0.22, 0.2), Vector2(0.78, 0.2), cut, 1.0)


## The whole suit on its wearer: head, jacket and legs.
func _figure(box: Rect2, ink: Color, cut: Color) -> void:
	_dot(box, Vector2(0.5, 0.11), 0.1, ink)
	var top := [Vector2(0.30, 0.25), Vector2(0.70, 0.25), Vector2(0.72, 0.62), Vector2(0.28, 0.62)]
	_poly(box, top, ink)
	for side: float in [-1.0, 1.0]:
		var arm := [
			Vector2(0.5 + 0.20 * side, 0.25),
			Vector2(0.5 + 0.36 * side, 0.34),
			Vector2(0.5 + 0.33 * side, 0.64),
			Vector2(0.5 + 0.25 * side, 0.63),
		]
		_poly(box, arm, ink)
		var leg := [
			Vector2(0.5 + 0.21 * side, 0.64),
			Vector2(0.5 + 0.01 * side, 0.64),
			Vector2(0.5 + 0.04 * side, 0.98),
			Vector2(0.5 + 0.20 * side, 0.98),
		]
		_poly(box, leg, ink)
	_line(box, Vector2(0.43, 0.25), Vector2(0.5, 0.44), cut)
	_line(box, Vector2(0.57, 0.25), Vector2(0.5, 0.44), cut)
