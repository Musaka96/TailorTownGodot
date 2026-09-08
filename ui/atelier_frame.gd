class_name AtelierFrame
extends Control

## Decorative bespoke-tailoring frame drawn on top of a menu panel. Three layers:
##   1. a faint background PATTERN (pinstripe, ruled lines, herringbone, grid,
##      dots, cork) spanning the WHOLE panel — a watermark over the items, so the
##      screen reads as one textured sheet. Fabric swatches sit above it (their
##      z_index) so the real cloth preview stays clean.
##   2. a dashed "stitch" line inside the edge + chalk corner ticks;
##   3. a solid SHAPE accent (clip / book spine+ribbon / dog-ear / pin / tape)
##      tucked hard into the top-right or edges — never the top-left title.
## Transparent centre, ignores the mouse. Configure via Style.apply_skin(). The
## node is laid out inside the panel's content margins, but it reads those margins
## back off the panel so the pattern + shapes reach the true panel edges.

enum Pattern { NONE, PINSTRIPE, RULES, HERRINGBONE, GRID, DOTS, CORK }
enum Shape { NONE, CLIP, BOOK, FOLD, PIN, TAPE }

const STITCH := 7.0  # dashed stitch line, in from the TRUE panel edge (margin band)
const EDGE := 5.0  # shape accents sit this far from the true panel edge
const CHALK := Color(0.933, 0.949, 0.957)

var accent := Color("c9a24a")
var trim := Color("4a3826")
var pattern: int = Pattern.NONE
var shape: int = Shape.NONE
var radii := Vector4i(20, 20, 20, 20)  # top-left, top-right, bottom-right, bottom-left


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func setup(
	accent_col: Color, trim_col: Color, pattern_val: int, shape_val: int, radii_val: Vector4i
) -> void:
	accent = accent_col
	trim = trim_col
	pattern = pattern_val
	shape = shape_val
	radii = radii_val
	queue_redraw()


func _draw() -> void:
	var panel := _panel_rect()  # the full panel, in local coords
	_draw_pattern(panel)
	_draw_stitch(panel)
	_draw_corner_ticks(panel)
	_draw_shape(panel)


## The full panel rectangle expressed in this node's local space. The node fills
## the panel's content area, so the panel edges lie outside it by the stylebox's
## content margins — read those back so the pattern/shapes reach the real edges.
func _panel_rect() -> Rect2:
	var p := get_parent() as Control
	if p == null:
		return Rect2(Vector2.ZERO, size)
	var sb := p.get_theme_stylebox("panel")
	if sb == null:
		return Rect2(Vector2.ZERO, size)
	var ml := sb.get_margin(SIDE_LEFT)
	var mt := sb.get_margin(SIDE_TOP)
	var mr := sb.get_margin(SIDE_RIGHT)
	var mb := sb.get_margin(SIDE_BOTTOM)
	return Rect2(Vector2(-ml, -mt), size + Vector2(ml + mr, mt + mb))


# --- Layer 1: background pattern (whole panel, over items) ------------------


func _draw_pattern(panel: Rect2) -> void:
	var pad := 4.0
	var area := Rect2(panel.position + Vector2(pad, pad), panel.size - Vector2(pad, pad) * 2.0)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	match pattern:
		Pattern.PINSTRIPE:
			_pat_lines(area, true, 14.0, Color(accent.r, accent.g, accent.b, 0.10))
		Pattern.RULES:
			_pat_lines(area, false, 27.0, Color(trim.r, trim.g, trim.b, 0.08))
		Pattern.GRID:
			var g := Color(trim.r, trim.g, trim.b, 0.07)
			_pat_lines(area, true, 24.0, g)
			_pat_lines(area, false, 24.0, g)
		Pattern.DOTS:
			_pat_dots(area, 22.0, Color(accent.r, accent.g, accent.b, 0.14))
		Pattern.HERRINGBONE:
			_pat_herringbone(area, Color(accent.r, accent.g, accent.b, 0.10))
		Pattern.CORK:
			_pat_cork(area, Color(trim.r, trim.g, trim.b, 0.12))
		_:
			pass


