class_name Mirror
extends Node3D

## The fitting station: a mirror and stool where a customer stands and you design
## their suit. Interacting opens the suit builder (with the camera framing the
## customer, if one is currently being fitted here).
##
## `customer` is set by whichever Customer walks up to be fitted, and cleared when
## they leave. With no customer it's free-design mode (no order is created).

var customer: Node = null


func get_interaction_prompt(_actor) -> String:
	if customer != null:
		return "Design the suit"
	return "Fitting mirror (no customer)"


func interact(actor) -> void:
	UI.open_suit_builder(self, actor)
