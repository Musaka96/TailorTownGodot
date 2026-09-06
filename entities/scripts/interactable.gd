class_name Interactable
extends Area3D

## Generic interaction trigger. Put this Area3D on (or under) any object the
## player can interact with; it forwards prompt/interact to `target` (defaults to
## the parent), which implements:
##   func get_interaction_prompt(actor) -> String
##   func interact(actor) -> void
##
## The player's InteractionController finds these via the "interactable" group +
## Area overlap, so this must sit on the interactable collision layer.

@export var target: Node


func _ready() -> void:
	add_to_group("interactable")
	if target == null:
		target = get_parent()


func get_prompt(actor) -> String:
	if target and target.has_method("get_interaction_prompt"):
		return target.get_interaction_prompt(actor)
	return "Interact"


func do_interact(actor) -> void:
	if target and target.has_method("interact"):
		target.interact(actor)


## Enable/disable detection (e.g. while an item is carried or shelved).
func set_enabled(enabled: bool) -> void:
	monitorable = enabled
	if enabled:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")
