class_name PartTabs
extends Control

## The fitting room's part switcher: a strip of small icon tabs — an eye for the whole
## suit, then each garment — instead of one more value row. The current tab is a brass label with a
## stitched underline; when the strip itself is the selected row it gains a brass running
## stitch and ‹ › chevrons, so A/D visibly belongs to it. Flat shapes from Style tokens,
## each glyph drawn in a 0..1 box and scaled to its tab.
##   PartTabs.make(parts, current, focused, ticks)
## `parts` are GarmentTypes; tab 0 is always the overview, so `current` is -1 for it (the
## suit builder's own convention) and `ticks` lists the parts that earn a ✓.

const HEIGHT := 50.0
const TAB_W := 52.0
const GAP := 6.0
const ICON := 28.0
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
		var mid := (size.y - 8.0) * 0.5
		_chevron(Vector2(_tab_rect(0).position.x - CHEVRON_W * 0.5, mid), -1.0)
		_chevron(Vector2(_tab_rect(count - 1).end.x + CHEVRON_W * 0.5, mid), 1.0)


func _tab_rect(i: int) -> Rect2:
	# Fixed-width tabs, centred as a group (narrower only if the strip can't hold them).
	var count := parts.size() + 1
	var room := (size.x - CHEVRON_W * 2.0 - GAP * float(count - 1)) / float(count)
	var w := minf(TAB_W, room)
	var total := w * float(count) + GAP * float(count - 1)
	var left := (size.x - total) * 0.5
	return Rect2(Vector2(left + (w + GAP) * float(i), 0.0), Vector2(w, size.y - 8.0))


func _draw_tab(i: int, rect: Rect2) -> void:
	var on := i == current + 1
	var fill := Style.BRASS if on else Style.CARD
	var line := Style.WALNUT if on else Style.CREAM_DARK
	var poly := Craft.rounded(rect, 10.0)
	Craft.card(self, poly, fill, line, 2.0)
	if on and focused:
		Craft.stitch(self, poly, Style.WALNUT, 4.0, 1.2)
	var ink := Style.WALNUT if on else Style.INK_SOFT
	var icon_at := rect.get_center() - Vector2(ICON, ICON) * 0.5
	_glyph(-1 if i == 0 else int(parts[i - 1]), Rect2(icon_at, Vector2(ICON, ICON)), ink, fill)
	if on:
		# The stitched underline that marks "you are here", even when the cursor isn't.
		var y := rect.end.y + 5.0
		var x := rect.position.x + 10.0
		while x < rect.end.x - 10.0:
			draw_line(Vector2(x, y), Vector2(minf(x + 7.0, rect.end.x - 10.0), y), Style.BRASS, 2.0)
			x += 12.0
	if i > 0 and ticks.has(parts[i - 1]):
		var at := rect.position + Vector2(rect.size.x - 8.0, 8.0)
		draw_circle(at, 6.0, Style.FOREST)
		draw_polyline(
			PackedVector2Array(
				[at + Vector2(-3, 0), at + Vector2(-0.8, 2.4), at + Vector2(3, -2.2)]
			),
			Style.CHALK,
			1.6,
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
			_eye(box, ink, cut)


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


## The overview: an almond eye with an iris and a little catchlight.
func _eye(box: Rect2, ink: Color, cut: Color) -> void:
	var lid := []
	for k in 13:
		var t := float(k) / 12.0
		lid.append(Vector2(0.04 + 0.92 * t, 0.5 - 0.30 * sin(t * PI)))
	for k in range(1, 12):
		var t := 1.0 - float(k) / 12.0
		lid.append(Vector2(0.04 + 0.92 * t, 0.5 + 0.30 * sin(t * PI)))
	_poly(box, lid, ink)
	_dot(box, Vector2(0.5, 0.5), 0.20, cut)
	_dot(box, Vector2(0.5, 0.5), 0.11, ink)
	_dot(box, Vector2(0.56, 0.44), 0.04, cut)
