class_name Craft

## The "made by hand" kit shared by every screen: silhouettes that look like real
## tailoring objects (swing tickets, price tags, pinked cloth, notepads), the bits that
## make them feel physical (stitching, brass eyelets and string, push-pins, a tape
## measure), and a small motion vocabulary (pop in, wiggle, bump). CraftPanel wraps the
## shapes as a container; custom _draw() code can call these directly.
##
## Everything is static and draws onto the CanvasItem it is given, in its local space.

const SHADOW_OFFSET := Vector2(0, 5)
## How many flourish() variations there are (see _play_flourish).
const FLOURISHES := 5

## The last flourish played, so the same one never plays twice in a row.
static var _last_flourish := -1

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


## A dashed running stitch `inset` px inside the polygon's edge. `progress` < 1 draws only
## that fraction of the way round (from the first corner), for sewing it in.
static func stitch(
	ci: CanvasItem,
	poly: PackedVector2Array,
	col: Color,
	inset := 6.0,
	width := 1.5,
	progress := 1.0,
) -> void:
	var inner := offset(poly, -inset)
	var left := INF
	if progress < 1.0:
		var total := 0.0
		for i in inner.size():
			total += inner[i].distance_to(inner[(i + 1) % inner.size()])
		left = total * maxf(progress, 0.0)
	for i in inner.size():
		var a := inner[i]
		var b := inner[(i + 1) % inner.size()]
		var run := a.distance_to(b)
		if run > left:
			if left > 1.0:
				ci.draw_dashed_line(a, a.lerp(b, left / run), col, width, 5.0)
			return
		ci.draw_dashed_line(a, b, col, width, 5.0)
		left -= run


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


## A spiral binding along the top edge of `r`: punched holes a little below the edge
## and a wire coil through each one. Each coil rises out of its hole up the front of
## the paper, loops over the edge and drops behind it, so the strand reads as going
## *through* the hole rather than sitting beside it. `wire` is the metal colour.
static func spiral(
	ci: CanvasItem, r: Rect2, wire := Color(0.66, 0.67, 0.70), step := 24.0, inset := 26.0
) -> void:
	var x := r.position.x + inset
	var last := r.end.x - inset + 0.5
	while x <= last:
		coil(ci, Vector2(x, r.position.y + 9.0), r.position.y, wire)
		x += step


## One coil of a spiral binding: the punched hole at `hole` and the wire loop that
## climbs from it over the paper edge at `y_edge`. The loop is a sheared ellipse so it
## leans like a real coil; only the part above the edge and the front strand show.
static func coil(ci: CanvasItem, hole: Vector2, y_edge: float, wire: Color) -> void:
	var ry := hole.y - (y_edge - 1.0)
	var lean := 0.35  # the top of the loop sits this far (× ry) left of the hole
	var c := Vector2(hole.x - lean * ry, y_edge - 1.0)
	var rx := 4.2
	var dark := Color(0.18, 0.13, 0.10, 0.92)
	# The hole: a lighter lower rim (the paper's thickness) under a dark punch.
	ci.draw_circle(hole + Vector2(0, 1.0), 3.6, Color(1, 1, 1, 0.45))
	ci.draw_circle(hole, 3.3, dark)
	# Sample the loop. t = -PI/2 is the top; the right half (cos t > 0) is the strand in
	# front of the paper, which descends into the hole at t = PI/2.
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for i in 41:
		var t := -PI / 2.0 + TAU * i / 40.0
		var p := c + Vector2(rx * cos(t) + lean * ry * sin(t), ry * sin(t))
		if cos(t) >= -0.02:
			front.append(p)
		elif p.y <= y_edge + 0.5:
			back.append(p)
	# Behind the edge: dimmer, thinner.
	if back.size() >= 2:
		ci.draw_polyline(back, wire.darkened(0.38), 2.0, true)
	# Its shadow on the paper, then the front strand and a thin highlight.
	var on_paper := PackedVector2Array()
	for p in front:
		if p.y >= y_edge:
			on_paper.append(p + Vector2(1.2, 1.6))
	if on_paper.size() >= 2:
		ci.draw_polyline(on_paper, Color(0, 0, 0, 0.18), 2.6, true)
	ci.draw_polyline(front, wire, 2.6, true)
	var lit := PackedVector2Array()
	for p in front:
		lit.append(p + Vector2(-0.6, -0.7))
	ci.draw_polyline(lit, Color(0.95, 0.95, 0.97, 0.85), 0.9, true)
	# The lower half of the punch drawn back over the wire's end: it goes *into* the hole.
	var lip := PackedVector2Array([hole])
	for i in 9:
		lip.append(hole + Vector2.from_angle(PI * i / 8.0) * 3.3)
	ci.draw_colored_polygon(lip, dark)


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