## Evenly spaced vertical (or horizontal) hairlines across `area`.
func _pat_lines(area: Rect2, vertical: bool, step: float, col: Color) -> void:
	if vertical:
		var x := area.position.x + step
		while x < area.end.x:
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), col, 1.0)
			x += step
	else:
		var y := area.position.y + step
		while y < area.end.y:
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), col, 1.0)
			y += step


func _pat_dots(area: Rect2, step: float, col: Color) -> void:
	var y := area.position.y + step
	while y < area.end.y:
		var x := area.position.x + step
		while x < area.end.x:
			draw_circle(Vector2(x, y), 1.6, col)
			x += step
		y += step


## Little alternating diagonal strokes — a woven, tweed-y feel.
func _pat_herringbone(area: Rect2, col: Color) -> void:
	var step := 16.0
	var row := 0
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		var up := row % 2 == 0
		while x < area.end.x:
			var a := Vector2(x, y + step)
			var b := Vector2(x + step * 0.5, y) if up else Vector2(x + step * 0.5, y + step)
			var c := Vector2(x + step, y + step) if up else Vector2(x + step, y)
			draw_line(a, b, col, 1.0)
			draw_line(b, c, col, 1.0)
			x += step
		y += step
		row += 1


## Stable speckle (seeded so it doesn't shimmer between redraws).
func _pat_cork(area: Rect2, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for _i in 320:
		var p := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y),
		)
		draw_circle(p, rng.randf_range(0.8, 1.8), col)


# --- Layer 2: stitch + corner ticks (inner border) -------------------------


## Dashed stitch just inside the true panel edge (in the margin band, clear of the
## content), following each corner's radius so it hugs the panel's own silhouette.
func _draw_stitch(panel: Rect2) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.75)
	var lo := panel.position + Vector2(STITCH, STITCH)
	var hi := panel.end - Vector2(STITCH, STITCH)
	var tl := float(radii.x)
	var tr := float(radii.y)
	var br := float(radii.z)
	var bl := float(radii.w)
	draw_dashed_line(Vector2(lo.x + tl, lo.y), Vector2(hi.x - tr, lo.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x + bl, hi.y), Vector2(hi.x - br, hi.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x, lo.y + tl), Vector2(lo.x, hi.y - bl), a, 2.0, 5.0)
	draw_dashed_line(Vector2(hi.x, lo.y + tr), Vector2(hi.x, hi.y - br), a, 2.0, 5.0)


## Little chalk registration ticks, set at each corner's rounded tangent.
func _draw_corner_ticks(panel: Rect2) -> void:
	var ch := Color(CHALK.r, CHALK.g, CHALK.b, 0.9)
	var lo := panel.position + Vector2(STITCH, STITCH)
	var hi := panel.end - Vector2(STITCH, STITCH)
	var d := 9.0
	var tl := maxf(float(radii.x) - STITCH, 0.0)
	var tr := maxf(float(radii.y) - STITCH, 0.0)
	var br := maxf(float(radii.z) - STITCH, 0.0)
	var bl := maxf(float(radii.w) - STITCH, 0.0)
	var p := Vector2(lo.x + tl, lo.y + tl)
	draw_line(p + Vector2(0, d), p, ch, 2.0)
	draw_line(p, p + Vector2(d, 0), ch, 2.0)
	p = Vector2(hi.x - tr, lo.y + tr)
	draw_line(p - Vector2(d, 0), p, ch, 2.0)
	draw_line(p, p + Vector2(0, d), ch, 2.0)
	p = Vector2(lo.x + bl, hi.y - bl)
	draw_line(p + Vector2(0, -d), p, ch, 2.0)
	draw_line(p, p + Vector2(d, 0), ch, 2.0)
	p = Vector2(hi.x - br, hi.y - br)
	draw_line(p - Vector2(d, 0), p, ch, 2.0)
	draw_line(p, p + Vector2(0, -d), ch, 2.0)


