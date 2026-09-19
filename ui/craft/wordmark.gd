class_name Wordmark
extends Control

## The shop's name as fascia lettering: a two-line gold-leaf lockup in the display face,
## a running stitch sewn underneath that ends in a threaded needle, and a tracked
## tagline. Flat shapes only — the leaf is a face, a dark lower edge and a pale upper
## one. `progress` (0..1) sews the thread in; sew_in() animates it.

const LETTER := 62  # display size of the two name lines
const LEAD := 54.0  # baseline to baseline
const STEP := 50.0  # how far the second line is indented past the first
const TAGLINE := "BESPOKE TAILORING  ·  ON THE ROW"

var progress := 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(360, 178)


## Sew the underline in from the left.
func sew_in(time := 0.9, delay := 0.0) -> void:
	progress = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(delay)
	tw.tween_property(self, "progress", 1.0, time)


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
	var caps := Style.font_caps()
	var tag_w := caps.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO).x
	var tag_at := Vector2((size.x - tag_w) * 0.5, seam_y + 30.0)
	draw_string(caps, tag_at, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.T_MICRO, Style.CREAM)


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
	var dir := (_seam(from, reach + 1.0, span) - tip).normalized().rotated(-0.35)
	var eye := tip + dir * 6.0
	var point := tip + dir * 46.0
	draw_line(tip, eye, Style.CHALK, 1.5, true)
	draw_line(eye, point, Style.STEEL, 3.5, true)
	draw_line(point, point + dir * 7.0, Style.STEEL, 1.5, true)
	draw_circle(eye + dir * 3.0, 1.2, Style.WALNUT)


func _seam(from: Vector2, along: float, span: float) -> Vector2:
	return from + Vector2(along, sin(along / span * TAU) * 4.0)