## Pop a control in from slightly small with a springy overshoot. A control attached to
## an interface size (UiScale) settles at that size, around its own pivot.
static func pop_in(c: Control, from := 0.88, time := 0.26) -> void:
	if c == null:
		return
	_centre_pivot(c)
	var rest := UiScale.target_scale(c)
	c.scale = rest * from
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", rest, time)


## Pivot on the centre, unless an interface size owns the pivot (UiScale).
static func _centre_pivot(c: Control) -> void:
	if UiScale.is_attached(c):
		UiScale.fit_pivot(c)
	else:
		c.pivot_offset = c.size * 0.5


## A quick side-to-side wiggle (rotation) that settles back to `rest_deg`.
static func wiggle(c: Control, deg := 3.0, rest_deg := 0.0) -> void:
	if c == null:
		return
	if not UiScale.is_attached(c):  # moving a scaled control's pivot would shift it
		c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
	var tw := c.create_tween()
	for d in [deg, -deg * 0.7, deg * 0.4, 0.0]:
		tw.tween_property(c, "rotation_degrees", rest_deg + d, 0.07)


## The little "picked!" flourish a card gives when it becomes the selection: one of a few
## variations in the same springy style (a wiggle, a bump, a squash, a swing off one pin,
## the stitching sewn in), never the same one twice running.
static func flourish(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	if c.size.x < 1.0:
		await c.get_tree().process_frame  # let the container lay it out so pivots are right
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
	var pick := randi() % FLOURISHES
	if pick == _last_flourish:
		pick = (pick + 1 + randi() % (FLOURISHES - 1)) % FLOURISHES
	_last_flourish = pick
	_play_flourish(c, pick)


static func _play_flourish(c: Control, pick: int) -> void:
	# A card re-selected mid-flourish starts clean rather than stacking tweens.
	if c.has_meta("flourish_tween"):
		var old: Tween = c.get_meta("flourish_tween")
		if old != null and old.is_valid():
			old.kill()
	c.scale = Vector2.ONE
	c.rotation_degrees = 0.0
	var tw := c.create_tween()
	c.set_meta("flourish_tween", tw)
	var dir := 1.0 if randf() < 0.5 else -1.0
	match pick:
		0:  # wiggle, either way round
			c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
			for d in [1.2, -0.84, 0.48, 0.0]:
				tw.tween_property(c, "rotation_degrees", d * dir, 0.07)
		1:  # springy bump
			c.pivot_offset = c.size * 0.5
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", Vector2(1.035, 1.035), 0.08)
			tw.tween_property(c, "scale", Vector2.ONE, 0.18)
		2:  # squash & stretch, like a cushion being pressed
			c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y)
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", Vector2(1.03, 0.9), 0.07)
			tw.tween_property(c, "scale", Vector2(0.99, 1.04), 0.09)
			tw.tween_property(c, "scale", Vector2.ONE, 0.12)
		3:  # swings off one corner pin and settles
			c.pivot_offset = Vector2(c.size.x if dir < 0.0 else 0.0, 0.0)
			c.rotation_degrees = 1.6 * dir
			tw.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "rotation_degrees", 0.0, 0.55)
		_:  # the stitching runs round the card as it's sewn in, with a tiny lift
			c.pivot_offset = c.size * 0.5
			if "stitch_progress" in c:
				c.set("stitch_progress", 0.0)
				tw.tween_property(c, "stitch_progress", 1.0, 0.32)
			tw.parallel().tween_property(c, "scale", Vector2(1.02, 1.02), 0.1)
			tw.tween_property(c, "scale", Vector2.ONE, 0.14)


## A small scale bump (for "this changed").
static func bump(c: Control, amount := 1.12) -> void:
	if c == null:
		return
	_centre_pivot(c)
	var rest := UiScale.target_scale(c)
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", rest * amount, 0.08)
	tw.tween_property(c, "scale", rest, 0.18)