# --- Layer 3: shape accent (hard to the top-right / edges) ------------------


func _draw_shape(panel: Rect2) -> void:
	match shape:
		Shape.CLIP:
			_shape_clip(panel)
		Shape.BOOK:
			_shape_book(panel)
		Shape.FOLD:
			_shape_fold(panel)
		Shape.PIN:
			_shape_pin(panel)
		Shape.TAPE:
			_shape_tape(panel)
		_:
			pass


## A bulldog clip gripping the top-right of an order pad.
func _shape_clip(r: Rect2) -> void:
	var w := 54.0
	var x := r.end.x - EDGE - w
	var y := r.position.y + EDGE
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 13.0)), accent, true)
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 13.0)), trim, false, 1.5)
	draw_line(Vector2(x + w * 0.5, y + 13.0), Vector2(x + w * 0.5, y + 20.0), trim, 2.0)


## A book: a spine bar down the left edge plus a ribbon bookmark top-right.
func _shape_book(r: Rect2) -> void:
	var spine := Color(accent.r, accent.g, accent.b, 0.85)
	var spine_rect := Rect2(r.position + Vector2(EDGE, EDGE), Vector2(7.0, r.size.y - EDGE * 2.0))
	draw_rect(spine_rect, spine, true)
	var x := r.end.x - EDGE - 34.0
	var w := 15.0
	var top := r.position.y
	var bot := top + 50.0
	draw_rect(Rect2(Vector2(x, top), Vector2(w, bot - top)), accent, true)
	var pts := PackedVector2Array(
		[
			Vector2(x, bot),
			Vector2(x + w * 0.5, bot - 8.0),
			Vector2(x + w, bot),
			Vector2(x + w, bot + 8.0),
			Vector2(x + w * 0.5, bot),
			Vector2(x, bot + 8.0),
		]
	)
	draw_colored_polygon(pts, accent)


## A dog-eared folded corner, hard into the top-right.
func _shape_fold(r: Rect2) -> void:
	var s := 30.0
	var tr := Vector2(r.end.x - EDGE, r.position.y + EDGE)
	var pts := PackedVector2Array([tr - Vector2(s, 0), tr, tr + Vector2(0, s)])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.9))
	var inner := PackedVector2Array(
		[tr - Vector2(s, 0), tr - Vector2(s * 0.5, -s * 0.5), tr + Vector2(0, s)]
	)
	draw_colored_polygon(inner, Color(accent.r, accent.g, accent.b, 0.45))


## A push-pin holding a ticket to the board, top-right corner.
func _shape_pin(r: Rect2) -> void:
	var c := Vector2(r.end.x - EDGE - 14.0, r.position.y + EDGE + 14.0)
	draw_circle(c, 8.0, accent)
	draw_circle(c - Vector2(2.5, 2.5), 3.0, Color(CHALK.r, CHALK.g, CHALK.b, 0.8))
	draw_circle(c, 8.0, trim, false, 1.5)


## Strips of masking tape across the top-right and bottom-left corners.
func _shape_tape(r: Rect2) -> void:
	var col := Color(CHALK.r, CHALK.g, CHALK.b, 0.32)
	var s := 34.0
	var tr := Vector2(r.end.x - EDGE, r.position.y + EDGE)
	draw_colored_polygon(
		PackedVector2Array(
			[tr - Vector2(s, -6), tr + Vector2(6, 0), tr + Vector2(0, s), tr - Vector2(s + 6, -s)]
		),
		col
	)
	var bl := Vector2(r.position.x + EDGE, r.end.y - EDGE)
	draw_colored_polygon(
		PackedVector2Array(
			[
				bl + Vector2(-6, -s),
				bl + Vector2(s, 6),
				bl + Vector2(s + 6, 0),
				bl + Vector2(0, -s - 6)
			]
		),
		col
	)
