class_name PointerPin
extends Control

## The tutorial's "look here" marker in the craft style: a dressmaker's pin — glossy
## burgundy head, brass needle — hovering above the target and bobbing down toward it,
## with a soft pulsing chalk ring where it points. Call point_at(screen_pos) each frame
## (the needle tip lands on that point); hide it with `visible = false`.
##
## When the target is off the screen the pin stays visible: it sits on the screen edge
## nearest the target, needle turned to point the way, with a chevron past the tip so
## the player knows where to walk.

const NEEDLE := 44.0  # needle length (tip → head)
const HEAD_R := 14.0
const BOB := 6.0
const TILT := 0.35  # radians the pin leans (head up-right, tip down-left)
const EDGE := 56.0  # inset from the viewport edge where an off-screen pin parks

var _target := Vector2.ZERO
var _time := 0.0
var _off_screen := false
var _aim := Vector2.DOWN  # screen direction toward an off-screen target


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Put the needle tip on `screen_pos`. A point outside the viewport parks the pin on the
## nearest edge, pointing toward it.
func point_at(screen_pos: Vector2) -> void:
	var rect := get_viewport_rect().grow(-EDGE)
	_off_screen = not rect.has_point(screen_pos)
	if _off_screen:
		var centre := rect.get_center()
		_aim = (screen_pos - centre).normalized()
		if not _aim.is_finite() or _aim == Vector2.ZERO:
			_aim = Vector2.DOWN
		_target = screen_pos.clamp(rect.position, rect.end)
	else:
		_target = screen_pos
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	position = _target
	queue_redraw()


func _draw() -> void:
	var bob := (0.5 + 0.5 * sin(_time * 5.5)) * BOB
	if _off_screen:
		_draw_chevron(bob)
		_draw_pin(-_aim, 6.0 + bob)
		return
	# Pulsing ring on the spot.
	var pulse := fmod(_time * 0.9, 1.0)
	var ring := Color(Style.CHALK, 0.85 * (1.0 - pulse))
	draw_arc(Vector2.ZERO, 8.0 + pulse * 18.0, 0.0, TAU, 32, ring, 2.5, true)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, Color(Style.BRASS, 0.9), 2.0, true)
	# The pin, leaning, hovering above the tip.
	_draw_pin(Vector2(sin(TILT), -cos(TILT)), 4.0 + bob)


## The pin with its tip `lift` px from the origin along `dir` (tip → head).
func _draw_pin(dir: Vector2, lift: float) -> void:
	var tip := dir * lift
	var head := tip + dir * NEEDLE
	var side := Vector2(-dir.y, dir.x)
	var shaft := PackedVector2Array([tip, head + side * 3.0, head - side * 3.0])
	draw_colored_polygon(shaft, Style.BRASS)
	Craft.outline(self, shaft, Style.WALNUT, 1.5)
	draw_line(tip, head, Style.RIM_DARK, 1.0, true)
	draw_line(tip + side * 0.8, head + side * 1.6, Color(Style.CHALK, 0.7), 1.0, true)
	# Head with a shadow, outline and highlight (like Craft.pin, a touch bigger).
	draw_circle(head + Vector2(2.0, 3.0), HEAD_R, Style.SHADOW)
	draw_circle(head, HEAD_R, Style.BURGUNDY)
	draw_circle(head, HEAD_R, Style.WALNUT, false, 2.0, true)
	draw_circle(head - Vector2(HEAD_R, HEAD_R) * 0.32, HEAD_R * 0.34, Color(Style.CHALK, 0.9))


## A chalk chevron just past the needle tip, nudging outward toward the target.
func _draw_chevron(bob: float) -> void:
	var side := Vector2(-_aim.y, _aim.x)
	var apex := _aim * (14.0 - bob)
	var back := apex - _aim * 10.0
	var pts := PackedVector2Array([back + side * 9.0, apex, back - side * 9.0])
	draw_polyline(pts, Style.SHADOW, 5.0, true)
	draw_polyline(pts, Style.CHALK, 3.0, true)
