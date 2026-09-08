class_name AtelierFrame
extends Control

## Decorative bespoke-tailoring frame drawn over a menu panel. Three layers, from
## back to front:
##   1. a faint full-area background PATTERN (pinstripe, ruled lines, herringbone,
##      cutting-grid, cork…) — a watermark, so body text stays readable over it;
##   2. a dashed "stitch" line just inside the edge + chalk corner ticks;
##   3. a solid SHAPE accent (clip / book spine+ribbon / dog-ear / pin / tape),
##      always tucked into the top-right or edges — never the top-left, where the
##      screen title lives — so it can't collide with text.
## Transparent centre, ignores the mouse. Configure via Style.apply_skin().

enum Pattern { NONE, PINSTRIPE, RULES, HERRINGBONE, GRID, DOTS, CORK }
enum Shape { NONE, CLIP, BOOK, FOLD, PIN, TAPE }

const INSET := 9.0
const CORNER := 16.0
const CHALK := Color(0.933, 0.949, 0.957)

var accent := Color("c9a24a")
var trim := Color("4a3826")
var pattern: int = Pattern.NONE
var shape: int = Shape.NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func setup(accent_col: Color, trim_col: Color, pattern_val: int, shape_val: int) -> void:
	accent = accent_col
	trim = trim_col
	pattern = pattern_val
	shape = shape_val
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_draw_pattern(r)
	_draw_stitch(r)
	_draw_corner_ticks(r)
	_draw_shape(r)


# --- Layer 1: background pattern (watermark) -------------------------------


func _draw_pattern(r: Rect2) -> void:
	var pad := INSET + 8.0
	var area := Rect2(r.position + Vector2(pad, pad), r.size - Vector2(pad, pad) * 2.0)
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
	for _i in 240:
		var p := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y),
		)
		draw_circle(p, rng.randf_range(0.8, 1.8), col)


# --- Layer 2: stitch + corner ticks ----------------------------------------


func _draw_stitch(r: Rect2) -> void:
	var a := Color(accent.r, accent.g, accent.b, 0.75)
	var lo := r.position + Vector2(INSET, INSET)
	var hi := r.end - Vector2(INSET, INSET)
	var c := CORNER
	draw_dashed_line(Vector2(lo.x + c, lo.y), Vector2(hi.x - c, lo.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x + c, hi.y), Vector2(hi.x - c, hi.y), a, 2.0, 5.0)
	draw_dashed_line(Vector2(lo.x, lo.y + c), Vector2(lo.x, hi.y - c), a, 2.0, 5.0)
	draw_dashed_line(Vector2(hi.x, lo.y + c), Vector2(hi.x, hi.y - c), a, 2.0, 5.0)


func _draw_corner_ticks(r: Rect2) -> void:
	var ch := Color(CHALK.r, CHALK.g, CHALK.b, 0.9)
	var lo := r.position + Vector2(INSET, INSET)
	var hi := r.end - Vector2(INSET, INSET)
	var d := 9.0
	draw_line(Vector2(lo.x, lo.y + d), Vector2(lo.x, lo.y), ch, 2.0)
	draw_line(Vector2(lo.x, lo.y), Vector2(lo.x + d, lo.y), ch, 2.0)
	draw_line(Vector2(hi.x - d, lo.y), Vector2(hi.x, lo.y), ch, 2.0)
	draw_line(Vector2(hi.x, lo.y), Vector2(hi.x, lo.y + d), ch, 2.0)
	draw_line(Vector2(lo.x, hi.y - d), Vector2(lo.x, hi.y), ch, 2.0)
	draw_line(Vector2(lo.x, hi.y), Vector2(lo.x + d, hi.y), ch, 2.0)
	draw_line(Vector2(hi.x - d, hi.y), Vector2(hi.x, hi.y), ch, 2.0)
	draw_line(Vector2(hi.x, hi.y - d), Vector2(hi.x, hi.y), ch, 2.0)


# --- Layer 3: shape accent (top-right / edges only) ------------------------


func _draw_shape(r: Rect2) -> void:
	match shape:
		Shape.CLIP:
			_shape_clip(r)
		Shape.BOOK:
			_shape_book(r)
		Shape.FOLD:
			_shape_fold(r)
		Shape.PIN:
			_shape_pin(r)
		Shape.TAPE:
			_shape_tape(r)
		_:
			pass


## A bulldog clip gripping the top-right of an order pad.
func _shape_clip(r: Rect2) -> void:
	var w := 54.0
	var x := r.end.x - INSET - 20.0 - w
	var y := r.position.y + INSET - 3.0
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 13.0)), accent, true)
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 13.0)), trim, false, 1.5)
	draw_line(Vector2(x + w * 0.5, y + 13.0), Vector2(x + w * 0.5, y + 20.0), trim, 2.0)


## A book: a spine bar down the left edge plus a ribbon bookmark top-right.
func _shape_book(r: Rect2) -> void:
	var spine := Color(accent.r, accent.g, accent.b, 0.85)
	var spine_rect := Rect2(r.position + Vector2(3.0, 3.0), Vector2(7.0, r.size.y - 6.0))
	draw_rect(spine_rect, spine, true)
	var x := r.end.x - INSET - 46.0
	var w := 15.0
	var top := r.position.y + INSET - 2.0
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


## A dog-eared folded corner, top-right (a bolt of cloth turned back).
func _shape_fold(r: Rect2) -> void:
	var s := 30.0
	var tr := Vector2(r.end.x - INSET, r.position.y + INSET)
	var pts := PackedVector2Array([tr - Vector2(s, 0), tr, tr + Vector2(0, s)])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.9))
	var inner := PackedVector2Array(
		[tr - Vector2(s, 0), tr - Vector2(s * 0.5, -s * 0.5), tr + Vector2(0, s)]
	)
	draw_colored_polygon(inner, Color(accent.r, accent.g, accent.b, 0.45))


## A push-pin holding a ticket to the board, top-right.
func _shape_pin(r: Rect2) -> void:
	var c := Vector2(r.end.x - INSET - 24.0, r.position.y + INSET + 8.0)
	draw_circle(c, 8.0, accent)
	draw_circle(c - Vector2(2.5, 2.5), 3.0, Color(CHALK.r, CHALK.g, CHALK.b, 0.8))
	draw_circle(c, 8.0, trim, false, 1.5)


## Two strips of masking tape across the top-right and bottom-left corners.
func _shape_tape(r: Rect2) -> void:
	var col := Color(CHALK.r, CHALK.g, CHALK.b, 0.32)
	var s := 34.0
	var tr := Vector2(r.end.x - INSET, r.position.y + INSET)
	draw_colored_polygon(
		PackedVector2Array(
			[tr - Vector2(s, -6), tr + Vector2(6, 0), tr + Vector2(0, s), tr - Vector2(s + 6, -s)]
		),
		col
	)
	var bl := Vector2(r.position.x + INSET, r.end.y - INSET)
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
