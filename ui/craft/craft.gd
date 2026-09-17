class_name Craft

## The "made by hand" kit shared by every screen: silhouettes that look like real
## tailoring objects (swing tickets, price tags, pinked cloth, notepads), the bits that
## make them feel physical (stitching, brass eyelets and string, push-pins, a tape
## measure), and a small motion vocabulary (pop in, wiggle, bump). CraftPanel wraps the
## shapes as a container; custom _draw() code can call these directly.
##
## Everything is static and draws onto the CanvasItem it is given, in its local space.

const SHADOW_OFFSET := Vector2(0, 5)

# --- Silhouettes -------------------------------------------------------------


## A swing ticket: rectangle with both top corners clipped off.
static func ticket(r: Rect2, notch := 14.0) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array(
		[
			Vector2(p.x + notch, p.y),
			Vector2(e.x - notch, p.y),
			Vector2(e.x, p.y + notch),
			e,
			Vector2(p.x, e.y),
			Vector2(p.x, p.y + notch),
		]
	)


## A price tag pointing left: the left edge comes to a blunt point (where the eyelet
## sits), the rest is a slightly rounded rectangle.
static func price_tag(r: Rect2, point := 16.0) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	var mid := r.get_center().y
	var rr := 4.0
	return PackedVector2Array(
		[
			Vector2(p.x + point, p.y),
			Vector2(e.x - rr, p.y),
			Vector2(e.x, p.y + rr),
			Vector2(e.x, e.y - rr),
			Vector2(e.x - rr, e.y),
			Vector2(p.x + point, e.y),
			Vector2(p.x, mid),
		]
	)


## Cloth cut with pinking shears: zigzag top and bottom edges, straight sides.
static func pinked(r: Rect2, tooth := 7.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(2, int(r.size.x / (tooth * 2.0)))
	var step := r.size.x / n
	for i in n + 1:
		var x := r.position.x + i * step
		pts.append(Vector2(x, r.position.y))
		if i < n:
			pts.append(Vector2(x + step * 0.5, r.position.y + tooth * 0.8))
	for i in range(n, -1, -1):
		var x := r.position.x + i * step
		pts.append(Vector2(x, r.end.y))
		if i > 0:
			pts.append(Vector2(x - step * 0.5, r.end.y - tooth * 0.8))
	return pts


## A rounded rectangle as a polygon (corner radius `rad`, `seg` points per corner).
static func rounded(r: Rect2, rad := 12.0, seg := 5) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI / 2.0],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI / 2.0) * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Shrink (negative `by`) or grow a polygon evenly — for stitch lines and outlines.
static func offset(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(poly, by, Geometry2D.JOIN_MITER)
	return res[0] if not res.is_empty() else poly


# --- Drawing -----------------------------------------------------------------


## A filled card with a soft drop shadow and an outline.
static func card(
	ci: CanvasItem, poly: PackedVector2Array, fill: Color, line: Color, width := 2.0
) -> void:
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + SHADOW_OFFSET)
	ci.draw_colored_polygon(shadow, Style.SHADOW)
	ci.draw_colored_polygon(poly, fill)
	outline(ci, poly, line, width)


static func outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, width := 2.0) -> void:
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_polyline(closed, col, width, true)


## A dashed running stitch `inset` px inside the polygon's edge.
static func stitch(
	ci: CanvasItem, poly: PackedVector2Array, col: Color, inset := 6.0, width := 1.5
) -> void:
	var inner := offset(poly, -inset)
	for i in inner.size():
		ci.draw_dashed_line(inner[i], inner[(i + 1) % inner.size()], col, width, 5.0)


## A brass eyelet (punched hole) with an optional loop of string rising from it.
static func eyelet(ci: CanvasItem, at: Vector2, string_len := 26.0, sway := 0.0) -> void:
	if string_len > 0.0:
		var s := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			s.append(at + Vector2(sin(t * PI) * 10.0 + sway * t, -t * string_len))
		ci.draw_polyline(s, Style.BROWN, 2.0, true)
	ci.draw_circle(at, 6.5, Style.BRASS)
	ci.draw_circle(at, 3.5, Style.WALNUT)


