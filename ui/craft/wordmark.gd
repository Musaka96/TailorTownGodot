class_name Wordmark
extends Control

## The shop's name as fascia lettering: a two-line gold-leaf lockup in the display face,
## a running stitch sewn underneath that ends in a threaded needle, and a tracked
## tagline. Flat shapes only — the leaf is a face, a dark lower edge and a pale upper
## one. `progress` (0..1) sews the thread in; sew_in() animates it, ticking a soft thread
## pull per stitch, and when the seam is done the leaf catches the light: `glint` (0..1)
## walks a twinkle across the lettering, and again every so often after.

const LETTER := 62  # display size of the two name lines
const LEAD := 54.0  # baseline to baseline
const STEP := 50.0  # how far the second line is indented past the first
const TAGLINE := "BESPOKE TAILORING  ·  ON THE ROW"
const STITCH := 15.0  # one dash + its gap, px
const GLINT_EVERY := 7.0  # seconds between idle twinkles
## The needle's shape: (distance from the head, half-width) pairs, head to point, px,
## before NEEDLE_SIZE. It is drawn oversized on purpose so it reads as a needle at a glance.
const NEEDLE_SIZE := 1.8
const NEEDLE_PROFILE := [
	Vector2(0.0, 2.4),
	Vector2(10.0, 2.2),
	Vector2(13.0, 1.9),
	Vector2(34.0, 1.9),
	Vector2(42.0, 1.1),
	Vector2(47.0, 0.35),
	Vector2(49.0, 0.0),
]
## Where the light catches, as fractions of the lettering block (x, y).
const GLINTS := [Vector2(0.16, 0.2), Vector2(0.72, 0.12), Vector2(0.5, 0.62), Vector2(0.95, 0.5)]

var progress := 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var glint := 1.0:
	set(value):
		glint = clampf(value, 0.0, 1.0)
		queue_redraw()
## Play the thread sound as the seam is sewn (off for silent uses of the lockup).
var sounds := true
## false = the name and its seam only (store capsules too small for the tagline).
var tagline := true

var _stitches_heard := 0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(360, 178)


## Sew the underline in from the left.
func sew_in(time := 0.9, delay := 0.0) -> void:
	progress = 0.0
	glint = 1.0
	_stitches_heard = 0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_method(_sew_to, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_callback(_knot)
	_tween.tween_property(self, "glint", 1.0, 1.1).from(0.0)
	_tween.tween_callback(_idle_glints)


func _sew_to(value: float) -> void:
	progress = value
	# One thread pull per stitch the needle completes (every other one: it's a quick seam).
	var done := int(_seam_span() * value / STITCH)
	if done > _stitches_heard:
		_stitches_heard = done
		if sounds and done % 2 == 0:
			Sfx.play("sign_sew", -13.0, 0.92, 1.12)


func _knot() -> void:
	if sounds:
		Sfx.play("pin_in", -12.0, 1.15, 1.25)


func _idle_glints() -> void:
	_tween = create_tween().set_loops()
	_tween.tween_interval(GLINT_EVERY)
	_tween.tween_property(self, "glint", 1.0, 1.1).from(0.0)


func _seam_span() -> float:
	var font := Style.font_display()
	var top := font.get_string_size("Tailor", HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER)
	var low := font.get_string_size("Town", HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER)
	return maxf(top.x, STEP + low.x) + 10.0


func _draw() -> void:
	var font := Style.font_display()
	var top := font.get_string_size("Tailor", HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER)
	var low := font.get_string_size("Town", HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER)
	var block_w := maxf(top.x, STEP + low.x)
	var x := (size.x - block_w) * 0.5
	var base := 60.0
	_leaf(font, "Tailor", Vector2(x, base))
	_leaf(font, "Town", Vector2(x + STEP, base + LEAD))
	var seam_y := base + LEAD + 20.0
	_thread(Vector2(x - 6.0, seam_y), Vector2(x + block_w + 4.0, seam_y))
	_glints(Rect2(Vector2(x, base - LETTER * 0.75), Vector2(block_w, LEAD + LETTER * 0.8)))
	if not tagline:
		return
	var caps := Style.font_caps()
	var tag_w := caps.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO).x
	var tag_at := Vector2((size.x - tag_w) * 0.5, seam_y + 30.0)
	draw_string(caps, tag_at, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, Style.CREAM)
	_flourish(Vector2(tag_at.x - 12.0, tag_at.y - 4.0), -1.0)
	_flourish(Vector2(tag_at.x + tag_w + 12.0, tag_at.y - 4.0), 1.0)


## A little engraved rule ending in a diamond, either side of the tagline.
func _flourish(at: Vector2, dir: float) -> void:
	var brass := Style.tint(Style.BRASS, 0.85)
	draw_line(at, at + Vector2(22.0 * dir, 0), brass, 1.0, true)
	var d := at + Vector2(27.0 * dir, 0)
	var pts := PackedVector2Array(
		[d + Vector2(-3.5, 0), d + Vector2(0, -3.5), d + Vector2(3.5, 0), d + Vector2(0, 3.5)]
	)
	draw_colored_polygon(pts, brass)


