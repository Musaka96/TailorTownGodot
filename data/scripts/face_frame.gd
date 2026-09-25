class_name FaceFrame
extends Resource

## Where a head's face sits: the bounding rect of its flat front (the vertices facing +Z),
## measured in head-bone rest space by FaceUvBaker, plus optional per-head nudges. The head
## mesh's UV2 maps that rect to 0..1 (u right, v down, as the camera sees the face), and
## skin_face.gdshader draws the FaceStyle's elements at their face-unit positions in it.

## Rect centre in metres (head-bone rest space, x right as the camera sees it, y up).
@export var center := Vector2.ZERO
## Rect width and height in metres.
@export var size := Vector2.ONE
## The front plate's depth (largest z of the front vertices), metres.
@export var front_z := 0.0
## Shift of the whole face in face units (x right, y down).
@export var offset := Vector2.ZERO
## Scale of the whole face about the rect centre (1 = as the style lays it out).
@export var scale := 1.0
## Where the eye line sits on this head, as a fraction of the face height from the top
## (< 0 = where the style puts it). Moves eyes and brows together.
@export var eye_line := -1.0


## Width over height of the rect.
func aspect() -> float:
	return size.x / maxf(size.y, 1e-5)


func describe() -> String:
	return (
		"centre (%.3f, %.3f) m, size %.3f x %.3f m, aspect %.2f, front z %.3f"
		% [center.x, center.y, size.x, size.y, aspect(), front_z]
	)
