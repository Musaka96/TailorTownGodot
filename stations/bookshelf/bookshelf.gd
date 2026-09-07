class_name Bookshelf
extends Node3D

## A shelf of reference books. Interacting opens the Tailor's Handbook, where the
## player can study fabrics, patterns, styles and dress codes.


func get_interaction_prompt(_actor) -> String:
	return "Read the Tailor's Handbook"


func interact(actor) -> void:
	UI.open_handbook(actor)