## Four-point twinkles walking across the leaf as `glint` runs 0..1, one after another.
func _glints(block: Rect2) -> void:
	if glint >= 1.0:
		return
	for i in GLINTS.size():
		var local := glint * (GLINTS.size() + 1.0) - float(i)  # each lives for ~2 slots
		if local <= 0.0 or local >= 2.0:
			continue
		var life := sin(local / 2.0 * PI)
		var at: Vector2 = block.position + block.size * GLINTS[i]
		var r := 9.0 * life
		var col := Style.tint(Style.CHALK, life)
		draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, 1.6, true)
		draw_line(at - Vector2(0, r), at + Vector2(0, r), col, 1.6, true)
		draw_circle(at, 1.8 * life, col)


## One line of gold leaf: dark lower-right edge, pale upper-left edge, brass face.
func _leaf(font: Font, text: String, at: Vector2) -> void:
	var left := HORIZONTAL_ALIGNMENT_LEFT
	draw_string(font, at + Vector2(2.5, 3.0), text, left, -1, LETTER, Style.tint(Style.SHADOW, 0.5))
	draw_string(font, at + Vector2(1.5, 1.5), text, left, -1, LETTER, Style.RIM_DARK)
	draw_string(font, at + Vector2(-1.0, -1.0), text, left, -1, LETTER, Style.BRASS_LIGHT)
	draw_string(font, at, text, left, -1, LETTER, Style.BRASS)


## A running stitch from `from` to `to` with a gentle wave, sewn as far as `progress`,
## and the needle riding its leading end.
func _thread(from: Vector2, to: Vector2) -> void:
	var span := to.x - from.x
	var reach := span * progress
	var dash := 9.0
	var gap := 6.0
	var x := 0.0
	while x < reach:
		var end := minf(x + dash, reach)
		draw_line(_seam(from, x, span), _seam(from, end, span), Style.CHALK, 2.0, true)
		x += dash + gap
	var tip := _seam(from, reach, span)
	var dir := (_seam(from, reach + 1.0, span) - tip).normalized().rotated(-0.5)
	_needle(tip + dir * 7.0 * NEEDLE_SIZE, dir, tip)


## A sewing needle lying along `dir` with its head at `head`: a rounded head, a long
## slot eye the thread runs through, a shaft that tapers to a fine point, and a lit edge.
## `thread_from` is where the sewn thread leaves the seam for the eye.
func _needle(head: Vector2, dir: Vector2, thread_from: Vector2) -> void:
	var side := dir.orthogonal()
	var body := PackedVector2Array()
	var back := PackedVector2Array()
	for i in NEEDLE_PROFILE.size():
		var at: Vector2 = head + dir * NEEDLE_PROFILE[i].x * NEEDLE_SIZE
		body.append(at + side * NEEDLE_PROFILE[i].y * NEEDLE_SIZE)
		back.append(at - side * NEEDLE_PROFILE[i].y * NEEDLE_SIZE)
	back.reverse()
	var outline := body.duplicate()
	outline.append_array(back)
	for i in range(1, 6):  # the round of the head, from the back edge over to the front
		var a := -PI * 0.5 - PI * i / 6.0
		outline.append(head + (dir * cos(a) + side * sin(a)) * NEEDLE_PROFILE[0].y * NEEDLE_SIZE)
	var s := NEEDLE_SIZE
	var eye_mid := head + dir * 5.5 * s
	# Behind the needle: the thread's tail hanging out of the eye's far side.
	var tail := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		tail.append(eye_mid - side * (3.0 + 9.0 * t) * s - dir * (5.0 * t * t) * s)
	draw_polyline(tail, Style.CHALK, 2.0, true)
	draw_colored_polygon(outline, Style.STEEL)
	# Shade the lower edge, light the upper one.
	var low := PackedVector2Array()
	var lit := PackedVector2Array()
	for i in NEEDLE_PROFILE.size() - 1:
		var at: Vector2 = head + dir * NEEDLE_PROFILE[i].x * s
		low.append(at - side * NEEDLE_PROFILE[i].y * 0.55 * s)
		lit.append(at + side * NEEDLE_PROFILE[i].y * 0.45 * s)
	draw_polyline(low, Style.STEEL_DARK, 1.2 * s, true)
	draw_polyline(lit, Style.tint(Style.CHALK, 0.85), 1.0 * s, true)
	outline.append(outline[0])
	draw_polyline(outline, Style.STEEL_DARK, 1.2, true)
	# The eye: a long slot through the head, and the thread coming in through it.
	var slot := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		slot.append(eye_mid + (dir * cos(a) * 3.6 + side * sin(a) * 1.15) * s)
	draw_colored_polygon(slot, Style.WALNUT)
	draw_line(thread_from, eye_mid - dir * 1.5 * s, Style.CHALK, 2.0, true)


func _seam(from: Vector2, along: float, span: float) -> Vector2:
	return from + Vector2(along, sin(along / span * TAU) * 4.0)
