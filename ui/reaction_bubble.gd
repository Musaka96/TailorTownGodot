class_name ReactionBubble
extends PanelContainer

## What the customer at the fitting mirror says about the design, in a speech bubble at
## his shoulder: a cream card with a running stitch, edged in the mood's colour (forest
## for a yes, clay for a no), a round badge with a heart or a little raincloud, and his
## one line. A curved tail points at his head and follows it as the camera moves. Only
## the bubble is a fixed width; the text wraps.
##   ReactionBubble.show_for(host, customer, head_height, happy, lines)

const WIDTH := 300.0
const BADGE := 46.0
const RADIUS := 22.0
const STITCH_INSET := 6.0
const TAIL_ROOT := 26.0  # the tail's width where it leaves the card
const TAIL_TIP := 3.0  # radius of its rounded tip
const TAIL_STEPS := 8  # samples along each side of the tail
const GAP := 70.0  # px from the head to the bubble's near edge
const CLEAR := 36.0  # the bubble's near edge never comes closer to the head's centre
const EDGE := 16.0  # keep this far inside the screen / the panel
const TAIL_DROP := 18.0  # how far the tail hangs below a bubble sat over the head
const BOB := 2.0  # idle bob, px either way
const BOB_PERIOD := 2.4  # seconds
const POP_TIME := 0.3

var target: Node3D
var head_height := 1.8
## The area the bubble must stay inside (screen px) — left of the builder's panel.
var bounds := Rect2()
var _happy := true
var _head := Vector2.ZERO  # the head on screen, set by _follow
var _has_head := false
var _age := 0.0


static func show_for(
	host: Control, who: Node3D, at_height: float, happy: bool, lines: PackedStringArray
) -> ReactionBubble:
	var bubble := ReactionBubble.new()
	bubble.target = who
	bubble.head_height = at_height
	bubble._happy = happy
	bubble._build(lines)
	host.add_child(bubble)
	UiScale.attach(bubble, UiScale.DIALOGUE, Vector2(0.5, 0.5))
	bubble._follow()
	Craft.pop_in(bubble, 0.7, POP_TIME)
	if not happy:
		# A no: once it has popped, a small shake of the head.
		var tw := bubble.create_tween()
		tw.tween_interval(POP_TIME)
		tw.tween_callback(func() -> void: Craft.wiggle(bubble, 4.0))
	return bubble


## Shrink a touch and fade out, then go.
func dismiss() -> void:
	set_process(false)
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", UiScale.target_scale(self) * 0.9, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)


