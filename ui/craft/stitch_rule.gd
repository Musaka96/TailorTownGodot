class_name StitchRule
extends Control

## The rule under a title: a short solid bar in the skin accent, then a running stitch
## out to the right edge — like a seam started with a bar tack. `weight` thins it for
## section headers.

const BAR := 40.0  # length of the solid bar tack
const DASH := 6.0
const GAP := 5.0

var accent := Style.BRASS
var bar := true
var weight := 3.0


static func make(col: Color, with_bar := true, thickness := 3.0) -> StitchRule:
	var rule := StitchRule.new()
	rule.accent = col
	rule.bar = with_bar
	rule.weight = thickness
	return rule


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, weight + 2.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var y := size.y * 0.5
	var x := 0.0
	if bar:
		var tack := Rect2(0.0, y - weight * 0.5, minf(BAR, size.x), weight)
		draw_rect(tack, accent)
		x = BAR + GAP
	var thread := Style.tint(accent, 0.85)
	while x < size.x:
		var end := minf(x + DASH, size.x)
		draw_line(Vector2(x, y), Vector2(end, y), thread, maxf(weight - 1.0, 1.0))
		x += DASH + GAP
