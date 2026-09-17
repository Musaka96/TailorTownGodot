class_name PointerPin
extends Control

## The tutorial's "look here" marker in the craft style: a dressmaker's pin — glossy
## burgundy head, brass needle — hovering above the target and bobbing down toward it,
## with a soft pulsing chalk ring where it points. Call point_at(screen_pos) each frame
## (the needle tip lands on that point); hide it with `visible = false`.

const NEEDLE := 44.0  # needle length (tip → head)
const HEAD_R := 14.0
const BOB := 6.0
const TILT := 0.35  # radians the pin leans (head up-right, tip down-left)

var _target := Vector2.ZERO
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Put the needle tip on `screen_pos`.
func point_at(screen_pos: Vector2) -> void:
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
	# Pulsing ring on the spot.
	var pulse := fmod(_time * 0.9, 1.0)
	var ring := Color(Style.CHALK, 0.85 * (1.0 - pulse))
	draw_arc(Vector2.ZERO, 8.0 + pulse * 18.0, 0.0, TAU, 32, ring, 2.5, true)
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, Color(Style.BRASS, 0.9), 2.0, true)
	# The pin, leaning, hovering above the tip.
	var dir := Vector2(sin(TILT), -cos(TILT))  # from tip toward the head
	var tip := dir * (4.0 + bob)
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
