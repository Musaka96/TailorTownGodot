class_name SpeechTail
extends Control

## A little downward tail for a speech-bubble panel — a filled triangle hanging off
## the panel's bottom edge with a matching outline, so a menu reads as something the
## character is "saying". Add it as a child of the bubble PanelContainer (like
## AtelierFrame); it reads the panel's content margins back so the tail sits on the
## true bottom edge rather than the inset content rect. Transparent, ignores mouse.

const DROP := 18.0  # how far the tail hangs below the panel
const WIDTH := 28.0

var fill := Color("f4ead2")
var border := Color("6b4f34")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func setup(fill_col: Color, border_col: Color) -> void:
	fill = fill_col
	border = border_col
	queue_redraw()


func _draw() -> void:
	var ml := 0.0
	var mr := 0.0
	var mb := 0.0
	var p := get_parent() as Control
	if p != null:
		var sb := p.get_theme_stylebox("panel")
		if sb != null:
			ml = sb.get_margin(SIDE_LEFT)
			mr = sb.get_margin(SIDE_RIGHT)
			mb = sb.get_margin(SIDE_BOTTOM)
	var panel_w := size.x + ml + mr
	var bottom := size.y + mb
	var bx := -ml + panel_w * 0.30  # tail base, left of centre toward the customer
	var a := Vector2(bx, bottom - 2.0)
	var b := Vector2(bx + WIDTH, bottom - 2.0)
	var tip := Vector2(bx + WIDTH * 0.3, bottom + DROP)
	draw_colored_polygon(PackedVector2Array([a, b, tip]), fill)
	draw_line(a, tip, border, 2.0)
	draw_line(b, tip, border, 2.0)
