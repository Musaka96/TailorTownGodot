class_name MinigameCanvas
extends Control

## A blank drawing surface for the cutting / sewing minigames. It sits inside the
## atelier panel (so it draws on top of the stitched frame) and defers all painting
## to a Callable the host sets — `painter.call(self)` runs inside this node's _draw,
## so the host can issue draw_* commands against it. Call queue_redraw() to repaint.

var painter := Callable()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