## A dressmaker's pin lying on the surface at `angle`: a steel shaft with a coloured
## glass bead at one end and a fine point at the other, so it reads as pushed through
## the cloth rather than as a dot. (Craft.pin is the head-on board pin.)
static func dress_pin(
	ci: CanvasItem, at: Vector2, angle: float, bead: Color, length := 26.0
) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var head := at - dir * length * 0.5
	var point := at + dir * length * 0.5
	ci.draw_line(head + SHADOW_OFFSET * 0.4, point + SHADOW_OFFSET * 0.4, Style.SHADOW, 3.0)
	ci.draw_line(head, point, Style.STEEL_DARK, 3.0)
	ci.draw_line(head + dir * 3.0, head.lerp(point, 0.75), Style.STEEL, 1.5)
	ci.draw_circle(head + SHADOW_OFFSET * 0.4, 4.5, Style.SHADOW)
	ci.draw_circle(head, 4.5, bead)
	ci.draw_circle(head - dir * 1.4, 1.6, Style.tint(Style.CHALK, 0.75))


## A glossy push-pin head.
static func pin(ci: CanvasItem, at: Vector2, col: Color, rad := 7.0) -> void:
	ci.draw_circle(at + Vector2(1.5, 2.5), rad, Style.SHADOW)
	ci.draw_circle(at, rad, col)
	ci.draw_circle(at, rad, Style.WALNUT, false, 1.5, true)
	ci.draw_circle(at - Vector2(rad, rad) * 0.3, rad * 0.35, Style.CHALK)


## A tape measure strip across `r`: yellow tape, a tick every 10 cm and a number
## every metre up to `max_m`, plus labelled `marks` ({metres: text}) and a brass
## cursor at `cursor_m` (negative = none).
static func tape(
	ci: CanvasItem, r: Rect2, max_m: float, marks: Dictionary, cursor_m := -1.0
) -> void:
	var font: Font = (ci as Control).get_theme_default_font() if ci is Control else null
	if font == null:
		font = ThemeDB.fallback_font
	card(ci, rounded(r, 4.0, 2), Style.TAPE, Style.WALNUT, 1.5)
	var px := r.size.x / maxf(max_m, 0.1)
	var steps := int(round(max_m * 10.0))
	for i in steps + 1:
		var x := r.position.x + i * px / 10.0
		var tall := 0.45 if i % 10 == 0 else (0.28 if i % 5 == 0 else 0.16)
		ci.draw_line(
			Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y * tall), Style.WALNUT, 1.0
		)
		if i % 10 == 0 and i > 0 and i < steps:
			ci.draw_string(
				font,
				Vector2(x + 2, r.end.y - 3),
				str(int(i / 10.0)),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Style.WALNUT
			)
	var k := 0
	for m: float in marks:
		var x := r.position.x + m * px
		var lift := 6.0 + 12.0 * (k % 2)  # stagger neighbouring labels
		k += 1
		ci.draw_line(Vector2(x, r.position.y - lift + 2), Vector2(x, r.end.y), Style.BURGUNDY, 2.0)
		ci.draw_string(
			font,
			Vector2(x - 30, r.position.y - lift),
			str(marks[m]),
			HORIZONTAL_ALIGNMENT_CENTER,
			60,
			10,
			Style.BURGUNDY
		)
	if cursor_m >= 0.0:
		var x := r.position.x + minf(cursor_m, max_m) * px
		var tri := PackedVector2Array(
			[Vector2(x, r.end.y - 2), Vector2(x - 7, r.end.y + 9), Vector2(x + 7, r.end.y + 9)]
		)
		ci.draw_colored_polygon(tri, Style.BRASS)
		outline(ci, tri, Style.WALNUT, 1.5)
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Style.WALNUT, 2.0)


# --- Motion ------------------------------------------------------------------


## Pop a control in from slightly small with a springy overshoot.
static func pop_in(c: Control, from := 0.88, time := 0.26) -> void:
	if c == null:
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(from, from)
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, time)


## A quick side-to-side wiggle (rotation) that settles back to `rest_deg`.
static func wiggle(c: Control, deg := 3.0, rest_deg := 0.0) -> void:
	if c == null:
		return
	c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
	var tw := c.create_tween()
	for d in [deg, -deg * 0.7, deg * 0.4, 0.0]:
		tw.tween_property(c, "rotation_degrees", rest_deg + d, 0.07)


## A small scale bump (for "this changed").
static func bump(c: Control, amount := 1.12) -> void:
	if c == null:
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(amount, amount), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18)
