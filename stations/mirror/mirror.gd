class_name Mirror
extends Node3D

## The fitting station: a mirror and stool where a customer sits and you design
## their suit. Interacting opens the suit builder (with the camera framing the
## customer).

@onready var customer: Node = $Customer


func get_interaction_prompt(_actor) -> String:
	return "Design a suit"


func interact(actor) -> void:
	UI.open_suit_builder(self, actor)
