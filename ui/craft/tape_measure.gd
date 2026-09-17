class_name TapeMeasure
extends Control

## A tailor's tape measure strip (see Craft.tape): metre numbers, labelled marks for
## what each part needs, and a brass cursor at the current cut length that slides
## smoothly when it changes. Used by the shelf's cut measuring.

var max_m := 3.0
var marks: Dictionary = {}  # metres -> label
var value := 0.0:
	set(v):
		value = v
		queue_redraw()

var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Slide the cursor to `metres`.
func set_value(metres: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "value", metres, 0.12)


func _draw() -> void:
	var r := Rect2(Vector2(4, 24), Vector2(size.x - 8, 20))
	Craft.tape(self, r, max_m, marks, value)
