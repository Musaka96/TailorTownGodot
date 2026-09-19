class_name PatienceMeter
extends Control

## A waiting customer's patience, drawn as a little stitched bar with an hourglass: it
## drains forest -> amber -> clay as `value` falls from 1 to 0, and trembles near the end.
## Purely a view — whoever owns the wait sets `value`.

const BAR := Vector2(92, 14)

var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## The wait has been eased (a coffee in hand): the hourglass turns forest green.
var soothed := false:
	set(v):
		soothed = v
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR.x + 26.0, 24.0)
	size = custom_minimum_size


func _process(delta: float) -> void:
	_time += delta
	if value < 0.25:
		queue_redraw()


func _draw() -> void:
	var shake := Vector2(sin(_time * 40.0) * 1.5, 0.0) if value < 0.25 else Vector2.ZERO
	var plate := Rect2(shake, size)
	Craft.card(self, Craft.rounded(plate, 11.0), Style.CREAM, Style.WALNUT, 2.0)
	_hourglass(plate.position + Vector2(13.0, size.y * 0.5))
	var track := Rect2(
		plate.position + Vector2(24.0, (size.y - BAR.y) * 0.5), BAR - Vector2(6.0, 0.0)
	)
	draw_colored_polygon(Craft.rounded(track, 6.0), Style.CREAM_DARK)
	if value > 0.0:
		# Never narrower than it is tall: a sliver of a rounded rect can't be triangulated.
		var wide := maxf(track.size.x * value, track.size.y + 1.0)
		var fill := Rect2(track.position, Vector2(wide, track.size.y))
		draw_colored_polygon(Craft.rounded(fill, 6.0), Style.fill_color(value))


func _hourglass(at: Vector2) -> void:
	var col := Style.FOREST if soothed else Style.WALNUT
	var top := PackedVector2Array([at + Vector2(-5, -7), at + Vector2(5, -7), at])
	var low := PackedVector2Array([at + Vector2(-5, 7), at + Vector2(5, 7), at])
	draw_colored_polygon(top, col)
	draw_colored_polygon(low, col)
	draw_line(at + Vector2(-6, -7), at + Vector2(6, -7), col, 2.0)
	draw_line(at + Vector2(-6, 7), at + Vector2(6, 7), col, 2.0)