func _build(lines: PackedStringArray) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	# The card and its tail are drawn in _draw as one shape; the stylebox only pads.
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(Style.S3)
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S3)
	add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(BADGE, BADGE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.draw.connect(_draw_badge.bind(badge))
	row.add_child(badge)
	var lbl := Label.new()
	lbl.text = " ".join(lines)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wrapping labels need a real width, or they measure themselves one letter wide.
	lbl.custom_minimum_size = Vector2(WIDTH - BADGE - Style.S3 * 3.0, 0)
	lbl.add_theme_font_override("font", Style.font_medium())
	lbl.add_theme_font_size_override("font_size", Style.T_VALUE)
	lbl.add_theme_color_override("font_color", Style.INK)
	row.add_child(lbl)


func _process(delta: float) -> void:
	_age += delta
	_follow()


## Sit beside the head (towards the free side of the screen), inside `bounds`.
func _follow() -> void:
	if target == null or not is_instance_valid(target):
		dismiss()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := cam.unproject_position(target.global_position + Vector3.UP * head_height)
	var box := get_combined_minimum_size()
	if not size.is_equal_approx(box):
		size = box  # never taller than the words
	var area := bounds if bounds.has_area() else get_viewport_rect()
	# Beside the head on the free side, slid in to fit; the other side if that would cover
	# the face; above the head if neither side has the room.
	var at := Vector2(minf(head.x + GAP, area.end.x - box.x - EDGE), head.y - box.y * 0.35)
	if at.x < head.x + CLEAR:
		at.x = head.x - GAP - box.x
		if at.x < area.position.x + EDGE:
			at = Vector2(head.x - box.x * 0.5, head.y - box.y - TAIL_DROP - 6.0)
	at.x = clampf(at.x, area.position.x + EDGE, maxf(area.position.x, area.end.x - box.x - EDGE))
	at.y = clampf(at.y, area.position.y + EDGE, maxf(area.position.y, area.end.y - box.y - EDGE))
	# A gentle idle bob, so the bubble breathes while it waits.
	at.y += sin(_age * TAU / BOB_PERIOD) * BOB
	global_position = at
	_head = head
	_has_head = true
	queue_redraw()


func _draw() -> void:
	var mood := Style.FOREST if _happy else Style.CLAY
	var card := Craft.rounded(Rect2(Vector2.ZERO, size), RADIUS, 6)
	var tail := _tail_poly(card)
	# Shadow and fill for the card and the tail, then one outline round both, so the tail
	# grows out of the card with no seam.
	var outline: Array[PackedVector2Array] = [card]
	var shapes: Array[PackedVector2Array] = [card]
	if not tail.is_empty():
		shapes.append(tail)
		var merged := Geometry2D.merge_polygons(card, tail)
		if merged.size() == 1:
			outline = [merged[0]]
		else:
			outline = [card, tail]
	for poly in shapes:
		var shadow := PackedVector2Array()
		for p in poly:
			shadow.append(p + Craft.SHADOW_OFFSET)
		draw_colored_polygon(shadow, Style.SHADOW)
	for poly in shapes:
		draw_colored_polygon(poly, Style.CREAM)
	for poly in outline:
		Craft.outline(self, poly, mood, 2.0)
	Craft.stitch(self, card, Style.tint(mood, 0.6), STITCH_INSET, 1.5)


## The curved teardrop tail, in the bubble's space: two quadratic curves from a root on
## the card's edge (tucked a little inside it) to a rounded tip that points at the head.
## Wound the same way as `card`, so the two merge into one outline. Empty if no head yet.
func _tail_poly(card: PackedVector2Array) -> PackedVector2Array:
	if not _has_head:
		return PackedVector2Array()
	var head := get_global_transform().affine_inverse() * _head  # scale-aware
	var half := TAIL_ROOT * 0.5
	var root: Vector2
	var along: Vector2  # the edge the tail grows from
	var out: Vector2  # that edge's outward normal
	var reach: float
	if head.y > size.y * 0.5 and head.x > 0.0 and head.x < size.x:
		# Sitting over the head: the tail hangs from the bottom edge, leaning to it.
		var lo := RADIUS + half
		root = Vector2(clampf(head.x, lo, maxf(lo, size.x - lo)), size.y)
		along = Vector2.RIGHT
		out = Vector2.DOWN
		reach = TAIL_DROP
	else:
		var lo := RADIUS + half
		var y := clampf(head.y, lo, maxf(lo, size.y - lo))
		var left := head.x < size.x * 0.5
		root = Vector2(0.0 if left else size.x, y)
		along = Vector2.DOWN
		out = Vector2.LEFT if left else Vector2.RIGHT
		reach = clampf(root.distance_to(head) * 0.55, 12.0, 56.0)
	var aim := (head - root).normalized()
	if aim.dot(out) < 0.3:
		aim = (aim + out).normalized()  # never back across the card
	var tip := root + aim * reach
	var a := root + along * half - out * 5.0
	var b := root - along * half - out * 5.0
	var side := aim.orthogonal()
	if side.dot(a - root) < 0.0:
		side = -side
	var pts := PackedVector2Array()
	_quad(pts, a, root + along * half + aim * reach * 0.5, tip + side * TAIL_TIP)
	# Round the tip: half a turn from the a-side to the b-side, through the point.
	var turn := 1.0 if side.rotated(PI * 0.5).dot(aim) > 0.0 else -1.0
	for k in range(1, 5):
		pts.append(tip + side.rotated(turn * PI * float(k) / 5.0) * TAIL_TIP)
	_quad(pts, tip - side * TAIL_TIP, root - along * half + aim * reach * 0.5, b)
	if Geometry2D.is_polygon_clockwise(pts) != Geometry2D.is_polygon_clockwise(card):
		pts.reverse()
	return pts


## Append a quadratic curve from `p0` via control `c` to `p1`, TAIL_STEPS + 1 points.
func _quad(pts: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2) -> void:
	for k in TAIL_STEPS + 1:
		var t := float(k) / float(TAIL_STEPS)
		pts.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))


## A round badge in the mood's colour with a chalk mark: a heart for a yes, a little
## raincloud with two drops for a no.
func _draw_badge(badge: Control) -> void:
	var c := badge.size * 0.5
	var r := minf(c.x, c.y)
	var mood := Style.FOREST if _happy else Style.CLAY
	badge.draw_circle(c + Vector2(0, 2), r, Style.SHADOW)
	badge.draw_circle(c, r, mood)
	badge.draw_circle(c, r - 3.0, Style.tint(Style.CHALK, 0.18), false, 1.5, true)
	if _happy:
		_heart(badge, c, r)
	else:
		_raincloud(badge, c, r)


func _heart(badge: Control, c: Vector2, r: float) -> void:
	# The classic heart curve (x within ±16, y from -12 to 17), scaled into the badge.
	var k := r * 0.55 / 16.0
	var pts := PackedVector2Array()
	for i in 36:
		var t := TAU * float(i) / 36.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y - 2.5) * k)
	badge.draw_colored_polygon(pts, Style.CHALK)


func _raincloud(badge: Control, c: Vector2, r: float) -> void:
	var u := r / 20.0  # drawn in a 40-unit box
	var ink := Style.CHALK
	var at := c + Vector2(0, -3) * u
	badge.draw_circle(at + Vector2(-6, -1) * u, 5.0 * u, ink)
	badge.draw_circle(at + Vector2(0, -5) * u, 7.0 * u, ink)
	badge.draw_circle(at + Vector2(7, -1) * u, 5.0 * u, ink)
	var base := Rect2(at + Vector2(-11, -1) * u, Vector2(22, 6) * u)
	badge.draw_colored_polygon(Craft.rounded(base, 3.0 * u), ink)
	for drop: Vector2 in [Vector2(-4, 10), Vector2(4, 13)]:
		var p := at + drop * u
		badge.draw_circle(p, 2.2 * u, ink)
		var point := PackedVector2Array(
			[p + Vector2(-2.1, 0) * u, p + Vector2(0, -4.5) * u, p + Vector2(2.1, 0) * u]
		)
		badge.draw_colored_polygon(point, ink)
